-- ============================================================================
-- GAWAZENY SECURITY HARDENING MIGRATION
-- Migration Timestamp: 20261029231500
-- Consolidated, Idempotent Security Hardening Script
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. ADMIN & SUPERUSER ROLE HELPERS (H7)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_superuser()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE id = auth.uid()
      AND UPPER(COALESCE(role, '')) IN ('SUPER_ADMIN', 'SUPERUSER')
  );
$$;

-- ----------------------------------------------------------------------------
-- 1. C1: BLOCK SELF-VERIFICATION & SELF-UPGRADE VIA PROFILES UPDATE
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_profile_sensitive_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- service_role / direct DB connections have no auth.uid(): allow
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- trusted RPCs set this flag with set_config(..., true) (transaction-local)
  IF current_setting('app.bypass_profile_guard', true) = 'on' THEN
    RETURN NEW;
  END IF;

  -- Superusers and admins can update if needed
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  -- Normal users cannot self-promote, self-verify, change id, or modify timestamps
  NEW.id := OLD.id;
  NEW.verification_status := OLD.verification_status;
  NEW.subscription_status := OLD.subscription_status;
  NEW.created_at := OLD.created_at;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profile_sensitive_columns ON public.profiles;
CREATE TRIGGER trg_protect_profile_sensitive_columns
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_sensitive_columns();

-- Ensure profiles update policy allows users to update own non-sensitive columns
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id OR public.is_admin())
WITH CHECK (auth.uid() = id OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 2. C2: SECURE submit_identity_verification (FORCES PENDING & STRIPS p_status)
-- ----------------------------------------------------------------------------
-- Drop vulnerable overload signatures that accept p_status from clients
DROP FUNCTION IF EXISTS public.submit_identity_verification(text, text, text, date, numeric, jsonb, verification_status_type);
DROP FUNCTION IF EXISTS public.submit_identity_verification(text, text, text, date, numeric, boolean, verification_status_type);

CREATE OR REPLACE FUNCTION public.submit_identity_verification(
  p_id_url TEXT,
  p_selfie_url TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_record_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not allowed' USING ERRCODE = '42501';
  END IF;

  -- Validate inputs: must not be empty
  IF p_id_url IS NULL OR length(trim(p_id_url)) = 0 
     OR p_selfie_url IS NULL OR length(trim(p_selfie_url)) = 0 THEN
    RAISE EXCEPTION 'Both ID card and selfie image URLs are required';
  END IF;

  -- Set transaction-local bypass flag so the trigger allows updating profiles.verification_status
  PERFORM set_config('app.bypass_profile_guard', 'on', true);

  -- Upsert verification record forced to PENDING status
  INSERT INTO public.identity_verifications (
    user_id,
    id_card_image_url,
    selfie_image_url,
    status,
    rejection_reason,
    created_at
  )
  VALUES (
    v_user_id,
    p_id_url,
    p_selfie_url,
    'PENDING'::verification_status_type,
    NULL,
    now()
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    id_card_image_url = EXCLUDED.id_card_image_url,
    selfie_image_url = EXCLUDED.selfie_image_url,
    status = 'PENDING'::verification_status_type,
    rejection_reason = NULL,
    created_at = now()
  RETURNING id INTO v_record_id;

  -- Sync verification status to PENDING on profiles
  UPDATE public.profiles
  SET verification_status = 'PENDING'::verification_status_type,
      updated_at = now()
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'record_id', v_record_id,
    'status', 'PENDING',
    'message', 'تم استلام طلب توثيق حسابك بنجاح. سيتم مراجعة طلبك بواسطة الإدارة خلال دقائق.'
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. C3: FIX IDOR IN LIKES AND MATCHES RPCS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_mutual_matches(p_user_id UUID)
RETURNS TABLE (
  match_id UUID,
  partner_id UUID,
  full_name TEXT,
  gender gender_type,
  age INT,
  residence_city TEXT,
  job_title TEXT,
  marital_status marital_status_type,
  verification_status verification_status_type,
  photo_url TEXT,
  matched_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR (p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin()) THEN
    RAISE EXCEPTION 'not allowed' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT 
    m.id AS match_id,
    p.id AS partner_id,
    p.full_name,
    p.gender,
    p.age,
    p.residence_city,
    p.job_title,
    p.marital_status,
    p.verification_status,
    (
      SELECT pp.photo_url 
      FROM profile_photos pp 
      WHERE pp.user_id = p.id 
      ORDER BY pp.is_primary DESC, pp.created_at DESC 
      LIMIT 1
    ) AS photo_url,
    m.created_at AS matched_at
  FROM matches m
  JOIN profiles p ON p.id = (CASE WHEN m.user_one = p_user_id THEN m.user_two ELSE m.user_one END)
  WHERE (m.user_one = p_user_id OR m.user_two = p_user_id)
    AND m.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM blocked_users bu
      WHERE (bu.blocker_id = p_user_id AND bu.blocked_id = p.id)
         OR (bu.blocker_id = p.id AND bu.blocked_id = p_user_id)
    )
  ORDER BY m.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_received_likes(p_user_id UUID)
RETURNS TABLE (
  like_id UUID,
  sender_id UUID,
  full_name TEXT,
  gender gender_type,
  age INT,
  residence_city TEXT,
  job_title TEXT,
  marital_status marital_status_type,
  verification_status verification_status_type,
  photo_url TEXT,
  liked_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR (p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin()) THEN
    RAISE EXCEPTION 'not allowed' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT 
    l.id AS like_id,
    p.id AS sender_id,
    p.full_name,
    p.gender,
    p.age,
    p.residence_city,
    p.job_title,
    p.marital_status,
    p.verification_status,
    (
      SELECT pp.photo_url 
      FROM profile_photos pp 
      WHERE pp.user_id = p.id 
      ORDER BY pp.is_primary DESC, pp.created_at DESC 
      LIMIT 1
    ) AS photo_url,
    l.created_at AS liked_at
  FROM likes l
  JOIN profiles p ON p.id = l.from_user_id
  WHERE l.to_user_id = p_user_id
    AND NOT EXISTS (
      SELECT 1 FROM matches m
      WHERE (m.user_one = LEAST(p_user_id, p.id) AND m.user_two = GREATEST(p_user_id, p.id))
        AND m.is_active = true
    )
    AND NOT EXISTS (
      SELECT 1 FROM blocked_users bu
      WHERE (bu.blocker_id = p_user_id AND bu.blocked_id = p.id)
         OR (bu.blocker_id = p.id AND bu.blocked_id = p_user_id)
    )
  ORDER BY l.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_sent_likes(p_user_id UUID)
RETURNS TABLE (
  like_id UUID,
  target_id UUID,
  full_name TEXT,
  gender gender_type,
  age INT,
  residence_city TEXT,
  job_title TEXT,
  marital_status marital_status_type,
  verification_status verification_status_type,
  photo_url TEXT,
  liked_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR (p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin()) THEN
    RAISE EXCEPTION 'not allowed' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT 
    l.id AS like_id,
    p.id AS target_id,
    p.full_name,
    p.gender,
    p.age,
    p.residence_city,
    p.job_title,
    p.marital_status,
    p.verification_status,
    (
      SELECT pp.photo_url 
      FROM profile_photos pp 
      WHERE pp.user_id = p.id 
      ORDER BY pp.is_primary DESC, pp.created_at DESC 
      LIMIT 1
    ) AS photo_url,
    l.created_at AS liked_at
  FROM likes l
  JOIN profiles p ON p.id = l.to_user_id
  WHERE l.from_user_id = p_user_id
    AND NOT EXISTS (
      SELECT 1 FROM matches m
      WHERE (m.user_one = LEAST(p_user_id, p.id) AND m.user_two = GREATEST(p_user_id, p.id))
        AND m.is_active = true
    )
    AND NOT EXISTS (
      SELECT 1 FROM blocked_users bu
      WHERE (bu.blocker_id = p_user_id AND bu.blocked_id = p.id)
         OR (bu.blocker_id = p.id AND bu.blocked_id = p_user_id)
    )
  ORDER BY l.created_at DESC;
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. C4: DROP AUTO-PROMOTION TO SUPER_ADMIN BY EMAIL
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_auto_assign_admin ON auth.users;
DROP FUNCTION IF EXISTS public.on_auth_user_created_assign_admin();

-- ----------------------------------------------------------------------------
-- 5. C5: RESTRICT identity_verifications RLS
-- ----------------------------------------------------------------------------
ALTER TABLE public.identity_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "verif_update_own_or_admin" ON public.identity_verifications;
DROP POLICY IF EXISTS "verif_update_own" ON public.identity_verifications;
DROP POLICY IF EXISTS "verif_update_admin_only" ON public.identity_verifications;

CREATE POLICY "verif_update_admin_only"
ON public.identity_verifications FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "verif_insert_own" ON public.identity_verifications;
DROP POLICY IF EXISTS "identity_verifications_insert_own" ON public.identity_verifications;

CREATE POLICY "identity_verifications_insert_own"
ON public.identity_verifications FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id 
  AND status = 'PENDING'::verification_status_type
);

DROP POLICY IF EXISTS "verif_select_own_or_admin" ON public.identity_verifications;
DROP POLICY IF EXISTS "identity_verifications_select_own" ON public.identity_verifications;

CREATE POLICY "identity_verifications_select_own"
ON public.identity_verifications FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 6. C6: RESTRICT subscriptions RLS (ADMIN ONLY FOR INSERT/UPDATE/DELETE)
-- ----------------------------------------------------------------------------
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "subscriptions_insert_own_or_admin" ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions_insert_own" ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions_insert_admin_only" ON public.subscriptions;

CREATE POLICY "subscriptions_insert_admin_only"
ON public.subscriptions FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "subscriptions_update_admin_only" ON public.subscriptions;
CREATE POLICY "subscriptions_update_admin_only"
ON public.subscriptions FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "subscriptions_delete_admin_only" ON public.subscriptions;
CREATE POLICY "subscriptions_delete_admin_only"
ON public.subscriptions FOR DELETE
TO authenticated
USING (public.is_admin());

DROP POLICY IF EXISTS "subscriptions_select_own_or_admin" ON public.subscriptions;
CREATE POLICY "subscriptions_select_own_or_admin"
ON public.subscriptions FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 7. C7: RESTRICT partner_preferences RLS
-- ----------------------------------------------------------------------------
ALTER TABLE public.partner_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "partner_preferences_select_authenticated" ON public.partner_preferences;
DROP POLICY IF EXISTS "partner_preferences_select_own" ON public.partner_preferences;

CREATE POLICY "partner_preferences_select_own"
ON public.partner_preferences FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 8. C8: SECURE discover_members RPC (RATE LIMITS, AUTH CHECK & NO RAW BIRTHDATE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.discover_members(
  p_current_user_id UUID,
  p_gender_filter TEXT DEFAULT NULL,
  p_search_query TEXT DEFAULT NULL,
  p_min_age INT DEFAULT NULL,
  p_max_age INT DEFAULT NULL,
  p_cities TEXT[] DEFAULT NULL,
  p_marital_statuses marital_status_type[] DEFAULT NULL,
  p_education_level TEXT DEFAULT NULL,
  p_must_pray BOOLEAN DEFAULT NULL,
  p_non_smoker_only BOOLEAN DEFAULT NULL,
  p_verified_only BOOLEAN DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  gender gender_type,
  birth_date DATE,
  age INT,
  nationality TEXT,
  residence_city TEXT,
  marital_status marital_status_type,
  job_title TEXT,
  education_level TEXT,
  height_cm INT,
  weight_kg INT,
  smoker BOOLEAN,
  prays TEXT,
  wants_children BOOLEAN,
  bio TEXT,
  verification_status verification_status_type,
  subscription_status subscription_status_type,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  photo_url TEXT,
  compatibility_score INT,
  is_liked BOOLEAN,
  is_matched BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_gender gender_type;
  v_user_city TEXT;
  v_target_gender gender_type;
  v_allow_all_genders BOOLEAN := false;
  v_effective_limit INT;
  v_effective_offset INT;
BEGIN
  -- Strict IDOR check
  IF auth.uid() IS NULL OR (p_current_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin()) THEN
    RAISE EXCEPTION 'not allowed' USING ERRCODE = '42501';
  END IF;

  -- Cap limit between 1 and 100
  v_effective_limit := LEAST(COALESCE(p_limit, 20), 100);
  v_effective_offset := GREATEST(COALESCE(p_offset, 0), 0);

  SELECT p.gender, p.residence_city
  INTO v_user_gender, v_user_city
  FROM profiles p
  WHERE p.id = p_current_user_id;

  IF v_user_gender IS NULL THEN
    RETURN;
  END IF;

  IF p_gender_filter IS NOT NULL AND UPPER(TRIM(p_gender_filter)) = 'ALL' THEN
    v_allow_all_genders := true;
  ELSIF p_gender_filter IS NOT NULL AND UPPER(TRIM(p_gender_filter)) IN ('MALE', 'FEMALE') THEN
    v_target_gender := UPPER(TRIM(p_gender_filter))::gender_type;
  ELSE
    IF v_user_gender = 'MALE' THEN
      v_target_gender := 'FEMALE';
    ELSE
      v_target_gender := 'MALE';
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.full_name,
    p.gender,
    -- Coarsen birth_date to year-only January 1st to prevent exact birthdate leak
    make_date(EXTRACT(YEAR FROM p.birth_date)::int, 1, 1) AS birth_date,
    COALESCE(p.age, EXTRACT(YEAR FROM age(p.birth_date))::int) AS age,
    p.nationality,
    p.residence_city,
    p.marital_status,
    p.job_title,
    p.education_level,
    p.height_cm,
    p.weight_kg,
    p.smoker,
    p.prays,
    p.wants_children,
    p.bio,
    p.verification_status,
    p.subscription_status,
    p.created_at,
    p.updated_at,
    (
      SELECT pp.photo_url
      FROM profile_photos pp
      WHERE pp.user_id = p.id
      ORDER BY pp.is_primary DESC, pp.created_at DESC
      LIMIT 1
    ) AS photo_url,
    85 AS compatibility_score,
    EXISTS (
      SELECT 1 FROM likes l
      WHERE l.from_user_id = p_current_user_id AND l.to_user_id = p.id
    ) AS is_liked,
    EXISTS (
      SELECT 1 FROM matches m
      WHERE (
        (m.user_one = p_current_user_id AND m.user_two = p.id)
        OR (m.user_one = p.id AND m.user_two = p_current_user_id)
      ) AND m.is_active = true
    ) AS is_matched
  FROM profiles p
  WHERE p.id <> p_current_user_id
    AND (v_allow_all_genders OR p.gender = v_target_gender)
    AND (p_min_age IS NULL OR p.age >= p_min_age)
    AND (p_max_age IS NULL OR p.age <= p_max_age)
    AND (p_cities IS NULL OR p.residence_city = ANY(p_cities))
    AND (p_marital_statuses IS NULL OR p.marital_status = ANY(p_marital_statuses))
    AND (p_education_level IS NULL OR p.education_level = p_education_level)
    AND (p_non_smoker_only IS NULL OR NOT p_non_smoker_only OR p.smoker = false)
    AND (p_verified_only IS NULL OR NOT p_verified_only OR p.verification_status = 'VERIFIED')
    AND (
      p_search_query IS NULL
      OR p.full_name ILIKE '%' || p_search_query || '%'
      OR p.residence_city ILIKE '%' || p_search_query || '%'
      OR p.job_title ILIKE '%' || p_search_query || '%'
    )
    -- Exclude blocked users both ways
    AND NOT EXISTS (
      SELECT 1 FROM blocked_users bu
      WHERE (bu.blocker_id = p_current_user_id AND bu.blocked_id = p.id)
         OR (bu.blocker_id = p.id AND bu.blocked_id = p_current_user_id)
    )
  ORDER BY p.created_at DESC
  LIMIT v_effective_limit
  OFFSET v_effective_offset;
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. H4 & H5: CONVERSATION SECURITY GUARDS
-- ----------------------------------------------------------------------------
-- H4: Require legitimate active match on conversation creation
DROP POLICY IF EXISTS "conv_insert_participant" ON public.conversations;
CREATE POLICY "conv_insert_participant"
ON public.conversations FOR INSERT
TO authenticated
WITH CHECK (
  (auth.uid() = user_one OR auth.uid() = user_two)
  AND EXISTS (
    SELECT 1 FROM public.matches m
    WHERE m.id = match_id
      AND m.is_active = true
      AND (
        (m.user_one = user_one AND m.user_two = user_two)
        OR (m.user_one = user_two AND m.user_two = user_one)
      )
  )
);

-- H5: Protect conversation structural columns from tampering
CREATE OR REPLACE FUNCTION public.protect_conversation_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR public.is_admin() THEN
    RETURN NEW;
  END IF;

  NEW.id := OLD.id;
  NEW.match_id := OLD.match_id;
  NEW.user_one := OLD.user_one;
  NEW.user_two := OLD.user_two;
  NEW.created_at := OLD.created_at;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_conversation_columns ON public.conversations;
CREATE TRIGGER trg_protect_conversation_columns
BEFORE UPDATE ON public.conversations
FOR EACH ROW EXECUTE FUNCTION public.protect_conversation_columns();

DROP POLICY IF EXISTS "conv_update_participant" ON public.conversations;
CREATE POLICY "conv_update_participant"
ON public.conversations FOR UPDATE
TO authenticated
USING (auth.uid() = user_one OR auth.uid() = user_two OR public.is_admin())
WITH CHECK (auth.uid() = user_one OR auth.uid() = user_two OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 10. H8: REMOVE PLAIN-TEXT VOUCHERS & ADD RATE LIMITING
-- ----------------------------------------------------------------------------
-- Delete known sample plain-text vouchers from database
DELETE FROM public.voucher_codes WHERE code IN (
  'VIP-GOLD-30D', 'VIP-PLAT-90D', 'VIP-VIP-180D', 'VIP-ANNUAL-365', 
  'VIP-BUNDLE-30D', 'PROMO-FREE-7D', 'PROMO-WELCOME-30D'
);

-- Create voucher attempt tracking table for brute-force rate limiting
CREATE TABLE IF NOT EXISTS public.voucher_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  attempted_code TEXT,
  success BOOLEAN DEFAULT false,
  attempted_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.voucher_attempts ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_voucher_attempts_user ON public.voucher_attempts(user_id, attempted_at DESC);

-- Rate-limited voucher redemption RPC with bypass flag
CREATE OR REPLACE FUNCTION public.redeem_voucher_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_failed_count INT;
  v_voucher RECORD;
  v_current_ends_at TIMESTAMPTZ;
  v_new_starts_at TIMESTAMPTZ;
  v_new_ends_at TIMESTAMPTZ;
  v_sub_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not allowed' USING ERRCODE = '42501';
  END IF;

  -- Brute-force protection: reject if more than 5 failed attempts in the last hour
  SELECT COUNT(*) INTO v_failed_count
  FROM public.voucher_attempts
  WHERE user_id = v_user_id
    AND success = false
    AND attempted_at >= (now() - INTERVAL '1 hour');

  IF v_failed_count >= 5 THEN
    RAISE EXCEPTION 'لقد تجاوزت الحد الأقصى لمحاولات إدخال الكود. يرجى الانتظار لمدة ساعة قبل المحاولة مرة أخرى.';
  END IF;

  -- Find and lock voucher row
  SELECT * INTO v_voucher
  FROM public.voucher_codes
  WHERE UPPER(TRIM(code)) = UPPER(TRIM(p_code))
    AND is_active = true
    AND is_redeemed = false
    AND (expires_at IS NULL OR expires_at > now())
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Log failed attempt
    INSERT INTO public.voucher_attempts (user_id, attempted_code, success)
    VALUES (v_user_id, p_code, false);

    RAISE EXCEPTION 'كود القسيمة غير صالح أو مستخدم مسبقاً أو منتهي الصلاحية.';
  END IF;

  -- Calculate subscription dates
  SELECT ends_at INTO v_current_ends_at
  FROM public.subscriptions
  WHERE user_id = v_user_id AND status = 'ACTIVE' AND ends_at > now()
  ORDER BY ends_at DESC
  LIMIT 1;

  IF v_current_ends_at IS NOT NULL THEN
    v_new_starts_at := v_current_ends_at;
    v_new_ends_at := v_current_ends_at + (v_voucher.duration_days || ' days')::INTERVAL;
  ELSE
    v_new_starts_at := now();
    v_new_ends_at := now() + (v_voucher.duration_days || ' days')::INTERVAL;
  END IF;

  -- Set transaction-local bypass flag for profile guard
  PERFORM set_config('app.bypass_profile_guard', 'on', true);

  -- Mark voucher redeemed
  UPDATE public.voucher_codes
  SET is_redeemed = true,
      redeemed_by = v_user_id,
      redeemed_at = now()
  WHERE id = v_voucher.id;

  -- Insert subscription
  INSERT INTO public.subscriptions (
    user_id,
    tier,
    amount_egp,
    status,
    starts_at,
    ends_at
  )
  VALUES (
    v_user_id,
    v_voucher.tier,
    v_voucher.value_egp,
    'ACTIVE',
    v_new_starts_at,
    v_new_ends_at
  )
  RETURNING id INTO v_sub_id;

  -- Update profiles subscription status
  UPDATE public.profiles
  SET subscription_status = 'ACTIVE',
      updated_at = now()
  WHERE id = v_user_id;

  -- Log successful attempt
  INSERT INTO public.voucher_attempts (user_id, attempted_code, success)
  VALUES (v_user_id, p_code, true);

  RETURN jsonb_build_object(
    'success', true,
    'subscription_id', v_sub_id,
    'tier', v_voucher.tier,
    'duration_days', v_voucher.duration_days,
    'starts_at', v_new_starts_at,
    'ends_at', v_new_ends_at,
    'message', 'تم تفعيل باقة الاشتراك بنجاح عبر كود القسيمة!'
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 11. H9: STORAGE PERMISSIONS HARDENING
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  REVOKE ALL ON storage.buckets FROM anon, authenticated;
  REVOKE ALL ON storage.objects FROM anon, authenticated;
  GRANT SELECT ON storage.buckets TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated;
  GRANT SELECT ON storage.objects TO anon;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- ----------------------------------------------------------------------------
-- 12. ADMIN ACTIONS & TRUSTED RPCS: SET BYPASS GUARD
-- ----------------------------------------------------------------------------
-- Update admin_review_identity_verification
CREATE OR REPLACE FUNCTION public.admin_review_identity_verification(
  p_verification_id UUID,
  p_decision TEXT, -- 'APPROVE' or 'REJECT'
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_verification RECORD;
  v_new_status verification_status_type;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  SELECT * INTO v_verification
  FROM public.identity_verifications
  WHERE id = p_verification_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Verification record not found';
  END IF;

  IF UPPER(p_decision) = 'APPROVE' THEN
    v_new_status := 'VERIFIED';
  ELSIF UPPER(p_decision) = 'REJECT' THEN
    v_new_status := 'FAILED';
  ELSE
    RAISE EXCEPTION 'Invalid decision: must be APPROVE or REJECT';
  END IF;

  -- Set bypass flag
  PERFORM set_config('app.bypass_profile_guard', 'on', true);

  UPDATE public.identity_verifications
  SET status = v_new_status,
      rejection_reason = CASE WHEN v_new_status = 'FAILED' THEN p_reason ELSE NULL END
  WHERE id = p_verification_id;

  UPDATE public.profiles
  SET verification_status = v_new_status,
      updated_at = now()
  WHERE id = v_verification.user_id;

  RETURN jsonb_build_object(
    'success', true,
    'verification_id', p_verification_id,
    'user_id', v_verification.user_id,
    'status', v_new_status
  );
END;
$$;

-- Update create_subscription_for_user
CREATE OR REPLACE FUNCTION public.create_subscription_for_user(
  p_user_id UUID,
  p_tier subscription_plan_tier,
  p_duration_days INT,
  p_amount NUMERIC
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sub_id UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- Set bypass flag
  PERFORM set_config('app.bypass_profile_guard', 'on', true);

  INSERT INTO public.subscriptions (
    user_id,
    tier,
    amount_egp,
    status,
    starts_at,
    ends_at
  )
  VALUES (
    p_user_id,
    p_tier,
    p_amount,
    'ACTIVE',
    now(),
    now() + (p_duration_days || ' days')::INTERVAL
  )
  RETURNING id INTO v_sub_id;

  UPDATE public.profiles
  SET subscription_status = 'ACTIVE',
      updated_at = now()
  WHERE id = p_user_id;

  RETURN v_sub_id;
END;
$$;

-- Update destructive admin functions to require is_superuser()
CREATE OR REPLACE FUNCTION public.admin_delete_user(
  p_target_user_id UUID,
  p_report_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_superuser() THEN
    RAISE EXCEPTION 'Unauthorized: Super Admin access required for account deletion';
  END IF;

  -- Set bypass flag
  PERFORM set_config('app.bypass_profile_guard', 'on', true);

  UPDATE public.profiles
  SET full_name = '[حساب محذوف]',
      bio = NULL,
      job_title = NULL,
      subscription_status = 'CANCELLED',
      updated_at = now()
  WHERE id = p_target_user_id;

  DELETE FROM public.profile_photos WHERE user_id = p_target_user_id;
  UPDATE public.matches SET is_active = false WHERE user_one = p_target_user_id OR user_two = p_target_user_id;

  IF p_report_id IS NOT NULL THEN
    UPDATE public.user_reports
    SET status = 'RESOLVED_DELETED',
        resolved_at = now(),
        resolved_by = auth.uid(),
        resolution_notes = 'تم حذف حساب المستخدم المخالف بواسطة المدير العام'
    WHERE id = p_report_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'action', 'deleted', 'user_id', p_target_user_id);
END;
$$;

-- ----------------------------------------------------------------------------
-- 13. REVOKE EXECUTE ON SECURITY DEFINER FUNCTIONS FROM PUBLIC & ANON
-- ----------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT proname, oidvectortypes(proargtypes) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true
  ) LOOP
    BEGIN
      EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM PUBLIC, anon;', r.proname, r.args);
      EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO authenticated;', r.proname, r.args);
    EXCEPTION WHEN OTHERS THEN
      -- continue if function signature or permission variant differs
      NULL;
    END LOOP;
  END LOOP;
END $$;
