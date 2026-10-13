import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/presentation/login_screen.dart';
import '../profile_controller.dart';

/// Screen displaying matrimonial platform privacy guidelines, terms of service,
/// data security commitments, and permanent account deletion controls.
class PrivacySecurityScreen extends ConsumerWidget {
  const PrivacySecurityScreen({super.key});

  void _showDeleteAccountConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.errorRed,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                context.tr('deleteAccountFinal'),
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.errorRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('deleteAccountWarningTitle'),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              context.tr('deleteAccountConsequences'),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 8.h),
            _bulletItem(context.tr('deleteConsequence1')),
            _bulletItem(context.tr('deleteConsequence2')),
            _bulletItem(context.tr('deleteConsequence3')),
            _bulletItem(context.tr('deleteConsequence4')),
            _bulletItem(
              context.isArabic
                  ? 'إنهاء اشتراكك الحالي فوراً بلا إمكانية استرداد'
                  : 'Immediately terminate your current subscription with no refund',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.isArabic ? 'إلغاء والتراجع' : 'Cancel & Go Back'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await ref
                  .read(profileControllerProvider.notifier)
                  .deleteAccount();

              if (context.mounted && success) {
                // Navigate to Login and clear backstack
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              context.isArabic ? 'نعم، احذف حسابي نهائياً' : 'Yes, Delete My Account',
            ),
          ),
        ],
      ),
    );
  }

  static Widget _bulletItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AppColors.errorRed, fontSize: 14.sp)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(context.tr('privacyAndSecurity')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          children: [
            // 1. Data Security Header Card
            Container(
              padding: EdgeInsets.all(18.r),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.security_rounded,
                      color: AppColors.surfaceWhite,
                      size: 28.sp,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.isArabic
                              ? 'خصوصيتك أمانة مقدسة'
                              : 'Your Privacy is a Sacred Trust',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.surfaceWhite,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          context.isArabic
                              ? 'بياناتك مشفرة بالكامل ولا يتم مشاركتها مع أي جهة خارجية أو استخدامها في الإعلانات.'
                              : 'Your data is fully encrypted and never shared with third parties or used for advertisements.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.surfaceWhite.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // 2. Terms of Service Tile
            _buildExpandablePolicy(
              title: context.isArabic
                  ? 'شروط الخدمة والاستخدام الشرعي'
                  : 'Terms of Service & Ethical Use',
              icon: Icons.gavel_rounded,
              content: context.isArabic
                  ? 'منصة "جوزيني يا ماما" مخصصة حصراً للزواج الشرعي الجاد والمعلن وفق الضوابط الأخلاقية والدينية.\n\n'
                      '• يُحظر تماماً استخدام المنصة لأي أغراض تعارف غير جادة أو صداقة أو تسلية.\n'
                      '• يجب إدخال بيانات صحيحة ومطابقة للهوية الوطنية الرسمية.\n'
                      '• يحق لإدارة المنصة حظر أي حساب يخالف شروط الآداب العامة دون سابق إنذار.\n'
                      '• يجب الحفاظ على سرية التواصل واحترام خصوصية العائلات المشاركة.'
                  : 'The "Gawezeny Ya Mama" platform is dedicated exclusively to serious, declared matrimonial intentions in accordance with ethical and cultural values.\n\n'
                      '• Using the platform for dating, casual friendship, or entertainment is strictly prohibited.\n'
                      '• All personal data entered must be truthful and match official national ID.\n'
                      '• Management reserves the right to ban any account violating community standards without prior notice.\n'
                      '• Members must respect mutual confidentiality and the privacy of participating families.',
            ),
            SizedBox(height: 12.h),

            // 3. Privacy Policy Tile
            _buildExpandablePolicy(
              title: context.isArabic
                  ? 'سياسة الخصوصية وسرية البيانات'
                  : 'Privacy Policy & Data Confidentiality',
              icon: Icons.privacy_tip_outlined,
              content: context.isArabic
                  ? 'نلتزم بأعلى معايير الأمان وحماية البيانات الشخصية وفق القوانين المنظمة:\n\n'
                      '• صور بطاقات الرقم القومي تُستخدم فقط للتحقق الآلي المشفر ولا يتم عرضها لأي مستخدم آخر نهائياً.\n'
                      '• يتم إخفاء أرقام الهواتف ووسائل التواصل المباشرة حتى حدوث التوافق والموافقة المتبادلة.\n'
                      '• التشفير التام (End-to-End Encryption) للرسائل بين الطرفين لضمان سرية الحوار العائلي.\n'
                      '• للمستخدم الحق الكامل في حذف حسابه وكافة بياناته نهائياً في أي وقت.'
                  : 'We adhere to the highest standards of security and personal data protection:\n\n'
                      '• National ID card photos are strictly used for encrypted automated verification and never shown to any other user.\n'
                      '• Phone numbers and direct contact details remain hidden until mutual match approval.\n'
                      '• End-to-end message encryption ensures strict family chat confidentiality.\n'
                      '• Users retain full rights to permanently delete their account and data at any time.',
            ),
            SizedBox(height: 12.h),

            // 4. Verification Standards
            _buildExpandablePolicy(
              title: context.isArabic
                  ? 'معايير توثيق الهوية بالذكاء الاصطناعي'
                  : 'AI Identity Verification Standards',
              icon: Icons.fingerprint_rounded,
              content: context.isArabic
                  ? 'نظام التوثيق الذكي يفحص بطاقة الرقم القومي المصرية ويطابق بصمة الوجه اللحظية لمنع الحسابات الوهمية أو انتحال الشخصيات، لضمان أن كل شخص تتحدث معه هو إنسان حقيقي وجاد بنسبة 100%.'
                  : 'Our intelligent verification system verifies official Egyptian National IDs and matches real-time facial biometrics to eliminate fake accounts, ensuring that every person you speak with is 100% genuine and serious.',
            ),
            SizedBox(height: 12.h),

            // 5. Screenshot & Privacy Protection Policy
            _buildExpandablePolicy(
              title: context.isArabic
                  ? 'حماية لقطات الشاشة وتسجيل الشاشة'
                  : 'Screenshot & Screen Recording Protection',
              icon: Icons.phonelink_lock_rounded,
              content: context.isArabic
                  ? 'لحماية خصوصية الصور الشخصية والبيانات العائلية وحفظ الأمان، تطبق منصة "جوزيني يا ماما" حماية مشددة على مستوى النظام تمنع التقاط لقطات الشاشة (Screenshots) أو تسجيل الفيديو داخل كافة شاشات التطبيق لضمان سرية وخصوصية تامة لكل عضو.'
                  : 'To safeguard photos and family privacy, "Gawezeny Ya Mama" enforces system-level protection against screenshots and screen recordings across the app, ensuring absolute confidentiality for every member.',
            ),
            SizedBox(height: 28.h),

            // 6. Danger Zone: Delete Account
            Container(
              padding: EdgeInsets.all(18.r),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: AppColors.errorRed.withValues(alpha: 0.3),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.cardShadowColor,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.delete_forever_rounded,
                        color: AppColors.errorRed,
                        size: 24.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          context.isArabic
                              ? 'منطقة الخطر: حذف الحساب نهائياً'
                              : 'Danger Zone: Delete Account Permanently',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.errorRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    context.isArabic
                        ? 'إذا قررت مغادرة المنصة أو وُفقت في الزواج (مبارك مقدماً!)، يمكنك حذف حسابك وجميع بياناتك نهائياً من خوادمنا بشكل فوري.'
                        : 'If you decide to leave or found your match (congratulations in advance!), you can permanently erase your account and all associated data from our servers immediately.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    height: 46.h,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.errorRed,
                        side: const BorderSide(color: AppColors.errorRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: () => _showDeleteAccountConfirmation(context, ref),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        context.isArabic
                            ? 'حذف الحساب والبيانات نهائياً'
                            : 'Permanently Delete Account & Data',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandablePolicy({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        leading: Icon(icon, color: AppColors.primaryNavy, size: 22.sp),
        title: Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14.sp,
          ),
        ),
        childrenPadding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 16.h),
        children: [
          Text(
            content,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
