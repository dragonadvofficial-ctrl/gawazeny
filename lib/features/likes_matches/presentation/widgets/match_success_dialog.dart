import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../chat/presentation/chat_inbox_screen.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../verification/presentation/identity_verification_screen.dart';

/// Celebratory Matrimonial Match Dialog displayed immediately when a mutual like is formed.
class MatchSuccessDialog extends ConsumerWidget {
  final UserProfile partnerProfile;
  final String? partnerPhotoUrl;
  final String? currentUserPhotoUrl;
  final VoidCallback? onDismiss;

  const MatchSuccessDialog({
    super.key,
    required this.partnerProfile,
    this.partnerPhotoUrl,
    this.currentUserPhotoUrl,
    this.onDismiss,
  });

  /// Static helper to display the dialog with smooth modal animation.
  static Future<void> show(
    BuildContext context, {
    required UserProfile partnerProfile,
    String? partnerPhotoUrl,
    String? currentUserPhotoUrl,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق نافذة التوافق',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) => MatchSuccessDialog(
        partnerProfile: partnerProfile,
        partnerPhotoUrl: partnerPhotoUrl,
        currentUserPhotoUrl: currentUserPhotoUrl,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: const [
            BoxShadow(
              color: Color(0x330F2D5B),
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Floating Decorative Header Badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.lightPink,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: AppColors.secondaryPink.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '💍',
                    style: TextStyle(fontSize: 18.sp),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'مبروك! حصل توافق بنية الزواج',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.secondaryPink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Dual Avatars with Heart Connector
            SizedBox(
              height: 100.h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Right Avatar: Current User
                      _buildAvatar(
                        imageUrl: currentUserPhotoUrl,
                        fallbackIcon: Icons.person_rounded,
                        borderColor: AppColors.primaryNavy,
                      ),
                      SizedBox(width: 48.w),
                      // Left Avatar: Matched Partner
                      _buildAvatar(
                        imageUrl: partnerPhotoUrl,
                        fallbackIcon: Icons.favorite_rounded,
                        borderColor: AppColors.secondaryPink,
                      ),
                    ],
                  ),

                  // Center Linking Heart with Glow
                  Container(
                    width: 46.r,
                    height: 46.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.pinkGradient,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55E94B7A),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.favorite_rounded,
                        color: AppColors.surfaceWhite,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),

            // Partner Headline
            Text(
              partnerProfile.fullName,
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Text(
              '${partnerProfile.age ?? 25} سنة • ${partnerProfile.residenceCity}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),

            // Marriage Intention Copy
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                'الطرفان أبديا اهتماماً جاداً. الخطوة التالية هي التأكد من التوثيق بالهوية لبدء المحادثة الآمنة.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // Action 1: Proceed to ID Verification or Chat
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.pinkGradient,
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33E94B7A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();

                    // Check if current user has verified identity via metadata
                    final isUserVerified = currentUser?.appMetadata['is_verified'] == true;

                    if (isUserVerified) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChatInboxScreen(),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const IdentityVerificationScreen(),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'بدء التوثيق / المحادثة',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.surfaceWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),

            // Action 2: Continue Browsing
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
              child: Text(
                'متابعة التصفح',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({
    required String? imageUrl,
    required IconData fallbackIcon,
    required Color borderColor,
  }) {
    return Container(
      width: 76.r,
      height: 76.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.lightPink,
                  child: Center(
                    child: SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.lightPink,
                  child: Icon(fallbackIcon, color: borderColor, size: 36.sp),
                ),
              )
            : Container(
                color: AppColors.lightPink,
                child: Icon(fallbackIcon, color: borderColor, size: 36.sp),
              ),
      ),
    );
  }
}
