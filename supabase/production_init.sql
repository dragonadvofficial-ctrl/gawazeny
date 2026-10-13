-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Matrimonial Platform)
-- MIGRATION: Consolidated Production Initialization & Scale Hardening (100,000 Users)
-- FILE: supabase/production_init.sql
-- DESCRIPTION: Unified production database schema combining core tables,
--              high-performance composite/partial indexes, triggers,
--              atomic stored procedures (RPCs), Row Level Security (RLS) policies,
--              Supabase Realtime publication, storage buckets, and admin security.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EXTENSIONS
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 2. CUSTOM ENUM TYPES
-- ----------------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE gender_type AS ENUM ('MALE', 'FEMALE');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE marital_status_type AS ENUM ('SINGLE', 'DIVORCED', 'WIDOWED');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE verification_status_type AS ENUM (
    'UNVERIFIED',
    'PENDING',
    'VERIFIED',
    'FAILED',
    'MANUAL_REVIEW'
  );
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE subscription_status_type AS ENUM (
    'FREE',
    'PENDING_PAYMENT',
    'ACTIVE',
    'EXPIRED',
    'CANCELLED',
    'PAYMENT_FAILED'
  );
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE subscription_plan_tier AS ENUM (
    'MONTHLY_200',
    'QUARTERLY_500',
    'SEMI_ANNUAL_900',
    'ANNUAL_1500',
    'BUNDLE_FB_1000'
  );
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- ----------------------------------------------------------------------------
-- 3. CORE TABLES & CONSTRAINTS
-- ----------------------------------------------------------------------------

-- PROFILES TABLE
CREATE TABLE IF NOT EXISTS profiles (
  id                  UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name           TEXT NOT NULL,
  gender              gender_type NOT NULL,
  birth_date          DATE NOT NULL,
  age                 INT,
  nationality         TEXT NOT NULL,
  residence_city      TEXT NOT NULL,
  marital_status      marital_status_type NOT NULL,
  job_title           TEXT,
  education_level     TEXT,
  height_cm           INT,
  weight_kg           INT,
  smoker              BOOLEAN DEFAULT false,
  prays               TEXT,
  wants_children      BOOLEAN DEFAULT true,
  bio                 TEXT,
  verification_status verification_status_type DEFAULT 'UNVERIFIED',
  subscription_status subscription_status_type DEFAULT 'FREE',
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION calculate_profile_age()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.birth_date IS NOT NULL THEN
    NEW.age := EXTRACT(YEAR FROM age(NEW.birth_date))::INT;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_calculate_profile_age ON profiles;
CREATE TRIGGER trigger_calculate_profile_age
BEFORE INSERT OR UPDATE OF birth_date ON profiles
FOR EACH ROW
EXECUTE FUNCTION calculate_profile_age();

-- PARTNER PREFERENCES TABLE
CREATE TABLE IF NOT EXISTS partner_preferences (
  user_id                     UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  min_age                     INT DEFAULT 18,
  max_age                     INT DEFAULT 60,
  acceptable_marital_statuses marital_status_type[] DEFAULT '{}',
  acceptable_cities           TEXT[] DEFAULT '{}',
  must_pray                   BOOLEAN DEFAULT false,
  accepts_smokers             BOOLEAN DEFAULT false,
  created_at                  TIMESTAMPTZ DEFAULT now()
);

-- PROFILE PHOTOS TABLE
CREATE TABLE IF NOT EXISTS profile_photos (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  photo_url  TEXT NOT NULL,
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- LIKES TABLE
CREATE TABLE IF NOT EXISTS likes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  to_user_id   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT unique_like_pair UNIQUE (from_user_id, to_user_id),
  CONSTRAINT no_self_like CHECK (from_user_id <> to_user_id)
);

-- MATCHES TABLE
CREATE TABLE IF NOT EXISTS matches (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_one   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  user_two   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_active  BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT unique_match_pair UNIQUE (user_one, user_two),
  CONSTRAINT ordered_users CHECK (user_one < user_two)
);

-- BLOCKED USERS TABLE
CREATE TABLE IF NOT EXISTS blocked_users (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT unique_block_pair UNIQUE (blocker_id, blocked_id),
  CONSTRAINT no_self_block CHECK (blocker_id <> blocked_id)
);

-- IDENTITY VERIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS identity_verifications (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  id_card_image_url    TEXT NOT NULL,
  selfie_image_url     TEXT NOT NULL,
  extracted_name       TEXT,
  extracted_birth_date DATE,
  face_match_score     NUMERIC(5,2),
  liveness_passed      BOOLEAN DEFAULT false,
  status               verification_status_type DEFAULT 'PENDING',
  rejection_reason     TEXT,
  created_at           TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT identity_verifications_user_id_key UNIQUE (user_id)
);

-- SUBSCRIPTIONS TABLE
CREATE TABLE IF NOT EXISTS subscriptions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  tier              subscription_plan_tier NOT NULL,
  amount_egp        NUMERIC(10,2) NOT NULL,
  status            subscription_status_type DEFAULT 'PENDING_PAYMENT',
  starts_at         TIMESTAMPTZ,
  ends_at           TIMESTAMPTZ,
  payment_reference TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);

-- CONVERSATIONS TABLE
CREATE TABLE IF NOT EXISTS conversations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id        UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  user_one        UUID NOT NULL REFERENCES profiles(id),
  user_two        UUID NOT NULL REFERENCES profiles(id),
  last_message    TEXT,
  last_message_at TIMESTAMPTZ DEFAULT now(),
  created_at      TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT conversations_match_id_key UNIQUE (match_id)
);

-- MESSAGES TABLE
CREATE TABLE IF NOT EXISTS messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id       UUID NOT NULL REFERENCES profiles(id),
  content         TEXT NOT NULL,
  is_read         BOOLEAN DEFAULT false,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- VOUCHER CODES TABLE
CREATE TABLE IF NOT EXISTS voucher_codes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code          TEXT NOT NULL UNIQUE,
  tier          subscription_plan_tier NOT NULL DEFAULT 'MONTHLY_200',
  duration_days INT NOT NULL DEFAULT 30,
  amount_egp    NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  is_used       BOOLEAN NOT NULL DEFAULT false,
  is_redeemed   BOOLEAN GENERATED ALWAYS AS (is_used) STORED,
  used_by       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  used_at       TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ,
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- USER REPORTS TABLE
CREATE TABLE IF NOT EXISTS user_reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reported_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reason           TEXT NOT NULL,
  details          TEXT,
  status           TEXT NOT NULL DEFAULT 'PENDING',
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  resolved_at      TIMESTAMPTZ,
  resolved_by      UUID,
  CONSTRAINT chk_reporter_differs CHECK (reporter_id <> reported_user_id)
);

-- ADMIN USERS TABLE
CREATE TABLE IF NOT EXISTS admin_users (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email        TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT 'مشرف',
  role         TEXT NOT NULL DEFAULT 'SUPER_ADMIN',
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 4. HIGH-PERFORMANCE SCALABILITY INDEXES (OPTIMIZED FOR 100k+ USERS)
-- ----------------------------------------------------------------------------

-- Discovery & Matching feed multi-column filtering
CREATE INDEX IF NOT EXISTS idx_profiles_matching_filter 
  ON profiles(gender, residence_city, marital_status, verification_status);

CREATE INDEX IF NOT EXISTS idx_profiles_gender_age 
  ON profiles(gender, age);

CREATE INDEX IF NOT EXISTS idx_profiles_created_at 
  ON profiles(created_at DESC);

-- Likes high-throughput lookup & reciprocal match check
CREATE INDEX IF NOT EXISTS idx_likes_lookup 
  ON likes(to_user_id, from_user_id);

CREATE INDEX IF NOT EXISTS idx_likes_from_user 
  ON likes(from_user_id, created_at DESC);

-- Active Matches lookup & participant isolation
CREATE INDEX IF NOT EXISTS idx_matches_participants 
  ON matches(user_one, user_two) 
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_matches_user_one_active 
  ON matches(user_one) 
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_matches_user_two_active 
  ON matches(user_two) 
  WHERE is_active = true;

-- Message inbox & conversation message pagination
CREATE INDEX IF NOT EXISTS idx_messages_conversation_ordered 
  ON messages(conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_unread_badge 
  ON messages(conversation_id, is_read, sender_id);

CREATE INDEX IF NOT EXISTS idx_conversations_user_one 
  ON conversations(user_one, last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_conversations_user_two 
  ON conversations(user_two, last_message_at DESC);

-- Offline Voucher fast redemption lookup
CREATE INDEX IF NOT EXISTS idx_voucher_codes_lookup 
  ON voucher_codes(code) 
  WHERE is_redeemed = false;

CREATE INDEX IF NOT EXISTS idx_voucher_codes_upper 
  ON voucher_codes(UPPER(code));

CREATE INDEX IF NOT EXISTS idx_voucher_codes_used_by 
  ON voucher_codes(used_by);

-- Safety & Blocking high-frequency checks
CREATE INDEX IF NOT EXISTS idx_blocked_users_pair 
  ON blocked_users(blocker_id, blocked_id);

CREATE INDEX IF NOT EXISTS idx_blocked_users_reverse 
  ON blocked_users(blocked_id, blocker_id);

-- Moderation Reports pending queue
CREATE INDEX IF NOT EXISTS idx_user_reports_status 
  ON user_reports(status) 
  WHERE status = 'PENDING';

CREATE INDEX IF NOT EXISTS idx_user_reports_reporter 
  ON user_reports(reporter_id);

CREATE INDEX IF NOT EXISTS idx_user_reports_reported 
  ON user_reports(reported_user_id);

-- Subscriptions history lookup
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status 
  ON subscriptions(user_id, status);

-- ----------------------------------------------------------------------------
-- 5. AUTOMATIC TIMESTAMPS TRIGGER
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_timestamp_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_profiles_update_timestamp ON profiles;
CREATE TRIGGER trigger_profiles_update_timestamp
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_timestamp_column();

DROP TRIGGER IF EXISTS trigger_reports_update_timestamp ON user_reports;
CREATE TRIGGER trigger_reports_update_timestamp
BEFORE UPDATE ON user_reports
FOR EACH ROW
EXECUTE FUNCTION update_timestamp_column();

-- ----------------------------------------------------------------------------
-- 6. ATOMIC AUTO-MATCH TRIGGER (AFTER INSERT ON likes)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_new_like()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if reciprocal like already exists (to_user_id liked from_user_id)
  IF EXISTS (
    SELECT 1 FROM likes
    WHERE from_user_id = NEW.to_user_id
      AND to_user_id = NEW.from_user_id
  ) THEN
    -- Automatically insert into matches ensuring user_one < user_two order
    INSERT INTO matches (
      user_one,
      user_two,
      is_active,
      created_at
    )
    VALUES (
      LEAST(NEW.from_user_id, NEW.to_user_id),
      GREATEST(NEW.from_user_id, NEW.to_user_id),
      true,
      now()
    )
    ON CONFLICT (user_one, user_two) DO UPDATE SET is_active = true;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_handle_new_like ON likes;
CREATE TRIGGER trigger_handle_new_like
AFTER INSERT ON likes
FOR EACH ROW
EXECUTE FUNCTION handle_new_like();

-- ----------------------------------------------------------------------------
-- 7. CHAT TRIGGER (Auto-update last_message & last_message_at)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE conversations
  SET
    last_message = NEW.content,
    last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_message ON messages;
CREATE TRIGGER on_new_message
AFTER INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION update_conversation_last_message();

-- ----------------------------------------------------------------------------
-- 8. CORE APPLICATION STORED PROCEDURES (RPCs)
-- ----------------------------------------------------------------------------

-- 8.1 get_smart_matches (High-performance paginated recommendation algorithm)
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
  -- 1. Retrieve current user profile
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
          50,
          50 -- Base score minimum 50%
          + (CASE WHEN p.age BETWEEN v_min_age AND v_max_age THEN 20 ELSE 0 END)
          + (CASE WHEN (p.residence_city = v_user_city OR (array_length(v_acceptable_cities, 1) > 0 AND p.residence_city = ANY(v_acceptable_cities))) THEN 20 ELSE 0 END)
          + (CASE WHEN (array_length(v_acceptable_statuses, 1) IS NULL OR array_length(v_acceptable_statuses, 1) = 0 OR p.marital_status = ANY(v_acceptable_statuses)) THEN 20 ELSE 0 END)
          + (CASE WHEN (v_must_pray IS FALSE OR p.prays ILIKE '%محافظ%') THEN 15 ELSE 0 END)
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
      -- Exclude blocked users in either direction
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

-- 8.2 send_like_and_check_match (Atomic registration & instant match return)
CREATE OR REPLACE FUNCTION send_like_and_check_match(p_to_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from_user_id UUID := auth.uid();
  v_match_id     UUID := NULL;
  v_is_match     BOOLEAN := false;
  v_partner_name TEXT;
  v_partner_photo TEXT;
BEGIN
  IF v_from_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_from_user_id = p_to_user_id THEN
    RAISE EXCEPTION 'Users cannot like themselves';
  END IF;

  -- 1. Insert like
  INSERT INTO likes (from_user_id, to_user_id, created_at)
  VALUES (v_from_user_id, p_to_user_id, now())
  ON CONFLICT (from_user_id, to_user_id) DO NOTHING;

  -- 2. Check if mutual match exists (trigger has run if reciprocal existed)
  SELECT id INTO v_match_id
  FROM matches
  WHERE user_one = LEAST(v_from_user_id, p_to_user_id)
    AND user_two = GREATEST(v_from_user_id, p_to_user_id)
    AND is_active = true
  LIMIT 1;

  IF v_match_id IS NOT NULL THEN
    v_is_match := true;

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

-- 8.3 get_user_mutual_matches
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

-- 8.4 get_received_likes
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

-- 8.5 get_sent_likes
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

-- 8.6 redeem_voucher_code (Atomic redemption with pessimistic FOR UPDATE row lock)
CREATE OR REPLACE FUNCTION redeem_voucher_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id         UUID := auth.uid();
  v_norm_code       TEXT;
  v_voucher         RECORD;
  v_current_ends_at TIMESTAMPTZ;
  v_starts_at       TIMESTAMPTZ;
  v_ends_at         TIMESTAMPTZ;
  v_sub_id          UUID;
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

  -- 3. Pessimistic row locking against race conditions
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

  -- 5. Calculate subscription duration (extend active if applicable)
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

  -- 6. Mark voucher as redeemed
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

  -- 8. Elevate user profile status to ACTIVE
  UPDATE profiles
  SET subscription_status = 'ACTIVE',
      updated_at = now()
  WHERE id = v_user_id;

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

-- 8.7 submit_user_report (Report user with optional automatic blocking)
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
  v_report_id   UUID;
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
      NULL;
    END;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم استلام بلاغك وسيقوم فريق الإدارة بمراجعته فوراً',
    'report_id', v_report_id
  );
END;
$$;

-- 8.8 block_user & unblock_user & get_blocked_users
CREATE OR REPLACE FUNCTION block_user(p_target_id UUID, p_reason TEXT DEFAULT NULL)
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

  INSERT INTO blocked_users (blocker_id, blocked_id, created_at)
  VALUES (v_me, p_target_id, now())
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  -- Deactivate any existing mutual match
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

-- 8.9 get_or_create_conversation & mark_messages_read
CREATE OR REPLACE FUNCTION get_or_create_conversation(
  p_match_id UUID,
  p_partner_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_conv_id        UUID;
  v_my_status      TEXT;
  v_partner_status TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Verify match exists and caller is a participant
  IF NOT EXISTS (
    SELECT 1 FROM matches m
    WHERE m.id = p_match_id AND m.is_active = true
      AND (m.user_one = v_user_id OR m.user_two = v_user_id)
  ) THEN
    RETURN jsonb_build_object('error', 'NO_MATCH', 'message', 'لا يوجد توافق نشط');
  END IF;

  -- Both participants must be verified for Islamic matrimonial integrity
  SELECT verification_status::TEXT INTO v_my_status
  FROM profiles WHERE id = v_user_id;

  SELECT verification_status::TEXT INTO v_partner_status
  FROM profiles WHERE id = p_partner_id;

  IF v_my_status != 'VERIFIED' THEN
    RETURN jsonb_build_object('error', 'NOT_VERIFIED', 'message', 'يجب توثيق هويتك أولاً لبدء المحادثة');
  END IF;

  IF v_partner_status != 'VERIFIED' THEN
    RETURN jsonb_build_object('error', 'PARTNER_NOT_VERIFIED', 'message', 'الطرف الآخر لم يُوثّق هويته بعد');
  END IF;

  -- Block check
  IF EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = v_user_id AND blocked_id = p_partner_id)
       OR (blocker_id = p_partner_id AND blocked_id = v_user_id)
  ) THEN
    RETURN jsonb_build_object('error', 'BLOCKED', 'message', 'تعذر فتح المحادثة بسبب الحظر');
  END IF;

  -- Upsert conversation
  INSERT INTO conversations (match_id, user_one, user_two)
  VALUES (p_match_id, v_user_id, p_partner_id)
  ON CONFLICT (match_id) DO UPDATE SET match_id = EXCLUDED.match_id
  RETURNING id INTO v_conv_id;

  RETURN jsonb_build_object(
    'conversation_id', v_conv_id,
    'my_status', v_my_status,
    'partner_status', v_partner_status
  );
END;
$$;

CREATE OR REPLACE FUNCTION mark_messages_read(p_conversation_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE messages
  SET is_read = true
  WHERE conversation_id = p_conversation_id
    AND sender_id != auth.uid()
    AND is_read = false;
END;
$$;

-- 8.10 submit_identity_verification & get_my_verification_status
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
DECLARE
  v_user_id UUID := auth.uid();
  v_record_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO identity_verifications (
    user_id,
    id_card_image_url,
    selfie_image_url,
    extracted_name,
    extracted_birth_date,
    face_match_score,
    liveness_passed,
    status,
    created_at
  )
  VALUES (
    v_user_id,
    p_id_url,
    p_selfie_url,
    p_ocr_name,
    p_birth_date,
    p_score,
    p_liveness,
    p_status,
    now()
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    id_card_image_url = EXCLUDED.id_card_image_url,
    selfie_image_url = EXCLUDED.selfie_image_url,
    extracted_name = EXCLUDED.extracted_name,
    extracted_birth_date = EXCLUDED.extracted_birth_date,
    face_match_score = EXCLUDED.face_match_score,
    liveness_passed = EXCLUDED.liveness_passed,
    status = EXCLUDED.status,
    rejection_reason = CASE
      WHEN EXCLUDED.status = 'FAILED'::verification_status_type
        THEN 'حدث خطأ في مطابقة بيانات الهوية مع الصورة الشخصية'
      ELSE NULL
    END,
    created_at = now()
  RETURNING id INTO v_record_id;

  -- Sync status directly into profiles table
  UPDATE profiles
  SET verification_status = p_status,
      updated_at = now()
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'record_id', v_record_id,
    'status', p_status::TEXT,
    'score', p_score,
    'liveness', p_liveness
  );
END;
$$;

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

-- 8.11 process_subscription_payment & delete_user_account
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
  v_caller_id     UUID := auth.uid();
  v_duration_days INT;
  v_amount_egp    NUMERIC(10,2);
  v_starts_at     TIMESTAMPTZ := now();
  v_ends_at       TIMESTAMPTZ;
  v_sub_id        UUID;
BEGIN
  IF v_caller_id IS NULL OR v_caller_id <> p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot process subscription for another user';
  END IF;

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

  UPDATE profiles
  SET subscription_status = 'ACTIVE',
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

  -- Cascade delete from profiles
  DELETE FROM profiles WHERE id = v_me;

  -- Delete auth user record if permissions permit
  BEGIN
    DELETE FROM auth.users WHERE id = v_me;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'User account permanently deleted'
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. ADMIN SECURITY & MODERATION STORED PROCEDURES (RPCs)
-- ----------------------------------------------------------------------------

-- 9.1 is_admin() Helper
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

-- 9.2 admin_review_verification (Approve or Reject verification request)
CREATE OR REPLACE FUNCTION admin_review_verification(
  p_verification_id UUID,
  p_action TEXT, -- 'APPROVE' or 'REJECT'
  p_rejection_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id       UUID := auth.uid();
  v_verification   RECORD;
  v_new_status     verification_status_type;
BEGIN
  IF NOT is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح');
  END IF;

  SELECT * INTO v_verification
  FROM identity_verifications
  WHERE id = p_verification_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'طلب التحقق غير موجود');
  END IF;

  IF p_action = 'APPROVE' THEN
    v_new_status := 'VERIFIED';
  ELSIF p_action = 'REJECT' THEN
    v_new_status := 'FAILED';
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'إجراء غير صالح');
  END IF;

  UPDATE identity_verifications
  SET status = v_new_status,
      rejection_reason = CASE WHEN p_action = 'REJECT' THEN p_rejection_reason ELSE NULL END
  WHERE id = p_verification_id;

  UPDATE profiles
  SET verification_status = v_new_status,
      updated_at = now()
  WHERE id = v_verification.user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE WHEN p_action = 'APPROVE'
      THEN 'تم قبول التحقق بنجاح'
      ELSE 'تم رفض طلب التحقق'
    END
  );
END;
$$;

-- 9.3 admin_generate_vouchers (Batch generation)
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
  v_admin_id        UUID := auth.uid();
  v_generated_codes TEXT[] := '{}';
  v_code            TEXT;
  v_i               INT;
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

-- 9.4 admin_resolve_report (Unified report resolution)
CREATE OR REPLACE FUNCTION admin_resolve_report(
  p_report_id UUID,
  p_resolution TEXT, -- 'RESOLVED_BLOCKED', 'RESOLVED_DELETED', 'DISMISSED', 'RESOLVED'
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_report   RECORD;
BEGIN
  IF NOT is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح');
  END IF;

  SELECT * INTO v_report FROM user_reports WHERE id = p_report_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'البلاغ غير موجود');
  END IF;

  -- Perform actions based on resolution type
  IF p_resolution = 'RESOLVED_BLOCKED' THEN
    PERFORM admin_block_user(v_report.reported_user_id, p_report_id, COALESCE(p_notes, 'تم الحظر بناءً على البلاغ'));
  ELSIF p_resolution = 'RESOLVED_DELETED' THEN
    PERFORM admin_delete_account(v_report.reported_user_id, p_report_id);
  ELSE
    UPDATE user_reports
    SET status = p_resolution,
        resolved_at = now(),
        resolved_by = v_admin_id,
        updated_at = now()
    WHERE id = p_report_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'تم إنهاء ومعالجة البلاغ بنجاح');
END;
$$;

-- 9.5 admin_block_user
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

  INSERT INTO blocked_users (blocker_id, blocked_id)
  VALUES (v_admin_id, p_target_user_id)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  UPDATE profiles
  SET subscription_status = 'CANCELLED',
      bio = '[محظور] ' || COALESCE(bio, ''),
      updated_at = now()
  WHERE id = p_target_user_id;

  IF p_report_id IS NOT NULL THEN
    UPDATE user_reports
    SET status = 'RESOLVED_BLOCKED',
        resolved_at = now(),
        resolved_by = v_admin_id,
        updated_at = now()
    WHERE id = p_report_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'تم حظر المستخدم بنجاح');
END;
$$;

-- 9.6 admin_delete_account
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

  UPDATE profiles
  SET full_name = '[حساب محذوف]',
      bio = NULL,
      job_title = NULL,
      subscription_status = 'CANCELLED',
      verification_status = 'FAILED',
      updated_at = now()
  WHERE id = p_target_user_id;

  DELETE FROM profile_photos WHERE user_id = p_target_user_id;

  UPDATE matches
  SET is_active = false
  WHERE user_one = p_target_user_id OR user_two = p_target_user_id;

  IF p_report_id IS NOT NULL THEN
    UPDATE user_reports
    SET status = 'RESOLVED_DELETED',
        resolved_at = now(),
        resolved_by = v_admin_id,
        updated_at = now()
    WHERE id = p_report_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'تم حذف الحساب بنجاح');
END;
$$;

-- 9.7 admin_dismiss_report
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

  RETURN jsonb_build_object('success', true, 'message', 'تم رفض وحفظ البلاغ');
END;
$$;

-- 9.8 admin_get_dashboard_stats
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

-- ----------------------------------------------------------------------------
-- 10. ROW LEVEL SECURITY (RLS) POLICIES
-- ----------------------------------------------------------------------------

-- Enable Row Level Security on all core tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE voucher_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

-- 10.1 profiles policies
DROP POLICY IF EXISTS "profiles_select_authenticated_not_blocked" ON profiles;
CREATE POLICY "profiles_select_authenticated_not_blocked"
ON profiles FOR SELECT
TO authenticated
USING (
  is_admin()
  OR id = auth.uid()
  OR NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_id = profiles.id)
       OR (blocker_id = profiles.id AND blocked_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
CREATE POLICY "profiles_insert_own"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own"
ON profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id OR is_admin())
WITH CHECK (auth.uid() = id OR is_admin());

-- 10.2 partner_preferences policies
DROP POLICY IF EXISTS "partner_preferences_select_authenticated" ON partner_preferences;
CREATE POLICY "partner_preferences_select_authenticated"
ON partner_preferences FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "partner_preferences_insert_own" ON partner_preferences;
CREATE POLICY "partner_preferences_insert_own"
ON partner_preferences FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "partner_preferences_update_own" ON partner_preferences;
CREATE POLICY "partner_preferences_update_own"
ON partner_preferences FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 10.3 profile_photos policies
DROP POLICY IF EXISTS "profile_photos_select_not_blocked" ON profile_photos;
CREATE POLICY "profile_photos_select_not_blocked"
ON profile_photos FOR SELECT
TO authenticated
USING (
  is_admin()
  OR user_id = auth.uid()
  OR NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_id = profile_photos.user_id)
       OR (blocker_id = profile_photos.user_id AND blocked_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "profile_photos_insert_own" ON profile_photos;
CREATE POLICY "profile_photos_insert_own"
ON profile_photos FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "profile_photos_update_own" ON profile_photos;
CREATE POLICY "profile_photos_update_own"
ON profile_photos FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "profile_photos_delete_own" ON profile_photos;
CREATE POLICY "profile_photos_delete_own"
ON profile_photos FOR DELETE
TO authenticated
USING (auth.uid() = user_id OR is_admin());

-- 10.4 likes policies
DROP POLICY IF EXISTS "likes_select_involved" ON likes;
CREATE POLICY "likes_select_involved"
ON likes FOR SELECT
TO authenticated
USING (auth.uid() = from_user_id OR auth.uid() = to_user_id OR is_admin());

DROP POLICY IF EXISTS "likes_insert_own" ON likes;
CREATE POLICY "likes_insert_own"
ON likes FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = from_user_id);

DROP POLICY IF EXISTS "likes_delete_own" ON likes;
CREATE POLICY "likes_delete_own"
ON likes FOR DELETE
TO authenticated
USING (auth.uid() = from_user_id);

-- 10.5 matches policies
DROP POLICY IF EXISTS "matches_select_participants" ON matches;
CREATE POLICY "matches_select_participants"
ON matches FOR SELECT
TO authenticated
USING (auth.uid() IN (user_one, user_two) OR is_admin());

-- 10.6 blocked_users policies
DROP POLICY IF EXISTS "blocked_users_full_control_blocker" ON blocked_users;
CREATE POLICY "blocked_users_full_control_blocker"
ON blocked_users FOR ALL
TO authenticated
USING (auth.uid() = blocker_id OR is_admin())
WITH CHECK (auth.uid() = blocker_id OR is_admin());

-- 10.7 identity_verifications policies
DROP POLICY IF EXISTS "verif_select_own_or_admin" ON identity_verifications;
CREATE POLICY "verif_select_own_or_admin"
ON identity_verifications FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "verif_insert_own" ON identity_verifications;
CREATE POLICY "verif_insert_own"
ON identity_verifications FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "verif_update_own_or_admin" ON identity_verifications;
CREATE POLICY "verif_update_own_or_admin"
ON identity_verifications FOR UPDATE
TO authenticated
USING (auth.uid() = user_id OR is_admin())
WITH CHECK (auth.uid() = user_id OR is_admin());

-- 10.8 subscriptions policies
DROP POLICY IF EXISTS "subscriptions_select_own_or_admin" ON subscriptions;
CREATE POLICY "subscriptions_select_own_or_admin"
ON subscriptions FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR is_admin());

DROP POLICY IF EXISTS "subscriptions_insert_own_or_admin" ON subscriptions;
CREATE POLICY "subscriptions_insert_own_or_admin"
ON subscriptions FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id OR is_admin());

-- 10.9 conversations policies
DROP POLICY IF EXISTS "conv_select_participant_or_admin" ON conversations;
CREATE POLICY "conv_select_participant_or_admin"
ON conversations FOR SELECT
TO authenticated
USING (
  is_admin()
  OR (
    (auth.uid() = user_one OR auth.uid() = user_two)
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND verification_status = 'VERIFIED'
    )
  )
);

DROP POLICY IF EXISTS "conv_insert_participant" ON conversations;
CREATE POLICY "conv_insert_participant"
ON conversations FOR INSERT
TO authenticated
WITH CHECK (
  (auth.uid() = user_one OR auth.uid() = user_two)
  AND EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND verification_status = 'VERIFIED'
  )
);

DROP POLICY IF EXISTS "conv_update_participant" ON conversations;
CREATE POLICY "conv_update_participant"
ON conversations FOR UPDATE
TO authenticated
USING (auth.uid() = user_one OR auth.uid() = user_two);

-- 10.10 messages policies
DROP POLICY IF EXISTS "msg_select_participant_or_admin" ON messages;
CREATE POLICY "msg_select_participant_or_admin"
ON messages FOR SELECT
TO authenticated
USING (
  is_admin()
  OR (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = conversation_id
        AND (c.user_one = auth.uid() OR c.user_two = auth.uid())
    )
    AND NOT EXISTS (
      SELECT 1 FROM blocked_users
      WHERE (blocker_id = auth.uid() AND blocked_id IN (
          SELECT CASE WHEN user_one = auth.uid() THEN user_two ELSE user_one END
          FROM conversations WHERE id = conversation_id
        ))
         OR (blocked_id = auth.uid() AND blocker_id IN (
          SELECT CASE WHEN user_one = auth.uid() THEN user_two ELSE user_one END
          FROM conversations WHERE id = conversation_id
        ))
    )
  )
);

DROP POLICY IF EXISTS "msg_insert_own" ON messages;
CREATE POLICY "msg_insert_own"
ON messages FOR INSERT
TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = conversation_id
      AND (c.user_one = auth.uid() OR c.user_two = auth.uid())
  )
  AND EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
      AND verification_status = 'VERIFIED'
  )
);

DROP POLICY IF EXISTS "msg_update_read" ON messages;
CREATE POLICY "msg_update_read"
ON messages FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = conversation_id
      AND (c.user_one = auth.uid() OR c.user_two = auth.uid())
  )
);

-- 10.11 voucher_codes policies
DROP POLICY IF EXISTS "voucher_codes_select" ON voucher_codes;
CREATE POLICY "voucher_codes_select"
ON voucher_codes FOR SELECT
TO authenticated
USING (auth.uid() = used_by OR is_admin());

DROP POLICY IF EXISTS "voucher_codes_admin_manage" ON voucher_codes;
CREATE POLICY "voucher_codes_admin_manage"
ON voucher_codes FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- 10.12 user_reports policies
DROP POLICY IF EXISTS "user_reports_insert_own" ON user_reports;
CREATE POLICY "user_reports_insert_own"
ON user_reports FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "user_reports_select_own_or_admin" ON user_reports;
CREATE POLICY "user_reports_select_own_or_admin"
ON user_reports FOR SELECT
TO authenticated
USING (auth.uid() = reporter_id OR is_admin());

DROP POLICY IF EXISTS "user_reports_admin_update" ON user_reports;
CREATE POLICY "user_reports_admin_update"
ON user_reports FOR UPDATE
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- 10.13 admin_users policies
DROP POLICY IF EXISTS "admin_users_select_own" ON admin_users;
CREATE POLICY "admin_users_select_own"
ON admin_users FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- 11. STORAGE BUCKETS & POLICIES
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('profile-photos', 'profile-photos', true),
  ('identity-documents', 'identity-documents', false)
ON CONFLICT (id) DO NOTHING;

-- Profile Photos (Public CDN)
DROP POLICY IF EXISTS "Public can view profile photos" ON storage.objects;
CREATE POLICY "Public can view profile photos"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'profile-photos');

DROP POLICY IF EXISTS "Users can upload their own profile photos" ON storage.objects;
CREATE POLICY "Users can upload their own profile photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can delete their own profile photos" ON storage.objects;
CREATE POLICY "Users can delete their own profile photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Identity Documents (Strict Private & Admin Access)
DROP POLICY IF EXISTS "Users can upload their own identity documents" ON storage.objects;
CREATE POLICY "Users can upload their own identity documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'identity-documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users and Admins can view identity documents" ON storage.objects;
CREATE POLICY "Users and Admins can view identity documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'identity-documents'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR is_admin())
);

-- ----------------------------------------------------------------------------
-- 12. SUPABASE REALTIME CONFIGURATION
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
  END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 13. SEED INITIAL SUPER ADMIN & PROVISIONING TRIGGER
-- ----------------------------------------------------------------------------
-- Automatic trigger to elevate target admin emails to SUPER_ADMIN upon signup
CREATE OR REPLACE FUNCTION on_auth_user_created_assign_admin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF LOWER(NEW.email) IN ('admin@gawezeny.com', 'superadmin@gawezeny.com') THEN
    INSERT INTO admin_users (id, email, display_name, role)
    VALUES (NEW.id, NEW.email, 'المدير العام (Super Admin)', 'SUPER_ADMIN')
    ON CONFLICT (id) DO UPDATE SET role = 'SUPER_ADMIN';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_auto_assign_admin ON auth.users;
CREATE TRIGGER trigger_auto_assign_admin
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION on_auth_user_created_assign_admin();

-- Link existing auth user if admin@gawezeny.com is already registered
DO $$
DECLARE
  v_admin_email TEXT := 'admin@gawezeny.com';
  v_user_id     UUID;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE LOWER(email) = LOWER(v_admin_email) LIMIT 1;
  IF v_user_id IS NOT NULL THEN
    INSERT INTO admin_users (id, email, display_name, role)
    VALUES (v_user_id, v_admin_email, 'المدير العام (Super Admin)', 'SUPER_ADMIN')
    ON CONFLICT (id) DO UPDATE SET role = 'SUPER_ADMIN', email = v_admin_email;
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 14. SEED OFFICIAL PRODUCTION TEST VOUCHERS
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
