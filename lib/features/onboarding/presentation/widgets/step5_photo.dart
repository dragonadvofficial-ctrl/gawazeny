import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/text_styles.dart';
import '../onboarding_controller.dart';

/// Step 5: Primary profile photo selection and preview (الصورة الشخصية)
class Step5PhotoWidget extends ConsumerStatefulWidget {
  const Step5PhotoWidget({super.key});

  @override
  ConsumerState<Step5PhotoWidget> createState() => _Step5PhotoWidgetState();
}

class _Step5PhotoWidgetState extends ConsumerState<Step5PhotoWidget> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        ref.read(onboardingControllerProvider.notifier).setPhoto(
              bytes,
              file.name,
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.tr('error')}: $e',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.surfaceWhite,
              ),
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            context.tr('profilePhotoStep'),
            style: AppTextStyles.headlineMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          Text(
            context.tr('profilePhotoStepSub'),
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28.h),

          // Avatar Preview Card
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 170.r,
                height: 170.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceWhite,
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadowColor,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: state.photoBytes != null
                        ? AppColors.secondaryPink
                        : AppColors.borderSubtle,
                    width: 3.0,
                  ),
                ),
                child: ClipOval(
                  child: state.photoBytes != null
                      ? Image.memory(
                          state.photoBytes!,
                          fit: BoxFit.cover,
                          width: 170.r,
                          height: 170.r,
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 90.sp,
                          color: AppColors.textSecondary.withValues(alpha: 0.4),
                        ),
                ),
              ),
              if (state.photoBytes != null)
                Positioned(
                  bottom: 4.h,
                  right: 12.w,
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: const BoxDecoration(
                      color: AppColors.successGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: AppColors.surfaceWhite,
                      size: 20.sp,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 24.h),

          // Upload action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(context.tr('chooseFromGallery')),
              ),
              SizedBox(width: 14.w),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(130.w, 52.h),
                ),
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(context.tr('takePhotoCamera')),
              ),
            ],
          ),
          SizedBox(height: 28.h),

          // Guidelines Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: AppColors.primaryNavy,
                        size: 22.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        context.tr('photoGuidelines'),
                        style: AppTextStyles.titleSmall,
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  _GuidelineItem(text: context.tr('guidelineRecentFace')),
                  _GuidelineItem(text: context.tr('guidelineModesty')),
                  _GuidelineItem(text: context.tr('guidelineNoCelebrities')),
                  _GuidelineItem(text: context.tr('guidelineSafetyReview')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidelineItem extends StatelessWidget {
  final String text;

  const _GuidelineItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.secondaryPink,
            size: 16.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
