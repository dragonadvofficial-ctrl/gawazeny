import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/theme/text_styles.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import 'login_screen.dart';

/// Beautiful matrimonial splash & welcome screen welcoming users to "جوزيني يا ماما".
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Column(
            children: [
              const Spacer(),

              // Logo & Brand Container
              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 190.w,
                    maxHeight: 170.h,
                  ),
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: AppColors.borderSubtle, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryNavy.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Matrimonial Brand Title
              Text(
                context.tr('appName'),
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineLarge.copyWith(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8.h),

              // Quranic Verse / Matrimonial Tagline
              Text(
                context.tr('welcomeVerse'),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                context.tr('welcomeSubtitle'),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 36.h),

              // Matrimonial Value Highlights
              _buildValuePill(
                icon: Icons.verified_user_rounded,
                title: context.tr('aiVerificationTitle'),
                subtitle: context.tr('aiVerificationSub'),
              ),
              SizedBox(height: 12.h),
              _buildValuePill(
                icon: Icons.favorite_border_rounded,
                title: context.tr('smartMatchTitle'),
                subtitle: context.tr('smartMatchSub'),
              ),
              SizedBox(height: 12.h),
              _buildValuePill(
                icon: Icons.lock_outline_rounded,
                title: context.tr('fullPrivacyTitle'),
                subtitle: context.tr('fullPrivacySub'),
              ),

              const Spacer(flex: 2),

              // Action: Start Journey Now
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBurgundy,
                    foregroundColor: AppColors.surfaceWhite,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    context.tr('startJourneyNow'),
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.surfaceWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Action: Sign In
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryNavy,
                    side: BorderSide(
                      color: AppColors.primaryBurgundy,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    context.tr('signInExisting'),
                    style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValuePill({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.lightPink,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primaryBurgundy,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelMedium.copyWith(
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
        ],
      ),
    );
  }
}
