-- ─────────────────────────────────────────────────────────────────────────────
-- ADD LIVE MATCH STATE COLUMNS TO scheduled_matches
-- Run this in your Supabase SQL Editor → Dashboard → SQL Editor → New Query
-- This enables events (scorers, cards etc.) and minute to persist across devices
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Add current_minute column (tracks elapsed match time)
ALTER TABLE public.scheduled_matches
  ADD COLUMN IF NOT EXISTS current_minute INT NOT NULL DEFAULT 0;

-- 2. Add events column (stores all match events as JSON array)
ALTER TABLE public.scheduled_matches
  ADD COLUMN IF NOT EXISTS events JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 3. Update the RLS policy to also allow referees to update scores/events
--    (previously only admins could update)
DROP POLICY IF EXISTS "referee update live match" ON public.scheduled_matches;

CREATE POLICY "referee update live match"
  ON public.scheduled_matches FOR UPDATE
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') IN ('admin', 'referee')
  );

-- Done! Now the Flutter app can save and restore events + minute across all devices.
