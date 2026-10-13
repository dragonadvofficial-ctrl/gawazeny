import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/profile_repository.dart';

/// Modal bottom sheet for submitting safety reports and optionally blocking users.
class ReportUserSheet extends ConsumerStatefulWidget {
  final String reportedUserId;
  final String reportedUserName;

  const ReportUserSheet({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
  });

  /// Displays the reporting bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String reportedUserId,
    required String reportedUserName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReportUserSheet(
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
      ),
    );
  }

  @override
  ConsumerState<ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends ConsumerState<ReportUserSheet> {
  static const List<String> _presetReasons = [
    'حساب وهمي أو معلومات وبيانات غير صحيحة',
    'سلوك غير لائق أو مضايقة أو إساءة لفظية',
    'صور شخصية مضللة أو غير لائقة أو مسروقة',
    'طلب أموال أو نشاط تجاري أو اشتباه احتيال',
    'عدم الجدية في الزواج وانتهاك الشروط الشرعية',
  ];

  int _selectedReasonIndex = 0;
  late final TextEditingController _detailsController;
  bool _blockUser = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _detailsController = TextEditingController();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(profileRepositoryProvider);
      final success = await repository.reportUser(
        reportedUserId: widget.reportedUserId,
        reason: _presetReasons[_selectedReasonIndex],
        details: _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
        block: _blockUser,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      if (success) {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إرسال البلاغ حالياً، يرجى المحاولة لاحقاً'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إرسال البلاغ: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.successGreen,
            ),
            SizedBox(width: 8.w),
            Text(
              'تم استلام بلاغك',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryNavy,
              ),
            ),
          ],
        ),
        content: Text(
          'نشكرك على مساهمتك في الحفاظ على مجتمع آمن. سيقوم فريق الإشراف بمراجعة الحساب واتخاذ الإجراء المناسب بكل سرية وسرعة.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.fromLTRB(
        20.w,
        14.h,
        20.w,
        MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44.w,
                height: 4.h,
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
                        color: AppColors.errorRed.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.flag_rounded,
                        color: AppColors.errorRed,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      'إبلاغ عن ${widget.reportedUserName}',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // Confidentiality Note
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: AppColors.primaryNavy,
                    size: 20.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'بلاغك سري تماماً ولن يتم إخطار الطرف الآخر بهويتك مطلقاً.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Reasons Section
            Text(
              'اختر سبب البلاغ:',
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryNavy,
              ),
            ),
            SizedBox(height: 8.h),

            ...List.generate(_presetReasons.length, (index) {
              final isSelected = _selectedReasonIndex == index;
              return Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: InkWell(
                  onTap: () => setState(() => _selectedReasonIndex = index),
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.lightPink.withValues(alpha: 0.3)
                          : AppColors.offWhite,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.secondaryPink
                            : AppColors.borderSubtle,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected
                              ? AppColors.secondaryPink
                              : AppColors.borderSubtle,
                          size: 20.sp,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            _presetReasons[index],
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primaryNavy,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: 12.h),

            // Additional Details
            Text(
              'تفاصيل إضافية (اختياري):',
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryNavy,
              ),
            ),
            SizedBox(height: 6.h),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'صف ما حدث بالتفصيل لمساعدة الإدارة في اتخاذ القرار المناسب...',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppColors.offWhite,
                contentPadding: EdgeInsets.all(12.r),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(
                    color: AppColors.secondaryPink,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // Block User Option
            Container(
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: CheckboxListTile(
                value: _blockUser,
                onChanged: (val) => setState(() => _blockUser = val ?? true),
                title: Text(
                  'حظر هذا المستخدم وتجنب رؤيته في الاقتراحات',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryNavy,
                  ),
                ),
                activeColor: AppColors.secondaryPink,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            SizedBox(height: 16.h),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitReport,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.surfaceWhite,
                        ),
                      )
                    : Text(
                        'إرسال البلاغ للإدارة',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.surfaceWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
