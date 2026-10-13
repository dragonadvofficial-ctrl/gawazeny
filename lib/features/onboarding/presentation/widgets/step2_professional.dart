import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../onboarding_controller.dart';

/// Step 2: Professional qualifications & physical attributes (التعليم والعمل والمواصفات)
class Step2ProfessionalWidget extends ConsumerWidget {
  const Step2ProfessionalWidget({super.key});

  static const List<String> _educationOptions = [
    'مؤهل متوسط / دبلوم',
    'مؤهل فوق متوسط',
    'مؤهل جامعي / بكالوريوس',
    'ماجستير (دراسات عليا)',
    'دكتوراه / زمالة',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'التعليم والعمل والمواصفات',
            style: AppTextStyles.headlineMedium,
          ),
          SizedBox(height: 6.h),
          Text(
            'تساعد هذه البيانات في إيجاد تكافؤ اجتماعي وعلمي مناسب بين الطرفين.',
            style: AppTextStyles.bodySmall,
          ),
          SizedBox(height: 24.h),

          // Job Title
          Text(
            'المسمى الوظيفي / مجال العمل',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.primaryNavy,
            ),
          ),
          SizedBox(height: 8.h),
          TextFormField(
            initialValue: state.jobTitle,
            decoration: const InputDecoration(
              hintText: 'مثال: مهندس برمجيات، محاسب قانوني، طبيب',
              prefixIcon: Icon(Icons.work_outline),
            ),
            onChanged: controller.setJobTitle,
          ),
          SizedBox(height: 20.h),

          // Education Level Dropdown
          Text(
            'المؤهل الدراسي',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.primaryNavy,
            ),
          ),
          SizedBox(height: 8.h),
          DropdownButtonFormField<String>(
            initialValue: _educationOptions.contains(state.educationLevel)
                ? state.educationLevel
                : _educationOptions[2],
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.school_outlined),
            ),
            items: _educationOptions.map((edu) {
              return DropdownMenuItem<String>(
                value: edu,
                child: Text(edu, style: AppTextStyles.bodyMedium),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) controller.setEducationLevel(val);
            },
          ),
          SizedBox(height: 24.h),

          // Height Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الطول',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.primaryNavy,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.lightPink,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${state.heightCm} سم',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.secondaryPink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: state.heightCm.toDouble(),
            min: 140,
            max: 210,
            divisions: 70,
            activeColor: AppColors.secondaryPink,
            inactiveColor: AppColors.lightPink,
            onChanged: (val) => controller.setHeight(val.round()),
          ),
          SizedBox(height: 16.h),

          // Weight Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الوزن',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.primaryNavy,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.lightPink,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${state.weightKg} كجم',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.secondaryPink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: state.weightKg.toDouble(),
            min: 40,
            max: 150,
            divisions: 110,
            activeColor: AppColors.secondaryPink,
            inactiveColor: AppColors.lightPink,
            onChanged: (val) => controller.setWeight(val.round()),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
