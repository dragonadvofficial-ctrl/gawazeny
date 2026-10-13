import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
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

      return ChatAuthResult.allowed(map['conversation_id'] as String);
    } catch (e, stack) {
      developer.log('getOrCreateConversation RPC error: $e',
          error: e, stackTrace: stack);

      // Client-side fallback guard: check verification status directly
      return await _clientSideAuthGuard(matchId, partnerId);
    }
  }

  Future<ChatAuthResult> _clientSideAuthGuard(
      String matchId, String partnerId) async {
    final uid = _userId!;

    try {
      // Check own verification status
      final myProfile = await _client
          .from('profiles')
          .select('verification_status')
          .eq('id', uid)
          .single();

      if ((myProfile['verification_status'] as String?) != 'VERIFIED') {
        return ChatAuthResult.denied(
          'NOT_VERIFIED',
          'يجب توثيق هويتك أولاً لبدء المحادثة',
        );
      }

      // Check partner verification status
      final partnerProfile = await _client
          .from('profiles')
          .select('verification_status')
          .eq('id', partnerId)
          .single();

      if ((partnerProfile['verification_status'] as String?) != 'VERIFIED') {
        return ChatAuthResult.denied(
          'PARTNER_NOT_VERIFIED',
          'الطرف الآخر لم يُوثّق هويته بعد، لا يمكن بدء المحادثة',
        );
      }

      // Check block status
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

      // Upsert conversation directly
      final existing = await _client
          .from('conversations')
          .select('id')
          .eq('match_id', matchId)
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
