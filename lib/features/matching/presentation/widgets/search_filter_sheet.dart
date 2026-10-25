import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/matching_filters.dart';

/// Modal bottom sheet allowing users to customize matrimonial search and discovery filters.
class SearchFilterSheet extends StatefulWidget {
  final MatchingFilters initialFilters;
  final ValueChanged<MatchingFilters> onApply;

  const SearchFilterSheet({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  static const List<String> _popularCities = [
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'المنصورة',
    'طنطا',
    'الزقازيق',
    'أسيوط',
    'سوهاج',
    'بورسعيد',
    'الإسماعيلية',
  ];

  static const List<String> _educationLevels = [
    'مؤهل متوسط / دبلوم',
    'مؤهل فوق متوسط',
    'مؤهل جامعي / بكالوريوس',
    'ماجستير (دراسات عليا)',
    'دكتوراه / زمالة',
  ];

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  late TextEditingController _searchController;
  GenderType? _targetGender;
  late bool _showAllGenders;
  late String _sortBy;
  late int _minAge;
  late int _maxAge;
  late List<String> _selectedCities;
  late List<MaritalStatusType> _selectedMaritalStatuses;
  String? _selectedEducation;
  late bool _mustPray;
  late bool _nonSmokerOnly;
  late bool _verifiedOnly;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilters;
    _searchController = TextEditingController(text: f.searchQuery);
    _targetGender = f.targetGender;
    _showAllGenders = f.showAllGenders;
    _sortBy = f.sortBy;
    _minAge = f.minAge;
    _maxAge = f.maxAge;
    _selectedCities = List.from(f.selectedCities);
    _selectedMaritalStatuses = List.from(f.selectedMaritalStatuses);
    _selectedEducation = f.educationLevel;
    _mustPray = f.mustPray;
    _nonSmokerOnly = f.nonSmokerOnly;
    _verifiedOnly = f.verifiedOnly;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _searchController.clear();
      _targetGender = null;
      _showAllGenders = false;
      _sortBy = 'compatibility';
      _minAge = 18;
      _maxAge = 60;
      _selectedCities.clear();
      _selectedMaritalStatuses.clear();
      _selectedEducation = null;
      _mustPray = false;
      _nonSmokerOnly = false;
      _verifiedOnly = false;
    });
  }

  void _apply() {
    final filters = MatchingFilters(
      searchQuery: _searchController.text.trim(),
      targetGender: _targetGender,
      showAllGenders: _showAllGenders,
      sortBy: _sortBy,
      minAge: _minAge,
      maxAge: _maxAge,
      selectedCities: _selectedCities,
      selectedMaritalStatuses: _selectedMaritalStatuses,
      educationLevel: _selectedEducation,
      mustPray: _mustPray,
      nonSmokerOnly: _nonSmokerOnly,
      verifiedOnly: _verifiedOnly,
    );
    widget.onApply(filters);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.offWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 12.h),
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('filterResultsTitle'),
                      style: AppTextStyles.headlineMedium,
                    ),
                    TextButton(
                      onPressed: _reset,
                      child: Text(
                        context.tr('reset'),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.secondaryPink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Filter Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 16.h,
                  ),
                  children: [
                    // 1. Gender Filter
                    Text(
                      context.tr('showCandidates'),
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primaryNavy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      children: [
                        _FilterChipItem(
                          label: context.tr('femalesOnly'),
                          isSelected: !_showAllGenders && _targetGender == GenderType.female,
                          onTap: () {
                            setState(() {
                              _targetGender = GenderType.female;
                              _showAllGenders = false;
                            });
                          },
                        ),
                        _FilterChipItem(
                          label: context.tr('malesOnly'),
                          isSelected: !_showAllGenders && _targetGender == GenderType.male,
                          onTap: () {
                            setState(() {
                              _targetGender = GenderType.male;
                              _showAllGenders = false;
                            });
                          },
                        ),
                        _FilterChipItem(
                          label: context.tr('allMembers'),
                          isSelected: _showAllGenders,
                          onTap: () {
                            setState(() {
                              _showAllGenders = true;
                              _targetGender = null;
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _showAllGenders || _targetGender != null
                          ? (context.isArabic
                              ? 'ملاحظة: تُحسب نسبة التوافق للزواج فقط بين الجنسين المتقابلين وفقاً لضوابط المنصة.'
                              : 'Note: Marriage compatibility is calculated only between opposite genders.')
                          : '',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.sp,
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // 2. Keyword / Name Search
                    Text(
                      context.tr('searchByNameOrKeyword'),
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: context.tr('searchHintKeyword'),
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // 3. Sorting Criterion
                    Text(
                      context.tr('sortResults'),
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      children: [
                        _FilterChipItem(
                          label: context.tr('sortByCompatibility'),
                          isSelected: _sortBy == 'compatibility',
                          onTap: () => setState(() => _sortBy = 'compatibility'),
                        ),
                        _FilterChipItem(
                          label: context.tr('sortByNewest'),
                          isSelected: _sortBy == 'newest',
                          onTap: () => setState(() => _sortBy = 'newest'),
                        ),
                        _FilterChipItem(
                          label: context.tr('sortByVerified'),
                          isSelected: _sortBy == 'verified',
                          onTap: () => setState(() => _sortBy = 'verified'),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // 4. Age RangeSlider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('requiredAge'),
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lightPink,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            context.isArabic
                                ? 'من $_minAge إلى $_maxAge سنة'
                                : 'From $_minAge to $_maxAge ${context.tr('yearsOld')}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.secondaryPink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: RangeValues(
                        _minAge.toDouble(),
                        _maxAge.toDouble(),
                      ),
                      min: 18,
                      max: 60,
                      divisions: 42,
                      activeColor: AppColors.secondaryPink,
                      inactiveColor: AppColors.lightPink,
                      onChanged: (RangeValues vals) {
                        setState(() {
                          _minAge = vals.start.round();
                          _maxAge = vals.end.round();
                        });
                      },
                    ),
                    SizedBox(height: 20.h),

                    // 5. Marital Status Filter
                    Text(
                      context.tr('maritalStatus'),
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      children: [
                        _FilterChipItem(
                          label: context.tr('single'),
                          isSelected: _selectedMaritalStatuses
                              .contains(MaritalStatusType.single),
                          onTap: () {
                            setState(() {
                              if (_selectedMaritalStatuses
                                  .contains(MaritalStatusType.single)) {
                                _selectedMaritalStatuses
                                    .remove(MaritalStatusType.single);
                              } else {
                                _selectedMaritalStatuses
                                    .add(MaritalStatusType.single);
                              }
                            });
                          },
                        ),
                        _FilterChipItem(
                          label: context.tr('divorced'),
                          isSelected: _selectedMaritalStatuses
                              .contains(MaritalStatusType.divorced),
                          onTap: () {
                            setState(() {
                              if (_selectedMaritalStatuses
                                  .contains(MaritalStatusType.divorced)) {
                                _selectedMaritalStatuses
                                    .remove(MaritalStatusType.divorced);
                              } else {
                                _selectedMaritalStatuses
                                    .add(MaritalStatusType.divorced);
                              }
                            });
                          },
                        ),
                        _FilterChipItem(
                          label: context.tr('widowed'),
                          isSelected: _selectedMaritalStatuses
                              .contains(MaritalStatusType.widowed),
                          onTap: () {
                            setState(() {
                              if (_selectedMaritalStatuses
                                  .contains(MaritalStatusType.widowed)) {
                                _selectedMaritalStatuses
                                    .remove(MaritalStatusType.widowed);
                              } else {
                                _selectedMaritalStatuses
                                    .add(MaritalStatusType.widowed);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // 6. Residence City Filter
                    Text(
                      context.tr('cityAndGovernorate'),
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: SearchFilterSheet._popularCities.map((city) {
                        final isSelected = _selectedCities.contains(city);
                        return _FilterChipItem(
                          label: city,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCities.remove(city);
                              } else {
                                _selectedCities.add(city);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 20.h),

                    // 7. Education Level Filter
                    Text(
                      context.tr('educationLevel'),
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedEducation,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      hint: Text(
                        context.isArabic
                            ? 'الكل (أي مؤهل دراسي)'
                            : 'All (Any education level)',
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            context.isArabic
                                ? 'الكل (أي مؤهل دراسي)'
                                : 'All (Any education level)',
                          ),
                        ),
                        ...SearchFilterSheet._educationLevels.map((edu) {
                          return DropdownMenuItem<String?>(
                            value: edu,
                            child: Text(edu),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedEducation = val;
                        });
                      },
                    ),
                    SizedBox(height: 20.h),

                    // 8. Lifestyle & Verification Criteria
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          CheckboxListTile(
                            title: Text(context.tr('mustPrayRegularly')),
                            value: _mustPray,
                            activeColor: AppColors.secondaryPink,
                            onChanged: (val) {
                              setState(() {
                                _mustPray = val ?? false;
                              });
                            },
                          ),
                          const Divider(height: 1),
                          CheckboxListTile(
                            title: Text(context.tr('nonSmokerOnly')),
                            value: _nonSmokerOnly,
                            activeColor: AppColors.secondaryPink,
                            onChanged: (val) {
                              setState(() {
                                _nonSmokerOnly = val ?? false;
                              });
                            },
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: Text(context.tr('verifiedOnly')),
                            subtitle: Text(
                              context.isArabic
                                  ? 'إظهار الأعضاء الموثقين بالرقم القومي والمطابقة الحيوية فقط'
                                  : 'Show members verified with national ID only',
                            ),
                            value: _verifiedOnly,
                            activeThumbColor: AppColors.successGreen,
                            onChanged: (val) {
                              setState(() {
                                _verifiedOnly = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),

              // Bottom Apply Button
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 12.h,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceWhite,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.borderSubtle,
                      width: 1.0,
                    ),
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _apply,
                  child: Text(context.tr('applyFilters')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.secondaryPink,
      backgroundColor: AppColors.surfaceWhite,
      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: isSelected ? AppColors.surfaceWhite : AppColors.primaryNavy,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.secondaryPink : AppColors.borderSubtle,
      ),
    );
  }
}
