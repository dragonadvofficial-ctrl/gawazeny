import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gawezeny/core/localization/app_translations.dart';
import 'package:gawezeny/core/theme/app_theme.dart';
import 'package:gawezeny/features/auth/data/auth_repository.dart';
import 'package:gawezeny/features/auth/presentation/auth_controller.dart';
import 'package:gawezeny/features/auth/presentation/login_screen.dart';
import 'package:gawezeny/features/auth/presentation/widgets/email_confirmation_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget buildTestApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG'), Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    ),
  );
}

class LoadingAuthController extends AuthController {
  LoadingAuthController(super.repo) {
    state = const AsyncValue.loading();
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  void setDevice(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Remember Me on This Device Tests', () {
    testWidgets('LoginScreen shows "Remember Me" checkbox on Sign In tab, unchecked by default',
        (tester) async {
      setDevice(tester);
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      // Checkbox label should exist
      final rememberMeText = find.text('تذكّرني على هذا الجهاز');
      expect(rememberMeText, findsOneWidget);

      // Checkbox widget should exist and be unchecked by default
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);
      final checkbox = tester.widget<Checkbox>(checkboxFinder);
      expect(checkbox.value, isFalse, reason: 'Must be unchecked by default');
    });

    testWidgets('Tapping "Remember Me" checkbox or label toggles its state', (tester) async {
      setDevice(tester);
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      // Tap the label
      await tester.tap(find.text('تذكّرني على هذا الجهاز'));
      await tester.pumpAndSettle();

      // Checkbox should now be checked
      var checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);

      // Tap again to toggle off
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('Switching to Register tab hides the "Remember Me" checkbox', (tester) async {
      setDevice(tester);
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      // Initially on Sign In tab
      expect(find.text('تذكّرني على هذا الجهاز'), findsOneWidget);

      // Switch to Register Tab
      await tester.tap(find.text('حساب جديد'));
      await tester.pumpAndSettle();

      // "Remember Me" should NOT appear on Register tab
      expect(find.text('تذكّرني على هذا الجهاز'), findsNothing);
      expect(find.text('إنشاء حساب والانتقال للاستبيان'), findsOneWidget);
    });
  });

  group('Loading State on Sign Up and Sign In Tests', () {
    testWidgets('Button shows loading text and indicator and is disabled when loading',
        (tester) async {
      setDevice(tester);

      await tester.pumpWidget(
        buildTestApp(
          const LoginScreen(),
          overrides: [
            authControllerProvider.overrideWith((ref) {
              final repo = ref.watch(authRepositoryProvider);
              return LoadingAuthController(repo);
            }),
          ],
        ),
      );
      await tester.pump();

      // On Sign In tab with loading:
      expect(find.text('جارٍ تسجيل الدخول...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify button is disabled
      final elevatedButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(elevatedButton.onPressed, isNull);
    });
  });

  group('EmailConfirmationDialog Tests', () {
    testWidgets('EmailConfirmationDialog renders title, exact message, email, and cooldown timer',
        (tester) async {
      setDevice(tester);

      bool goToSignInCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: EmailConfirmationDialog(
              email: 'mohamedworking921@gmail.com',
              onGoToSignIn: () {
                goToSignInCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // 1. Verify Dialog Title
      expect(find.text('تم إنشاء حسابك بنجاح! 📩'), findsOneWidget);

      // 2. Verify registered email display
      expect(find.text('mohamedworking921@gmail.com'), findsOneWidget);

      // 3. Verify exact requested description text
      expect(
        find.textContaining('بعتنالك رسالة تأكيد على بريدك الإلكتروني'),
        findsOneWidget,
      );
      expect(
        find.textContaining('مجلد الرسائل غير المرغوب فيها (Spam)'),
        findsOneWidget,
      );

      // 4. Verify Cooldown button text
      expect(find.textContaining('إعادة الإرسال بعد'), findsOneWidget);

      // 5. Verify "الانتقال لتسجيل الدخول" button exists and works
      final goToSignInFinder = find.text('الانتقال لتسجيل الدخول');
      expect(goToSignInFinder, findsOneWidget);

      await tester.tap(goToSignInFinder);
      await tester.pump();
      expect(goToSignInCalled, isTrue);
    });
  });

  group('AuthRepository Exception and Rate Limit Translation Tests', () {
    test('Translates Supabase rate-limit countdown into Arabic', () {
      // 1. Exact error message shown in user screenshot
      const rawException = AuthException(
        'For security purposes, you can only request this after 54 seconds.',
        statusCode: '429',
      );
      final mapped = AuthRepository.mapAuthException(rawException);
      expect(mapped, 'لأسباب أمنية، يرجى الانتظار 54 ثانية قبل إعادة إرسال الطلب');
    });

    test('Translates User already registered into Arabic', () {
      const exception = AuthException(
        'User already registered',
        statusCode: '400',
      );
      final mapped = AuthRepository.mapAuthException(exception);
      expect(mapped, 'هذا البريد الإلكتروني مسجل مسبقاً، يرجى الانتقال إلى تسجيل الدخول');
    });

    test('Translates general rate limit into Arabic', () {
      const exception = AuthException(
        'over_email_send_rate_limit',
        statusCode: '429',
      );
      final mapped = AuthRepository.mapAuthException(exception);
      expect(mapped, 'تم تجاوز الحد المسموح من الطلبات، يرجى الانتظار دقيقة ثم إعادة المحاولة');
    });

    test('Translates weak password into Arabic', () {
      const exception = AuthException(
        'Password should be at least 6 characters',
        statusCode: '422',
      );
      final mapped = AuthRepository.mapAuthException(exception);
      expect(mapped, 'يجب أن تتكون كلمة المرور من 6 خانات على الأقل');
    });

    test('Translates invalid credentials into Arabic', () {
      const exception = AuthException(
        'Invalid login credentials',
        statusCode: '400',
      );
      final mapped = AuthRepository.mapAuthException(exception);
      expect(mapped, 'البريد الإلكتروني أو كلمة المرور غير صحيحة');
    });

    test('Translates connection timeout into Arabic', () {
      const exception = AuthException(
        'Connection timed out',
        statusCode: '504',
      );
      final mapped = AuthRepository.mapAuthException(exception);
      expect(mapped, 'تعذر الاتصال بالخادم، يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً');
    });
  });
}
