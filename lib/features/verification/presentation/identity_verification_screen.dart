import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/theme/text_styles.dart';
import '../../profile/domain/user_profile.dart';
import 'verification_controller.dart';

/// Complete 2-step identity verification wizard with AI pipeline integration.
class IdentityVerificationScreen extends ConsumerWidget {
  const IdentityVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verificationControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(context.isArabic
            ? 'توثيق الهوية بالذكاء الاصطناعي'
            : 'AI Identity Verification'),
        leading: state.step != VerificationStep.processing
            ? null
            : const SizedBox.shrink(),
        automaticallyImplyLeading: state.step != VerificationStep.processing,
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
          VerificationStep.idCard => _IdCardStep(key: const ValueKey('id')),
          VerificationStep.selfie => _SelfieStep(key: const ValueKey('selfie')),
          VerificationStep.processing =>
            _ProcessingView(key: const ValueKey('processing')),
          VerificationStep.result => _ResultView(
              key: const ValueKey('result'),
              errorMessage: state.errorMessage,
            ),
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
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: Column(
        children: [
          // Security Trust Banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.lightPink,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.secondaryPink.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.security_rounded,
                    color: AppColors.secondaryPink, size: 22.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    context.isArabic
                        ? 'بياناتك مشفرة ومحمية بأعلى معايير الأمان ولا تُشارك مع أي طرف'
                        : 'Your data is encrypted, secure, and never shared with third parties',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primaryNavy),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          // Step indicators
          Row(
            children: [
              _StepDot(
                  stepNumber: 1,
                  label: context.isArabic ? 'البطاقة' : 'ID Card',
                  isActive: currentStep >= 1,
                  isDone: currentStep > 1),
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
                  label: context.isArabic ? 'السيلفي' : 'Selfie',
                  isActive: currentStep >= 2,
                  isDone: false),
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
                ? Icon(Icons.check_rounded,
                    color: AppColors.surfaceWhite, size: 18.sp)
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
                // Title
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
                      ? 'يُرجى رفع صورة واضحة للوجه الأمامي لبطاقة الرقم القومي المصرية'
                      : 'Please upload a clear photo of the front face of your Egyptian National ID',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                SizedBox(height: 20.h),

                // ID Card Preview / Upload Zone
                GestureDetector(
                  onTap: () => pickImage(ImageSource.gallery),
                  child: Container(
                    height: 200.h,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: state.hasIdCard
                            ? AppColors.successGreen
                            : AppColors.borderSubtle,
                        width: state.hasIdCard ? 2 : 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadowColor,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: state.hasIdCard
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18.r),
                            child: Image.memory(
                              state.idCardBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(18.r),
                                decoration: const BoxDecoration(
                                  color: AppColors.lightPink,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.badge_outlined,
                                  color: AppColors.secondaryPink,
                                  size: 40.sp,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                context.isArabic
                                    ? 'اضغط لرفع صورة البطاقة'
                                    : 'Tap to upload ID photo',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                context.isArabic
                                    ? 'JPG أو PNG • جودة عالية'
                                    : 'JPG or PNG • High quality',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textMuted,
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
                        label: Text(context.isArabic ? 'من المعرض' : 'From Gallery'),
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
                        label: Text(context.isArabic ? 'من الكاميرا' : 'From Camera'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          side: const BorderSide(color: AppColors.primaryNavy),
                          foregroundColor: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                // Quality Guidelines
                _GuidelinesCard(
                  guidelines: context.isArabic
                      ? const [
                          'تأكد من وضوح النص والصورة بشكل كامل، وبدون انعكاس للضوء',
                          'وضع البطاقة على خلفية داكنة ومسطحة',
                          'التأكد من عدم وجود ظلال أو طيات تحجب البيانات',
                          'صورة مباشرة للوجه الأمامي فقط لبطاقة الرقم القومي',
                        ]
                      : const [
                          'Ensure all text and photos are sharp without reflections',
                          'Place the ID card flat on a dark surface',
                          'Make sure no shadows or folds obscure the information',
                          'Direct photo of the front face of your National ID only',
                        ],
                ),
                SizedBox(height: 24.h),

                // Error display
                if (state.errorMessage != null) ...[
                  _ErrorBanner(message: state.errorMessage!),
                  SizedBox(height: 16.h),
                ],

                // Continue Button
                SizedBox(
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: state.hasIdCard ? controller.proceedToSelfie : null,
                    child: Text(
                      context.isArabic
                          ? 'التالي — التقاط السيلفي'
                          : 'Next — Take Selfie',
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
// STEP 2: SELFIE CAPTURE
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
                      ? 'التقاط صورة سيلفي حية'
                      : 'Take a Live Selfie',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  context.isArabic
                      ? 'يرجى التقاط صورة واضحة لوجهك في إضاءة جيدة للتأكد من مطابقتها مع الهوية'
                      : 'Please take a clear selfie in good lighting to match with your National ID',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                SizedBox(height: 20.h),

                // Selfie Preview with oval face-guide frame
                Center(
                  child: GestureDetector(
                    onTap: () => captureSelfie(ImageSource.camera),
                    child: SizedBox(
                      width: 240.r,
                      height: 280.r,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background card
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
                                  blurRadius: 12,
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
                                      // Oval face guide
                                      Container(
                                        width: 120.r,
                                        height: 150.r,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.rectangle,
                                          borderRadius:
                                              BorderRadius.circular(80.r),
                                          border: Border.all(
                                            color: AppColors.secondaryPink
                                                .withValues(alpha: 0.5),
                                            width: 2.5,
                                          ),
                                          color: AppColors.lightPink
                                              .withValues(alpha: 0.3),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.face_outlined,
                                            color: AppColors.secondaryPink,
                                            size: 52.sp,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 14.h),
                                      Text(
                                        context.isArabic
                                            ? 'اضغط للتقاط السيلفي'
                                            : 'Tap to take a selfie',
                                        style: AppTextStyles.labelMedium
                                            .copyWith(
                                                color: AppColors.primaryNavy),
                                      ),
                                    ],
                                  ),
                          ),

                          // Live/Valid indicator overlay
                          if (state.hasSelfie)
                            Positioned(
                              bottom: 12.h,
                              right: 12.w,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10.w, vertical: 5.h),
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
                                      context.isArabic
                                          ? 'تم التقاطها'
                                          : 'Captured',
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
                        label: Text(context.isArabic ? 'الكاميرا الأمامية' : 'Front Camera'),
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
                        label: Text(context.isArabic ? 'من المعرض' : 'From Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          side: const BorderSide(color: AppColors.borderSubtle),
                          foregroundColor: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                // Selfie Guidelines
                _GuidelinesCard(
                  guidelines: context.isArabic
                      ? const [
                          'التقط الصورة في ضوء كافٍ وموزع بالتساوي على الوجه',
                          'تأكد أن وجهك يظهر كاملاً داخل الإطار البيضاوي',
                          'لا ترتدي نظارات شمسية أو قناعاً أثناء الالتقاط',
                          'انظر مباشرةً إلى الكاميرا بتعبير محايد وواضح',
                        ]
                      : const [
                          'Take photo in good, evenly distributed facial lighting',
                          'Ensure your face fits inside the oval guide',
                          'Do not wear sunglasses or masks during capture',
                          'Look directly into camera with a clear, neutral expression',
                        ],
                ),
                SizedBox(height: 24.h),

                // Error display
                if (state.errorMessage != null) ...[
                  _ErrorBanner(message: state.errorMessage!),
                  SizedBox(height: 16.h),
                ],

                // Submit Button
                SizedBox(
                  height: 52.h,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: state.hasSelfie
                          ? AppColors.pinkGradient
                          : null,
                      color: state.hasSelfie
                          ? null
                          : AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: state.hasSelfie
                          ? () => ref
                              .read(verificationControllerProvider.notifier)
                              .submitForAiVerification()
                          : null,
                      child: Text(
                        context.isArabic
                            ? 'إرسال للتحقق بالذكاء الاصطناعي'
                            : 'Submit for AI Verification',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: state.hasSelfie
                              ? AppColors.surfaceWhite
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
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
// PROCESSING VIEW
// ============================================================================
class _ProcessingView extends StatelessWidget {
  const _ProcessingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated AI pulse indicator
            SizedBox(
              width: 100.r,
              height: 100.r,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100.r,
                    height: 100.r,
                    child: CircularProgressIndicator(
                      color: AppColors.secondaryPink,
                      strokeWidth: 4.r,
                    ),
                  ),
                  Container(
                    width: 72.r,
                    height: 72.r,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.surfaceWhite,
                        size: 36.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 28.h),
            Text(
              context.isArabic ? 'جارٍ التحقق من هويتك' : 'Verifying Your Identity',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              context.isArabic
                  ? 'يقوم الذكاء الاصطناعي بمطابقة بيانات البطاقة مع صورة السيلفي...\nيرجى الانتظار وعدم إغلاق التطبيق'
                  : 'AI is matching your ID card with your selfie...\nPlease wait and do not close the app',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            _ProcessingStep(
                icon: Icons.badge_outlined,
                label: context.isArabic ? 'فحص وثيقة الهوية' : 'Checking ID document'),
            SizedBox(height: 12.h),
            _ProcessingStep(
                icon: Icons.text_fields_rounded,
                label: context.isArabic ? 'استخراج بيانات OCR' : 'Extracting OCR data'),
            SizedBox(height: 12.h),
            _ProcessingStep(
                icon: Icons.face_retouching_natural_rounded,
                label: context.isArabic ? 'مطابقة الوجه البيومترية' : 'Biometric face matching'),
            SizedBox(height: 12.h),
            _ProcessingStep(
                icon: Icons.verified_user_rounded,
                label: context.isArabic ? 'التحقق من الحيوية' : 'Liveness verification'),
          ],
        ),
      ),
    );
  }
}

class _ProcessingStep extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProcessingStep({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32.r,
          height: 32.r,
          decoration: const BoxDecoration(
            color: AppColors.lightPink,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, color: AppColors.secondaryPink, size: 16.sp),
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryNavy),
        ),
      ],
    );
  }
}

// ============================================================================
// RESULT VIEW — VERIFIED / FAILED / MANUAL_REVIEW
// ============================================================================
class _ResultView extends ConsumerWidget {
  final String? errorMessage;

  const _ResultView({super.key, this.errorMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verificationControllerProvider);
    final controller = ref.read(verificationControllerProvider.notifier);
    final status = state.finalStatus ?? VerificationStatusType.failed;

    return switch (status) {
      VerificationStatusType.verified => _VerifiedView(
          extractedName: state.aiResult?.extractedName ??
              state.existingRecord?.extractedName,
          score: state.aiResult?.faceMatchScore ??
              state.existingRecord?.faceMatchScore,
        ),
      VerificationStatusType.failed => _FailedView(
          idCardBytes: state.idCardBytes,
          selfieBytes: state.selfieBytes,
          idCardUrl: state.idCardUrl,
          selfieUrl: state.selfieUrl,
          rejectionReason: state.aiResult?.rejectionReason ??
              state.existingRecord?.rejectionReason ??
              'حدث خطأ أثناء عملية التوثيق. يرجى التحقق من الصور وإعادة المحاولة',
          onRetryNewImages: controller.retryWithNewImages,
          onResubmitSame:
              state.idCardBytes != null && state.selfieBytes != null
                  ? controller.resubmitSameImages
                  : null,
        ),
      VerificationStatusType.manualReview => const _ManualReviewView(),
      _ => _FailedView(
          idCardBytes: state.idCardBytes,
          selfieBytes: state.selfieBytes,
          idCardUrl: state.idCardUrl,
          selfieUrl: state.selfieUrl,
          rejectionReason:
              'حدث خطأ أثناء عملية التوثيق. يرجى التحقق من الصور وإعادة المحاولة',
          onRetryNewImages: controller.retryWithNewImages,
          onResubmitSame: null,
        ),
    };
  }
}

// ============================================================================
// VERIFIED SUCCESS VIEW
// ============================================================================
class _VerifiedView extends StatelessWidget {
  final String? extractedName;
  final double? score;

  const _VerifiedView({this.extractedName, this.score});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success badge
          Center(
            child: Container(
              width: 110.r,
              height: 110.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.successGreen.withValues(alpha: 0.12),
                border: Border.all(
                    color: AppColors.successGreen, width: 3),
              ),
              child: Center(
                child: Icon(
                  Icons.verified_rounded,
                  color: AppColors.successGreen,
                  size: 56.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          Text(
            context.isArabic ? 'تم التوثيق بنجاح! ✅' : 'Verified Successfully! ✅',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.successGreen,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            context.isArabic
                ? 'هويتك موثقة وحسابك مفعّل بالكامل. يمكنك الآن التواصل مع التوافقات.'
                : 'Your identity is verified and your account is active. You can now connect with matches.',
            style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28.h),

          // Result Details Card
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                  color: AppColors.successGreen.withValues(alpha: 0.3)),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.cardShadowColor,
                    blurRadius: 10,
                    offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              children: [
                if (extractedName != null) ...[
                  _ResultRow(
                    icon: Icons.person_rounded,
                    label: context.isArabic ? 'الاسم المُستخرج' : 'Extracted Name',
                    value: extractedName!,
                  ),
                  Divider(height: 24.h, color: AppColors.borderSubtle),
                ],
                _ResultRow(
                  icon: Icons.face_retouching_natural_rounded,
                  label: context.isArabic ? 'نسبة تطابق الوجه' : 'Face Match Score',
                  value: '${score?.toStringAsFixed(0) ?? '—'}%',
                  valueColor: AppColors.successGreen,
                ),
                Divider(height: 24.h, color: AppColors.borderSubtle),
                _ResultRow(
                  icon: Icons.security_rounded,
                  label: context.isArabic ? 'التحقق من الحيوية' : 'Liveness Verification',
                  value: context.isArabic ? 'ناجح' : 'Passed',
                  valueColor: AppColors.successGreen,
                ),
                Divider(height: 24.h, color: AppColors.borderSubtle),
                _ResultRow(
                  icon: Icons.badge_rounded,
                  label: context.isArabic ? 'حالة التوثيق' : 'Verification Status',
                  value: context.isArabic ? 'موثق' : 'Verified',
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
// FAILED VIEW WITH SIDE-BY-SIDE PREVIEW
// ============================================================================
class _FailedView extends StatelessWidget {
  final Uint8List? idCardBytes;
  final Uint8List? selfieBytes;
  final String? idCardUrl;
  final String? selfieUrl;
  final String rejectionReason;
  final VoidCallback onRetryNewImages;
  final Future<void> Function()? onResubmitSame;

  const _FailedView({
    this.idCardBytes,
    this.selfieBytes,
    this.idCardUrl,
    this.selfieUrl,
    required this.rejectionReason,
    required this.onRetryNewImages,
    this.onResubmitSame,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error Icon
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
                child: Icon(Icons.error_outline_rounded,
                    color: AppColors.errorRed, size: 46.sp),
              ),
            ),
          ),
          SizedBox(height: 20.h),

          Text(
            context.isArabic ? 'فشل التوثيق' : 'Verification Failed',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.errorRed,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10.h),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                  color: AppColors.errorRed.withValues(alpha: 0.2)),
            ),
            child: Text(
              rejectionReason,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.errorRed,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24.h),

          // Side-by-side images (if available)
          if (idCardBytes != null || selfieBytes != null) ...[
            Text(
              context.isArabic ? 'مقارنة الصور المرفوعة' : 'Uploaded Photos Comparison',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _ImagePreviewCard(
                    label: context.isArabic ? 'صورة البطاقة' : 'ID Card Photo',
                    bytes: idCardBytes,
                    icon: Icons.badge_outlined,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _ImagePreviewCard(
                    label: context.isArabic ? 'السيلفي' : 'Selfie',
                    bytes: selfieBytes,
                    icon: Icons.face_outlined,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
          ],

          // Action Buttons
          SizedBox(
            height: 52.h,
            child: ElevatedButton.icon(
              onPressed: onRetryNewImages,
              icon: Icon(Icons.upload_file_rounded, size: 20.sp),
              label: Text(context.isArabic ? 'إعادة رفع الصور' : 'Upload New Photos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryPink,
              ),
            ),
          ),
          if (onResubmitSame != null) ...[
            SizedBox(height: 12.h),
            SizedBox(
              height: 52.h,
              child: OutlinedButton.icon(
                onPressed: onResubmitSame,
                icon: Icon(Icons.refresh_rounded, size: 20.sp),
                label: Text(context.isArabic ? 'إعادة الإرسال بنفس الصور' : 'Resubmit Same Photos'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryNavy),
                  foregroundColor: AppColors.primaryNavy,
                ),
              ),
            ),
          ],
          SizedBox(height: 12.h),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              context.isArabic ? 'العودة لاحقاً' : 'Return Later',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MANUAL REVIEW VIEW
// ============================================================================
class _ManualReviewView extends StatelessWidget {
  const _ManualReviewView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 100.r,
              height: 100.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warningOrange.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.warningOrange, width: 3),
              ),
              child: Center(
                child: Icon(Icons.pending_actions_rounded,
                    color: AppColors.warningOrange, size: 50.sp),
              ),
            ),
          ),
          SizedBox(height: 28.h),

          Text(
            context.isArabic ? 'طلبك قيد المراجعة' : 'Your Request is Under Review',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.warningOrange,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          Text(
            context.isArabic
                ? 'طلبك قيد المراجعة بواسطة فريق العمل للتأكد من البيانات.\nسيتم إخطارك بالنتيجة خلال 24-48 ساعة.'
                : 'Your request is being reviewed by our team to verify details.\nYou will be notified within 24-48 hours.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),

          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                  color: AppColors.warningOrange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.access_time_rounded,
                    color: AppColors.warningOrange, size: 28.sp),
                SizedBox(height: 8.h),
                Text(
                  context.isArabic ? 'ماذا يحدث الآن؟' : 'What happens now?',
                  style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12.h),
                _InfoItem(label: context.isArabic
                    ? 'يراجع فريقنا صورة بطاقتك والسيلفي يدوياً'
                    : 'Our team manually reviews your ID card and selfie'),
                _InfoItem(label: context.isArabic
                    ? 'لن تُخزَّن بياناتك إلا بالقدر الضروري للتوثيق'
                    : 'Your data is only stored as needed for verification'),
                _InfoItem(label: context.isArabic
                    ? 'ستتلقى إشعاراً فور اتخاذ القرار'
                    : 'You will receive a notification as soon as a decision is made'),
              ],
            ),
          ),
          SizedBox(height: 32.h),

          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
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

class _InfoItem extends StatelessWidget {
  final String label;
  const _InfoItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: AppColors.warningOrange, size: 16.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// REUSABLE COMPONENTS
// ============================================================================
class _GuidelinesCard extends StatelessWidget {
  final List<String> guidelines;
  const _GuidelinesCard({required this.guidelines});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.primaryNavy, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                context.isArabic ? 'نصائح لصورة واضحة' : 'Tips for a Clear Photo',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ...guidelines.map(
            (g) => Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.secondaryPink)),
                  Expanded(
                    child: Text(
                      g,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary, height: 1.4),
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
        color: AppColors.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppColors.errorRed, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewCard extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final IconData icon;

  const _ImagePreviewCard({
    required this.label,
    required this.bytes,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium
              .copyWith(color: AppColors.primaryNavy, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8.h),
        Container(
          height: 130.h,
          decoration: BoxDecoration(
            color: AppColors.lightPink,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: bytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: Image.memory(bytes!, fit: BoxFit.cover, width: double.infinity),
                )
              : Center(
                  child: Icon(icon,
                      color: AppColors.secondaryPink, size: 40.sp),
                ),
        ),
      ],
    );
  }
}

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
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: const BoxDecoration(
            color: AppColors.offWhite,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryNavy, size: 18.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
