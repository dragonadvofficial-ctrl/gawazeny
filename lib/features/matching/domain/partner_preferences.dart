import '../../profile/domain/user_profile.dart';

/// Domain model representing partner preferences from the `partner_preferences` table.
class PartnerPreferences {
  final String userId;
  final int minAge;
  final int maxAge;
  final List<MaritalStatusType> acceptableMaritalStatuses;
  final List<String> acceptableCities;
  final bool mustPray;
  final bool acceptsSmokers;
  final DateTime createdAt;

  const PartnerPreferences({
    required this.userId,
    this.minAge = 18,
    this.maxAge = 60,
    this.acceptableMaritalStatuses = const [],
    this.acceptableCities = const [],
    this.mustPray = false,
    this.acceptsSmokers = false,
    required this.createdAt,
  });

  factory PartnerPreferences.fromMap(Map<String, dynamic> map) {
    final rawStatuses = map['acceptable_marital_statuses'] as List<dynamic>? ?? [];
    final statuses = rawStatuses
        .map((e) => MaritalStatusType.fromDbValue(e.toString()))
        .toList();

    final rawCities = map['acceptable_cities'] as List<dynamic>? ?? [];
    final cities = rawCities.map((e) => e.toString()).toList();

    return PartnerPreferences(
      userId: map['user_id'] as String,
      minAge: (map['min_age'] as num?)?.toInt() ?? 18,
      maxAge: (map['max_age'] as num?)?.toInt() ?? 60,
      acceptableMaritalStatuses: statuses,
      acceptableCities: cities,
      mustPray: map['must_pray'] as bool? ?? false,
      acceptsSmokers: map['accepts_smokers'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'min_age': minAge,
      'max_age': maxAge,
      'acceptable_marital_statuses': acceptableMaritalStatuses
          .map((status) => status.toDbValue())
          .toList(),
      'acceptable_cities': acceptableCities,
      'must_pray': mustPray,
    };
  }

  PartnerPreferences copyWith({
    String? userId,
    int? minAge,
    int? maxAge,
    List<MaritalStatusType>? acceptableMaritalStatuses,
    List<String>? acceptableCities,
    bool? mustPray,
    bool? acceptsSmokers,
    DateTime? createdAt,
  }) {
    return PartnerPreferences(
      userId: userId ?? this.userId,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      acceptableMaritalStatuses:
          acceptableMaritalStatuses ?? this.acceptableMaritalStatuses,
      acceptableCities: acceptableCities ?? this.acceptableCities,
      mustPray: mustPray ?? this.mustPray,
      acceptsSmokers: acceptsSmokers ?? this.acceptsSmokers,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
