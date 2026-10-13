import '../../profile/domain/user_profile.dart';

/// Represents a candidate profile paired with its 3-tier compatibility score and avatar URL.
class ScoredProfile {
  final UserProfile profile;
  final int compatibilityScore;
  final String? primaryPhotoUrl;

  const ScoredProfile({
    required this.profile,
    required this.compatibilityScore,
    this.primaryPhotoUrl,
  });

  /// Factory constructor parsing records returned from the `get_smart_matches` RPC or raw query.
  factory ScoredProfile.fromMap(Map<String, dynamic> map) {
    final profile = UserProfile.fromMap(map);
    final score = (map['compatibility_score'] as num?)?.toInt() ?? 75;
    final photoUrl = map['photo_url'] as String?;

    return ScoredProfile(
      profile: profile,
      compatibilityScore: score.clamp(50, 99),
      primaryPhotoUrl: photoUrl,
    );
  }

  // Quick convenience getters
  String get id => profile.id;
  String get fullName => profile.fullName;
  int? get age => profile.age;
  String get residenceCity => profile.residenceCity;
  String? get jobTitle => profile.jobTitle;
  String? get educationLevel => profile.educationLevel;
  MaritalStatusType get maritalStatus => profile.maritalStatus;
  bool get isVerified =>
      profile.verificationStatus == VerificationStatusType.verified;
}
