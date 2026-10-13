import '../../profile/domain/user_profile.dart';

/// Filter criteria for discovery feed and matrimonial search.
class MatchingFilters {
  final String searchQuery;
  final int minAge;
  final int maxAge;
  final List<String> selectedCities;
  final List<MaritalStatusType> selectedMaritalStatuses;
  final String? educationLevel;
  final bool mustPray;
  final bool nonSmokerOnly;
  final bool verifiedOnly;

  const MatchingFilters({
    this.searchQuery = '',
    this.minAge = 18,
    this.maxAge = 60,
    this.selectedCities = const [],
    this.selectedMaritalStatuses = const [],
    this.educationLevel,
    this.mustPray = false,
    this.nonSmokerOnly = false,
    this.verifiedOnly = false,
  });

  /// Returns true if no special filters are active.
  bool get isDefault =>
      searchQuery.trim().isEmpty &&
      minAge == 18 &&
      maxAge == 60 &&
      selectedCities.isEmpty &&
      selectedMaritalStatuses.isEmpty &&
      educationLevel == null &&
      !mustPray &&
      !nonSmokerOnly &&
      !verifiedOnly;

  /// Number of active custom filters for badge display.
  int get activeFiltersCount {
    int count = 0;
    if (searchQuery.trim().isNotEmpty) count++;
    if (minAge > 18 || maxAge < 60) count++;
    if (selectedCities.isNotEmpty) count += selectedCities.length;
    if (selectedMaritalStatuses.isNotEmpty) {
      count += selectedMaritalStatuses.length;
    }
    if (educationLevel != null && educationLevel!.isNotEmpty) count++;
    if (mustPray) count++;
    if (nonSmokerOnly) count++;
    if (verifiedOnly) count++;
    return count;
  }

  /// Evaluates whether a candidate profile matches the filter criteria.
  bool matchesProfile(UserProfile profile) {
    // 1. Search Query (Name, Job, City, Bio)
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

    // 2. Age Filter
    final age = profile.age ??
        (DateTime.now().year - profile.birthDate.year);
    if (age < minAge || age > maxAge) {
      return false;
    }

    // 3. City Filter
    if (selectedCities.isNotEmpty &&
        !selectedCities.contains(profile.residenceCity)) {
      return false;
    }

    // 4. Marital Status Filter
    if (selectedMaritalStatuses.isNotEmpty &&
        !selectedMaritalStatuses.contains(profile.maritalStatus)) {
      return false;
    }

    // 5. Education Level Filter
    if (educationLevel != null &&
        educationLevel!.isNotEmpty &&
        profile.educationLevel != educationLevel) {
      return false;
    }

    // 6. Prayer Filter
    if (mustPray && !(profile.prays ?? '').contains('محافظ')) {
      return false;
    }

    // 7. Non-Smoker Filter
    if (nonSmokerOnly && profile.smoker) {
      return false;
    }

    // 8. Verified Account Filter
    if (verifiedOnly &&
        profile.verificationStatus != VerificationStatusType.verified) {
      return false;
    }

    return true;
  }

  MatchingFilters copyWith({
    String? searchQuery,
    int? minAge,
    int? maxAge,
    List<String>? selectedCities,
    List<MaritalStatusType>? selectedMaritalStatuses,
    String? educationLevel,
    bool? mustPray,
    bool? nonSmokerOnly,
    bool? verifiedOnly,
  }) {
    return MatchingFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      selectedCities: selectedCities ?? this.selectedCities,
      selectedMaritalStatuses:
          selectedMaritalStatuses ?? this.selectedMaritalStatuses,
      educationLevel: educationLevel ?? this.educationLevel,
      mustPray: mustPray ?? this.mustPray,
      nonSmokerOnly: nonSmokerOnly ?? this.nonSmokerOnly,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    );
  }
}
