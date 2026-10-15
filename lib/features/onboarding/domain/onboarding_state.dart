import 'dart:typed_data';
import '../../profile/domain/user_profile.dart';

/// Draft state model representing the multi-step onboarding wizard.
class OnboardingState {
  final int currentStep;
  final bool isSubmitting;
  final String? errorMessage;

  // Step 1: Basic Details (الأساسيات)
  final String fullName;
  final GenderType gender;
  final DateTime? birthDate;
  final String nationality;
  final String residenceCity;
  final MaritalStatusType maritalStatus;

  // Step 2: Professional & Physical (التعليم والعمل والمواصفات)
  final String jobTitle;
  final String educationLevel;
  final int heightCm;
  final int weightKg;

  // Step 3: Lifestyle & Values (نمط الحياة والالتزام)
  final bool smoker;
  final String prays;
  final bool wantsChildren;
  final String bio;

  // Step 4: Partner Preferences (مواصفات شريك الحياة)
  final int minAge;
  final int maxAge;
  final List<MaritalStatusType> acceptableMaritalStatuses;
  final List<String> acceptableCities;
  final bool mustPray;
  final bool acceptsSmokers;

  // Step 5: Profile Photo (الصورة الشخصية)
  final Uint8List? photoBytes;
  final String? photoFileName;
  final String? uploadedPhotoUrl;

  const OnboardingState({
    this.currentStep = 0,
    this.isSubmitting = false,
    this.errorMessage,
    this.fullName = '',
    this.gender = GenderType.male,
    this.birthDate,
    this.nationality = 'مصري',
    this.residenceCity = 'القاهرة',
    this.maritalStatus = MaritalStatusType.single,
    this.jobTitle = '',
    this.educationLevel = 'مؤهل جامعي / بكالوريوس',
    this.heightCm = 175,
    this.weightKg = 75,
    this.smoker = false,
    this.prays = 'محافظ على الصلاة في المسجد',
    this.wantsChildren = true,
    this.bio = '',
    this.minAge = 20,
    this.maxAge = 35,
    this.acceptableMaritalStatuses = const [MaritalStatusType.single],
    this.acceptableCities = const ['القاهرة', 'الجيزة', 'الإسكندرية'],
    this.mustPray = true,
    this.acceptsSmokers = false,
    this.photoBytes,
    this.photoFileName,
    this.uploadedPhotoUrl,
  });

  /// Automatically computes age from the selected birth date.
  int? get calculatedAge {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  /// Step 1 validation: Full name required, birth date set and adult (age >= 18).
  bool get isStep1Valid {
    if (fullName.trim().length < 3) return false;
    if (birthDate == null) return false;
    final age = calculatedAge;
    if (age == null || age < 18) return false;
    if (nationality.trim().isEmpty) return false;
    if (residenceCity.trim().isEmpty) return false;
    return true;
  }

  /// Step 2 validation: Job title not empty.
  bool get isStep2Valid {
    return jobTitle.trim().isNotEmpty && educationLevel.trim().isNotEmpty;
  }

  /// Step 3 validation: Prayer commitment specified and bio with at least 10 chars.
  bool get isStep3Valid {
    return prays.trim().isNotEmpty && bio.trim().length >= 10;
  }

  /// Step 4 validation: Valid age range and at least one marital status accepted.
  bool get isStep4Valid {
    return minAge >= 18 &&
        maxAge >= minAge &&
        acceptableMaritalStatuses.isNotEmpty &&
        acceptableCities.isNotEmpty;
  }

  /// Step 5 validation: Photo selected or uploaded.
  bool get isStep5Valid {
    return photoBytes != null || uploadedPhotoUrl != null;
  }

  OnboardingState copyWith({
    int? currentStep,
    bool? isSubmitting,
    String? errorMessage,
    String? fullName,
    GenderType? gender,
    DateTime? birthDate,
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
    int? minAge,
    int? maxAge,
    List<MaritalStatusType>? acceptableMaritalStatuses,
    List<String>? acceptableCities,
    bool? mustPray,
    bool? acceptsSmokers,
    Uint8List? photoBytes,
    String? photoFileName,
    String? uploadedPhotoUrl,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
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
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      acceptableMaritalStatuses:
          acceptableMaritalStatuses ?? this.acceptableMaritalStatuses,
      acceptableCities: acceptableCities ?? this.acceptableCities,
      mustPray: mustPray ?? this.mustPray,
      acceptsSmokers: acceptsSmokers ?? this.acceptsSmokers,
      photoBytes: photoBytes ?? this.photoBytes,
      photoFileName: photoFileName ?? this.photoFileName,
      uploadedPhotoUrl: uploadedPhotoUrl ?? this.uploadedPhotoUrl,
    );
  }
}
