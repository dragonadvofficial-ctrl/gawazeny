import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gawezeny/core/localization/app_translations.dart';
import 'package:gawezeny/features/onboarding/presentation/onboarding_controller.dart';

void main() {
  group('Step 1 Placeholder & Translations', () {
    test('fullNameHint Arabic is exactly مثال: محمود محمد محمود حسن', () {
      final hint = AppTranslations.tr('fullNameHint', localeCode: 'ar');
      expect(hint, equals('مثال: محمود محمد محمود حسن'));
    });
  });

  group('Onboarding Governorates & State Retention', () {
    test('Residence city from Step 1 is automatically preserved in acceptableCities', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(onboardingControllerProvider.notifier);

      // User sets residence city in Step 1 to Alexandria
      controller.setResidenceCity('الإسكندرية');

      var state = container.read(onboardingControllerProvider);
      expect(state.residenceCity, equals('الإسكندرية'));
      expect(state.acceptableCities.contains('الإسكندرية'), isTrue);

      // User moves from Step 1 -> 2 -> 3 -> 4
      controller.nextStep(); // to Step 2
      controller.nextStep(); // to Step 3
      controller.nextStep(); // to Step 4

      state = container.read(onboardingControllerProvider);
      expect(state.currentStep, equals(3)); // 0-indexed Step 4
      expect(state.acceptableCities.contains('الإسكندرية'), isTrue);

      // User toggles another governorate in Step 4
      controller.toggleCity('الدقهلية');
      state = container.read(onboardingControllerProvider);
      expect(state.acceptableCities.contains('الدقهلية'), isTrue);
      expect(state.acceptableCities.contains('الإسكندرية'), isTrue);

      // User goes Back to Step 3, then Back to Step 2, then Next to Step 4
      controller.previousStep();
      expect(container.read(onboardingControllerProvider).currentStep, equals(2));
      controller.previousStep();
      expect(container.read(onboardingControllerProvider).currentStep, equals(1));
      controller.nextStep();
      controller.nextStep();
      expect(container.read(onboardingControllerProvider).currentStep, equals(3));

      // Choices MUST BE RETAINED!
      final finalState = container.read(onboardingControllerProvider);
      expect(finalState.acceptableCities.contains('الإسكندرية'), isTrue);
      expect(finalState.acceptableCities.contains('الدقهلية'), isTrue);
    });

    test('Governorate quick actions (select all, only residence, clear) function properly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(onboardingControllerProvider.notifier);
      controller.setResidenceCity('طنطا');

      // Select all
      controller.selectAllCities(['القاهرة', 'الجيزة', 'الإسكندرية', 'طنطا', 'أسوان']);
      expect(container.read(onboardingControllerProvider).acceptableCities.length, equals(5));

      // Select only residence city
      controller.selectOnlyResidenceCity();
      expect(container.read(onboardingControllerProvider).acceptableCities, equals(['طنطا']));

      // Clear
      controller.clearCities();
      expect(container.read(onboardingControllerProvider).acceptableCities, isEmpty);
    });
  });
}
