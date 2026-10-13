import '../../profile/domain/user_profile.dart';

/// Domain model representing identity verification requests from the `identity_verifications` table.
class IdentityVerification {
  final String id;
  final String userId;
  final String idCardImageUrl;
  final String selfieImageUrl;
  final String? extractedName;
  final DateTime? extractedBirthDate;
  final double? faceMatchScore;
  final bool livenessPassed;
  final VerificationStatusType status;
  final String? rejectionReason;
  final DateTime createdAt;

  const IdentityVerification({
    required this.id,
    required this.userId,
    required this.idCardImageUrl,
    required this.selfieImageUrl,
    this.extractedName,
    this.extractedBirthDate,
    this.faceMatchScore,
    this.livenessPassed = false,
    this.status = VerificationStatusType.pending,
    this.rejectionReason,
    required this.createdAt,
  });

  factory IdentityVerification.fromMap(Map<String, dynamic> map) {
    return IdentityVerification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      idCardImageUrl: map['id_card_image_url'] as String,
      selfieImageUrl: map['selfie_image_url'] as String,
      extractedName: map['extracted_name'] as String?,
      extractedBirthDate: map['extracted_birth_date'] != null
          ? DateTime.parse(map['extracted_birth_date'] as String)
          : null,
      faceMatchScore: map['face_match_score'] != null
          ? (map['face_match_score'] as num).toDouble()
          : null,
      livenessPassed: map['liveness_passed'] as bool? ?? false,
      status: VerificationStatusType.fromDbValue(
        (map['status'] as String?) ?? 'PENDING',
      ),
      rejectionReason: map['rejection_reason'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'id_card_image_url': idCardImageUrl,
      'selfie_image_url': selfieImageUrl,
      'extracted_name': extractedName,
      'extracted_birth_date': extractedBirthDate?.toIso8601String().split('T').first,
      'face_match_score': faceMatchScore,
      'liveness_passed': livenessPassed,
      'status': status.toDbValue(),
      'rejection_reason': rejectionReason,
    };
  }
}
