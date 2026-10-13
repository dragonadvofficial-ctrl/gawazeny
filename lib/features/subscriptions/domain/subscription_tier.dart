import '../../profile/domain/user_profile.dart';

/// Enumeration of subscription tiers matching the Supabase `subscription_plan_tier` enum.
enum SubscriptionPlanTier {
  monthly200(
    dbValue: 'MONTHLY_200',
    titleArabic: 'اشتراك شهري',
    titleEnglish: 'Monthly Subscription',
    subtitleArabic: 'باقة شهرية متجددة',
    subtitleEnglish: 'Renewable monthly package',
    priceEgp: 200,
    originalPriceEgp: null,
    durationDays: 30,
    description: 'وصول كامل لجميع الملفات والتوافقات وإرسال إعجابات جادة لمدة 30 يوماً',
    descriptionEn: 'Full access to all candidate profiles, daily matches, and unlimited likes for 30 days',
    isPopular: false,
    isBestValue: false,
    isSpecial: false,
    perks: [
      'إرسال إعجابات غير محدودة بنية الزواج',
      'تصفح كافة الملفات والتوافقات اليومية',
      'إمكانية بدء محادثات فورية عند التوافق المتبادل',
      'دعم فني عائلي مخصص للرد على الاستفسارات',
    ],
    perksEn: [
      'Unlimited serious matrimonial likes',
      'Browse all daily profiles and compatibility recommendations',
      'Instant direct chats upon mutual match',
      'Dedicated family support team for inquiries',
    ],
  ),
  quarterly500(
    dbValue: 'QUARTERLY_500',
    titleArabic: 'اشتراك 3 شهور',
    titleEnglish: '3 Months Subscription',
    subtitleArabic: 'وفر 100 ج.م (بدلاً من 600 ج.م)',
    subtitleEnglish: 'Save 100 EGP (was 600 EGP)',
    priceEgp: 500,
    originalPriceEgp: 600,
    durationDays: 90,
    description: 'الباقة الاقتصادية للتعارف الجاد والمدروس مع أولوية الظهور في نتائج البحث',
    descriptionEn: 'Economical package for serious dating with advanced search priority',
    isPopular: false,
    isBestValue: false,
    isSpecial: false,
    perks: [
      'توفير 100 ج.م مقارنة بالاشتراك الشهري',
      'أولوية متقدمة في نتائج بحث شريك الحياة',
      'إرسال إعجابات غير محدودة طوال الـ 90 يوماً',
      'إشعار فوري بقراءة الطرف الآخر لرسائلك',
    ],
    perksEn: [
      'Save 100 EGP compared to monthly plan',
      'Higher ranking in partner search results',
      'Unlimited serious likes throughout 90 days',
      'Read receipts when your messages are opened',
    ],
  ),
  semiAnnual900(
    dbValue: 'SEMI_ANNUAL_900',
    titleArabic: 'اشتراك 6 شهور',
    titleEnglish: '6 Months Subscription',
    subtitleArabic: 'الأكثر اختياراً للزواج الجاد',
    subtitleEnglish: 'Most popular choice for marriage',
    priceEgp: 900,
    originalPriceEgp: 1200,
    durationDays: 180,
    description: 'الخيار الأكثر شعبية للبحث الجاد والتعارف المنضبط بتوفير 300 ج.م (خصم 25%)',
    descriptionEn: 'Most popular option for serious marriage seeking with 300 EGP savings (25% off)',
    isPopular: true,
    isBestValue: false,
    isSpecial: false,
    perks: [
      'توفير 300 ج.م كاملة (خصم 25%)',
      'شارة "باحث جاد" مميزة تظهر على ملفك الشخصي',
      'أولوية مضاعفة في نتائج البحث والترشيحات اليومية',
      'تقرير وإحصائيات تفاعلية بمن شاهد ملفك الشخصي',
      'جلسة استشارية تعارف هاتفية مجانية من أخصائي العلاقات',
    ],
    perksEn: [
      'Full 300 EGP savings (25% discount)',
      'Distinctive "Serious Seeker" profile badge',
      'Double boost in search results and daily matches',
      'Interactive visitor analytics on your profile',
      'Free 1-on-1 matrimonial consultation session',
    ],
  ),
  annual1500(
    dbValue: 'ANNUAL_1500',
    titleArabic: 'اشتراك 12 شهر',
    titleEnglish: '12 Months (Annual)',
    subtitleArabic: 'أفضل قيمة وأعلى توفير (بدلاً من 2400 ج.م)',
    subtitleEnglish: 'Best value & highest savings (was 2400 EGP)',
    priceEgp: 1500,
    originalPriceEgp: 2400,
    durationDays: 365,
    description: 'أفضل استقرار وقيمة طوال العام مع توفير 900 ج.م ومرافقة عائلية كاملة',
    descriptionEn: 'Greatest stability and value all year with 900 EGP savings and full platform liaison',
    isPopular: false,
    isBestValue: true,
    isSpecial: false,
    perks: [
      'توفير 900 ج.م كاملة (خصم 38% مقارنة بالشهري)',
      'ظهور دائم في قمة الترشيحات والتوافقات الأسبوعية',
      'مرافقة واستشارات مستمرة طوال العام مع وسيط المنصة',
      'إمكانية إيقاف مؤقت للاشتراك لمرة واحدة حتى 60 يوماً',
      'وصول لكافة الميزات الحالية والمستقبلية بلا حدود',
    ],
    perksEn: [
      'Save 900 EGP (38% discount vs monthly)',
      'Permanent placement at the top of weekly matches',
      'Continuous matrimonial liaison support all year',
      'Ability to pause subscription once up to 60 days',
      'Unlimited access to all present and future features',
    ],
  ),
  bundleFb1000(
    dbValue: 'BUNDLE_FB_1000',
    titleArabic: 'عرض فيسبوك المميز',
    titleEnglish: 'Facebook VIP Bundle',
    subtitleArabic: 'بوست على فيسبوك + اشتراك شهر هدية',
    subtitleEnglish: 'Facebook Feature Post + 1-Month Free',
    priceEgp: 1000,
    originalPriceEgp: null,
    durationDays: 30,
    description: 'نشر مواصفاتك في مجموعات جوزيني يا ماما الرسمية على فيسبوك (+150 ألف متابع) مع اشتراك شهر هدية داخل التطبيق',
    descriptionEn: 'Feature your matrimonial bio on our official Facebook pages (+150K followers) with 1 month free in-app',
    isPopular: false,
    isBestValue: false,
    isSpecial: true,
    perks: [
      'نشر بوست مخصص بمواصفاتك على صفحة ومجموعات فيسبوك الرسمية',
      'اشتراك شهر كامل هدية داخل التطبيق (قيمة 200 ج.م)',
      'وصول لأكثر من 150 ألف متابع مهتم بالزواج الشرعي المحترم',
      'مراجعة وتنسيق صياغة البوست باحترافية من فريق المنصة',
    ],
    perksEn: [
      'Dedicated post on official Facebook groups & page',
      'Full 1-month in-app subscription gift (200 EGP value)',
      'Direct reach to 150K+ serious marriage seekers',
      'Professional bio formatting by platform editors',
    ],
  );

  final String dbValue;
  final String titleArabic;
  final String titleEnglish;
  final String subtitleArabic;
  final String subtitleEnglish;
  final int priceEgp;
  final int? originalPriceEgp;
  final int durationDays;
  final String description;
  final String descriptionEn;
  final bool isPopular;
  final bool isBestValue;
  final bool isSpecial;
  final List<String> perks;
  final List<String> perksEn;

  const SubscriptionPlanTier({
    required this.dbValue,
    required this.titleArabic,
    required this.titleEnglish,
    required this.subtitleArabic,
    required this.subtitleEnglish,
    required this.priceEgp,
    this.originalPriceEgp,
    required this.durationDays,
    required this.description,
    required this.descriptionEn,
    this.isPopular = false,
    this.isBestValue = false,
    this.isSpecial = false,
    required this.perks,
    required this.perksEn,
  });

  /// Calculates percentage of savings if original price exists.
  int? get discountPercentage {
    if (originalPriceEgp == null || originalPriceEgp! <= priceEgp) return null;
    return (((originalPriceEgp! - priceEgp) / originalPriceEgp!) * 100).round();
  }

  /// Calculates net savings amount in EGP.
  int? get savingsEgp {
    if (originalPriceEgp == null || originalPriceEgp! <= priceEgp) return null;
    return originalPriceEgp! - priceEgp;
  }

  /// Formatted price with Egyptian currency symbol.
  String get formattedPrice => '$priceEgp ج.م';

  /// Localized title based on user language.
  String localizedTitle(bool isArabic) => isArabic ? titleArabic : titleEnglish;

  /// Localized subtitle based on user language.
  String localizedSubtitle(bool isArabic) =>
      isArabic ? subtitleArabic : subtitleEnglish;

  /// Localized description based on user language.
  String localizedDescription(bool isArabic) =>
      isArabic ? description : descriptionEn;

  /// Localized perks list.
  List<String> localizedPerks(bool isArabic) => isArabic ? perks : perksEn;

  /// Formatted duration in Arabic.
  String get formattedDuration {
    switch (this) {
      case SubscriptionPlanTier.monthly200:
        return 'شهر واحد';
      case SubscriptionPlanTier.quarterly500:
        return '3 أشهر';
      case SubscriptionPlanTier.semiAnnual900:
        return '6 أشهر';
      case SubscriptionPlanTier.annual1500:
        return '12 شهراً (سنة)';
      case SubscriptionPlanTier.bundleFb1000:
        return 'شهر واحد + بوست مميز';
    }
  }

  /// Localized duration text.
  String localizedDuration(bool isArabic) {
    if (isArabic) return formattedDuration;
    switch (this) {
      case SubscriptionPlanTier.monthly200:
        return '1 Month';
      case SubscriptionPlanTier.quarterly500:
        return '3 Months';
      case SubscriptionPlanTier.semiAnnual900:
        return '6 Months';
      case SubscriptionPlanTier.annual1500:
        return '12 Months (1 Year)';
      case SubscriptionPlanTier.bundleFb1000:
        return '1 Month + VIP Post';
    }
  }

  static SubscriptionPlanTier fromDbValue(String value) {
    for (final tier in SubscriptionPlanTier.values) {
      if (tier.dbValue == value) {
        return tier;
      }
    }
    return SubscriptionPlanTier.monthly200;
  }
}

/// Domain model representing a user subscription record from the `subscriptions` table.
class SubscriptionModel {
  final String id;
  final String userId;
  final SubscriptionPlanTier tier;
  final double amountEgp;
  final SubscriptionStatusType status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? paymentReference;
  final DateTime createdAt;

  const SubscriptionModel({
    required this.id,
    required this.userId,
    required this.tier,
    required this.amountEgp,
    required this.status,
    this.startsAt,
    this.endsAt,
    this.paymentReference,
    required this.createdAt,
  });

  /// Whether the subscription is currently active and within its valid date range.
  bool get isActive {
    if (status != SubscriptionStatusType.active) return false;
    if (endsAt == null) return true;
    return endsAt!.isAfter(DateTime.now());
  }

  /// Whether the subscription has expired.
  bool get isExpired {
    if (status == SubscriptionStatusType.expired) return true;
    if (endsAt != null && endsAt!.isBefore(DateTime.now())) return true;
    return false;
  }

  /// Days remaining before the subscription ends.
  int get daysRemaining {
    if (endsAt == null) return 0;
    final diff = endsAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    return SubscriptionModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      tier: SubscriptionPlanTier.fromDbValue(map['tier'] as String),
      amountEgp: (map['amount_egp'] as num).toDouble(),
      status: SubscriptionStatusType.fromDbValue(
        (map['status'] as String?) ?? 'PENDING_PAYMENT',
      ),
      startsAt: map['starts_at'] != null
          ? DateTime.parse(map['starts_at'] as String)
          : null,
      endsAt: map['ends_at'] != null
          ? DateTime.parse(map['ends_at'] as String)
          : null,
      paymentReference: map['payment_reference'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'tier': tier.dbValue,
      'amount_egp': amountEgp,
      'status': status.toDbValue(),
      'starts_at': startsAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'payment_reference': paymentReference,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
