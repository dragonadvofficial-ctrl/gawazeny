-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- FUNCTION: discover_members(...)
-- DESCRIPTION: Comprehensive discovery and matrimonial search stored procedure.
--              Allows browsing registered members, optional same-gender browsing
--              (with marriage compatibility suppressed), flexible criteria filtering,
--              and eliminates any compulsory minimum compatibility threshold.
-- ============================================================================

CREATE OR REPLACE FUNCTION discover_members(
  p_current_user_id UUID,
  p_gender_filter TEXT DEFAULT NULL, -- 'FEMALE', 'MALE', 'ALL', or NULL (default opposite)
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
  v_pref_min_age INT := 18;
  v_pref_max_age INT := 60;
  v_pref_statuses marital_status_type[] := '{}';
  v_pref_cities TEXT[] := '{}';
  v_pref_must_pray BOOLEAN := false;
  v_pref_accepts_smokers BOOLEAN := false;
  v_target_gender gender_type;
  v_allow_all_genders BOOLEAN := false;
BEGIN
  -- 1. Retrieve current user profile
  SELECT p.gender, p.residence_city
  INTO v_user_gender, v_user_city
  FROM profiles p
  WHERE p.id = p_current_user_id;

  IF v_user_gender IS NULL THEN
    RETURN;
  END IF;

  -- 2. Determine target gender
  IF p_gender_filter IS NOT NULL AND UPPER(TRIM(p_gender_filter)) = 'ALL' THEN
    v_allow_all_genders := true;
  ELSIF p_gender_filter IS NOT NULL AND UPPER(TRIM(p_gender_filter)) IN ('MALE', 'FEMALE') THEN
    v_target_gender := UPPER(TRIM(p_gender_filter))::gender_type;
  ELSE
    -- Default to opposite gender according to traditional serious matrimonial matching
    IF v_user_gender = 'MALE' THEN
      v_target_gender := 'FEMALE';
    ELSE
      v_target_gender := 'MALE';
    END IF;
  END IF;

  -- 3. Retrieve partner preferences if available
  SELECT
    pref.min_age,
    pref.max_age,
    pref.acceptable_marital_statuses,
    pref.acceptable_cities,
    pref.must_pray,
    pref.accepts_smokers
  INTO
    v_pref_min_age,
    v_pref_max_age,
    v_pref_statuses,
    v_pref_cities,
    v_pref_must_pray,
    v_pref_accepts_smokers
  FROM partner_preferences pref
  WHERE pref.user_id = p_current_user_id;

  -- 4. Query candidate profiles
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
      COALESCE(ph.photo_url, p.photo_url) AS photo_url,
      -- Marriage compatibility score calculated ONLY when opposite gender!
      -- If same gender (e.g. browsing accounts), score is strictly NULL.
      CASE 
        WHEN p.gender <> v_user_gender THEN
          LEAST(
            99,
            GREATEST(
              10,
              0
              -- Age Fit (+20%)
              + (CASE WHEN p.age BETWEEN v_pref_min_age AND v_pref_max_age THEN 20 ELSE 0 END)
              -- City Match (+20%)
              + (CASE WHEN (p.residence_city = v_user_city OR (array_length(v_pref_cities, 1) > 0 AND p.residence_city = ANY(v_pref_cities))) THEN 20 ELSE 0 END)
              -- Marital Status Fit (+20%)
              + (CASE WHEN (array_length(v_pref_statuses, 1) IS NULL OR array_length(v_pref_statuses, 1) = 0 OR p.marital_status = ANY(v_pref_statuses)) THEN 20 ELSE 0 END)
              -- Prayer Alignment (+15%)
              + (CASE WHEN (v_pref_must_pray IS FALSE OR p.prays ILIKE '%محافظ%' OR p.prays ILIKE '%دائماً%' OR p.prays ILIKE '%وقتها%' OR p.prays ILIKE '%مسجد%') THEN 15 ELSE 0 END)
              -- Smoking Alignment (+15%)
              + (CASE WHEN (v_pref_accepts_smokers IS TRUE OR p.smoker IS FALSE) THEN 15 ELSE 0 END)
              -- Verification Bonus (+10%)
              + (CASE WHEN p.verification_status = 'VERIFIED' THEN 10 ELSE 0 END)
            )
          )::INT
        ELSE
          NULL -- Same-gender browsing has NO marriage compatibility percentage
      END AS compatibility_score,
      EXISTS (
        SELECT 1 FROM likes l
        WHERE l.from_user_id = p_current_user_id AND l.to_user_id = p.id
      ) AS is_liked,
      EXISTS (
        SELECT 1 FROM matches m
        WHERE (m.user_one = LEAST(p_current_user_id, p.id) AND m.user_two = GREATEST(p_current_user_id, p.id))
          AND m.is_active = true
      ) AS is_matched
    FROM profiles p
    LEFT JOIN LATERAL (
      SELECT photos.photo_url
      FROM profile_photos photos
      WHERE photos.user_id = p.id
      ORDER BY photos.is_primary DESC, photos.created_at DESC
      LIMIT 1
    ) ph ON true
    WHERE p.id <> p_current_user_id
      -- Target gender match unless 'ALL' explicitly chosen
      AND (v_allow_all_genders OR p.gender = v_target_gender)
      -- Exclude blocked users (either direction)
      AND NOT EXISTS (
        SELECT 1 FROM blocked_users b
        WHERE (b.blocker_id = p_current_user_id AND b.blocked_id = p.id)
           OR (b.blocker_id = p.id AND b.blocked_id = p_current_user_id)
      )
      -- Keyword / text search (name, job, city, bio)
      AND (
        p_search_query IS NULL OR TRIM(p_search_query) = ''
        OR p.full_name ILIKE '%' || TRIM(p_search_query) || '%'
        OR (p.job_title IS NOT NULL AND p.job_title ILIKE '%' || TRIM(p_search_query) || '%')
        OR p.residence_city ILIKE '%' || TRIM(p_search_query) || '%'
        OR (p.bio IS NOT NULL AND p.bio ILIKE '%' || TRIM(p_search_query) || '%')
      )
      -- Optional age range filter
      AND (p_min_age IS NULL OR p.age >= p_min_age)
      AND (p_max_age IS NULL OR p.age <= p_max_age)
      -- Optional cities filter
      AND (p_cities IS NULL OR array_length(p_cities, 1) IS NULL OR array_length(p_cities, 1) = 0 OR p.residence_city = ANY(p_cities))
      -- Optional marital statuses filter
      AND (p_marital_statuses IS NULL OR array_length(p_marital_statuses, 1) IS NULL OR array_length(p_marital_statuses, 1) = 0 OR p.marital_status = ANY(p_marital_statuses))
      -- Optional education level filter
      AND (p_education_level IS NULL OR TRIM(p_education_level) = '' OR p.education_level = p_education_level)
      -- Optional prayer filter
      AND (p_must_pray IS NOT TRUE OR p.prays ILIKE '%محافظ%' OR p.prays ILIKE '%دائماً%' OR p.prays ILIKE '%وقتها%' OR p.prays ILIKE '%مسجد%')
      -- Optional non-smoker filter
      AND (p_non_smoker_only IS NOT TRUE OR p.smoker = false)
      -- Optional verified only filter
      AND (p_verified_only IS NOT TRUE OR p.verification_status = 'VERIFIED')
  )
  SELECT *
  FROM scored_candidates sc
  ORDER BY
    sc.compatibility_score DESC NULLS LAST,
    (sc.verification_status = 'VERIFIED') DESC,
    sc.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
