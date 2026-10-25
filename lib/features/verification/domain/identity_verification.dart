import '../../profile/domain/user_profile.dart';

/// Domain model representing identity verification requests from the `identity_verifications` table.
/// Manual admin approval workflow: User submits documents -> Status: PENDING -> Admin reviews & decides.
class IdentityVerification {
  final String id;
  final String userId;
  final String idCardImageUrl;
  final String selfieImageUrl;
  final String? userFullName;
  final VerificationStatusType status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  // Optional legacy fields for backward database schema compatibility
  final String? extractedName;
  final DateTime? extractedBirthDate;
  final double? faceMatchScore;
  final bool livenessPassed;

  const IdentityVerification({
    required this.id,
    required this.userId,
    required this.idCardImageUrl,
    required this.selfieImageUrl,
    this.userFullName,
    this.status = VerificationStatusType.pending,
    this.rejectionReason,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.extractedName,
    this.extractedBirthDate,
    this.faceMatchScore,
    this.livenessPassed = false,
  });

  bool get isPending => status == VerificationStatusType.pending;
  bool get isVerified => status == VerificationStatusType.verified;
  bool get isFailed => status == VerificationStatusType.failed;

  IdentityVerification copyWith({
    String? id,
    String? userId,
    String? idCardImageUrl,
    String? selfieImageUrl,
    String? userFullName,
    VerificationStatusType? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return IdentityVerification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      idCardImageUrl: idCardImageUrl ?? this.idCardImageUrl,
      selfieImageUrl: selfieImageUrl ?? this.selfieImageUrl,
      userFullName: userFullName ?? this.userFullName,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      extractedName: extractedName,
      extractedBirthDate: extractedBirthDate,
      faceMatchScore: faceMatchScore,
      livenessPassed: livenessPassed,
    );
  }

  factory IdentityVerification.fromMap(Map<String, dynamic> map, {String? registeredFullName}) {
    return IdentityVerification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      idCardImageUrl: (map['id_card_image_url'] ?? '') as String,
      selfieImageUrl: (map['selfie_image_url'] ?? '') as String,
      userFullName: registeredFullName ?? (map['user_full_name'] as String?),
      status: VerificationStatusType.fromDbValue(
        (map['status'] as String?) ?? 'PENDING',
      ),
      rejectionReason: map['rejection_reason'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'] as String)
          : null,
      reviewedBy: map['reviewed_by'] as String?,
      extractedName: map['extracted_name'] as String?,
      extractedBirthDate: map['extracted_birth_date'] != null
          ? DateTime.parse(map['extracted_birth_date'] as String)
          : null,
      faceMatchScore: map['face_match_score'] != null
          ? (map['face_match_score'] as num).toDouble()
          : null,
      livenessPassed: map['liveness_passed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'id_card_image_url': idCardImageUrl,
      'selfie_image_url': selfieImageUrl,
      'status': status.toDbValue(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
    };
  }
}
