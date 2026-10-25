-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- SCRIPT: Identity Verification RPCs & Secure Submit Function
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. RPC: submit_identity_verification
-- Atomically saves a verification attempt and syncs profiles.verification_status.
-- SECURITY DEFINER so the trigger can update profiles on behalf of the user.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION submit_identity_verification(
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
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Upsert the verification record with PENDING status for manual admin approval
  INSERT INTO identity_verifications (
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

  -- Sync verification_status onto profiles table as PENDING
  UPDATE profiles
  SET verification_status = 'PENDING'::verification_status_type,
      updated_at = now()
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'record_id', v_record_id,
    'status', 'PENDING',
    'message', 'تم استلام طلب توثيق حسابك بنجاح. برجاء الانتظار، سيتم مراجعة طلبك خلال 15 دقيقة.'
  );
END;
$$;

-- Backward-compatibility wrapper for legacy 7-parameter calls
CREATE OR REPLACE FUNCTION submit_identity_verification(
  p_id_url TEXT,
  p_selfie_url TEXT,
  p_ocr_name TEXT,
  p_birth_date DATE,
  p_score NUMERIC,
  p_liveness BOOLEAN,
  p_status verification_status_type
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN submit_identity_verification(p_id_url, p_selfie_url);
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. RPC: get_my_verification_status
-- Returns the latest verification record for the authenticated user.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_my_verification_status()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_row identity_verifications%ROWTYPE;
BEGIN
  SELECT * INTO v_row
  FROM identity_verifications
  WHERE user_id = v_user_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'UNVERIFIED');
  END IF;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'status', v_row.status::TEXT,
    'face_match_score', v_row.face_match_score,
    'liveness_passed', v_row.liveness_passed,
    'extracted_name', v_row.extracted_name,
    'rejection_reason', v_row.rejection_reason,
    'created_at', v_row.created_at::TEXT
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. RLS for identity_verifications
-- Users can only view and insert/update their own records
-- ----------------------------------------------------------------------------
ALTER TABLE identity_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "verif_select_own" ON identity_verifications;
CREATE POLICY "verif_select_own"
ON identity_verifications FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "verif_insert_own" ON identity_verifications;
CREATE POLICY "verif_insert_own"
ON identity_verifications FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "verif_update_own" ON identity_verifications;
CREATE POLICY "verif_update_own"
ON identity_verifications FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 4. Unique constraint on user_id for upsert compatibility
-- (Only runs if constraint doesn't already exist)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'identity_verifications_user_id_key'
  ) THEN
    ALTER TABLE identity_verifications ADD CONSTRAINT identity_verifications_user_id_key UNIQUE (user_id);
  END IF;
END;
$$;
