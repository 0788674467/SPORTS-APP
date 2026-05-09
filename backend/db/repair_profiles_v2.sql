-- ============================================================
--  REPAIR SCRIPT (v2): Robust RLS & Access Fix
--  Run this in Supabase SQL Editor.
-- ============================================================

-- 1. Ensure the profiles table is correct
-- (If you already ran this, it will just re-enable policies)

-- 2. UPDATE RLS POLICY: Make it check the database instead of the JWT
-- This ensures that as soon as a user is promoted to admin, they gain access
-- WITHOUT needing to log out and log back in.

DROP POLICY IF EXISTS "Admins can read all" ON public.profiles;

CREATE POLICY "Admins can read all" ON public.profiles
  FOR SELECT USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- Also ensure admins can update (approve) other profiles
DROP POLICY IF EXISTS "Admins can update all" ON public.profiles;
CREATE POLICY "Admins can update all" ON public.profiles
  FOR UPDATE USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- 3. Ensure the Sync Trigger handles "null" roles correctly
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role, approval_status, team_name, phone)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'full_name',
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'role', 'spectator'),
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
