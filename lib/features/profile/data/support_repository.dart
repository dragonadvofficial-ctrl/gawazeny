import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';

/// Model representing a support message sent by a user.
class SupportMessage {
  final String id;
  final String userId;
  final String? subject;
  final String content;
  final String status;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.userId,
    this.subject,
    required this.content,
    required this.status,
    this.adminReply,
    this.repliedAt,
    required this.createdAt,
  });

  factory SupportMessage.fromMap(Map<String, dynamic> map) {
    return SupportMessage(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      subject: map['subject'] as String?,
      content: map['content'] as String,
      status: map['status'] as String? ?? 'open',
      adminReply: map['admin_reply'] as String?,
      repliedAt: map['replied_at'] != null
          ? DateTime.parse(map['replied_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Human-readable status label in Arabic.
  String get statusLabelAr {
    switch (status) {
      case 'open':
        return 'مفتوحة';
      case 'in_progress':
        return 'قيد المعالجة';
      case 'closed':
        return 'مغلقة';
      default:
        return status;
    }
  }

  String get statusLabelEn {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }
}

/// Repository for sending and fetching support messages.
class SupportRepository {
  final SupabaseService _supabase;

  const SupportRepository(this._supabase);

  /// Sends a new support message from the current user.
  Future<bool> sendSupportMessage({
    required String subject,
    required String content,
  }) async {
    try {
      final userId = _supabase.requireCurrentUserId;
      await _supabase.client.from('support_messages').insert({
        'user_id': userId,
        'subject': subject,
        'content': content,
        'status': 'open',
      });
      return true;
    } catch (e, stack) {
      developer.log(
        'SupportRepository.sendSupportMessage error: $e',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Fetches all support messages for the current user.
  Future<List<SupportMessage>> getUserMessages() async {
    try {
      final userId = _supabase.requireCurrentUserId;
      final response = await _supabase.client
          .from('support_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((m) => SupportMessage.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e, stack) {
      developer.log(
        'SupportRepository.getUserMessages error: $e',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }
}

/// Provider for [SupportRepository].
final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return SupportRepository(supabase);
});
