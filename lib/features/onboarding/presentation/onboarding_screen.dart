import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/text_styles.dart';
import 'onboarding_controller.dart';
import 'widgets/step1_basics.dart';
import 'widgets/step2_professional.dart';
import 'widgets/step3_lifestyle.dart';
import 'widgets/step4_preferences.dart';
import 'widgets/step5_photo.dart';

/// Multi-step onboarding wizard for serious marriage profile completion.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  String _getStepTitle(BuildContext context, int step) {
    switch (step) {
      case 0:
        return context.tr('basicData');
      case 1:
        return context.tr('educationAndWork');
      case 2:
        return context.tr('lifestyleValues');
      case 3:
        return context.tr('partnerPreferences');
      case 4:
      default:
        return context.tr('profilePhotoStep');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final currentUser = ref.watch(currentUserProvider);

    final currentStep = state.currentStep;
    final progress = (currentStep + 1) / 5.0;

    void handleNext() {
      // Validate active step
      if (currentStep == 0 && !state.isStep1Valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('step1Validation')),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }
      if (currentStep == 1 && !state.isStep2Valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('step2Validation')),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }
      if (currentStep == 2 && !state.isStep3Valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('step3Validation')),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }
      if (currentStep == 3 && !state.isStep4Valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('step4Validation')),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      controller.nextStep();
    }

    Future<void> handleSubmit() async {
      final userId = currentUser?.id ?? ref.read(supabaseServiceProvider).client.auth.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('errorAuthRequired')),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      final success = await controller.submitOnboarding(userId);

      if (!success && context.mounted) {
        final error = state.errorMessage ?? context.tr('errorGeneric');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(
          context.tr('onboardingTitle'),
          style: AppTextStyles.titleLarge,
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Center(
              child: Text(
                context.isArabic
                    ? 'الخطوة ${currentStep + 1} من 5'
                    : 'Step ${currentStep + 1} of 5',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.secondaryPink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Animated Progress Indicator Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getStepTitle(context, currentStep),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.r),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      tween: Tween<double>(begin: 0.0, end: progress),
                      builder: (context, val, _) {
                        return LinearProgressIndicator(
                          value: val,
                          minHeight: 7.h,
                          backgroundColor: AppColors.lightPink,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.secondaryPink,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Step Content
            Expanded(
              child: _buildStep(currentStep),
            ),

            // Bottom Sticky Navigation Action Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderSubtle,
                    width: 1.0,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadowColor,
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (currentStep > 0) ...[
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: state.isSubmitting ? null : controller.previousStep,
                        child: Text(context.tr('back')),
                      ),
                    ),
                    SizedBox(width: 12.w),
                  ],
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: state.isSubmitting
                          ? null
                          : (currentStep == 4 ? handleSubmit : handleNext),
                      child: state.isSubmitting
                          ? SizedBox(
                              width: 22.r,
                              height: 22.r,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.surfaceWhite,
                              ),
                            )
                          : Text(
                              currentStep == 4
                                  ? context.tr('completeProfileStartMatch')
                                  : context.tr('proceedNextStep'),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return const Step1BasicsWidget();
      case 1:
        return const Step2ProfessionalWidget();
      case 2:
        return const Step3LifestyleWidget();
      case 3:
        return const Step4PreferencesWidget();
      case 4:
      default:
        return const Step5PhotoWidget();
    }
  }
}
