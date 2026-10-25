// ============================================================================
// ADMIN DASHBOARD APPLICATION
// Platform: جوزيني يا ماما
// Complete production-ready admin dashboard with Supabase integration & Demo Mode.
// ============================================================================

(() => {
  'use strict';

  // --------------------------------------------------------------------------
  // Configuration & Supabase Initialization
  // --------------------------------------------------------------------------
  const DEFAULT_SUPABASE_URL = 'https://npcqnrucmwzompwmvztw.supabase.co';
  const DEFAULT_SUPABASE_KEY = 'sb_publishable_c-wIMq0t09mTU4Uhp4lafg_zI-ZjgwL';

  // Purge legacy placeholder credentials if previously cached in localStorage
  if (localStorage.getItem('gawezeny_supabase_url')?.includes('placeholder')) {
    localStorage.removeItem('gawezeny_supabase_url');
  }
  if (localStorage.getItem('gawezeny_supabase_anon_key')?.includes('placeholder')) {
    localStorage.removeItem('gawezeny_supabase_anon_key');
  }

  localStorage.removeItem('gawezeny_demo_mode');
  let currentSupabaseUrl = localStorage.getItem('gawezeny_supabase_url') || (typeof SUPABASE_URL !== 'undefined' && SUPABASE_URL ? SUPABASE_URL : DEFAULT_SUPABASE_URL);
  let currentSupabaseKey = localStorage.getItem('gawezeny_supabase_anon_key') || (typeof SUPABASE_ANON_KEY !== 'undefined' && SUPABASE_ANON_KEY ? SUPABASE_ANON_KEY : DEFAULT_SUPABASE_KEY);
  
  // REAL DATABASE MODE ONLY - Mock / Demo data is strictly disabled
  const isDemoMode = false;
  let supabase = null;

  function initSupabaseClient() {
    try {
      if (window.supabase && currentSupabaseUrl && !currentSupabaseUrl.includes('placeholder')) {
        supabase = window.supabase.createClient(currentSupabaseUrl, currentSupabaseKey);
      } else {
        supabase = null;
      }
    } catch (err) {
      console.warn('Failed to initialize Supabase client:', err);
      supabase = null;
    }
  }
  initSupabaseClient();

  // --------------------------------------------------------------------------
  // Rich Error Formatting Helper (Displays exact actionable errors)
  // --------------------------------------------------------------------------
  function formatDetailedError(err) {
    if (!err) return { title: 'خطأ غير محدد', message: 'حدث خطأ غير معروف', raw: '' };
    if (typeof err === 'string') return { title: 'تنبيه', message: err, raw: err };

    let title = 'حدث خطأ في العملية';
    let message = err.message || 'فشلت الاستجابة من خادم Supabase';
    let rawParts = [];

    const lowerMsg = (message + ' ' + (err.error_description || '')).toLowerCase();

    if (lowerMsg.includes('invalid login credentials')) {
      title = 'بيانات الدخول غير صحيحة';
      message = 'البريد أو كلمة المرور غير مطابقة. تأكد من إدخال الحساب الصحيح المسجل في Supabase.';
    } else if (lowerMsg.includes('email not confirmed') || err.error_code === 'email_not_confirmed') {
      title = 'البريد الإلكتروني غير مؤكد';
      message = `هذا البريد مسجل ولكن لم يتم تأكيده في Supabase.\nقم بتشغيل أمر التأكيد في SQL Editor:\nUPDATE auth.users SET email_confirmed_at = now() WHERE email = '${err.email || 'البريد المستخدم'}';`;
    } else if (lowerMsg.includes('jwt') || lowerMsg.includes('token') || err.code === 'PGRST301') {
      title = 'انتهت صلاحية الجلسة';
      message = 'انتهت صلاحية رمز الدخول، يرجى إعادة تسجيل الدخول.';
    } else if (err.code === '42501' || lowerMsg.includes('permission denied') || lowerMsg.includes('row-level security') || lowerMsg.includes('rls')) {
      title = 'خطأ في صلاحيات قاعدة البيانات (RLS Policy)';
      message = 'تم حظر الاستعلام بواسطة Row Level Security. تأكد من تشغيل سكريبت صلاحيات الأدمن في Supabase SQL Editor.';
    } else if (err.code === '42883' || (lowerMsg.includes('function') && lowerMsg.includes('does not exist'))) {
      title = 'دالة قاعدة البيانات مفقودة';
      message = 'الدالة المطلوبة (RPC) غير موجودة في قاعدة البيانات. تأكد من تشغيل ملف admin_setup.sql في Supabase SQL Editor.';
    }

    if (err.details) rawParts.push(`Details: ${err.details}`);
    if (err.hint) rawParts.push(`Hint: ${err.hint}`);
    if (err.code) rawParts.push(`Code: ${err.code}`);
    if (err.status) rawParts.push(`HTTP: ${err.status}`);
    if (err.message && !rawParts.some(p => p.includes(err.message))) rawParts.push(`Message: ${err.message}`);

    return {
      title,
      message,
      raw: rawParts.join(' | ') || (typeof err === 'object' ? JSON.stringify(err) : String(err)),
    };
  }

  // --------------------------------------------------------------------------
  // Application State
  // --------------------------------------------------------------------------
  let currentPage = 'overview';
  let currentUser = null;
  let adminInfo = null;

  // Cache for profile lookups
  const profileCache = new Map();

  // --------------------------------------------------------------------------
  // Mock Data Store (Used when Demo Mode is active)
  // --------------------------------------------------------------------------
  const mockProfiles = [
    {
      id: 'usr-1',
      full_name: 'أحمد محمود القاضي',
      gender: 'MALE',
      age: 29,
      residence_city: 'القاهرة',
      marital_status: 'SINGLE',
      job_title: 'مهندس برمجيات',
      verification_status: 'VERIFIED',
      subscription_status: 'ACTIVE',
      created_at: new Date(Date.now() - 35 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
    },
    {
      id: 'usr-2',
      full_name: 'سارة عبد الله الشناوي',
      gender: 'FEMALE',
      age: 26,
      residence_city: 'الإسكندرية',
      marital_status: 'SINGLE',
      job_title: 'صيدلانية إكلينيكية',
      verification_status: 'VERIFIED',
      subscription_status: 'ACTIVE',
      created_at: new Date(Date.now() - 28 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&auto=format&fit=crop&q=80',
    },
    {
      id: 'usr-3',
      full_name: 'كريم عبد العزيز سالم',
      gender: 'MALE',
      age: 32,
      residence_city: 'الجيزة',
      marital_status: 'DIVORCED',
      job_title: 'محاسب قانوني',
      verification_status: 'UNVERIFIED',
      subscription_status: 'FREE',
      created_at: new Date(Date.now() - 14 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&auto=format&fit=crop&q=80',
    },
    {
      id: 'usr-4',
      full_name: 'د. مريم إبراهيم حسن',
      gender: 'FEMALE',
      age: 27,
      residence_city: 'المنصورة',
      marital_status: 'SINGLE',
      job_title: 'طبيبة أسنان',
      verification_status: 'PENDING',
      subscription_status: 'ACTIVE',
      created_at: new Date(Date.now() - 10 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
    },
    {
      id: 'usr-5',
      full_name: 'عمر الفاروق النجار',
      gender: 'MALE',
      age: 31,
      residence_city: 'طنطا',
      marital_status: 'SINGLE',
      job_title: 'مدير تسويق رقمي',
      verification_status: 'VERIFIED',
      subscription_status: 'FREE',
      created_at: new Date(Date.now() - 45 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=200&auto=format&fit=crop&q=80',
    },
    {
      id: 'usr-6',
      full_name: 'ياسمين صبري خليل',
      gender: 'FEMALE',
      age: 25,
      residence_city: 'القاهرة',
      marital_status: 'SINGLE',
      job_title: 'معلمة لغة إنجليزية',
      verification_status: 'VERIFIED',
      subscription_status: 'ACTIVE',
      created_at: new Date(Date.now() - 8 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80',
    },
    {
      id: 'usr-7',
      full_name: 'طارق علام الديب',
      gender: 'MALE',
      age: 36,
      residence_city: 'الزقازيق',
      marital_status: 'WIDOWED',
      job_title: 'صاحب أعمال تجارية',
      verification_status: 'UNVERIFIED',
      subscription_status: 'EXPIRED',
      created_at: new Date(Date.now() - 60 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&auto=format&fit=crop&q=80',
    },
    {
      id: 'usr-8',
      full_name: 'نور الدين مصطفى',
      gender: 'MALE',
      age: 28,
      residence_city: 'الإسماعيلية',
      marital_status: 'SINGLE',
      job_title: 'مصمم جرافيك وفنون بصرية',
      verification_status: 'MANUAL_REVIEW',
      subscription_status: 'FREE',
      created_at: new Date(Date.now() - 5 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
    },
    {
      id: 'usr-9',
      full_name: 'فريدة الشاذلي',
      gender: 'FEMALE',
      age: 30,
      residence_city: 'القاهرة',
      marital_status: 'SINGLE',
      job_title: 'محامية استشارات قانونية',
      verification_status: 'VERIFIED',
      subscription_status: 'ACTIVE',
      created_at: new Date(Date.now() - 18 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200&auto=format&fit=crop&q=80',
    },
    {
      id: 'usr-10',
      full_name: 'إسلام حسن بدوي',
      gender: 'MALE',
      age: 33,
      residence_city: 'أسيوط',
      marital_status: 'SINGLE',
      job_title: 'مهندس اتصالات',
      verification_status: 'FAILED',
      subscription_status: 'CANCELLED',
      created_at: new Date(Date.now() - 40 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=200&auto=format&fit=crop&q=80',
    },
    {
      id: 'usr-11',
      full_name: 'سلمى عادل رمزي',
      gender: 'FEMALE',
      age: 24,
      residence_city: 'بورسعيد',
      marital_status: 'SINGLE',
      job_title: 'أخصائية تغذية علاجية',
      verification_status: 'PENDING',
      subscription_status: 'FREE',
      created_at: new Date(Date.now() - 3 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
    },
    {
      id: 'usr-12',
      full_name: 'رامي وجدي سعيد',
      gender: 'MALE',
      age: 27,
      residence_city: 'القاهرة',
      marital_status: 'SINGLE',
      job_title: 'مندوب تسويق ومبيعات',
      verification_status: 'UNVERIFIED',
      subscription_status: 'FREE',
      created_at: new Date(Date.now() - 2 * 86400000).toISOString(),
      photo_url: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
    },
  ];

  const mockReports = [
    {
      id: 'rep-1',
      reporter_id: 'usr-2',
      reported_user_id: 'usr-12',
      reason: 'سلوك مسيء وغير لائق في المحادثة',
      details: 'قام بإرسال عبارات غير لائقة بعد بدء المحادثة وتكرار الاتصال خارج المنصة بطريقة مزعجة.',
      status: 'PENDING',
      created_at: new Date(Date.now() - 2 * 3600000).toISOString(),
    },
    {
      id: 'rep-2',
      reporter_id: 'usr-9',
      reported_user_id: 'usr-7',
      reason: 'استخدام صور مضللة وغير حقيقية',
      details: 'الصور الشخصية الظاهرة بالحساب تعود لشخصية عامة معروفة وليست للشخص الفعلي.',
      status: 'PENDING',
      created_at: new Date(Date.now() - 14 * 3600000).toISOString(),
    },
    {
      id: 'rep-3',
      reporter_id: 'usr-6',
      reported_user_id: 'usr-3',
      reason: 'طلب أموال أو احتيال مالي',
      details: 'تواصل وطلب تحويل رصيد محفظة إلكترونية بزعم تعرضه لحالة طارئة.',
      status: 'PENDING',
      created_at: new Date(Date.now() - 28 * 3600000).toISOString(),
    },
    {
      id: 'rep-4',
      reporter_id: 'usr-4',
      reported_user_id: 'usr-10',
      reason: 'شروط مسيئة في النبذة الشخصية',
      details: 'كتابة عبارات استهزاء ومخالفة لآداب التعارف الشرعي في نبذة الحساب.',
      status: 'RESOLVED_BLOCKED',
      created_at: new Date(Date.now() - 96 * 3600000).toISOString(),
    },
  ];

  const mockVerifications = [
    {
      id: 'ver-1',
      user_id: 'usr-4',
      status: 'PENDING',
      id_card_image_url: 'https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?w=600&auto=format&fit=crop&q=80',
      selfie_image_url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&auto=format&fit=crop&q=80',
      face_match_score: 95,
      created_at: new Date(Date.now() - 3 * 3600000).toISOString(),
    },
    {
      id: 'ver-2',
      user_id: 'usr-8',
      status: 'MANUAL_REVIEW',
      id_card_image_url: 'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=600&auto=format&fit=crop&q=80',
      selfie_image_url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&auto=format&fit=crop&q=80',
      face_match_score: 72,
      created_at: new Date(Date.now() - 18 * 3600000).toISOString(),
    },
    {
      id: 'ver-3',
      user_id: 'usr-11',
      status: 'PENDING',
      id_card_image_url: 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=600&auto=format&fit=crop&q=80',
      selfie_image_url: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=600&auto=format&fit=crop&q=80',
      face_match_score: 91,
      created_at: new Date(Date.now() - 36 * 3600000).toISOString(),
    },
  ];

  const mockVouchers = [
    { code: 'GWZ-A9842F1C', tier: 'MONTHLY_200', duration_days: 30, amount_egp: 200, is_used: false, used_by: null, created_at: new Date(Date.now() - 2 * 86400000).toISOString() },
    { code: 'GWZ-B4D710FF', tier: 'QUARTERLY_500', duration_days: 90, amount_egp: 500, is_used: false, used_by: null, created_at: new Date(Date.now() - 3 * 86400000).toISOString() },
    { code: 'GWZ-C390E7A2', tier: 'SEMI_ANNUAL_900', duration_days: 180, amount_egp: 900, is_used: false, used_by: null, created_at: new Date(Date.now() - 4 * 86400000).toISOString() },
    { code: 'GWZ-D82109BC', tier: 'ANNUAL_1500', duration_days: 365, amount_egp: 1500, is_used: false, used_by: null, created_at: new Date(Date.now() - 5 * 86400000).toISOString() },
    { code: 'GWZ-FB664321', tier: 'BUNDLE_FB_1000', duration_days: 30, amount_egp: 1000, is_used: false, used_by: null, created_at: new Date(Date.now() - 6 * 86400000).toISOString() },
    { code: 'GWZ-M109341A', tier: 'MONTHLY_200', duration_days: 30, amount_egp: 200, is_used: true, used_by: 'usr-1', used_at: new Date(Date.now() - 10 * 86400000).toISOString(), created_at: new Date(Date.now() - 15 * 86400000).toISOString() },
    { code: 'GWZ-S3301988', tier: 'SEMI_ANNUAL_900', duration_days: 180, amount_egp: 900, is_used: true, used_by: 'usr-2', used_at: new Date(Date.now() - 20 * 86400000).toISOString(), created_at: new Date(Date.now() - 25 * 86400000).toISOString() },
    { code: 'GWZ-Q849202E', tier: 'QUARTERLY_500', duration_days: 90, amount_egp: 500, is_used: true, used_by: 'usr-4', used_at: new Date(Date.now() - 5 * 86400000).toISOString(), created_at: new Date(Date.now() - 12 * 86400000).toISOString() },
    { code: 'GWZ-A77312CD', tier: 'ANNUAL_1500', duration_days: 365, amount_egp: 1500, is_used: true, used_by: 'usr-6', used_at: new Date(Date.now() - 7 * 86400000).toISOString(), created_at: new Date(Date.now() - 8 * 86400000).toISOString() },
    { code: 'GWZ-M550183F', tier: 'MONTHLY_200', duration_days: 30, amount_egp: 200, is_used: true, used_by: 'usr-9', used_at: new Date(Date.now() - 12 * 86400000).toISOString(), created_at: new Date(Date.now() - 14 * 86400000).toISOString() },
  ];

  // --------------------------------------------------------------------------
  // DOM Helpers
  // --------------------------------------------------------------------------
  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => document.querySelectorAll(sel);

  function show(el) { if (el) el.style.display = ''; }
  function hide(el) { if (el) el.style.display = 'none'; }

  // --------------------------------------------------------------------------
  // Toast Notification System
  // --------------------------------------------------------------------------
  function showToast(message, type = 'info') {
    const container = $('#toast-container');
    const icons = {
      success: 'check_circle',
      error: 'error',
      warning: 'warning',
      info: 'info',
    };

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `
      <span class="material-icons-round">${icons[type] || 'info'}</span>
      <span>${message}</span>
    `;
    container.appendChild(toast);

    setTimeout(() => {
      toast.classList.add('toast-exit');
      setTimeout(() => toast.remove(), 300);
    }, 4000);
  }

  // --------------------------------------------------------------------------
  // Confirmation Modal
  // --------------------------------------------------------------------------
  function showConfirm(title, message, btnClass = 'btn-danger') {
    return new Promise((resolve) => {
      $('#confirm-title').textContent = title;
      $('#confirm-message').textContent = message;
      const okBtn = $('#confirm-ok');
      okBtn.className = `btn ${btnClass}`;
      show($('#confirm-modal'));

      const handleOk = () => {
        hide($('#confirm-modal'));
        cleanup();
        resolve(true);
      };
      const handleCancel = () => {
        hide($('#confirm-modal'));
        cleanup();
        resolve(false);
      };
      const cleanup = () => {
        okBtn.removeEventListener('click', handleOk);
        $('#confirm-cancel').removeEventListener('click', handleCancel);
      };

      okBtn.addEventListener('click', handleOk);
      $('#confirm-cancel').addEventListener('click', handleCancel);
    });
  }

  // --------------------------------------------------------------------------
  // Date Formatting
  // --------------------------------------------------------------------------
  function formatDate(dateStr) {
    if (!dateStr) return '—';
    const d = new Date(dateStr);
    return d.toLocaleDateString('ar-EG', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }

  function formatDateTime(dateStr) {
    if (!dateStr) return '—';
    const d = new Date(dateStr);
    return d.toLocaleDateString('ar-EG', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  // --------------------------------------------------------------------------
  // Profile Lookup Helper
  // --------------------------------------------------------------------------
  async function getProfile(userId) {
    if (!userId) return null;
    if (profileCache.has(userId)) return profileCache.get(userId);

    if (isDemoMode || !supabase) {
      const p = mockProfiles.find((u) => u.id === userId);
      if (p) profileCache.set(userId, p);
      return p || null;
    }

    try {
      const { data } = await supabase
        .from('profiles')
        .select('id, full_name, gender, age, residence_city')
        .eq('id', userId)
        .single();

      if (data) profileCache.set(userId, data);
      return data;
    } catch {
      return null;
    }
  }

  async function getProfilePhoto(userId) {
    if (!userId) return null;

    if (isDemoMode || !supabase) {
      const p = mockProfiles.find((u) => u.id === userId);
      return p?.photo_url || null;
    }

    try {
      const { data } = await supabase
        .from('profile_photos')
        .select('photo_url')
        .eq('user_id', userId)
        .eq('is_primary', true)
        .single();
      return data?.photo_url || null;
    } catch {
      return null;
    }
  }

  function renderUserMini(profile, photoUrl) {
    const name = profile?.full_name || 'مستخدم محذوف';
    const avatar = photoUrl
      ? `<img class="user-mini-avatar" src="${photoUrl}" alt="${name}">`
      : `<div class="user-mini-avatar-placeholder"><span class="material-icons-round">person</span></div>`;
    return `<div class="user-mini">${avatar}<span class="user-mini-name">${name}</span></div>`;
  }

  // --------------------------------------------------------------------------
  // Badge Helpers
  // --------------------------------------------------------------------------
  function reportStatusBadge(status) {
    const cls = {
      PENDING: 'badge-pending',
      RESOLVED_BLOCKED: 'badge-danger',
      RESOLVED_DELETED: 'badge-danger',
      DISMISSED: 'badge-muted',
    };
    return `<span class="badge ${cls[status] || 'badge-info'}">${REPORT_STATUS_LABELS[status] || status}</span>`;
  }

  function verificationStatusBadge(status) {
    const cls = {
      UNVERIFIED: 'badge-muted',
      PENDING: 'badge-pending',
      VERIFIED: 'badge-success',
      FAILED: 'badge-danger',
      MANUAL_REVIEW: 'badge-info',
    };
    return `<span class="badge ${cls[status] || 'badge-info'}">${VERIFICATION_STATUS_LABELS[status] || status}</span>`;
  }

  function subscriptionStatusBadge(status) {
    const cls = {
      FREE: 'badge-muted',
      PENDING_PAYMENT: 'badge-pending',
      ACTIVE: 'badge-success',
      EXPIRED: 'badge-danger',
      CANCELLED: 'badge-danger',
    };
    return `<span class="badge ${cls[status] || 'badge-info'}">${SUBSCRIPTION_STATUS_LABELS[status] || status}</span>`;
  }

  // --------------------------------------------------------------------------
  // Mode Badge Update
  // --------------------------------------------------------------------------
  function updateModeBadge() {
    const badge = $('#mode-badge');
    const badgeText = $('#mode-badge-text');
    if (!badge || !badgeText) return;

    if (isDemoMode || !supabase) {
      badge.className = 'mode-badge mode-badge-demo';
      badge.title = 'وضع المعاينة التجريبية - انقر للاتصال بقاعدة بيانات حقيقية';
      badge.innerHTML = `<span class="mode-dot mode-dot-demo"></span><span id="mode-badge-text">وضع المعاينة التجريبية (Demo)</span>`;
    } else {
      badge.className = 'mode-badge mode-badge-live';
      badge.title = 'متصل بـ Supabase مباشرة - انقر لتعديل الإعدادات';
      badge.innerHTML = `<span class="mode-dot mode-dot-live"></span><span id="mode-badge-text">متصل بقاعدة البيانات (Live)</span>`;
    }
  }

  // ==========================================================================
  // AUTHENTICATION (Live Database Only)
  // ==========================================================================
  async function handleLogin(e) {
    e.preventDefault();
    const email = $('#login-email').value.trim();
    const password = $('#login-password').value;
    const errorEl = $('#login-error');
    const btnText = $('#login-btn .btn-text');
    const btnLoader = $('#login-btn .btn-loader');

    hide(errorEl);

    if (!supabase) {
      errorEl.innerHTML = `
        <div class="login-error-title"><span class="material-icons-round">error</span> خطأ في التهيئة</div>
        <div>لم يتم تهيئة عميل Supabase. تأكد من صحة المفاتيح في إعدادات الاتصال.</div>
      `;
      show(errorEl);
      return;
    }

    btnText.textContent = 'جاري الاتصال والتحقق...';
    show(btnLoader);
    $('#login-btn').disabled = true;

    try {
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({ email, password });
      if (authError) {
        authError.email = email;
        throw authError;
      }

      if (!authData?.user) {
        throw new Error('لم يتم استلام بيانات المستخدم من Supabase');
      }

      // Verify admin status in admin_users table
      const { data: adminData, error: adminError } = await supabase
        .from('admin_users')
        .select('*')
        .eq('id', authData.user.id)
        .maybeSingle();

      if (adminError) {
        console.error('admin_users lookup failed:', adminError);
        throw new Error(`تعذر قراءة جدول المشرفين (admin_users): ${adminError.message}`);
      }

      if (!adminData) {
        await supabase.auth.signOut();
        const err = new Error(
          `تم تسجيل الدخول بنجاح بحساب (${email})، ولكن هذا الحساب ليس مسجلاً في جدول المشرفين (admin_users).\n` +
          `قم بإضافته عبر تنفيذ هذا الاستعلام في Supabase SQL Editor:\n` +
          `INSERT INTO admin_users (id, email, display_name, role) VALUES ('${authData.user.id}', '${email}', 'مدير النظام', 'admin');`
        );
        err.user_id = authData.user.id;
        throw err;
      }

      currentUser = authData.user;
      adminInfo = adminData;
      showDashboard();
      showToast(`مرحباً بك ${adminInfo.display_name || 'مدير المنصة'} (متصل بقاعدة البيانات الحية)`, 'success');
    } catch (err) {
      console.error('Login error:', err);
      const parsed = formatDetailedError(err);
      errorEl.innerHTML = `
        <div class="login-error-title">
          <span class="material-icons-round" style="font-size:18px;">error_outline</span>
          <span>${parsed.title}</span>
        </div>
        <div>${parsed.message.replace(/\n/g, '<br>')}</div>
        ${parsed.raw ? `<div class="login-error-code">${parsed.raw}</div>` : ''}
      `;
      show(errorEl);
    } finally {
      btnText.textContent = 'تسجيل الدخول (بيانات حية)';
      hide(btnLoader);
      $('#login-btn').disabled = false;
    }
  }

  async function handleLogout() {
    const confirmed = await showConfirm('تسجيل الخروج', 'هل تريد تسجيل الخروج من لوحة الإدارة؟', 'btn-outline');
    if (!confirmed) return;

    if (supabase) {
      try { await supabase.auth.signOut(); } catch (e) { /* ignore */ }
    }

    currentUser = null;
    adminInfo = null;
    profileCache.clear();
    hide($('#dashboard'));
    show($('#login-screen'));
  }

  async function checkSession() {
    if (!supabase) return;

    try {
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      if (sessionError || !session) return;

      const { data: adminData, error: adminError } = await supabase
        .from('admin_users')
        .select('*')
        .eq('id', session.user.id)
        .maybeSingle();

      if (adminData) {
        currentUser = session.user;
        adminInfo = adminData;
        showDashboard();
      }
    } catch (err) {
      console.warn('Session check failed:', err);
    }
  }

  function showDashboard() {
    hide($('#login-screen'));
    show($('#dashboard'));
    $('#admin-name').textContent = adminInfo?.display_name || 'مدير النظام';
    updateModeBadge();
    navigateTo('overview');
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================
  function navigateTo(page) {
    currentPage = page;

    // Update nav items
    $$('.nav-item').forEach((item) => {
      item.classList.toggle('active', item.dataset.page === page);
    });

    // Show page
    $$('.page').forEach((p) => p.classList.remove('active'));
    const pageEl = $(`#page-${page}`);
    if (pageEl) pageEl.classList.add('active');

    // Update title
    const titles = {
      overview: 'نظرة عامة',
      reports: 'إدارة البلاغات',
      vouchers: 'إدارة القسائم',
      verifications: 'مراجعة التحقق',
      users: 'إدارة المستخدمين',
    };
    $('#page-title').textContent = titles[page] || '';

    // Close mobile sidebar
    $('#sidebar').classList.remove('open');
    const overlay = document.querySelector('.sidebar-overlay');
    if (overlay) overlay.classList.remove('show');

    // Load page data
    loadPageData(page);
  }

  async function loadPageData(page) {
    switch (page) {
      case 'overview': await loadOverview(); break;
      case 'reports': await loadReports(); break;
      case 'vouchers': await loadVouchers(); break;
      case 'verifications': await loadVerifications(); break;
      case 'users': await loadUsers(); break;
    }
  }

  // ==========================================================================
  // OVERVIEW PAGE
  // ==========================================================================
  async function loadOverview() {
    try {
      let stats = {};

      try {
        const { data, error } = await supabase.rpc('admin_get_dashboard_stats');
        if (error) throw error;
        stats = data || {};
      } catch (rpcErr) {
        console.warn('admin_get_dashboard_stats RPC not found, falling back to direct table queries:', rpcErr);
        const [
          { count: totalUsers },
          { count: verifiedUsers },
          { count: pendingVerif },
          { count: pendingReports },
          { count: activeSubs },
          { count: totalVouchers },
          { count: usedVouchers }
        ] = await Promise.all([
          supabase.from('profiles').select('id', { count: 'exact', head: true }),
          supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('verification_status', 'VERIFIED'),
          supabase.from('identity_verifications').select('id', { count: 'exact', head: true }).in('status', ['PENDING', 'MANUAL_REVIEW']),
          supabase.from('user_reports').select('id', { count: 'exact', head: true }).eq('status', 'PENDING'),
          supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('subscription_status', 'ACTIVE'),
          supabase.from('voucher_codes').select('code', { count: 'exact', head: true }),
          supabase.from('voucher_codes').select('code', { count: 'exact', head: true }).eq('is_used', true),
        ]);

        stats = {
          total_users: totalUsers || 0,
          verified_users: verifiedUsers || 0,
          pending_verifications: pendingVerif || 0,
          pending_reports: pendingReports || 0,
          active_subscribers: activeSubs || 0,
          total_vouchers: totalVouchers || 0,
          used_vouchers: usedVouchers || 0,
          unused_vouchers: Math.max(0, (totalVouchers || 0) - (usedVouchers || 0)),
        };
      }

      $('#stat-total-users').textContent = stats.total_users ?? 0;
      $('#stat-pending-reports').textContent = stats.pending_reports ?? 0;
      $('#stat-verified-users').textContent = stats.verified_users ?? 0;
      $('#stat-active-subs').textContent = stats.active_subscribers ?? 0;
      $('#stat-male-users').textContent = stats.male_users ?? 0;
      $('#stat-female-users').textContent = stats.female_users ?? 0;
      $('#stat-total-matches').textContent = stats.total_matches ?? 0;
      $('#stat-total-vouchers').textContent = stats.total_vouchers ?? 0;
      $('#stat-used-vouchers').textContent = stats.used_vouchers ?? 0;
      $('#stat-unused-vouchers').textContent = stats.unused_vouchers ?? 0;
      $('#stat-users-today').textContent = stats.users_today ?? 0;
      $('#stat-reports-today').textContent = stats.reports_today ?? 0;
      $('#stat-pending-verif').textContent = stats.pending_verifications ?? 0;

      // Update badges in sidebar
      const reportsBadge = $('#reports-badge');
      const verifBadge = $('#verifications-badge');

      if (stats.pending_reports > 0) {
        reportsBadge.textContent = stats.pending_reports;
        show(reportsBadge);
      } else {
        hide(reportsBadge);
      }

      if (stats.pending_verifications > 0) {
        verifBadge.textContent = stats.pending_verifications;
        show(verifBadge);
      } else {
        hide(verifBadge);
      }
    } catch (err) {
      showToast('فشل تحميل الإحصائيات: ' + err.message, 'error');
    }
  }

  // ==========================================================================
  // REPORTS PAGE
  // ==========================================================================
  async function loadReports() {
    const tbody = $('#reports-tbody');
    tbody.innerHTML = '<tr class="empty-row"><td colspan="7">جاري التحميل...</td></tr>';

    try {
      if (!supabase) throw new Error('عميل Supabase غير متصل');

      const statusFilter = $('#reports-status-filter').value;
      let query = supabase
        .from('user_reports')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100);

      if (statusFilter !== 'ALL') {
        query = query.eq('status', statusFilter);
      }

      const { data, error } = await query;
      if (error) throw error;
      const reports = data || [];

      if (!reports || reports.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="7">لا توجد بلاغات مسجلة في قاعدة البيانات</td></tr>';
        return;
      }

      // Fetch all related profiles
      const userIds = new Set();
      reports.forEach((r) => { userIds.add(r.reporter_id); userIds.add(r.reported_user_id); });

      const profilePromises = [...userIds].map(async (uid) => {
        const profile = await getProfile(uid);
        const photo = await getProfilePhoto(uid);
        return { uid, profile, photo };
      });

      const profileResults = await Promise.all(profilePromises);
      const profileMap = new Map();
      const photoMap = new Map();
      profileResults.forEach(({ uid, profile, photo }) => {
        profileMap.set(uid, profile);
        photoMap.set(uid, photo);
      });

      let html = '';
      reports.forEach((report) => {
        const reporter = profileMap.get(report.reporter_id);
        const reported = profileMap.get(report.reported_user_id);
        const reporterPhoto = photoMap.get(report.reporter_id);
        const reportedPhoto = photoMap.get(report.reported_user_id);
        const isPending = report.status === 'PENDING';

        html += `
          <tr id="report-row-${report.id}">
            <td>${renderUserMini(reporter, reporterPhoto)}</td>
            <td>${renderUserMini(reported, reportedPhoto)}</td>
            <td><strong>${report.reason || '—'}</strong></td>
            <td><span class="truncate" style="max-width:280px; display:inline-block;">${report.details || '—'}</span></td>
            <td>${formatDateTime(report.created_at)}</td>
            <td>${reportStatusBadge(report.status)}</td>
            <td>
              ${isPending ? `
                <div class="action-btns">
                  <button class="action-btn action-btn-block" onclick="adminActions.blockUser('${report.reported_user_id}', '${report.id}')" title="حظر الحساب">
                    <span class="material-icons-round">block</span> حظر
                  </button>
                  <button class="action-btn action-btn-delete" onclick="adminActions.deleteAccount('${report.reported_user_id}', '${report.id}')" title="حذف الحساب">
                    <span class="material-icons-round">delete</span> حذف
                  </button>
                  <button class="action-btn action-btn-dismiss" onclick="adminActions.dismissReport('${report.id}')" title="رفض البلاغ">
                    <span class="material-icons-round">close</span> رفض
                  </button>
                </div>
              ` : '<span class="badge badge-muted">تم الإجراء</span>'}
            </td>
          </tr>
        `;
      });

      tbody.innerHTML = html;
    } catch (err) {
      tbody.innerHTML = `<tr class="empty-row"><td colspan="7">خطأ: ${err.message}</td></tr>`;
      showToast('فشل تحميل البلاغات: ' + err.message, 'error');
    }
  }

  // ==========================================================================
  // VOUCHERS PAGE
  // ==========================================================================
  async function loadVouchers() {
    const tbody = $('#vouchers-tbody');
    tbody.innerHTML = '<tr class="empty-row"><td colspan="7">جاري التحميل...</td></tr>';

    try {
      if (!supabase) throw new Error('عميل Supabase غير متصل');

      const statusFilter = $('#vouchers-status-filter').value;
      let query = supabase
        .from('voucher_codes')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(200);

      if (statusFilter === 'AVAILABLE') query = query.eq('is_used', false);
      else if (statusFilter === 'USED') query = query.eq('is_used', true);

      const { data, error } = await query;
      if (error) throw error;
      const vouchers = data || [];

      if (!vouchers || vouchers.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="7">لا توجد قسائم مسجلة في قاعدة البيانات</td></tr>';
        return;
      }

      // Fetch user profiles for used vouchers
      const usedByIds = vouchers.filter((v) => v.used_by).map((v) => v.used_by);
      const uniqueUserIds = [...new Set(usedByIds)];
      const userProfiles = new Map();
      await Promise.all(uniqueUserIds.map(async (uid) => {
        const p = await getProfile(uid);
        if (p) userProfiles.set(uid, p);
      }));

      let html = '';
      vouchers.forEach((v) => {
        const usedBy = v.used_by ? (userProfiles.get(v.used_by)?.full_name || 'مستخدم مسجل') : '—';
        const statusBadge = v.is_used
          ? '<span class="badge badge-success">مستخدمة</span>'
          : '<span class="badge badge-pending">متاحة</span>';

        html += `
          <tr>
            <td class="code-cell" style="user-select:all; cursor:pointer;" onclick="navigator.clipboard.writeText('${v.code}'); showToast('تم نسخ الكود: ${v.code}', 'info')">${v.code}</td>
            <td><strong>${TIER_LABELS[v.tier] || v.tier}</strong></td>
            <td>${v.duration_days} يوم</td>
            <td><strong>${v.amount_egp} ج.م</strong></td>
            <td>${statusBadge}</td>
            <td>${usedBy}${v.used_at ? '<br><small style="color:var(--text-muted)">' + formatDate(v.used_at) + '</small>' : ''}</td>
            <td>${formatDate(v.created_at)}</td>
          </tr>
        `;
      });

      tbody.innerHTML = html;
    } catch (err) {
      tbody.innerHTML = `<tr class="empty-row"><td colspan="7">خطأ: ${err.message}</td></tr>`;
      showToast('فشل تحميل القسائم', 'error');
    }
  }

  async function generateVouchers(e) {
    e.preventDefault();

    const tier = $('#voucher-tier').value;
    const count = parseInt($('#voucher-count').value, 10);
    const durationDays = parseInt($('#voucher-duration').value, 10);
    const amountEgp = parseFloat($('#voucher-amount').value);
    const prefix = $('#voucher-prefix').value.trim() || 'GWZ';
    const expiresAt = $('#voucher-expires').value || null;
    const notes = $('#voucher-notes').value.trim() || null;

    try {
      if (!supabase) throw new Error('عميل Supabase غير متصل');

      const { data, error } = await supabase.rpc('admin_generate_vouchers', {
        p_tier: tier,
        p_count: count,
        p_duration_days: durationDays,
        p_amount_egp: amountEgp,
        p_prefix: prefix,
        p_expires_at: expiresAt,
        p_notes: notes,
      });

      if (error) throw error;
      if (!data?.success) throw new Error(data?.error || 'فشل إنشاء القسائم');
      const generatedCodes = data.codes || [];

      // Show generated codes result in modal
      hide($('#generate-vouchers-form'));
      const resultDiv = $('#generated-codes-result');
      show(resultDiv);
      $('#generated-codes-message').textContent = `تم توليد ${generatedCodes.length} كود اشتراك بنجاح`;

      const codesList = $('#generated-codes-list');
      codesList.innerHTML = generatedCodes.map((c) => `<span class="code-chip">${c}</span>`).join('');

      showToast(`تم إنشاء ${generatedCodes.length} كود بنجاح`, 'success');
      loadVouchers();
      loadOverview();
    } catch (err) {
      showToast('فشل إنشاء القسائم: ' + err.message, 'error');
    }
  }

  // ==========================================================================
  // VERIFICATIONS PAGE (Live Database Only)
  // ==========================================================================
  async function loadVerifications() {
    const grid = $('#verifications-grid');
    grid.innerHTML = '<div class="empty-state"><span class="material-icons-round">hourglass_empty</span><p>جاري تحميل طلبات التحقق من قاعدة البيانات الحية...</p></div>';

    try {
      if (!supabase) throw new Error('عميل Supabase غير متصل. يرجى التحقق من الإعدادات.');

      const statusFilter = $('#verifications-status-filter').value;
      let query = supabase
        .from('identity_verifications')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(50);

      if (statusFilter === 'PENDING') {
        query = query.in('status', ['PENDING', 'MANUAL_REVIEW']);
      } else if (statusFilter === 'APPROVED' || statusFilter === 'VERIFIED') {
        query = query.in('status', ['VERIFIED', 'APPROVED']);
      } else if (statusFilter === 'REJECTED' || statusFilter === 'FAILED') {
        query = query.in('status', ['FAILED', 'REJECTED']);
      }

      const { data, error } = await query;
      if (error) throw error;
      const verifications = data || [];

      if (!verifications || verifications.length === 0) {
        grid.innerHTML = `
          <div class="empty-state">
            <span class="material-icons-round" style="color:var(--text-muted); font-size:48px;">inbox</span>
            <p style="font-weight:700; margin-top:8px;">لا توجد طلبات تحقق تطابق التصفية في قاعدة البيانات الحية</p>
            <span style="font-size:12px; color:var(--text-muted);">عندما يقوم أي مستخدم برفع بطاقة الهوية والصورة، سيظهر طلبه هنا فوراً.</span>
          </div>
        `;
        return;
      }

      // Fetch profiles
      const profilePromises = verifications.map(async (v) => {
        const profile = await getProfile(v.user_id);
        return { ...v, profile };
      });
      const enrichedVerifications = await Promise.all(profilePromises);

      let html = '';
      enrichedVerifications.forEach((v, idx) => {
        const isPending = ['PENDING', 'MANUAL_REVIEW'].includes(v.status);
        const idCardUrl = v.id_card_image_url || '';
        const selfieUrl = v.selfie_image_url || '';

        html += `
          <div class="verification-card" id="verif-card-${v.id}" style="animation-delay: ${idx * 0.05}s">
            <div class="verification-card-header">
              <div class="verification-user-info">
                <span class="user-name"><strong>${v.profile?.full_name || 'مستخدم (معرف: ' + v.user_id.substring(0, 8) + '...)'}</strong></span>
                <span class="user-date">${formatDateTime(v.created_at)}</span>
              </div>
              ${verificationStatusBadge(v.status)}
            </div>
            <div class="verification-images">
              <div class="image-panel">
                ${idCardUrl
                  ? `<img src="${idCardUrl}" alt="بطاقة الهوية الوطنية" loading="lazy" onclick="window.open('${idCardUrl}', '_blank')" style="cursor:zoom-in;"><span class="image-label">بطاقة الرقم القومي (انقر للتكبير)</span>`
                  : '<div class="no-image"><span class="material-icons-round" style="font-size:32px;display:block;margin-bottom:4px">badge</span>لا توجد صورة</div>'
                }
              </div>
              <div class="image-panel">
                ${selfieUrl
                  ? `<img src="${selfieUrl}" alt="الصورة الشخصية" loading="lazy" onclick="window.open('${selfieUrl}', '_blank')" style="cursor:zoom-in;"><span class="image-label">صورة السيلفي المباشرة (انقر للتكبير)</span>`
                  : '<div class="no-image"><span class="material-icons-round" style="font-size:32px;display:block;margin-bottom:4px">face</span>لا توجد صورة</div>'
                }
              </div>
            </div>
            <div class="verification-card-footer">
              ${isPending ? `
                <button class="action-btn action-btn-approve" onclick="adminActions.approveVerification('${v.id}')">
                  <span class="material-icons-round">check</span> قبول وتوثيق
                </button>
                <button class="action-btn action-btn-reject" onclick="adminActions.rejectVerification('${v.id}')">
                  <span class="material-icons-round">close</span> رفض الطلب
                </button>
              ` : `<span class="badge ${v.status === 'VERIFIED' ? 'badge-success' : 'badge-danger'}">تم الحسم: ${VERIFICATION_STATUS_LABELS[v.status] || v.status}</span>`}
              ${v.rejection_reason ? `<div class="rejection-reason-notice" style="color:#dc3545; font-size:12px; margin-top:8px; width:100%;"><span class="material-icons-round" style="font-size:14px; vertical-align:middle;">error_outline</span> سبب الرفض: <strong>${v.rejection_reason}</strong></div>` : ''}
            </div>
          </div>
        `;
      });

      grid.innerHTML = html;
    } catch (err) {
      console.error('loadVerifications error:', err);
      const parsed = formatDetailedError(err);
      grid.innerHTML = `
        <div class="empty-state" style="border:1px solid #f5c2c7; background:#fff2f2; border-radius:12px; padding:24px; text-align:right;">
          <div style="display:flex; align-items:center; gap:8px; color:#842029; font-weight:700; font-size:16px;">
            <span class="material-icons-round" style="color:#dc3545; font-size:28px;">error</span>
            <span>${parsed.title}</span>
          </div>
          <p style="color:#b02a37; margin:10px 0; font-size:14px; line-height:1.6;">${parsed.message}</p>
          ${parsed.raw ? `<div class="login-error-code">${parsed.raw}</div>` : ''}
        </div>
      `;
      showToast(`فشل جلب طلبات التحقق: ${parsed.message}`, 'error');
    }
  }

  // ==========================================================================
  // USERS PAGE
  // ==========================================================================
  let usersDebounceTimer = null;

  async function loadUsers() {
    const tbody = $('#users-tbody');
    tbody.innerHTML = '<tr class="empty-row"><td colspan="9">جاري التحميل...</td></tr>';

    try {
      if (!supabase) throw new Error('عميل Supabase غير متصل');

      const searchTerm = $('#users-search').value.trim().toLowerCase();
      const genderFilter = $('#users-gender-filter').value;
      const verificationFilter = $('#users-verification-filter').value;
      const subscriptionFilter = $('#users-subscription-filter').value;

      let query = supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100);

      if (searchTerm) {
        query = query.or(`full_name.ilike.%${searchTerm}%,residence_city.ilike.%${searchTerm}%`);
      }
      if (genderFilter !== 'ALL') query = query.eq('gender', genderFilter);
      if (verificationFilter !== 'ALL') query = query.eq('verification_status', verificationFilter);
      if (subscriptionFilter !== 'ALL') query = query.eq('subscription_status', subscriptionFilter);

      const { data, error } = await query;
      if (error) throw error;
      const users = data || [];

      if (!users || users.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="9">لا يوجد مستخدمون مطابقون لمعايير البحث في قاعدة البيانات</td></tr>';
        return;
      }

      let html = '';
      users.forEach((u) => {
        html += `
          <tr id="user-row-${u.id}">
            <td><strong>${u.full_name}</strong></td>
            <td>${GENDER_LABELS[u.gender] || u.gender}</td>
            <td>${u.age ?? '—'}</td>
            <td>${u.residence_city || '—'}</td>
            <td>${MARITAL_STATUS_LABELS[u.marital_status] || u.marital_status}</td>
            <td>${verificationStatusBadge(u.verification_status)}</td>
            <td>${subscriptionStatusBadge(u.subscription_status)}</td>
            <td>${formatDate(u.created_at)}</td>
            <td>
              <div class="action-btns">
                <button class="action-btn action-btn-block" onclick="adminActions.blockUser('${u.id}')" title="حظر">
                  <span class="material-icons-round">block</span>
                </button>
                <button class="action-btn action-btn-delete" onclick="adminActions.deleteAccount('${u.id}')" title="حذف">
                  <span class="material-icons-round">delete</span>
                </button>
              </div>
            </td>
          </tr>
        `;
      });

      tbody.innerHTML = html;
    } catch (err) {
      tbody.innerHTML = `<tr class="empty-row"><td colspan="9">خطأ: ${err.message}</td></tr>`;
      showToast('فشل تحميل المستخدمين: ' + err.message, 'error');
    }
  }

  // ==========================================================================
  // ADMIN ACTIONS (Exposed globally for onclick handlers)
  // ==========================================================================
  window.adminActions = {
    async blockUser(userId, reportId = null) {
      const confirmed = await showConfirm(
        'حظر المستخدم',
        'هل أنت متأكد من حظر هذا المستخدم؟ سيتم إلغاء اشتراكه ومنعه من استخدام التطبيق.'
      );
      if (!confirmed) return;

      try {
        if (!supabase) throw new Error('عميل Supabase غير متصل');

        const { data, error } = await supabase.rpc('admin_block_user', {
          p_target_user_id: userId,
          p_report_id: reportId,
          p_reason: 'تم الحظر بواسطة الإدارة',
        });
        if (error) throw error;
        if (data && data.success === false) throw new Error(data.error || 'فشلت عملية الحظر');

        showToast('تم حظر المستخدم بنجاح في قاعدة البيانات', 'success');
        profileCache.delete(userId);
        loadPageData(currentPage);
        loadOverview();
      } catch (err) {
        console.error('blockUser error:', err);
        const parsed = formatDetailedError(err);
        showToast('فشل حظر المستخدم: ' + parsed.message, 'error');
        alert(`❌ تعذر حظر المستخدم:\n\n${parsed.title}\n${parsed.message}\n\n${parsed.raw ? `[تفاصيل الخطأ: ${parsed.raw}]` : ''}`);
      }
    },

    async deleteAccount(userId, reportId = null) {
      const confirmed = await showConfirm(
        'حذف الحساب نهائياً',
        'هل أنت متأكد من حذف هذا الحساب؟ سيتم محو البيانات والصور نهائياً. لا يمكن التراجع عن هذا الإجراء!'
      );
      if (!confirmed) return;

      try {
        if (!supabase) throw new Error('عميل Supabase غير متصل');

        const { data, error } = await supabase.rpc('admin_delete_account', {
          p_target_user_id: userId,
          p_report_id: reportId,
        });
        if (error) throw error;
        if (data && data.success === false) throw new Error(data.error || 'فشلت عملية حذف الحساب');

        showToast('تم حذف الحساب بنجاح من قاعدة البيانات', 'success');
        profileCache.delete(userId);
        loadPageData(currentPage);
        loadOverview();
      } catch (err) {
        console.error('deleteAccount error:', err);
        const parsed = formatDetailedError(err);
        showToast('فشل حذف الحساب: ' + parsed.message, 'error');
        alert(`❌ تعذر حذف الحساب:\n\n${parsed.title}\n${parsed.message}\n\n${parsed.raw ? `[تفاصيل الخطأ: ${parsed.raw}]` : ''}`);
      }
    },

    async dismissReport(reportId) {
      const confirmed = await showConfirm(
        'رفض البلاغ',
        'هل تريد رفض هذا البلاغ وإغلاقه بدون اتخاذ إجراء بحق المستخدم؟',
        'btn-outline'
      );
      if (!confirmed) return;

      try {
        if (!supabase) throw new Error('عميل Supabase غير متصل');

        const { data, error } = await supabase.rpc('admin_dismiss_report', {
          p_report_id: reportId,
        });
        if (error) throw error;
        if (data && data.success === false) throw new Error(data.error || 'فشلت عملية رفض البلاغ');

        showToast('تم رفض البلاغ وإغلاقه', 'info');
        loadReports();
        loadOverview();
      } catch (err) {
        console.error('dismissReport error:', err);
        const parsed = formatDetailedError(err);
        showToast('فشل رفض البلاغ: ' + parsed.message, 'error');
        alert(`❌ تعذر رفض البلاغ:\n\n${parsed.title}\n${parsed.message}\n\n${parsed.raw ? `[تفاصيل الخطأ: ${parsed.raw}]` : ''}`);
      }
    },

    async approveVerification(verificationId) {
      const confirmed = await showConfirm(
        'قبول طلب التحقق',
        'هل تأكدت من مطابقة بطاقة الرقم القومي مع الصورة الشخصية وتريد توثيق الحساب بالعلامة الزرقاء؟',
        'btn-success'
      );
      if (!confirmed) return;

      try {
        let done = false;

        // Attempt 1: Call RPC admin_review_verification
        try {
          const { data, error } = await supabase.rpc('admin_review_verification', {
            p_verification_id: verificationId,
            p_action: 'APPROVE',
          });
          if (error) throw error;
          if (data && data.success === false) throw new Error(data.error || 'فشلت عملية قبول التحقق');
          done = true;
        } catch (rpcErr) {
          console.warn('RPC admin_review_verification failed, falling back to direct table updates:', rpcErr);

          // Attempt 2: Direct updates on identity_verifications & profiles
          const { data: vRecord, error: fetchErr } = await supabase
            .from('identity_verifications')
            .select('user_id')
            .eq('id', verificationId)
            .single();

          if (fetchErr) throw fetchErr;

          const { error: vErr } = await supabase
            .from('identity_verifications')
            .update({ status: 'VERIFIED' })
            .eq('id', verificationId);

          if (vErr) throw vErr;

          if (vRecord?.user_id) {
            const { error: pErr } = await supabase
              .from('profiles')
              .update({ verification_status: 'VERIFIED', updated_at: new Date().toISOString() })
              .eq('id', vRecord.user_id);

            if (pErr) console.warn('Profile sync warning:', pErr);
          }
          done = true;
        }

        showToast('تم قبول التحقق وتوثيق الحساب بالعلامة الزرقاء بنجاح!', 'success');
        loadVerifications();
        loadOverview();
      } catch (err) {
        console.error('approveVerification error:', err);
        const parsed = formatDetailedError(err);
        showToast(`فشل قبول التحقق: ${parsed.message}`, 'error');
        alert(`❌ تعذر قبول طلب التوثيق:\n\n${parsed.title}\n${parsed.message}\n\n${parsed.raw ? `[تفاصيل الخطأ: ${parsed.raw}]` : ''}`);
      }
    },

    async rejectVerification(verificationId) {
      const defaultReason = 'عدم وضوح صورة بطاقة الرقم القومي أو عدم تطابقها مع الصورة الشخصية';
      const reasonInput = prompt('يرجى إدخال سبب رفض طلب التوثيق (سيظهر للمستخدم في حسابه):', defaultReason);
      if (reasonInput === null) return; // User cancelled prompt

      const finalReason = reasonInput.trim() || defaultReason;

      try {
        try {
          const { data, error } = await supabase.rpc('admin_review_verification', {
            p_verification_id: verificationId,
            p_action: 'REJECT',
            p_rejection_reason: finalReason,
          });
          if (error) throw error;
          if (data && data.success === false) throw new Error(data.error || 'فشلت عملية رفض التحقق');
        } catch (rpcErr) {
          console.warn('RPC admin_review_verification failed, falling back to direct table updates:', rpcErr);

          const { data: vRecord, error: fetchErr } = await supabase
            .from('identity_verifications')
            .select('user_id')
            .eq('id', verificationId)
            .single();

          if (fetchErr) throw fetchErr;

          const { error: vErr } = await supabase
            .from('identity_verifications')
            .update({
              status: 'FAILED',
              rejection_reason: finalReason,
            })
            .eq('id', verificationId);

          if (vErr) throw vErr;

          if (vRecord?.user_id) {
            await supabase
              .from('profiles')
              .update({ verification_status: 'FAILED', updated_at: new Date().toISOString() })
              .eq('id', vRecord.user_id);
          }
        }

        showToast('تم رفض طلب التحقق', 'warning');
        loadVerifications();
        loadOverview();
      } catch (err) {
        console.error('rejectVerification error:', err);
        const parsed = formatDetailedError(err);
        showToast(`فشل رفض التحقق: ${parsed.message}`, 'error');
        alert(`❌ تعذر رفض طلب التوثيق:\n\n${parsed.title}\n${parsed.message}\n\n${parsed.raw ? `[تفاصيل الخطأ: ${parsed.raw}]` : ''}`);
      }
    },
  };

  // ==========================================================================
  // CONFIGURATION MODAL (Supabase Credentials)
  // ==========================================================================
  function openConfigModal() {
    if ($('#cfg-supabase-url')) $('#cfg-supabase-url').value = currentSupabaseUrl;
    if ($('#cfg-supabase-key')) $('#cfg-supabase-key').value = currentSupabaseKey;
    show($('#config-modal'));
  }

  function closeConfigModal() {
    hide($('#config-modal'));
  }

  function handleConfigSubmit(e) {
    e.preventDefault();
    const newUrl = $('#cfg-supabase-url').value.trim();
    const newKey = $('#cfg-supabase-key').value.trim();

    if (!newUrl || !newKey) {
      showToast('يرجى إدخال رابط المشروع ومفتاح Supabase معاً', 'warning');
      return;
    }

    localStorage.setItem('gawezeny_supabase_url', newUrl);
    localStorage.setItem('gawezeny_supabase_anon_key', newKey);
    currentSupabaseUrl = newUrl;
    currentSupabaseKey = newKey;
    initSupabaseClient();
    showToast('تم حفظ إعدادات Supabase وتطبيق الاتصال الحي بنجاح', 'success');

    closeConfigModal();
    updateModeBadge();
    profileCache.clear();
    loadPageData(currentPage);
  }

  function handleConfigReset() {
    localStorage.removeItem('gawezeny_supabase_url');
    localStorage.removeItem('gawezeny_supabase_anon_key');
    localStorage.removeItem('gawezeny_demo_mode');
    currentSupabaseUrl = typeof SUPABASE_URL !== 'undefined' && SUPABASE_URL ? SUPABASE_URL : DEFAULT_SUPABASE_URL;
    currentSupabaseKey = typeof SUPABASE_ANON_KEY !== 'undefined' && SUPABASE_ANON_KEY ? SUPABASE_ANON_KEY : DEFAULT_SUPABASE_KEY;
    initSupabaseClient();
    closeConfigModal();
    updateModeBadge();
    showToast('تمت استعادة الإعدادات الافتراضية والاتصال بـ Supabase', 'info');
    loadPageData(currentPage);
  }

  // ==========================================================================
  // EVENT LISTENERS
  // ==========================================================================
  function initEventListeners() {
    // Login form
    if ($('#login-form')) $('#login-form').addEventListener('submit', handleLogin);
    if ($('#demo-login-btn')) $('#demo-login-btn').addEventListener('click', () => {});

    // Password toggle
    $('#toggle-password').addEventListener('click', () => {
      const input = $('#login-password');
      const icon = $('#toggle-password .material-icons-round');
      if (input.type === 'password') {
        input.type = 'text';
        icon.textContent = 'visibility';
      } else {
        input.type = 'password';
        icon.textContent = 'visibility_off';
      }
    });

    // Logout
    $('#logout-btn').addEventListener('click', handleLogout);

    // Navigation
    $$('.nav-item').forEach((item) => {
      item.addEventListener('click', (e) => {
        e.preventDefault();
        navigateTo(item.dataset.page);
      });
    });

    // Mobile menu
    $('#mobile-menu-btn').addEventListener('click', () => {
      $('#sidebar').classList.toggle('open');
      toggleSidebarOverlay(true);
    });

    // Refresh button
    $('#refresh-btn').addEventListener('click', async () => {
      const btn = $('#refresh-btn');
      btn.classList.add('spinning');
      profileCache.clear();
      await loadPageData(currentPage);
      if (currentPage !== 'overview') await loadOverview();
      btn.classList.remove('spinning');
      showToast('تم تحديث البيانات', 'success');
    });

    // Config Modal Listeners
    $('#open-config-btn').addEventListener('click', openConfigModal);
    $('#topbar-config-btn').addEventListener('click', openConfigModal);
    $('#mode-badge').addEventListener('click', openConfigModal);
    $('#config-modal-close').addEventListener('click', closeConfigModal);
    $('#config-modal').addEventListener('click', (e) => {
      if (e.target === $('#config-modal')) closeConfigModal();
    });
    $('#config-form').addEventListener('submit', handleConfigSubmit);
    $('#config-reset-btn').addEventListener('click', handleConfigReset);

    // Reports filter
    $('#reports-status-filter').addEventListener('change', loadReports);

    // Vouchers
    $('#vouchers-status-filter').addEventListener('change', loadVouchers);
    $('#generate-vouchers-btn').addEventListener('click', () => {
      show($('#generate-vouchers-form'));
      hide($('#generated-codes-result'));
      show($('#voucher-modal'));
    });
    $('#voucher-modal-close').addEventListener('click', () => hide($('#voucher-modal')));
    $('#voucher-modal').addEventListener('click', (e) => {
      if (e.target === $('#voucher-modal')) hide($('#voucher-modal'));
    });
    $('#generate-vouchers-form').addEventListener('submit', generateVouchers);
    $('#copy-codes-btn').addEventListener('click', () => {
      const codes = [...$$('#generated-codes-list .code-chip')].map((el) => el.textContent).join('\n');
      navigator.clipboard.writeText(codes).then(() => {
        showToast('تم نسخ جميع الأكواد إلى الحافظة', 'success');
      });
    });

    // Auto-fill voucher amount based on tier selection
    $('#voucher-tier').addEventListener('change', (e) => {
      const amounts = {
        'MONTHLY_200': 200,
        'QUARTERLY_500': 500,
        'SEMI_ANNUAL_900': 900,
        'ANNUAL_1500': 1500,
        'BUNDLE_FB_1000': 1000,
      };
      const durations = {
        'MONTHLY_200': 30,
        'QUARTERLY_500': 90,
        'SEMI_ANNUAL_900': 180,
        'ANNUAL_1500': 365,
        'BUNDLE_FB_1000': 30,
      };
      $('#voucher-amount').value = amounts[e.target.value] ?? 200;
      $('#voucher-duration').value = durations[e.target.value] ?? 30;
    });

    // Verifications filter
    $('#verifications-status-filter').addEventListener('change', loadVerifications);

    // Users Search & Filters
    $('#users-search').addEventListener('input', () => {
      clearTimeout(usersDebounceTimer);
      usersDebounceTimer = setTimeout(loadUsers, 300);
    });
    $('#users-gender-filter').addEventListener('change', loadUsers);
    $('#users-verification-filter').addEventListener('change', loadUsers);
    $('#users-subscription-filter').addEventListener('change', loadUsers);
  }

  // Sidebar overlay for mobile
  function toggleSidebarOverlay(showOverlay) {
    let overlay = document.querySelector('.sidebar-overlay');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.className = 'sidebar-overlay';
      document.body.appendChild(overlay);
      overlay.addEventListener('click', () => {
        $('#sidebar').classList.remove('open');
        overlay.classList.remove('show');
      });
    }
    if (showOverlay) overlay.classList.add('show');
    else overlay.classList.remove('show');
  }

  // Clock in Topbar
  function updateClock() {
    const now = new Date();
    const timeStr = now.toLocaleTimeString('ar-EG', {
      hour: '2-digit',
      minute: '2-digit',
    });
    const dateStr = now.toLocaleDateString('ar-EG', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
    const clockEl = $('#topbar-time');
    if (clockEl) clockEl.textContent = `${dateStr} — ${timeStr}`;
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================
  async function init() {
    initEventListeners();
    updateClock();
    setInterval(updateClock, 30000);
    updateModeBadge();
    await checkSession();
  }

  // Start on DOM ready
  document.addEventListener('DOMContentLoaded', init);
})();
