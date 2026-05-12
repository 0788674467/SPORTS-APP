-- ============================================================
-- FIX: Profile Pictures - RLS + Storage
-- Run this in Supabase SQL Editor to fix avatar display issues
-- ============================================================

-- 1. Drop old restrictive policy that blocks admin from reading all profiles
DROP POLICY IF EXISTS "profiles: own row" ON public.profiles;
DROP POLICY IF EXISTS "Admins can read all" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own" ON public.profiles;

-- 2. Create correct, comprehensive RLS policies
-- Allow anyone authenticated to SELECT all profiles (needed for admin to see coaches/referees)
CREATE POLICY "Authenticated users can read all profiles"
  ON public.profiles FOR SELECT
  USING (auth.role() = 'authenticated');

-- Allow users to INSERT/UPDATE their own profile
CREATE POLICY "Users can manage own profile"
  ON public.profiles FOR ALL
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Allow admins (role = 'admin') to manage ALL profiles
CREATE POLICY "Admins can manage all profiles"
  ON public.profiles FOR ALL
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  )
  WITH CHECK (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  );

-- 3. Make the avatars storage bucket public (so URLs work without auth)
-- Run this if the bucket exists already:
UPDATE storage.buckets SET public = TRUE WHERE id = 'avatars';

-- If bucket doesn't exist, create it:
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', TRUE)
ON CONFLICT (id) DO UPDATE SET public = TRUE;

-- 4. Storage RLS: Allow authenticated users to upload to their own folder
DROP POLICY IF EXISTS "Avatar upload policy" ON storage.objects;
CREATE POLICY "Avatar upload policy"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid() IS NOT NULL AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Avatar update policy" ON storage.objects;
CREATE POLICY "Avatar update policy"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars' AND
    auth.uid() IS NOT NULL AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow public read of all avatars (since bucket is public)
DROP POLICY IF EXISTS "Avatar public read" ON storage.objects;
CREATE POLICY "Avatar public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- 5. Ensure profiles table has email and avatar_url columns (add if missing)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS avatar_index INT DEFAULT 0;

-- 6. Backfill email from auth.users for existing profiles
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id AND p.email IS NULL;
