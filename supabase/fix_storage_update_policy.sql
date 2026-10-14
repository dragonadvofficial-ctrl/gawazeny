-- ============================================================================
-- MIGRATION: Add missing UPDATE policy for profile-photos storage bucket
-- DESCRIPTION: Without this policy, upsert (overwrite) on storage objects 
--              fails with 403 Unauthorized. This policy allows authenticated
--              users to update/overwrite their own profile photos.
-- RUN THIS ON: Supabase Dashboard > SQL Editor
-- ============================================================================

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
