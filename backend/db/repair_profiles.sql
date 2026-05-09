-- ============================================================
--  REPAIR SCRIPT: Fix Profiles & Sync Trigger
--  Run this in Supabase SQL Editor to resolve the 500 error.
-- ============================================================

-- 1. Drop old table and dependents to ensure clean slate
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 2. Create the correct profiles table for the app
CREATE TABLE public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name     TEXT,
  email         TEXT,
  phone         TEXT,
  role          TEXT DEFAULT 'spectator',
  approval_status TEXT DEFAULT 'approved', -- 'pending' for coaches/referees
  avatar_url    TEXT,
  team_name     TEXT, -- Store team name for coaches during signup
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 4. Recreate the sync function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role, approval_status, team_name, phone)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'full_name',
    NEW.email,
    NEW.raw_user_meta_data ->> 'role',
    COALESCE(NEW.raw_user_meta_data ->> 'approval_status', 
             CASE WHEN (NEW.raw_user_meta_data ->> 'role') IN ('coach', 'referee') THEN 'pending' ELSE 'approved' END),
    NEW.raw_user_meta_data ->> 'team_name',
    NEW.raw_user_meta_data ->> 'phone'
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    approval_status = EXCLUDED.approval_status,
    team_name = EXCLUDED.team_name,
    phone = EXCLUDED.phone,
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Re-bind the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 6. Helper RPC for approvals
CREATE OR REPLACE FUNCTION approve_user(user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles SET approval_status = 'approved' WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
