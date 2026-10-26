import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_locale_controller.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import '../../subscriptions/presentation/subscriptions_controller.dart';
import '../../subscriptions/presentation/subscriptions_screen.dart';
import '../../verification/presentation/identity_verification_screen.dart';
import '../domain/user_profile.dart';
import 'profile_controller.dart';
import 'screens/blocked_users_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/privacy_security_screen.dart';
import 'widgets/profile_photo_crop_dialog.dart';
import 'widgets/support_sheet.dart';

/// Production-ready User Profile and Account Management Screen.
/// Executive layout matching brand colors (Navy, Pink, OffWhite) with
/// complete settings menu, verification routing, language toggle, and avatar management.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showSignOutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Text(
          context.tr('logout'),
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          context.tr('logoutConfirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(authControllerProvider.notifier).signOut();
              } catch (_) {}
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(context.tr('logout')),
          ),
        ],
      ),
    );
  }

  void _showLanguageBottomSheet(BuildContext context, WidgetRef ref) {
    final activeLocale = ref.read(localeProvider);
    final currentLang = activeLocale.languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            SizedBox(height: 18.h),
            Text(
              sheetCtx.tr('selectLanguage'),
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16.h),
            _buildLanguageOption(
              context: sheetCtx,
              ref: ref,
              title: sheetCtx.tr('arabicEgypt'),
              code: 'ar',
              isSelected: currentLang == 'ar',
            ),
            SizedBox(height: 10.h),
            _buildLanguageOption(
              context: sheetCtx,
              ref: ref,
              title: sheetCtx.tr('englishUS'),
              code: 'en',
              isSelected: currentLang == 'en',
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String code,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.pop(context);
        await ref.read(profileControllerProvider.notifier).setLanguage(code);
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              code == 'ar'
                  ? AppTranslations.tr('langSetArabic', localeCode: 'ar')
                  : AppTranslations.tr('langSetEnglish', localeCode: 'en'),
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );
      },
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightPink.withValues(alpha: 0.3) : AppColors.offWhite,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected ? AppColors.secondaryPink : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryNavy : AppColors.textPrimary,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.secondaryPink,
              ),
          ],
        ),
      ),
    );
  }

  void _showPhotoOptionsSheet(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            SizedBox(height: 18.h),
            Text(
              context.tr('changeProfilePhoto'),
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryNavy,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 18.h),

            // 1. Choose from gallery
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: AppColors.lightPink.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primaryNavy,
                ),
              ),
              title: Text(
                context.tr('chooseFromGallery'),
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _pickAndCropImage(context, ref, ImageSource.gallery);
              },
            ),
            SizedBox(height: 6.h),

            // 2. Take with camera
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: AppColors.lightPink.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primaryNavy,
                ),
              ),
              title: Text(
                context.tr('takePhotoCamera'),
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _pickAndCropImage(context, ref, ImageSource.camera);
              },
            ),

            // 3. Delete / Remove Photo (if user has photo)
            if (profile?.photoUrl != null && profile!.photoUrl!.isNotEmpty) ...[
              SizedBox(height: 6.h),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.errorRed,
                  ),
                ),
                title: Text(
                  context.tr('removePhoto'),
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.errorRed,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final success = await ref
                      .read(profileControllerProvider.notifier)
                      .removeProfilePhoto();
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('photoRemovedSuccess')),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  }
                },
              ),
            ],
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCropImage(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );

      if (pickedFile == null) return;

      final rawBytes = await pickedFile.readAsBytes();
      if (!context.mounted) return;

      final croppedBytes = await ProfilePhotoCropDialog.show(context, rawBytes);
      if (croppedBytes == null || !context.mounted) return;

      final extension = pickedFile.name.split('.').last;
      final success = await ref
          .read(profileControllerProvider.notifier)
          .uploadProfilePhoto(croppedBytes, extension);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('photoUpdatedSuccess')),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('photoUploadError')),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final subState = ref.watch(subscriptionsControllerProvider);
    final activeLocale = ref.watch(localeProvider);

    final profile = profileState.profile;
    final isVerified = profile?.isVerified ?? false;
    final activeSub = subState.activeSubscription;
    final isSubscribed = activeSub != null && activeSub.isActive;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(context.tr('navProfile')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: context.tr('privacyAndSecurity'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacySecurityScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            children: [
              // 1. Executive Profile Header Card with Avatar and Badges
              _buildProfileHeaderCard(
                context,
                ref: ref,
                profile: profile,
                isVerified: isVerified,
                isSubscribed: isSubscribed,
                activeSub: activeSub,
              ),
              SizedBox(height: 20.h),

              // 2. Main Account Management Menu Section
              _buildMenuSection(
                title: context.tr('accountManagement'),
                items: [
                  _MenuItem(
                    icon: Icons.edit_outlined,
                    iconColor: AppColors.primaryNavy,
                    title: context.tr('editProfile'),
                    subtitle: context.tr('editProfileSub'),
                    onTap: () {
                      if (profile != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(profile: profile),
                          ),
                        );
                      }
                    },
                  ),
                  _MenuItem(
                    icon: Icons.verified_user_outlined,
                    iconColor: isVerified ? AppColors.successGreen : AppColors.secondaryPink,
                    title: context.tr('idVerification'),
                    subtitle: isVerified
                        ? context.tr('idVerificationSubVerified')
                        : context.tr('idVerificationSubUnverified'),
                    badge: isVerified ? context.tr('verified') : context.tr('requiredBadge'),
                    badgeColor: isVerified ? AppColors.successGreen : AppColors.secondaryPink,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const IdentityVerificationScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.workspace_premium_outlined,
                    iconColor: const Color(0xFFE6A100),
                    title: context.tr('currentPlan'),
                    subtitle: isSubscribed
                        ? '${activeSub.tier.titleArabic} (${activeSub.daysRemaining} days)'
                        : context.tr('currentPlanSubFree'),
                    badge: isSubscribed ? context.tr('activeSub') : context.tr('upgradeBadge'),
                    badgeColor: isSubscribed ? AppColors.primaryNavy : AppColors.secondaryPink,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionsScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.block_flipped,
                    iconColor: AppColors.errorRed,
                    title: context.tr('blockedUsers'),
                    subtitle: context.tr('blockedUsersSub'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BlockedUsersScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // 3. Settings & Privacy Section
              _buildMenuSection(
                title: context.tr('settingsSection'),
                items: [
                  _MenuItem(
                    icon: Icons.language_rounded,
                    iconColor: AppColors.primaryNavy,
                    title: context.tr('language'),
                    subtitle: activeLocale.languageCode == 'ar' ? 'العربية (مصر)' : 'English (US)',
                    onTap: () => _showLanguageBottomSheet(context, ref),
                  ),
                  _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: AppColors.primaryNavy,
                    title: context.tr('privacyAndSecurity'),
                    subtitle: context.tr('privacySecuritySub'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacySecurityScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.support_agent_rounded,
                    iconColor: AppColors.secondaryPink,
                    title: context.isArabic ? 'الدعم والمساعدة' : 'Help & Support',
                    subtitle: context.isArabic ? 'تواصل مع فريق إدارة المنصة' : 'Contact platform administration',
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const SupportSheet(),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.errorRed,
                    title: context.tr('logout'),
                    subtitle: context.tr('logoutConfirm'),
                    isDestructive: true,
                    onTap: () => _showSignOutConfirmation(context, ref),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Version and branding
              Text(
                context.tr('appVersion'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(
    BuildContext context, {
    required WidgetRef ref,
    required UserProfile? profile,
    required bool isVerified,
    required bool isSubscribed,
    required dynamic activeSub,
  }) {
    final name = profile?.fullName ?? 'أحمد محمود';
    final age = profile?.age ?? 30;
    final job = profile?.jobTitle ?? context.tr('notSpecified');
    final city = profile?.residenceCity ?? 'القاهرة';
    final photoUrl = profile?.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar + Verification Badge + Camera Edit Button
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => _showPhotoOptionsSheet(context, ref, profile),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasPhoto
                          ? AppColors.secondaryPink
                          : AppColors.primaryNavy.withValues(alpha: 0.15),
                      width: 3.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadowColor,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 48.r,
                    backgroundColor: AppColors.lightPink,
                    backgroundImage: hasPhoto
                        ? (photoUrl.startsWith('data:')
                            ? MemoryImage(base64Decode(photoUrl.split(',').last)) as ImageProvider
                            : CachedNetworkImageProvider(photoUrl))
                        : null,
                    child: !hasPhoto
                        ? Icon(
                            Icons.person_rounded,
                            size: 54.sp,
                            color: AppColors.primaryNavy,
                          )
                        : null,
                  ),
                ),
              ),

              // Verification Badge (Bottom End)
              Positioned(
                bottom: 2.h,
                right: 2.w,
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceWhite,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isVerified ? Icons.verified_rounded : Icons.pending_rounded,
                    color: isVerified ? AppColors.successGreen : AppColors.warningOrange,
                    size: 20.sp,
                  ),
                ),
              ),

              // Prominent Camera Edit Badge (Bottom Start)
              Positioned(
                bottom: 2.h,
                left: 2.w,
                child: GestureDetector(
                  onTap: () => _showPhotoOptionsSheet(context, ref, profile),
                  child: Container(
                    padding: EdgeInsets.all(7.r),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryPink,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceWhite, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadowColor,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.surfaceWhite,
                      size: 16.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Explicit Action Button to Change or Upload Profile Photo
          InkWell(
            onTap: () => _showPhotoOptionsSheet(context, ref, profile),
            borderRadius: BorderRadius.circular(20.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.lightPink.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: AppColors.secondaryPink.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasPhoto ? Icons.edit_rounded : Icons.add_a_photo_rounded,
                    size: 15.sp,
                    color: AppColors.primaryNavy,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    hasPhoto
                        ? context.tr('changeProfilePhoto')
                        : context.tr('uploadProfilePhotoBtn'),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // User Name
          Text(
            name,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryNavy,
            ),
          ),
          SizedBox(height: 4.h),

          // Subtitle (Age, Job, City)
          Text(
            '$age ${context.tr('yearsOld')} • $job • $city',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 14.h),

          // Verification Status & Subscription Pills Row
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            alignment: WrapAlignment.center,
            children: [
              // Verification Pill
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isVerified
                      ? AppColors.successGreen.withValues(alpha: 0.12)
                      : AppColors.warningOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isVerified
                        ? AppColors.successGreen.withValues(alpha: 0.3)
                        : AppColors.warningOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVerified ? Icons.verified_user_rounded : Icons.shield_outlined,
                      color: isVerified ? AppColors.successGreen : AppColors.warningOrange,
                      size: 14.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      isVerified ? context.tr('verified') : context.tr('unverified'),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isVerified ? AppColors.successGreen : AppColors.warningOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Subscription Pill
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isSubscribed
                      ? AppColors.primaryNavy.withValues(alpha: 0.08)
                      : AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isSubscribed
                        ? AppColors.primaryNavy.withValues(alpha: 0.2)
                        : AppColors.borderSubtle,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: isSubscribed ? AppColors.primaryNavy : AppColors.textSecondary,
                      size: 14.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      isSubscribed ? context.tr('activeSub') : context.tr('freeTier'),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isSubscribed ? AppColors.primaryNavy : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          child: Text(
            title,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 6.h),
        Material(
          color: AppColors.surfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 56,
              color: AppColors.borderSubtle,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                onTap: item.onTap,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: item.isDestructive
                        ? AppColors.errorRed.withValues(alpha: 0.1)
                        : AppColors.lightPink.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.iconColor,
                    size: 22.sp,
                  ),
                ),
                title: Text(
                  item.title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: item.isDestructive ? AppColors.errorRed : AppColors.primaryNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: item.subtitle != null
                    ? Text(
                        item.subtitle!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11.sp,
                        ),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.badge != null) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: item.badgeColor ?? AppColors.secondaryPink,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          item.badge!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.surfaceWhite,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],
                    Icon(
                      context.isArabic
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20.sp,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.isDestructive = false,
    required this.onTap,
  });
}
