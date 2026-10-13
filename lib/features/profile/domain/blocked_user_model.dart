/// Domain model representing a blocked user profile.
class BlockedUserModel {
  final String id;
  final String blockedUserId;
  final String fullName;
  final String residenceCity;
  final String? photoUrl;
  final DateTime blockedAt;

  const BlockedUserModel({
    required this.id,
    required this.blockedUserId,
    required this.fullName,
    required this.residenceCity,
    this.photoUrl,
    required this.blockedAt,
  });

  factory BlockedUserModel.fromMap(Map<String, dynamic> map) {
    return BlockedUserModel(
      id: (map['block_id'] ?? map['id']) as String,
      blockedUserId: (map['blocked_user_id'] ?? map['blocked_id']) as String,
      fullName: (map['full_name'] as String?) ?? 'مستخدم محظور',
      residenceCity: (map['residence_city'] as String?) ?? 'غير محدد',
      photoUrl: map['photo_url'] as String?,
      blockedAt: map['blocked_at'] != null
          ? DateTime.parse(map['blocked_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'blocked_user_id': blockedUserId,
      'full_name': fullName,
      'residence_city': residenceCity,
      'photo_url': photoUrl,
      'blocked_at': blockedAt.toIso8601String(),
    };
  }
}
