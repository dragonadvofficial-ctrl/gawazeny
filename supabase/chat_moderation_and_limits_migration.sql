-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- SCRIPT: Chat Moderation System & Dynamic Message Limits Migration
-- ============================================================================

-- Ensure is_admin helper exists
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE id = auth.uid()
  );
$$;

-- ----------------------------------------------------------------------------
-- 1. CHAT MODERATION SETTINGS TABLE
-- Admin-configurable settings for message moderation
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_moderation_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  block_phones BOOLEAN NOT NULL DEFAULT true,
  block_urls BOOLEAN NOT NULL DEFAULT true,
  block_social_media BOOLEAN NOT NULL DEFAULT true,
  custom_blocked_keywords TEXT[] DEFAULT '{}',
  limit_action TEXT NOT NULL DEFAULT 'block' CHECK (limit_action IN ('block', 'flag_only')),
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID
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

-- ----------------------------------------------------------------------------
-- 2. CHAT MODERATION VIOLATIONS LOG
-- Stores moderation attempts without storing unnecessary raw private sensitive text
-- ----------------------------------------------------------------------------
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
CREATE INDEX IF NOT EXISTS idx_chat_violations_type ON chat_moderation_violations(violation_type);

-- ----------------------------------------------------------------------------
-- 3. ENHANCE CHAT LIMIT SETTINGS TABLE
-- Add support for configurable free reset period (daily, monthly, total)
-- ----------------------------------------------------------------------------
ALTER TABLE chat_limit_settings 
  ADD COLUMN IF NOT EXISTS free_total_limit INT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS free_limit_period TEXT DEFAULT 'monthly' CHECK (free_limit_period IN ('daily', 'monthly', 'total'));

-- Ensure subscription_plans has chat limits columns
ALTER TABLE subscription_plans
  ADD COLUMN IF NOT EXISTS chat_message_limit INT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS chat_limit_period TEXT DEFAULT 'monthly' CHECK (chat_limit_period IN ('daily', 'monthly', 'per_subscription'));

-- ----------------------------------------------------------------------------
-- 4. TEXT NORMALIZATION HELPER FUNCTION
-- Normalizes Arabic text, removes diacritics, unifies letters, converts numerals
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

  -- Replace Eastern Arabic numerals with Western Arabic numerals
  v_res := translate(v_res, '٠١٢٣٤٥٦٧٨٩', '0123456789');

  -- Replace Persian numerals
  v_res := translate(v_res, '۰۱۲۳۴۵۶۷۸۹', '0123456789');

  -- Remove Arabic Tashkeel (diacritics: Fatha, Damma, Kasra, Sukun, Tanween, Shadda)
  v_res := regexp_replace(v_res, '[\u064B-\u065F\u0670]', '', 'g');

  -- Remove Tatweel / Kashida
  v_res := regexp_replace(v_res, '\u0640', '', 'g');

  -- Remove zero-width characters and invisible joiners
  v_res := regexp_replace(v_res, '[\u200B-\u200F\uFEFF\u00AD]', '', 'g');

  -- Normalize Alef variations (أ, إ, آ, ٱ -> ا)
  v_res := translate(v_res, 'أإآٱ', 'اااا');

  -- Normalize Taa Marbuta (ة -> ه)
  v_res := translate(v_res, 'ة', 'ه');

  -- Normalize Yaa / Alef Maksura (ى -> ي)
  v_res := translate(v_res, 'ى', 'ي');

  RETURN v_res;
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. CHAT MODERATION CHECK FUNCTION
-- Inspects message content for phone numbers, external URLs, and social handles
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
  -- Load moderation settings
  SELECT block_phones, block_urls, block_social_media, custom_blocked_keywords, limit_action
  INTO v_settings
  FROM chat_moderation_settings
  WHERE id = 'default';

  IF v_settings IS NULL THEN
    -- Fallback default
    v_settings.block_phones := true;
    v_settings.block_urls := true;
    v_settings.block_social_media := true;
    v_settings.custom_blocked_keywords := '{}';
  END IF;

  v_clean := normalize_chat_text(p_content);

  -- --------------------------------------------------------------------------
  -- CHECK A: Custom Blocked Keywords
  -- --------------------------------------------------------------------------
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

  -- --------------------------------------------------------------------------
  -- CHECK B: Phone Numbers
  -- --------------------------------------------------------------------------
  IF v_violation_type IS NULL AND v_settings.block_phones THEN
    -- 1. Extract pure consecutive digits ignoring whitespace/dashes/brackets/dots between digits
    -- e.g. "0 1 0 1 2 3 4 5 6 7 8" or "010-1234-5678" or "+20 10 9988 7766"
    v_digits_only := regexp_replace(v_clean, '[^0-9]', '', 'g');

    -- Egyptian Mobile: 010, 011, 012, 015 (11 digits, or 12/13 with country code 20 / 0020 / +20)
    IF v_digits_only ~ '(20)?1[0125][0-9]{8}' THEN
      v_violation_type := 'PHONE_NUMBER';
      v_matched_pattern := 'رقم هاتف مصري محمول';
      v_rule_reason := 'مشاركة أرقام الهواتف غير مسموح بها داخل المحادثة حفاظاً على خصوصيتك وأمانك وفقاً لشروط الاستخدام.';
    
    -- Generic international phone pattern (7 to 15 digits in sequence or with international prefix)
    ELSIF v_clean ~ '(\+|00)[0-9]{1,4}[\s\-\.()]{0,3}[0-9]{3,}[\s\-\.()]{0,3}[0-9]{3,}'
          OR length(v_digits_only) >= 8 AND v_clean ~ '(^|\s|[^\w])([0-9][\s\-\.()]{0,2}){8,14}($|\s|[^\w])' THEN
      v_violation_type := 'PHONE_NUMBER';
      v_matched_pattern := 'رقم هاتف دولي';
      v_rule_reason := 'مشاركة أرقام الهواتف والتواصل الخارجي غير مسموح بها داخل المحادثة.';

    -- 2. Spelled-out phone numbers in Arabic (e.g. زيرو عشره / زيرو واحد صفر / صفر واحد صفر)
    ELSIF v_clean ~ '(زيرو|صفر)\s*(عشر[ةه]|واحد\s*صفر|واحد\s*[0-9]|[0-9]\s*[0-9])'
       OR v_clean ~ '(رقمي|نمرتي|موبايلي|فون|واتس)\s*(هو|:)?\s*([0-9]|زيرو|صفر|واحد)' THEN
      v_violation_type := 'PHONE_NUMBER';
      v_matched_pattern := 'رقم هاتف مكتوب بصيغة نصية';
      v_rule_reason := 'مشاركة أرقام الهواتف أو طلب التواصل الخارجي غير مسموح بها داخل المحادثة.';
    END IF;

    -- Also check sequence of multiple spelled digits
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

  -- --------------------------------------------------------------------------
  -- CHECK C: External Links & URLs
  -- --------------------------------------------------------------------------
  IF v_violation_type IS NULL AND v_settings.block_urls THEN
    -- Protocol links: http://, https://, ftp://
    IF v_clean ~ 'https?:\/\/[^\s]+' OR v_clean ~ 'ftp:\/\/[^\s]+' THEN
      v_violation_type := 'EXTERNAL_URL';
      v_matched_pattern := 'رابط ويب مباشر (URL)';
      v_rule_reason := 'إرسال الروابط والمواقع الخارجية غير مسموح به داخل المحادثة لحماية المستخدمين.';

    -- Domain prefixes: www., ftp.
    ELSIF v_clean ~ 'www\.[a-z0-9\-]+(\.[a-z]{2,})+' THEN
      v_violation_type := 'EXTERNAL_URL';
      v_matched_pattern := 'رابط موقع ويب (www)';
      v_rule_reason := 'إرسال الروابط والمواقع الخارجية غير مسموح به داخل المحادثة.';

    -- Common top-level domains without protocol (with or without spaces around dot: .com, .net, etc.)
    ELSIF v_clean ~ '[a-z0-9\-]+(\s*(\.|\(\.\)|\[\.\])\s*)(com|net|org|app|io|me|eg|co|ai|ly|gl|link|site|online|xyz|top|info|biz|tv|cc|to)($|\s|[^\w])'
       OR v_clean ~ '(t\.me|wa\.me|bit\.ly|tinyurl\.com|cutt\.ly|instagr\.am|fb\.com|fb\.me)\/[a-z0-9\-_]+'
       OR v_clean ~ '(دوت\s*كوم|دوت\s*نت|دوت\s*اورج|\s*dot\s*com|\s*dot\s*net)' THEN
      v_violation_type := 'EXTERNAL_URL';
      v_matched_pattern := 'اسم نطاق أو رابط مختصر';
      v_rule_reason := 'مشاركة الروابط الخارجية أو النطاقات غير مسموح بها داخل المحادثة.';
    END IF;
  END IF;

  -- --------------------------------------------------------------------------
  -- CHECK D: Social Media Accounts & Contact Exchange Intent
  -- --------------------------------------------------------------------------
  IF v_violation_type IS NULL AND v_settings.block_social_media THEN
    -- Handles with @ (e.g. @username)
    IF v_clean ~ '(^|\s)@[a-z0-9_\.]{3,30}($|\s)' THEN
      v_violation_type := 'SOCIAL_MEDIA';
      v_matched_pattern := 'اسم مستخدم خارجي (@handle)';
      v_rule_reason := 'مشاركة أسماء المستخدمين وحسابات التواصل غير مسموح بها داخل المحادثة.';

    -- Requests to exchange social media accounts in Egyptian and standard Arabic
    -- e.g. "ابعتلي أكاونت الفيسبوك", "ابعتلي الأكاونت بتاعك", "ابعتلي حسابك", "ابعتلي الإنستجرام", "ابعتلي الواتساب"
    ELSIF v_clean ~ '(ابعت|ابعتي|ابعتلي|ابعتيلي|هات|هاتي|اديني|عايز|عايزه|عاوز|عاوزه|نكمل|نتكلم|شات|كلمني|كلميني)\s*.*(اكاونت|حساب|فيسبوك|فيس|انستا|انستجرام|واتس|واتساب|تلي|تليجرام|تيليجرام|سناب|سنابشات|تيك\s*توك|فون|نمره|رقمك|رقمي|يوزرك|يوزر)'
       OR v_clean ~ '(اكاونت|حسابي|يوزري|صفحتي)\s*(علي|في|بتاعي)?\s*(الفيسبوك|الفيس|الانستا|الانستجرام|الواتس|الواتساب|التليجرام|السناب)'
       OR v_clean ~ '(نتكلم|نكلم|نكمل\s*كلام)\s*(بره|برة|فون|واتس|علي\s*الواتس|علي\s*الفيس|علي\s*الانستا)'
       OR v_clean ~ '(تواصل\s*خارجي|شات\s*بره|شات\s*برة)' THEN
      v_violation_type := 'SOCIAL_MEDIA';
      v_matched_pattern := 'طلب تبادل حسابات تواصل أو شات خارجي';
      v_rule_reason := 'طلب أو تبادل حسابات التواصل الاجتماعي (فيسبوك، انستجرام، واتساب، تليجرام، وغيرها) غير مسموح به؛ لضمان جدية وأمان التعارف داخل التطبيق.';
    END IF;
  END IF;

  -- --------------------------------------------------------------------------
  -- If violation found, log to violations table and return disallowed result
  -- --------------------------------------------------------------------------
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
-- 6. RPC: check_user_message_limit WITH CONCURRENCY ADVISORY LOCK
-- Enforces message limits dynamically based on subscription plans & admin settings
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
  -- Obtain advisory transaction lock per user to avoid concurrency race condition bypass
  PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text));

  -- Get user subscription status
  SELECT subscription_status::text INTO v_sub_status FROM profiles WHERE id = p_user_id;

  -- Get global limit settings
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

  -- Check if user has an ACTIVE subscription
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

  -- --------------------------------------------------------------------------
  -- CASE 1: Subscribed user
  -- --------------------------------------------------------------------------
  IF v_user_type = 'subscribed' THEN
    IF v_plan_limit IS NULL THEN
      -- Unlimited messages for this paid plan
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
      ELSE -- monthly
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

  -- --------------------------------------------------------------------------
  -- CASE 2: Free / Non-subscribed user
  -- --------------------------------------------------------------------------
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
    ELSE -- monthly
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
-- 7. COMBINED BEFORE INSERT TRIGGER ON MESSAGES
-- Enforces:
--   1. Moderation rules (Phone, URL, Social Media) -> aborts if violated
--   2. Rate Limits (Free/Paid quotas) -> aborts if quota reached
-- Rejected messages NEVER get inserted and therefore NEVER count towards limits!
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
-- 8. EXTENDED DASHBOARD RPC TO INCLUDE MODERATION STATS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_get_chat_moderation_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_violations INT;
  v_phone_violations INT;
  v_url_violations INT;
  v_social_violations INT;
  v_today_violations INT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: admin access required';
  END IF;

  SELECT COUNT(*) INTO v_total_violations FROM chat_moderation_violations;
  SELECT COUNT(*) INTO v_phone_violations FROM chat_moderation_violations WHERE violation_type = 'PHONE_NUMBER';
  SELECT COUNT(*) INTO v_url_violations FROM chat_moderation_violations WHERE violation_type = 'EXTERNAL_URL';
  SELECT COUNT(*) INTO v_social_violations FROM chat_moderation_violations WHERE violation_type = 'SOCIAL_MEDIA';
  SELECT COUNT(*) INTO v_today_violations FROM chat_moderation_violations WHERE created_at >= CURRENT_DATE;

  RETURN jsonb_build_object(
    'total_violations', v_total_violations,
    'phone_violations', v_phone_violations,
    'url_violations', v_url_violations,
    'social_violations', v_social_violations,
    'today_violations', v_today_violations
  );
END;
$$;
