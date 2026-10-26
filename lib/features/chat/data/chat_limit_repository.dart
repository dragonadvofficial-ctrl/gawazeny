import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';

/// Model holding the user's current message usage and limits.
class ChatLimitStatus {
  final bool allowed;
  final bool limitEnabled;
  final bool unlimited;
  final int? effectiveLimit;
  final String period;
  final int sentToday;
  final int sentMonth;
  final int remaining;
  final String limitAction;

  const ChatLimitStatus({
    this.allowed = true,
    this.limitEnabled = false,
    this.unlimited = true,
    this.effectiveLimit,
    this.period = 'monthly',
    this.sentToday = 0,
    this.sentMonth = 0,
    this.remaining = 999,
    this.limitAction = 'block_and_prompt',
  });

  factory ChatLimitStatus.fromMap(Map<String, dynamic> map) {
    return ChatLimitStatus(
      allowed: map['allowed'] as bool? ?? true,
      limitEnabled: map['limit_enabled'] as bool? ?? false,
      unlimited: map['unlimited'] as bool? ?? false,
      effectiveLimit: map['effective_limit'] as int?,
      period: map['period'] as String? ?? 'monthly',
      sentToday: map['sent_today'] as int? ?? 0,
      sentMonth: map['sent_month'] as int? ?? 0,
      remaining: map['remaining'] as int? ?? 999,
      limitAction: map['limit_action'] as String? ?? 'block_and_prompt',
    );
  }

  /// Whether the user should be prompted to upgrade.
  bool get shouldPromptUpgrade =>
      limitEnabled && !unlimited && !allowed && limitAction == 'block_and_prompt';
}

/// Repository for checking chat message rate limits.
class ChatLimitRepository {
  final SupabaseService _supabase;

  const ChatLimitRepository(this._supabase);

  /// Checks the current user's message limit status via the database RPC.
  Future<ChatLimitStatus> checkMessageLimit() async {
    try {
      final userId = _supabase.requireCurrentUserId;
      final response = await _supabase.client.rpc(
        'check_user_message_limit',
        params: {'p_user_id': userId},
      );

      if (response != null && response is Map) {
        return ChatLimitStatus.fromMap(Map<String, dynamic>.from(response));
      }
    } catch (e, stack) {
      developer.log(
        'ChatLimitRepository.checkMessageLimit notice: $e',
        error: e,
        stackTrace: stack,
      );
    }
    // Default: allow if we can't check
    return const ChatLimitStatus();
  }
}

/// Provider for [ChatLimitRepository].
final chatLimitRepositoryProvider = Provider<ChatLimitRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return ChatLimitRepository(supabase);
});

/// Provider to check current user's chat limit status.
final chatLimitStatusProvider = FutureProvider<ChatLimitStatus>((ref) async {
  final repo = ref.watch(chatLimitRepositoryProvider);
  return repo.checkMessageLimit();
});
