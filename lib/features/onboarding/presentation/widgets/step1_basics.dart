import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_data_lists.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../profile/domain/user_profile.dart';
import '../onboarding_controller.dart';

/// Step 1: Basic personal details (الأساسيات)
class Step1BasicsWidget extends ConsumerStatefulWidget {
  const Step1BasicsWidget({super.key});

  @override
  ConsumerState<Step1BasicsWidget> createState() => _Step1BasicsWidgetState();
}

class _Step1BasicsWidgetState extends ConsumerState<Step1BasicsWidget> {
  int? _selectedDay;
  int? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    final initialDate = ref.read(onboardingControllerProvider).birthDate;
    if (initialDate != null) {
      _selectedDay = initialDate.day;
      _selectedMonth = initialDate.month;
      _selectedYear = initialDate.year;
    }
  }

  void _onDateComponentChanged({
    int? day,
    int? month,
    int? year,
    required OnboardingController controller,
  }) {
    setState(() {
      if (day != null) _selectedDay = day;
      if (month != null) _selectedMonth = month;
      if (year != null) _selectedYear = year;
    });

    if (_selectedDay != null && _selectedMonth != null && _selectedYear != null) {
      final maxDays = DateUtils.getDaysInMonth(_selectedYear!, _selectedMonth!);
      final validDay = _selectedDay! > maxDays ? maxDays : _selectedDay!;
      if (validDay != _selectedDay) {
        setState(() {
          _selectedDay = validDay;
        });
      }
      controller.setBirthDate(DateTime(_selectedYear!, _selectedMonth!, validDay));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    // Sync state if initialized outside
    if (state.birthDate != null &&
        (_selectedDay == null || _selectedMonth == null || _selectedYear == null)) {
      _selectedDay = state.birthDate!.day;
      _selectedMonth = state.birthDate!.month;
      _selectedYear = state.birthDate!.year;
    }

    final maxDaysInCurrentMonth = (_selectedYear != null && _selectedMonth != null)
        ? DateUtils.getDaysInMonth(_selectedYear!, _selectedMonth!)
        : 31;
    final daysList = List.generate(maxDaysInCurrentMonth, (i) => i + 1);

    final currentYear = DateTime.now().year;
    final maxYear = currentYear - 18;
    final minYear = 1950;
    final yearsList = List.generate(
      maxYear - minYear + 1,
      (index) => maxYear - index,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'البيانات الأساسية',
            style: AppTextStyles.headlineMedium,
          ),
          SizedBox(height: 6.h),
          Text(
            'يرجى إدخال بياناتك الحقيقية المطابقة لبطاقة الرقم القومي.',
            style: AppTextStyles.bodySmall,
          ),
          SizedBox(height: 24.h),

          // Full Name
          Text(
            'الاسم الرباعي',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.primaryNavy,
            ),
          ),
          SizedBox(height: 8.h),
          TextFormField(
            initialValue: state.fullName,
            decoration: const InputDecoration(
              hintText: 'مثال: محمد ايهاب',
              prefixIcon: Icon(Icons.person_outline),
            ),
            onChanged: controller.setFullName,
          ),
          SizedBox(height: 20.h),

          // Gender Selection Toggle
          Text(
            'الجنس',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.primaryNavy,
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _GenderCard(
                  title: 'رجل / عريس',
                  icon: Icons.male_rounded,
                  isSelected: state.gender == GenderType.male,
                  onTap: () => controller.setGender(GenderType.male),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: _GenderCard(
                  title: 'امرأة / عروسة',
                  icon: Icons.female_rounded,
                  isSelected: state.gender == GenderType.female,
                  onTap: () => controller.setGender(GenderType.female),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Birth Date Header & Automated Age
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تاريخ الميلاد',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.primaryNavy,
                ),
              ),
              if (state.calculatedAge != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.lightPink,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${state.calculatedAge} سنة',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),

          // 3 Separate Scrollable Dropdown Pickers: Day, Month, Year
          Row(
            children: [
              // 1. Day Picker (اليوم)
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('day_$_selectedDay'),
                  initialValue: (_selectedDay != null && daysList.contains(_selectedDay))
                      ? _selectedDay
                      : null,
                  isExpanded: true,
                  menuMaxHeight: 280.h,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primaryNavy,
                    size: 20,
                  ),
                  decoration: InputDecoration(
                    labelText: 'اليوم',
                    labelStyle: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primaryNavy,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
                    filled: true,
                    fillColor: AppColors.surfaceWhite,
                  ),
                  items: daysList.map((day) {
                    return DropdownMenuItem<int>(
                      value: day,
                      child: Text(
                        '$day',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primaryNavy,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (day) {
                    _onDateComponentChanged(
                      day: day,
                      controller: controller,
                    );
                  },
                ),
              ),
              SizedBox(width: 8.w),

              // 2. Month Picker (الشهر)
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('month_$_selectedMonth'),
                  initialValue: _selectedMonth,
                  isExpanded: true,
                  menuMaxHeight: 280.h,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primaryNavy,
                    size: 20,
                  ),
                  decoration: InputDecoration(
                    labelText: 'الشهر',
                    labelStyle: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primaryNavy,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
                    filled: true,
                    fillColor: AppColors.surfaceWhite,
                  ),
                  items: AppDataLists.arabicMonths.map((m) {
                    final monthNumber = m['number'] as int;
                    final monthName = m['name'] as String;
                    return DropdownMenuItem<int>(
                      value: monthNumber,
                      child: Text(
                        '$monthNumber - $monthName',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primaryNavy,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (month) {
                    _onDateComponentChanged(
                      month: month,
                      controller: controller,
                    );
                  },
                ),
              ),
              SizedBox(width: 8.w),

              // 3. Year Picker (السنة)
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('year_$_selectedYear'),
                  initialValue: (_selectedYear != null && yearsList.contains(_selectedYear))
                      ? _selectedYear
                      : null,
                  isExpanded: true,
                  menuMaxHeight: 280.h,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primaryNavy,
                    size: 20,
                  ),
                  decoration: InputDecoration(
                    labelText: 'السنة',
                    labelStyle: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primaryNavy,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
                    filled: true,
                    fillColor: AppColors.surfaceWhite,
                  ),
                  items: yearsList.map((year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(
                        '$year',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primaryNavy,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (year) {
                    _onDateComponentChanged(
                      year: year,
                      controller: controller,
                    );
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Residence City & Nationality - Scrollable Dropdown Selection
          Row(
            children: [
              // Residence City (مدينة الإقامة - المحافظات والمدن المصرية)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مدينة الإقامة',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    DropdownButtonFormField<String>(
                      key: ValueKey('city_${state.residenceCity}'),
                      initialValue: AppDataLists.egyptianCities.contains(state.residenceCity)
                          ? state.residenceCity
                          : null,
                      isExpanded: true,
                      menuMaxHeight: 320.h,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primaryNavy,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'اختر المدينة',
                        prefixIcon: Icon(
                          Icons.location_city_outlined,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      items: AppDataLists.egyptianCities.map((city) {
                        return DropdownMenuItem<String>(
                          value: city,
                          child: Text(
                            city,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primaryNavy,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          controller.setResidenceCity(val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),

              // Nationality (الجنسية - دول العالم)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الجنسية',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    DropdownButtonFormField<String>(
                      key: ValueKey('nation_${state.nationality}'),
                      initialValue: AppDataLists.worldNationalities.contains(state.nationality)
                          ? state.nationality
                          : null,
                      isExpanded: true,
                      menuMaxHeight: 320.h,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primaryNavy,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'اختر الجنسية',
                        prefixIcon: Icon(
                          Icons.flag_outlined,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      items: AppDataLists.worldNationalities.map((nation) {
                        return DropdownMenuItem<String>(
                          value: nation,
                          child: Text(
                            nation,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primaryNavy,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          controller.setNationality(val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Marital Status
          Text(
            'الحالة الاجتماعية',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.primaryNavy,
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 10.w,
            children: [
              _MaritalChoiceChip(
                label: 'أعزب / عزباء',
                isSelected: state.maritalStatus == MaritalStatusType.single,
                onSelected: () => controller.setMaritalStatus(MaritalStatusType.single),
              ),
              _MaritalChoiceChip(
                label: 'مطلق / مطلقة',
                isSelected: state.maritalStatus == MaritalStatusType.divorced,
                onSelected: () => controller.setMaritalStatus(MaritalStatusType.divorced),
              ),
              _MaritalChoiceChip(
                label: 'أرمل / أرملة',
                isSelected: state.maritalStatus == MaritalStatusType.widowed,
                onSelected: () => controller.setMaritalStatus(MaritalStatusType.widowed),
              ),
            ],
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightPink : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isSelected ? AppColors.secondaryPink : AppColors.borderSubtle,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 36.sp,
              color: isSelected ? AppColors.secondaryPink : AppColors.primaryNavy,
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: AppTextStyles.titleSmall.copyWith(
                color: isSelected ? AppColors.secondaryPink : AppColors.primaryNavy,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaritalChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _MaritalChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.secondaryPink,
      backgroundColor: AppColors.surfaceWhite,
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
