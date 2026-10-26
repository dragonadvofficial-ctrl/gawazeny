/// Application-wide string constants for the "جوزيني يا ماما" platform.
abstract final class AppStrings {
  // Brand & General
  static const String appName = 'جوزيني يا ماما';
  static const String appTagline = 'منصة الزواج الجاد المتوافقة مع القيم العائلية والشريعة';
  static const String welcomeMessage = 'أهلاً بك في جوزيني يا ماما';
  static const String startJourney = 'ابدأ رحلة البحث عن شريك حياتك';

  // Navigation & Sections
  static const String navHome = 'الرئيسية';
  static const String navMatches = 'التوافقات';
  static const String navLikes = 'الإعجابات';
  static const String navChat = 'المحادثات';
  static const String navProfile = 'ملفي الشخصي';

  // Common Actions
  static const String confirm = 'تأكيد';
  static const String cancel = 'إلغاء';
  static const String save = 'حفظ';
  static const String edit = 'تعديل';
  static const String delete = 'حذف';
  static const String next = 'التالي';
  static const String back = 'السابق';
  static const String skip = 'تخطي';
  static const String startYourJourneyNow = 'ابدأ رحلتك الآن';
  static const String retry = 'إعادة المحاولة';
  static const String submit = 'إرسال';
  static const String block = 'حظر';
  static const String report = 'إبلاغ';
  static const String seeMore = 'عرض المزيد';
  static const String seeLess = 'عرض أقل';

  // Gender
  static const String genderMale = 'رجل';
  static const String genderFemale = 'امرأة';

  // Marital Status
  static const String maritalSingle = 'أعزب / عزباء';
  static const String maritalDivorced = 'مطلق / مطلقة';
  static const String maritalWidowed = 'أرمل / أرملة';

  // Verification Status
  static const String verificationUnverified = 'غير موثق';
  static const String verificationPending = 'قيد المراجعة';
  static const String verificationVerified = 'موثق بالهوية الوطنية';
  static const String verificationFailed = 'فشل التوثيق';
  static const String verificationManualReview = 'مراجعة يدوية';

  // Subscription Plans
  static const String subPlanMonthly = 'اشتراك شهري (200 ج.م)';
  static const String subPlanQuarterly = 'اشتراك ربع سنوي (500 ج.م)';
  static const String subPlanSemiAnnual = 'اشتراك نصف سنوي (900 ج.م)';
  static const String subPlanAnnual = 'اشتراك سنوي (1500 ج.م)';
  static const String subPlanBundle = 'باقة الفيسبوك المميزة (1000 ج.م)';

  // Error Messages
  static const String errorGeneric = 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً';
  static const String errorNoInternet = 'لا يوجد اتصال بالإنترنت';
  static const String errorAuthRequired = 'يرجى تسجيل الدخول أولاً';
  static const String errorSessionExpired = 'انتهت صلاحية الجلسة، يرجى إعادة تسجيل الدخول';

  // Identity Verification
  static const String idVerificationTitle = 'توثيق الحساب';
  static const String idVerificationSubtitle = 'لضمان مجتمع آمن وجاد، نطلب مراجعة بطاقة الرقم القومي والصورة الشخصية';
  static const String uploadIdCard = 'رفع صورة بطاقة الرقم القومي';
  static const String takeSelfie = 'التقاط الصورة الشخصية';
  static const String verificationPendingNotice =
      'تم استلام طلب توثيق حسابك بنجاح. برجاء الانتظار، سيتم مراجعة طلبك خلال 15 دقيقة.';

  // Authentication & Session Persistence
  static const String rememberMeOnThisDevice = 'تذكّرني على هذا الجهاز';
  static const String creatingAccount = 'جارٍ إنشاء الحساب...';
  static const String signingIn = 'جارٍ تسجيل الدخول...';
  static const String accountCreatedSuccessTitle = 'تم إنشاء حسابك بنجاح! 📩';
  static const String accountCreatedSuccessDesc =
      'بعتنالك رسالة تأكيد على بريدك الإلكتروني. افتح الرسالة واضغط على رابط التأكيد لتفعيل حسابك. لو مش لاقي الرسالة، راجع مجلد الرسائل غير المرغوب فيها (Spam).';
  static const String resendConfirmationEmail = 'إعادة إرسال رسالة التأكيد';
  static const String goToSignIn = 'الانتقال لتسجيل الدخول';
}
