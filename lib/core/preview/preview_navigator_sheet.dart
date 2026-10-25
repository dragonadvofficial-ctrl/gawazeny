import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../theme/text_styles.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/chat/presentation/chat_controller.dart';
import '../../features/chat/presentation/chat_inbox_screen.dart';
import '../../features/chat/presentation/chat_room_screen.dart';
import '../../features/likes_matches/presentation/matches_screen.dart';
import '../../features/likes_matches/presentation/widgets/match_success_dialog.dart';
import '../../features/matching/domain/matching_filters.dart';
import '../../features/matching/presentation/matching_screen.dart';
import '../../features/matching/presentation/widgets/profile_details_sheet.dart';
import '../../features/matching/presentation/widgets/search_filter_sheet.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_controller.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/screens/blocked_users_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/privacy_security_screen.dart';
import '../../features/profile/domain/user_profile.dart';
import '../../features/subscriptions/presentation/subscriptions_screen.dart';
import '../../features/verification/presentation/identity_verification_screen.dart';
import '../../features/verification/presentation/verification_controller.dart';
import 'preview_mock_data.dart';

/// Modal bottom sheet listing all 16 screens, interactive dialogs, and verification states
/// for rapid visual QA, client presentation, and screenshots.
class PreviewNavigatorSheet extends ConsumerWidget {
  const PreviewNavigatorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PreviewNavigatorSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.offWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            children: [
              // Sheet Handle Bar
              SizedBox(height: 12.h),
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

              // Title Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: AppColors.lightPink,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.dashboard_customize_rounded,
                        color: AppColors.primaryBurgundy,
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لوحة التنقل السريع والمعاينة 📱',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'استعرض جميع شاشات «جوزيني يا ماما» فوراً',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Screen Items List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                  children: [
                    // ========================================================
                    // 1. REGISTRATION & ONBOARDING
                    // ========================================================
                    _buildSectionHeader('1. التسجيل والدخول والتهيئة', Icons.login_rounded),
                    _buildItemCard(
                      context,
                      number: '1',
                      title: 'شاشة البداية والترحيب (Welcome / Splash)',
                      subtitle: '«ابدأ رحلتك الآن» وقيم المنصة الشرعية الجادة',
                      icon: Icons.celebration_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '2',
                      title: 'تسجيل الدخول وإنشاء حساب (Login / Register)',
                      subtitle: 'التبديل التفاعلي بين الدخول والحساب الجديد',
                      icon: Icons.account_circle_outlined,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '3',
                      title: 'خطوات إكمال الملف الشخصي الـ 5 (Onboarding)',
                      subtitle: 'معالج التسجيل: الأساسيات، العمل، نمط الحياة، الشريك، والصورة',
                      icon: Icons.format_list_numbered_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                        );
                      },
                    ),

                    // ========================================================
                    // 2. DISCOVERY & MATCHING FEED
                    // ========================================================
                    _buildSectionHeader('2. الاستكشاف والتوافق الذكي', Icons.favorite_rounded),
                    _buildItemCard(
                      context,
                      number: '4',
                      title: 'الرئيسية: بطاقات التوافق (Matching Feed)',
                      subtitle: 'بطاقات سارة محمود ومريم خليل ونور الهدى مع نسب التوافق',
                      icon: Icons.style_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MatchingScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '5',
                      title: 'تفاصيل الملف الشخصي (Profile Details Sheet)',
                      subtitle: 'البيانات الكاملة لسارة محمود مع الالتزام والمواصفات',
                      icon: Icons.badge_outlined,
                      onTap: () {
                        Navigator.of(context).pop();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ProfileDetailsSheet(
                            scoredCandidate: PreviewMockData.recommendedProfiles[0],
                            onLike: () => Navigator.of(context).pop(),
                            onPass: () => Navigator.of(context).pop(),
                          ),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '6',
                      title: 'فلاتر البحث المتقدمة (Filter Modal Sheet)',
                      subtitle: 'تصفية العمر، المدينة، الالتزام، والحالة الاجتماعية',
                      icon: Icons.tune_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => SearchFilterSheet(
                            initialFilters: const MatchingFilters(),
                            onApply: (_) => Navigator.of(context).pop(),
                          ),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '7',
                      title: 'ديالوج التوافق الاحتفالي (Match Success Dialog)',
                      subtitle: '«مبروك! حصل توافق بنية الزواج 💍» مع الصورتين',
                      icon: Icons.auto_awesome_rounded,
                      badgeColor: AppColors.primaryBurgundy,
                      onTap: () {
                        Navigator.of(context).pop();
                        MatchSuccessDialog.show(
                          context,
                          partnerProfile: PreviewMockData.recommendedProfiles[0].profile,
                          partnerPhotoUrl: PreviewMockData.recommendedProfiles[0].primaryPhotoUrl,
                          currentUserPhotoUrl: PreviewMockData.currentUserPhotoUrl,
                        );
                      },
                    ),

                    // ========================================================
                    // 3. MUTUAL MATCHES & LIKES
                    // ========================================================
                    _buildSectionHeader('3. التوافقات والإعجابات المتبادلة', Icons.people_alt_rounded),
                    _buildItemCard(
                      context,
                      number: '8',
                      title: 'شاشة التوافقات والإعجابات (Matches Tabs)',
                      subtitle: 'التبويبات الثلاثة: التوافقات (3)، الواردة (3)، والمرسلة (2)',
                      icon: Icons.connect_without_contact_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MatchesScreen()),
                        );
                      },
                    ),

                    // ========================================================
                    // 4. IDENTITY VERIFICATION (MANUAL ADMIN REVIEW)
                    // ========================================================
                    _buildSectionHeader('4. توثيق الحساب (مراجعة الإدارة)', Icons.verified_user_rounded),
                    _buildItemCard(
                      context,
                      number: '9a',
                      title: 'توثيق الحساب: خطوة رفع البطاقة (ID Upload)',
                      subtitle: 'إرشادات التقاط صورة بطاقة الرقم القومي المصرية بوضوح',
                      icon: Icons.credit_card_rounded,
                      onTap: () {
                        ref.read(verificationControllerProvider.notifier).setStepForPreview(
                              VerificationStep.idCard,
                            );
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '9b',
                      title: 'توثيق الحساب: خطوة الصورة الشخصية (Photo Step)',
                      subtitle: 'التقاط الصورة الشخصية الحديثة للمطابقة اليدوية من الإدارة',
                      icon: Icons.camera_alt_outlined,
                      onTap: () {
                        ref.read(verificationControllerProvider.notifier).setStepForPreview(
                              VerificationStep.selfie,
                            );
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '9c',
                      title: 'توثيق الحساب: قيد المراجعة الإدارية (PENDING)',
                      subtitle: '«تم استلام طلب توثيق حسابك بنجاح. برجاء الانتظار، سيتم مراجعة طلبك خلال 15 دقيقة.»',
                      icon: Icons.hourglass_top_rounded,
                      badgeColor: AppColors.warningOrange,
                      onTap: () {
                        ref.read(verificationControllerProvider.notifier).setResultForPreview(
                              status: VerificationStatusType.pending,
                              registeredName: 'أحمد محمود القاضي',
                            );
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '9d',
                      title: 'توثيق الحساب: تم التوثيق والاعتماد (VERIFIED)',
                      subtitle: '«تم توثيق حسابك بنجاح! ✅» مع شارة التوثيق والاسم المسجل',
                      icon: Icons.check_circle_outline_rounded,
                      badgeColor: AppColors.successGreen,
                      onTap: () {
                        ref.read(verificationControllerProvider.notifier).setResultForPreview(
                              status: VerificationStatusType.verified,
                              registeredName: 'أحمد محمود القاضي',
                            );
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '9e',
                      title: 'توثيق الحساب: تم الرفض من الإدارة (REJECTED)',
                      subtitle: 'عرض سبب الرفض المحدد من قِبل الأدمن مع إمكانية إعادة التقديم',
                      icon: Icons.error_outline_rounded,
                      badgeColor: AppColors.errorRed,
                      onTap: () {
                        ref.read(verificationControllerProvider.notifier).setResultForPreview(
                              status: VerificationStatusType.failed,
                              rejectionReason: 'عدم وضوح صورة بطاقة الرقم القومي أو انتهاء صلاحيتها.',
                              registeredName: 'أحمد محمود القاضي',
                            );
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()),
                        );
                      },
                    ),

                    // ========================================================
                    // 5. CHAT & MESSAGING
                    // ========================================================
                    _buildSectionHeader('5. المحادثات والدردشة الآمنة', Icons.chat_rounded),
                    _buildItemCard(
                      context,
                      number: '10',
                      title: 'صندوق المحادثات (Chat Inbox)',
                      subtitle: 'محادثات نشطة مع سارة ومريم ود. هبة الله وعداد غير المقروء',
                      icon: Icons.mark_chat_unread_outlined,
                      onTap: () {
                        ref.read(inboxControllerProvider.notifier).loadConversations();
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChatInboxScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '11',
                      title: 'غرفة الشات المباشرة (Active Chat Room)',
                      subtitle: 'محادثة أحمد وسارة: شريط التنبيه الشرعي، الرسائل، وحالات القراءة',
                      icon: Icons.forum_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(
                              conversation: PreviewMockData.conversations[0],
                            ),
                          ),
                        );
                      },
                    ),

                    // ========================================================
                    // 6. SUBSCRIPTIONS, PROFILE & PRIVACY
                    // ========================================================
                    _buildSectionHeader('6. الاشتراكات وإدارة الحساب', Icons.settings_rounded),
                    _buildItemCard(
                      context,
                      number: '12a',
                      title: 'باقات الاشتراكات الرسمية الـ 5',
                      subtitle: '200، 500، 900، 1500 ج.م، وعرض فيسبوك 1000 ج.م مع الأسعار والمميزات',
                      icon: Icons.workspace_premium_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '12b',
                      title: 'صفحة ملخص الطلب والدفع («ادفع الآن»)',
                      subtitle: 'تفاصيل الخصم، وسيلة الدفع (إنستاباي/فودافون كاش)، وزر التأكيد',
                      icon: Icons.payment_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        SubscriptionsScreen.openCheckoutSheet(context);
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '13',
                      title: 'حسابي (Profile Overview)',
                      subtitle: 'بيانات أحمد مصطفى، شارة التوثيق، الاشتراك السنوي، وقائمة الإعدادات',
                      icon: Icons.person_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '14',
                      title: 'تعديل الملف الشخصي (Edit Profile)',
                      subtitle: 'نموذج تعديل البيانات والمواصفات الشخصية ونبذة التعارف',
                      icon: Icons.edit_note_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(
                              profile: PreviewMockData.currentProfile,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '15a',
                      title: 'المستخدمون المحظورون (قائمة ممتلئة)',
                      subtitle: 'عرض مستخدمين محظورين مع أزرار إلغاء الحظر',
                      icon: Icons.block_flipped,
                      onTap: () {
                        ref.read(profileControllerProvider.notifier).setBlockedUsersForPreview(
                              PreviewMockData.blockedUsers,
                            );
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '15b',
                      title: 'المستخدمون المحظورون (الحالة الفارغة)',
                      subtitle: '«قائمة الحظر فارغة حالياً»',
                      icon: Icons.check_box_outline_blank_rounded,
                      onTap: () {
                        ref.read(profileControllerProvider.notifier).setEmptyBlockedUsersForPreview();
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                        );
                      },
                    ),
                    _buildItemCard(
                      context,
                      number: '16',
                      title: 'الخصوصية والأمان وحذف الحساب',
                      subtitle: 'شروط الخدمة الشرعية، سياسة الخصوصية، ومودال الحذف النهائي',
                      icon: Icons.security_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 16.h, 4.w, 8.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: AppColors.primaryBurgundy),
          SizedBox(width: 8.w),
          Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context, {
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 8.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
        side: BorderSide(color: AppColors.borderSubtle.withValues(alpha: 0.8)),
      ),
      color: AppColors.surfaceWhite,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 32.r,
                height: 32.r,
                decoration: BoxDecoration(
                  color: badgeColor?.withValues(alpha: 0.12) ?? AppColors.lightPink,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: badgeColor ?? AppColors.primaryBurgundy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primaryNavy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14.sp,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
