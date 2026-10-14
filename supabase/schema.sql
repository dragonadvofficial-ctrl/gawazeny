-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- DATABASE: Supabase PostgreSQL Core Schema & Row Level Security Setup
-- DESCRIPTION: Complete, copy-pasteable database schema with enums, tables,
--              triggers, indexes, and comprehensive RLS policies.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EXTENSIONS
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 2. CUSTOM ENUMS
-- ----------------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE gender_type AS ENUM (
    'MALE',
    'FEMALE'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE marital_status_type AS ENUM (
    'SINGLE',
    'DIVORCED',
    'WIDOWED'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE verification_status_type AS ENUM (
    'UNVERIFIED',
    'PENDING',
    'VERIFIED',
    'FAILED',
    'MANUAL_REVIEW'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE subscription_status_type AS ENUM (
    'FREE',
    'PENDING_PAYMENT',
    'ACTIVE',
    'EXPIRED',
    'CANCELLED'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE subscription_plan_tier AS ENUM (
    'MONTHLY_200',
    'QUARTERLY_500',
    'SEMI_ANNUAL_900',
    'ANNUAL_1500',
    'BUNDLE_FB_1000'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ----------------------------------------------------------------------------
-- 3. CORE TABLES
-- ----------------------------------------------------------------------------

-- PROFILES TABLE
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  gender gender_type NOT NULL,
  birth_date DATE NOT NULL,
  age INT,
  nationality TEXT NOT NULL,
  residence_city TEXT NOT NULL,
  marital_status marital_status_type NOT NULL,
  job_title TEXT,
  education_level TEXT,
  height_cm INT,
  weight_kg INT,
  smoker BOOLEAN DEFAULT false,
  prays TEXT,
  wants_children BOOLEAN DEFAULT true,
  bio TEXT,
  verification_status verification_status_type DEFAULT 'UNVERIFIED',
  subscription_status subscription_status_type DEFAULT 'FREE',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
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
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  min_age INT DEFAULT 18,
  max_age INT DEFAULT 60,
  acceptable_marital_statuses marital_status_type[] DEFAULT '{}',
  acceptable_cities TEXT[] DEFAULT '{}',
  must_pray BOOLEAN DEFAULT false,
  accepts_smokers BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- PROFILE PHOTOS TABLE
CREATE TABLE IF NOT EXISTS profile_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- LIKES TABLE
CREATE TABLE IF NOT EXISTS likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  to_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT unique_like_pair UNIQUE (from_user_id, to_user_id),
  CONSTRAINT no_self_like CHECK (from_user_id <> to_user_id)
);

-- MATCHES TABLE
CREATE TABLE IF NOT EXISTS matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_one UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  user_two UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT unique_match_pair UNIQUE (user_one, user_two),
  CONSTRAINT ordered_users CHECK (user_one < user_two)
);

-- BLOCKED USERS TABLE
CREATE TABLE IF NOT EXISTS blocked_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT unique_block_pair UNIQUE (blocker_id, blocked_id),
  CONSTRAINT no_self_block CHECK (blocker_id <> blocked_id)
);

-- IDENTITY VERIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS identity_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  id_card_image_url TEXT NOT NULL,
  selfie_image_url TEXT NOT NULL,
  extracted_name TEXT,
  extracted_birth_date DATE,
  face_match_score NUMERIC(5,2),
  liveness_passed BOOLEAN DEFAULT false,
  status verification_status_type DEFAULT 'PENDING',
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 4. PERFORMANCE & LOOKUP INDEXES
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_profiles_gender ON profiles(gender);
CREATE INDEX IF NOT EXISTS idx_profiles_residence_city ON profiles(residence_city);
CREATE INDEX IF NOT EXISTS idx_profiles_marital_status ON profiles(marital_status);
CREATE INDEX IF NOT EXISTS idx_profiles_verification_status ON profiles(verification_status);

CREATE INDEX IF NOT EXISTS idx_partner_preferences_user_id ON partner_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_profile_photos_user_id ON profile_photos(user_id);
CREATE INDEX IF NOT EXISTS idx_profile_photos_is_primary ON profile_photos(user_id, is_primary);

CREATE INDEX IF NOT EXISTS idx_likes_from_user ON likes(from_user_id);
CREATE INDEX IF NOT EXISTS idx_likes_to_user ON likes(to_user_id);

CREATE INDEX IF NOT EXISTS idx_matches_user_one ON matches(user_one);
CREATE INDEX IF NOT EXISTS idx_matches_user_two ON matches(user_two);
CREATE INDEX IF NOT EXISTS idx_matches_pair ON matches(user_one, user_two);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked ON blocked_users(blocked_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_pair ON blocked_users(blocker_id, blocked_id);

CREATE INDEX IF NOT EXISTS idx_identity_verifications_user ON identity_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_identity_verifications_status ON identity_verifications(status);

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

-- ----------------------------------------------------------------------------
-- 6. AUTOMATIC MATCH TRIGGER (AFTER INSERT ON likes)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_new_like()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if a reciprocal like already exists (to_user_id liked from_user_id)
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
    ON CONFLICT (user_one, user_two) DO NOTHING;
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
-- 7. ROW LEVEL SECURITY (RLS) CONFIGURATION
-- ----------------------------------------------------------------------------

-- Enable Row Level Security on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity_verifications ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- RLS POLICIES: profiles
-- ----------------------------------------------------------------------------

-- SELECT: Authenticated users can view profiles EXCEPT if blocked in either direction
DROP POLICY IF EXISTS "profiles_select_authenticated_not_blocked" ON profiles;
CREATE POLICY "profiles_select_authenticated_not_blocked"
ON profiles FOR SELECT
TO authenticated
USING (
  id = auth.uid()
  OR NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_id = profiles.id)
       OR (blocker_id = profiles.id AND blocked_id = auth.uid())
  )
);

-- INSERT: Authenticated users can only create their own profile
DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
CREATE POLICY "profiles_insert_own"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- UPDATE: Authenticated users can only update their own profile
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own"
ON profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- RLS POLICIES: partner_preferences
-- ----------------------------------------------------------------------------

-- SELECT: Authenticated users can view partner preferences for matching algorithms
DROP POLICY IF EXISTS "partner_preferences_select_authenticated" ON partner_preferences;
CREATE POLICY "partner_preferences_select_authenticated"
ON partner_preferences FOR SELECT
TO authenticated
USING (true);

-- INSERT: Users can only set their own partner preferences
DROP POLICY IF EXISTS "partner_preferences_insert_own" ON partner_preferences;
CREATE POLICY "partner_preferences_insert_own"
ON partner_preferences FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- UPDATE: Users can only update their own partner preferences
DROP POLICY IF EXISTS "partner_preferences_update_own" ON partner_preferences;
CREATE POLICY "partner_preferences_update_own"
ON partner_preferences FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- RLS POLICIES: profile_photos
-- ----------------------------------------------------------------------------

-- SELECT: Authenticated users can view photos of profiles that have not blocked each other
DROP POLICY IF EXISTS "profile_photos_select_not_blocked" ON profile_photos;
CREATE POLICY "profile_photos_select_not_blocked"
ON profile_photos FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_id = profile_photos.user_id)
       OR (blocker_id = profile_photos.user_id AND blocked_id = auth.uid())
  )
);

-- INSERT: Users can only upload photos for their own profile
DROP POLICY IF EXISTS "profile_photos_insert_own" ON profile_photos;
CREATE POLICY "profile_photos_insert_own"
ON profile_photos FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- UPDATE: Users can only update their own photos (e.g. set primary)
DROP POLICY IF EXISTS "profile_photos_update_own" ON profile_photos;
CREATE POLICY "profile_photos_update_own"
ON profile_photos FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- DELETE: Users can only delete their own photos
DROP POLICY IF EXISTS "profile_photos_delete_own" ON profile_photos;
CREATE POLICY "profile_photos_delete_own"
ON profile_photos FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- RLS POLICIES: likes
-- ----------------------------------------------------------------------------

-- SELECT: Users can only see likes sent by themselves
DROP POLICY IF EXISTS "likes_select_own" ON likes;
CREATE POLICY "likes_select_own"
ON likes FOR SELECT
TO authenticated
USING (auth.uid() = from_user_id);

-- INSERT: Users can only insert likes where from_user_id = auth.uid()
DROP POLICY IF EXISTS "likes_insert_own" ON likes;
CREATE POLICY "likes_insert_own"
ON likes FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = from_user_id);

-- DELETE: Users can revoke/cancel their own like
DROP POLICY IF EXISTS "likes_delete_own" ON likes;
CREATE POLICY "likes_delete_own"
ON likes FOR DELETE
TO authenticated
USING (auth.uid() = from_user_id);

-- ----------------------------------------------------------------------------
-- RLS POLICIES: matches
-- ----------------------------------------------------------------------------

-- SELECT: Users can only see matches where they are one of the two participants
DROP POLICY IF EXISTS "matches_select_participants" ON matches;
CREATE POLICY "matches_select_participants"
ON matches FOR SELECT
TO authenticated
USING (auth.uid() IN (user_one, user_two));

-- ----------------------------------------------------------------------------
-- RLS POLICIES: blocked_users
-- ----------------------------------------------------------------------------

-- ALL: Full control (SELECT, INSERT, UPDATE, DELETE) allowed only where auth.uid() = blocker_id
DROP POLICY IF EXISTS "blocked_users_full_control_blocker" ON blocked_users;
CREATE POLICY "blocked_users_full_control_blocker"
ON blocked_users FOR ALL
TO authenticated
USING (auth.uid() = blocker_id)
WITH CHECK (auth.uid() = blocker_id);

-- ----------------------------------------------------------------------------
-- RLS POLICIES: identity_verifications
-- ----------------------------------------------------------------------------

-- SELECT: Users can only inspect their own verification status
DROP POLICY IF EXISTS "identity_verifications_select_own" ON identity_verifications;
CREATE POLICY "identity_verifications_select_own"
ON identity_verifications FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- INSERT: Users can only submit verification records for themselves
DROP POLICY IF EXISTS "identity_verifications_insert_own" ON identity_verifications;
CREATE POLICY "identity_verifications_insert_own"
ON identity_verifications FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 8. STORAGE BUCKETS SETUP & SECURITY POLICIES
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('profile-photos', 'profile-photos', true),
  ('identity-documents', 'identity-documents', false)
ON CONFLICT (id) DO NOTHING;

-- Profile Photos Bucket Policies
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

-- Allow users to overwrite/update their own profile photos (needed for upsert)
DROP POLICY IF EXISTS "Users can update their own profile photos" ON storage.objects;
CREATE POLICY "Users can update their own profile photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Identity Documents Bucket Policies (Strict Private)
DROP POLICY IF EXISTS "Users can upload their own identity documents" ON storage.objects;
CREATE POLICY "Users can upload their own identity documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'identity-documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can view their own identity documents" ON storage.objects;
CREATE POLICY "Users can view their own identity documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'identity-documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
