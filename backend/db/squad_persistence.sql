-- 1. Update Players Table Schema
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS reg_no TEXT;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS university_id TEXT;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS course TEXT;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS year_of_study TEXT;

-- Update Position Constraint
ALTER TABLE public.players DROP CONSTRAINT IF EXISTS players_position_check;
ALTER TABLE public.players ADD CONSTRAINT players_position_check 
  CHECK (position IN ('GK', 'DEF', 'MID', 'FWD', 'DF', 'MF', 'FW'));

-- 2. Ensure Coach Teams exist
-- Every profile with role='coach' should have a team record.
-- We can use a function to auto-create teams if they don't exist.
CREATE OR REPLACE FUNCTION public.ensure_coach_team()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role = 'coach' AND NEW.team_name IS NOT NULL THEN
    INSERT INTO public.teams (coach_id, name)
    VALUES (NEW.id, NEW.team_name)
    ON CONFLICT (name) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_ensure_coach_team ON public.profiles;
CREATE TRIGGER trg_ensure_coach_team
  AFTER INSERT OR UPDATE OF role, team_name ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.ensure_coach_team();

-- Backfill existing coaches
INSERT INTO public.teams (coach_id, name)
SELECT id, team_name FROM public.profiles 
WHERE role = 'coach' AND team_name IS NOT NULL
ON CONFLICT (name) DO NOTHING;

-- 3. Storage Setup (Supabase Storage)
-- Note: This requires the storage extension to be enabled.

-- Player Photos Bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('player_photos', 'player_photos', true) ON CONFLICT (id) DO NOTHING;
-- Team Logos Bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('team_logos', 'team_logos', true) ON CONFLICT (id) DO NOTHING;
-- Avatars Bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;

-- STORAGE POLICIES
-- 1. Selection (Public Read)
DROP POLICY IF EXISTS "Public Read player_photos" ON storage.objects;
CREATE POLICY "Public Read player_photos" ON storage.objects FOR SELECT USING (bucket_id = 'player_photos');

DROP POLICY IF EXISTS "Public Read team_logos" ON storage.objects;
CREATE POLICY "Public Read team_logos" ON storage.objects FOR SELECT USING (bucket_id = 'team_logos');

DROP POLICY IF EXISTS "Public Read avatars" ON storage.objects;
CREATE POLICY "Public Read avatars" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');

-- 2. Insertion (Authenticated Only)
DROP POLICY IF EXISTS "Auth Insert player_photos" ON storage.objects;
CREATE POLICY "Auth Insert player_photos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'player_photos' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Auth Insert team_logos" ON storage.objects;
CREATE POLICY "Auth Insert team_logos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'team_logos' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Auth Insert avatars" ON storage.objects;
CREATE POLICY "Auth Insert avatars" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

-- 3. Update/Management (Authenticated Only)
DROP POLICY IF EXISTS "Auth Update player_photos" ON storage.objects;
CREATE POLICY "Auth Update player_photos" ON storage.objects FOR UPDATE WITH CHECK (bucket_id = 'player_photos' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Auth Update team_logos" ON storage.objects;
CREATE POLICY "Auth Update team_logos" ON storage.objects FOR UPDATE WITH CHECK (bucket_id = 'team_logos' AND auth.role() = 'authenticated');

-- 4. RLS for Players
-- Coaches can manage players for their own team
DROP POLICY IF EXISTS "Coaches manage own team players" ON public.players;
CREATE POLICY "Coaches manage own team players" ON public.players
FOR ALL USING (
  team_id IN (SELECT id FROM public.teams WHERE coach_id = auth.uid())
);

-- Public read for players (for lineups)
DROP POLICY IF EXISTS "Public read players" ON public.players;
CREATE POLICY "Public read players" ON public.players FOR SELECT USING (true);

-- ─── Squad Submission Migration ───────────────────────────────────────────────
-- Run this in your Supabase SQL editor ONCE.

-- 5. Add squad submission columns to teams
ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS submission_status TEXT NOT NULL DEFAULT 'draft'
  CHECK (submission_status IN ('draft', 'submitted', 'approved', 'rejected'));

ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ;

ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS rejection_note TEXT;

-- 6. RLS: Coaches can update their own team row (to submit squad)
--    Admins can update any team row (to approve/reject)
DROP POLICY IF EXISTS "Coaches and admins can update teams" ON public.teams;
CREATE POLICY "Coaches and admins can update teams" ON public.teams
  FOR UPDATE USING (
    coach_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 7. Coaches can read their own team row; everyone can read for fixtures/standings
DROP POLICY IF EXISTS "Public read teams" ON public.teams;
CREATE POLICY "Public read teams" ON public.teams
  FOR SELECT USING (true);

-- ─── FK Constraint: teams.coach_id → profiles.id ─────────────────────────────
-- This allows PostgREST to JOIN teams with profiles so coach names appear.
-- Run ONCE in Supabase SQL editor.

-- First ensure all coach profiles exist (backfill from auth.users if needed)
-- The profiles table should already have rows created by your sign-up trigger.

ALTER TABLE public.teams
  DROP CONSTRAINT IF EXISTS teams_coach_id_fkey;

ALTER TABLE public.teams
  ADD CONSTRAINT teams_coach_id_fkey
  FOREIGN KEY (coach_id)
  REFERENCES public.profiles(id)
  ON DELETE SET NULL;

-- Verify: this query should now return coach names
-- SELECT t.name, p.full_name FROM teams t JOIN profiles p ON t.coach_id = p.id;

-- ─── Venues Table ─────────────────────────────────────────────────────────────
-- Run ONCE in Supabase SQL editor.

CREATE TABLE IF NOT EXISTS public.venues (
  id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT         NOT NULL,
  location   TEXT,
  capacity   INT,
  is_active  BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ  DEFAULT NOW()
);

ALTER TABLE public.venues ENABLE ROW LEVEL SECURITY;

-- Seed default venues (safe to re-run)
INSERT INTO public.venues (name, location) VALUES
  ('MMU Main Ground', 'Main Campus'),
  ('Court A', 'Sports Complex'),
  ('Court B', 'Sports Complex')
ON CONFLICT DO NOTHING;

-- Public read
DROP POLICY IF EXISTS "Public read venues" ON public.venues;
CREATE POLICY "Public read venues" ON public.venues
  FOR SELECT USING (true);

-- Admin full CRUD
DROP POLICY IF EXISTS "Admin manage venues" ON public.venues;
CREATE POLICY "Admin manage venues" ON public.venues
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
