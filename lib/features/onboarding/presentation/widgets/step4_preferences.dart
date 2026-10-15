import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_data_lists.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../profile/domain/user_profile.dart';
import '../onboarding_controller.dart';

/// Step 4: Partner criteria and matching preferences (مواصفات شريك الحياة)
class Step4PreferencesWidget extends ConsumerWidget {
  const Step4PreferencesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    // Clean list of Egyptian governorates and key cities
    final allEgyptianCities = AppDataLists.egyptianCities
        .where((c) => !c.contains('(') && !c.contains('مقيم'))
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مواصفات شريك الحياة',
            style: AppTextStyles.headlineMedium,
          ),
          SizedBox(height: 6.h),
          Text(
            'حدد المعايير التي تهمك لتصفية المرشحين بما يتوافق مع رغباتك وقيمك.',
            style: AppTextStyles.bodySmall,
          ),
          SizedBox(height: 24.h),

          // Age Range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الفئة العمرية المفضلة',
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
                  'من ${state.minAge} إلى ${state.maxAge} سنة',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.secondaryPink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          RangeSlider(
            values: RangeValues(
              state.minAge.toDouble(),
              state.maxAge.toDouble(),
            ),
            min: 18,
            max: 60,
            divisions: 42,
            activeColor: AppColors.secondaryPink,
            inactiveColor: AppColors.lightPink,
            onChanged: (RangeValues values) {
              controller.setAgeRange(
                values.start.round(),
                values.end.round(),
              );
            },
          ),
          SizedBox(height: 20.h),

          // Acceptable Marital Statuses
          Text(
            'الحالات الاجتماعية المقبولة للشريك',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.primaryNavy,
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _StatusFilterChip(
                label: 'أعزب / عزباء',
                isSelected: state.acceptableMaritalStatuses
                    .contains(MaritalStatusType.single),
                onSelected: () =>
                    controller.toggleMaritalStatus(MaritalStatusType.single),
              ),
              _StatusFilterChip(
                label: 'مطلق / مطلقة',
                isSelected: state.acceptableMaritalStatuses
                    .contains(MaritalStatusType.divorced),
                onSelected: () =>
                    controller.toggleMaritalStatus(MaritalStatusType.divorced),
              ),
              _StatusFilterChip(
                label: 'أرمل / أرملة',
                isSelected: state.acceptableMaritalStatuses
                    .contains(MaritalStatusType.widowed),
                onSelected: () =>
                    controller.toggleMaritalStatus(MaritalStatusType.widowed),
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // Acceptable Governorates & Cities
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المدن والمحافظات المفضلة',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.primaryNavy,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.lightPink,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '${state.acceptableCities.length} محددة',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.secondaryPink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'المحافظات المحددة في الخطوات السابقة تظهر محددة تلقائياً. يمكنك إضافة أو إزالة أي محافظة.',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 10.h),

          // Quick actions bar
          Row(
            children: [
              if (state.residenceCity.isNotEmpty) ...[
                ActionChip(
                  avatar: const Icon(
                    Icons.home_outlined,
                    size: 16,
                    color: AppColors.secondaryPink,
                  ),
                  label: Text(
                    'محافظتي (${state.residenceCity})',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.secondaryPink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: AppColors.lightPink,
                  side: BorderSide.none,
                  onPressed: () {
                    if (!state.acceptableCities.contains(state.residenceCity)) {
                      controller.toggleCity(state.residenceCity);
                    }
                  },
                ),
                SizedBox(width: 8.w),
              ],
              ActionChip(
                avatar: const Icon(
                  Icons.select_all,
                  size: 16,
                  color: AppColors.primaryNavy,
                ),
                label: Text(
                  'تحديد الكل',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: AppColors.borderSubtle.withAlpha(80),
                side: BorderSide.none,
                onPressed: () => controller.selectAllCities(allEgyptianCities),
              ),
              SizedBox(width: 8.w),
              ActionChip(
                avatar: const Icon(
                  Icons.clear_all,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                label: Text(
                  'مسح',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                backgroundColor: AppColors.borderSubtle.withAlpha(50),
                side: BorderSide.none,
                onPressed: controller.clearCities,
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Chips display with preserved selection
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: {
              ...state.acceptableCities,
              if (state.residenceCity.isNotEmpty) state.residenceCity,
              ...allEgyptianCities,
            }.map((city) {
              final isSelected = state.acceptableCities.contains(city);
              return FilterChip(
                label: Text(city),
                selected: isSelected,
                selectedColor: AppColors.primaryNavy,
                backgroundColor: AppColors.surfaceWhite,
                checkmarkColor: AppColors.surfaceWhite,
                showCheckmark: true,
                labelStyle: AppTextStyles.bodySmall.copyWith(
                  color:
                      isSelected ? AppColors.surfaceWhite : AppColors.primaryNavy,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primaryNavy
                      : AppColors.borderSubtle,
                ),
                onSelected: (_) => controller.toggleCity(city),
              );
            }).toList(),
          ),
          SizedBox(height: 24.h),

          // Religious & Smoking Requirements
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                CheckboxListTile(
                  title: Text(
                    'يشترط الالتزام التام بالصلاة',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: state.mustPray,
                  activeColor: AppColors.secondaryPink,
                  onChanged: (val) => controller.setMustPray(val ?? false),
                ),
                const Divider(height: 1),
                CheckboxListTile(
                  title: Text(
                    'أقبل بشريك مدخن',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: state.acceptsSmokers,
                  activeColor: AppColors.secondaryPink,
                  onChanged: (val) => controller.setAcceptsSmokers(val ?? false),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _StatusFilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.secondaryPink,
      backgroundColor: AppColors.surfaceWhite,
      checkmarkColor: AppColors.surfaceWhite,
      showCheckmark: true,
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: isSelected ? AppColors.surfaceWhite : AppColors.primaryNavy,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.secondaryPink : AppColors.borderSubtle,
      ),
    );
  }
}
