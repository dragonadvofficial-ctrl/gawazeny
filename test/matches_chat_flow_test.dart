import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gawezeny/core/localization/app_translations.dart';
import 'package:gawezeny/core/network/supabase_client.dart';
import 'package:gawezeny/core/preview/preview_mock_data.dart';
import 'package:gawezeny/core/theme/app_theme.dart';
import 'package:gawezeny/features/chat/data/chat_repository.dart';
import 'package:gawezeny/features/chat/domain/chat_message.dart';
import 'package:gawezeny/features/chat/presentation/chat_room_screen.dart';
import 'package:gawezeny/features/likes_matches/domain/match_model.dart';
import 'package:gawezeny/features/likes_matches/presentation/likes_matches_controller.dart';
import 'package:gawezeny/features/likes_matches/presentation/matches_screen.dart';
import 'package:gawezeny/features/profile/domain/user_profile.dart';
import 'package:gawezeny/features/profile/presentation/profile_controller.dart';
import 'package:gawezeny/features/verification/presentation/identity_verification_screen.dart';

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => kTransparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(kTransparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class FakeChatRepository extends Fake implements ChatRepository {
  final Map<String, String> conversations = {};
  int getOrCreateCallCount = 0;
  ChatAuthResult? customAuthResult;

  @override
  Future<ChatAuthResult> getOrCreateConversation({
    required String matchId,
    required String partnerId,
  }) async {
    getOrCreateCallCount++;
    if (customAuthResult != null) return customAuthResult!;

    final convKey = '$matchId:$partnerId';
    if (!conversations.containsKey(convKey)) {
      conversations[convKey] = 'conv-$matchId';
    }
    return ChatAuthResult.allowed(conversations[convKey]!);
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId, {int limit = 60}) async {
    if (conversationId.contains('empty') || conversationId.contains('unchatted')) {
      return [];
    }
    return PreviewMockData.chatMessages;
  }

  @override
  Stream<List<ChatMessage>> subscribeToMessages(String conversationId) {
    return const Stream.empty();
  }

  @override
  Future<void> markMessagesRead(String conversationId) async {}

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    return ChatMessage(
      id: 'sent-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: 'mock-user-1',
      content: content,
      isRead: false,
      createdAt: DateTime.now(),
      status: MessageStatus.sent,
    );
  }
}

class FakeLikesMatchesController extends StateNotifier<LikesMatchesState>
    implements LikesMatchesController {
  FakeLikesMatchesController(super.initialState);

  @override
  void setTab(int index) {
    state = state.copyWith(activeTabIndex: index);
  }

  @override
  Future<void> loadAll() async {}

  @override
  Future<LikeResult?> likeBack(ReceivedLike receivedLike) async => null;

  @override
  Future<void> cancelSentLike(SentLike sentLike) async {}

  @override
  Future<void> unmatch(MutualMatch match) async {}
}

Widget createTestWidget({
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  group('Matches to Chat Flow Tests', () {
    testWidgets(
      'Tapping on a verified mutual match card opens ChatRoomScreen with partner details and history',
      (WidgetTester tester) async {
        setDevice(tester);

        final fakeRepo = FakeChatRepository();
        final verifiedMatch = PreviewMockData.mutualMatches[0]; // Sara Mahmoud

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              chatRepositoryProvider.overrideWithValue(fakeRepo),
              currentUserProvider.overrideWithValue(PreviewMockData.currentUserAuth),
              currentUserProfileProvider.overrideWithValue(PreviewMockData.currentProfile),
              likesMatchesControllerProvider.overrideWith(
                (ref) => FakeLikesMatchesController(
                  LikesMatchesState(
                    mutualMatches: [verifiedMatch],
                    activeTabIndex: 0,
                  ),
                ),
              ),
            ],
            child: const MatchesScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Verify mutual match cards are rendered
        expect(find.text('سارة محمود'), findsOneWidget);
        expect(find.text('تم التوافق بنية الزواج 💍'), findsOneWidget);

        // Tap on the card containing "سارة محمود"
        await tester.tap(find.text('سارة محمود'));
        await tester.pumpAndSettle();

        // ChatRoomScreen should now be visible
        expect(find.byType(ChatRoomScreen), findsOneWidget);
        expect(find.text('موثّق الهوية ✓'), findsOneWidget);

        // Chat messages for Sara should be visible
        expect(
          find.textContaining('السلام عليكم ورحمة الله وبركاته يا آنسة سارة'),
          findsOneWidget,
        );

        // Send a new message
        final inputFinder = find.byType(TextField);
        expect(inputFinder, findsOneWidget);
        await tester.enterText(inputFinder, 'يشرفنا الترتيب للرؤية الشرعية');
        await tester.pump();

        // Tap send button
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        expect(find.text('يشرفنا الترتيب للرؤية الشرعية'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping the dedicated "محادثة" button on match card directly opens ChatRoomScreen',
      (WidgetTester tester) async {
        setDevice(tester);

        final fakeRepo = FakeChatRepository();
        final verifiedMatch = PreviewMockData.mutualMatches[0]; // Sara Mahmoud

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              chatRepositoryProvider.overrideWithValue(fakeRepo),
              currentUserProvider.overrideWithValue(PreviewMockData.currentUserAuth),
              currentUserProfileProvider.overrideWithValue(PreviewMockData.currentProfile),
              likesMatchesControllerProvider.overrideWith(
                (ref) => FakeLikesMatchesController(
                  LikesMatchesState(
                    mutualMatches: [verifiedMatch],
                    activeTabIndex: 0,
                  ),
                ),
              ),
            ],
            child: const MatchesScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Find the "محادثة" button
        final chatButton = find.text('محادثة');
        expect(chatButton, findsOneWidget);

        // Tap the "محادثة" button
        await tester.tap(chatButton);
        await tester.pumpAndSettle();

        // ChatRoomScreen should now be opened
        expect(find.byType(ChatRoomScreen), findsOneWidget);
        expect(find.text('سارة محمود'), findsOneWidget);
      },
    );

    testWidgets(
      'Opening chat for a match without prior history renders empty chat prompt',
      (WidgetTester tester) async {
        setDevice(tester);

        final fakeRepo = FakeChatRepository();
        final unchattedPartner = UserProfile(
          id: 'candidate-new-partner',
          fullName: 'فاطمة أحمد',
          gender: GenderType.female,
          birthDate: DateTime(1999, 1, 1),
          age: 26,
          nationality: 'مصرية',
          residenceCity: 'طنطا',
          maritalStatus: MaritalStatusType.single,
          verificationStatus: VerificationStatusType.verified,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final unchattedMatch = MutualMatch(
          matchId: 'match-new-unchatted',
          partnerProfile: unchattedPartner,
          matchedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              chatRepositoryProvider.overrideWithValue(fakeRepo),
              currentUserProvider.overrideWithValue(PreviewMockData.currentUserAuth),
              currentUserProfileProvider.overrideWithValue(PreviewMockData.currentProfile),
              likesMatchesControllerProvider.overrideWith(
                (ref) => FakeLikesMatchesController(
                  LikesMatchesState(
                    mutualMatches: [unchattedMatch],
                    activeTabIndex: 0,
                  ),
                ),
              ),
            ],
            child: const MatchesScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('فاطمة أحمد'), findsOneWidget);

        // Tap to open chat
        await tester.tap(find.text('فاطمة أحمد'));
        await tester.pumpAndSettle();

        expect(find.byType(ChatRoomScreen), findsOneWidget);
        expect(find.text('ابدأ محادثة مع فاطمة أحمد'), findsOneWidget);
      },
    );

    testWidgets(
      'When current user is unverified, tapping match prompts verification dialog with navigation to ID screen',
      (WidgetTester tester) async {
        setDevice(tester);

        final fakeRepo = FakeChatRepository();
        final unverifiedProfile = PreviewMockData.currentProfile.copyWith(
          verificationStatus: VerificationStatusType.unverified,
        );
        final verifiedMatch = PreviewMockData.mutualMatches[0];

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              chatRepositoryProvider.overrideWithValue(fakeRepo),
              currentUserProvider.overrideWithValue(
                User(
                  id: PreviewMockData.currentUserId,
                  appMetadata: const {'provider': 'email', 'is_verified': false},
                  userMetadata: const {'full_name': 'أحمد مصطفى'},
                  aud: 'authenticated',
                  createdAt: '2025-01-01T10:00:00.000Z',
                ),
              ),
              currentUserProfileProvider.overrideWithValue(unverifiedProfile),
              likesMatchesControllerProvider.overrideWith(
                (ref) => FakeLikesMatchesController(
                  LikesMatchesState(
                    mutualMatches: [verifiedMatch],
                    activeTabIndex: 0,
                  ),
                ),
              ),
            ],
            child: const MatchesScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap match card
        await tester.tap(find.text('سارة محمود'));
        await tester.pumpAndSettle();

        // Verification required dialog should appear
        expect(find.text('توثيق الهوية مطلوب'), findsOneWidget);
        expect(find.text('توثيق الهوية الآن'), findsOneWidget);

        // Tap "توثيق الهوية الآن"
        await tester.tap(find.text('توثيق الهوية الآن'));
        await tester.pumpAndSettle();

        // Should navigate to IdentityVerificationScreen
        expect(find.byType(IdentityVerificationScreen), findsOneWidget);
      },
    );

    testWidgets(
      'When partner profile is unverified, tapping card shows warning notice and prevents chat opening',
      (WidgetTester tester) async {
        setDevice(tester);

        final fakeRepo = FakeChatRepository();
        final unverifiedPartner = UserProfile(
          id: 'candidate-unverified-partner',
          fullName: 'زينب الشريف',
          gender: GenderType.female,
          birthDate: DateTime(2001, 3, 10),
          age: 24,
          nationality: 'مصرية',
          residenceCity: 'الجيزة',
          maritalStatus: MaritalStatusType.single,
          verificationStatus: VerificationStatusType.unverified,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final matchWithUnverifiedPartner = MutualMatch(
          matchId: 'match-unverified-partner',
          partnerProfile: unverifiedPartner,
          matchedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              chatRepositoryProvider.overrideWithValue(fakeRepo),
              currentUserProvider.overrideWithValue(PreviewMockData.currentUserAuth),
              currentUserProfileProvider.overrideWithValue(PreviewMockData.currentProfile),
              likesMatchesControllerProvider.overrideWith(
                (ref) => FakeLikesMatchesController(
                  LikesMatchesState(
                    mutualMatches: [matchWithUnverifiedPartner],
                    activeTabIndex: 0,
                  ),
                ),
              ),
            ],
            child: const MatchesScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('زينب الشريف'), findsOneWidget);

        // Tap card
        await tester.tap(find.text('زينب الشريف'));
        await tester.pumpAndSettle();

        // ChatRoomScreen must NOT be opened
        expect(find.byType(ChatRoomScreen), findsNothing);

        // Warning snackbar must be displayed
        expect(
          find.text(
            'الطرف الآخر لم يُتمم توثيق هويته بعد. المحادثة تتاح فقط بعد توثيق الطرفين لضمان الجدية والأمان.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'When backend denies access due to block, displays error snackbar',
      (WidgetTester tester) async {
        setDevice(tester);

        final fakeRepo = FakeChatRepository()
          ..customAuthResult = ChatAuthResult.denied('BLOCKED', 'تعذر فتح المحادثة بسبب الحظر');
        final verifiedMatch = PreviewMockData.mutualMatches[0];

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              chatRepositoryProvider.overrideWithValue(fakeRepo),
              currentUserProvider.overrideWithValue(PreviewMockData.currentUserAuth),
              currentUserProfileProvider.overrideWithValue(PreviewMockData.currentProfile),
              likesMatchesControllerProvider.overrideWith(
                (ref) => FakeLikesMatchesController(
                  LikesMatchesState(
                    mutualMatches: [verifiedMatch],
                    activeTabIndex: 0,
                  ),
                ),
              ),
            ],
            child: const MatchesScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap match card
        await tester.tap(find.text('سارة محمود'));
        await tester.pumpAndSettle();

        // ChatRoomScreen must NOT be opened
        expect(find.byType(ChatRoomScreen), findsNothing);

        // Blocked snackbar must be displayed
        expect(find.text('تعذر فتح المحادثة بسبب الحظر'), findsOneWidget);
      },
    );
  });
}
