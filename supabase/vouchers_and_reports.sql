-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- SCRIPT: Voucher System & User Reporting Migration
-- DESCRIPTION: Tables, RPCs, and RLS policies for offline voucher redemption
--              and safety reporting system.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. VOUCHER CODES TABLE
-- Codes issued upon offline payment (InstaPay, Vodafone Cash, Fawry, etc.)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS voucher_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  tier subscription_plan_tier NOT NULL DEFAULT 'MONTHLY_200',
  duration_days INT NOT NULL DEFAULT 30,
  amount_egp NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  is_used BOOLEAN NOT NULL DEFAULT false,
  used_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Case-insensitive unique index & fast lookup indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_voucher_codes_code_upper ON voucher_codes (UPPER(code));
CREATE INDEX IF NOT EXISTS idx_voucher_codes_is_used ON voucher_codes(is_used);
CREATE INDEX IF NOT EXISTS idx_voucher_codes_used_by ON voucher_codes(used_by);

-- Row Level Security
ALTER TABLE voucher_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "voucher_codes_select_redeemed" ON voucher_codes;
CREATE POLICY "voucher_codes_select_redeemed"
ON voucher_codes FOR SELECT
TO authenticated
USING (auth.uid() = used_by);

-- Direct client updates/inserts disabled for security; redemption must use RPC.

-- ----------------------------------------------------------------------------
-- 2. RPC: redeem_voucher_code
-- Atomic redemption with pessimistic row lock (FOR UPDATE), validation,
-- subscription generation, and profile status upgrade.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION redeem_voucher_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_norm_code TEXT;
  v_voucher RECORD;
  v_current_ends_at TIMESTAMPTZ;
  v_starts_at TIMESTAMPTZ;
  v_ends_at TIMESTAMPTZ;
  v_sub_id UUID;
BEGIN
  -- 1. Verify caller authentication
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'يجب تسجيل الدخول أولاً لتفعيل كود القسيمة'
    );
  END IF;

  -- 2. Normalize code input
  v_norm_code := UPPER(TRIM(COALESCE(p_code, '')));
  IF v_norm_code = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'يرجى إدخال كود القسيمة'
    );
  END IF;

  -- 3. Lock and fetch voucher record
  SELECT * INTO v_voucher
  FROM voucher_codes
  WHERE UPPER(code) = v_norm_code
  FOR UPDATE;

  -- 4. Validations
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'كود القسيمة غير صالح أو غير موجود'
    );
  END IF;

  IF v_voucher.is_used THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'تم استخدام كود القسيمة هذا من قبل'
    );
  END IF;

  IF v_voucher.expires_at IS NOT NULL AND v_voucher.expires_at < now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'انتهت صلاحية كود القسيمة هذا'
    );
  END IF;

  -- 5. Calculate subscription duration (extend existing if active)
  SELECT ends_at INTO v_current_ends_at
  FROM subscriptions
  WHERE user_id = v_user_id AND status = 'ACTIVE' AND ends_at > now()
  ORDER BY ends_at DESC
  LIMIT 1;

  IF v_current_ends_at IS NOT NULL THEN
    v_starts_at := v_current_ends_at;
  ELSE
    v_starts_at := now();
  END IF;

  v_ends_at := v_starts_at + (v_voucher.duration_days || ' days')::INTERVAL;

  -- 6. Mark voucher as used
  UPDATE voucher_codes
  SET is_used = true,
      used_by = v_user_id,
      used_at = now()
  WHERE id = v_voucher.id;

  -- 7. Insert subscription history record
  INSERT INTO subscriptions (
    user_id,
    tier,
    amount_egp,
    status,
    starts_at,
    ends_at,
    payment_reference,
    created_at
  ) VALUES (
    v_user_id,
    v_voucher.tier,
    v_voucher.amount_egp,
    'ACTIVE',
    v_starts_at,
    v_ends_at,
    'VOUCHER:' || v_voucher.code,
    now()
  ) RETURNING id INTO v_sub_id;

  -- 8. Update user profile to active
  UPDATE profiles
  SET subscription_status = 'ACTIVE',
      updated_at = now()
  WHERE id = v_user_id;

  -- 9. Return success response
  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تفعيل الاشتراك بنجاح!',
    'subscription_id', v_sub_id,
    'tier', v_voucher.tier,
    'duration_days', v_voucher.duration_days,
    'starts_at', v_starts_at,
    'ends_at', v_ends_at
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. USER REPORTS TABLE
-- User safety and reporting inappropriate accounts or behavior.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reported_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT NOT NULL DEFAULT 'PENDING',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID,
  CONSTRAINT chk_reporter_differs CHECK (reporter_id <> reported_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_reports_reporter ON user_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_reported ON user_reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_status ON user_reports(status);
CREATE INDEX IF NOT EXISTS idx_user_reports_created ON user_reports(created_at DESC);

-- Row Level Security
ALTER TABLE user_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_reports_insert_own" ON user_reports;
CREATE POLICY "user_reports_insert_own"
ON user_reports FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "user_reports_select_own" ON user_reports;
CREATE POLICY "user_reports_select_own"
ON user_reports FOR SELECT
TO authenticated
USING (auth.uid() = reporter_id);

-- ----------------------------------------------------------------------------
-- 4. RPC: submit_user_report
-- Submits a report and optionally blocks the user atomically.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION submit_user_report(
  p_reported_user_id UUID,
  p_reason TEXT,
  p_details TEXT DEFAULT NULL,
  p_block_user BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reporter_id UUID := auth.uid();
  v_report_id UUID;
  v_block_res JSONB;
BEGIN
  IF v_reporter_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'يجب تسجيل الدخول لإرسال البلاغ'
    );
  END IF;

  IF v_reporter_id = p_reported_user_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'لا يمكنك الإبلاغ عن حسابك الخاص'
    );
  END IF;

  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'يرجى اختيار سبب البلاغ'
    );
  END IF;

  -- 1. Insert report record
  INSERT INTO user_reports (
    reporter_id,
    reported_user_id,
    reason,
    details,
    status
  ) VALUES (
    v_reporter_id,
    p_reported_user_id,
    TRIM(p_reason),
    NULLIF(TRIM(p_details), ''),
    'PENDING'
  ) RETURNING id INTO v_report_id;

  -- 2. Optional user blocking
  IF p_block_user THEN
    BEGIN
      PERFORM block_user(p_reported_user_id, 'Blocked during report: ' || p_reason);
    EXCEPTION WHEN OTHERS THEN
      -- If block_user fails or already blocked, ignore to ensure report persists
      NULL;
    END BEGIN;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم استلام بلاغك وسيقوم فريق الإدارة بمراجعته فوراً',
    'report_id', v_report_id
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. SEED VOUCHER CODES (For production testing & administrative issuance)
-- ----------------------------------------------------------------------------
INSERT INTO voucher_codes (code, tier, duration_days, amount_egp, notes)
VALUES
  ('VIP-GOLD-30D', 'MONTHLY_200', 30, 200.00, 'اشتراك شهري تجريبي - كود الإدارة'),
  ('VIP-PLAT-90D', 'QUARTERLY_500', 90, 500.00, 'اشتراك ربع سنوي - كود الإدارة'),
  ('VIP-VIP-180D', 'SEMI_ANNUAL_900', 180, 900.00, 'اشتراك نصف سنوي - كود الإدارة'),
  ('VIP-ANNUAL-365', 'ANNUAL_1500', 365, 1500.00, 'اشتراك سنوي كامل - كود الإدارة'),
  ('VIP-BUNDLE-30D', 'BUNDLE_FB_1000', 30, 1000.00, 'باقة إعلان فيسبوك واشتراك - كود الإدارة'),
  ('PROMO-FREE-7D', 'MONTHLY_200', 7, 0.00, 'قسيمة ترويجية مجانية 7 أيام'),
  ('PROMO-WELCOME-30D', 'MONTHLY_200', 30, 0.00, 'قسيمة ترحيبية مجانية شهر كامل')
ON CONFLICT (code) DO NOTHING;
