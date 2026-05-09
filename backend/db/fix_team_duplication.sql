-- 1. Clean up existing duplicates (keep the most recent one for each coach)
DELETE FROM public.teams a
USING public.teams b
WHERE a.id < b.id
  AND a.coach_id = b.coach_id;

-- 2. Add unique constraint to coach_id
ALTER TABLE public.teams DROP CONSTRAINT IF EXISTS teams_coach_id_key;
ALTER TABLE public.teams 
  ADD CONSTRAINT teams_coach_id_key UNIQUE (coach_id);

-- 3. Update the trigger function to use UPSERT logic
CREATE OR REPLACE FUNCTION public.ensure_coach_team()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role = 'coach' AND NEW.team_name IS NOT NULL THEN
    INSERT INTO public.teams (coach_id, name)
    VALUES (NEW.id, NEW.team_name)
    ON CONFLICT (coach_id) DO UPDATE SET name = EXCLUDED.name;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
