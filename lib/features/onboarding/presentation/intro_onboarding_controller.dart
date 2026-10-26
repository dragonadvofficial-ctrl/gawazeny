import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State notifier managing first-launch 6-screen onboarding introduction lifecycle.
class IntroOnboardingNotifier extends StateNotifier<bool> {
  IntroOnboardingNotifier(super.initialState);

  static const String keyCompleted = 'has_completed_onboarding';

  /// Mark the introductory onboarding as completed or skipped, persisting state across sessions.
  Future<void> completeIntro() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyCompleted, true);
    } catch (e, stackTrace) {
      developer.log(
        'Failed to save onboarding completion state to SharedPreferences: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Reset onboarding state back to uncompleted (useful for testing or cache reset).
  Future<void> resetIntro() async {
    state = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyCompleted);
    } catch (e, stackTrace) {
      developer.log(
        'Failed to reset onboarding state in SharedPreferences: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Riverpod provider for introductory onboarding state.
/// Can be overridden at startup in [ProviderScope] with pre-loaded value.
final introOnboardingProvider =
    StateNotifierProvider<IntroOnboardingNotifier, bool>((ref) {
  return IntroOnboardingNotifier(false);
});
