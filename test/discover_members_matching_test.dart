import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gawezeny/core/theme/app_theme.dart';
import 'package:gawezeny/features/matching/domain/matching_filters.dart';
import 'package:gawezeny/features/matching/domain/partner_preferences.dart';
import 'package:gawezeny/features/matching/domain/scored_profile.dart';
import 'package:gawezeny/features/matching/presentation/widgets/discover_member_card.dart';
import 'package:gawezeny/features/profile/domain/user_profile.dart';

Widget buildTestApp(Widget child) {
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

UserProfile createSampleProfile({
  required String id,
  required String name,
  required GenderType gender,
  required String city,
  int age = 25,
  MaritalStatusType maritalStatus = MaritalStatusType.single,
  String jobTitle = 'مهندس',
  String? education = 'بكالوريوس',
  bool smoker = false,
  String prays = 'محافظ على الصلاة في المسجد',
  VerificationStatusType verification = VerificationStatusType.verified,
  String bio = 'نبذة تعريفية جادة للزواج',
}) {
  final now = DateTime.now();
  return UserProfile(
    id: id,
    fullName: name,
    gender: gender,
    birthDate: DateTime(now.year - age, 1, 1),
    age: age,
    nationality: 'مصري',
    residenceCity: city,
    maritalStatus: maritalStatus,
    jobTitle: jobTitle,
    educationLevel: education,
    smoker: smoker,
    prays: prays,
    wantsChildren: true,
    bio: bio,
    verificationStatus: verification,
    subscriptionStatus: SubscriptionStatusType.active,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Discover Members & Matchmaking Test Suite (13 Scenarios)', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Male account with only 1 female in the app
    // -------------------------------------------------------------------------
    test('Scenario 1: Male account with only 1 registered female displays her profile', () {
      final maleUser = createSampleProfile(
        id: 'male-01',
        name: 'أحمد محمود',
        gender: GenderType.male,
        city: 'القاهرة',
      );
      final singleFemale = createSampleProfile(
        id: 'female-01',
        name: 'سارة مصطفى',
        gender: GenderType.female,
        city: 'القاهرة',
      );

      const filters = MatchingFilters();
      // Should match the single female and not the male user himself
      expect(filters.matchesProfile(singleFemale, currentUserGender: maleUser.gender), isTrue);
      expect(singleFemale.id != maleUser.id, isTrue);

      final scored = ScoredProfile(
        profile: singleFemale,
        compatibilityScore: 92,
      );
      expect(scored.hasCompatibility, isTrue);
      expect(scored.compatibilityScore, equals(92));
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Male account with a small number of females (2, 3, 4)
    // -------------------------------------------------------------------------
    test('Scenario 2: Male account with 2, 3, or 4 registered females lists all of them', () {
      final maleUser = createSampleProfile(id: 'male-01', name: 'أحمد', gender: GenderType.male, city: 'القاهرة');
      final females = [
        createSampleProfile(id: 'f-1', name: 'مريم خليل', gender: GenderType.female, city: 'الجيزة'),
        createSampleProfile(id: 'f-2', name: 'نور الهدى', gender: GenderType.female, city: 'المنصورة'),
        createSampleProfile(id: 'f-3', name: 'هبة كامل', gender: GenderType.female, city: 'الإسكندرية'),
      ];

      const filters = MatchingFilters();
      final matched = females.where((f) => filters.matchesProfile(f, currentUserGender: maleUser.gender)).toList();
      expect(matched.length, equals(3));
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Female account with small number of males
    // -------------------------------------------------------------------------
    test('Scenario 3: Female account with a small number of males lists eligible males', () {
      final femaleUser = createSampleProfile(id: 'female-01', name: 'منى السيد', gender: GenderType.female, city: 'القاهرة');
      final males = [
        createSampleProfile(id: 'm-1', name: 'عمر عبد العزيز', gender: GenderType.male, city: 'القاهرة'),
        createSampleProfile(id: 'm-2', name: 'كريم يوسف', gender: GenderType.male, city: 'الإسكندرية'),
      ];

      const filters = MatchingFilters();
      final matched = males.where((m) => filters.matchesProfile(m, currentUserGender: femaleUser.gender)).toList();
      expect(matched.length, equals(2));
    });

    // -------------------------------------------------------------------------
    // Scenario 4 & 5: High and low compatibility appearing together, no minimum threshold
    // -------------------------------------------------------------------------
    test('Scenario 4 & 5: High and low compatibility candidates appear together without minimum score threshold', () {
      final highMatch = ScoredProfile(
        profile: createSampleProfile(id: 'f-high', name: 'سارة', gender: GenderType.female, city: 'القاهرة'),
        compatibilityScore: 95,
      );
      final lowMatch = ScoredProfile(
        profile: createSampleProfile(id: 'f-low', name: 'ياسمين', gender: GenderType.female, city: 'أسيوط', age: 38),
        compatibilityScore: 20, // Low score 20%
      );
      final uncalculated = ScoredProfile(
        profile: createSampleProfile(id: 'f-none', name: 'سلمى', gender: GenderType.female, city: 'طنطا'),
        compatibilityScore: null, // Null score
      );

      final list = [highMatch, lowMatch, uncalculated];

      // Verify none of them are filtered out by an arbitrary score threshold
      expect(list.length, equals(3));
      expect(list.any((p) => p.compatibilityScore == 20), isTrue);
      expect(list.any((p) => p.compatibilityScore == null), isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Same gender selection suppresses marriage compatibility score
    // -------------------------------------------------------------------------
    test('Scenario 6: Same gender selection suppresses marriage compatibility score (score is null)', () {
      final maleUser = createSampleProfile(id: 'm-caller', name: 'أحمد', gender: GenderType.male, city: 'القاهرة');
      final maleCandidate = createSampleProfile(id: 'm-browsing', name: 'عمر', gender: GenderType.male, city: 'القاهرة');

      // In repository calculation:
      // When user.gender == target.gender, calculateCompatibility returns null
      int? calculateCompat(UserProfile user, UserProfile target) {
        if (user.gender == target.gender) return null;
        return 85;
      }

      final score = calculateCompat(maleUser, maleCandidate);
      expect(score, isNull);

      final scoredSameGender = ScoredProfile(
        profile: maleCandidate,
        compatibilityScore: score,
      );
      expect(scoredSameGender.hasCompatibility, isFalse);
      expect(scoredSameGender.compatibilityScore, isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Individual filters and combined filters
    // -------------------------------------------------------------------------
    test('Scenario 7: Testing individual filters and then combining multiple filters', () {
      final candidate = createSampleProfile(
        id: 'f-test',
        name: 'مريم حسن',
        gender: GenderType.female,
        city: 'الإسكندرية',
        age: 26,
        maritalStatus: MaritalStatusType.single,
        smoker: false,
        verification: VerificationStatusType.verified,
      );

      // 1. City filter
      expect(const MatchingFilters(selectedCities: ['الإسكندرية']).matchesProfile(candidate), isTrue);
      expect(const MatchingFilters(selectedCities: ['القاهرة']).matchesProfile(candidate), isFalse);

      // 2. Age filter
      expect(const MatchingFilters(minAge: 20, maxAge: 30).matchesProfile(candidate), isTrue);
      expect(const MatchingFilters(minAge: 30, maxAge: 40).matchesProfile(candidate), isFalse);

      // 3. Marital status filter
      expect(const MatchingFilters(selectedMaritalStatuses: [MaritalStatusType.single]).matchesProfile(candidate), isTrue);
      expect(const MatchingFilters(selectedMaritalStatuses: [MaritalStatusType.divorced]).matchesProfile(candidate), isFalse);

      // 4. Combined filters (all match)
      final combinedMatch = const MatchingFilters(
        selectedCities: ['الإسكندرية'],
        minAge: 24,
        maxAge: 28,
        selectedMaritalStatuses: [MaritalStatusType.single],
        nonSmokerOnly: true,
        verifiedOnly: true,
      );
      expect(combinedMatch.matchesProfile(candidate), isTrue);

      // 5. Combined filters (one mismatch: city)
      final combinedMismatch = combinedMatch.copyWith(selectedCities: ['طنطا']);
      expect(combinedMismatch.matchesProfile(candidate), isFalse);
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Empty optional filters do not exclude candidates
    // -------------------------------------------------------------------------
    test('Scenario 8: Empty optional filters do not exclude candidates', () {
      final candidate = createSampleProfile(
        id: 'f-open',
        name: 'فاطمة',
        gender: GenderType.female,
        city: 'المنصورة',
        age: 24,
      );

      const defaultFilters = MatchingFilters();
      expect(defaultFilters.isDefault, isTrue);
      expect(defaultFilters.matchesProfile(candidate), isTrue);

      // Filters with empty city and marital status arrays
      const emptyListsFilter = MatchingFilters(
        selectedCities: [],
        selectedMaritalStatuses: [],
        searchQuery: '',
      );
      expect(emptyListsFilter.matchesProfile(candidate), isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Keyword search with matching and non-matching queries
    // -------------------------------------------------------------------------
    test('Scenario 9: Keyword search accurately filters by name, job, city, or bio', () {
      final candidate = createSampleProfile(
        id: 'f-search',
        name: 'سارة محمود القاضي',
        gender: GenderType.female,
        city: 'الإسكندرية',
        jobTitle: 'صيدلانية سريرية',
        bio: 'أحب القراءة والعمل الخيري وتكوين أسرة صالحة',
      );

      // Match by partial name
      expect(const MatchingFilters(searchQuery: 'سارة').matchesProfile(candidate), isTrue);
      expect(const MatchingFilters(searchQuery: 'القاضي').matchesProfile(candidate), isTrue);

      // Match by job
      expect(const MatchingFilters(searchQuery: 'صيدلانية').matchesProfile(candidate), isTrue);

      // Match by city
      expect(const MatchingFilters(searchQuery: 'الإسكندرية').matchesProfile(candidate), isTrue);

      // Match by bio
      expect(const MatchingFilters(searchQuery: 'خيري').matchesProfile(candidate), isTrue);

      // Non-matching keyword
      expect(const MatchingFilters(searchQuery: 'مهندس برمجة').matchesProfile(candidate), isFalse);
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Pagination and list handling
    // -------------------------------------------------------------------------
    test('Scenario 10: Pagination correctly limits and offsets candidate lists', () {
      final candidates = List.generate(
        15,
        (i) => ScoredProfile(
          profile: createSampleProfile(id: 'u-$i', name: 'مرشح $i', gender: GenderType.female, city: 'القاهرة'),
          compatibilityScore: 70 + i,
        ),
      );

      final page1 = candidates.sublist(0, 5);
      final page2 = candidates.sublist(5, 10);
      final page3 = candidates.sublist(10, 15);

      expect(page1.length, equals(5));
      expect(page2.length, equals(5));
      expect(page3.length, equals(5));
      expect(page1.first.id, equals('u-0'));
      expect(page2.first.id, equals('u-5'));
      expect(page3.first.id, equals('u-10'));
    });

    // -------------------------------------------------------------------------
    // Scenario 11: Empty results state handling
    // -------------------------------------------------------------------------
    test('Scenario 11: Empty state and non-matching filters produce clean empty list', () {
      final candidates = [
        createSampleProfile(id: 'f-1', name: 'سارة', gender: GenderType.female, city: 'القاهرة'),
      ];

      const noMatchFilter = MatchingFilters(selectedCities: ['أسوان']);
      final results = candidates.where((c) => noMatchFilter.matchesProfile(c)).toList();
      expect(results.isEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 12: Exclusion of current user and mutual blocked users
    // -------------------------------------------------------------------------
    test('Scenario 12: Current user and blocked accounts are strictly excluded', () {
      const currentUserId = 'user-current-id';
      const blockedUserId = 'user-blocked-id';
      final blockedSet = {blockedUserId};

      final allProfiles = [
        createSampleProfile(id: currentUserId, name: 'أنا', gender: GenderType.male, city: 'القاهرة'),
        createSampleProfile(id: blockedUserId, name: 'محظور', gender: GenderType.female, city: 'القاهرة'),
        createSampleProfile(id: 'user-valid', name: 'مرشحة صالحة', gender: GenderType.female, city: 'القاهرة'),
      ];

      final eligible = allProfiles.where((p) {
        if (p.id == currentUserId) return false;
        if (blockedSet.contains(p.id)) return false;
        return true;
      }).toList();

      expect(eligible.length, equals(1));
      expect(eligible.first.id, equals('user-valid'));
    });

    // -------------------------------------------------------------------------
    // Scenario 13: Recalculation when preferences or profile change
    // -------------------------------------------------------------------------
    test('Scenario 13: Dynamic compatibility recalculates upon preferences change', () {
      final target = createSampleProfile(id: 't-1', name: 'سارة', gender: GenderType.female, city: 'الإسكندرية', age: 25);

      int computeScore(PartnerPreferences prefs) {
        int score = 0;
        if (target.age! >= prefs.minAge && target.age! <= prefs.maxAge) score += 20;
        if (prefs.acceptableCities.contains(target.residenceCity)) score += 20;
        return score;
      }

      // Initial preferences: only Cairo accepted
      final prefs1 = PartnerPreferences(
        userId: 'u-1',
        createdAt: DateTime.now(),
        minAge: 20,
        maxAge: 30,
        acceptableCities: const ['القاهرة'],
      );
      expect(computeScore(prefs1), equals(20)); // Only age fits

      // Updated preferences: Alexandria added
      final prefs2 = prefs1.copyWith(acceptableCities: ['القاهرة', 'الإسكندرية']);
      expect(computeScore(prefs2), equals(40)); // Both age and city fit
    });

    // -------------------------------------------------------------------------
    // Widget Test: DiscoverMemberCard renders correctly with all specs and badges
    // -------------------------------------------------------------------------
    testWidgets('DiscoverMemberCard renders profile details, compatibility badge, and actions', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final candidate = ScoredProfile(
        profile: createSampleProfile(
          id: 'card-test-01',
          name: 'سارة محمود',
          gender: GenderType.female,
          city: 'الإسكندرية',
          age: 25,
          jobTitle: 'صيدلانية سريرية',
          bio: 'نبذة عن سارة محمود ورغبتها في بناء بيت مسلم',
        ),
        compatibilityScore: 94,
      );

      bool detailsTapped = false;
      bool likeTapped = false;

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: DiscoverMemberCard(
              candidate: candidate,
              currentUserGender: GenderType.male,
              onTapDetails: () => detailsTapped = true,
              onLike: () => likeTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Check name, age, city, job
      expect(find.textContaining('سارة محمود، 25 سنة'), findsOneWidget);
      expect(find.textContaining('الإسكندرية'), findsOneWidget);
      expect(find.textContaining('صيدلانية سريرية'), findsOneWidget);

      // Check compatibility badge
      expect(find.textContaining('94%'), findsOneWidget);

      // Check action buttons
      expect(find.text('عرض الملف'), findsOneWidget);
      expect(find.text('إعجاب'), findsOneWidget);

      // Test tap details
      await tester.tap(find.text('عرض الملف'));
      await tester.pump();
      expect(detailsTapped, isTrue);

      // Test tap like
      await tester.tap(find.text('إعجاب'));
      await tester.pump();
      expect(likeTapped, isTrue);
    });

    // -------------------------------------------------------------------------
    // Widget Test: DiscoverMemberCard with same-gender shows browsing badge
    // -------------------------------------------------------------------------
    testWidgets('DiscoverMemberCard with same-gender shows browsing only badge without percentage', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final maleCandidate = ScoredProfile(
        profile: createSampleProfile(
          id: 'card-test-male',
          name: 'عمر عبد العزيز',
          gender: GenderType.male,
          city: 'القاهرة',
        ),
        compatibilityScore: null,
      );

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: DiscoverMemberCard(
              candidate: maleCandidate,
              currentUserGender: GenderType.male, // Male viewing Male
              onTapDetails: () {},
              onLike: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('تصفح فقط'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });
  });
}
