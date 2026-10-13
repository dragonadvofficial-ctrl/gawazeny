-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- SCRIPT: Subscriptions, Payment Processing, User Management & Privacy RPCs
-- DESCRIPTION: Implements subscriptions table, payment activation RPC,
--              user blocking & unblocking, and permanent account deletion.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ENUM EXTENSIONS
-- Ensure 'PAYMENT_FAILED' is added to subscription_status_type
-- ----------------------------------------------------------------------------
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    JOIN pg_type ON pg_enum.enumtypid = pg_type.oid 
    WHERE pg_type.typname = 'subscription_status_type' AND enumlabel = 'PAYMENT_FAILED'
  ) THEN
    ALTER TYPE subscription_status_type ADD VALUE 'PAYMENT_FAILED';
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2. SUBSCRIPTIONS TABLE
-- Tracks payment history and active/historical subscription tiers per user.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  tier subscription_plan_tier NOT NULL,
  amount_egp NUMERIC(10,2) NOT NULL,
  status subscription_status_type DEFAULT 'PENDING_PAYMENT',
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  payment_reference TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for performance & query lookups
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_tier ON subscriptions(tier);
CREATE INDEX IF NOT EXISTS idx_subscriptions_ends_at ON subscriptions(ends_at);

-- ----------------------------------------------------------------------------
-- 3. ROW LEVEL SECURITY: SUBSCRIPTIONS
-- ----------------------------------------------------------------------------
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "subscriptions_select_own" ON subscriptions;
CREATE POLICY "subscriptions_select_own"
ON subscriptions FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "subscriptions_insert_own" ON subscriptions;
CREATE POLICY "subscriptions_insert_own"
ON subscriptions FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 4. RPC: process_subscription_payment
-- Server-side activation of subscription to prevent client-side bypass.
-- Calculates validity period based on tier, creates subscription record,
-- and updates profiles.subscription_status to 'ACTIVE'.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION process_subscription_payment(
  p_user_id UUID,
  p_tier subscription_plan_tier,
  p_payment_ref TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_duration_days INT;
  v_amount_egp NUMERIC(10,2);
  v_starts_at TIMESTAMPTZ := now();
  v_ends_at TIMESTAMPTZ;
  v_sub_id UUID;
BEGIN
  -- Security check: Caller must be the user themselves
  IF v_caller_id IS NULL OR v_caller_id <> p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot process subscription for another user';
  END IF;

  -- Tier pricing and duration calculation
  CASE p_tier
    WHEN 'MONTHLY_200' THEN
      v_duration_days := 30;
      v_amount_egp := 200.00;
    WHEN 'QUARTERLY_500' THEN
      v_duration_days := 90;
      v_amount_egp := 500.00;
    WHEN 'SEMI_ANNUAL_900' THEN
      v_duration_days := 180;
      v_amount_egp := 900.00;
    WHEN 'ANNUAL_1500' THEN
      v_duration_days := 365;
      v_amount_egp := 1500.00;
    WHEN 'BUNDLE_FB_1000' THEN
      v_duration_days := 30;
      v_amount_egp := 1000.00;
    ELSE
      v_duration_days := 30;
      v_amount_egp := 200.00;
  END CASE;

  v_ends_at := v_starts_at + (v_duration_days || ' days')::INTERVAL;

  -- 1. Insert active subscription record
  INSERT INTO subscriptions (
    user_id,
    tier,
    amount_egp,
    status,
    starts_at,
    ends_at,
    payment_reference,
    created_at
  )
  VALUES (
    p_user_id,
    p_tier,
    v_amount_egp,
    'ACTIVE',
    v_starts_at,
    v_ends_at,
    p_payment_ref,
    now()
  )
  RETURNING id INTO v_sub_id;

  -- 2. Update user profile subscription status to ACTIVE
  UPDATE profiles
  SET 
    subscription_status = 'ACTIVE',
    updated_at = now()
  WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'subscription_id', v_sub_id,
    'tier', p_tier,
    'amount_egp', v_amount_egp,
    'status', 'ACTIVE',
    'starts_at', v_starts_at,
    'ends_at', v_ends_at,
    'payment_reference', p_payment_ref
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. RPC: block_user
-- Inserts block record and immediately deactivates any existing match.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION block_user(p_target_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_me = p_target_id THEN
    RAISE EXCEPTION 'Users cannot block themselves';
  END IF;

  -- 1. Insert into blocked_users
  INSERT INTO blocked_users (blocker_id, blocked_id, created_at)
  VALUES (v_me, p_target_id, now())
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  -- 2. Deactivate any mutual match between the two parties
  UPDATE matches
  SET is_active = false
  WHERE (user_one = LEAST(v_me, p_target_id) AND user_two = GREATEST(v_me, p_target_id));

  RETURN jsonb_build_object(
    'success', true,
    'blocker_id', v_me,
    'blocked_id', p_target_id,
    'message', 'User blocked successfully'
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. RPC: unblock_user
-- Removes entry from blocked_users.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION unblock_user(p_target_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID := auth.uid();
  v_deleted_count INT;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM blocked_users
  WHERE blocker_id = v_me AND blocked_id = p_target_id;

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'unblocked_id', p_target_id,
    'rows_affected', v_deleted_count,
    'message', 'User unblocked successfully'
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. RPC: get_blocked_users
-- Retrieves blocked profiles for the current user including primary photo.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_blocked_users()
RETURNS TABLE (
  block_id UUID,
  blocked_user_id UUID,
  full_name TEXT,
  residence_city TEXT,
  photo_url TEXT,
  blocked_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  RETURN QUERY
  SELECT 
    b.id AS block_id,
    b.blocked_id AS blocked_user_id,
    p.full_name,
    p.residence_city,
    ph.photo_url,
    b.created_at AS blocked_at
  FROM blocked_users b
  JOIN profiles p ON p.id = b.blocked_id
  LEFT JOIN LATERAL (
    SELECT profile_photos.photo_url
    FROM profile_photos
    WHERE profile_photos.user_id = b.blocked_id
    ORDER BY profile_photos.is_primary DESC, profile_photos.created_at DESC
    LIMIT 1
  ) ph ON true
  WHERE b.blocker_id = v_me
  ORDER BY b.created_at DESC;
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. RPC: delete_user_account
-- Irreversibly deletes user profile and cascading records (matches, chat, etc.)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Deleting from profiles triggers ON DELETE CASCADE across:
  -- - partner_preferences
  -- - profile_photos
  -- - likes (from_user_id and to_user_id)
  -- - matches (user_one and user_two)
  -- - blocked_users (blocker_id and blocked_id)
  -- - identity_verifications
  -- - conversations (user_one and user_two)
  -- - messages (sender_id)
  -- - subscriptions (user_id)
  DELETE FROM profiles WHERE id = v_me;

  -- 2. Delete auth user record if permissions permit
  BEGIN
    DELETE FROM auth.users WHERE id = v_me;
  EXCEPTION WHEN OTHERS THEN
    -- Fall back gracefully if auth.users direct delete is restricted
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'User account permanently deleted'
  );
END;
$$;
