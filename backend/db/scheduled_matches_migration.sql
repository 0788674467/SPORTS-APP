-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEDULED MATCHES — persistent fixture store
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.scheduled_matches (
  id           text primary key,                  -- e.g. 'F1', 'F2'
  home_team    text not null,
  away_team    text not null,
  date_time    timestamptz not null,
  venue        text not null,
  referee      text,
  status       text not null default 'scheduled', -- scheduled | live | completed | postponed
  home_score   int  not null default 0,
  away_score   int  not null default 0,
  season       text not null default '2026',
  created_at   timestamptz not null default now()
);

-- ── Row Level Security ────────────────────────────────────────────────────────
alter table public.scheduled_matches enable row level security;

-- Everyone (including unauthenticated) can read fixtures
create policy "public read scheduled_matches"
  on public.scheduled_matches for select
  using (true);

-- Only admins can insert / update / delete
create policy "admin insert scheduled_matches"
  on public.scheduled_matches for insert
  with check ( (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' );

create policy "admin update scheduled_matches"
  on public.scheduled_matches for update
  using ( (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' );

create policy "admin delete scheduled_matches"
  on public.scheduled_matches for delete
  using ( (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' );

-- ── Realtime ──────────────────────────────────────────────────────────────────
-- Enables live updates to all dashboards when admin edits a fixture
alter publication supabase_realtime add table public.scheduled_matches;
