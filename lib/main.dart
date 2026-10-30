import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/localization/app_locale_controller.dart';
import 'core/localization/app_translations.dart';
import 'core/network/auth_gate.dart';
import 'core/preview/preview_config.dart';
import 'core/security/secure_local_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/chat/presentation/chat_inbox_screen.dart';
import 'features/likes_matches/presentation/matches_screen.dart';
import 'features/matching/presentation/matching_screen.dart';
import 'features/onboarding/presentation/intro_onboarding_controller.dart';
import 'features/profile/presentation/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase reading from string constants with SecureLocalStorage (C10)
  try {
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: SupabaseConstants.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: const SecureLocalStorage(),
      ),
      debug: false,
    );
  } catch (error, stackTrace) {
    developer.log(
      'Supabase initialization notice: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Enforce "Remember me on this device" policy on cold app launch
  try {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe =
        prefs.getBool('auth_remember_me_on_this_device') ?? false;
    if (!rememberMe) {
      // Discard stored local session if user did not opt into remembering session
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    }
  } catch (e) {
    developer.log('Remember-me cold launch session check notice: $e');
  }

  // Pre-fetch persistent language selection to eliminate flicker and guarantee correct startup
  Locale initialLocale = const Locale('ar', 'EG');
  bool hasCompletedIntro = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('app_selected_language');
    if (savedCode == 'en') {
      initialLocale = const Locale('en', 'US');
    }
    hasCompletedIntro =
        prefs.getBool(IntroOnboardingNotifier.keyCompleted) ?? false;
  } catch (e) {
    developer.log('Initial app config pre-load notice: $e');
  }

  // Wrap MyApp in ProviderScope with initial locale and onboarding state initialized
  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => LocaleNotifier(initialLocale)),
        introOnboardingProvider.overrideWith(
          (ref) => IntroOnboardingNotifier(hasCompletedIntro),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// Root Application Widget configured with reactive locale, typography, and automatic RTL/LTR.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final isArabic = currentLocale.languageCode == 'ar';

    // ScreenUtilInit configured with standard mobile design size (390 x 844)
    return ScreenUtilInit(
      key: ValueKey('screen_util_${currentLocale.languageCode}'),
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          key: ValueKey('gawezeny_material_app_${currentLocale.languageCode}'),
          navigatorKey: appNavigatorKey,
          title: AppTranslations.tr('appName', localeCode: currentLocale.languageCode),
          debugShowCheckedModeBanner: false,
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
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            return currentLocale;
          },
          home: Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const AuthGate(),
          ),
        );
      },
      child: const AuthGate(),
    );
  }
}

/// Main bottom navigation shell connecting core app features.
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MatchingScreen(),
    MatchesScreen(),
    ChatInboxScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Watch active locale so navigation bar labels immediately refresh on language change
    ref.watch(localeProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_outline_rounded),
            activeIcon: const Icon(Icons.favorite_rounded),
            label: context.tr('navHome'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline_rounded),
            activeIcon: const Icon(Icons.people_rounded),
            label: context.tr('navMatches'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: const Icon(Icons.chat_bubble_rounded),
            label: context.tr('navChat'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline_rounded),
            activeIcon: const Icon(Icons.person_rounded),
            label: context.tr('navProfile'),
          ),
        ],
      ),
    );
  }
}
