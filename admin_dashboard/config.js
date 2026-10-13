// ============================================================================
// ADMIN DASHBOARD CONFIGURATION
// Platform: جوزيني يا ماما
// Update these values with your actual Supabase project credentials.
// ============================================================================

const SUPABASE_URL = 'https://npcqnrucmwzompwmvztw.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_c-wIMq0t09mTU4Uhp4lafg_zI-ZjgwL';

// Tier display names (Arabic)
const TIER_LABELS = {
  'MONTHLY_200': 'شهري - 200 ج.م',
  'QUARTERLY_500': 'ربع سنوي - 500 ج.م',
  'SEMI_ANNUAL_900': 'نصف سنوي - 900 ج.م',
  'ANNUAL_1500': 'سنوي - 1500 ج.م',
  'BUNDLE_FB_1000': 'باقة فيسبوك - 1000 ج.م',
};

// Report status display names
const REPORT_STATUS_LABELS = {
  'PENDING': 'معلقة',
  'RESOLVED_BLOCKED': 'تم الحظر',
  'RESOLVED_DELETED': 'تم الحذف',
  'DISMISSED': 'مرفوضة',
};

// Verification status display names
const VERIFICATION_STATUS_LABELS = {
  'UNVERIFIED': 'غير موثق',
  'PENDING': 'قيد المراجعة',
  'VERIFIED': 'موثق',
  'FAILED': 'مرفوض',
  'MANUAL_REVIEW': 'مراجعة يدوية',
};

// Subscription status display names
const SUBSCRIPTION_STATUS_LABELS = {
  'FREE': 'مجاني',
  'PENDING_PAYMENT': 'بانتظار الدفع',
  'ACTIVE': 'نشط',
  'EXPIRED': 'منتهي',
  'CANCELLED': 'ملغي',
};

// Gender display names
const GENDER_LABELS = {
  'MALE': 'ذكر',
  'FEMALE': 'أنثى',
};

// Marital status display names
const MARITAL_STATUS_LABELS = {
  'SINGLE': 'أعزب/عزباء',
  'DIVORCED': 'مطلق/ة',
  'WIDOWED': 'أرمل/ة',
};
