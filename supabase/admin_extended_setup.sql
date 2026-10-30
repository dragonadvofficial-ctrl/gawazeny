-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- SCRIPT:   Extended Admin Dashboard - Support, Alerts, Settings, Chat Limits
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. PREREQUISITES (ADMIN USERS TABLE & HELPER FUNCTION)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT,
  role TEXT NOT NULL DEFAULT 'ADMIN' CHECK (role IN ('SUPER_ADMIN', 'ADMIN', 'MODERATOR')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_users_select_own" ON admin_users;
CREATE POLICY "admin_users_select_own"
ON admin_users FOR SELECT
TO authenticated
USING (id = auth.uid());

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM admin_users WHERE id = auth.uid()
  );
$$;

-- ----------------------------------------------------------------------------
-- 1. SUPPORT MESSAGES TABLE
-- Stores messages sent from users to the admin support team.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS support_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  subject TEXT,
  content TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'closed')),
  admin_reply TEXT,
  admin_id UUID REFERENCES admin_users(id),
  replied_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;

-- Users can insert their own support messages
DROP POLICY IF EXISTS "support_messages_insert_own" ON support_messages;
CREATE POLICY "support_messages_insert_own"
ON support_messages FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Users can read their own support messages (to see replies)
DROP POLICY IF EXISTS "support_messages_select_own" ON support_messages;
CREATE POLICY "support_messages_select_own"
ON support_messages FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Admins can read all support messages
DROP POLICY IF EXISTS "admin_select_all_support" ON support_messages;
CREATE POLICY "admin_select_all_support"
ON support_messages FOR SELECT
TO authenticated
USING (is_admin());

-- Admins can update support messages (reply, change status)
DROP POLICY IF EXISTS "admin_update_support" ON support_messages;
CREATE POLICY "admin_update_support"
ON support_messages FOR UPDATE
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

CREATE INDEX IF NOT EXISTS idx_support_messages_user ON support_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_status ON support_messages(status);

-- ----------------------------------------------------------------------------
-- 2. ADMIN ALERTS TABLE
-- Stores system alerts, reports, payment issues, suspicious activities.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type TEXT NOT NULL DEFAULT 'general'
    CHECK (alert_type IN ('report', 'suspicious_activity', 'system_error', 'payment_issue', 'subscription', 'general')),
  title TEXT NOT NULL,
  description TEXT,
  severity TEXT NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  status TEXT NOT NULL DEFAULT 'new'
    CHECK (status IN ('new', 'in_review', 'resolved')),
  related_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  related_entity_id TEXT,
  resolved_by UUID REFERENCES admin_users(id),
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE admin_alerts ENABLE ROW LEVEL SECURITY;

-- Only admins can access alerts
DROP POLICY IF EXISTS "admin_select_alerts" ON admin_alerts;
CREATE POLICY "admin_select_alerts"
ON admin_alerts FOR SELECT
TO authenticated
USING (is_admin());

DROP POLICY IF EXISTS "admin_insert_alerts" ON admin_alerts;
CREATE POLICY "admin_insert_alerts"
ON admin_alerts FOR INSERT
TO authenticated
WITH CHECK (is_admin());

DROP POLICY IF EXISTS "admin_update_alerts" ON admin_alerts;
CREATE POLICY "admin_update_alerts"
ON admin_alerts FOR UPDATE
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

CREATE INDEX IF NOT EXISTS idx_admin_alerts_status ON admin_alerts(status);
CREATE INDEX IF NOT EXISTS idx_admin_alerts_type ON admin_alerts(alert_type);

-- ----------------------------------------------------------------------------
-- 3. PAYMENT SETTINGS TABLE
-- Admin-configurable payment gateway settings (Vodafone Cash, InstaPay).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payment_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  vodafone_cash_number TEXT NOT NULL DEFAULT '01099887766',
  vodafone_cash_name TEXT NOT NULL DEFAULT 'جوزيني يا ماما',
  vodafone_cash_enabled BOOLEAN NOT NULL DEFAULT true,
  instapay_account TEXT NOT NULL DEFAULT 'gawezeny@instapay',
  instapay_name TEXT NOT NULL DEFAULT 'جوزيني يا ماما',
  instapay_enabled BOOLEAN NOT NULL DEFAULT true,
  support_whatsapp TEXT NOT NULL DEFAULT '01099887766',
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES admin_users(id)
);

ALTER TABLE payment_settings ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read payment settings (needed for checkout)
DROP POLICY IF EXISTS "payment_settings_select_all" ON payment_settings;
CREATE POLICY "payment_settings_select_all"
ON payment_settings FOR SELECT
TO authenticated
USING (true);

-- Only admins can update payment settings
DROP POLICY IF EXISTS "admin_update_payment_settings" ON payment_settings;
CREATE POLICY "admin_update_payment_settings"
ON payment_settings FOR UPDATE
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- Insert default payment settings row
INSERT INTO payment_settings (id) VALUES ('default') ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. SUBSCRIPTION PLANS TABLE (Admin-managed)
-- Dynamic subscription plans that can be created/modified by admin.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_key TEXT NOT NULL UNIQUE,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  price_egp NUMERIC(10,2) NOT NULL,
  original_price_egp NUMERIC(10,2),
  duration_days INT NOT NULL DEFAULT 30,
  features_ar TEXT[] DEFAULT '{}',
  features_en TEXT[] DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_popular BOOLEAN NOT NULL DEFAULT false,
  is_best_value BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 0,
  chat_message_limit INT DEFAULT NULL,
  chat_limit_period TEXT DEFAULT 'monthly'
    CHECK (chat_limit_period IN ('daily', 'monthly', 'per_subscription')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read active plans
DROP POLICY IF EXISTS "subscription_plans_select_active" ON subscription_plans;
CREATE POLICY "subscription_plans_select_active"
ON subscription_plans FOR SELECT
TO authenticated
USING (true);

-- Only admins can insert/update/delete plans
DROP POLICY IF EXISTS "admin_manage_plans" ON subscription_plans;
CREATE POLICY "admin_manage_plans"
ON subscription_plans FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- Seed default plans from existing enum values
INSERT INTO subscription_plans (tier_key, name_ar, name_en, price_egp, original_price_egp, duration_days, is_popular, is_best_value, sort_order, chat_message_limit, chat_limit_period)
VALUES
  ('MONTHLY_200', 'اشتراك شهري', 'Monthly Subscription', 200, NULL, 30, false, false, 1, 100, 'monthly'),
  ('QUARTERLY_500', 'اشتراك 3 شهور', '3 Months Subscription', 500, 600, 90, false, false, 2, 500, 'monthly'),
  ('SEMI_ANNUAL_900', 'اشتراك 6 شهور', '6 Months Subscription', 900, 1200, 180, true, false, 3, NULL, 'monthly'),
  ('ANNUAL_1500', 'اشتراك 12 شهر', '12 Months (Annual)', 1500, 2400, 365, false, true, 4, NULL, 'monthly'),
  ('BUNDLE_FB_1000', 'عرض فيسبوك المميز', 'Facebook VIP Bundle', 1000, NULL, 30, false, false, 5, 100, 'monthly')
ON CONFLICT (tier_key) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. CHAT MESSAGE LIMITS TABLE
-- Global chat limit settings configurable by admin.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_limit_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  free_daily_limit INT NOT NULL DEFAULT 10,
  free_monthly_limit INT NOT NULL DEFAULT 50,
  free_total_limit INT DEFAULT NULL,
  free_limit_period TEXT NOT NULL DEFAULT 'monthly'
    CHECK (free_limit_period IN ('daily', 'monthly', 'total')),
  limit_action TEXT NOT NULL DEFAULT 'block_and_prompt'
    CHECK (limit_action IN ('block_and_prompt', 'soft_warning', 'block_only')),
  enabled BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES admin_users(id)
);

ALTER TABLE chat_limit_settings ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read chat limits (needed in the app)
DROP POLICY IF EXISTS "chat_limits_select_all" ON chat_limit_settings;
CREATE POLICY "chat_limits_select_all"
ON chat_limit_settings FOR SELECT
TO authenticated
USING (true);

-- Only admins can update
DROP POLICY IF EXISTS "admin_update_chat_limits" ON chat_limit_settings;
CREATE POLICY "admin_update_chat_limits"
ON chat_limit_settings FOR UPDATE
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

INSERT INTO chat_limit_settings (id, free_daily_limit, free_monthly_limit, free_limit_period) 
VALUES ('default', 10, 50, 'monthly') 
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5B. CHAT MODERATION SETTINGS & VIOLATIONS LOG
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_moderation_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  block_phones BOOLEAN NOT NULL DEFAULT true,
  block_urls BOOLEAN NOT NULL DEFAULT true,
  block_social_media BOOLEAN NOT NULL DEFAULT true,
  custom_blocked_keywords TEXT[] DEFAULT '{}',
  limit_action TEXT NOT NULL DEFAULT 'block' CHECK (limit_action IN ('block', 'flag_only')),
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES admin_users(id)
);

ALTER TABLE chat_moderation_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_moderation_settings_select_all" ON chat_moderation_settings;
CREATE POLICY "chat_moderation_settings_select_all"
ON chat_moderation_settings FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "admin_update_chat_moderation_settings" ON chat_moderation_settings;
CREATE POLICY "admin_update_chat_moderation_settings"
ON chat_moderation_settings FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

INSERT INTO chat_moderation_settings (id, block_phones, block_urls, block_social_media)
VALUES ('default', true, true, true)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS chat_moderation_violations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
  violation_type TEXT NOT NULL CHECK (violation_type IN ('PHONE_NUMBER', 'EXTERNAL_URL', 'SOCIAL_MEDIA', 'CUSTOM_KEYWORD')),
  matched_pattern TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE chat_moderation_violations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_select_chat_violations" ON chat_moderation_violations;
CREATE POLICY "admin_select_chat_violations"
ON chat_moderation_violations FOR SELECT
TO authenticated
USING (is_admin());

CREATE INDEX IF NOT EXISTS idx_chat_violations_sender ON chat_moderation_violations(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_violations_created_at ON chat_moderation_violations(created_at DESC);

-- ----------------------------------------------------------------------------
-- 6. ADMIN AUDIT LOG TABLE
-- Tracks all important admin actions with timestamps and values.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id),
  admin_email TEXT,
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id TEXT,
  old_values JSONB,
  new_values JSONB,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE admin_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_select_audit_log" ON admin_audit_log;
CREATE POLICY "admin_select_audit_log"
ON admin_audit_log FOR SELECT
TO authenticated
USING (is_admin());

DROP POLICY IF EXISTS "admin_insert_audit_log" ON admin_audit_log;
CREATE POLICY "admin_insert_audit_log"
ON admin_audit_log FOR INSERT
TO authenticated
WITH CHECK (is_admin());

CREATE INDEX IF NOT EXISTS idx_audit_log_admin ON admin_audit_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON admin_audit_log(action);

-- ----------------------------------------------------------------------------
-- 7. HELPER: Text normalization for chat moderation
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION normalize_chat_text(p_text TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_res TEXT;
BEGIN
  IF p_text IS NULL THEN
    RETURN '';
  END IF;

  v_res := lower(p_text);
  v_res := translate(v_res, '٠١٢٣٤٥٦٧٨٩', '0123456789');
  v_res := translate(v_res, '۰۱۲۳۴۵۶۷۸۹', '0123456789');
  v_res := regexp_replace(v_res, '[\u064B-\u065F\u0670]', '', 'g');
  v_res := regexp_replace(v_res, '\u0640', '', 'g');
  v_res := regexp_replace(v_res, '[\u200B-\u200F\uFEFF\u00AD]', '', 'g');
  v_res := translate(v_res, 'أإآٱ', 'اااا');
  v_res := translate(v_res, 'ة', 'ه');
  v_res := translate(v_res, 'ى', 'ي');

  RETURN v_res;
END;
$$;

-- ----------------------------------------------------------------------------
-- 7B. CHAT MODERATION CHECK FUNCTION
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_chat_message_moderation(
  p_content TEXT,
  p_sender_id UUID,
  p_conversation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_settings RECORD;
  v_clean TEXT;
  v_digits_only TEXT;
  v_violation_type TEXT := NULL;
  v_matched_pattern TEXT := NULL;
  v_rule_reason TEXT := NULL;
  v_kw TEXT;
  v_spelled_digit_count INT := 0;
BEGIN
  SELECT block_phones, block_urls, block_social_media, custom_blocked_keywords, limit_action
  INTO v_settings
  FROM chat_moderation_settings
  WHERE id = 'default';

  IF v_settings IS NULL THEN
    v_settings.block_phones := true;
    v_settings.block_urls := true;
    v_settings.block_social_media := true;
    v_settings.custom_blocked_keywords := '{}';
  END IF;

  v_clean := normalize_chat_text(p_content);

  -- Custom Keywords
  IF v_settings.custom_blocked_keywords IS NOT NULL AND array_length(v_settings.custom_blocked_keywords, 1) > 0 THEN
    FOREACH v_kw IN ARRAY v_settings.custom_blocked_keywords LOOP
      IF length(trim(v_kw)) > 1 AND v_clean LIKE '%' || normalize_chat_text(trim(v_kw)) || '%' THEN
        v_violation_type := 'CUSTOM_KEYWORD';
        v_matched_pattern := trim(v_kw);
        v_rule_reason := 'تم حظر الرسالة لاحتوائها على عبارة محظورة إدارياً: ' || trim(v_kw);
        EXIT;
      END IF;
    END LOOP;
  END IF;

  -- Phone Numbers
  IF v_violation_type IS NULL AND v_settings.block_phones THEN
    v_digits_only := regexp_replace(v_clean, '[^0-9]', '', 'g');

    IF v_digits_only ~ '(20)?1[0125][0-9]{8}' THEN
      v_violation_type := 'PHONE_NUMBER';
      v_matched_pattern := 'رقم هاتف مصري محمول';
      v_rule_reason := 'مشاركة أرقام الهواتف غير مسموح بها داخل المحادثة حفاظاً على خصوصيتك وأمانك وفقاً لشروط الاستخدام.';
    ELSIF v_clean ~ '(\+|00)[0-9]{1,4}[\s\-\.()]{0,3}[0-9]{3,}[\s\-\.()]{0,3}[0-9]{3,}'
          OR length(v_digits_only) >= 8 AND v_clean ~ '(^|\s|[^\w])([0-9][\s\-\.()]{0,2}){8,14}($|\s|[^\w])' THEN
      v_violation_type := 'PHONE_NUMBER';
      v_matched_pattern := 'رقم هاتف دولي';
      v_rule_reason := 'مشاركة أرقام الهواتف والتواصل الخارجي غير مسموح بها داخل المحادثة.';
    ELSIF v_clean ~ '(زيرو|صفر)\s*(عشر[ةه]|واحد\s*صفر|واحد\s*[0-9]|[0-9]\s*[0-9])'
       OR v_clean ~ '(رقمي|نمرتي|موبايلي|فون|واتس)\s*(هو|:)?\s*([0-9]|زيرو|صفر|واحد)' THEN
      v_violation_type := 'PHONE_NUMBER';
      v_matched_pattern := 'رقم هاتف مكتوب بصيغة نصية';
      v_rule_reason := 'مشاركة أرقام الهواتف أو طلب التواصل الخارجي غير مسموح بها داخل المحادثة.';
    END IF;

    IF v_violation_type IS NULL THEN
      SELECT count(*) INTO v_spelled_digit_count
      FROM regexp_matches(v_clean, '(زيرو|صفر|واحد|اتنين|تلاته|اربعه|خمسه|سته|سبعه|تمانيه|تسعه)', 'g');
      IF v_spelled_digit_count >= 5 THEN
        v_violation_type := 'PHONE_NUMBER';
        v_matched_pattern := 'أرقام هواتف مكتوبة بحروف هجائية';
        v_rule_reason := 'مشاركة أرقام الهواتف بوسائل كتابية بديلة غير مسموح بها داخل المحادثة.';
      END IF;
    END IF;
  END IF;

  -- External Links & URLs
  IF v_violation_type IS NULL AND v_settings.block_urls THEN
    IF v_clean ~ 'https?:\/\/[^\s]+' OR v_clean ~ 'ftp:\/\/[^\s]+' THEN
      v_violation_type := 'EXTERNAL_URL';
      v_matched_pattern := 'رابط ويب مباشر (URL)';
      v_rule_reason := 'إرسال الروابط والمواقع الخارجية غير مسموح به داخل المحادثة لحماية المستخدمين.';
    ELSIF v_clean ~ 'www\.[a-z0-9\-]+(\.[a-z]{2,})+' THEN
      v_violation_type := 'EXTERNAL_URL';
      v_matched_pattern := 'رابط موقع ويب (www)';
      v_rule_reason := 'إرسال الروابط والمواقع الخارجية غير مسموح به داخل المحادثة.';
    ELSIF v_clean ~ '[a-z0-9\-]+(\s*(\.|\(\.\)|\[\.\])\s*)(com|net|org|app|io|me|eg|co|ai|ly|gl|link|site|online|xyz|top|info|biz|tv|cc|to)($|\s|[^\w])'
       OR v_clean ~ '(t\.me|wa\.me|bit\.ly|tinyurl\.com|cutt\.ly|instagr\.am|fb\.com|fb\.me)\/[a-z0-9\-_]+'
       OR v_clean ~ '(دوت\s*كوم|دوت\s*نت|دوت\s*اورج|\s*dot\s*com|\s*dot\s*net)' THEN
      v_violation_type := 'EXTERNAL_URL';
      v_matched_pattern := 'اسم نطاق أو رابط مختصر';
      v_rule_reason := 'مشاركة الروابط الخارجية أو النطاقات غير مسموح بها داخل المحادثة.';
    END IF;
  END IF;

  -- Social Media Requests and Handles
  IF v_violation_type IS NULL AND v_settings.block_social_media THEN
    IF v_clean ~ '(^|\s)@[a-z0-9_\.]{3,30}($|\s)' THEN
      v_violation_type := 'SOCIAL_MEDIA';
      v_matched_pattern := 'اسم مستخدم خارجي (@handle)';
      v_rule_reason := 'مشاركة أسماء المستخدمين وحسابات التواصل غير مسموح بها داخل المحادثة.';
    ELSIF v_clean ~ '(ابعت|ابعتي|ابعتلي|ابعتيلي|هات|هاتي|اديني|عايز|عايزه|عاوز|عاوزه|نكمل|نتكلم|شات|كلمني|كلميني)\s*.*(اكاونت|حساب|فيسبوك|فيس|انستا|انستجرام|واتس|واتساب|تلي|تليجرام|تيليجرام|سناب|سنابشات|تيك\s*توك|فون|نمره|رقمك|رقمي|يوزرك|يوزر)'
       OR v_clean ~ '(اكاونت|حسابي|يوزري|صفحتي)\s*(علي|في|بتاعي)?\s*(الفيسبوك|الفيس|الانستا|الانستجرام|الواتس|الواتساب|التليجرام|السناب)'
       OR v_clean ~ '(نتكلم|نكلم|نكمل\s*كلام)\s*(بره|برة|فون|واتس|علي\s*الواتس|علي\s*الفيس|علي\s*الانستا)'
       OR v_clean ~ '(تواصل\s*خارجي|شات\s*بره|شات\s*برة)' THEN
      v_violation_type := 'SOCIAL_MEDIA';
      v_matched_pattern := 'طلب تبادل حسابات تواصل أو شات خارجي';
      v_rule_reason := 'طلب أو تبادل حسابات التواصل الاجتماعي (فيسبوك، انستجرام، واتساب، تليجرام، وغيرها) غير مسموح به؛ لضمان جدية وأمان التعارف داخل التطبيق.';
    END IF;
  END IF;

  IF v_violation_type IS NOT NULL THEN
    INSERT INTO chat_moderation_violations (
      sender_id,
      conversation_id,
      violation_type,
      matched_pattern
    ) VALUES (
      p_sender_id,
      p_conversation_id,
      v_violation_type,
      v_matched_pattern
    );

    RETURN jsonb_build_object(
      'allowed', false,
      'violation_type', v_violation_type,
      'matched_pattern', v_matched_pattern,
      'reason', v_rule_reason
    );
  END IF;

  RETURN jsonb_build_object('allowed', true);
END;
$$;

-- ----------------------------------------------------------------------------
-- 7C. RPC: check_user_message_limit WITH ADVISORY TRANSACTION LOCK
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_user_message_limit(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sub_status TEXT;
  v_sub_tier TEXT;
  v_sub_starts_at TIMESTAMPTZ;
  v_plan_limit INT;
  v_plan_period TEXT;
  v_plan_name TEXT := 'مستخدم عادي (مجاني)';
  v_free_daily INT;
  v_free_monthly INT;
  v_free_total INT;
  v_free_period TEXT;
  v_limit_enabled BOOLEAN;
  v_limit_action TEXT;
  v_sent_count INT := 0;
  v_effective_limit INT;
  v_effective_period TEXT;
  v_is_allowed BOOLEAN := true;
  v_user_type TEXT := 'free';
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text));

  SELECT subscription_status::text INTO v_sub_status FROM profiles WHERE id = p_user_id;

  SELECT free_daily_limit, free_monthly_limit, free_total_limit, free_limit_period, enabled, limit_action
  INTO v_free_daily, v_free_monthly, v_free_total, v_free_period, v_limit_enabled, v_limit_action
  FROM chat_limit_settings WHERE id = 'default';

  IF v_limit_enabled IS NULL THEN
    v_limit_enabled := true;
    v_limit_action := 'block_and_prompt';
    v_free_period := 'monthly';
    v_free_monthly := 50;
    v_free_daily := 10;
  END IF;

  IF NOT v_limit_enabled THEN
    RETURN jsonb_build_object(
      'allowed', true,
      'limit_enabled', false,
      'unlimited', true,
      'user_type', 'free'
    );
  END IF;

  IF v_sub_status = 'ACTIVE' THEN
    SELECT s.tier::text, s.created_at INTO v_sub_tier, v_sub_starts_at
    FROM subscriptions s
    WHERE s.user_id = p_user_id AND s.status = 'ACTIVE'
    ORDER BY s.created_at DESC LIMIT 1;

    IF v_sub_tier IS NOT NULL THEN
      SELECT sp.chat_message_limit, sp.chat_limit_period, sp.name_ar
      INTO v_plan_limit, v_plan_period, v_plan_name
      FROM subscription_plans sp WHERE sp.tier_key = v_sub_tier;

      v_user_type := 'subscribed';
    END IF;
  END IF;

  IF v_user_type = 'subscribed' THEN
    IF v_plan_limit IS NULL THEN
      SELECT COUNT(*) INTO v_sent_count FROM messages
      WHERE sender_id = p_user_id AND created_at >= date_trunc('month', CURRENT_DATE);

      RETURN jsonb_build_object(
        'allowed', true,
        'limit_enabled', true,
        'unlimited', true,
        'user_type', 'subscribed',
        'plan_name', v_plan_name,
        'effective_limit', NULL,
        'period', COALESCE(v_plan_period, 'monthly'),
        'sent_count', v_sent_count,
        'remaining', 999999,
        'limit_action', v_limit_action
      );
    ELSE
      v_effective_limit := v_plan_limit;
      v_effective_period := COALESCE(v_plan_period, 'monthly');

      IF v_effective_period = 'daily' THEN
        SELECT COUNT(*) INTO v_sent_count FROM messages
        WHERE sender_id = p_user_id AND created_at >= CURRENT_DATE;
      ELSIF v_effective_period = 'per_subscription' THEN
        SELECT COUNT(*) INTO v_sent_count FROM messages
        WHERE sender_id = p_user_id AND created_at >= COALESCE(v_sub_starts_at, date_trunc('month', CURRENT_DATE));
      ELSE
        SELECT COUNT(*) INTO v_sent_count FROM messages
        WHERE sender_id = p_user_id AND created_at >= date_trunc('month', CURRENT_DATE);
      END IF;

      v_is_allowed := (v_sent_count < v_effective_limit);

      RETURN jsonb_build_object(
        'allowed', v_is_allowed,
        'limit_enabled', true,
        'unlimited', false,
        'user_type', 'subscribed',
        'plan_name', v_plan_name,
        'effective_limit', v_effective_limit,
        'period', v_effective_period,
        'sent_count', v_sent_count,
        'remaining', GREATEST(0, v_effective_limit - v_sent_count),
        'limit_action', v_limit_action
      );
    END IF;
  ELSE
    v_effective_period := COALESCE(v_free_period, 'monthly');

    IF v_effective_period = 'daily' THEN
      v_effective_limit := COALESCE(v_free_daily, 10);
      SELECT COUNT(*) INTO v_sent_count FROM messages
      WHERE sender_id = p_user_id AND created_at >= CURRENT_DATE;
    ELSIF v_effective_period = 'total' THEN
      v_effective_limit := COALESCE(v_free_total, 50);
      SELECT COUNT(*) INTO v_sent_count FROM messages
      WHERE sender_id = p_user_id;
    ELSE
      v_effective_limit := COALESCE(v_free_monthly, 50);
      SELECT COUNT(*) INTO v_sent_count FROM messages
      WHERE sender_id = p_user_id AND created_at >= date_trunc('month', CURRENT_DATE);
    END IF;

    v_is_allowed := (v_sent_count < v_effective_limit);

    RETURN jsonb_build_object(
      'allowed', v_is_allowed,
      'limit_enabled', true,
      'unlimited', false,
      'user_type', 'free',
      'plan_name', 'مستخدم مجاني',
      'effective_limit', v_effective_limit,
      'period', v_effective_period,
      'sent_count', v_sent_count,
      'remaining', GREATEST(0, v_effective_limit - v_sent_count),
      'limit_action', v_limit_action
    );
  END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. TRIGGER: Enforce Moderation and Limits on Backend Before Insert
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_message_security_and_limits()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mod_result JSONB;
  v_limit_result JSONB;
BEGIN
  -- 1. CHAT MODERATION CHECK (Runs FIRST)
  v_mod_result := check_chat_message_moderation(NEW.content, NEW.sender_id, NEW.conversation_id);
  IF (v_mod_result->>'allowed')::boolean = false THEN
    RAISE EXCEPTION 'CHAT_MODERATION_VIOLATION: %', v_mod_result->>'reason';
  END IF;

  -- 2. MESSAGE LIMIT CHECK (Runs SECOND)
  v_limit_result := check_user_message_limit(NEW.sender_id);
  IF (v_limit_result->>'limit_enabled')::boolean = true
     AND (v_limit_result->>'allowed')::boolean = false
     AND (v_limit_result->>'limit_action') IN ('block_and_prompt', 'block_only') THEN
    RAISE EXCEPTION 'CHAT_LIMIT_EXCEEDED: لقد استنفدت الحد الأقصى للرسائل المسموح بها (%/%). يرجى الاشتراك أو ترقية باقتك للاستمرار في المراسلة.',
      v_limit_result->>'sent_count',
      v_limit_result->>'effective_limit';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_message_limit ON messages;
DROP TRIGGER IF EXISTS trg_enforce_message_security_and_limits ON messages;

CREATE TRIGGER trg_enforce_message_security_and_limits
BEFORE INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION enforce_message_security_and_limits();

-- ----------------------------------------------------------------------------
-- 9. RPC: Extended Dashboard Statistics
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_get_extended_dashboard_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_users INT;
  v_verified_users INT;
  v_active_subs INT;
  v_pending_reports INT;
  v_open_support INT;
  v_open_alerts INT;
  v_total_revenue NUMERIC;
BEGIN
  -- Verify admin privileges
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: admin access required';
  END IF;

  SELECT COUNT(*) INTO v_total_users FROM profiles;
  SELECT COUNT(*) INTO v_verified_users FROM profiles WHERE verification_status = 'VERIFIED';
  SELECT COUNT(*) INTO v_active_subs FROM subscriptions WHERE status = 'ACTIVE';
  SELECT COUNT(*) INTO v_pending_reports FROM user_reports WHERE status = 'PENDING';
  SELECT COUNT(*) INTO v_open_support FROM support_messages WHERE status = 'open';
  SELECT COUNT(*) INTO v_open_alerts FROM admin_alerts WHERE status = 'new';
  SELECT COALESCE(SUM(amount_egp), 0) INTO v_total_revenue FROM subscriptions WHERE status = 'ACTIVE';

  RETURN jsonb_build_object(
    'total_users', v_total_users,
    'verified_users', v_verified_users,
    'active_subscriptions', v_active_subs,
    'pending_reports', v_pending_reports,
    'open_support_messages', v_open_support,
    'open_alerts', v_open_alerts,
    'total_revenue', v_total_revenue
  );
END;
$$;

