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
      alerts: 'إدارة التنبيهات والإشعارات',
      support: 'رسائل الدعم الفني',
      reports: 'إدارة البلاغات',
      vouchers: 'إدارة القسائم',
      verifications: 'مراجعة التحقق',
      users: 'إدارة المستخدمين',
      settings: 'الإعدادات العامة والتحكم',
      audit: 'سجل العمليات الإدارية',
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
      case 'alerts': await loadAlerts(); break;
      case 'support': await loadSupport(); break;
      case 'reports': await loadReports(); break;
      case 'vouchers': await loadVouchers(); break;
      case 'verifications': await loadVerifications(); break;
      case 'users': await loadUsers(); break;
      case 'settings': await loadSettings(); break;
      case 'audit': await loadAuditLog(); break;
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
          { count: usedVouchers },
          { count: openAlerts },
          { count: openSupport }
        ] = await Promise.all([
          supabase.from('profiles').select('id', { count: 'exact', head: true }),
          supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('verification_status', 'VERIFIED'),
          supabase.from('identity_verifications').select('id', { count: 'exact', head: true }).in('status', ['PENDING', 'MANUAL_REVIEW']),
          supabase.from('user_reports').select('id', { count: 'exact', head: true }).eq('status', 'PENDING'),
          supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('subscription_status', 'ACTIVE'),
          supabase.from('voucher_codes').select('code', { count: 'exact', head: true }),
          supabase.from('voucher_codes').select('code', { count: 'exact', head: true }).eq('is_used', true),
          supabase.from('admin_alerts').select('id', { count: 'exact', head: true }).eq('status', 'new'),
          supabase.from('support_messages').select('id', { count: 'exact', head: true }).eq('status', 'open'),
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
          open_alerts: openAlerts || 0,
          open_support: openSupport || 0,
        };
      }

      $('#stat-total-users').textContent = stats.total_users ?? 0;
      $('#stat-pending-reports').textContent = stats.pending_reports ?? 0;
      $('#stat-verified-users').textContent = stats.verified_users ?? 0;
      $('#stat-active-subs').textContent = stats.active_subscribers ?? 0;
      $('#stat-open-alerts').textContent = stats.open_alerts ?? 0;
      $('#stat-open-support').textContent = stats.open_support ?? 0;
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
      const alertsBadge = $('#alerts-badge');
      const supportBadge = $('#support-badge');

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

      if (stats.open_alerts > 0) {
        alertsBadge.textContent = stats.open_alerts;
        show(alertsBadge);
      } else {
        hide(alertsBadge);
      }

      if (stats.open_support > 0) {
        supportBadge.textContent = stats.open_support;
        show(supportBadge);
      } else {
        hide(supportBadge);
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
  // AUDIT LOG HELPER
  // ==========================================================================
  async function logAdminAction(action, entityType, entityId, oldValues, newValues, description) {
    try {
      if (!supabase) return;
      const adminId = currentUser ? currentUser.id : null;
      const adminEmail = currentUser ? currentUser.email : 'admin@gawezeny.com';
      await supabase.from('admin_audit_log').insert({
        admin_id: adminId,
        admin_email: adminEmail,
        action,
        entity_type: entityType,
        entity_id: String(entityId || ''),
        old_values: oldValues || null,
        new_values: newValues || null,
        description: description || ''
      });
    } catch (err) {
      console.warn('Audit log write notice:', err);
    }
  }

  // ==========================================================================
  // ALERTS MANAGEMENT
  // ==========================================================================
  let currentActiveAlert = null;
  let alertsDebounceTimer = null;

  const ALERT_TYPE_LABELS = {
    'report': 'بلاغ مستخدم',
    'suspicious_activity': 'نشاط مشبوه',
    'payment_issue': 'مشكلة دفع',
    'subscription': 'اشتراك',
    'system_error': 'خطأ نظام',
    'general': 'عام'
  };

  const ALERT_STATUS_LABELS = {
    'new': 'جديد',
    'in_review': 'قيد المراجعة',
    'resolved': 'تم الحل'
  };

  async function loadAlerts() {
    const tbody = $('#alerts-tbody');
    if (!tbody) return;
    tbody.innerHTML = '<tr class="empty-row"><td colspan="7">جاري التحميل...</td></tr>';

    try {
      if (!supabase) throw new Error('Supabase غير متصل');
      let query = supabase.from('admin_alerts').select('*').order('created_at', { ascending: false });

      const statusFilter = $('#alerts-status-filter')?.value || 'ALL';
      if (statusFilter !== 'ALL') query = query.eq('status', statusFilter);

      const typeFilter = $('#alerts-type-filter')?.value || 'ALL';
      if (typeFilter !== 'ALL') query = query.eq('alert_type', typeFilter);

      const sevFilter = $('#alerts-severity-filter')?.value || 'ALL';
      if (sevFilter !== 'ALL') query = query.eq('severity', sevFilter);

      const { data: alerts, error } = await query;
      if (error) throw error;

      if (!alerts || alerts.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="7">لا توجد تنبيهات تطابق المعايير المحددة</td></tr>';
        return;
      }

      const searchQuery = ($('#alerts-search')?.value || '').trim().toLowerCase();
      const filtered = searchQuery
        ? alerts.filter(a => (a.title || '').toLowerCase().includes(searchQuery) || (a.description || '').toLowerCase().includes(searchQuery))
        : alerts;

      if (filtered.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="7">لا توجد نتائج بحث</td></tr>';
        return;
      }

      tbody.innerHTML = '';
      for (const alert of filtered) {
        let userDisplay = '—';
        if (alert.related_user_id) {
          const prof = await getProfile(alert.related_user_id);
          userDisplay = prof ? prof.full_name : alert.related_user_id.slice(0, 8);
        }

        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td><span class="badge badge-${alert.severity}">${alert.severity.toUpperCase()}</span></td>
          <td><span class="tag">${ALERT_TYPE_LABELS[alert.alert_type] || alert.alert_type}</span></td>
          <td><strong>${escapeHtml(alert.title)}</strong><div class="truncate text-muted" style="font-size:12px;">${escapeHtml(alert.description || '')}</div></td>
          <td>${escapeHtml(userDisplay)}</td>
          <td><span class="badge badge-${alert.status}">${ALERT_STATUS_LABELS[alert.status] || alert.status}</span></td>
          <td class="text-muted" style="font-size:12px;">${formatDateTime(alert.created_at)}</td>
          <td>
            <button class="btn btn-outline btn-sm view-alert-btn" data-id="${alert.id}">
              <span class="material-icons-round">visibility</span>
              معاينة وحل
            </button>
          </td>
        `;
        tr.querySelector('.view-alert-btn').addEventListener('click', () => openAlertModal(alert));
        tbody.appendChild(tr);
      }
    } catch (err) {
      tbody.innerHTML = `<tr class="empty-row error-row"><td colspan="7">خطأ في تحميل التنبيهات: ${escapeHtml(err.message)}</td></tr>`;
      showToast('تعذر تحميل التنبيهات: ' + err.message, 'error');
    }
  }

  function openAlertModal(alert) {
    currentActiveAlert = alert;
    $('#alert-modal-title').textContent = alert.title;
    $('#alert-modal-type').textContent = ALERT_TYPE_LABELS[alert.alert_type] || alert.alert_type;
    $('#alert-modal-severity').innerHTML = `<span class="badge badge-${alert.severity}">${alert.severity.toUpperCase()}</span>`;
    $('#alert-modal-status').innerHTML = `<span class="badge badge-${alert.status}">${ALERT_STATUS_LABELS[alert.status] || alert.status}</span>`;
    $('#alert-modal-user').textContent = alert.related_user_id || 'غير محدد';
    $('#alert-modal-desc').textContent = alert.description || 'لا يوجد وصف';
    $('#alert-modal-notes').value = alert.resolution_notes || '';
    show($('#alert-details-modal'));
  }

  async function updateAlertStatus(newStatus) {
    if (!currentActiveAlert || !supabase) return;
    const notes = $('#alert-modal-notes').value.trim();
    const oldStatus = currentActiveAlert.status;

    try {
      const updateData = {
        status: newStatus,
        resolution_notes: notes,
        updated_at: new Date().toISOString()
      };
      if (newStatus === 'resolved') {
        updateData.resolved_at = new Date().toISOString();
        if (currentUser) updateData.resolved_by = currentUser.id;
      }

      const { error } = await supabase.from('admin_alerts').update(updateData).eq('id', currentActiveAlert.id);
      if (error) throw error;

      await logAdminAction(
        'update_alert_status',
        'admin_alerts',
        currentActiveAlert.id,
        { status: oldStatus },
        { status: newStatus, resolution_notes: notes },
        `تحديث حالة التنبيه (${currentActiveAlert.title}) إلى ${newStatus}`
      );

      hide($('#alert-details-modal'));
      showToast('تم تحديث حالة التنبيه بنجاح', 'success');
      await loadAlerts();
      await loadOverview();
    } catch (err) {
      showToast('فشل تحديث التنبيه: ' + err.message, 'error');
    }
  }

  function openCreateAlertModal() {
    $('#create-alert-form').reset();
    show($('#create-alert-modal'));
  }

  async function handleCreateAlertSubmit(e) {
    e.preventDefault();
    if (!supabase) return;

    const type = $('#new-alert-type').value;
    const severity = $('#new-alert-severity').value;
    const title = $('#new-alert-title').value.trim();
    const desc = $('#new-alert-desc').value.trim();
    const userId = $('#new-alert-user-id').value.trim() || null;

    if (!title) {
      showToast('يرجى إدخال عنوان التنبيه', 'warning');
      return;
    }

    try {
      const { data, error } = await supabase.from('admin_alerts').insert({
        alert_type: type,
        severity,
        title,
        description: desc,
        related_user_id: userId,
        status: 'new'
      }).select().single();

      if (error) throw error;

      await logAdminAction(
        'create_alert',
        'admin_alerts',
        data ? data.id : null,
        null,
        { type, severity, title },
        `إنشاء تنبيه إداري جديد: ${title}`
      );

      hide($('#create-alert-modal'));
      showToast('تمت إضافة التنبيه بنجاح', 'success');
      await loadAlerts();
      await loadOverview();
    } catch (err) {
      showToast('فشل إنشاء التنبيه: ' + err.message, 'error');
    }
  }

  // ==========================================================================
  // SUPPORT MESSAGES MANAGEMENT
  // ==========================================================================
  let currentActiveSupportMsg = null;
  let supportDebounceTimer = null;

  async function loadSupport() {
    const tbody = $('#support-tbody');
    if (!tbody) return;
    tbody.innerHTML = '<tr class="empty-row"><td colspan="7">جاري التحميل...</td></tr>';

    try {
      if (!supabase) throw new Error('Supabase غير متصل');
      let query = supabase.from('support_messages').select('*').order('created_at', { ascending: false });

      const statusFilter = $('#support-status-filter')?.value || 'ALL';
      if (statusFilter !== 'ALL') query = query.eq('status', statusFilter);

      const { data: messages, error } = await query;
      if (error) throw error;

      if (!messages || messages.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="7">لا توجد رسائل دعم واردة في هذا القسم</td></tr>';
        return;
      }

      const searchQuery = ($('#support-search')?.value || '').trim().toLowerCase();
      const filtered = searchQuery
        ? messages.filter(m => (m.subject || '').toLowerCase().includes(searchQuery) || (m.content || '').toLowerCase().includes(searchQuery))
        : messages;

      if (filtered.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="7">لا توجد نتائج بحث</td></tr>';
        return;
      }

      tbody.innerHTML = '';
      for (const msg of filtered) {
        const prof = await getProfile(msg.user_id);
        const userName = prof ? prof.full_name : msg.user_id.slice(0, 8);

        const tr = document.createElement('tr');
        const hasReply = Boolean(msg.admin_reply);

        tr.innerHTML = `
          <td><strong>${escapeHtml(userName)}</strong></td>
          <td>${escapeHtml(msg.subject || 'استفسار عام')}</td>
          <td><div class="truncate text-muted">${escapeHtml(msg.content)}</div></td>
          <td><span class="badge badge-${msg.status}">${msg.status === 'open' ? 'مفتوحة' : msg.status === 'in_progress' ? 'قيد المعالجة' : 'مغلقة'}</span></td>
          <td>${hasReply ? '<span class="tag tag-success">تم الرد</span>' : '<span class="tag tag-warning">بانتظار الرد</span>'}</td>
          <td class="text-muted" style="font-size:12px;">${formatDateTime(msg.created_at)}</td>
          <td>
            <button class="btn btn-outline btn-sm reply-support-btn" data-id="${msg.id}">
              <span class="material-icons-round">reply</span>
              عرض والرد
            </button>
          </td>
        `;
        tr.querySelector('.reply-support-btn').addEventListener('click', () => openSupportModal(msg, userName));
        tbody.appendChild(tr);
      }
    } catch (err) {
      tbody.innerHTML = `<tr class="empty-row error-row"><td colspan="7">خطأ في تحميل رسائل الدعم: ${escapeHtml(err.message)}</td></tr>`;
      showToast('تعذر تحميل رسائل الدعم: ' + err.message, 'error');
    }
  }

  function openSupportModal(msg, userName) {
    currentActiveSupportMsg = msg;
    $('#support-modal-subject').textContent = msg.subject || 'رسالة دعم';
    $('#support-modal-sender').textContent = userName || msg.user_id;
    $('#support-modal-date').textContent = formatDateTime(msg.created_at);
    $('#support-modal-status').innerHTML = `<span class="badge badge-${msg.status}">${msg.status === 'open' ? 'مفتوحة' : msg.status === 'in_progress' ? 'قيد المعالجة' : 'مغلقة'}</span>`;
    $('#support-modal-content').textContent = msg.content;
    $('#support-reply-text').value = msg.admin_reply || '';
    $('#support-reply-status').value = msg.status === 'open' ? 'closed' : msg.status;
    show($('#support-modal'));
  }

  async function handleSupportReplySubmit(e) {
    e.preventDefault();
    if (!currentActiveSupportMsg || !supabase) return;

    const replyText = $('#support-reply-text').value.trim();
    const newStatus = $('#support-reply-status').value;

    if (!replyText) {
      showToast('يرجى كتابة نص الرد قبل الإرسال', 'warning');
      return;
    }

    try {
      const updateData = {
        admin_reply: replyText,
        status: newStatus,
        replied_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      };
      if (currentUser) updateData.admin_id = currentUser.id;

      const { error } = await supabase.from('support_messages').update(updateData).eq('id', currentActiveSupportMsg.id);
      if (error) throw error;

      await logAdminAction(
        'reply_support_message',
        'support_messages',
        currentActiveSupportMsg.id,
        { status: currentActiveSupportMsg.status, admin_reply: currentActiveSupportMsg.admin_reply },
        { status: newStatus, admin_reply: replyText },
        `الرد على تذكرة دعم المستخدم: ${currentActiveSupportMsg.subject || ''}`
      );

      hide($('#support-modal'));
      showToast('تم إرسال الرد وتحديث حالة الرسالة بنجاح', 'success');
      await loadSupport();
      await loadOverview();
    } catch (err) {
      showToast('فشل إرسال الرد: ' + err.message, 'error');
    }
  }

  // ==========================================================================
  // SETTINGS MANAGEMENT (Payments, Plans, Chat Limits)
  // ==========================================================================
  async function loadSettings() {
    await Promise.all([
      loadPaymentSettings(),
      loadSubscriptionPlans(),
      loadChatLimitsSettings(),
      loadChatModerationSettings(),
      loadChatModerationViolations()
    ]);
  }

  async function loadPaymentSettings() {
    if (!supabase) return;
    try {
      const { data, error } = await supabase.from('payment_settings').select('*').eq('id', 'default').maybeSingle();
      if (error) throw error;

      if (data) {
        $('#cfg-voda-number').value = data.vodafone_cash_number || '';
        $('#cfg-voda-name').value = data.vodafone_cash_name || '';
        $('#cfg-voda-enabled').checked = Boolean(data.vodafone_cash_enabled);
        $('#cfg-insta-account').value = data.instapay_account || '';
        $('#cfg-insta-name').value = data.instapay_name || '';
        $('#cfg-insta-enabled').checked = Boolean(data.instapay_enabled);
        $('#cfg-support-whatsapp').value = data.support_whatsapp || '';
      }
    } catch (err) {
      console.warn('loadPaymentSettings notice:', err);
    }
  }

  async function handlePaymentSettingsSubmit(e) {
    e.preventDefault();
    if (!supabase) return;

    const vodaNum = $('#cfg-voda-number').value.trim();
    const vodaName = $('#cfg-voda-name').value.trim();
    const vodaEnabled = $('#cfg-voda-enabled').checked;
    const instaAcc = $('#cfg-insta-account').value.trim();
    const instaName = $('#cfg-insta-name').value.trim();
    const instaEnabled = $('#cfg-insta-enabled').checked;
    const supportWa = $('#cfg-support-whatsapp').value.trim();

    // Validation
    const phoneRegex = /^01[0125][0-9]{8}$/;
    if (!phoneRegex.test(vodaNum)) {
      showToast('رقم فودافون كاش غير صحيح. يجب أن يتكون من 11 رقماً ويبدأ بـ 010 أو 011 أو 012 أو 015', 'warning');
      return;
    }
    if (!phoneRegex.test(supportWa)) {
      showToast('رقم واتساب الدعم غير صحيح. يجب أن يكون رقماً مصرياً صالحاً', 'warning');
      return;
    }
    if (!instaAcc) {
      showToast('يرجى إدخال عنوان حساب إنستاباي (IPA)', 'warning');
      return;
    }

    try {
      const payload = {
        id: 'default',
        vodafone_cash_number: vodaNum,
        vodafone_cash_name: vodaName,
        vodafone_cash_enabled: vodaEnabled,
        instapay_account: instaAcc,
        instapay_name: instaName,
        instapay_enabled: instaEnabled,
        support_whatsapp: supportWa,
        updated_at: new Date().toISOString()
      };
      if (currentUser) payload.updated_by = currentUser.id;

      const { error } = await supabase.from('payment_settings').upsert(payload);
      if (error) throw error;

      await logAdminAction(
        'update_payment_settings',
        'payment_settings',
        'default',
        null,
        payload,
        'تحديث إعدادات بوابات الدفع (Vodafone Cash & InstaPay)'
      );

      showToast('تم حفظ إعدادات بوابات الدفع بنجاح وعكسها في التطبيق', 'success');
    } catch (err) {
      showToast('فشل حفظ إعدادات الدفع: ' + err.message, 'error');
    }
  }

  function handleTestDeepLinks() {
    const voda = $('#cfg-voda-number').value.trim() || '01099887766';
    const insta = $('#cfg-insta-account').value.trim() || 'gawezeny@instapay';
    const wa = $('#cfg-support-whatsapp').value.trim() || '01099887766';

    const sampleAmount = 200;
    const ussd = `*9*7*${voda}*${sampleAmount}#`;
    const instapayUri = `instapay://`;
    const waUri = `https://wa.me/2${wa}`;

    showConfirm(
      'معاينة روابط الدفع المدعومة',
      `• كود فودافون كاش المباشر (USSD):\n  ${ussd}\n\n• رابط فتح إنستا باي (Deep Link):\n  ${instapayUri}\n\n• رابط واتساب الدعم:\n  ${waUri}\n\nجميع الروابط جاهزة ومطابقة للمواصفات الرسمية.`,
      'btn-primary'
    );
  }

  // --- Subscription Plans Management ---
  async function loadSubscriptionPlans() {
    const tbody = $('#plans-tbody');
    if (!tbody || !supabase) return;
    tbody.innerHTML = '<tr class="empty-row"><td colspan="9">جاري التحميل...</td></tr>';

    try {
      const [plansRes, subsRes] = await Promise.all([
        supabase.from('subscription_plans').select('*').order('sort_order', { ascending: true }),
        supabase.from('subscriptions').select('tier').eq('status', 'ACTIVE')
      ]);

      if (plansRes.error) throw plansRes.error;
      const plans = plansRes.data || [];

      // Count active subscribers per tier
      const subCounts = {};
      if (subsRes.data) {
        for (const s of subsRes.data) {
          subCounts[s.tier] = (subCounts[s.tier] || 0) + 1;
        }
      }

      if (plans.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="9">لا توجد خطط اشتراك مسجلة</td></tr>';
        return;
      }

      tbody.innerHTML = '';
      for (const p of plans) {
        const tr = document.createElement('tr');
        const activeCount = subCounts[p.tier_key] || 0;

        tr.innerHTML = `
          <td><code>${escapeHtml(p.tier_key)}</code></td>
          <td><strong>${escapeHtml(p.name_ar)}</strong></td>
          <td>${p.price_egp} ج.م</td>
          <td>${p.duration_days} يوم</td>
          <td>${p.chat_message_limit ? p.chat_message_limit + ' رسالة' : 'غير محدود'}</td>
          <td>${p.is_popular ? '<span class="tag tag-pink">شائع</span>' : p.is_best_value ? '<span class="tag tag-gold">أفضل قيمة</span>' : '—'}</td>
          <td><span class="badge ${p.is_active ? 'badge-success' : 'badge-disabled'}">${p.is_active ? 'نشطة' : 'معطلة'}</span></td>
          <td><strong>${activeCount}</strong> مشترك</td>
          <td>
            <div style="display:flex; gap:6px;">
              <button class="btn btn-outline btn-sm edit-plan-btn" data-key="${p.tier_key}">
                <span class="material-icons-round">edit</span>
                تعديل
              </button>
              <button class="btn ${p.is_active ? 'btn-danger' : 'btn-success'} btn-sm toggle-plan-btn" data-key="${p.tier_key}">
                ${p.is_active ? 'تعطيل' : 'تفعيل'}
              </button>
            </div>
          </td>
        `;
        tr.querySelector('.edit-plan-btn').addEventListener('click', () => openPlanModal(p));
        tr.querySelector('.toggle-plan-btn').addEventListener('click', () => togglePlanActive(p));
        tbody.appendChild(tr);
      }
    } catch (err) {
      tbody.innerHTML = `<tr class="empty-row error-row"><td colspan="9">خطأ في تحميل الخطط: ${escapeHtml(err.message)}</td></tr>`;
      console.warn('loadSubscriptionPlans error:', err);
    }
  }

  function openPlanModal(plan = null) {
    $('#plan-id').value = plan ? plan.id : '';
    $('#plan-tier-key').value = plan ? plan.tier_key : '';
    $('#plan-tier-key').readOnly = Boolean(plan);
    $('#plan-name-ar').value = plan ? plan.name_ar : '';
    $('#plan-name-en').value = plan ? plan.name_en : '';
    $('#plan-price').value = plan ? plan.price_egp : '';
    $('#plan-duration').value = plan ? plan.duration_days : 30;
    $('#plan-chat-limit').value = plan && plan.chat_message_limit ? plan.chat_message_limit : '';
    $('#plan-chat-period').value = plan && plan.chat_limit_period ? plan.chat_limit_period : 'monthly';
    $('#plan-features-ar').value = plan && plan.features_ar ? plan.features_ar.join('\n') : '';
    $('#plan-is-active').checked = plan ? Boolean(plan.is_active) : true;
    $('#plan-is-popular').checked = plan ? Boolean(plan.is_popular) : false;
    $('#plan-modal-title').textContent = plan ? 'تعديل خطة الاشتراك' : 'إضافة خطة اشتراك جديدة';
    show($('#plan-modal'));
  }

  async function handlePlanSubmit(e) {
    e.preventDefault();
    if (!supabase) return;

    const id = $('#plan-id').value;
    const tierKey = $('#plan-tier-key').value.trim().toUpperCase();
    const nameAr = $('#plan-name-ar').value.trim();
    const nameEn = $('#plan-name-en').value.trim();
    const price = parseFloat($('#plan-price').value) || 0;
    const duration = parseInt($('#plan-duration').value, 10) || 30;
    const chatLimitRaw = $('#plan-chat-limit').value.trim();
    const chatLimit = chatLimitRaw ? parseInt(chatLimitRaw, 10) : null;
    const chatLimitPeriod = $('#plan-chat-period').value || 'monthly';
    const featuresRaw = $('#plan-features-ar').value.trim();
    const featuresAr = featuresRaw ? featuresRaw.split(/[\n,]+/).map(s => s.trim()).filter(Boolean) : [];
    const isActive = $('#plan-is-active').checked;
    const isPopular = $('#plan-is-popular').checked;

    if (!tierKey || !nameAr) {
      showToast('يرجى ملء مفتاح الخطة والاسم بالعربية', 'warning');
      return;
    }

    try {
      const payload = {
        tier_key: tierKey,
        name_ar: nameAr,
        name_en: nameEn || nameAr,
        price_egp: price,
        duration_days: duration,
        chat_message_limit: chatLimit,
        chat_limit_period: chatLimitPeriod,
        features_ar: featuresAr,
        is_active: isActive,
        is_popular: isPopular,
        updated_at: new Date().toISOString()
      };

      if (id) {
        const { error } = await supabase.from('subscription_plans').update(payload).eq('id', id);
        if (error) throw error;
        await logAdminAction('update_plan', 'subscription_plans', tierKey, null, payload, `تعديل خطة الاشتراك (${nameAr})`);
      } else {
        const { error } = await supabase.from('subscription_plans').insert(payload);
        if (error) throw error;
        await logAdminAction('create_plan', 'subscription_plans', tierKey, null, payload, `إنشاء خطة اشتراك جديدة (${nameAr})`);
      }

      hide($('#plan-modal'));
      showToast('تم حفظ خطة الاشتراك بنجاح وتحديث حدود الرسائل', 'success');
      await loadSubscriptionPlans();
      await loadChatLimitsSettings();
    } catch (err) {
      showToast('فشل حفظ الخطة: ' + err.message, 'error');
    }
  }

  async function togglePlanActive(plan) {
    if (!supabase) return;
    const newStatus = !plan.is_active;
    const actionText = newStatus ? 'تفعيل' : 'تعطيل';
    const confirmed = await showConfirm(
      `${actionText} خطة الاشتراك`,
      `هل أنت متأكد من ${actionText} خطة "${plan.name_ar}"؟ لن تتأثر الاشتراكات النشطة الحالية للمستخدمين.`,
      newStatus ? 'btn-success' : 'btn-danger'
    );
    if (!confirmed) return;

    try {
      const { error } = await supabase.from('subscription_plans').update({
        is_active: newStatus,
        updated_at: new Date().toISOString()
      }).eq('id', plan.id);
      if (error) throw error;

      await logAdminAction('toggle_plan_status', 'subscription_plans', plan.tier_key, { is_active: plan.is_active }, { is_active: newStatus }, `${actionText} خطة: ${plan.name_ar}`);
      showToast(`تم ${actionText} الخطة بنجاح`, 'success');
      await loadSubscriptionPlans();
    } catch (err) {
      showToast(`فشل ${actionText} الخطة: ` + err.message, 'error');
    }
  }

  // --- Chat Message Limits Settings ---
  async function loadChatLimitsSettings() {
    if (!supabase) return;
    try {
      const { data, error } = await supabase.from('chat_limit_settings').select('*').eq('id', 'default').maybeSingle();
      if (error) throw error;

      if (data) {
        if ($('#cfg-chat-daily-limit')) $('#cfg-chat-daily-limit').value = data.free_daily_limit ?? 10;
        if ($('#cfg-chat-monthly-limit')) $('#cfg-chat-monthly-limit').value = data.free_monthly_limit ?? 50;
        if ($('#cfg-chat-total-limit')) $('#cfg-chat-total-limit').value = data.free_total_limit ?? '';
        if ($('#cfg-chat-period')) $('#cfg-chat-period').value = data.free_limit_period || 'monthly';
        if ($('#cfg-chat-limit-action')) $('#cfg-chat-limit-action').value = data.limit_action || 'block_and_prompt';
        if ($('#cfg-chat-limits-enabled')) $('#cfg-chat-limits-enabled').checked = Boolean(data.enabled);
      }

      // Populate Subscribed Plans summary table in limits tab
      await loadChatLimitsPlansSummary();
    } catch (err) {
      console.warn('loadChatLimitsSettings notice:', err);
    }
  }

  async function loadChatLimitsPlansSummary() {
    const tbody = $('#limits-plans-summary-tbody');
    if (!tbody || !supabase) return;

    try {
      const { data: plans, error } = await supabase
        .from('subscription_plans')
        .select('*')
        .order('sort_order', { ascending: true });

      if (error) throw error;

      if (!plans || plans.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="7">لا توجد خطط اشتراك مسجلة بعد</td></tr>';
        return;
      }

      tbody.innerHTML = '';
      for (const p of plans) {
        const periodText = p.chat_limit_period === 'daily'
          ? 'يومياً'
          : p.chat_limit_period === 'per_subscription'
            ? 'خلال مدة الباقة'
            : 'شهرياً';

        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td><code>${escapeHtml(p.tier_key)}</code></td>
          <td><strong>${escapeHtml(p.name_ar)}</strong></td>
          <td>${p.price_egp} ج.م</td>
          <td>${p.duration_days} يوم</td>
          <td>${p.chat_message_limit ? '<strong style="color:var(--primary);">' + p.chat_message_limit + ' رسالة</strong>' : '<span class="tag tag-gold">غير محدود</span>'}</td>
          <td>${periodText}</td>
          <td>
            <button class="btn btn-outline btn-sm quick-edit-limit-btn" data-key="${p.tier_key}">
              <span class="material-icons-round">edit</span>
              تعديل الحد
            </button>
          </td>
        `;
        tr.querySelector('.quick-edit-limit-btn').addEventListener('click', () => openPlanModal(p));
        tbody.appendChild(tr);
      }
    } catch (err) {
      tbody.innerHTML = `<tr class="empty-row error-row"><td colspan="7">خطأ في تحميل ملخص حدود الباقات: ${escapeHtml(err.message)}</td></tr>`;
    }
  }

  async function handleChatLimitsSubmit(e) {
    e.preventDefault();
    if (!supabase) return;

    const dailyLimit = parseInt($('#cfg-chat-daily-limit').value, 10) || 10;
    const monthlyLimit = parseInt($('#cfg-chat-monthly-limit').value, 10) || 50;
    const totalLimitRaw = $('#cfg-chat-total-limit').value.trim();
    const totalLimit = totalLimitRaw ? parseInt(totalLimitRaw, 10) : null;
    const period = $('#cfg-chat-period').value || 'monthly';
    const action = $('#cfg-chat-limit-action').value;
    const enabled = $('#cfg-chat-limits-enabled').checked;

    try {
      const payload = {
        id: 'default',
        free_daily_limit: dailyLimit,
        free_monthly_limit: monthlyLimit,
        free_total_limit: totalLimit,
        free_limit_period: period,
        limit_action: action,
        enabled,
        updated_at: new Date().toISOString()
      };
      if (currentUser) payload.updated_by = currentUser.id;

      const { error } = await supabase.from('chat_limit_settings').upsert(payload);
      if (error) throw error;

      await logAdminAction(
        'update_chat_limits',
        'chat_limit_settings',
        'default',
        null,
        payload,
        `تحديث حدود رسائل الشات للمستخدمين المجانيين (الفترة: ${period}, يومي: ${dailyLimit}, شهري: ${monthlyLimit}, إجمالي: ${totalLimit ?? 'غير محدد'}, مفعل: ${enabled})`
      );

      showToast('تم حفظ وتطبيق إعدادات حدود رسائل الشات بنجاح في الـ Backend وقاعدة البيانات', 'success');
    } catch (err) {
      showToast('فشل حفظ حدود الشات: ' + err.message, 'error');
    }
  }

  // --- Chat Moderation Settings & Violations Log ---
  async function loadChatModerationSettings() {
    if (!supabase) return;
    try {
      const { data, error } = await supabase.from('chat_moderation_settings').select('*').eq('id', 'default').maybeSingle();
      if (error) throw error;

      if (data) {
        if ($('#cfg-mod-phones')) $('#cfg-mod-phones').checked = data.block_phones !== false;
        if ($('#cfg-mod-urls')) $('#cfg-mod-urls').checked = data.block_urls !== false;
        if ($('#cfg-mod-social')) $('#cfg-mod-social').checked = data.block_social_media !== false;
        if ($('#cfg-mod-action')) $('#cfg-mod-action').value = data.limit_action || 'block';
        if ($('#cfg-mod-custom-keywords')) {
          $('#cfg-mod-custom-keywords').value = (data.custom_blocked_keywords || []).join('\n');
        }
      }
    } catch (err) {
      console.warn('loadChatModerationSettings notice:', err);
    }
  }

  async function handleChatModerationSubmit(e) {
    e.preventDefault();
    if (!supabase) return;

    const blockPhones = $('#cfg-mod-phones').checked;
    const blockUrls = $('#cfg-mod-urls').checked;
    const blockSocial = $('#cfg-mod-social').checked;
    const action = $('#cfg-mod-action').value;
    const customKeywordsRaw = $('#cfg-mod-custom-keywords').value.trim();
    const customKeywords = customKeywordsRaw
      ? customKeywordsRaw.split(/[\n,]+/).map(s => s.trim()).filter(Boolean)
      : [];

    try {
      const payload = {
        id: 'default',
        block_phones: blockPhones,
        block_urls: blockUrls,
        block_social_media: blockSocial,
        limit_action: action,
        custom_blocked_keywords: customKeywords,
        updated_at: new Date().toISOString()
      };
      if (currentUser) payload.updated_by = currentUser.id;

      const { error } = await supabase.from('chat_moderation_settings').upsert(payload);
      if (error) throw error;

      await logAdminAction(
        'update_chat_moderation_settings',
        'chat_moderation_settings',
        'default',
        null,
        payload,
        `تحديث قواعد منع بيانات التواصل (أرقام: ${blockPhones}, روابط: ${blockUrls}, سوشيال: ${blockSocial}, كلمات: ${customKeywords.length})`
      );

      showToast('تم حفظ قواعد الرقابة ومنع بيانات التواصل بنجاح وتفعيلها في الـ Backend', 'success');
    } catch (err) {
      showToast('فشل حفظ إعدادات الرقابة: ' + err.message, 'error');
    }
  }

  async function loadChatModerationViolations() {
    const tbody = $('#mod-violations-tbody');
    if (!tbody || !supabase) return;

    tbody.innerHTML = '<tr class="empty-row"><td colspan="5">جاري التحميل...</td></tr>';

    try {
      const { data: violations, error } = await supabase
        .from('chat_moderation_violations')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(50);

      if (error) throw error;

      if (!violations || violations.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="5">لا توجد محاولات انتهاك مرصودة حتى الآن (جميع المحادثات ملتزمة بالقواعد)</td></tr>';
        return;
      }

      // Collect user IDs for sender names
      const senderIds = [...new Set(violations.map(v => v.sender_id).filter(Boolean))];
      let userNamesMap = {};
      if (senderIds.length > 0) {
        try {
          const { data: users } = await supabase
            .from('profiles')
            .select('id, full_name, phone_number')
            .in('id', senderIds);
          if (users) {
            users.forEach(u => {
              userNamesMap[u.id] = u.full_name || u.phone_number || 'مستخدم';
            });
          }
        } catch (_) {}
      }

      tbody.innerHTML = '';
      for (const v of violations) {
        const typeBadge = v.violation_type === 'PHONE_NUMBER'
          ? '<span class="badge badge-danger">رقم هاتف محمول/دولي</span>'
          : v.violation_type === 'EXTERNAL_URL'
            ? '<span class="badge badge-warning">رابط ويب خارجي</span>'
            : v.violation_type === 'SOCIAL_MEDIA'
              ? '<span class="badge badge-purple">حساب / شات سوشيال</span>'
              : '<span class="badge badge-navy">كلمة محظورة</span>';

        const senderName = userNamesMap[v.sender_id] || `<code>${escapeHtml((v.sender_id || '').substring(0, 8))}...</code>`;

        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td>${formatDate(v.created_at)}</td>
          <td><strong>${senderName}</strong></td>
          <td>${typeBadge}</td>
          <td><code style="background:var(--border-subtle); padding:2px 6px; border-radius:4px;">${escapeHtml(v.matched_pattern || '—')}</code></td>
          <td><span class="tag tag-pink">تم حظر الإرسال (Blocked)</span></td>
        `;
        tbody.appendChild(tr);
      }
    } catch (err) {
      tbody.innerHTML = `<tr class="empty-row error-row"><td colspan="5">خطأ في تحميل سجل الانتهاكات: ${escapeHtml(err.message)}</td></tr>`;
      console.warn('loadChatModerationViolations notice:', err);
    }
  }

  // ==========================================================================
  // AUDIT LOG PAGE
  // ==========================================================================
  let auditDebounceTimer = null;

  async function loadAuditLog() {
    const tbody = $('#audit-table tbody');
    if (!tbody || !supabase) return;
    tbody.innerHTML = '<tr class="empty-row"><td colspan="5">جاري التحميل...</td></tr>';

    try {
      const { data: logs, error } = await supabase
        .from('admin_audit_log')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100);

      if (error) throw error;

      if (!logs || logs.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="5">لا توجد عمليات إدارية مسجلة بعد</td></tr>';
        return;
      }

      const searchQuery = ($('#audit-search')?.value || '').trim().toLowerCase();
      const filtered = searchQuery
        ? logs.filter(l => (l.action || '').toLowerCase().includes(searchQuery) || (l.description || '').toLowerCase().includes(searchQuery) || (l.admin_email || '').toLowerCase().includes(searchQuery))
        : logs;

      if (filtered.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="5">لا توجد نتائج بحث</td></tr>';
        return;
      }

      tbody.innerHTML = '';
      for (const log of filtered) {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td><strong>${escapeHtml(log.admin_email || 'مدير النظام')}</strong></td>
          <td><span class="tag tag-navy">${escapeHtml(log.action)}</span></td>
          <td><code>${escapeHtml(log.entity_type || '—')} / ${escapeHtml(log.entity_id || '—')}</code></td>
          <td>
            <div style="font-weight:600;">${escapeHtml(log.description || '—')}</div>
            ${log.new_values ? `<pre style="font-size:11px; color:var(--text-muted); margin:4px 0 0 0; max-height:40px; overflow:hidden;">${escapeHtml(JSON.stringify(log.new_values))}</pre>` : ''}
          </td>
          <td class="text-muted" style="font-size:12px;">${formatDateTime(log.created_at)}</td>
        `;
        tbody.appendChild(tr);
      }
    } catch (err) {
      tbody.innerHTML = `<tr class="empty-row error-row"><td colspan="5">خطأ في تحميل سجل العمليات: ${escapeHtml(err.message)}</td></tr>`;
      console.warn('loadAuditLog error:', err);
    }
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

    // Alerts Search & Filters
    if ($('#alerts-status-filter')) $('#alerts-status-filter').addEventListener('change', loadAlerts);
    if ($('#alerts-type-filter')) $('#alerts-type-filter').addEventListener('change', loadAlerts);
    if ($('#alerts-severity-filter')) $('#alerts-severity-filter').addEventListener('change', loadAlerts);
    if ($('#alerts-search')) {
      $('#alerts-search').addEventListener('input', () => {
        clearTimeout(alertsDebounceTimer);
        alertsDebounceTimer = setTimeout(loadAlerts, 300);
      });
    }
    if ($('#create-alert-btn')) $('#create-alert-btn').addEventListener('click', openCreateAlertModal);
    if ($('#create-alert-modal-close')) $('#create-alert-modal-close').addEventListener('click', () => hide($('#create-alert-modal')));
    if ($('#create-alert-cancel')) $('#create-alert-cancel').addEventListener('click', () => hide($('#create-alert-modal')));
    if ($('#create-alert-modal')) {
      $('#create-alert-modal').addEventListener('click', (e) => {
        if (e.target === $('#create-alert-modal')) hide($('#create-alert-modal'));
      });
    }
    if ($('#create-alert-form')) $('#create-alert-form').addEventListener('submit', handleCreateAlertSubmit);
    if ($('#alert-modal-close')) $('#alert-modal-close').addEventListener('click', () => hide($('#alert-details-modal')));
    if ($('#alert-details-modal')) {
      $('#alert-details-modal').addEventListener('click', (e) => {
        if (e.target === $('#alert-details-modal')) hide($('#alert-details-modal'));
      });
    }
    if ($('#alert-set-in-review-btn')) $('#alert-set-in-review-btn').addEventListener('click', () => updateAlertStatus('in_review'));
    if ($('#alert-set-resolved-btn')) $('#alert-set-resolved-btn').addEventListener('click', () => updateAlertStatus('resolved'));

    // Support Messages
    if ($('#support-status-filter')) $('#support-status-filter').addEventListener('change', loadSupport);
    if ($('#support-search')) {
      $('#support-search').addEventListener('input', () => {
        clearTimeout(supportDebounceTimer);
        supportDebounceTimer = setTimeout(loadSupport, 300);
      });
    }
    if ($('#support-modal-close')) $('#support-modal-close').addEventListener('click', () => hide($('#support-modal')));
    if ($('#support-reply-cancel')) $('#support-reply-cancel').addEventListener('click', () => hide($('#support-modal')));
    if ($('#support-modal')) {
      $('#support-modal').addEventListener('click', (e) => {
        if (e.target === $('#support-modal')) hide($('#support-modal'));
      });
    }
    if ($('#support-reply-form')) $('#support-reply-form').addEventListener('submit', handleSupportReplySubmit);

    // Settings Navigation Tabs
    $$('.settings-tab-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        const targetTabId = btn.dataset.tab;
        $$('.settings-tab-btn').forEach(b => b.classList.remove('active'));
        $$('.settings-tab-content').forEach(c => c.classList.remove('active'));
        btn.classList.add('active');
        const targetContent = document.getElementById(targetTabId);
        if (targetContent) targetContent.classList.add('active');
      });
    });

    // Settings Forms & Actions
    if ($('#payment-settings-form')) $('#payment-settings-form').addEventListener('submit', handlePaymentSettingsSubmit);
    if ($('#test-deep-links-btn')) $('#test-deep-links-btn').addEventListener('click', handleTestDeepLinks);
    if ($('#add-plan-btn')) $('#add-plan-btn').addEventListener('click', () => openPlanModal(null));
    if ($('#plan-modal-close')) $('#plan-modal-close').addEventListener('click', () => hide($('#plan-modal')));
    if ($('#plan-modal-cancel')) $('#plan-modal-cancel').addEventListener('click', () => hide($('#plan-modal')));
    if ($('#plan-modal')) {
      $('#plan-modal').addEventListener('click', (e) => {
        if (e.target === $('#plan-modal')) hide($('#plan-modal'));
      });
    }
    if ($('#plan-form')) $('#plan-form').addEventListener('submit', handlePlanSubmit);
    if ($('#chat-limits-form')) $('#chat-limits-form').addEventListener('submit', handleChatLimitsSubmit);
    if ($('#chat-moderation-form')) $('#chat-moderation-form').addEventListener('submit', handleChatModerationSubmit);
    if ($('#refresh-mod-violations-btn')) $('#refresh-mod-violations-btn').addEventListener('click', loadChatModerationViolations);

    // Audit Log Search
    if ($('#audit-search')) {
      $('#audit-search').addEventListener('input', () => {
        clearTimeout(auditDebounceTimer);
        auditDebounceTimer = setTimeout(loadAuditLog, 300);
      });
    }
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
