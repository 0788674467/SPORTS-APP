-- ============================================================
--  LEAGUE MANAGEMENT SYSTEM — COMPREHENSIVE DATABASE SCHEMA
--  Run this entire file in Supabase SQL Editor.
--  Uses IF NOT EXISTS for all tables and DROP/REPLACE for functions.
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PROFILES (Unified Structure)
CREATE TABLE IF NOT EXISTS public.profiles (
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

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. TEAMS
CREATE TABLE IF NOT EXISTS public.teams (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL UNIQUE,
  coach_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  logo_url      TEXT,
  home_color    TEXT,
  away_color    TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. PLAYERS
CREATE TABLE IF NOT EXISTS public.players (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id       UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  full_name     TEXT NOT NULL,
  jersey_number INT NOT NULL,
  position      TEXT CHECK (position IN ('GK','DEF','MID','FWD')),
  date_of_birth DATE,
  is_eligible   BOOLEAN NOT NULL DEFAULT TRUE,
  photo_url     TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (team_id, jersey_number)
);

-- 4. SEASONS
CREATE TABLE IF NOT EXISTS public.seasons (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL,
  start_date    DATE NOT NULL,
  end_date      DATE NOT NULL,
  is_current    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. TEAM REGISTRATIONS
CREATE TABLE IF NOT EXISTS public.team_registrations (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id       UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  season_id     UUID NOT NULL REFERENCES public.seasons(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','approved','rejected')),
  submitted_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at   TIMESTAMPTZ,
  reviewed_by   UUID REFERENCES public.profiles(id),
  UNIQUE (team_id, season_id)
);

-- 6. FIXTURES
CREATE TABLE IF NOT EXISTS public.fixtures (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  season_id       UUID NOT NULL REFERENCES public.seasons(id) ON DELETE CASCADE,
  home_team_id    UUID NOT NULL REFERENCES public.teams(id) ON DELETE RESTRICT,
  away_team_id    UUID NOT NULL REFERENCES public.teams(id) ON DELETE RESTRICT,
  referee_id      UUID REFERENCES public.profiles(id),
  scheduled_at    TIMESTAMPTZ NOT NULL,
  venue           TEXT,
  status          TEXT NOT NULL DEFAULT 'scheduled'
                    CHECK (status IN ('scheduled','postponed','cancelled','completed')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (home_team_id <> away_team_id)
);

-- 7. MATCHES
CREATE TABLE IF NOT EXISTS public.matches (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  fixture_id      UUID NOT NULL UNIQUE REFERENCES public.fixtures(id) ON DELETE CASCADE,
  started_at      TIMESTAMPTZ,
  ended_at        TIMESTAMPTZ,
  home_score      INT NOT NULL DEFAULT 0,
  away_score      INT NOT NULL DEFAULT 0,
  status          TEXT NOT NULL DEFAULT 'not_started'
                    CHECK (status IN ('not_started','first_half','half_time',
                                      'second_half','completed','abandoned')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. LINEUPS
CREATE TABLE IF NOT EXISTS public.lineups (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  fixture_id    UUID NOT NULL REFERENCES public.fixtures(id) ON DELETE CASCADE,
  team_id       UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  player_id     UUID NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
  jersey_number INT NOT NULL,
  position      TEXT CHECK (position IN ('GK','DEF','MID','FWD')),
  is_starter    BOOLEAN NOT NULL DEFAULT TRUE,
  is_locked     BOOLEAN NOT NULL DEFAULT FALSE,
  submitted_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (fixture_id, team_id, player_id)
);

-- 9. MATCH EVENTS
CREATE TABLE IF NOT EXISTS public.match_events (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id      UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  team_id       UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  player_id     UUID REFERENCES public.players(id) ON DELETE SET NULL,
  event_type    TEXT NOT NULL
                  CHECK (event_type IN ('goal','own_goal','yellow_card',
                                        'red_card','sub_in','sub_out','penalty_scored',
                                        'penalty_missed')),
  minute        INT NOT NULL CHECK (minute >= 0 AND minute <= 120),
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. SUBSTITUTION REQUESTS
CREATE TABLE IF NOT EXISTS public.substitution_requests (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id        UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  team_id         UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  player_off_id   UUID NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
  player_on_id    UUID NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
  requested_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','approved','rejected')),
  minute          INT CHECK (minute >= 0 AND minute <= 120),
  reviewed_at     TIMESTAMPTZ,
  CHECK (player_off_id <> player_on_id)
);

-- 11. MATCH REPORTS
CREATE TABLE IF NOT EXISTS public.match_reports (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id        UUID NOT NULL UNIQUE REFERENCES public.matches(id) ON DELETE CASCADE,
  referee_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  narrative       TEXT,
  incidents       TEXT,
  submitted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  admin_approved  BOOLEAN NOT NULL DEFAULT FALSE,
  approved_at     TIMESTAMPTZ,
  approved_by     UUID REFERENCES public.profiles(id)
);

-- 12. STANDINGS
CREATE TABLE IF NOT EXISTS public.standings (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  season_id       UUID NOT NULL REFERENCES public.seasons(id) ON DELETE CASCADE,
  team_id         UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  played          INT NOT NULL DEFAULT 0,
  won             INT NOT NULL DEFAULT 0,
  drawn           INT NOT NULL DEFAULT 0,
  lost            INT NOT NULL DEFAULT 0,
  goals_for       INT NOT NULL DEFAULT 0,
  goals_against   INT NOT NULL DEFAULT 0,
  goal_difference INT GENERATED ALWAYS AS (goals_for - goals_against) STORED,
  points          INT GENERATED ALWAYS AS ((won * 3) + drawn) STORED,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (season_id, team_id)
);

-- 13. NOTIFICATIONS
CREATE TABLE IF NOT EXISTS public.notifications (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type          TEXT NOT NULL,
  title         TEXT NOT NULL,
  body          TEXT,
  is_read       BOOLEAN NOT NULL DEFAULT FALSE,
  related_table TEXT,
  related_id    UUID,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. AUDIT LOG
CREATE TABLE IF NOT EXISTS public.audit_log (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_id      UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  action        TEXT NOT NULL,
  target_table  TEXT NOT NULL,
  target_id     UUID NOT NULL,
  old_value     JSONB,
  new_value     JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DOMAIN TRIGGERS (Logic)
-- ============================================================

-- A. Red card → ineligibility
CREATE OR REPLACE FUNCTION fn_red_card_suspend_player()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.event_type = 'red_card' AND NEW.player_id IS NOT NULL THEN
    UPDATE players SET is_eligible = FALSE WHERE id = NEW.player_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_red_card_suspend ON match_events;
CREATE TRIGGER trg_red_card_suspend
AFTER INSERT ON match_events
FOR EACH ROW EXECUTE FUNCTION fn_red_card_suspend_player();

-- B. Match completed → calculate standings
CREATE OR REPLACE FUNCTION fn_recalculate_standings()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_fixture   fixtures%ROWTYPE;
  v_season_id UUID;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') THEN
    SELECT * INTO v_fixture FROM fixtures WHERE id = NEW.fixture_id;
    v_season_id := v_fixture.season_id;
    -- Home Team
    INSERT INTO standings (season_id, team_id, played, won, drawn, lost, goals_for, goals_against, updated_at)
    VALUES (v_season_id, v_fixture.home_team_id, 1,
            CASE WHEN NEW.home_score > NEW.away_score THEN 1 ELSE 0 END,
            CASE WHEN NEW.home_score = NEW.away_score THEN 1 ELSE 0 END,
            CASE WHEN NEW.home_score < NEW.away_score THEN 1 ELSE 0 END,
            NEW.home_score, NEW.away_score, NOW())
    ON CONFLICT (season_id, team_id) DO UPDATE SET
      played = standings.played + 1,
      won = standings.won + CASE WHEN NEW.home_score > NEW.away_score THEN 1 ELSE 0 END,
      drawn = standings.drawn + CASE WHEN NEW.home_score = NEW.away_score THEN 1 ELSE 0 END,
      lost = standings.lost + CASE WHEN NEW.home_score < NEW.away_score THEN 1 ELSE 0 END,
      goals_for = standings.goals_for + NEW.home_score,
      goals_against = standings.goals_against + NEW.away_score,
      updated_at = NOW();
    -- Away Team
    INSERT INTO standings (season_id, team_id, played, won, drawn, lost, goals_for, goals_against, updated_at)
    VALUES (v_season_id, v_fixture.away_team_id, 1,
            CASE WHEN NEW.away_score > NEW.home_score THEN 1 ELSE 0 END,
            CASE WHEN NEW.away_score = NEW.home_score THEN 1 ELSE 0 END,
            CASE WHEN NEW.away_score < NEW.home_score THEN 1 ELSE 0 END,
            NEW.away_score, NEW.home_score, NOW())
    ON CONFLICT (season_id, team_id) DO UPDATE SET
      played = standings.played + 1,
      won = standings.won + CASE WHEN NEW.away_score > NEW.home_score THEN 1 ELSE 0 END,
      drawn = standings.drawn + CASE WHEN NEW.away_score = NEW.home_score THEN 1 ELSE 0 END,
      lost = standings.lost + CASE WHEN NEW.away_score < NEW.home_score THEN 1 ELSE 0 END,
      goals_for = standings.goals_for + NEW.away_score,
      goals_against = standings.goals_against + NEW.home_score,
      updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_standings_on_complete ON matches;
CREATE TRIGGER trg_standings_on_complete
AFTER UPDATE ON matches
FOR EACH ROW EXECUTE FUNCTION fn_recalculate_standings();

-- C. Substitution approved → match events
CREATE OR REPLACE FUNCTION fn_sub_request_to_events()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status = 'pending' THEN
    INSERT INTO match_events (match_id, team_id, player_id, event_type, minute)
    VALUES (NEW.match_id, NEW.team_id, NEW.player_off_id, 'sub_out', NEW.minute);
    INSERT INTO match_events (match_id, team_id, player_id, event_type, minute)
    VALUES (NEW.match_id, NEW.team_id, NEW.player_on_id, 'sub_in', NEW.minute);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sub_approved_to_events ON substitution_requests;
CREATE TRIGGER trg_sub_approved_to_events
AFTER UPDATE ON substitution_requests
FOR EACH ROW EXECUTE FUNCTION fn_sub_request_to_events();

-- ============================================================
-- SYNC TRIGGER: auth.users -> public.profiles
-- ============================================================

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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- RLS - ENABLE ON ALL TABLES
-- ============================================================
ALTER TABLE public.teams                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.players              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seasons              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_registrations   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fixtures             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lineups              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_events         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.substitution_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_reports        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.standings            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log            ENABLE ROW LEVEL SECURITY;

-- Base Policies
DROP POLICY IF EXISTS "profiles: own row" ON public.profiles;
CREATE POLICY "profiles: own row" ON public.profiles FOR ALL USING (auth.uid() = id);

DROP POLICY IF EXISTS "Public read teams" ON public.teams;
CREATE POLICY "Public read teams" ON public.teams FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read standings" ON public.standings;
CREATE POLICY "Public read standings" ON public.standings FOR SELECT USING (true);

-- Helpful Indexing
CREATE INDEX IF NOT EXISTS idx_players_team        ON players(team_id);
CREATE INDEX IF NOT EXISTS idx_lineups_fixture     ON lineups(fixture_id);
CREATE INDEX IF NOT EXISTS idx_match_events_match  ON match_events(match_id);
CREATE INDEX IF NOT EXISTS idx_standings_season    ON standings(season_id, points DESC);

-- Helper RPC: approve_user
CREATE OR REPLACE FUNCTION approve_user(user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles SET approval_status = 'approved' WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
