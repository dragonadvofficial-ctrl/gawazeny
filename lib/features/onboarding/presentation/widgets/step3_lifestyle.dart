import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../onboarding_controller.dart';

/// Step 3: Lifestyle, religious values, and personal bio (نمط الحياة والالتزام)
class Step3LifestyleWidget extends ConsumerWidget {
  const Step3LifestyleWidget({super.key});

  static const List<String> _prayerOptions = [
    'محافظ على الصلاة في المسجد',
    'محافظ على الصلاة في وقتها',
    'أصلي معظم الأوقات',
    'أصلي متقطع وبحاجة للتشجيع',
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
            'نمط الحياة والالتزام',
            style: AppTextStyles.headlineMedium,
          ),
          SizedBox(height: 6.h),
          Text(
            'بيانات الصدق والوضوح تبني بيوتاً سعيدة ومستقرة على طاعة الله.',
            style: AppTextStyles.bodySmall,
          ),
          SizedBox(height: 24.h),

          // Prayer Commitment
          Text(
            'الالتزام بالصلاة',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.primaryNavy,
            ),
          ),
          SizedBox(height: 8.h),
          DropdownButtonFormField<String>(
            initialValue: _prayerOptions.contains(state.prays)
                ? state.prays
                : _prayerOptions.first,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.mosque_outlined),
            ),
            items: _prayerOptions.map((opt) {
              return DropdownMenuItem<String>(
                value: opt,
                child: Text(opt, style: AppTextStyles.bodyMedium),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) controller.setPrays(val);
            },
          ),
          SizedBox(height: 20.h),

          // Smoking Switch Card
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              title: Text(
                'هل أنت مدخن؟',
                style: AppTextStyles.titleMedium,
              ),
              subtitle: Text(
                state.smoker ? 'نعم، مدخن' : 'غير مدخن',
                style: AppTextStyles.bodySmall.copyWith(
                  color: state.smoker ? AppColors.errorRed : AppColors.successGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              activeThumbColor: AppColors.secondaryPink,
              value: state.smoker,
              onChanged: controller.setSmoker,
            ),
          ),
          SizedBox(height: 14.h),

          // Wants Children Switch Card
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              title: Text(
                'الرغبة في الإنجاب',
                style: AppTextStyles.titleMedium,
              ),
              subtitle: Text(
                state.wantsChildren ? 'نعم، أرغب في الإنجاب بإذن الله' : 'لا أفضل الإنجاب حالياً',
                style: AppTextStyles.bodySmall,
              ),
              activeThumbColor: AppColors.secondaryPink,
              value: state.wantsChildren,
              onChanged: controller.setWantsChildren,
            ),
          ),
          SizedBox(height: 24.h),

          // Personal Bio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'نبذة عني وعن شريكي المنشود',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.primaryNavy,
                ),
              ),
              Text(
                '${state.bio.length} / 400',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          TextFormField(
            initialValue: state.bio,
            maxLines: 4,
            maxLength: 400,
            decoration: const InputDecoration(
              hintText:
                  'تحدث باختصار عن شخصيتك، أسلوب حياتك، وتطلعاتك لشريك الحياة المستقبلي...',
              counterText: '',
            ),
            onChanged: controller.setBio,
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
