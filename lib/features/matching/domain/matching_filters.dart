import '../../profile/domain/user_profile.dart';

/// Filter criteria for discovery directory and matrimonial search.
class MatchingFilters {
  final String searchQuery;
  final GenderType? targetGender;
  final bool showAllGenders;
  final int minAge;
  final int maxAge;
  final List<String> selectedCities;
  final List<MaritalStatusType> selectedMaritalStatuses;
  final String? educationLevel;
  final bool mustPray;
  final bool nonSmokerOnly;
  final bool verifiedOnly;
  final String sortBy; // 'compatibility', 'newest', 'verified'

  const MatchingFilters({
    this.searchQuery = '',
    this.targetGender,
    this.showAllGenders = false,
    this.minAge = 18,
    this.maxAge = 60,
    this.selectedCities = const [],
    this.selectedMaritalStatuses = const [],
    this.educationLevel,
    this.mustPray = false,
    this.nonSmokerOnly = false,
    this.verifiedOnly = false,
    this.sortBy = 'compatibility',
  });

  /// Returns true if no custom filters are active.
  bool get isDefault =>
      searchQuery.trim().isEmpty &&
      targetGender == null &&
      !showAllGenders &&
      minAge == 18 &&
      maxAge == 60 &&
      selectedCities.isEmpty &&
      selectedMaritalStatuses.isEmpty &&
      educationLevel == null &&
      !mustPray &&
      !nonSmokerOnly &&
      !verifiedOnly &&
      sortBy == 'compatibility';

  /// Number of active custom filters for badge display.
  int get activeFiltersCount {
    int count = 0;
    if (searchQuery.trim().isNotEmpty) count++;
    if (targetGender != null || showAllGenders) count++;
    if (minAge > 18 || maxAge < 60) count++;
    if (selectedCities.isNotEmpty) count += selectedCities.length;
    if (selectedMaritalStatuses.isNotEmpty) {
      count += selectedMaritalStatuses.length;
    }
    if (educationLevel != null && educationLevel!.isNotEmpty) count++;
    if (mustPray) count++;
    if (nonSmokerOnly) count++;
    if (verifiedOnly) count++;
    if (sortBy != 'compatibility') count++;
    return count;
  }

  /// Evaluates whether a candidate profile matches the filter criteria.
  bool matchesProfile(
    UserProfile profile, {
    GenderType? currentUserGender,
  }) {
    // 1. Gender Filter
    if (showAllGenders) {
      // Allow any registered gender
    } else if (targetGender != null) {
      if (profile.gender != targetGender) {
        return false;
      }
    } else if (currentUserGender != null) {
      // Default to opposite gender according to matrimonial rules
      final defaultTarget = currentUserGender == GenderType.male
          ? GenderType.female
          : GenderType.male;
      if (profile.gender != defaultTarget) {
        return false;
      }
    }

    // 2. Keyword / Name Search (Name, Job, City, Bio)
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      final matchName = profile.fullName.toLowerCase().contains(query);
      final matchJob =
          (profile.jobTitle ?? '').toLowerCase().contains(query);
      final matchCity = profile.residenceCity.toLowerCase().contains(query);
      final matchBio = (profile.bio ?? '').toLowerCase().contains(query);
      if (!matchName && !matchJob && !matchCity && !matchBio) {
        return false;
      }
    }

    // 3. Age Filter (Only enforce when user actually adjusted the range)
    if (minAge > 18 || maxAge < 60) {
      final age = profile.age ??
          (DateTime.now().year - profile.birthDate.year);
      if (age < minAge || age > maxAge) {
        return false;
      }
    }

    // 4. City Filter
    if (selectedCities.isNotEmpty &&
        !selectedCities.contains(profile.residenceCity)) {
      return false;
    }

    // 5. Marital Status Filter
    if (selectedMaritalStatuses.isNotEmpty &&
        !selectedMaritalStatuses.contains(profile.maritalStatus)) {
      return false;
    }

    // 6. Education Level Filter
    if (educationLevel != null &&
        educationLevel!.isNotEmpty &&
        profile.educationLevel != educationLevel) {
      return false;
    }

    // 7. Prayer Commitment Filter
    if (mustPray) {
      final prayText = (profile.prays ?? '').toLowerCase();
      final commitsToPrayer = prayText.contains('محافظ') ||
          prayText.contains('دائماً') ||
          prayText.contains('وقتها') ||
          prayText.contains('مسجد') ||
          prayText.contains('معظم');
      if (!commitsToPrayer) {
        return false;
      }
    }

    // 8. Non-Smoker Filter
    if (nonSmokerOnly && profile.smoker) {
      return false;
    }

    // 9. Verified Account Filter
    if (verifiedOnly &&
        profile.verificationStatus != VerificationStatusType.verified) {
      return false;
    }

    return true;
  }

  MatchingFilters copyWith({
    String? searchQuery,
    GenderType? targetGender,
    bool clearTargetGender = false,
    bool? showAllGenders,
    int? minAge,
    int? maxAge,
    List<String>? selectedCities,
    List<MaritalStatusType>? selectedMaritalStatuses,
    String? educationLevel,
    bool clearEducationLevel = false,
    bool? mustPray,
    bool? nonSmokerOnly,
    bool? verifiedOnly,
    String? sortBy,
  }) {
    return MatchingFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      targetGender: clearTargetGender ? null : (targetGender ?? this.targetGender),
      showAllGenders: showAllGenders ?? this.showAllGenders,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      selectedCities: selectedCities ?? this.selectedCities,
      selectedMaritalStatuses:
          selectedMaritalStatuses ?? this.selectedMaritalStatuses,
      educationLevel: clearEducationLevel
          ? null
          : (educationLevel ?? this.educationLevel),
      mustPray: mustPray ?? this.mustPray,
      nonSmokerOnly: nonSmokerOnly ?? this.nonSmokerOnly,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}
