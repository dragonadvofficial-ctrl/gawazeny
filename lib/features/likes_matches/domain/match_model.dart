import '../../profile/domain/user_profile.dart';

/// Domain model representing a like from the `likes` table.
class LikeRecord {
  final String id;
  final String fromUserId;
  final String toUserId;
  final DateTime createdAt;

  const LikeRecord({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
  });

  factory LikeRecord.fromMap(Map<String, dynamic> map) {
    return LikeRecord(
      id: map['id'] as String,
      fromUserId: map['from_user_id'] as String,
      toUserId: map['to_user_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
    };
  }
}

/// Domain model representing a verified mutual match from the `matches` table.
class MatchRecord {
  final String id;
  final String userOne;
  final String userTwo;
  final bool isActive;
  final DateTime createdAt;

  const MatchRecord({
    required this.id,
    required this.userOne,
    required this.userTwo,
    this.isActive = true,
    required this.createdAt,
  });

  factory MatchRecord.fromMap(Map<String, dynamic> map) {
    return MatchRecord(
      id: map['id'] as String,
      userOne: map['user_one'] as String,
      userTwo: map['user_two'] as String,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_one': userOne,
      'user_two': userTwo,
      'is_active': isActive,
    };
  }

  /// Returns the other user's ID given the current user's ID.
  String getPartnerId(String currentUserId) {
    return currentUserId == userOne ? userTwo : userOne;
  }
}

/// Domain representation of a mutual match with loaded partner profile & photo.
class MutualMatch {
  final String matchId;
  final UserProfile partnerProfile;
  final String? primaryPhotoUrl;
  final DateTime matchedAt;
  final bool isActive;

  const MutualMatch({
    required this.matchId,
    required this.partnerProfile,
    this.primaryPhotoUrl,
    required this.matchedAt,
    this.isActive = true,
  });

  factory MutualMatch.fromRpcMap(Map<String, dynamic> map) {
    final partner = UserProfile(
      id: map['partner_id'] as String,
      fullName: map['full_name'] as String? ?? 'شريك متوافق',
      gender: GenderType.fromDbValue(map['gender'] as String? ?? 'FEMALE'),
      birthDate: DateTime.now().subtract(Duration(days: ((map['age'] as int? ?? 25) * 365.25).round())),
      age: map['age'] as int?,
      nationality: 'مصري',
      residenceCity: map['residence_city'] as String? ?? 'القاهرة',
      maritalStatus: MaritalStatusType.fromDbValue(map['marital_status'] as String? ?? 'SINGLE'),
      jobTitle: map['job_title'] as String?,
      verificationStatus: VerificationStatusType.fromDbValue(map['verification_status'] as String? ?? 'UNVERIFIED'),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return MutualMatch(
      matchId: map['match_id'] as String,
      partnerProfile: partner,
      primaryPhotoUrl: map['photo_url'] as String?,
      matchedAt: map['matched_at'] != null 
          ? DateTime.parse(map['matched_at'] as String) 
          : DateTime.now(),
      isActive: true,
    );
  }
}

/// Domain representation of an incoming like from another candidate.
class ReceivedLike {
  final String likeId;
  final UserProfile senderProfile;
  final String? primaryPhotoUrl;
  final DateTime likedAt;

  const ReceivedLike({
    required this.likeId,
    required this.senderProfile,
    this.primaryPhotoUrl,
    required this.likedAt,
  });

  factory ReceivedLike.fromRpcMap(Map<String, dynamic> map) {
    final sender = UserProfile(
      id: map['sender_id'] as String,
      fullName: map['full_name'] as String? ?? 'مرسل الإعجاب',
      gender: GenderType.fromDbValue(map['gender'] as String? ?? 'FEMALE'),
      birthDate: DateTime.now().subtract(Duration(days: ((map['age'] as int? ?? 25) * 365.25).round())),
      age: map['age'] as int?,
      nationality: 'مصري',
      residenceCity: map['residence_city'] as String? ?? 'القاهرة',
      maritalStatus: MaritalStatusType.fromDbValue(map['marital_status'] as String? ?? 'SINGLE'),
      jobTitle: map['job_title'] as String?,
      verificationStatus: VerificationStatusType.fromDbValue(map['verification_status'] as String? ?? 'UNVERIFIED'),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return ReceivedLike(
      likeId: map['like_id'] as String,
      senderProfile: sender,
      primaryPhotoUrl: map['photo_url'] as String?,
      likedAt: map['liked_at'] != null 
          ? DateTime.parse(map['liked_at'] as String) 
          : DateTime.now(),
    );
  }
}

/// Domain representation of an outgoing like sent by the current user.
class SentLike {
  final String likeId;
  final UserProfile targetProfile;
  final String? primaryPhotoUrl;
  final DateTime likedAt;

  const SentLike({
    required this.likeId,
    required this.targetProfile,
    this.primaryPhotoUrl,
    required this.likedAt,
  });

  factory SentLike.fromRpcMap(Map<String, dynamic> map) {
    final target = UserProfile(
      id: map['target_id'] as String,
      fullName: map['full_name'] as String? ?? 'الشريك المرغوب',
      gender: GenderType.fromDbValue(map['gender'] as String? ?? 'FEMALE'),
      birthDate: DateTime.now().subtract(Duration(days: ((map['age'] as int? ?? 25) * 365.25).round())),
      age: map['age'] as int?,
      nationality: 'مصري',
      residenceCity: map['residence_city'] as String? ?? 'القاهرة',
      maritalStatus: MaritalStatusType.fromDbValue(map['marital_status'] as String? ?? 'SINGLE'),
      jobTitle: map['job_title'] as String?,
      verificationStatus: VerificationStatusType.fromDbValue(map['verification_status'] as String? ?? 'UNVERIFIED'),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return SentLike(
      likeId: map['like_id'] as String,
      targetProfile: target,
      primaryPhotoUrl: map['photo_url'] as String?,
      likedAt: map['liked_at'] != null 
          ? DateTime.parse(map['liked_at'] as String) 
          : DateTime.now(),
    );
  }
}

/// Encapsulates the outcome of liking a candidate.
class LikeResult {
  final bool isMatch;
  final String? matchId;
  final String? partnerName;
  final String? partnerPhotoUrl;
  final UserProfile? partnerProfile;

  const LikeResult({
    required this.isMatch,
    this.matchId,
    this.partnerName,
    this.partnerPhotoUrl,
    this.partnerProfile,
  });

  factory LikeResult.fromRpcJson(Map<String, dynamic> json, {UserProfile? fallbackProfile}) {
    return LikeResult(
      isMatch: json['is_match'] as bool? ?? false,
      matchId: json['match_id'] as String?,
      partnerName: json['partner_name'] as String? ?? fallbackProfile?.fullName,
      partnerPhotoUrl: json['partner_photo'] as String?,
      partnerProfile: fallbackProfile,
    );
  }
}
