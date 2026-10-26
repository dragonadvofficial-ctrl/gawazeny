-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- SCRIPT:   Extended Admin Dashboard - Support, Alerts, Settings, Chat Limits
-- ============================================================================

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
  free_daily_limit INT NOT NULL DEFAULT 5,
  free_monthly_limit INT NOT NULL DEFAULT 50,
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

INSERT INTO chat_limit_settings (id) VALUES ('default') ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 6. ADMIN AUDIT LOG TABLE
-- Tracks all important admin actions with timestamps and values.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES admin_users(id),
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
-- 7. RPC: Check user message count for rate limiting
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
  v_plan_limit INT;
  v_plan_period TEXT;
  v_free_daily INT;
  v_free_monthly INT;
  v_limit_enabled BOOLEAN;
  v_limit_action TEXT;
  v_sent_today INT;
  v_sent_month INT;
  v_effective_limit INT;
  v_effective_period TEXT;
  v_is_allowed BOOLEAN;
BEGIN
  -- Get user subscription status
  SELECT subscription_status::text INTO v_sub_status FROM profiles WHERE id = p_user_id;

  -- Get global free limits
  SELECT free_daily_limit, free_monthly_limit, enabled, limit_action
  INTO v_free_daily, v_free_monthly, v_limit_enabled, v_limit_action
  FROM chat_limit_settings WHERE id = 'default';

  IF NOT v_limit_enabled THEN
    RETURN jsonb_build_object('allowed', true, 'limit_enabled', false);
  END IF;

  -- Get active subscription tier limit if subscribed
  IF v_sub_status = 'ACTIVE' THEN
    SELECT s.tier::text INTO v_sub_tier
    FROM subscriptions s
    WHERE s.user_id = p_user_id AND s.status = 'ACTIVE'
    ORDER BY s.created_at DESC LIMIT 1;

    IF v_sub_tier IS NOT NULL THEN
      SELECT sp.chat_message_limit, sp.chat_limit_period
      INTO v_plan_limit, v_plan_period
      FROM subscription_plans sp WHERE sp.tier_key = v_sub_tier;
    END IF;
  END IF;

  -- Count messages sent today and this month
  SELECT COUNT(*) INTO v_sent_today FROM messages
  WHERE sender_id = p_user_id AND created_at >= CURRENT_DATE;

  SELECT COUNT(*) INTO v_sent_month FROM messages
  WHERE sender_id = p_user_id AND created_at >= date_trunc('month', CURRENT_DATE);

  -- Determine effective limit
  IF v_sub_status = 'ACTIVE' AND v_plan_limit IS NULL THEN
    -- Unlimited for this plan
    RETURN jsonb_build_object(
      'allowed', true, 'limit_enabled', true, 'unlimited', true,
      'sent_today', v_sent_today, 'sent_month', v_sent_month
    );
  ELSIF v_sub_status = 'ACTIVE' AND v_plan_limit IS NOT NULL THEN
    v_effective_limit := v_plan_limit;
    v_effective_period := COALESCE(v_plan_period, 'monthly');
  ELSE
    -- Free user
    v_effective_limit := v_free_monthly;
    v_effective_period := 'monthly';
  END IF;

  IF v_effective_period = 'daily' THEN
    v_is_allowed := v_sent_today < COALESCE(v_effective_limit, v_free_daily);
  ELSE
    v_is_allowed := v_sent_month < v_effective_limit;
  END IF;

  RETURN jsonb_build_object(
    'allowed', v_is_allowed,
    'limit_enabled', true,
    'unlimited', false,
    'effective_limit', v_effective_limit,
    'period', v_effective_period,
    'sent_today', v_sent_today,
    'sent_month', v_sent_month,
    'remaining', GREATEST(0, v_effective_limit - CASE WHEN v_effective_period = 'daily' THEN v_sent_today ELSE v_sent_month END),
    'limit_action', v_limit_action
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. TRIGGER: Enforce chat limits on the Backend
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_message_limit_before_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit_result JSONB;
BEGIN
  v_limit_result := check_user_message_limit(NEW.sender_id);
  IF (v_limit_result->>'limit_enabled')::boolean = true
     AND (v_limit_result->>'allowed')::boolean = false
     AND (v_limit_result->>'limit_action') = 'block_and_prompt' THEN
    RAISE EXCEPTION 'CHAT_LIMIT_EXCEEDED: تم استنفاد الحد الأقصى المسموح به لرسائل المحادثة لخطة اشتراكك الحالية';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_message_limit ON messages;
CREATE TRIGGER trg_enforce_message_limit
BEFORE INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION enforce_message_limit_before_insert();

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
  SELECT COUNT(*) INTO v_pending_reports FROM reports WHERE status = 'PENDING';
  SELECT COUNT(*) INTO v_open_support FROM support_messages WHERE status = 'open';
  SELECT COUNT(*) INTO v_open_alerts FROM admin_alerts WHERE status = 'new';
  SELECT COALESCE(SUM(amount_paid), 0) INTO v_total_revenue FROM subscriptions WHERE status = 'ACTIVE';

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

