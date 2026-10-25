import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gawezeny/core/localization/app_translations.dart';
import 'package:gawezeny/core/preview/preview_mock_data.dart';
import 'package:gawezeny/core/theme/app_theme.dart';
import 'package:gawezeny/features/profile/domain/user_profile.dart';
import 'package:gawezeny/features/profile/presentation/profile_controller.dart';
import 'package:gawezeny/features/verification/data/verification_repository.dart';
import 'package:gawezeny/features/verification/domain/identity_verification.dart';
import 'package:gawezeny/features/verification/presentation/identity_verification_screen.dart';
import 'package:gawezeny/features/verification/presentation/verification_controller.dart';

Widget createVerificationTestWidget({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG'), Locale('ar')],
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

void setDevice(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expected15MinNotice =
      'تم استلام طلب توثيق حسابك بنجاح. برجاء الانتظار، سيتم مراجعة طلبك خلال 15 دقيقة.';

  group('Manual Admin Verification Workflow Tests', () {
    test('1. Domain Model correctly tracks PENDING, APPROVED and REJECTED states without AI', () {
      final request = IdentityVerification(
        id: 'ver-101',
        userId: 'usr-999',
        userFullName: 'محمود عبد السلام الشافعي',
        idCardImageUrl: 'https://example.com/id.jpg',
        selfieImageUrl: 'https://example.com/selfie.jpg',
        status: VerificationStatusType.pending,
        createdAt: DateTime.now(),
      );

      expect(request.isPending, isTrue);
      expect(request.isVerified, isFalse);
      expect(request.userFullName, 'محمود عبد السلام الشافعي');

      // Admin approves
      final approved = request.copyWith(
        status: VerificationStatusType.verified,
        reviewedAt: DateTime.now(),
        reviewedBy: 'admin-lead',
      );
      expect(approved.isVerified, isTrue);
      expect(approved.isPending, isFalse);

      // Admin rejects with custom reason
      final rejected = request.copyWith(
        status: VerificationStatusType.failed,
        rejectionReason: 'صورة البطاقة غير واضحة والاسم غير مقروء',
        reviewedAt: DateTime.now(),
        reviewedBy: 'admin-lead',
      );
      expect(rejected.isFailed, isTrue);
      expect(rejected.rejectionReason, 'صورة البطاقة غير واضحة والاسم غير مقروء');
    });

    test('2. VerificationStatusType aliases correctly map APPROVED and REJECTED', () {
      expect(VerificationStatusType.fromDbValue('PENDING'), VerificationStatusType.pending);
      expect(VerificationStatusType.fromDbValue('pending'), VerificationStatusType.pending);
      expect(VerificationStatusType.fromDbValue('APPROVED'), VerificationStatusType.verified);
      expect(VerificationStatusType.fromDbValue('VERIFIED'), VerificationStatusType.verified);
      expect(VerificationStatusType.fromDbValue('REJECTED'), VerificationStatusType.failed);
      expect(VerificationStatusType.fromDbValue('FAILED'), VerificationStatusType.failed);
      expect(VerificationStatusType.fromDbValue('UNVERIFIED'), VerificationStatusType.unverified);
    });

    test('3. VerificationSubmissionResult returns exact 15-minute notice', () {
      final result = VerificationSubmissionResult(
        success: true,
        message: expected15MinNotice,
        verification: IdentityVerification(
          id: 'v-1',
          userId: 'u-1',
          userFullName: 'يوسف العوضي',
          idCardImageUrl: 'id.jpg',
          selfieImageUrl: 'selfie.jpg',
          status: VerificationStatusType.pending,
          createdAt: DateTime.now(),
        ),
      );

      expect(result.success, isTrue);
      expect(result.message, contains('15 دقيقة'));
      expect(result.message, expected15MinNotice);
      expect(result.verification.status, VerificationStatusType.pending);
      expect(result.verification.userFullName, 'يوسف العوضي');
    });

    testWidgets('4. Pending review view displays exact 15-minute message and registered user name', (
      WidgetTester tester,
    ) async {
      setDevice(tester);

      final registeredProfile = PreviewMockData.currentProfile.copyWith(
        fullName: 'حازم صلاح الدين مصطفى',
        verificationStatus: VerificationStatusType.pending,
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWithValue(registeredProfile),
        ],
      );
      addTearDown(container.dispose);

      // Set state to pending
      container.read(verificationControllerProvider.notifier).setResultForPreview(
            status: VerificationStatusType.pending,
            registeredName: registeredProfile.fullName,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              locale: const Locale('ar', 'EG'),
              supportedLocales: const [Locale('ar', 'EG'), Locale('ar')],
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: IdentityVerificationScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('طلبك قيد المراجعة'), findsOneWidget);

      // Check exact required 15-minute review notice
      expect(find.text(expected15MinNotice), findsOneWidget);

      // Check registered user name (proves no OCR fake name is displayed)
      expect(find.text('حازم صلاح الدين مصطفى'), findsOneWidget);

      // Check status label
      expect(find.text('في انتظار مراجعة الإدارة'), findsOneWidget);

      // Verify no AI or face match score appears
      expect(find.textContaining('نسبة تطابق'), findsNothing);
      expect(find.textContaining('OCR'), findsNothing);
      expect(find.textContaining('الذكاء الاصطناعي'), findsNothing);
    });

    testWidgets('5. Approved view displays success confirmation and registered user name', (
      WidgetTester tester,
    ) async {
      setDevice(tester);

      final registeredProfile = PreviewMockData.currentProfile.copyWith(
        fullName: 'سارة إبراهيم منصور',
        verificationStatus: VerificationStatusType.verified,
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWithValue(registeredProfile),
        ],
      );
      addTearDown(container.dispose);

      container.read(verificationControllerProvider.notifier).setResultForPreview(
            status: VerificationStatusType.verified,
            registeredName: registeredProfile.fullName,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              locale: const Locale('ar', 'EG'),
              supportedLocales: const [Locale('ar', 'EG'), Locale('ar')],
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: IdentityVerificationScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تم توثيق حسابك بنجاح! ✅'), findsOneWidget);
      expect(find.text('سارة إبراهيم منصور'), findsOneWidget);
      expect(find.text('موثق ومعتمد رسمياً'), findsOneWidget);
    });

    testWidgets('6. Rejected view displays rejection reason and retry action', (
      WidgetTester tester,
    ) async {
      setDevice(tester);

      const customReason = 'الصورة الشخصية غير متطابقة مع صورة بطاقة الرقم القومي المصرية.';
      final container = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWithValue(PreviewMockData.currentProfile),
        ],
      );
      addTearDown(container.dispose);

      container.read(verificationControllerProvider.notifier).setResultForPreview(
            status: VerificationStatusType.failed,
            rejectionReason: customReason,
            registeredName: PreviewMockData.currentProfile.fullName,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              locale: const Locale('ar', 'EG'),
              supportedLocales: const [Locale('ar', 'EG'), Locale('ar')],
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const Directionality(
                textDirection: TextDirection.rtl,
                child: IdentityVerificationScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تم رفض طلب التوثيق'), findsOneWidget);
      expect(find.text(customReason), findsOneWidget);
      expect(find.text('إعادة تقديم طلب التوثيق'), findsOneWidget);
    });
  });
}
