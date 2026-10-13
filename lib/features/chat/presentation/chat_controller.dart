import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/preview/preview_config.dart';
import '../../../core/preview/preview_mock_data.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message.dart';

// ============================================================================
// INBOX CONTROLLER — manages the list of conversations
// ============================================================================

class InboxState {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;

  const InboxState({
    this.conversations = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
  });

  InboxState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
  }) {
    return InboxState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Conversation> get filtered {
    if (searchQuery.isEmpty) return conversations;
    final q = searchQuery.toLowerCase();
    return conversations
        .where((c) => c.partnerName.toLowerCase().contains(q))
        .toList();
  }

  int get totalUnread =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);
}

class InboxController extends StateNotifier<InboxState> {
  final ChatRepository _repository;

  InboxController(this._repository) : super(const InboxState()) {
    loadConversations();
  }

  Future<void> loadConversations() async {
    if (kPreviewMode) {
      state = state.copyWith(
        conversations: PreviewMockData.conversations,
        isLoading: false,
        errorMessage: null,
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final convs = await _repository.fetchUserConversations();
      state = state.copyWith(conversations: convs, isLoading: false);
    } catch (e) {
      developer.log('InboxController.loadConversations error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل المحادثات، يرجى المحاولة لاحقاً',
      );
    }
  }

  void updateSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }
}

final inboxControllerProvider =
    StateNotifierProvider<InboxController, InboxState>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return InboxController(repo);
});

// ============================================================================
// CHAT ROOM CONTROLLER — manages a single active conversation
// ============================================================================

class ChatRoomState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;
  final ChatAuthResult? authResult;
  final bool isAuthChecking;

  const ChatRoomState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
    this.authResult,
    this.isAuthChecking = false,
  });

  ChatRoomState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    ChatAuthResult? authResult,
    bool? isAuthChecking,
  }) {
    return ChatRoomState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
      authResult: authResult ?? this.authResult,
      isAuthChecking: isAuthChecking ?? this.isAuthChecking,
    );
  }

  bool get isAllowed => authResult?.isAllowed == true;
  String? get conversationId => authResult?.conversationId;
}

class ChatRoomController extends StateNotifier<ChatRoomState> {
  final ChatRepository _repository;
  final Ref _ref;
  StreamSubscription<List<ChatMessage>>? _subscription;

  ChatRoomController(this._repository, this._ref)
      : super(const ChatRoomState());

  /// Initializes a chat room for a given match + partner.
  /// Runs the 3-gate authorization check before loading messages.
  Future<void> initRoom({
    required String matchId,
    required String partnerId,
  }) async {
    if (kPreviewMode) {
      state = state.copyWith(
        isAuthChecking: false,
        authResult: const ChatAuthResult(
          isAllowed: true,
          conversationId: 'preview-conv-sara',
        ),
        messages: PreviewMockData.chatMessages,
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(isAuthChecking: true, isLoading: true);

    final authResult = await _repository.getOrCreateConversation(
      matchId: matchId,
      partnerId: partnerId,
    );

    state = state.copyWith(
      authResult: authResult,
      isAuthChecking: false,
    );

    if (!authResult.isAllowed) {
      state = state.copyWith(isLoading: false);
      return;
    }

    await _loadMessages(authResult.conversationId!);
    _subscribeRealtime(authResult.conversationId!);
    await _repository.markMessagesRead(authResult.conversationId!);
  }

  Future<void> _loadMessages(String conversationId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final msgs = await _repository.fetchMessages(conversationId);
      state = state.copyWith(messages: msgs, isLoading: false);
    } catch (e) {
      developer.log('ChatRoomController._loadMessages error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل الرسائل',
      );
    }
  }

  void _subscribeRealtime(String conversationId) {
    _subscription?.cancel();
    final stream = _repository.subscribeToMessages(conversationId);
    _subscription = stream.listen((realtimeMsgs) {
      if (!mounted) return;
      // Merge realtime arrivals with existing messages, removing pending duplicates
      final existing = state.messages
          .where((m) => m.status != MessageStatus.sending)
          .toList();

      final allIds = existing.map((m) => m.id).toSet();
      final newOnes =
          realtimeMsgs.where((m) => !allIds.contains(m.id)).toList();

      if (newOnes.isNotEmpty) {
        final merged = [...existing, ...newOnes]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        state = state.copyWith(messages: merged);

        // Mark new received messages as read
        final convId = state.conversationId;
        if (convId != null) {
          _repository.markMessagesRead(convId);
        }
      }
    });
  }

  /// Sends a message with optimistic UI insertion.
  Future<void> sendMessage(String content) async {
    final convId = state.conversationId;
    final uid = _ref.read(currentUserProvider)?.id;
    if (convId == null || uid == null || content.trim().isEmpty) return;

    // Optimistic insert
    final pending = ChatMessage.pending(
      conversationId: convId,
      senderId: uid,
      content: content.trim(),
    );
    state = state.copyWith(
      messages: [...state.messages, pending],
      isSending: true,
      errorMessage: null,
    );

    if (kPreviewMode) {
      final confirmed = ChatMessage(
        id: 'msg-preview-${DateTime.now().millisecondsSinceEpoch}',
        conversationId: convId,
        senderId: uid,
        content: content.trim(),
        isRead: false,
        createdAt: DateTime.now(),
        status: MessageStatus.sent,
      );
      final updated = state.messages.map((m) {
        if (m.id == pending.id) return confirmed;
        return m;
      }).toList();
      state = state.copyWith(messages: updated, isSending: false);
      return;
    }

    try {
      final confirmed = await _repository.sendMessage(
        conversationId: convId,
        content: content.trim(),
      );

      // Replace pending with confirmed
      final updated = state.messages.map((m) {
        if (m.id == pending.id) return confirmed;
        return m;
      }).toList();

      state = state.copyWith(messages: updated, isSending: false);
    } catch (e) {
      developer.log('sendMessage error: $e');
      // Mark pending as failed
      final updated = state.messages.map((m) {
        if (m.id == pending.id) {
          return m.copyWith(status: MessageStatus.sent);
        }
        return m;
      }).toList();
      state = state.copyWith(
        messages: updated,
        isSending: false,
        errorMessage: 'تعذر إرسال الرسالة، يرجى المحاولة مجدداً',
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final chatRoomControllerProvider =
    StateNotifierProvider.autoDispose<ChatRoomController, ChatRoomState>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return ChatRoomController(repo, ref);
});
