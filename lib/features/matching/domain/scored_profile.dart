import '../../profile/domain/user_profile.dart';

/// Represents a candidate profile paired with its compatibility score, avatar URL, and like/match state.
class ScoredProfile {
  final UserProfile profile;
  /// Compatibility score (0-100%).
  /// Null if same-gender browsing or not yet computable.
  final int? compatibilityScore;
  final String? primaryPhotoUrl;
  final bool isLiked;
  final bool isMatched;

  const ScoredProfile({
    required this.profile,
    this.compatibilityScore,
    this.primaryPhotoUrl,
    this.isLiked = false,
    this.isMatched = false,
  });

  /// Factory constructor parsing records returned from the `discover_members` or `get_smart_matches` RPCs.
  factory ScoredProfile.fromMap(Map<String, dynamic> map) {
    final profile = UserProfile.fromMap(map);
    final score = (map['compatibility_score'] as num?)?.toInt().clamp(0, 100);
    final photoUrl = (map['photo_url'] ?? map['photoUrl'] ?? profile.photoUrl) as String?;
    final isLiked = map['is_liked'] as bool? ?? false;
    final isMatched = map['is_matched'] as bool? ?? false;

    return ScoredProfile(
      profile: profile,
      compatibilityScore: score,
      primaryPhotoUrl: photoUrl,
      isLiked: isLiked,
      isMatched: isMatched,
    );
  }

  // Quick convenience getters
  String get id => profile.id;
  String get fullName => profile.fullName;
  GenderType get gender => profile.gender;
  int? get age => profile.age;
  String get residenceCity => profile.residenceCity;
  String? get jobTitle => profile.jobTitle;
  String? get educationLevel => profile.educationLevel;
  MaritalStatusType get maritalStatus => profile.maritalStatus;
  bool get isVerified =>
      profile.verificationStatus == VerificationStatusType.verified;

  /// Whether a numerical marriage compatibility score was computed.
  bool get hasCompatibility => compatibilityScore != null;

  ScoredProfile copyWith({
    UserProfile? profile,
    int? compatibilityScore,
    bool clearCompatibilityScore = false,
    String? primaryPhotoUrl,
    bool? isLiked,
    bool? isMatched,
  }) {
    return ScoredProfile(
      profile: profile ?? this.profile,
      compatibilityScore: clearCompatibilityScore
          ? null
          : (compatibilityScore ?? this.compatibilityScore),
      primaryPhotoUrl: primaryPhotoUrl ?? this.primaryPhotoUrl,
      isLiked: isLiked ?? this.isLiked,
      isMatched: isMatched ?? this.isMatched,
    );
  }
}
