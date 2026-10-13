-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- SCRIPT: Likes & Mutual Matches Stored Procedures & RLS Enhancements
-- DESCRIPTION: Optimized queries for mutual matches, incoming likes, outgoing
--              likes, and atomic like-with-match detection.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. RLS ENHANCEMENT FOR LIKES
-- Allow users to view both likes they sent AND likes sent to them
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "likes_select_own" ON likes;
DROP POLICY IF EXISTS "likes_select_involved" ON likes;

CREATE POLICY "likes_select_involved"
ON likes FOR SELECT
TO authenticated
USING (
  auth.uid() = from_user_id 
  OR auth.uid() = to_user_id
);

-- ----------------------------------------------------------------------------
-- 2. RPC: send_like_and_check_match
-- Atomically registers a like and detects if a mutual match was triggered.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION send_like_and_check_match(p_to_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from_user_id UUID := auth.uid();
  v_match_id UUID := NULL;
  v_is_match BOOLEAN := false;
  v_partner_name TEXT;
  v_partner_photo TEXT;
BEGIN
  IF v_from_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_from_user_id = p_to_user_id THEN
    RAISE EXCEPTION 'Users cannot like themselves';
  END IF;

  -- 1. Insert like (ignore if already liked)
  INSERT INTO likes (from_user_id, to_user_id, created_at)
  VALUES (v_from_user_id, p_to_user_id, now())
  ON CONFLICT (from_user_id, to_user_id) DO NOTHING;

  -- 2. The trigger `trigger_handle_new_like` has already run if reciprocal like existed.
  -- Check if an active match exists between these two users
  SELECT id INTO v_match_id
  FROM matches
  WHERE (user_one = LEAST(v_from_user_id, p_to_user_id) AND user_two = GREATEST(v_from_user_id, p_to_user_id))
    AND is_active = true
  LIMIT 1;

  IF v_match_id IS NOT NULL THEN
    v_is_match := true;

    -- Fetch partner summary
    SELECT full_name INTO v_partner_name
    FROM profiles
    WHERE id = p_to_user_id;

    SELECT photo_url INTO v_partner_photo
    FROM profile_photos
    WHERE user_id = p_to_user_id
    ORDER BY is_primary DESC, created_at DESC
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'is_match', v_is_match,
    'match_id', v_match_id,
    'partner_name', v_partner_name,
    'partner_photo', v_partner_photo
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. RPC: get_user_mutual_matches
-- Fetches active mutual matches with partner profile details and photos.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_user_mutual_matches(p_user_id UUID)
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

-- ----------------------------------------------------------------------------
-- 4. RPC: get_received_likes
-- Fetches candidates who liked the user, where no match has been confirmed yet.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_received_likes(p_user_id UUID)
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

-- ----------------------------------------------------------------------------
-- 5. RPC: get_sent_likes
-- Fetches profiles the user sent a serious like to, awaiting response.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_sent_likes(p_user_id UUID)
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
