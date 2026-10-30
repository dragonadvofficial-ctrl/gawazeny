import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';

/// Model holding the user's current message usage and dynamic limits.
class ChatLimitStatus {
  final bool allowed;
  final bool limitEnabled;
  final bool unlimited;
  final int? effectiveLimit;
  final String period;
  final int sentCount;
  final int sentToday;
  final int sentMonth;
  final int remaining;
  final String userType;
  final String planName;
  final String limitAction;

  const ChatLimitStatus({
    this.allowed = true,
    this.limitEnabled = false,
    this.unlimited = true,
    this.effectiveLimit,
    this.period = 'monthly',
    this.sentCount = 0,
    this.sentToday = 0,
    this.sentMonth = 0,
    this.remaining = 999,
    this.userType = 'free',
    this.planName = 'مستخدم عادي (مجاني)',
    this.limitAction = 'block_and_prompt',
  });

  factory ChatLimitStatus.fromMap(Map<String, dynamic> map) {
    final sentCnt = map['sent_count'] as int? ??
        (map['period'] == 'daily'
            ? (map['sent_today'] as int? ?? 0)
            : (map['sent_month'] as int? ?? 0));

    return ChatLimitStatus(
      allowed: map['allowed'] as bool? ?? true,
      limitEnabled: map['limit_enabled'] as bool? ?? false,
      unlimited: map['unlimited'] as bool? ?? false,
      effectiveLimit: map['effective_limit'] as int?,
      period: map['period'] as String? ?? 'monthly',
      sentCount: sentCnt,
      sentToday: map['sent_today'] as int? ?? sentCnt,
      sentMonth: map['sent_month'] as int? ?? sentCnt,
      remaining: map['remaining'] as int? ?? 999,
      userType: map['user_type'] as String? ?? 'free',
      planName: map['plan_name'] as String? ?? 'مستخدم عادي (مجاني)',
      limitAction: map['limit_action'] as String? ?? 'block_and_prompt',
    );
  }

  /// Whether the user should be prompted to upgrade or subscribe.
  bool get shouldPromptUpgrade =>
      limitEnabled && !unlimited && !allowed && limitAction == 'block_and_prompt';

  /// Readable period label in Arabic.
  String get periodLabelArabic {
    switch (period) {
      case 'daily':
        return 'اليومي';
      case 'total':
        return 'الإجمالي';
      case 'per_subscription':
        return 'خلال فترة الاشتراك';
      case 'monthly':
      default:
        return 'الشهري';
    }
  }
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
