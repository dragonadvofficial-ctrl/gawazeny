import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../matching/domain/partner_preferences.dart';
import '../../profile/domain/user_profile.dart';
import '../data/onboarding_repository.dart';
import '../domain/onboarding_state.dart';

import '../../../core/network/auth_gate.dart';

/// StateNotifier orchestrating multi-step onboarding wizard navigation and final submission.
class OnboardingController extends StateNotifier<OnboardingState> {
  final OnboardingRepository _repository;
  final Ref _ref;
  bool _hasLoadedExisting = false;

  OnboardingController(this._repository, this._ref) : super(const OnboardingState());

  /// Loads existing profile and partner preferences from Supabase if available.
  Future<void> loadExistingData(String userId) async {
    if (_hasLoadedExisting) return;
    _hasLoadedExisting = true;

    try {
      final profile = await _repository.getProfile(userId);
      final preferences = await _repository.getPreferences(userId);
      final photoUrl = await _repository.getPrimaryPhotoUrl(userId);

      if (profile != null || preferences != null || photoUrl != null) {
        // Pre-fill state with saved data
        final currentCities = preferences?.acceptableCities ?? state.acceptableCities;
        final resCity = profile?.residenceCity.trim() ?? state.residenceCity;

        final citiesList = List<String>.from(currentCities);
        if (resCity.isNotEmpty && !citiesList.contains(resCity)) {
          citiesList.insert(0, resCity);
        }

        state = state.copyWith(
          fullName: profile?.fullName ?? state.fullName,
          gender: profile?.gender ?? state.gender,
          birthDate: profile?.birthDate ?? state.birthDate,
          nationality: profile?.nationality ?? state.nationality,
          residenceCity: resCity,
          maritalStatus: profile?.maritalStatus ?? state.maritalStatus,
          jobTitle: profile?.jobTitle ?? state.jobTitle,
          educationLevel: profile?.educationLevel ?? state.educationLevel,
          heightCm: profile?.heightCm ?? state.heightCm,
          weightKg: profile?.weightKg ?? state.weightKg,
          smoker: profile?.smoker ?? state.smoker,
          prays: profile?.prays ?? state.prays,
          wantsChildren: profile?.wantsChildren ?? state.wantsChildren,
          bio: profile?.bio ?? state.bio,
          minAge: preferences?.minAge ?? state.minAge,
          maxAge: preferences?.maxAge ?? state.maxAge,
          acceptableMaritalStatuses: preferences?.acceptableMaritalStatuses ?? state.acceptableMaritalStatuses,
          acceptableCities: citiesList,
          mustPray: preferences?.mustPray ?? state.mustPray,
          acceptsSmokers: preferences?.acceptsSmokers ?? state.acceptsSmokers,
          uploadedPhotoUrl: photoUrl ?? profile?.photoUrl ?? state.uploadedPhotoUrl,
        );
      }
    } catch (e) {
      debugPrint('loadExistingData error: $e');
    }
  }

  // Navigation
  void nextStep() {
    if (state.currentStep < 4) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step <= 4) {
      state = state.copyWith(currentStep: step);
    }
  }

  // Step 1 Setters
  void setFullName(String value) {
    state = state.copyWith(fullName: value);
  }

  void setGender(GenderType value) {
    state = state.copyWith(gender: value);
  }

  void setBirthDate(DateTime value) {
    state = state.copyWith(birthDate: value);
  }

  void setNationality(String value) {
    state = state.copyWith(nationality: value);
  }

  void setResidenceCity(String value) {
    final updatedCities = List<String>.from(state.acceptableCities);
    if (value.isNotEmpty && !updatedCities.contains(value)) {
      updatedCities.add(value);
    }
    state = state.copyWith(
      residenceCity: value,
      acceptableCities: updatedCities,
    );
  }

  void setMaritalStatus(MaritalStatusType value) {
    state = state.copyWith(maritalStatus: value);
  }

  // Step 2 Setters
  void setJobTitle(String value) {
    state = state.copyWith(jobTitle: value);
  }

  void setEducationLevel(String value) {
    state = state.copyWith(educationLevel: value);
  }

  void setHeight(int value) {
    state = state.copyWith(heightCm: value);
  }

  void setWeight(int value) {
    state = state.copyWith(weightKg: value);
  }

  // Step 3 Setters
  void setSmoker(bool value) {
    state = state.copyWith(smoker: value);
  }

  void setPrays(String value) {
    state = state.copyWith(prays: value);
  }

  void setWantsChildren(bool value) {
    state = state.copyWith(wantsChildren: value);
  }

  void setBio(String value) {
    state = state.copyWith(bio: value);
  }

  // Step 4 Setters
  void setAgeRange(int min, int max) {
    state = state.copyWith(minAge: min, maxAge: max);
  }

  void toggleMaritalStatus(MaritalStatusType status) {
    final list = List<MaritalStatusType>.from(state.acceptableMaritalStatuses);
    if (list.contains(status)) {
      if (list.length > 1) list.remove(status);
    } else {
      list.add(status);
    }
    state = state.copyWith(acceptableMaritalStatuses: list);
  }

  void toggleCity(String city) {
    final list = List<String>.from(state.acceptableCities);
    if (list.contains(city)) {
      list.remove(city);
    } else {
      list.add(city);
    }
    state = state.copyWith(acceptableCities: list);
  }

  void selectAllCities(List<String> allCities) {
    state = state.copyWith(acceptableCities: List<String>.from(allCities));
  }

  void selectOnlyResidenceCity() {
    if (state.residenceCity.isNotEmpty) {
      state = state.copyWith(acceptableCities: [state.residenceCity]);
    }
  }

  void clearCities() {
    state = state.copyWith(acceptableCities: []);
  }

  void setMustPray(bool value) {
    state = state.copyWith(mustPray: value);
  }

  void setAcceptsSmokers(bool value) {
    state = state.copyWith(acceptsSmokers: value);
  }

  // Step 5 Setters
  void setPhoto(Uint8List bytes, String fileName) {
    state = state.copyWith(photoBytes: bytes, photoFileName: fileName);
  }

  /// Submits the completed profile, partner preferences, and avatar to Supabase.
  Future<bool> submitOnboarding(String userId) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      String? photoUrl = state.uploadedPhotoUrl;
      String? photoUploadWarning;

      // 1. Attempt to upload photo to storage if new bytes were provided
      if (state.photoBytes != null) {
        final extension = state.photoFileName?.split('.').last ?? 'jpg';
        try {
          photoUrl = await _repository.uploadProfilePhoto(
            bytes: state.photoBytes!,
            userId: userId,
            fileExtension: extension,
          );
          state = state.copyWith(uploadedPhotoUrl: photoUrl);
        } catch (photoErr) {
          debugPrint('Photo upload failed: $photoErr');
          final errStr = photoErr.toString();
          if (errStr.contains('403') ||
              errStr.contains('Unauthorized') ||
              errStr.contains('row-level security')) {
            photoUploadWarning =
                'تعذر رفع الصورة الشخصية بسبب صلاحيات التخزين (403 Unauthorized). يرجى التأكد من تشغيل ملف تهيئة التخزين fix_avatar_storage_rls.sql في Supabase.';
          } else {
            photoUploadWarning = 'تعذر رفع الصورة الشخصية: $photoErr';
          }
        }
      }

      final now = DateTime.now();

      // 2. Persist User Profile FIRST (including photoUrl so profile has avatar)
      final profile = UserProfile(
        id: userId,
        fullName: state.fullName.trim(),
        gender: state.gender,
        birthDate: state.birthDate ?? DateTime(2000, 1, 1),
        age: state.calculatedAge,
        nationality: state.nationality.trim(),
        residenceCity: state.residenceCity.trim(),
        maritalStatus: state.maritalStatus,
        jobTitle: state.jobTitle.trim(),
        educationLevel: state.educationLevel.trim(),
        heightCm: state.heightCm,
        weightKg: state.weightKg,
        smoker: state.smoker,
        prays: state.prays,
        wantsChildren: state.wantsChildren,
        bio: state.bio.trim(),
        verificationStatus: VerificationStatusType.unverified,
        subscriptionStatus: SubscriptionStatusType.free,
        photoUrl: photoUrl,
        createdAt: now,
        updatedAt: now,
      );
      await _repository.saveProfile(profile);

      // 3. Save profile photo record in profile_photos table
      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          await _repository.saveProfilePhotoRecord(
            userId: userId,
            photoUrl: photoUrl,
          );
        } catch (photoRecErr) {
          debugPrint('saveProfilePhotoRecord non-critical error: $photoRecErr');
        }
      }

      // 4. Persist Partner Preferences (including all chosen governorates)
      final preferences = PartnerPreferences(
        userId: userId,
        minAge: state.minAge,
        maxAge: state.maxAge,
        acceptableMaritalStatuses: state.acceptableMaritalStatuses,
        acceptableCities: state.acceptableCities,
        mustPray: state.mustPray,
        acceptsSmokers: state.acceptsSmokers,
        createdAt: now,
      );
      await _repository.savePreferences(preferences);

      // Invalidate profile completion to trigger reactive navigation in AuthGate
      _ref.invalidate(profileCompletionProvider(userId));

      if (photoUploadWarning != null) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: photoUploadWarning,
        );
        return false;
      }

      state = state.copyWith(isSubmitting: false, errorMessage: null);
      return true;
    } catch (e) {
      String errorMsg = e.toString();
      debugPrint('submitOnboarding error: $errorMsg');
      if (errorMsg.contains('403') || errorMsg.contains('Unauthorized')) {
        errorMsg =
            'حدث خطأ في صلاحيات الحفظ (403 Unauthorized). يرجى التأكد من تسجيل الدخول أو إعدادات قاعدة البيانات في Supabase.';
      } else if (errorMsg.contains('network') || errorMsg.contains('SocketException')) {
        errorMsg = 'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.';
      }
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: errorMsg,
      );
      return false;
    }
  }
}

/// Riverpod provider for [OnboardingController].
final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  final repository = ref.watch(onboardingRepositoryProvider);
  return OnboardingController(repository, ref);
});
