import 'dart:typed_data';
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

  OnboardingController(this._repository, this._ref) : super(const OnboardingState());

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
    state = state.copyWith(residenceCity: value);
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
      if (list.length > 1) list.remove(city);
    } else {
      list.add(city);
    }
    state = state.copyWith(acceptableCities: list);
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

      // 1. Upload photo if binary is present
      if (state.photoBytes != null) {
        final extension = state.photoFileName?.split('.').last ?? 'jpg';
        photoUrl = await _repository.uploadProfilePhoto(
          bytes: state.photoBytes!,
          userId: userId,
          fileExtension: extension,
        );
        state = state.copyWith(uploadedPhotoUrl: photoUrl);
      }

      final now = DateTime.now();

      // 2. Persist User Profile
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
        createdAt: now,
        updatedAt: now,
      );
      await _repository.saveProfile(profile);

      // 3. Persist Partner Preferences
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

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
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
