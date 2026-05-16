-- ─── Match Reports Table ──────────────────────────────────────────────────────
-- Stores the full official match report submitted by the referee after each match.
-- Run this in your Supabase SQL Editor.

-- Drop existing table and recreate clean
DROP TABLE IF EXISTS match_reports CASCADE;

CREATE TABLE match_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fixture_id    TEXT NOT NULL,
  home_team     TEXT NOT NULL,
  away_team     TEXT NOT NULL,
  home_score    INTEGER NOT NULL DEFAULT 0,
  away_score    INTEGER NOT NULL DEFAULT 0,
  venue         TEXT,
  referee       TEXT,
  events        JSONB DEFAULT '[]'::jsonb,
  submitted_at  TIMESTAMPTZ DEFAULT now(),
  status        TEXT DEFAULT 'submitted',
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- Index for fast lookup by fixture
CREATE INDEX match_reports_fixture_idx ON match_reports (fixture_id);

-- RLS
ALTER TABLE match_reports ENABLE ROW LEVEL SECURITY;

-- Referees can insert their own reports
CREATE POLICY "Referees can insert match reports"
  ON match_reports FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'referee'
    )
  );

-- Admins and referees can read all reports
CREATE POLICY "Admins and referees can read match reports"
  ON match_reports FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'referee')
    )
  );

-- Admins can update report status (mark as reviewed)
CREATE POLICY "Admins can update match report status"
  ON match_reports FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );
