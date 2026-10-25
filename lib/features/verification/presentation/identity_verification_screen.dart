import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/theme/text_styles.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/profile_controller.dart';
import 'verification_controller.dart';

/// Complete manual identity verification flow with manual admin approval.
class IdentityVerificationScreen extends ConsumerWidget {
  const IdentityVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verificationControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(
          context.isArabic ? 'توثيق الحساب بالرقم القومي' : 'Account Verification',
        ),
        leading: state.step != VerificationStep.submitting
            ? null
            : const SizedBox.shrink(),
        automaticallyImplyLeading: state.step != VerificationStep.submitting,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        child: switch (state.step) {
          VerificationStep.idCard => const _IdCardStep(key: ValueKey('id')),
          VerificationStep.selfie => const _SelfieStep(key: ValueKey('selfie')),
          VerificationStep.submitting =>
            const _SubmittingView(key: ValueKey('submitting')),
          VerificationStep.result => const _ResultView(key: ValueKey('result')),
        },
      ),
    );
  }
}

// ============================================================================
// SHARED HEADER STEPPER
// ============================================================================
class _VerificationStepper extends StatelessWidget {
  final int currentStep;

  const _VerificationStepper({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        children: [
          // Security Trust Banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.lightPink,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.secondaryPink.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.secondaryPink,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    context.isArabic
                        ? 'بياناتك مشفرة ومحمية بأعلى معايير الأمان، وتُراجع يدوياً فقط بواسطة إدارة المنصة.'
                        : 'Your data is strictly encrypted and manually reviewed by our platform administration.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryNavy,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18.h),

          // Step indicators
          Row(
            children: [
              _StepDot(
                stepNumber: 1,
                label: context.isArabic ? 'بطاقة الرقم القومي' : 'National ID',
                isActive: currentStep >= 1,
                isDone: currentStep > 1,
              ),
              Expanded(
                child: Container(
                  height: 2.h,
                  color: currentStep > 1
                      ? AppColors.secondaryPink
                      : AppColors.borderSubtle,
                ),
              ),
              _StepDot(
                stepNumber: 2,
                label: context.isArabic ? 'الصورة الشخصية' : 'Personal Photo',
                isActive: currentStep >= 2,
                isDone: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int stepNumber;
  final String label;
  final bool isActive;
  final bool isDone;

  const _StepDot({
    required this.stepNumber,
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36.r,
          height: 36.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.secondaryPink : AppColors.borderSubtle,
          ),
          child: Center(
            child: isDone
                ? Icon(
                    Icons.check_rounded,
                    color: AppColors.surfaceWhite,
                    size: 18.sp,
                  )
                : Text(
                    '$stepNumber',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isActive
                          ? AppColors.surfaceWhite
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isActive ? AppColors.secondaryPink : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STEP 1: ID CARD CAPTURE
// ============================================================================
class _IdCardStep extends ConsumerWidget {
  const _IdCardStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verificationControllerProvider);
    final controller = ref.read(verificationControllerProvider.notifier);
    final picker = ImagePicker();

    Future<void> pickImage(ImageSource source) async {
      try {
        final file = await picker.pickImage(
          source: source,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 90,
        );
        if (file != null) {
          final bytes = await file.readAsBytes();
          controller.setIdCardImage(bytes);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر الوصول للكاميرا أو المعرض: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _VerificationStepper(currentStep: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.isArabic
                      ? 'رفع صورة بطاقة الرقم القومي'
                      : 'Upload National ID Card',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  context.isArabic
                      ? 'يُرجى رفع صورة واضحة للوجه الأمامي لبطاقة الرقم القومي المصرية.'
                      : 'Please upload a clear photo of the front of your Egyptian National ID.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 20.h),

                // ID Card Preview / Upload Zone
                GestureDetector(
                  onTap: () => pickImage(ImageSource.gallery),
                  child: Container(
                    height: 200.h,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: state.hasIdCard
                            ? AppColors.successGreen
                            : AppColors.borderSubtle,
                        width: state.hasIdCard ? 2 : 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadowColor,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: state.hasIdCard
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16.r),
                                child: Image.memory(
                                  state.idCardBytes!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 10.h,
                                right: 10.w,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.successGreen,
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.surfaceWhite,
                                        size: 14.sp,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        context.isArabic ? 'تم الرفع' : 'Uploaded',
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.surfaceWhite,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56.r,
                                height: 56.r,
                                decoration: BoxDecoration(
                                  color: AppColors.lightPink,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.badge_outlined,
                                    color: AppColors.secondaryPink,
                                    size: 28.sp,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                context.isArabic
                                    ? 'اضغط لرفع صورة البطاقة'
                                    : 'Tap to upload ID Card',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.primaryNavy,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'JPG, PNG • صورة واضحة ومقروءة',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Source Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pickImage(ImageSource.gallery),
                        icon: Icon(Icons.photo_library_outlined, size: 18.sp),
                        label: Text(context.isArabic ? 'من المعرض' : 'Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          side: const BorderSide(color: AppColors.primaryNavy),
                          foregroundColor: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pickImage(ImageSource.camera),
                        icon: Icon(Icons.camera_alt_outlined, size: 18.sp),
                        label: Text(context.isArabic ? 'من الكاميرا' : 'Camera'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          side: const BorderSide(color: AppColors.primaryNavy),
                          foregroundColor: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                // Guidelines
                _GuidelinesCard(
                  guidelines: context.isArabic
                      ? const [
                          'تأكد من وضوح كافة البيانات في البطاقة بدون انعكاس للضوء',
                          'ضع البطاقة على سطح مستوٍ ومفرود أثناء التصوير',
                          'تأكد أن البطاقة سارية وغير منتهية الصلاحية',
                        ]
                      : const [
                          'Ensure all details on ID are clear and free from glare',
                          'Place card on a flat surface while capturing',
                          'Ensure National ID card is valid and unexpired',
                        ],
                ),
                SizedBox(height: 24.h),

                // Error Banner
                if (state.errorMessage != null) ...[
                  _ErrorBanner(message: state.errorMessage!),
                  SizedBox(height: 16.h),
                ],

                // Next Button
                SizedBox(
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: state.hasIdCard ? controller.proceedToSelfie : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(
                      context.isArabic ? 'التالي — الصورة الشخصية' : 'Next — Personal Photo',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.surfaceWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STEP 2: SELFIE / PERSONAL PHOTO CAPTURE
// ============================================================================
class _SelfieStep extends ConsumerWidget {
  const _SelfieStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verificationControllerProvider);
    final controller = ref.read(verificationControllerProvider.notifier);
    final picker = ImagePicker();

    Future<void> captureSelfie(ImageSource source) async {
      try {
        final file = await picker.pickImage(
          source: source,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (file != null) {
          final bytes = await file.readAsBytes();
          controller.setSelfieImage(bytes);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر الوصول للكاميرا: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _VerificationStepper(currentStep: 2),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.isArabic
                      ? 'التقاط الصورة الشخصية الحديثة'
                      : 'Take a Personal Photo',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  context.isArabic
                      ? 'يرجى التقاط صورة واضحة وحديثة لوجهك في إضاءة جيدة لمطابقتها مع صورة البطاقة من قِبل الإدارة.'
                      : 'Please take a clear, recent photo of your face in good lighting for manual admin comparison.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 20.h),

                // Selfie Preview / Frame
                Center(
                  child: GestureDetector(
                    onTap: () => captureSelfie(ImageSource.camera),
                    child: SizedBox(
                      width: 240.r,
                      height: 270.r,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceWhite,
                              borderRadius: BorderRadius.circular(24.r),
                              border: Border.all(
                                color: state.hasSelfie
                                    ? AppColors.successGreen
                                    : AppColors.borderSubtle,
                                width: state.hasSelfie ? 2 : 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.cardShadowColor,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: state.hasSelfie
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(22.r),
                                    child: Image.memory(
                                      state.selfieBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 100.r,
                                        height: 120.r,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(60.r),
                                          border: Border.all(
                                            color: AppColors.secondaryPink
                                                .withValues(alpha: 0.5),
                                            width: 2,
                                          ),
                                          color: AppColors.lightPink
                                              .withValues(alpha: 0.4),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.face_outlined,
                                            color: AppColors.secondaryPink,
                                            size: 48.sp,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 14.h),
                                      Text(
                                        context.isArabic
                                            ? 'اضغط لالتقاط صورتك'
                                            : 'Tap to take photo',
                                        style: AppTextStyles.labelMedium.copyWith(
                                          color: AppColors.primaryNavy,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          if (state.hasSelfie)
                            Positioned(
                              bottom: 12.h,
                              right: 12.w,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen,
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.surfaceWhite,
                                      size: 14.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      context.isArabic ? 'تم التقاطها' : 'Captured',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.surfaceWhite,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Source Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => captureSelfie(ImageSource.camera),
                        icon: Icon(Icons.camera_front_rounded, size: 18.sp),
                        label: Text(context.isArabic ? 'الكاميرا' : 'Camera'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          side: const BorderSide(color: AppColors.primaryNavy),
                          foregroundColor: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => captureSelfie(ImageSource.gallery),
                        icon: Icon(Icons.photo_library_outlined, size: 18.sp),
                        label: Text(context.isArabic ? 'من المعرض' : 'Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          side: const BorderSide(color: AppColors.borderSubtle),
                          foregroundColor: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),

                // Guidelines
                _GuidelinesCard(
                  guidelines: context.isArabic
                      ? const [
                          'التقط الصورة في إضاءة واضحة ومباشرة على الوجه',
                          'تجنب ارتداء نظارات شمسية أو قناع يغطي الملامح',
                          'تأكد من مطابقة ملامح الصورة مع صورة بطاقتك الشخصية',
                        ]
                      : const [
                          'Take photo in clear, direct lighting on your face',
                          'Avoid wearing sunglasses or face masks',
                          'Ensure features clearly match your National ID photo',
                        ],
                ),
                SizedBox(height: 24.h),

                // Error banner
                if (state.errorMessage != null) ...[
                  _ErrorBanner(message: state.errorMessage!),
                  SizedBox(height: 16.h),
                ],

                // Submit Button
                SizedBox(
                  height: 52.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.hasSelfie
                          ? AppColors.secondaryPink
                          : AppColors.borderSubtle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    onPressed: state.hasSelfie
                        ? () => controller.submitVerificationRequest()
                        : null,
                    child: Text(
                      context.isArabic
                          ? 'إرسال طلب التوثيق للمراجعة الإدارية'
                          : 'Submit Request for Admin Review',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: state.hasSelfie
                            ? AppColors.surfaceWhite
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUBMITTING VIEW
// ============================================================================
class _SubmittingView extends StatelessWidget {
  const _SubmittingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80.r,
              height: 80.r,
              child: const CircularProgressIndicator(
                color: AppColors.secondaryPink,
                strokeWidth: 3.5,
              ),
            ),
            SizedBox(height: 28.h),
            Text(
              context.isArabic ? 'جارٍ إرسال المستندات بأمان' : 'Submitting Documents Securely',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              context.isArabic
                  ? 'يتم تشفير ورفع صورة البطاقة والصورة الشخصية لإرسالها إلى لوحة إدارة المنصة للمراجعة اليدوية...'
                  : 'Encrypting and uploading your documents to the admin review queue for manual approval...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// RESULT VIEW — PENDING / VERIFIED / REJECTED
// ============================================================================
class _ResultView extends ConsumerWidget {
  const _ResultView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verificationControllerProvider);
    final controller = ref.read(verificationControllerProvider.notifier);
    final profile = ref.watch(currentUserProfileProvider);

    // Registered user's real name (never an AI extracted random name)
    final registeredFullName = profile?.fullName ??
        state.currentRecord?.userFullName ??
        'صاحب الحساب المسجل';

    final status = state.finalStatus ?? VerificationStatusType.pending;

    return switch (status) {
      VerificationStatusType.verified => _VerifiedSuccessView(
          fullName: registeredFullName,
        ),
      VerificationStatusType.failed => _RejectedView(
          fullName: registeredFullName,
          rejectionReason: state.currentRecord?.rejectionReason ??
              state.errorMessage ??
              (context.isArabic
                  ? 'تم رفض طلب التوثيق لعدم وضوح صورة بطاقة الرقم القومي أو عدم تطابقها مع الصورة الشخصية.'
                  : 'Verification rejected due to unreadable ID or mismatch with personal photo.'),
          onRetry: controller.retryWithNewImages,
        ),
      _ => _PendingReviewView(
          fullName: registeredFullName,
          noticeMessage: state.noticeMessage ??
              'تم استلام طلب توثيق حسابك بنجاح. برجاء الانتظار، سيتم مراجعة طلبك خلال 15 دقيقة.',
        ),
    };
  }
}

// ============================================================================
// PENDING REVIEW VIEW (WITH THE 15-MINUTE GUARANTEE NOTICE)
// ============================================================================
class _PendingReviewView extends StatelessWidget {
  final String fullName;
  final String noticeMessage;

  const _PendingReviewView({
    required this.fullName,
    required this.noticeMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pending Icon
          Center(
            child: Container(
              width: 96.r,
              height: 96.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warningOrange.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.warningOrange, width: 3),
              ),
              child: Center(
                child: Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.warningOrange,
                  size: 48.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),

          // Headline
          Text(
            context.isArabic ? 'طلبك قيد المراجعة' : 'Your Request is Under Review',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.warningOrange,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 14.h),

          // Required 15-minute prompt notice banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: AppColors.warningOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.warningOrange.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: AppColors.warningOrange,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    noticeMessage,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // User & Review Details Card
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadowColor,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _ResultRow(
                  icon: Icons.person_outline_rounded,
                  label: context.isArabic ? 'صاحب الحساب' : 'Account Holder',
                  value: fullName,
                ),
                Divider(height: 24.h, color: AppColors.borderSubtle),
                _ResultRow(
                  icon: Icons.pending_actions_rounded,
                  label: context.isArabic ? 'حالة الطلب' : 'Request Status',
                  value: context.isArabic ? 'في انتظار مراجعة الإدارة' : 'Pending Admin Approval',
                  valueColor: AppColors.warningOrange,
                ),
                Divider(height: 24.h, color: AppColors.borderSubtle),
                _ResultRow(
                  icon: Icons.access_time_rounded,
                  label: context.isArabic ? 'المدة المستهدفة' : 'Target Window',
                  value: context.isArabic ? 'خلال 15 دقيقة' : 'Within 15 minutes',
                  valueColor: AppColors.primaryNavy,
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // Explanatory info box
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.isArabic ? 'آلية المراجعة الإدارية:' : 'Manual Review Process:',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                _InfoBullet(
                  text: context.isArabic
                      ? 'يقوم فريق الإدارة بفحص المستندات والصورة الشخصية يدوياً لضمان سلامة وجودة الحسابات.'
                      : 'Our admin team manually inspects submitted ID and photo for community safety.',
                ),
                _InfoBullet(
                  text: context.isArabic
                      ? 'مدة 15 دقيقة هي المدة المستهدفة للمراجعة ولا تعني الاعتماد التلقائي.'
                      : 'The 15-minute timeframe is our review target and does not mean automatic approval.',
                ),
                _InfoBullet(
                  text: context.isArabic
                      ? 'سيتم تفعيل شارة التوثيق الزرقاء وفتح إمكانية المحادثات بمجرد اعتماد الإدارة لطلبك.'
                      : 'The verified badge and chats unlock as soon as administration formally approves.',
                ),
              ],
            ),
          ),
          SizedBox(height: 28.h),

          // Return Home Button
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              minimumSize: Size(double.infinity, 52.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            child: Text(
              context.isArabic ? 'العودة للرئيسية' : 'Back to Home',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.surfaceWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// VERIFIED SUCCESS VIEW (AFTER ACTUAL ADMIN APPROVAL)
// ============================================================================
class _VerifiedSuccessView extends StatelessWidget {
  final String fullName;

  const _VerifiedSuccessView({required this.fullName});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 100.r,
              height: 100.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.successGreen.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.successGreen, width: 3),
              ),
              child: Center(
                child: Icon(
                  Icons.verified_rounded,
                  color: AppColors.successGreen,
                  size: 52.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),

          Text(
            context.isArabic ? 'تم توثيق حسابك بنجاح! ✅' : 'Account Verified Successfully! ✅',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.successGreen,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            context.isArabic
                ? 'تمت مراجعة واعتماد هويتك من قِبل إدارة المنصة. حسابك الآن موثق بالعلامة الزرقاء، ويمكنك التواصل مع كافة التوافقات بكل ثقة.'
                : 'Your identity has been reviewed and approved by platform administration. You can now chat with your matches.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28.h),

          // Details Card
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppColors.successGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                _ResultRow(
                  icon: Icons.person_rounded,
                  label: context.isArabic ? 'الاسم المسجل' : 'Registered Name',
                  value: fullName,
                ),
                Divider(height: 24.h, color: AppColors.borderSubtle),
                _ResultRow(
                  icon: Icons.verified_user_rounded,
                  label: context.isArabic ? 'حالة الحساب' : 'Account Status',
                  value: context.isArabic ? 'موثق ومعتمد رسمياً' : 'Verified & Approved',
                  valueColor: AppColors.successGreen,
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),

          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              minimumSize: Size(double.infinity, 52.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            child: Text(
              context.isArabic ? 'العودة للرئيسية' : 'Back to Home',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.surfaceWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// REJECTED VIEW (AFTER ADMIN REJECTION WITH REASON)
// ============================================================================
class _RejectedView extends StatelessWidget {
  final String fullName;
  final String rejectionReason;
  final VoidCallback onRetry;

  const _RejectedView({
    required this.fullName,
    required this.rejectionReason,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 90.r,
              height: 90.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.errorRed.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.errorRed, width: 2.5),
              ),
              child: Center(
                child: Icon(
                  Icons.cancel_rounded,
                  color: AppColors.errorRed,
                  size: 48.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),

          Text(
            context.isArabic ? 'تم رفض طلب التوثيق' : 'Verification Request Rejected',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.errorRed,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),

          // Rejection reason banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.errorRed.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.errorRed, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      context.isArabic ? 'سبب الرفض من الإدارة:' : 'Rejection Reason:',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.errorRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  rejectionReason,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.errorRed,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: 28.h),

          // Retry button
          SizedBox(
            height: 52.h,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, size: 20.sp),
              label: Text(
                context.isArabic ? 'إعادة تقديم طلب التوثيق' : 'Resubmit Verification Request',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              context.isArabic ? 'العودة للرئيسية' : 'Back to Home',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================
class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20.sp),
        SizedBox(width: 10.w),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(
              color: valueColor ?? AppColors.primaryNavy,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InfoBullet extends StatelessWidget {
  final String text;

  const _InfoBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.warningOrange,
            size: 16.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidelinesCard extends StatelessWidget {
  final List<String> guidelines;

  const _GuidelinesCard({required this.guidelines});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.secondaryPink,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                context.isArabic ? 'إرشادات لقبول المستندات' : 'Document Guidelines',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ...guidelines.map(
            (g) => Padding(
              padding: EdgeInsets.symmetric(vertical: 3.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.circle,
                    color: AppColors.secondaryPink,
                    size: 6.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      g,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.errorRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorRed,
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.errorRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
