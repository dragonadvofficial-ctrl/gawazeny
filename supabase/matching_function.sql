-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- FUNCTION: get_smart_matches(current_user_id, p_limit, p_offset)
-- DESCRIPTION: 3-Tier Recommendation Engine with dynamic compatibility scoring
--              (50% to 99%), opposite gender filtering, block & like exclusion.
-- ============================================================================

CREATE OR REPLACE FUNCTION get_smart_matches(
  current_user_id UUID,
  p_limit INT DEFAULT 20,
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
  compatibility_score INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_gender gender_type;
  v_target_gender gender_type;
  v_user_city TEXT;
  v_min_age INT := 18;
  v_max_age INT := 60;
  v_acceptable_statuses marital_status_type[] := '{}';
  v_acceptable_cities TEXT[] := '{}';
  v_must_pray BOOLEAN := false;
  v_accepts_smokers BOOLEAN := false;
BEGIN
  -- 1. Retrieve current user's profile info
  SELECT p.gender, p.residence_city
  INTO v_user_gender, v_user_city
  FROM profiles p
  WHERE p.id = current_user_id;

  IF v_user_gender IS NULL THEN
    RETURN;
  END IF;

  -- Opposite gender strictly enforced
  IF v_user_gender = 'MALE' THEN
    v_target_gender := 'FEMALE';
  ELSE
    v_target_gender := 'MALE';
  END IF;

  -- 2. Retrieve partner preferences if configured
  SELECT
    pref.min_age,
    pref.max_age,
    pref.acceptable_marital_statuses,
    pref.acceptable_cities,
    pref.must_pray,
    pref.accepts_smokers
  INTO
    v_min_age,
    v_max_age,
    v_acceptable_statuses,
    v_acceptable_cities,
    v_must_pray,
    v_accepts_smokers
  FROM partner_preferences pref
  WHERE pref.user_id = current_user_id;

  -- 3. Query candidate profiles and compute compatibility score
  RETURN QUERY
  WITH scored_candidates AS (
    SELECT
      p.id,
      p.full_name,
      p.gender,
      p.birth_date,
      p.age,
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
      ph.photo_url,
      LEAST(
        99,
        GREATEST(
          10,
          0 -- No artificial 50% floor
          + (CASE WHEN p.age BETWEEN v_min_age AND v_max_age THEN 20 ELSE 0 END)
          + (CASE WHEN (p.residence_city = v_user_city OR (array_length(v_acceptable_cities, 1) > 0 AND p.residence_city = ANY(v_acceptable_cities))) THEN 20 ELSE 0 END)
          + (CASE WHEN (array_length(v_acceptable_statuses, 1) IS NULL OR array_length(v_acceptable_statuses, 1) = 0 OR p.marital_status = ANY(v_acceptable_statuses)) THEN 20 ELSE 0 END)
          + (CASE WHEN (v_must_pray IS FALSE OR p.prays ILIKE '%محافظ%' OR p.prays ILIKE '%دائماً%' OR p.prays ILIKE '%وقتها%' OR p.prays ILIKE '%مسجد%') THEN 15 ELSE 0 END)
          + (CASE WHEN (v_accepts_smokers IS TRUE OR p.smoker IS FALSE) THEN 15 ELSE 0 END)
          + (CASE WHEN p.verification_status = 'VERIFIED' THEN 10 ELSE 0 END)
        )
      )::INT AS compatibility_score
    FROM profiles p
    LEFT JOIN LATERAL (
      SELECT photos.photo_url
      FROM profile_photos photos
      WHERE photos.user_id = p.id
      ORDER BY photos.is_primary DESC, photos.created_at DESC
      LIMIT 1
    ) ph ON true
    WHERE p.gender = v_target_gender
      AND p.id <> current_user_id
      -- Exclude users already liked by current user
      AND NOT EXISTS (
        SELECT 1 FROM likes l
        WHERE l.from_user_id = current_user_id
          AND l.to_user_id = p.id
      )
      -- Exclude blocked users (either direction)
      AND NOT EXISTS (
        SELECT 1 FROM blocked_users b
        WHERE (b.blocker_id = current_user_id AND b.blocked_id = p.id)
           OR (b.blocker_id = p.id AND b.blocked_id = current_user_id)
      )
  )
  SELECT *
  FROM scored_candidates sc
  ORDER BY
    sc.compatibility_score DESC,
    (sc.verification_status = 'VERIFIED') DESC,
    sc.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
