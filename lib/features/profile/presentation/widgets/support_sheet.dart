import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/support_repository.dart';

/// Provider to fetch user's support messages.
final userSupportMessagesProvider =
    FutureProvider.autoDispose<List<SupportMessage>>((ref) async {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getUserMessages();
});

/// Bottom sheet dialog allowing the user to view support tickets & send messages.
class SupportSheet extends ConsumerStatefulWidget {
  final String? initialSubject;
  final String? initialContent;

  const SupportSheet({
    super.key,
    this.initialSubject,
    this.initialContent,
  });

  @override
  ConsumerState<SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends ConsumerState<SupportSheet> {
  late final TextEditingController _subjectController;
  late final TextEditingController _contentController;
  bool _isSending = false;
  bool _showNewMessageForm = false;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.initialSubject ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    if (widget.initialSubject != null || widget.initialContent != null) {
      _showNewMessageForm = true;
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitMessage() async {
    final subject = _subjectController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isArabic
                ? 'يرجى كتابة نص الرسالة أولاً'
                : 'Please enter message content',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final repo = ref.read(supportRepositoryProvider);
    final success = await repo.sendSupportMessage(
      subject: subject.isEmpty
          ? (context.isArabic ? 'استفسار عام' : 'General Inquiry')
          : subject,
      content: content,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (success) {
      _contentController.clear();
      _subjectController.clear();
      setState(() => _showNewMessageForm = false);
      ref.invalidate(userSupportMessagesProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isArabic
                ? 'تم إرسال رسالتك بنجاح، سيقوم فريق الدعم بالرد قريباً'
                : 'Message sent successfully. Support team will reply soon.',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isArabic
                ? 'تعذر إرسال الرسالة، يرجى المحاولة لاحقاً'
                : 'Failed to send message. Please try again later.',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(userSupportMessagesProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
        20.w,
        MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ),
          SizedBox(height: 14.h),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.lightPink.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.secondaryPink,
                      size: 22.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    context.isArabic ? 'الدعم والمساعدة' : 'Help & Support',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Toggle form button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showNewMessageForm
                        ? AppColors.offWhite
                        : AppColors.secondaryPink,
                    foregroundColor: _showNewMessageForm
                        ? AppColors.primaryNavy
                        : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      side: _showNewMessageForm
                          ? const BorderSide(color: AppColors.borderSubtle)
                          : BorderSide.none,
                    ),
                  ),
                  onPressed: () {
                    setState(() => _showNewMessageForm = !_showNewMessageForm);
                  },
                  icon: Icon(
                    _showNewMessageForm
                        ? Icons.list_alt_rounded
                        : Icons.add_comment_rounded,
                    size: 18.sp,
                  ),
                  label: Text(
                    _showNewMessageForm
                        ? (context.isArabic ? 'عرض رسائلي السابقة' : 'View Past Tickets')
                        : (context.isArabic ? 'إرسال رسالة جديدة للدعم' : 'New Support Message'),
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // Content body
          Expanded(
            child: _showNewMessageForm
                ? _buildMessageForm(context)
                : _buildPastMessages(context, messagesAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageForm(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.isArabic ? 'عنوان الموضوع:' : 'Subject:',
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              hintText: context.isArabic
                  ? 'مثال: استفسار عن تفعيل باقة الدفع'
                  : 'e.g. Payment activation inquiry',
              filled: true,
              fillColor: AppColors.offWhite,
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
            ),
          ),
          SizedBox(height: 12.h),

          Text(
            context.isArabic ? 'تفاصيل الرسالة:' : 'Message Content:',
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: context.isArabic
                  ? 'اكتب استفسارك أو مشكلتك بالتفصيل وسيتم الرد من إدارة المنصة...'
                  : 'Write your question or details here...',
              filled: true,
              fillColor: AppColors.offWhite,
              contentPadding: EdgeInsets.all(14.r),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          SizedBox(
            height: 48.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              onPressed: _isSending ? null : _submitMessage,
              child: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      context.isArabic ? 'إرسال الرسالة' : 'Send Message',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastMessages(
    BuildContext context,
    AsyncValue<List<SupportMessage>> messagesAsync,
  ) {
    return messagesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.secondaryPink),
      ),
      error: (e, _) => Center(
        child: Text(
          context.isArabic
              ? 'تعذر تحميل رسائل الدعم'
              : 'Failed to load support messages',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
      ),
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_chat_read_outlined,
                  size: 48.sp,
                  color: AppColors.borderSubtle,
                ),
                SizedBox(height: 8.h),
                Text(
                  context.isArabic
                      ? 'لا توجد رسائل دعم سابقة'
                      : 'No previous support messages',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  context.isArabic
                      ? 'يمكنك بدء محادثة بالضغط على الزر أعلاه'
                      : 'You can send a message using the button above',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: messages.length,
          separatorBuilder: (context, index) => SizedBox(height: 10.h),
          itemBuilder: (context, index) {
            final msg = messages[index];
            final hasReply = msg.adminReply != null && msg.adminReply!.isNotEmpty;

            return Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          msg.subject ?? (context.isArabic ? 'استفسار' : 'Inquiry'),
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: _statusBgColor(msg.status),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          context.isArabic ? msg.statusLabelAr : msg.statusLabelEn,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _statusTextColor(msg.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 10.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    msg.content,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),

                  // Admin Reply if present
                  if (hasReply) ...[
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: AppColors.lightPink.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: AppColors.secondaryPink.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 14.sp,
                                color: AppColors.secondaryPink,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                context.isArabic ? 'رد الإدارة:' : 'Admin Reply:',
                                style: AppTextStyles.labelSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondaryPink,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            msg.adminReply!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.warningOrange.withValues(alpha: 0.15);
      case 'in_progress':
        return AppColors.secondaryPink.withValues(alpha: 0.15);
      case 'closed':
        return AppColors.successGreen.withValues(alpha: 0.15);
      default:
        return AppColors.borderSubtle;
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.warningOrange;
      case 'in_progress':
        return AppColors.secondaryPink;
      case 'closed':
        return AppColors.successGreen;
      default:
        return AppColors.textSecondary;
    }
  }
}
