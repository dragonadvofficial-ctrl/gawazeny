enum GenderType {
  male,
  female;

  String toDbValue() => this == GenderType.male ? 'MALE' : 'FEMALE';

  static GenderType fromDbValue(String value) {
    return value.toUpperCase() == 'FEMALE' ? GenderType.female : GenderType.male;
  }
}

enum MaritalStatusType {
  single,
  divorced,
  widowed;

  String toDbValue() {
    switch (this) {
      case MaritalStatusType.single:
        return 'SINGLE';
      case MaritalStatusType.divorced:
        return 'DIVORCED';
      case MaritalStatusType.widowed:
        return 'WIDOWED';
    }
  }

  static MaritalStatusType fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'DIVORCED':
        return MaritalStatusType.divorced;
      case 'WIDOWED':
        return MaritalStatusType.widowed;
      case 'SINGLE':
      default:
        return MaritalStatusType.single;
    }
  }
}

enum VerificationStatusType {
  unverified,
  pending,
  verified,
  failed,
  manualReview;

  String toDbValue() {
    switch (this) {
      case VerificationStatusType.unverified:
        return 'UNVERIFIED';
      case VerificationStatusType.pending:
        return 'PENDING';
      case VerificationStatusType.verified:
        return 'VERIFIED';
      case VerificationStatusType.failed:
        return 'FAILED';
      case VerificationStatusType.manualReview:
        return 'MANUAL_REVIEW';
    }
  }

  static VerificationStatusType fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return VerificationStatusType.pending;
      case 'VERIFIED':
        return VerificationStatusType.verified;
      case 'FAILED':
        return VerificationStatusType.failed;
      case 'MANUAL_REVIEW':
        return VerificationStatusType.manualReview;
      case 'UNVERIFIED':
      default:
        return VerificationStatusType.unverified;
    }
  }
}

enum SubscriptionStatusType {
  free,
  pendingPayment,
  active,
  expired,
  cancelled,
  paymentFailed;

  String toDbValue() {
    switch (this) {
      case SubscriptionStatusType.free:
        return 'FREE';
      case SubscriptionStatusType.pendingPayment:
        return 'PENDING_PAYMENT';
      case SubscriptionStatusType.active:
        return 'ACTIVE';
      case SubscriptionStatusType.expired:
        return 'EXPIRED';
      case SubscriptionStatusType.cancelled:
        return 'CANCELLED';
      case SubscriptionStatusType.paymentFailed:
        return 'PAYMENT_FAILED';
    }
  }

  static SubscriptionStatusType fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING_PAYMENT':
        return SubscriptionStatusType.pendingPayment;
      case 'ACTIVE':
        return SubscriptionStatusType.active;
      case 'EXPIRED':
        return SubscriptionStatusType.expired;
      case 'CANCELLED':
        return SubscriptionStatusType.cancelled;
      case 'PAYMENT_FAILED':
        return SubscriptionStatusType.paymentFailed;
      case 'FREE':
      default:
        return SubscriptionStatusType.free;
    }
  }

  String get titleArabic {
    switch (this) {
      case SubscriptionStatusType.free:
        return 'الباقة المجانية';
      case SubscriptionStatusType.pendingPayment:
        return 'بانتظار تأكيد الدفع';
      case SubscriptionStatusType.active:
        return 'اشتراك نشط';
      case SubscriptionStatusType.expired:
        return 'منتهي الصلاحية';
      case SubscriptionStatusType.cancelled:
        return 'ملغي';
      case SubscriptionStatusType.paymentFailed:
        return 'فشلت عملية الدفع';
    }
  }

  bool get isSubscribed => this == SubscriptionStatusType.active;
}

/// Domain model representing a user profile from the `profiles` table.
class UserProfile {
  final String id;
  final String fullName;
  final GenderType gender;
  final DateTime birthDate;
  final int? age;
  final String nationality;
  final String residenceCity;
  final MaritalStatusType maritalStatus;
  final String? jobTitle;
  final String? educationLevel;
  final int? heightCm;
  final int? weightKg;
  final bool smoker;
  final String? prays;
  final bool wantsChildren;
  final String? bio;
  final VerificationStatusType verificationStatus;
  final SubscriptionStatusType subscriptionStatus;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.gender,
    required this.birthDate,
    this.age,
    required this.nationality,
    required this.residenceCity,
    required this.maritalStatus,
    this.jobTitle,
    this.educationLevel,
    this.heightCm,
    this.weightKg,
    this.smoker = false,
    this.prays,
    this.wantsChildren = true,
    this.bio,
    this.verificationStatus = VerificationStatusType.unverified,
    this.subscriptionStatus = SubscriptionStatusType.free,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isVerified => verificationStatus == VerificationStatusType.verified;
  bool get isSubscribed => subscriptionStatus == SubscriptionStatusType.active;

  UserProfile copyWith({
    String? id,
    String? fullName,
    GenderType? gender,
    DateTime? birthDate,
    int? age,
    String? nationality,
    String? residenceCity,
    MaritalStatusType? maritalStatus,
    String? jobTitle,
    String? educationLevel,
    int? heightCm,
    int? weightKg,
    bool? smoker,
    String? prays,
    bool? wantsChildren,
    String? bio,
    VerificationStatusType? verificationStatus,
    SubscriptionStatusType? subscriptionStatus,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
      nationality: nationality ?? this.nationality,
      residenceCity: residenceCity ?? this.residenceCity,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      jobTitle: jobTitle ?? this.jobTitle,
      educationLevel: educationLevel ?? this.educationLevel,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      smoker: smoker ?? this.smoker,
      prays: prays ?? this.prays,
      wantsChildren: wantsChildren ?? this.wantsChildren,
      bio: bio ?? this.bio,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      gender: GenderType.fromDbValue(map['gender'] as String),
      birthDate: DateTime.parse(map['birth_date'] as String),
      age: map['age'] != null ? (map['age'] as num).toInt() : null,
      nationality: map['nationality'] as String,
      residenceCity: map['residence_city'] as String,
      maritalStatus: MaritalStatusType.fromDbValue(map['marital_status'] as String),
      jobTitle: map['job_title'] as String?,
      educationLevel: map['education_level'] as String?,
      heightCm: map['height_cm'] != null ? (map['height_cm'] as num).toInt() : null,
      weightKg: map['weight_kg'] != null ? (map['weight_kg'] as num).toInt() : null,
      smoker: map['smoker'] as bool? ?? false,
      prays: map['prays'] as String?,
      wantsChildren: map['wants_children'] as bool? ?? true,
      bio: map['bio'] as String?,
      verificationStatus: VerificationStatusType.fromDbValue(
        (map['verification_status'] as String?) ?? 'UNVERIFIED',
      ),
      subscriptionStatus: SubscriptionStatusType.fromDbValue(
        (map['subscription_status'] as String?) ?? 'FREE',
      ),
      photoUrl: (map['photo_url'] ?? map['photoUrl']) as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'gender': gender.toDbValue(),
      'birth_date': birthDate.toIso8601String().split('T').first,
      'nationality': nationality,
      'residence_city': residenceCity,
      'marital_status': maritalStatus.toDbValue(),
      'job_title': jobTitle,
      'education_level': educationLevel,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'smoker': smoker,
      'prays': prays,
      'wants_children': wantsChildren,
      'bio': bio,
      'verification_status': verificationStatus.toDbValue(),
      'subscription_status': subscriptionStatus.toDbValue(),
      'photo_url': photoUrl,
    };
  }
}
