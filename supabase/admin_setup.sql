-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- SCRIPT: Admin Dashboard Database Setup
-- DESCRIPTION: Admin users table, RLS policies for admin access, and
--              admin-specific RPC functions for moderation actions.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ADMIN USERS TABLE
-- Stores designated admin accounts. Only users listed here can access
-- the admin dashboard.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT 'مشرف',
  role TEXT NOT NULL DEFAULT 'admin',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

-- Admins can only read their own record (for auth verification)
DROP POLICY IF EXISTS "admin_users_select_own" ON admin_users;
CREATE POLICY "admin_users_select_own"
ON admin_users FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- 2. HELPER: is_admin() function
-- Returns true if the current authenticated user is in admin_users table.
-- Used by RLS policies and admin RPCs.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM admin_users WHERE id = auth.uid()
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. ADMIN RLS POLICIES
-- Allow admins to read all data needed for the dashboard.
-- ----------------------------------------------------------------------------

-- Admin can SELECT all user_reports
DROP POLICY IF EXISTS "admin_select_all_reports" ON user_reports;
CREATE POLICY "admin_select_all_reports"
ON user_reports FOR SELECT
TO authenticated
USING (is_admin());

-- Admin can UPDATE user_reports (to resolve them)
DROP POLICY IF EXISTS "admin_update_reports" ON user_reports;
CREATE POLICY "admin_update_reports"
ON user_reports FOR UPDATE
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- Admin can SELECT all voucher_codes
DROP POLICY IF EXISTS "admin_select_all_vouchers" ON voucher_codes;
CREATE POLICY "admin_select_all_vouchers"
ON voucher_codes FOR SELECT
TO authenticated
USING (is_admin());

-- Admin can INSERT voucher_codes
DROP POLICY IF EXISTS "admin_insert_vouchers" ON voucher_codes;
CREATE POLICY "admin_insert_vouchers"
ON voucher_codes FOR INSERT
TO authenticated
WITH CHECK (is_admin());

-- Admin can UPDATE voucher_codes
DROP POLICY IF EXISTS "admin_update_vouchers" ON voucher_codes;
CREATE POLICY "admin_update_vouchers"
ON voucher_codes FOR UPDATE
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- Admin can SELECT all identity_verifications
DROP POLICY IF EXISTS "admin_select_all_verifications" ON identity_verifications;
CREATE POLICY "admin_select_all_verifications"
ON identity_verifications FOR SELECT
TO authenticated
USING (is_admin());

-- Admin can UPDATE identity_verifications (approve/reject)
DROP POLICY IF EXISTS "admin_update_verifications" ON identity_verifications;
CREATE POLICY "admin_update_verifications"
ON identity_verifications FOR UPDATE
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- Admin can SELECT all profiles
DROP POLICY IF EXISTS "admin_select_all_profiles" ON profiles;
CREATE POLICY "admin_select_all_profiles"
ON profiles FOR SELECT
TO authenticated
USING (is_admin());

-- Admin can UPDATE all profiles (for banning/modifying status)
DROP POLICY IF EXISTS "admin_update_all_profiles" ON profiles;
CREATE POLICY "admin_update_all_profiles"
ON profiles FOR UPDATE
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- Admin can SELECT all profile_photos
DROP POLICY IF EXISTS "admin_select_all_photos" ON profile_photos;
CREATE POLICY "admin_select_all_photos"
ON profile_photos FOR SELECT
TO authenticated
USING (is_admin());

-- Admin can view identity documents in storage
DROP POLICY IF EXISTS "Admin can view all identity documents" ON storage.objects;
CREATE POLICY "Admin can view all identity documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'identity-documents'
  AND is_admin()
);

-- ----------------------------------------------------------------------------
-- 4. ADMIN RPC: admin_block_user
-- Inserts a system block and optionally updates report status.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_block_user(
  p_target_user_id UUID,
  p_report_id UUID DEFAULT NULL,
  p_reason TEXT DEFAULT 'تم الحظر بواسطة الإدارة'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
BEGIN
  IF NOT is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح');
  END IF;

  -- Insert system block (admin blocks the user on behalf of system)
  INSERT INTO blocked_users (blocker_id, blocked_id)
  VALUES (v_admin_id, p_target_user_id)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  -- Mark the user profile as banned (using subscription_status = 'CANCELLED')
  UPDATE profiles
  SET subscription_status = 'CANCELLED',
      bio = '[محظور] ' || COALESCE(bio, ''),
      updated_at = now()
  WHERE id = p_target_user_id;

  -- Resolve the report if provided
  IF p_report_id IS NOT NULL THEN
    UPDATE user_reports
    SET status = 'RESOLVED_BLOCKED',
        resolved_at = now(),
        resolved_by = v_admin_id,
        updated_at = now()
    WHERE id = p_report_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم حظر المستخدم بنجاح'
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. ADMIN RPC: admin_delete_account
-- Soft-deletes a user account by clearing their profile data.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_delete_account(
  p_target_user_id UUID,
  p_report_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
BEGIN
  IF NOT is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح');
  END IF;

  -- Clear profile data (soft delete)
  UPDATE profiles
  SET full_name = '[حساب محذوف]',
      bio = NULL,
      job_title = NULL,
      subscription_status = 'CANCELLED',
      verification_status = 'FAILED',
      updated_at = now()
  WHERE id = p_target_user_id;

  -- Remove all profile photos
  DELETE FROM profile_photos WHERE user_id = p_target_user_id;

  -- Deactivate all matches
  UPDATE matches
  SET is_active = false
  WHERE user_one = p_target_user_id OR user_two = p_target_user_id;

  -- Resolve the report if provided
  IF p_report_id IS NOT NULL THEN
    UPDATE user_reports
    SET status = 'RESOLVED_DELETED',
        resolved_at = now(),
        resolved_by = v_admin_id,
        updated_at = now()
    WHERE id = p_report_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم حذف الحساب بنجاح'
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. ADMIN RPC: admin_dismiss_report
-- Marks a report as dismissed without action.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_dismiss_report(p_report_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
BEGIN
  IF NOT is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح');
  END IF;

  UPDATE user_reports
  SET status = 'DISMISSED',
      resolved_at = now(),
      resolved_by = v_admin_id,
      updated_at = now()
  WHERE id = p_report_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'البلاغ غير موجود');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم رفض البلاغ'
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. ADMIN RPC: admin_review_verification
-- Approves or rejects an identity verification request.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_review_verification(
  p_verification_id UUID,
  p_action TEXT,  -- 'APPROVE' or 'REJECT'
  p_rejection_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_verification RECORD;
  v_new_status verification_status_type;
BEGIN
  IF NOT is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح للقيام بهذه العملية');
  END IF;

  SELECT * INTO v_verification
  FROM identity_verifications
  WHERE id = p_verification_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'طلب التحقق غير موجود');
  END IF;

  IF UPPER(p_action) IN ('APPROVE', 'APPROVED', 'VERIFIED') THEN
    v_new_status := 'VERIFIED'::verification_status_type;
  ELSIF UPPER(p_action) IN ('REJECT', 'REJECTED', 'FAILED') THEN
    v_new_status := 'FAILED'::verification_status_type;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'إجراء غير صالح');
  END IF;

  -- Update verification record
  UPDATE identity_verifications
  SET status = v_new_status,
      rejection_reason = CASE WHEN v_new_status = 'FAILED'::verification_status_type THEN COALESCE(p_rejection_reason, 'تم رفض طلب التوثيق من قِبل الإدارة') ELSE NULL END
  WHERE id = p_verification_id;

  -- Update profile verification status
  UPDATE profiles
  SET verification_status = v_new_status,
      updated_at = now()
  WHERE id = v_verification.user_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', v_new_status::TEXT,
    'message', CASE WHEN v_new_status = 'VERIFIED'::verification_status_type
      THEN 'تم قبول وتوثيق الحساب بنجاح'
      ELSE 'تم رفض طلب التوثيق'
    END
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. ADMIN RPC: admin_generate_vouchers
-- Batch-generates voucher codes for a specific plan tier.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_generate_vouchers(
  p_tier subscription_plan_tier,
  p_count INT,
  p_duration_days INT,
  p_amount_egp NUMERIC,
  p_prefix TEXT DEFAULT 'GWZ',
  p_expires_at TIMESTAMPTZ DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_generated_codes TEXT[] := '{}';
  v_code TEXT;
  v_i INT;
BEGIN
  IF NOT is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح');
  END IF;

  IF p_count < 1 OR p_count > 100 THEN
    RETURN jsonb_build_object('success', false, 'error', 'العدد يجب أن يكون بين 1 و 100');
  END IF;

  FOR v_i IN 1..p_count LOOP
    v_code := UPPER(p_prefix) || '-' || SUBSTRING(gen_random_uuid()::TEXT FROM 1 FOR 8);

    INSERT INTO voucher_codes (code, tier, duration_days, amount_egp, expires_at, notes)
    VALUES (v_code, p_tier, p_duration_days, p_amount_egp, p_expires_at,
            COALESCE(p_notes, 'تم إنشاؤه بواسطة لوحة الإدارة'));

    v_generated_codes := array_append(v_generated_codes, v_code);
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم إنشاء ' || p_count || ' كود بنجاح',
    'codes', to_jsonb(v_generated_codes)
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. ADMIN DASHBOARD STATS RPC
-- Returns aggregate statistics for the dashboard overview.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_get_dashboard_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stats JSONB;
BEGIN
  IF NOT is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح');
  END IF;

  SELECT jsonb_build_object(
    'success', true,
    'total_users', (SELECT COUNT(*) FROM profiles),
    'male_users', (SELECT COUNT(*) FROM profiles WHERE gender = 'MALE'),
    'female_users', (SELECT COUNT(*) FROM profiles WHERE gender = 'FEMALE'),
    'verified_users', (SELECT COUNT(*) FROM profiles WHERE verification_status = 'VERIFIED'),
    'active_subscribers', (SELECT COUNT(*) FROM profiles WHERE subscription_status = 'ACTIVE'),
    'pending_reports', (SELECT COUNT(*) FROM user_reports WHERE status = 'PENDING'),
    'pending_verifications', (SELECT COUNT(*) FROM identity_verifications WHERE status IN ('PENDING', 'MANUAL_REVIEW')),
    'total_vouchers', (SELECT COUNT(*) FROM voucher_codes),
    'used_vouchers', (SELECT COUNT(*) FROM voucher_codes WHERE is_used = true),
    'unused_vouchers', (SELECT COUNT(*) FROM voucher_codes WHERE is_used = false),
    'total_matches', (SELECT COUNT(*) FROM matches WHERE is_active = true),
    'users_today', (SELECT COUNT(*) FROM profiles WHERE created_at >= CURRENT_DATE),
    'reports_today', (SELECT COUNT(*) FROM user_reports WHERE created_at >= CURRENT_DATE)
  ) INTO v_stats;

  RETURN v_stats;
END;
$$;
