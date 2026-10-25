import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/chat/domain/chat_message.dart';
import '../../features/likes_matches/domain/match_model.dart';
import '../../features/matching/domain/scored_profile.dart';
import '../../features/profile/domain/blocked_user_model.dart';
import '../../features/profile/domain/user_profile.dart';
import '../../features/subscriptions/domain/subscription_tier.dart';

/// Comprehensive realistic Arabic mock data set for "جوزيني يا ماما" preview mode.
class PreviewMockData {
  PreviewMockData._();

  // ---------------------------------------------------------------------------
  // AUTHENTICATED USER & PROFILE
  // ---------------------------------------------------------------------------

  static const String currentUserId = '00000000-0000-0000-0000-000000000001';

  static final User currentUserAuth = User(
    id: currentUserId,
    appMetadata: const {'provider': 'email', 'is_verified': true},
    userMetadata: const {'full_name': 'أحمد مصطفى'},
    aud: 'authenticated',
    email: 'ahmed.mostafa@example.com',
    createdAt: '2025-01-01T10:00:00.000Z',
  );

  static final UserProfile currentProfile = UserProfile(
    id: currentUserId,
    fullName: 'أحمد مصطفى',
    gender: GenderType.male,
    birthDate: DateTime(1996, 5, 14),
    age: 28,
    nationality: 'مصري',
    residenceCity: 'القاهرة',
    maritalStatus: MaritalStatusType.single,
    jobTitle: 'مهندس برمجيات',
    educationLevel: 'بكالوريوس هندسة حاسبات ومعلومات',
    heightCm: 182,
    weightKg: 78,
    smoker: false,
    prays: 'دائماً بالمسجد',
    wantsChildren: true,
    bio: 'مهندس برمجيات محب للاستقرار والعمل، أبحث عن شريكة حياة صالحة نقدر معاً قيمة المودة والرحمة وتكوين بيت مسلم هادئ وناجح.',
    verificationStatus: VerificationStatusType.verified,
    subscriptionStatus: SubscriptionStatusType.active,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime.now(),
  );

  static const String currentUserPhotoUrl =
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80';

  // ---------------------------------------------------------------------------
  // RECOMMENDED PROFILES (FEED)
  // ---------------------------------------------------------------------------

  static final List<ScoredProfile> recommendedProfiles = [
    // 1. سارة محمود
    ScoredProfile(
      profile: UserProfile(
        id: 'candidate-sara-01',
        fullName: 'سارة محمود',
        gender: GenderType.female,
        birthDate: DateTime(1999, 8, 20),
        age: 25,
        nationality: 'مصرية',
        residenceCity: 'الإسكندرية',
        maritalStatus: MaritalStatusType.single,
        jobTitle: 'صيدلانية سريرية',
        educationLevel: 'بكالوريوس صيدلة إكلينيكية',
        heightCm: 165,
        weightKg: 58,
        smoker: false,
        prays: 'دائماً في وقتها',
        wantsChildren: true,
        bio: 'صيدلانية، مهتمة بالصحة والقراءة، أبحث عن شريك حياة صاحب خلق ودين، يقدر المسؤولية والمودة، ويكون سنداً ورفيقاً للحياة.',
        verificationStatus: VerificationStatusType.verified,
        subscriptionStatus: SubscriptionStatusType.active,
        createdAt: DateTime(2025, 1, 10),
        updatedAt: DateTime.now(),
      ),
      compatibilityScore: 94,
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
    ),

    // 2. مريم خليل
    ScoredProfile(
      profile: UserProfile(
        id: 'candidate-mariam-02',
        fullName: 'مريم خليل',
        gender: GenderType.female,
        birthDate: DateTime(1997, 3, 12),
        age: 27,
        nationality: 'مصرية',
        residenceCity: 'الجيزة',
        maritalStatus: MaritalStatusType.single,
        jobTitle: 'مصممة ديكور وعمارة داخلية',
        educationLevel: 'بكالوريوس فنون تطبيقية',
        heightCm: 168,
        weightKg: 62,
        smoker: false,
        prays: 'دائماً',
        wantsChildren: true,
        bio: 'أحب الفنون والتصميم والهدوء الأسري، أبحث عن إنسان متفاهم، طموح، وصادق النية في بناء حياة مستقرة أساسها الاحترام.',
        verificationStatus: VerificationStatusType.verified,
        subscriptionStatus: SubscriptionStatusType.active,
        createdAt: DateTime(2025, 1, 15),
        updatedAt: DateTime.now(),
      ),
      compatibilityScore: 88,
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&auto=format&fit=crop&q=80',
    ),

    // 3. نور الهدى
    ScoredProfile(
      profile: UserProfile(
        id: 'candidate-nour-03',
        fullName: 'نور الهدى',
        gender: GenderType.female,
        birthDate: DateTime(2000, 11, 5),
        age: 24,
        nationality: 'مصرية',
        residenceCity: 'المنصورة',
        maritalStatus: MaritalStatusType.single,
        jobTitle: 'معلمة لغة عربية',
        educationLevel: 'ليسانس دار علوم ودبلوم تربوي',
        heightCm: 162,
        weightKg: 55,
        smoker: false,
        prays: 'دائماً',
        wantsChildren: true,
        bio: 'معلمة لغة عربية ومهتمة بالتربية والقرآن الكريم. أبحث عن زوج صالح صاحب مروءة ودين، يعين على طاعة الله وحسن المعاشرة.',
        verificationStatus: VerificationStatusType.verified,
        subscriptionStatus: SubscriptionStatusType.free,
        createdAt: DateTime(2025, 1, 20),
        updatedAt: DateTime.now(),
      ),
      compatibilityScore: 91,
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400&auto=format&fit=crop&q=80',
    ),

    // 4. ياسمين عبد الرحمن (Low Compatibility Candidate - 25% to verify no minimum threshold)
    ScoredProfile(
      profile: UserProfile(
        id: 'candidate-yasmin-04',
        fullName: 'ياسمين عبد الرحمن',
        gender: GenderType.female,
        birthDate: DateTime(1993, 2, 18),
        age: 32,
        nationality: 'مصرية',
        residenceCity: 'أسيوط',
        maritalStatus: MaritalStatusType.divorced,
        jobTitle: 'أخصائية تسويق رقمي',
        educationLevel: 'مؤهل جامعي / بكالوريوس',
        heightCm: 160,
        weightKg: 65,
        smoker: true,
        prays: 'أصلي معظم الأوقات',
        wantsChildren: false,
        bio: 'مستقلة وطموحة، أعمل في التسويق وأبحث عن شخص متفهم وناضج يحترم خصوصية الآخر.',
        verificationStatus: VerificationStatusType.unverified,
        subscriptionStatus: SubscriptionStatusType.free,
        createdAt: DateTime(2025, 2, 5),
        updatedAt: DateTime.now(),
      ),
      compatibilityScore: 25, // Low score to verify visibility without 50% floor!
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&auto=format&fit=crop&q=80',
    ),

    // 5. سلمى إبراهيم (Uncalculated Compatibility Candidate - null score)
    ScoredProfile(
      profile: UserProfile(
        id: 'candidate-salma-05',
        fullName: 'سلمى إبراهيم',
        gender: GenderType.female,
        birthDate: DateTime(2001, 4, 15),
        age: 23,
        nationality: 'مصرية',
        residenceCity: 'طنطا',
        maritalStatus: MaritalStatusType.single,
        jobTitle: 'محاسبة مالية',
        educationLevel: 'بكالوريوس تجارة شعبة محاسبة',
        heightCm: 166,
        weightKg: 60,
        smoker: false,
        prays: 'محافظ على الصلاة في وقتها',
        wantsChildren: true,
        bio: 'خريجة تجارة، أحب النظام والترتيب، أبحث عن شريك جاد لبناء حياة مستقرة أساسها المودة.',
        verificationStatus: VerificationStatusType.verified,
        subscriptionStatus: SubscriptionStatusType.free,
        createdAt: DateTime(2025, 2, 10),
        updatedAt: DateTime.now(),
      ),
      compatibilityScore: null, // Null to verify "لم يتم حساب التوافق بعد" label!
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=400&auto=format&fit=crop&q=80',
    ),

    // 6. عمر عبد العزيز (Male Candidate for browsing)
    ScoredProfile(
      profile: UserProfile(
        id: 'candidate-omar-06',
        fullName: 'عمر عبد العزيز',
        gender: GenderType.male,
        birthDate: DateTime(1995, 9, 10),
        age: 29,
        nationality: 'مصري',
        residenceCity: 'القاهرة',
        maritalStatus: MaritalStatusType.single,
        jobTitle: 'مهندس مدني استشاري',
        educationLevel: 'بكالوريوس هندسة مدنية',
        heightCm: 180,
        weightKg: 82,
        smoker: false,
        prays: 'محافظ على الصلاة في المسجد',
        wantsChildren: true,
        bio: 'مهندس مدني، أعمل في المقاولات والاستشارات، أبحث عن شريكة صالحة هادئة الطباع.',
        verificationStatus: VerificationStatusType.verified,
        subscriptionStatus: SubscriptionStatusType.active,
        createdAt: DateTime(2025, 1, 8),
        updatedAt: DateTime.now(),
      ),
      compatibilityScore: null, // Null when viewed by male (browsing only)
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80',
    ),

    // 7. كريم يوسف (Male Candidate for browsing)
    ScoredProfile(
      profile: UserProfile(
        id: 'candidate-karim-07',
        fullName: 'كريم يوسف',
        gender: GenderType.male,
        birthDate: DateTime(1991, 6, 22),
        age: 33,
        nationality: 'مصري',
        residenceCity: 'الإسكندرية',
        maritalStatus: MaritalStatusType.divorced,
        jobTitle: 'مدير تسويق عقاري',
        educationLevel: 'بكالوريوس إدارة أعمال',
        heightCm: 177,
        weightKg: 76,
        smoker: false,
        prays: 'محافظ على الصلاة في وقتها',
        wantsChildren: true,
        bio: 'محب للرياضة والبحر، أبحث عن بداية جديدة قائمة على التفاهم والوضوح والاحترام المتبادل.',
        verificationStatus: VerificationStatusType.verified,
        subscriptionStatus: SubscriptionStatusType.free,
        createdAt: DateTime(2025, 1, 12),
        updatedAt: DateTime.now(),
      ),
      compatibilityScore: null, // Null when viewed by male
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400&auto=format&fit=crop&q=80',
    ),
  ];

  // ---------------------------------------------------------------------------
  // MATCHES & LIKES DATA
  // ---------------------------------------------------------------------------

  // 1. Mutual Matches (3 cards)
  static final List<MutualMatch> mutualMatches = [
    MutualMatch(
      matchId: 'match-01',
      partnerProfile: recommendedProfiles[0].profile,
      primaryPhotoUrl: recommendedProfiles[0].primaryPhotoUrl,
      matchedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    MutualMatch(
      matchId: 'match-02',
      partnerProfile: recommendedProfiles[1].profile,
      primaryPhotoUrl: recommendedProfiles[1].primaryPhotoUrl,
      matchedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    MutualMatch(
      matchId: 'match-03',
      partnerProfile: UserProfile(
        id: 'candidate-heba-04',
        fullName: 'د. هبة الله كامل',
        gender: GenderType.female,
        birthDate: DateTime(1998, 7, 10),
        age: 26,
        nationality: 'مصرية',
        residenceCity: 'القاهرة',
        maritalStatus: MaritalStatusType.single,
        jobTitle: 'طبيبة أسنان',
        educationLevel: 'بكالوريوس طب وجراحة الفم والأسنان',
        heightCm: 164,
        weightKg: 59,
        smoker: false,
        prays: 'دائماً',
        wantsChildren: true,
        bio: 'طبيبة أسنان، محبة للعائلة والهدوء. أبحث عن شريك جاد ومحترم لبناء بيت مسلم متماسك.',
        verificationStatus: VerificationStatusType.verified,
        subscriptionStatus: SubscriptionStatusType.active,
        createdAt: DateTime(2025, 2, 1),
        updatedAt: DateTime.now(),
      ),
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&auto=format&fit=crop&q=80',
      matchedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  // 2. Received Likes (3 cards)
  static final List<ReceivedLike> receivedLikes = [
    ReceivedLike(
      likeId: 'recv-like-01',
      senderProfile: recommendedProfiles[2].profile, // نور الهدى
      primaryPhotoUrl: recommendedProfiles[2].primaryPhotoUrl,
      likedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    ReceivedLike(
      likeId: 'recv-like-02',
      senderProfile: UserProfile(
        id: 'candidate-yasmine-05',
        fullName: 'ياسمين الشريف',
        gender: GenderType.female,
        birthDate: DateTime(1998, 4, 18),
        age: 26,
        nationality: 'مصرية',
        residenceCity: 'القاهرة',
        maritalStatus: MaritalStatusType.single,
        jobTitle: 'مترجمة فورية معتمدة',
        educationLevel: 'ليسانس ألسن لغة إنجليزية',
        heightCm: 166,
        weightKg: 60,
        smoker: false,
        prays: 'دائماً',
        wantsChildren: true,
        bio: 'مترجمة فورية، أحب الثقافة والقراءة، أبحث عن إنسان مسؤول ومهذب نقيم معاً أسرة ناجحة.',
        verificationStatus: VerificationStatusType.verified,
        subscriptionStatus: SubscriptionStatusType.free,
        createdAt: DateTime(2025, 2, 5),
        updatedAt: DateTime.now(),
      ),
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400&auto=format&fit=crop&q=80',
      likedAt: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    ReceivedLike(
      likeId: 'recv-like-03',
      senderProfile: UserProfile(
        id: 'candidate-amira-06',
        fullName: 'أميرة حسني',
        gender: GenderType.female,
        birthDate: DateTime(1996, 9, 2),
        age: 28,
        nationality: 'مصرية',
        residenceCity: 'الإسكندرية',
        maritalStatus: MaritalStatusType.single,
        jobTitle: 'محاسبة قانونية',
        educationLevel: 'بكالوريوس تجارة شعبة محاسبة',
        heightCm: 160,
        weightKg: 56,
        smoker: false,
        prays: 'دائماً',
        wantsChildren: true,
        bio: 'محاسبة قانونية، أحب الصدق والوضوح والالتزام. أبحث عن شريك ناضج يقدر الحياة الزوجية.',
        verificationStatus: VerificationStatusType.verified,
        subscriptionStatus: SubscriptionStatusType.active,
        createdAt: DateTime(2025, 2, 7),
        updatedAt: DateTime.now(),
      ),
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&auto=format&fit=crop&q=80',
      likedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  // 3. Sent Likes (2 cards)
  static final List<SentLike> sentLikes = [
    SentLike(
      likeId: 'sent-like-01',
      targetProfile: UserProfile(
        id: 'candidate-rana-07',
        fullName: 'رنا عبد العزيز',
        gender: GenderType.female,
        birthDate: DateTime(1999, 12, 1),
        age: 25,
        nationality: 'مصرية',
        residenceCity: 'الشيخ زايد',
        maritalStatus: MaritalStatusType.single,
        jobTitle: 'مهندسة معمارية',
        educationLevel: 'بكالوريوس هندسة معمارية',
        heightCm: 167,
        weightKg: 58,
        smoker: false,
        prays: 'دائماً',
        wantsChildren: true,
        bio: 'مهندسة معمارية محبة للتطوير، أبحث عن إنسان طموح وملتزم يشاركني رحلة العمر.',
        verificationStatus: VerificationStatusType.verified,
        subscriptionStatus: SubscriptionStatusType.free,
        createdAt: DateTime(2025, 2, 10),
        updatedAt: DateTime.now(),
      ),
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=400&auto=format&fit=crop&q=80',
      likedAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    SentLike(
      likeId: 'sent-like-02',
      targetProfile: UserProfile(
        id: 'candidate-fatma-08',
        fullName: 'فاطمة الزهراء',
        gender: GenderType.female,
        birthDate: DateTime(1997, 6, 25),
        age: 27,
        nationality: 'مصرية',
        residenceCity: 'المعادي',
        maritalStatus: MaritalStatusType.single,
        jobTitle: 'باحثة أكاديمية بالجامعة',
        educationLevel: 'ماجستير في العلوم البيولوجية',
        heightCm: 163,
        weightKg: 57,
        smoker: false,
        prays: 'دائماً',
        wantsChildren: true,
        bio: 'باحثة أكاديمية، محبة للقراءة والبحث العلمي، أبحث عن زوج ذي خلق كريم وروح مسؤولة.',
        verificationStatus: VerificationStatusType.verified,
        subscriptionStatus: SubscriptionStatusType.active,
        createdAt: DateTime(2025, 2, 12),
        updatedAt: DateTime.now(),
      ),
      primaryPhotoUrl:
          'https://images.unsplash.com/photo-1520813792240-56fc4a3765a7?w=400&auto=format&fit=crop&q=80',
      likedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  // ---------------------------------------------------------------------------
  // CHAT INBOX & CONVERSATIONS
  // ---------------------------------------------------------------------------

  static final List<Conversation> conversations = [
    Conversation(
      id: 'preview-conv-sara',
      matchId: 'match-01',
      userOneId: currentUserId,
      userTwoId: 'candidate-sara-01',
      partnerId: 'candidate-sara-01',
      partnerName: 'سارة محمود',
      partnerPhotoUrl: recommendedProfiles[0].primaryPhotoUrl,
      partnerIsVerified: true,
      lastMessage: 'بإذن الله، يشرفنا التواصل مع والد حضرتك لتحديد موعد الزيارة الرسمية',
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 10)),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 1,
    ),
    Conversation(
      id: 'preview-conv-mariam',
      matchId: 'match-02',
      userOneId: currentUserId,
      userTwoId: 'candidate-mariam-02',
      partnerId: 'candidate-mariam-02',
      partnerName: 'مريم خليل',
      partnerPhotoUrl: recommendedProfiles[1].primaryPhotoUrl,
      partnerIsVerified: true,
      lastMessage: 'شكراً لذوقك واحترامك أستاذ أحمد، تشرفت بالحديث معك.',
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      unreadCount: 0,
    ),
    Conversation(
      id: 'preview-conv-heba',
      matchId: 'match-03',
      userOneId: currentUserId,
      userTwoId: 'candidate-heba-04',
      partnerId: 'candidate-heba-04',
      partnerName: 'د. هبة الله كامل',
      partnerPhotoUrl:
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&auto=format&fit=crop&q=80',
      partnerIsVerified: true,
      lastMessage: 'وعليكم السلام ورحمة الله وبركاته، أهلاً بحضرتك.',
      lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      unreadCount: 0,
    ),
  ];

  // Realistic matrimonial chat messages between أحمد and سارة
  static final List<ChatMessage> chatMessages = [
    ChatMessage(
      id: 'msg-01',
      conversationId: 'preview-conv-sara',
      senderId: currentUserId,
      content: 'السلام عليكم ورحمة الله وبركاته يا آنسة سارة، تشرفت بالتوافق وممتن جداً لاهتمامك بملفي الشخصي.',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
      status: MessageStatus.read,
    ),
    ChatMessage(
      id: 'msg-02',
      conversationId: 'preview-conv-sara',
      senderId: 'candidate-sara-01',
      content: 'وعليكم السلام ورحمة الله وبركاته أستاذ أحمد، الشرف لي وسعيدة بالتواصل الهادف والجاد.',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
      status: MessageStatus.read,
    ),
    ChatMessage(
      id: 'msg-03',
      conversationId: 'preview-conv-sara',
      senderId: currentUserId,
      content: 'قرأت في ملفك الكريم رغبتك بالاستقرار وبناء أسرة على المودة والرحمة، وهذا هو نفس مقصدي وهدفي تماماً.',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
      status: MessageStatus.read,
    ),
    ChatMessage(
      id: 'msg-04',
      conversationId: 'preview-conv-sara',
      senderId: 'candidate-sara-01',
      content: 'بالفعل، هذا أهم ركن بالنسبة لي، وأحب أن تكون الخطوات واضحة ومرتبة وفي النور من البداية.',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
      status: MessageStatus.read,
    ),
    ChatMessage(
      id: 'msg-05',
      conversationId: 'preview-conv-sara',
      senderId: currentUserId,
      content: 'بكل تأكيد، ويسعدني ويشرفني التواصل المباشر مع والد حضرتك الكريم لتحديد موعد للزيارة الرسمية والتعارف الأسري.',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
      status: MessageStatus.read,
    ),
    ChatMessage(
      id: 'msg-06',
      conversationId: 'preview-conv-sara',
      senderId: 'candidate-sara-01',
      content: 'بإذن الله، يشرفنا التواصل مع والد حضرتك لتحديد موعد الزيارة الرسمية، وسأزودك برقم هاتفه بعد إخباره وموافقته.',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      status: MessageStatus.sent,
    ),
  ];

  // ---------------------------------------------------------------------------
  // IDENTITY VERIFICATION PRESETS
  // ---------------------------------------------------------------------------

  // Minimal valid 1x1 transparent PNG bytes for test/preview image byte holders
  static final Uint8List samplePngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  // ---------------------------------------------------------------------------
  // SUBSCRIPTIONS & BLOCKED USERS
  // ---------------------------------------------------------------------------

  static final SubscriptionModel activeSubscription = SubscriptionModel(
    id: 'sub-preview-01',
    userId: currentUserId,
    tier: SubscriptionPlanTier.annual1500,
    amountEgp: 1500,
    status: SubscriptionStatusType.active,
    startsAt: DateTime.now().subtract(const Duration(days: 30)),
    endsAt: DateTime.now().add(const Duration(days: 335)),
    paymentReference: 'PREVIEW-PAY-ANNUAL-001',
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
  );

  static final List<BlockedUserModel> blockedUsers = [
    BlockedUserModel(
      id: 'block-01',
      blockedUserId: 'user-blocked-01',
      fullName: 'محمود عبد السلام',
      residenceCity: 'طنطا',
      photoUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80',
      blockedAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
    BlockedUserModel(
      id: 'block-02',
      blockedUserId: 'user-blocked-02',
      fullName: 'خالد عبد الرحمن',
      residenceCity: 'المنصورة',
      photoUrl: null,
      blockedAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
  ];
}
