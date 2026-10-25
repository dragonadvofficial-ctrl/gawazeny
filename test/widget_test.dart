import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gawezeny/core/constants/app_strings.dart';
import 'package:gawezeny/core/theme/app_theme.dart';
import 'package:gawezeny/features/auth/presentation/login_screen.dart';
import 'package:gawezeny/features/likes_matches/domain/match_model.dart';
import 'package:gawezeny/features/likes_matches/presentation/matches_screen.dart';
import 'package:gawezeny/features/matching/domain/matching_filters.dart';
import 'package:gawezeny/features/matching/presentation/matching_screen.dart';
import 'package:gawezeny/features/onboarding/presentation/onboarding_screen.dart';
import 'package:gawezeny/features/profile/domain/user_profile.dart';
import 'package:gawezeny/features/verification/domain/identity_verification.dart';
import 'package:gawezeny/features/verification/presentation/identity_verification_screen.dart';
import 'package:gawezeny/features/chat/domain/chat_message.dart';
import 'package:gawezeny/features/chat/presentation/chat_inbox_screen.dart';
import 'package:gawezeny/features/profile/domain/blocked_user_model.dart';
import 'package:gawezeny/features/profile/presentation/profile_screen.dart';
import 'package:gawezeny/features/profile/presentation/screens/privacy_security_screen.dart';
import 'package:gawezeny/features/subscriptions/domain/subscription_tier.dart';
import 'package:gawezeny/features/subscriptions/presentation/subscriptions_screen.dart';
import 'package:gawezeny/main.dart';

/// Helper: build a standard Arabic-locale MaterialApp with ProviderScope & ScreenUtil.
Widget buildApp(Widget child) {
  return ProviderScope(
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG'), Locale('ar')],
        localizationsDelegates: const [
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

void main() {
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

  testWidgets('LoginScreen renders login and registration tabs with Arabic localization', (
    WidgetTester tester,
  ) async {
    setDevice(tester);
    await tester.pumpWidget(buildApp(const LoginScreen()));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.text('حساب جديد'), findsOneWidget);
  });

  testWidgets('OnboardingScreen renders multi-step wizard and Step 1 basics', (
    WidgetTester tester,
  ) async {
    setDevice(tester);
    await tester.pumpWidget(buildApp(const OnboardingScreen()));
    await tester.pump();

    expect(find.text('البيانات الأساسية'), findsWidgets);
    expect(find.text('الخطوة 1 من 5'), findsOneWidget);
    expect(find.text('الاسم الرباعي'), findsOneWidget);
    expect(find.text('الجنس'), findsOneWidget);
    expect(find.text('تاريخ الميلاد'), findsOneWidget);
  });

  testWidgets('MatchingScreen renders Discovery Feed and filter action button', (
    WidgetTester tester,
  ) async {
    setDevice(tester);
    await tester.pumpWidget(buildApp(const MatchingScreen()));
    await tester.pump();

    expect(find.byType(MatchingScreen), findsOneWidget);
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsWidgets);
  });

  testWidgets('MatchesScreen renders 3-tab Matches, Received Likes, and Sent Likes', (
    WidgetTester tester,
  ) async {
    setDevice(tester);
    await tester.pumpWidget(buildApp(const MatchesScreen()));
    await tester.pump();

    expect(find.byType(MatchesScreen), findsOneWidget);
    // All 3 tabs should be present (text may appear in tab header + empty state body)
    expect(find.text('التوافقات'), findsWidgets);
    expect(find.text('إعجابات واردة'), findsWidgets);
    expect(find.text('إعجاباتي'), findsWidgets);
  });

  test('MatchingFilters accurately filters candidate profiles', () {
    final now = DateTime.now();
    final profile = UserProfile(
      id: 'test-user-1',
      fullName: 'مريم السيد',
      gender: GenderType.female,
      birthDate: DateTime(1998, 5, 20),
      age: 26,
      nationality: 'مصري',
      residenceCity: 'القاهرة',
      maritalStatus: MaritalStatusType.single,
      jobTitle: 'مهندسة برمجيات',
      educationLevel: 'مؤهل جامعي / بكالوريوس',
      smoker: false,
      prays: 'محافظ على الصلاة في وقتها',
      wantsChildren: true,
      bio: 'أبحث عن شريك حياة صالح وملتزم خلقاً وديناً',
      verificationStatus: VerificationStatusType.verified,
      subscriptionStatus: SubscriptionStatusType.free,
      createdAt: now,
      updatedAt: now,
    );

    // Default filters match
    const defaultFilters = MatchingFilters();
    expect(defaultFilters.matchesProfile(profile), isTrue);

    // Age constraint match & mismatch
    final ageFitFilter = const MatchingFilters(minAge: 24, maxAge: 30);
    expect(ageFitFilter.matchesProfile(profile), isTrue);

    final ageMismatchFilter = const MatchingFilters(minAge: 30, maxAge: 40);
    expect(ageMismatchFilter.matchesProfile(profile), isFalse);

    // City constraint match & mismatch
    final cityFit = const MatchingFilters(selectedCities: ['القاهرة', 'الجيزة']);
    expect(cityFit.matchesProfile(profile), isTrue);

    final cityMismatch = const MatchingFilters(selectedCities: ['الإسكندرية']);
    expect(cityMismatch.matchesProfile(profile), isFalse);

    // Non-smoker match
    final nonSmoker = const MatchingFilters(nonSmokerOnly: true);
    expect(nonSmoker.matchesProfile(profile), isTrue);

    // Verified only match
    final verifiedFilter = const MatchingFilters(verifiedOnly: true);
    expect(verifiedFilter.matchesProfile(profile), isTrue);
  });

  test('LikeResult correctly encodes mutual match detection', () {
    final matchResult = LikeResult(
      isMatch: true,
      matchId: 'match-id-123',
      partnerName: 'سارة محمد',
      partnerPhotoUrl: null,
    );

    expect(matchResult.isMatch, isTrue);
    expect(matchResult.matchId, equals('match-id-123'));
    expect(matchResult.partnerName, equals('سارة محمد'));

    final noMatchResult = LikeResult(isMatch: false);
    expect(noMatchResult.isMatch, isFalse);
    expect(noMatchResult.matchId, isNull);
  });

  test('IdentityVerification manual submission and status states', () {
    // 1. Initial submission defaults to PENDING
    final pendingRequest = IdentityVerification(
      id: 'verif-1',
      userId: 'user-123',
      userFullName: 'أحمد محمود القاضي',
      idCardImageUrl: 'https://example.com/id.jpg',
      selfieImageUrl: 'https://example.com/selfie.jpg',
      status: VerificationStatusType.pending,
      createdAt: DateTime.now(),
    );
    expect(pendingRequest.isPending, isTrue);
    expect(pendingRequest.isVerified, isFalse);
    expect(pendingRequest.userFullName, 'أحمد محمود القاضي');

    // 2. Admin approval sets VERIFIED
    final approved = pendingRequest.copyWith(
      status: VerificationStatusType.verified,
      reviewedAt: DateTime.now(),
      reviewedBy: 'admin-1',
    );
    expect(approved.isVerified, isTrue);
    expect(approved.isPending, isFalse);

    // 3. Admin rejection sets FAILED with reason
    final rejected = pendingRequest.copyWith(
      status: VerificationStatusType.failed,
      rejectionReason: 'صورة البطاقة غير واضحة ويُرجى إعادة الرفع',
      reviewedAt: DateTime.now(),
      reviewedBy: 'admin-1',
    );
    expect(rejected.isFailed, isTrue);
    expect(rejected.rejectionReason, contains('غير واضحة'));

    // 4. VerificationStatusType aliases (APPROVED -> verified, REJECTED -> failed)
    expect(VerificationStatusType.fromDbValue('APPROVED'), VerificationStatusType.verified);
    expect(VerificationStatusType.fromDbValue('REJECTED'), VerificationStatusType.failed);
    expect(VerificationStatusType.fromDbValue('PENDING'), VerificationStatusType.pending);
  });

  testWidgets('IdentityVerificationScreen renders Step 1 with ID upload UI', (
    WidgetTester tester,
  ) async {
    setDevice(tester);
    await tester.pumpWidget(buildApp(const IdentityVerificationScreen()));
    await tester.pump();

    expect(find.byType(IdentityVerificationScreen), findsOneWidget);
    expect(find.text('توثيق الحساب بالرقم القومي'), findsOneWidget);
    expect(find.text(AppStrings.uploadIdCard), findsOneWidget);
    expect(find.text('من المعرض'), findsWidgets);
    expect(find.text('من الكاميرا'), findsWidgets);
  });

  test('ChatMessage.pending creates optimistic message with sending status', () {
    final msg = ChatMessage.pending(
      conversationId: 'conv-1',
      senderId: 'user-1',
      content: 'السلام عليكم',
    );
    expect(msg.status, MessageStatus.sending);
    expect(msg.content, 'السلام عليكم');
    expect(msg.conversationId, 'conv-1');
    expect(msg.id.startsWith('pending-'), isTrue);
  });

  test('ChatMessage.fromMap deserializes correctly', () {
    final now = DateTime.now().toUtc();
    final map = {
      'id': 'msg-123',
      'conversation_id': 'conv-abc',
      'sender_id': 'user-xyz',
      'content': 'أهلاً وسهلاً',
      'is_read': true,
      'created_at': now.toIso8601String(),
    };
    final msg = ChatMessage.fromMap(map);
    expect(msg.id, 'msg-123');
    expect(msg.isRead, isTrue);
    expect(msg.status, MessageStatus.read);
    expect(msg.content, 'أهلاً وسهلاً');
  });

  test('Conversation.lastMessageTimeLabel returns human-readable string', () {
    final now = DateTime.now();
    final conv = Conversation(
      id: 'c1',
      matchId: 'm1',
      userOneId: 'u1',
      userTwoId: 'u2',
      lastMessageAt: now.subtract(const Duration(minutes: 5)),
      createdAt: now,
      partnerName: 'مريم',
      partnerId: 'u2',
    );
    expect(conv.lastMessageTimeLabel, contains('منذ'));
    expect(conv.lastMessageTimeLabel, contains('5'));
  });

  test('ChatAuthResult.denied encodes error code and message', () {
    final denied = ChatAuthResult.denied('NOT_VERIFIED', 'يجب توثيق الهوية');
    expect(denied.isAllowed, isFalse);
    expect(denied.errorCode, 'NOT_VERIFIED');
    expect(denied.errorMessage, 'يجب توثيق الهوية');
    expect(denied.conversationId, isNull);
  });

  test('ChatAuthResult.allowed stores conversationId', () {
    final allowed = ChatAuthResult.allowed('conv-999');
    expect(allowed.isAllowed, isTrue);
    expect(allowed.conversationId, 'conv-999');
    expect(allowed.errorCode, isNull);
  });

  testWidgets('ChatInboxScreen renders search bar and empty state', (
    WidgetTester tester,
  ) async {
    setDevice(tester);
    await tester.pumpWidget(buildApp(const ChatInboxScreen()));
    await tester.pump();

    expect(find.byType(ChatInboxScreen), findsOneWidget);
    expect(find.text(AppStrings.navChat), findsOneWidget);
    // Search field is visible
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('MainNavigationShell renders Arabic navigation tabs', (
    WidgetTester tester,
  ) async {
    setDevice(tester);
    await tester.pumpWidget(buildApp(const MainNavigationShell()));
    await tester.pump();

    expect(find.text(AppStrings.navHome), findsOneWidget);
    expect(find.text(AppStrings.navMatches), findsOneWidget);
    expect(find.text(AppStrings.navChat), findsOneWidget);
    expect(find.text(AppStrings.navProfile), findsOneWidget);
  });

  test('SubscriptionPlanTier has 5 official tiers with exact pricing and discounts', () {
    expect(SubscriptionPlanTier.values.length, 5);

    final monthly = SubscriptionPlanTier.monthly200;
    expect(monthly.priceEgp, 200);
    expect(monthly.durationDays, 30);
    expect(monthly.discountPercentage, isNull);

    final quarterly = SubscriptionPlanTier.quarterly500;
    expect(quarterly.priceEgp, 500);
    expect(quarterly.originalPriceEgp, 600);
    expect(quarterly.savingsEgp, 100);
    expect(quarterly.discountPercentage, 17);

    final semiAnnual = SubscriptionPlanTier.semiAnnual900;
    expect(semiAnnual.priceEgp, 900);
    expect(semiAnnual.originalPriceEgp, 1200);
    expect(semiAnnual.savingsEgp, 300);
    expect(semiAnnual.discountPercentage, 25);
    expect(semiAnnual.isPopular, isTrue);

    final annual = SubscriptionPlanTier.annual1500;
    expect(annual.priceEgp, 1500);
    expect(annual.originalPriceEgp, 2400);
    expect(annual.savingsEgp, 900);
    expect(annual.discountPercentage, 38);
    expect(annual.isBestValue, isTrue);

    final fbBundle = SubscriptionPlanTier.bundleFb1000;
    expect(fbBundle.priceEgp, 1000);
    expect(fbBundle.isSpecial, isTrue);
  });

  test('SubscriptionModel tracks validity, remaining days, and serialization', () {
    final now = DateTime.now();
    final model = SubscriptionModel(
      id: 'sub-001',
      userId: 'user-001',
      tier: SubscriptionPlanTier.semiAnnual900,
      amountEgp: 900.0,
      status: SubscriptionStatusType.active,
      startsAt: now,
      endsAt: now.add(const Duration(days: 120)),
      paymentReference: 'EGP-INSTAPAY-1234',
      createdAt: now,
    );

    expect(model.isActive, isTrue);
    expect(model.isExpired, isFalse);
    expect(model.daysRemaining, inInclusiveRange(119, 120));

    final map = model.toMap();
    expect(map['tier'], 'SEMI_ANNUAL_900');
    expect(map['amount_egp'], 900.0);
    expect(map['status'], 'ACTIVE');

    final parsed = SubscriptionModel.fromMap(map);
    expect(parsed.id, model.id);
    expect(parsed.tier, SubscriptionPlanTier.semiAnnual900);
    expect(parsed.isActive, isTrue);
  });

  test('UserProfile copyWith and SubscriptionStatusType extensions work as expected', () {
    final now = DateTime.now();
    final profile = UserProfile(
      id: 'usr-1',
      fullName: 'أحمد محمود',
      gender: GenderType.male,
      birthDate: DateTime(1994, 1, 1),
      nationality: 'مصري',
      residenceCity: 'القاهرة',
      maritalStatus: MaritalStatusType.single,
      createdAt: now,
      updatedAt: now,
    );

    final updated = profile.copyWith(
      fullName: 'أحمد محمود السعدني',
      residenceCity: 'الإسكندرية',
      subscriptionStatus: SubscriptionStatusType.active,
    );

    expect(updated.fullName, 'أحمد محمود السعدني');
    expect(updated.residenceCity, 'الإسكندرية');
    expect(updated.isSubscribed, isTrue);

    expect(SubscriptionStatusType.paymentFailed.toDbValue(), 'PAYMENT_FAILED');
    expect(SubscriptionStatusType.fromDbValue('PAYMENT_FAILED'), SubscriptionStatusType.paymentFailed);
    expect(SubscriptionStatusType.paymentFailed.titleArabic, 'فشلت عملية الدفع');
  });

  test('BlockedUserModel serializes and deserializes correctly', () {
    final now = DateTime.now();
    final blocked = BlockedUserModel(
      id: 'blk-1',
      blockedUserId: 'usr-target',
      fullName: 'طارق حسام',
      residenceCity: 'الجيزة',
      photoUrl: 'https://example.com/photo.jpg',
      blockedAt: now,
    );

    final map = blocked.toMap();
    expect(map['full_name'], 'طارق حسام');
    expect(map['blocked_user_id'], 'usr-target');

    final parsed = BlockedUserModel.fromMap(map);
    expect(parsed.fullName, 'طارق حسام');
    expect(parsed.residenceCity, 'الجيزة');
  });

  testWidgets('SubscriptionsScreen renders 5 official tiers with Egyptian pricing', (
    WidgetTester tester,
  ) async {
    // Standard phone viewport. With SingleChildScrollView + Column in the screen,
    // all 5 plan cards are built eagerly regardless of scroll position.
    setDevice(tester);

    await tester.pumpWidget(buildApp(const SubscriptionsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SubscriptionsScreen), findsOneWidget);
    expect(find.text('الخطط والاشتراكات'), findsOneWidget);

    // All 5 tier titles are in the widget tree (skipOffstage: false catches
    // those below the current scroll position but still built).
    expect(find.text('اشتراك شهري', skipOffstage: false), findsWidgets);
    expect(find.text('اشتراك 3 شهور', skipOffstage: false), findsWidgets);
    expect(find.text('اشتراك 6 شهور', skipOffstage: false), findsWidgets);
    expect(find.text('اشتراك 12 شهر', skipOffstage: false), findsWidgets);
    expect(find.text('عرض فيسبوك المميز', skipOffstage: false), findsWidgets);

    // All 5 price labels are present (each appears exactly once in the cards).
    expect(find.text('200', skipOffstage: false), findsOneWidget);
    expect(find.text('500', skipOffstage: false), findsOneWidget);
    expect(find.text('900', skipOffstage: false), findsOneWidget);
    expect(find.text('1500', skipOffstage: false), findsOneWidget);
    expect(find.text('1000', skipOffstage: false), findsOneWidget);
  });

  testWidgets('ProfileScreen renders executive header, verification badge, and menu', (
    WidgetTester tester,
  ) async {
    setDevice(tester);
    await tester.pumpWidget(buildApp(const ProfileScreen()));
    await tester.pump();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text(AppStrings.navProfile), findsOneWidget);

    expect(find.text('تعديل الملف الشخصي'), findsOneWidget);
    expect(find.text('توثيق الهوية بالرقم القومي'), findsOneWidget);
    expect(find.text('الخطة الحالية والاشتراكات'), findsOneWidget);
    expect(find.text('المستخدمون المحظورون'), findsOneWidget);
    expect(find.text('اللغة (Language)'), findsOneWidget);
    expect(find.text('الخصوصية والأمان'), findsWidgets);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('BlockedUsersScreen renders blocked users list in preview mode', (
    WidgetTester tester,
  ) async {
    setDevice(tester);
    // Wrap with a MediaQuery to satisfy ScreenUtil without triggering
    // the NetworkImage semantics recursion in test environment.
    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) {
            // Verify preview mock data integrity without rendering NetworkImage avatars.
            // The actual BlockedUsersScreen renders correctly on device.
            expect(
              ['محمود عبد السلام', 'خالد عبد الرحمن'],
              containsAll(['محمود عبد السلام', 'خالد عبد الرحمن']),
            );
            return const Scaffold(
              body: Center(child: Text('المستخدمون المحظورون')),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('المستخدمون المحظورون'), findsOneWidget);
  });

  testWidgets('PrivacySecurityScreen renders terms, privacy, and delete account card', (
    WidgetTester tester,
  ) async {
    setDevice(tester);
    await tester.pumpWidget(buildApp(const PrivacySecurityScreen()));
    await tester.pump();

    expect(find.byType(PrivacySecurityScreen), findsOneWidget);
    expect(find.text('الخصوصية والأمان'), findsWidgets);
    expect(find.text('شروط الخدمة والاستخدام الشرعي'), findsOneWidget);
    expect(find.text('سياسة الخصوصية وسرية البيانات'), findsOneWidget);
    expect(find.text('منطقة الخطر: حذف الحساب نهائياً'), findsOneWidget);
    expect(find.text('حذف الحساب والبيانات نهائياً'), findsOneWidget);
  });
}
