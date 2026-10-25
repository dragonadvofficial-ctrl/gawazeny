import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/preview/preview_config.dart';
import '../../../core/preview/preview_mock_data.dart';
import '../domain/chat_message.dart';

/// Repository managing all chat operations: conversations, messages, realtime, and auth guards.
class ChatRepository {
  final SupabaseClient _client;

  ChatRepository(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // CHAT AUTHORIZATION GUARD
  // Calls the get_or_create_conversation RPC which validates:
  //   1. Active mutual match exists
  //   2. Both users are VERIFIED
  //   3. No block relationship
  // ---------------------------------------------------------------------------
  Future<ChatAuthResult> getOrCreateConversation({
    required String matchId,
    required String partnerId,
  }) async {
    if (kPreviewMode) {
      final existingConv = PreviewMockData.conversations.cast<Conversation?>().firstWhere(
        (c) => c != null && (c.matchId == matchId || c.partnerId == partnerId),
        orElse: () => null,
      );
      if (existingConv != null) {
        return ChatAuthResult.allowed(existingConv.id);
      }
      final generatedId = 'preview-conv-$matchId';
      return ChatAuthResult.allowed(generatedId);
    }

    final uid = _userId;
    if (uid == null) {
      return ChatAuthResult.denied('NOT_AUTH', 'يجب تسجيل الدخول أولاً');
    }

    try {
      final result = await _client.rpc(
        'get_or_create_conversation',
        params: {
          'p_match_id': matchId,
          'p_partner_id': partnerId,
        },
      );

      final map = Map<String, dynamic>.from(result as Map);
      if (map.containsKey('error')) {
        return ChatAuthResult.denied(
          map['error'] as String,
          map['message'] as String? ??
              'تعذر فتح المحادثة، يرجى المحاولة لاحقاً',
        );
      }

      final convId = map['conversation_id'] as String?;
      if (convId == null || convId.isEmpty) {
        return await _clientSideAuthGuard(matchId, partnerId);
      }

      return ChatAuthResult.allowed(convId);
    } on PostgrestException catch (e, stack) {
      developer.log('getOrCreateConversation PostgrestException: ${e.code} ${e.message}',
          error: e, stackTrace: stack);
      if (e.code == '401' || e.message.contains('Not authenticated')) {
        return ChatAuthResult.denied('NOT_AUTH', 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً');
      }
      return await _clientSideAuthGuard(matchId, partnerId);
    } catch (e, stack) {
      developer.log('getOrCreateConversation RPC error: $e',
          error: e, stackTrace: stack);

      // Client-side fallback guard: check verification status directly
      return await _clientSideAuthGuard(matchId, partnerId);
    }
  }

  Future<ChatAuthResult> _clientSideAuthGuard(
      String matchId, String partnerId) async {
    final uid = _userId;
    if (uid == null) {
      return ChatAuthResult.denied('NOT_AUTH', 'يجب تسجيل الدخول أولاً');
    }

    try {
      // 1. Verify active match exists & caller is participant
      try {
        final matchCheck = await _client
            .from('matches')
            .select('id, is_active, user_one, user_two')
            .eq('id', matchId)
            .maybeSingle();

        if (matchCheck != null) {
          if (matchCheck['is_active'] != true) {
            return ChatAuthResult.denied(
              'NO_MATCH',
              'تم إنهاء هذا التوافق، لا يمكن بدء المحادثة',
            );
          }
          final u1 = matchCheck['user_one'] as String?;
          final u2 = matchCheck['user_two'] as String?;
          if (uid != u1 && uid != u2) {
            return ChatAuthResult.denied(
              'UNAUTHORIZED',
              'ليس لديك صلاحية الوصول لهذا التوافق',
            );
          }
        }
      } catch (e) {
        developer.log('Direct match check query notice: $e');
      }

      // 2. Check own verification status
      final myProfile = await _client
          .from('profiles')
          .select('verification_status')
          .eq('id', uid)
          .single();

      final myStatus = (myProfile['verification_status'] as String?)?.toUpperCase();
      if (myStatus != 'VERIFIED') {
        return ChatAuthResult.denied(
          'NOT_VERIFIED',
          'يجب توثيق هويتك أولاً لبدء المحادثة',
        );
      }

      // 3. Check partner verification status
      final partnerProfile = await _client
          .from('profiles')
          .select('verification_status')
          .eq('id', partnerId)
          .single();

      final partnerStatus = (partnerProfile['verification_status'] as String?)?.toUpperCase();
      if (partnerStatus != 'VERIFIED') {
        return ChatAuthResult.denied(
          'PARTNER_NOT_VERIFIED',
          'الطرف الآخر لم يُوثّق هويته بعد، لا يمكن بدء المحادثة',
        );
      }

      // 4. Check block status
      final blockCheck = await _client
          .from('blocked_users')
          .select('id')
          .or('and(blocker_id.eq.$uid,blocked_id.eq.$partnerId),and(blocker_id.eq.$partnerId,blocked_id.eq.$uid)')
          .limit(1);

      if ((blockCheck as List).isNotEmpty) {
        return ChatAuthResult.denied(
          'BLOCKED',
          'تعذر فتح المحادثة بسبب الحظر',
        );
      }

      // 5. Look for existing conversation by match_id or between users to prevent duplicates
      final existing = await _client
          .from('conversations')
          .select('id')
          .or('match_id.eq.$matchId,and(user_one.eq.$uid,user_two.eq.$partnerId),and(user_one.eq.$partnerId,user_two.eq.$uid)')
          .limit(1)
          .maybeSingle();

      String conversationId;
      if (existing != null) {
        conversationId = existing['id'] as String;
      } else {
        final inserted = await _client
            .from('conversations')
            .insert({
              'match_id': matchId,
              'user_one': uid,
              'user_two': partnerId,
            })
            .select('id')
            .single();
        conversationId = inserted['id'] as String;
      }

      return ChatAuthResult.allowed(conversationId);
    } on PostgrestException catch (e) {
      developer.log('Client-side auth guard PostgrestException: ${e.code} ${e.message}');
      if (e.code == '401') {
        return ChatAuthResult.denied('NOT_AUTH', 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً');
      }
      if (e.code == '403') {
        return ChatAuthResult.denied('UNAUTHORIZED', 'غير مصرح لك بالوصول لهذه المحادثة');
      }
      if (e.code == '404') {
        return ChatAuthResult.denied('NOT_FOUND', 'بيانات المحادثة غير موجودة');
      }
      return ChatAuthResult.denied(
        'ERROR',
        'حدث خطأ في قاعدة البيانات (${e.code})',
      );
    } catch (e) {
      developer.log('Client-side auth guard fallback failed: $e');
      return ChatAuthResult.denied(
        'ERROR',
        'حدث خطأ أثناء التحقق من صلاحيات المحادثة',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // FETCH ALL CONVERSATIONS for current user with partner enrichment.
  // ---------------------------------------------------------------------------
  Future<List<Conversation>> fetchUserConversations() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final data = await _client
          .from('conversations')
          .select('''
            id, match_id, user_one, user_two, last_message, last_message_at, created_at
          ''')
          .or('user_one.eq.$uid,user_two.eq.$uid')
          .order('last_message_at', ascending: false);

      final conversations = <Conversation>[];

      for (final row in (data as List)) {
        final map = Map<String, dynamic>.from(row);
        final isUserOne = map['user_one'] as String == uid;
        final partnerId =
            isUserOne ? map['user_two'] as String : map['user_one'] as String;

        // Fetch partner profile separately
        try {
          final partnerData = await _client
              .from('profiles')
              .select('id, full_name, verification_status')
              .eq('id', partnerId)
              .single();

          // Attempt to get primary photo
          String? photoUrl;
          try {
            final photoData = await _client
                .from('profile_photos')
                .select('photo_url')
                .eq('user_id', partnerId)
                .eq('is_primary', true)
                .maybeSingle();
            photoUrl = photoData?['photo_url'] as String?;
          } catch (_) {}

          // Count unread messages
          int unreadCount = 0;
          try {
            final unread = await _client
                .from('messages')
                .select('id')
                .eq('conversation_id', map['id'] as String)
                .eq('is_read', false)
                .neq('sender_id', uid);
            unreadCount = (unread as List).length;
          } catch (_) {}

          map['partner_profile'] = {
            'full_name': partnerData['full_name'],
            'verification_status': partnerData['verification_status'],
            'primary_photo_url': photoUrl,
          };
          map['unread_count'] = unreadCount;

          conversations.add(Conversation.fromMap(map, uid));
        } catch (e) {
          developer.log('Error enriching conversation $partnerId: $e');
        }
      }

      return conversations;
    } catch (e) {
      developer.log('fetchUserConversations error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // FETCH MESSAGE HISTORY for a conversation (paginated, newest last).
  // ---------------------------------------------------------------------------
  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    int limit = 60,
  }) async {
    try {
      final data = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(limit);

      return (data as List)
          .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      developer.log('fetchMessages error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // SEND MESSAGE — returns the server-confirmed message.
  // ---------------------------------------------------------------------------
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final uid = _userId;
    if (uid == null) throw 'يجب تسجيل الدخول لإرسال الرسائل';

    final inserted = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': uid,
          'content': content.trim(),
          'is_read': false,
        })
        .select()
        .single();

    return ChatMessage.fromMap(Map<String, dynamic>.from(inserted));
  }

  // ---------------------------------------------------------------------------
  // REALTIME SUBSCRIPTION — stream of all messages for a conversation.
  // Uses Supabase Realtime channel with INSERT event listener.
  // ---------------------------------------------------------------------------
  Stream<List<ChatMessage>> subscribeToMessages(String conversationId) {
    final controller =
        _MessageStreamController(conversationId: conversationId);
    final channel = _client.channel('messages:$conversationId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            try {
              final newMsg = ChatMessage.fromMap(
                Map<String, dynamic>.from(payload.newRecord),
              );
              controller.onNewMessage(newMsg);
            } catch (e) {
              developer.log('Realtime message parse error: $e');
            }
          },
        )
        .subscribe();

    controller.setChannel(channel);
    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // MARK MESSAGES AS READ in a conversation.
  // ---------------------------------------------------------------------------
  Future<void> markMessagesRead(String conversationId) async {
    try {
      await _client.rpc(
        'mark_messages_read',
        params: {'p_conversation_id': conversationId},
      );
    } catch (_) {
      // Direct fallback
      try {
        final uid = _userId;
        if (uid == null) return;
        await _client
            .from('messages')
            .update({'is_read': true})
            .eq('conversation_id', conversationId)
            .eq('is_read', false)
            .neq('sender_id', uid);
      } catch (e) {
        developer.log('markMessagesRead fallback error: $e');
      }
    }
  }
}

/// Internal stream controller wrapping a Supabase Realtime channel.
class _MessageStreamController {
  final String conversationId;
  final _messages = <ChatMessage>[];
  late final _controller = _buildController();
  RealtimeChannel? _channel;

  _MessageStreamController({required this.conversationId});

  Stream<List<ChatMessage>> get stream => _controller.stream;

  StreamController<List<ChatMessage>> _buildController() {
    final sc = StreamController<List<ChatMessage>>.broadcast(
      onCancel: () => _channel?.unsubscribe(),
    );
    return sc;
  }

  void setChannel(RealtimeChannel channel) {
    _channel = channel;
  }

  void onNewMessage(ChatMessage message) {
    // Deduplicate by id
    if (!_messages.any((m) => m.id == message.id)) {
      _messages.add(message);
      _controller.add(List.unmodifiable(_messages));
    }
  }
}

/// Riverpod provider for [ChatRepository].
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ChatRepository(client);
});
