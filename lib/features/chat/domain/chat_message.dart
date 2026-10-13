/// Message delivery/read status.
enum MessageStatus {
  sending,
  sent,
  read;

  static MessageStatus fromMap(bool isRead, bool isSending) {
    if (isSending) return MessageStatus.sending;
    if (isRead) return MessageStatus.read;
    return MessageStatus.sent;
  }
}

/// Domain model for a single chat message in a conversation.
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.isRead = false,
    required this.createdAt,
    this.status = MessageStatus.sent,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      status: (map['is_read'] as bool? ?? false)
          ? MessageStatus.read
          : MessageStatus.sent,
    );
  }

  /// Optimistic pending message before server confirmation.
  factory ChatMessage.pending({
    required String conversationId,
    required String senderId,
    required String content,
  }) {
    return ChatMessage(
      id: 'pending-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      isRead: false,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'is_read': false,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    bool? isRead,
    DateTime? createdAt,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  /// Returns a short, human-readable relative timestamp.
  String get timeLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) {
      final h = createdAt.hour.toString().padLeft(2, '0');
      final m = createdAt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${createdAt.day}/${createdAt.month}';
  }
}

/// Domain model for a conversation thread between two matched users.
class Conversation {
  final String id;
  final String matchId;
  final String userOneId;
  final String userTwoId;
  final String? lastMessage;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  // Enriched partner data (joined on fetch)
  final String partnerName;
  final String partnerId;
  final String? partnerPhotoUrl;
  final bool partnerIsVerified;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.matchId,
    required this.userOneId,
    required this.userTwoId,
    this.lastMessage,
    required this.lastMessageAt,
    required this.createdAt,
    required this.partnerName,
    required this.partnerId,
    this.partnerPhotoUrl,
    this.partnerIsVerified = false,
    this.unreadCount = 0,
  });

  factory Conversation.fromMap(Map<String, dynamic> map, String currentUserId) {
    final isUserOne = map['user_one'] as String == currentUserId;
    final partnerId =
        isUserOne ? map['user_two'] as String : map['user_one'] as String;

    // Partner profile may be embedded as a joined map
    final partnerProfile = map['partner_profile'] as Map<String, dynamic>?;
    final partnerName = partnerProfile?['full_name'] as String? ?? 'مستخدم';
    final partnerPhotoUrl = partnerProfile?['primary_photo_url'] as String?;
    final partnerIsVerified =
        (partnerProfile?['verification_status'] as String?) == 'VERIFIED';

    return Conversation(
      id: map['id'] as String,
      matchId: map['match_id'] as String,
      userOneId: map['user_one'] as String,
      userTwoId: map['user_two'] as String,
      lastMessage: map['last_message'] as String?,
      lastMessageAt: map['last_message_at'] != null
          ? DateTime.parse(map['last_message_at'] as String).toLocal()
          : DateTime.now(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String).toLocal()
          : DateTime.now(),
      partnerName: partnerName,
      partnerId: partnerId,
      partnerPhotoUrl: partnerPhotoUrl,
      partnerIsVerified: partnerIsVerified,
      unreadCount: map['unread_count'] as int? ?? 0,
    );
  }

  Conversation copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    String? partnerPhotoUrl,
  }) {
    return Conversation(
      id: id,
      matchId: matchId,
      userOneId: userOneId,
      userTwoId: userTwoId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt,
      partnerName: partnerName,
      partnerId: partnerId,
      partnerPhotoUrl: partnerPhotoUrl ?? this.partnerPhotoUrl,
      partnerIsVerified: partnerIsVerified,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  /// Returns human-readable relative timestamp for inbox list.
  String get lastMessageTimeLabel {
    final now = DateTime.now();
    final diff = now.difference(lastMessageAt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) {
      final h = lastMessageAt.hour.toString().padLeft(2, '0');
      final m = lastMessageAt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diff.inDays == 1) return 'أمس';
    return '${lastMessageAt.day}/${lastMessageAt.month}';
  }
}

/// Result of the chat authorization guard check.
class ChatAuthResult {
  final bool isAllowed;
  final String? conversationId;
  final String? errorCode;
  final String? errorMessage;

  const ChatAuthResult({
    required this.isAllowed,
    this.conversationId,
    this.errorCode,
    this.errorMessage,
  });

  factory ChatAuthResult.allowed(String conversationId) {
    return ChatAuthResult(
      isAllowed: true,
      conversationId: conversationId,
    );
  }

  factory ChatAuthResult.denied(String code, String message) {
    return ChatAuthResult(
      isAllowed: false,
      errorCode: code,
      errorMessage: message,
    );
  }
}
