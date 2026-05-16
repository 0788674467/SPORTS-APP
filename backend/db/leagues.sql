-- ──────────────────────────────────────────────────────────────────────────────
-- Leagues Table — run in Supabase SQL Editor
-- ──────────────────────────────────────────────────────────────────────────────
create table if not exists public.leagues (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  season      text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Enable RLS
alter table public.leagues enable row level security;

-- Admins can do everything; everyone can read
create policy "Admins manage leagues" on public.leagues
  for all using (true) with check (true);

-- Seed with default league
insert into public.leagues (name, description, season, is_active)
values ('MMU Premier League', 'Main university football league', '2026', true)
on conflict do nothing;
