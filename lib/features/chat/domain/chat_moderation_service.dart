enum ChatViolationType {
  phoneNumber,
  externalLink,
  socialMedia,
  customKeyword,
}

class ChatModerationResult {
  final bool isAllowed;
  final ChatViolationType? violationType;
  final String? matchedPattern;
  final String? message;

  const ChatModerationResult({
    required this.isAllowed,
    this.violationType,
    this.matchedPattern,
    this.message,
  });

  factory ChatModerationResult.allowed() {
    return const ChatModerationResult(isAllowed: true);
  }

  factory ChatModerationResult.blocked({
    required ChatViolationType type,
    String? pattern,
    required String message,
  }) {
    return ChatModerationResult(
      isAllowed: false,
      violationType: type,
      matchedPattern: pattern,
      message: message,
    );
  }
}

/// Service providing intelligent chat moderation for Egyptian & international
/// contact exchange prevention (phone numbers, external links, social media handles).
class ChatModerationService {
  ChatModerationService._();

  /// Normalizes Arabic text for strict pattern matching.
  static String normalize(String text) {
    if (text.isEmpty) return '';

    var res = text.toLowerCase();

    // Map Eastern Arabic & Persian numerals to Western digits
    const easternNumerals = '٠١٢٣٤٥٦٧٨٩';
    const persianNumerals = '۰۱۲۳۴۵۶۷۸۹';
    const westernNumerals = '0123456789';

    for (var i = 0; i < 10; i++) {
      res = res.replaceAll(easternNumerals[i], westernNumerals[i]);
      res = res.replaceAll(persianNumerals[i], westernNumerals[i]);
    }

    // Strip Arabic diacritics (tashkeel)
    res = res.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

    // Strip Tatweel
    res = res.replaceAll('\u0640', '');

    // Strip zero-width & invisible characters
    res = res.replaceAll(RegExp(r'[\u200B-\u200F\uFEFF\u00AD]'), '');

    // Normalize Alef variations
    res = res.replaceAll(RegExp(r'[أإآٱ]'), 'ا');

    // Normalize Taa Marbuta
    res = res.replaceAll('ة', 'ه');

    // Normalize Yaa / Alef Maksura
    res = res.replaceAll('ى', 'ي');

    return res;
  }

  /// Evaluates message content and returns moderation verdict.
  static ChatModerationResult check(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) {
      return ChatModerationResult.allowed();
    }

    final normalized = normalize(trimmed);

    // -------------------------------------------------------------------------
    // 1. PHONE NUMBERS DETECTION
    // -------------------------------------------------------------------------
    final digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');

    // Egyptian mobile numbers (010, 011, 012, 015 - 11 digits, or with 20/0020/+20)
    final egyptianPhoneRegex = RegExp(r'(20)?1[0125][0-9]{8}');
    if (egyptianPhoneRegex.hasMatch(digitsOnly)) {
      return ChatModerationResult.blocked(
        type: ChatViolationType.phoneNumber,
        pattern: 'Egyptian Mobile',
        message: 'مشاركة أرقام الهواتف غير مسموح بها داخل المحادثة حفاظاً على خصوصيتك وأمانك وفقاً لشروط الاستخدام.',
      );
    }

    // International numbers: with + or 00 prefix and 7-15 digits
    final intlPhoneRegex = RegExp(r'(\+|00)[0-9]{1,4}[\s\-\.()]{0,3}[0-9]{3,}[\s\-\.()]{0,3}[0-9]{3,}');
    if (intlPhoneRegex.hasMatch(normalized)) {
      return ChatModerationResult.blocked(
        type: ChatViolationType.phoneNumber,
        pattern: 'International Phone',
        message: 'مشاركة أرقام الهواتف والتواصل الخارجي غير مسموح بها داخل المحادثة.',
      );
    }

    // Sequence of 8 to 14 digits separated by whitespace, dashes, or dots
    final spacedDigitsRegex = RegExp(r'(^|\s|[^\w])([0-9][\s\-\.()]{0,2}){8,14}($|\s|[^\w])');
    if (digitsOnly.length >= 8 && spacedDigitsRegex.hasMatch(normalized)) {
      return ChatModerationResult.blocked(
        type: ChatViolationType.phoneNumber,
        pattern: 'Spaced Digits Phone',
        message: 'مشاركة أرقام الهواتف غير مسموح بها داخل المحادثة.',
      );
    }

    // Spelled-out Egyptian phone numbers in Arabic text
    // e.g. "زيرو عشره", "صفر واحد صفر", "زيرو واحد اتنين", "رقمي زيرو..."
    final spelledPhoneIntro = RegExp(r'(زيرو|صفر)\s*(عشر[ةه]|واحد\s*صفر|واحد\s*[0-9]|[0-9]\s*[0-9])');
    final explicitPhoneHint = RegExp(r'(رقمي|نمرتي|موبايلي|فون|واتس)\s*(هو|:)?\s*([0-9]|زيرو|صفر|واحد)');
    if (spelledPhoneIntro.hasMatch(normalized) || explicitPhoneHint.hasMatch(normalized)) {
      return ChatModerationResult.blocked(
        type: ChatViolationType.phoneNumber,
        pattern: 'Spelled Out Phone',
        message: 'مشاركة أرقام الهواتف أو طلب التواصل الخارجي غير مسموح بها داخل المحادثة.',
      );
    }

    // High count of spelled-out digit words in a single message
    final digitWordsRegex = RegExp(r'(زيرو|صفر|واحد|اتنين|تلاته|اربعه|خمسه|سته|سبعه|تمانيه|تسعه)');
    final matches = digitWordsRegex.allMatches(normalized).length;
    if (matches >= 5) {
      return ChatModerationResult.blocked(
        type: ChatViolationType.phoneNumber,
        pattern: 'Multiple Spelled Digits',
        message: 'مشاركة أرقام الهواتف بوسائل كتابية بديلة غير مسموح بها داخل المحادثة.',
      );
    }

    // -------------------------------------------------------------------------
    // 2. EXTERNAL LINKS & URLS DETECTION
    // -------------------------------------------------------------------------
    // Protocol URLs: http://, https://, ftp://
    if (RegExp(r'https?:\/\/[^\s]+', caseSensitive: false).hasMatch(normalized) ||
        RegExp(r'ftp:\/\/[^\s]+', caseSensitive: false).hasMatch(normalized)) {
      return ChatModerationResult.blocked(
        type: ChatViolationType.externalLink,
        pattern: 'Direct URL',
        message: 'إرسال الروابط والمواقع الخارجية غير مسموح به داخل المحادثة لحماية المستخدمين.',
      );
    }

    // Standard web prefixes: www., ftp.
    if (RegExp(r'www\.[a-z0-9\-]+(\.[a-z]{2,})+', caseSensitive: false).hasMatch(normalized)) {
      return ChatModerationResult.blocked(
        type: ChatViolationType.externalLink,
        pattern: 'WWW Domain',
        message: 'إرسال الروابط والمواقع الخارجية غير مسموح به داخل المحادثة.',
      );
    }

    // Common TLDs (with or without spaces around dot, or with dot words)
    // e.g. "facebook.com", "instagr.am", "wa.me", "t.me", "bit.ly"
    final tldRegex = RegExp(
      r'[a-z0-9\-]+(\s*(\.|\(\.\)|\[\.\])\s*)(com|net|org|app|io|me|eg|co|ai|ly|gl|link|site|online|xyz|top|info|biz|tv|cc|to)($|\s|[^\w])',
      caseSensitive: false,
    );
    final shortenerRegex = RegExp(
      r'(t\.me|wa\.me|bit\.ly|tinyurl\.com|cutt\.ly|instagr\.am|fb\.com|fb\.me)\/[a-z0-9\-_]+',
      caseSensitive: false,
    );
    final obfuscatedDotRegex = RegExp(r'(دوت\s*كوم|دوت\s*نت|دوت\s*اورج|\s*dot\s*com|\s*dot\s*net)', caseSensitive: false);

    if (tldRegex.hasMatch(normalized) ||
        shortenerRegex.hasMatch(normalized) ||
        obfuscatedDotRegex.hasMatch(normalized)) {
      return ChatModerationResult.blocked(
        type: ChatViolationType.externalLink,
        pattern: 'Domain / Shortener',
        message: 'مشاركة الروابط الخارجية أو النطاقات غير مسموح بها داخل المحادثة.',
      );
    }

    // -------------------------------------------------------------------------
    // 3. SOCIAL MEDIA HANDLES & CONTACT INTENT DETECTION
    // -------------------------------------------------------------------------
    // Direct social handle: @username (3 to 30 alphanumeric characters)
    if (RegExp(r'(^|\s)@[a-z0-9_\.]{3,30}($|\s)', caseSensitive: false).hasMatch(normalized)) {
      return ChatModerationResult.blocked(
        type: ChatViolationType.socialMedia,
        pattern: 'Social Handle (@)',
        message: 'مشاركة أسماء المستخدمين وحسابات التواصل غير مسموح بها داخل المحادثة.',
      );
    }

    // Egyptian & Standard Arabic phrases requesting social media accounts:
    // "ابعتلي أكاونت الفيسبوك", "ابعتلي الأكاونت بتاعك", "ابعتلي حسابك", "ابعتلي الإنستجرام", "ابعتلي الواتساب"
    final requestPatterns = RegExp(
      r'(ابعت|ابعتي|ابعتلي|ابعتيلي|هات|هاتي|اديني|عايز|عايزه|عاوز|عاوزه|نكمل|نتكلم|شات|كلمني|كلميني)\s*.*(اكاونت|حساب|فيسبوك|فيس|انستا|انستجرام|واتس|واتساب|تلي|تليجرام|تيليجرام|سناب|سنابشات|تيك\s*توك|فون|نمره|رقمك|رقمي|يوزرك|يوزر)',
      caseSensitive: false,
    );
    final myAccountPatterns = RegExp(
      r'(اكاونت|حسابي|يوزري|صفحتي)\s*(علي|في|بتاعي)?\s*(الفيسبوك|الفيس|الانستا|الانستجرام|الواتس|الواتساب|التليجرام|السناب)',
      caseSensitive: false,
    );
    final chatOutsidePatterns = RegExp(
      r'(نتكلم|نكلم|نكمل\s*كلام)\s*(بره|برة|فون|واتس|علي\s*الواتس|علي\s*الفيس|علي\s*الانستا)|(تواصل\s*خارجي|شات\s*بره|شات\s*برة)',
      caseSensitive: false,
    );

    if (requestPatterns.hasMatch(normalized) ||
        myAccountPatterns.hasMatch(normalized) ||
        chatOutsidePatterns.hasMatch(normalized)) {
      return ChatModerationResult.blocked(
        type: ChatViolationType.socialMedia,
        pattern: 'Social Media Exchange Intent',
        message: 'طلب أو تبادل حسابات التواصل الاجتماعي (فيسبوك، انستجرام، واتساب، تليجرام، وغيرها) غير مسموح به؛ لضمان جدية وأمان التعارف داخل التطبيق.',
      );
    }

    return ChatModerationResult.allowed();
  }
}
