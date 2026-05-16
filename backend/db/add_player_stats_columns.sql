-- ─── Add player performance stat columns to players table ────────────────────
-- Run this in your Supabase SQL Editor

ALTER TABLE players
  ADD COLUMN IF NOT EXISTS goals        INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS assists      INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS yellow_cards INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS red_cards    INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS matches_played INTEGER NOT NULL DEFAULT 0;

-- Allow coaches to update their own players' stats
CREATE POLICY IF NOT EXISTS "Coaches can update player stats"
  ON players FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM teams
      WHERE teams.id = players.team_id
        AND teams.coach_id = auth.uid()
    )
  );

-- Allow referees to update stats (goals/assists during match)
CREATE POLICY IF NOT EXISTS "Referees can update player stats"
  ON players FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'referee'
    )
  );

-- Allow admins full access
CREATE POLICY IF NOT EXISTS "Admins can update player stats"
  ON players FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );
