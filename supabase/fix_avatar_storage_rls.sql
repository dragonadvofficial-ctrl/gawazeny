-- ============================================================================
-- MIGRATION: Fix Profile Photos Storage Bucket, RLS Policies & Columns
-- PROJECT: جوزيني يا ماما (Gawzeeny)
-- RUN THIS IN: Supabase Dashboard > SQL Editor
-- ============================================================================

-- 1. Ensure 'profile-photos' bucket exists and is marked public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-photos',
  'profile-photos',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

-- 2. Ensure 'identity-documents' bucket exists (private)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'identity-documents',
  'identity-documents',
  false,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. STORAGE.OBJECTS RLS POLICIES FOR 'profile-photos'
-- ----------------------------------------------------------------------------

-- Enable RLS on storage.objects (if not already enabled)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- SELECT Policy: Public can view profile photos (needed for viewing and public CDN)
DROP POLICY IF EXISTS "Public can view profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view profile photos" ON storage.objects;
CREATE POLICY "Public can view profile photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-photos');

-- INSERT Policy: Authenticated users can upload to their own folder: userId/...
DROP POLICY IF EXISTS "Users can upload their own profile photos" ON storage.objects;
CREATE POLICY "Users can upload their own profile photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- UPDATE Policy: Authenticated users can update/overwrite their own profile photos (CRITICAL for upsert: true)
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

-- DELETE Policy: Authenticated users can delete their own profile photos
DROP POLICY IF EXISTS "Users can delete their own profile photos" ON storage.objects;
CREATE POLICY "Users can delete their own profile photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ----------------------------------------------------------------------------
-- 4. PROFILES & PROFILE_PHOTOS DATABASE SCHEMA UPDATES
-- ----------------------------------------------------------------------------

-- Ensure photo_url column exists on profiles table for direct access
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Ensure profile_photos table has unique constraint on (user_id, is_primary) or user_id for primary photos
CREATE INDEX IF NOT EXISTS idx_profile_photos_user_id ON profile_photos(user_id);
CREATE INDEX IF NOT EXISTS idx_profile_photos_is_primary ON profile_photos(user_id, is_primary);

-- Create unique index for primary photo per user (ensures upsert compatibility)
DROP INDEX IF EXISTS idx_profile_photos_unique_primary;
CREATE UNIQUE INDEX idx_profile_photos_unique_primary
ON profile_photos(user_id)
WHERE is_primary = true;

-- Grant permissions to authenticated and anon roles on storage
GRANT ALL ON storage.buckets TO authenticated;
GRANT SELECT ON storage.buckets TO anon;
GRANT ALL ON storage.objects TO authenticated;
GRANT SELECT ON storage.objects TO anon;
