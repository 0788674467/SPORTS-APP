-- ============================================================
--  DEBUG SCRIPT: Open Access & RLS Reset
--  Run this in Supabase SQL Editor.
-- ============================================================

-- 1. Temporarily disable RLS to rule it out as the blocker
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 2. Drop all policies to start fresh
DROP POLICY IF EXISTS "Admins can read all" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update all" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own" ON public.profiles;
DROP POLICY IF EXISTS "profiles: own row" ON public.profiles;

-- 3. Create a "Full Access" policy for authenticated users (for testing)
CREATE POLICY "Full access for authenticated users" ON public.profiles
  FOR ALL USING (auth.role() = 'authenticated');

-- 4. Re-enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 5. Grant permissions to service_role and authenticated
GRANT ALL ON public.profiles TO authenticated, service_role;
