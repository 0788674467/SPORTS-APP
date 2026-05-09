-- Create the profiles table in public schema
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  role TEXT,
  approval_status TEXT DEFAULT 'pending',
  team_name TEXT,
  phone TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Admins can read all profiles
CREATE POLICY "Admins can read all" ON public.profiles
  FOR SELECT USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  );

-- Users can read their own profile
CREATE POLICY "Users can read own" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- Sync function to handle auth.users metadata changes
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, approval_status, team_name, phone)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'full_name',
    NEW.raw_user_meta_data ->> 'role',
    NEW.raw_user_meta_data ->> 'approval_status',
    NEW.raw_user_meta_data ->> 'team_name',
    NEW.raw_user_meta_data ->> 'phone'
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    approval_status = EXCLUDED.approval_status,
    team_name = EXCLUDED.team_name,
    phone = EXCLUDED.phone,
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the sync function on user signup/update
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Helper RPC to approve user (for the app to call)
CREATE OR REPLACE FUNCTION approve_user(user_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Update public profiles status
  UPDATE public.profiles SET approval_status = 'approved' WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
