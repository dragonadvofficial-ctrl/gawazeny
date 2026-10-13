import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gawezeny/core/localization/app_locale_controller.dart';
import 'package:gawezeny/core/localization/app_translations.dart';
import 'package:gawezeny/core/theme/app_theme.dart';
import 'package:gawezeny/features/profile/presentation/profile_controller.dart';
import 'package:gawezeny/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test MainNavigationShell locale switching with ProfileScreen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) {
            final currentLocale = ref.watch(localeProvider);
            return ScreenUtilInit(
              designSize: const Size(390, 844),
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (ctx, child) {
                return MaterialApp(
                  theme: AppTheme.lightTheme,
                  locale: currentLocale,
                  supportedLocales: const [
                    Locale('ar', 'EG'),
                    Locale('ar'),
                    Locale('en', 'US'),
                    Locale('en'),
                  ],
                  localizationsDelegates: const [
                    AppLocalizationsDelegate(),
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  home: const MainNavigationShell(),
                );
              },
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to profile tab (index 3)
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();

    // Check Arabic text is present
    expect(find.text('ملفي الشخصي'), findsWidgets);
    expect(find.text('إدارة الحساب والتوافقات'), findsOneWidget);

    // Now change language to English via controller
    await container.read(profileControllerProvider.notifier).setLanguage('en');
    await tester.pumpAndSettle();

    // Print all texts found on screen
    final allTexts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
    debugPrint('Found texts after en: $allTexts');

    expect(find.text('My Profile'), findsWidgets);
    expect(find.text('Account & Matching Management'), findsOneWidget);

    // Now change language back to Arabic to ensure bidirectional reactivity
    await container.read(profileControllerProvider.notifier).setLanguage('ar');
    await tester.pumpAndSettle();

    expect(find.text('ملفي الشخصي'), findsWidgets);
    expect(find.text('إدارة الحساب والتوافقات'), findsOneWidget);
  });
}
