-- ─── Match Reports Table ──────────────────────────────────────────────────────
-- Stores the full official match report submitted by the referee after each match.
-- Run this in your Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS match_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fixture_id    TEXT NOT NULL,                          -- references scheduled_matches.id
  home_team     TEXT NOT NULL,
  away_team     TEXT NOT NULL,
  home_score    INTEGER NOT NULL DEFAULT 0,
  away_score    INTEGER NOT NULL DEFAULT 0,
  venue         TEXT,
  referee       TEXT,
  events        JSONB DEFAULT '[]'::jsonb,              -- array of match events
  submitted_at  TIMESTAMPTZ DEFAULT now(),
  status        TEXT DEFAULT 'submitted',               -- 'submitted' | 'reviewed'
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- Index for fast lookup by fixture
CREATE INDEX IF NOT EXISTS match_reports_fixture_idx ON match_reports (fixture_id);

-- RLS
ALTER TABLE match_reports ENABLE ROW LEVEL SECURITY;

-- Referees can insert their own reports
CREATE POLICY IF NOT EXISTS "Referees can insert match reports"
  ON match_reports FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'referee'
    )
  );

-- Admins and referees can read all reports
CREATE POLICY IF NOT EXISTS "Admins and referees can read match reports"
  ON match_reports FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'referee')
    )
  );

-- Admins can update report status (mark as reviewed)
CREATE POLICY IF NOT EXISTS "Admins can update match report status"
  ON match_reports FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );
