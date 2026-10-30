import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/network/supabase_client.dart';
import '../../profile/presentation/widgets/report_user_sheet.dart';
import '../../subscriptions/presentation/subscriptions_screen.dart';
import '../../verification/presentation/identity_verification_screen.dart';
import '../domain/chat_message.dart';
import 'chat_controller.dart';

/// Full-featured secure chat room with realtime messaging, 3-gate auth guard,
/// safety banner, bubble UI, and action menu.
class ChatRoomScreen extends ConsumerStatefulWidget {
  final Conversation conversation;

  const ChatRoomScreen({super.key, required this.conversation});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Trigger auth check + message loading after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        ref.read(chatRoomControllerProvider.notifier).initRoom(
              matchId: widget.conversation.matchId,
              partnerId: widget.conversation.partnerId,
            );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatRoomControllerProvider);
    final currentUid = ref.watch(currentUserProvider)?.id ?? '';

    // Auto-scroll when new messages arrive
    ref.listen(chatRoomControllerProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: _buildAppBar(context, state),
      body: state.isAuthChecking
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.secondaryPink),
            )
          : !state.isAllowed
              ? _UnverifiedBlockView(
                  errorCode: state.authResult?.errorCode ?? '',
                  message: state.authResult?.errorMessage ??
                      (context.isArabic ? 'تعذر فتح المحادثة' : 'Could not open chat'),
                )
              : Column(
                  children: [
                    // Safety Banner
                    _SafetyBanner(),

                    // Messages List
                    Expanded(
                      child: state.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.secondaryPink,
                              ),
                            )
                          : state.messages.isEmpty
                              ? _EmptyChatState(
                                  partnerName:
                                      widget.conversation.partnerName)
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 12.h,
                                  ),
                                  itemCount: state.messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = state.messages[index];
                                    final isMine =
                                        msg.senderId == currentUid;
                                    final showDate = index == 0 ||
                                        !_isSameDay(
                                          state.messages[index - 1].createdAt,
                                          msg.createdAt,
                                        );

                                    return Column(
                                      children: [
                                        if (showDate)
                                          _DateDivider(date: msg.createdAt),
                                        _MessageBubble(
                                          message: msg,
                                          isMine: isMine,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                    ),

                    // Error snack
                    if (state.errorMessage != null)
                      _ErrorStrip(message: state.errorMessage!),

                    // Input Bar
                    _MessageInputBar(
                      controller: _textController,
                      isSending: state.isSending,
                      onSend: () async {
                        final text = _textController.text.trim();
                        if (text.isEmpty) return;
                        _textController.clear();
                        await ref
                            .read(chatRoomControllerProvider.notifier)
                            .sendMessage(text);
                      },
                    ),
                  ],
                ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, ChatRoomState state) {
    final partner = widget.conversation;

    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: AppColors.lightPink,
            backgroundImage: partner.partnerPhotoUrl != null
                ? CachedNetworkImageProvider(partner.partnerPhotoUrl!)
                : null,
            child: partner.partnerPhotoUrl == null
                ? Icon(Icons.person_rounded,
                    color: AppColors.primaryNavy, size: 20.sp)
                : null,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      partner.partnerName,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primaryNavy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (partner.partnerIsVerified) ...[
                      SizedBox(width: 4.w),
                      Icon(Icons.verified_rounded,
                          color: AppColors.successGreen, size: 14.sp),
                    ],
                  ],
                ),
                Text(
                  partner.partnerIsVerified
                      ? (context.isArabic ? 'موثّق الهوية ✓' : 'ID Verified ✓')
                      : (context.isArabic ? 'غير موثّق' : 'Unverified'),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: partner.partnerIsVerified
                        ? AppColors.successGreen
                        : AppColors.errorRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r)),
          onSelected: (value) => _handleMenuAction(context, value),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      color: AppColors.primaryNavy),
                  SizedBox(width: 8.w),
                  Text(context.isArabic ? 'عرض الملف الشخصي' : 'View Profile'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  const Icon(Icons.block_rounded, color: AppColors.errorRed),
                  SizedBox(width: 8.w),
                  Text(context.isArabic ? 'حظر المستخدم' : 'Block User'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined,
                      color: AppColors.warningOrange),
                  SizedBox(width: 8.w),
                  Text(context.isArabic ? 'إبلاغ' : 'Report'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, String value) {
    switch (value) {
      case 'profile':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.isArabic
                  ? 'عرض ملف ${widget.conversation.partnerName} الشخصي'
                  : 'Viewing ${widget.conversation.partnerName}\'s profile',
            ),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      case 'block':
        _showBlockConfirmDialog(context);
      case 'report':
        _showReportDialog(context);
    }
  }

  void _showBlockConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          context.isArabic
              ? 'حظر ${widget.conversation.partnerName}؟'
              : 'Block ${widget.conversation.partnerName}?',
          style: AppTextStyles.titleLarge
              .copyWith(color: AppColors.primaryNavy),
        ),
        content: Text(
          context.isArabic
              ? 'لن تتمكن من رؤية هذا المستخدم في الاقتراحات أو مراسلته. هل تريد المتابعة؟'
              : 'You will no longer see this user in recommendations or message them. Continue?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.isArabic
                        ? 'تم حظر المستخدم بنجاح'
                        : 'User blocked successfully',
                  ),
                  backgroundColor: AppColors.errorRed,
                ),
              );
            },
            child: Text(context.isArabic ? 'حظر' : 'Block'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    ReportUserSheet.show(
      context,
      reportedUserId: widget.conversation.partnerId,
      reportedUserName: widget.conversation.partnerName,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ============================================================================
// SAFETY BANNER
// ============================================================================
class _SafetyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: const BoxDecoration(
        color: AppColors.lightPink,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined,
              color: AppColors.secondaryPink, size: 14.sp),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              context.tr('chatRulesNotice'),
              style: TextStyle(
                fontSize: 10.5.sp,
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MESSAGE BUBBLE
// ============================================================================
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) SizedBox(width: 40.w),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: EdgeInsets.symmetric(
                  horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isMine
                    ? AppColors.primaryNavy
                    : AppColors.surfaceWhite,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18.r),
                  topRight: Radius.circular(18.r),
                  bottomLeft: isMine
                      ? Radius.circular(18.r)
                      : Radius.circular(4.r),
                  bottomRight: isMine
                      ? Radius.circular(4.r)
                      : Radius.circular(18.r),
                ),
                border: isMine
                    ? null
                    : Border.all(color: AppColors.borderSubtle),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.cardShadowColor,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isMine
                          ? AppColors.surfaceWhite
                          : AppColors.textPrimary,
                      height: 1.4,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.timeLabel,
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: isMine
                              ? AppColors.surfaceWhite.withValues(alpha: 0.65)
                              : AppColors.textMuted,
                        ),
                      ),
                      if (isMine) ...[
                        SizedBox(width: 3.w),
                        _StatusIcon(status: message.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMine) SizedBox(width: 40.w),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      MessageStatus.sending => SizedBox(
          width: 10.r,
          height: 10.r,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.surfaceWhite.withValues(alpha: 0.7),
          ),
        ),
      MessageStatus.sent => Icon(Icons.check_rounded,
          size: 11.sp,
          color: AppColors.surfaceWhite.withValues(alpha: 0.7)),
      MessageStatus.read => Icon(Icons.done_all_rounded,
          size: 11.sp, color: AppColors.infoBlue),
    };
  }
}

// ============================================================================
// DATE DIVIDER
// ============================================================================
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String get _label {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'اليوم';
    if (diff.inDays == 1) return 'أمس';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        children: [
          Expanded(
              child: Divider(color: AppColors.borderSubtle, height: 1.h)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                _label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          Expanded(
              child: Divider(color: AppColors.borderSubtle, height: 1.h)),
        ],
      ),
    );
  }
}

// ============================================================================
// MESSAGE INPUT BAR
// ============================================================================
class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Send button on the right (RTL: visually left)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: AppColors.secondaryPink,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: isSending ? null : onSend,
                  child: Padding(
                    padding: EdgeInsets.all(10.r),
                    child: isSending
                        ? SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: const CircularProgressIndicator(
                              color: AppColors.surfaceWhite,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: AppColors.surfaceWhite,
                            size: 20.sp,
                          ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),

            // Text field
            Expanded(
              child: TextField(
                controller: controller,
                textDirection:
                    context.isArabic ? TextDirection.rtl : TextDirection.ltr,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: context.tr('typeMessage'),
                  hintStyle: AppTextStyles.bodyMedium,
                  filled: true,
                  fillColor: AppColors.offWhite,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 10.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22.r),
                    borderSide:
                        const BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22.r),
                    borderSide:
                        const BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22.r),
                    borderSide: const BorderSide(
                        color: AppColors.primaryNavy, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY CHAT STATE (first message prompt)
// ============================================================================
class _EmptyChatState extends StatelessWidget {
  final String partnerName;
  const _EmptyChatState({required this.partnerName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(22.r),
              decoration: const BoxDecoration(
                color: AppColors.lightPink,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.waving_hand_rounded,
                  color: AppColors.secondaryPink, size: 40.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              context.isArabic
                  ? 'ابدأ محادثة مع $partnerName'
                  : 'Start a chat with $partnerName',
              style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              context.isArabic
                  ? 'قل السلام وابدأ التعارف الجاد بنية الزواج الصالح'
                  : 'Say hello and start a serious matrimonial conversation',
              style: AppTextStyles.bodyMedium
                  .copyWith(height: 1.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UNVERIFIED BLOCK VIEW — shown when chat guard rejects access
// ============================================================================
class _UnverifiedBlockView extends StatelessWidget {
  final String errorCode;
  final String message;

  const _UnverifiedBlockView({
    required this.errorCode,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnVerification = errorCode == 'NOT_VERIFIED';
    final isBlocked = errorCode == 'BLOCKED';
    final isNoMatch = errorCode == 'NO_MATCH';

    final IconData icon;
    final Color color;
    final String title;

    if (isBlocked) {
      icon = Icons.block_rounded;
      color = AppColors.errorRed;
      title = context.isArabic ? 'تعذر فتح المحادثة' : 'Could not open chat';
    } else if (isNoMatch) {
      icon = Icons.handshake_outlined;
      color = AppColors.warningOrange;
      title = context.isArabic ? 'لا يوجد توافق نشط' : 'No active match';
    } else {
      icon = Icons.verified_user_outlined;
      color = AppColors.warningOrange;
      title = context.isArabic ? 'التوثيق مطلوب' : 'Verification required';
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(26.r),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.5),
              ),
              child: Icon(icon, color: color, size: 50.sp),
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Text(
                message,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textPrimary, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 28.h),

            if (isOwnVerification) ...[
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.verified_user_rounded),
                  label: Text(
                    context.isArabic ? 'توثيق الهوية أولاً' : 'Verify ID First',
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const IdentityVerificationScreen(),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 12.h),
            ],

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.tr('back'),
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR STRIP — shown at bottom above input when send fails
// ============================================================================
class _ErrorStrip extends StatelessWidget {
  final String message;
  const _ErrorStrip({required this.message});

  @override
  Widget build(BuildContext context) {
    final isLimitError = message.contains('استنفدت') || message.contains('الحد الأقصى');
    final isModerationError = message.contains('غير مسموح') || message.contains('أرقام الهواتف') || message.contains('الروابط') || message.contains('التواصل');

    final color = isModerationError ? AppColors.warningOrange : AppColors.errorRed;
    final icon = isModerationError ? Icons.shield_rounded : Icons.warning_rounded;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelSmall.copyWith(
                color: color == AppColors.warningOrange ? AppColors.primaryNavy : color,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          if (isLimitError) ...[
            SizedBox(width: 8.w),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.secondaryPink,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
                );
              },
              child: Text(
                context.isArabic ? 'ترقية الباقة' : 'Upgrade',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
