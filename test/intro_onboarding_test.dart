import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gawezeny/core/constants/app_strings.dart';
import 'package:gawezeny/core/localization/app_translations.dart';
import 'package:gawezeny/core/network/auth_gate.dart';
import 'package:gawezeny/core/network/supabase_client.dart';
import 'package:gawezeny/features/auth/presentation/login_screen.dart';
import 'package:gawezeny/features/onboarding/presentation/intro_onboarding_controller.dart';
import 'package:gawezeny/features/onboarding/presentation/intro_onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestableWidget({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IntroOnboardingNotifier State and Persistence Tests', () {
    test('Defaults to false and saves true to SharedPreferences on completeIntro', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(introOnboardingProvider), isFalse);

      await container.read(introOnboardingProvider.notifier).completeIntro();

      expect(container.read(introOnboardingProvider), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(IntroOnboardingNotifier.keyCompleted), isTrue);
    });

    test('resetIntro restores state to false and removes key', () async {
      SharedPreferences.setMockInitialValues({
        IntroOnboardingNotifier.keyCompleted: true,
      });

      final container = ProviderContainer(
        overrides: [
          introOnboardingProvider.overrideWith(
            (ref) => IntroOnboardingNotifier(true),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(introOnboardingProvider), isTrue);

      await container.read(introOnboardingProvider.notifier).resetIntro();

      expect(container.read(introOnboardingProvider), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(IntroOnboardingNotifier.keyCompleted), isNull);
    });
  });

  group('IntroOnboardingScreen Widget Tests', () {
    testWidgets('Renders first onboarding screen with "التالي" and "تخطي"',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestableWidget(
          child: const IntroOnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check buttons for Screen 1
      expect(find.text(AppTranslations.tr('next', localeCode: 'ar')), findsOneWidget);
      expect(find.text(AppTranslations.tr('skip', localeCode: 'ar')), findsOneWidget);
      expect(find.text(AppTranslations.tr('startYourJourneyNow', localeCode: 'ar')), findsNothing);

      // Verify Image is present
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets(
        'Stepping sequentially through all 6 screens updates buttons and reaches "ابدأ رحلتك الآن"',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestableWidget(
          child: const IntroOnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final nextFinder = find.text(AppTranslations.tr('next', localeCode: 'ar'));
      final skipFinder = find.text(AppTranslations.tr('skip', localeCode: 'ar'));
      final startFinder =
          find.text(AppTranslations.tr('startYourJourneyNow', localeCode: 'ar'));

      // Screen 1: Next + Skip present, Start not present
      expect(nextFinder, findsOneWidget);
      expect(skipFinder, findsOneWidget);
      expect(startFinder, findsNothing);

      // Tap Next -> Screen 2
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
      expect(nextFinder, findsOneWidget);
      expect(skipFinder, findsOneWidget);
      expect(startFinder, findsNothing);

      // Tap Next -> Screen 3
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
      expect(nextFinder, findsOneWidget);
      expect(skipFinder, findsOneWidget);
      expect(startFinder, findsNothing);

      // Tap Next -> Screen 4
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
      expect(nextFinder, findsOneWidget);
      expect(skipFinder, findsOneWidget);
      expect(startFinder, findsNothing);

      // Tap Next -> Screen 5
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
      expect(nextFinder, findsOneWidget);
      expect(skipFinder, findsOneWidget);
      expect(startFinder, findsNothing);

      // Tap Next -> Screen 6 (Final Screen)
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();

      // On Screen 6: ONLY "ابدأ رحلتك الآن" should be present!
      expect(startFinder, findsOneWidget);
      expect(nextFinder, findsNothing);
      expect(skipFinder, findsNothing);
    });

    testWidgets('Tapping "تخطي" on early screen completes intro',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, _) => const MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: IntroOnboardingScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(introOnboardingProvider), isFalse);

      final skipFinder = find.text(AppTranslations.tr('skip', localeCode: 'ar'));
      await tester.tap(skipFinder);
      await tester.pumpAndSettle();

      expect(container.read(introOnboardingProvider), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(IntroOnboardingNotifier.keyCompleted), isTrue);
    });

    testWidgets('Tapping "ابدأ رحلتك الآن" on final screen completes intro',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, _) => const MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: IntroOnboardingScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to screen 6
      final nextFinder = find.text(AppTranslations.tr('next', localeCode: 'ar'));
      for (int i = 0; i < 5; i++) {
        await tester.tap(nextFinder);
        await tester.pumpAndSettle();
      }

      final startFinder =
          find.text(AppTranslations.tr('startYourJourneyNow', localeCode: 'ar'));
      expect(startFinder, findsOneWidget);

      await tester.tap(startFinder);
      await tester.pumpAndSettle();

      expect(container.read(introOnboardingProvider), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(IntroOnboardingNotifier.keyCompleted), isTrue);
    });
  });

  group('AuthGate Routing Flow Tests', () {
    testWidgets(
        'Shows IntroOnboardingScreen when introOnboardingProvider is false',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestableWidget(
          child: const AuthGate(),
          overrides: [
            introOnboardingProvider.overrideWith(
              (ref) => IntroOnboardingNotifier(false),
            ),
            currentUserProvider.overrideWith((ref) => null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IntroOnboardingScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets(
        'Shows LoginScreen directly when introOnboardingProvider is true and user is unauthenticated',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestableWidget(
          child: const AuthGate(),
          overrides: [
            introOnboardingProvider.overrideWith(
              (ref) => IntroOnboardingNotifier(true),
            ),
            currentUserProvider.overrideWith((ref) => null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IntroOnboardingScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Responsive Screen Size Tests for IntroOnboardingScreen', () {
    testWidgets('Renders properly without overflow on small device (375x667)',
        (tester) async {
      tester.view.physicalSize = const Size(375 * 2, 667 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestableWidget(
          child: const IntroOnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.next), findsOneWidget);
      expect(find.text(AppStrings.skip), findsOneWidget);
    });

    testWidgets('Renders properly without overflow on large phone (428x926)',
        (tester) async {
      tester.view.physicalSize = const Size(428 * 3, 926 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestableWidget(
          child: const IntroOnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.next), findsOneWidget);
      expect(find.text(AppStrings.skip), findsOneWidget);
    });

    testWidgets('Renders properly without overflow on tablet (800x1280)',
        (tester) async {
      tester.view.physicalSize = const Size(800 * 1.5, 1280 * 1.5);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestableWidget(
          child: const IntroOnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.next), findsOneWidget);
      expect(find.text(AppStrings.skip), findsOneWidget);
    });
  });
}
