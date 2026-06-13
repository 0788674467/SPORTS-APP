# UniLeague — University Soccer League Management System

**UniLeague** is a cross-platform (Flutter) soccer league management system built for **Mountains of the Moon University (MMU)**, Fort Portal, Uganda. It replaces manual paper/spreadsheet/WhatsApp-based league administration with a centralised digital platform featuring role-based dashboards, automated fixture generation, real-time match tracking, offline support, and spectator engagement.

**Authors:** Santo Rayern (2023/U/MMU/BCS/01673) & Mbambu Rosette (2023/U/MMU/BIT/01795)
**Supervisor:** Samuel Ocen (samuel.ocen@mmu.ac.ug)
**Timeline:** March 2026 – July 2026 (18 weeks)
**Methodology:** Design Science Research + Agile Development

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Objectives](#objectives)
3. [Tech Stack](#tech-stack)
4. [System Architecture](#system-architecture)
5. [Frontend (Flutter)](#frontend-flutter)
   - [State Management](#state-management)
   - [Admin Dashboard](#admin-dashboard)
   - [Coach Dashboard](#coach-dashboard)
   - [Referee Dashboard](#referee-dashboard)
   - [Spectator Portal](#spectator-portal)
   - [Auth Screens](#auth-screens)
   - [Shared Widgets](#shared-widgets)
6. [Backend (Node.js + Express)](#backend-nodejs--express)
   - [API Modules](#api-modules)
   - [Real-Time (Socket.IO)](#real-time-socketio)
   - [Auth & Middleware](#auth--middleware)
7. [Database (Supabase PostgreSQL)](#database-supabase-postgresql)
   - [Core Tables](#core-tables)
8. [Offline Support](#offline-support)
9. [Key Features in Detail](#key-features-in-detail)
   - [Round-Robin Fixture Generation](#round-robin-fixture-generation)
   - [Standings Calculation](#standings-calculations)
   - [Real-Time Match Updates](#real-time-match-updates)
   - [Substitution Requests](#substitution-requests)
   - [Spectator Chat](#spectator-chat)
   - [Officials Chat (DM)](#officials-chat-dm)
   - [PDF Report Generation](#pdf-report-generation)
   - [Lineup Builder](#lineup-builder)
   - [Squad Approval Workflow](#squad-approval-workflow)
10. [Testing & Evaluation](#testing--evaluation)
11. [Deployment & CI/CD](#deployment--cicd)
12. [Project Files](#project-files)
13. [Results & Achievements](#results--achievements)
14. [Limitations & Future Work](#limitations--future-work)

---

## Problem Statement

Soccer league management at MMU relied entirely on manual/fragmented processes:

- **Fixture generation**: Manual, causing scheduling conflicts and frequent changes
- **Player registration**: Stored in disconnected spreadsheets — duplicate/incomplete records
- **Match results**: Reported late or verbally — standings always inaccurate or outdated
- **Substitutions & events**: No audit trails — leading to disputes
- **Spectator access**: No reliable way for fans to check fixtures, results, or standings
- **Admin workload**: Volunteer coordinators bore heavy administrative burden

There was no integrated, cost-effective, offline-capable digital system suitable for a resource-constrained Ugandan university.

---

## Objectives

1. **Analyse** current soccer league management processes at MMU
2. **Design** a soccer league management system (architecture, DB, UI)
3. **Implement** the designed system using modern cross-platform technologies
4. **Test & evaluate** the system with representative MMU stakeholders

---

## Tech Stack

| Component | Technology | Purpose |
|---|---|---|
| Frontend | Flutter (Dart) | Cross-platform mobile + web (Android, iOS, Web, macOS, Linux, Windows) |
| State Management | Provider | App-wide state (auth, match, theme, locale) |
| HTTP Client | Dio | Frontend-to-backend API communication with JWT interceptor |
| Backend | Node.js + Express | RESTful API server (port 3000) |
| Database | Supabase PostgreSQL + Prisma ORM | Centralised relational data with RLS |
| Auth | Supabase Auth (JWT) | Secure login, role-based access |
| Real-Time | Socket.IO | Live match events, notifications, substitutions |
| Offline Storage | SQLite (sqflite) | Local cache when disconnected; auto-sync on reconnect |
| Charts | fl_chart | Performance visualisations (bar charts) |
| PDF Reports | pdf + file_saver + share_plus | Generate/download/share season reports |
| Security | Helmet, CORS, Zod validation | Secure headers, CORS config, input validation |
| Deployment | Docker, Docker Compose | Containerised backend + PostgreSQL |

---

## System Architecture

Three-tier client-server architecture:

```
┌─────────────────────────────────────────────┐
│  CLIENT LAYER (Flutter)                      │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐ │
│  │ Android   │ │   iOS    │ │ Flutter Web │ │
│  │ App       │ │   App    │ │ (Browser)   │ │
│  └────┬─────┘ └────┬─────┘ └──────┬──────┘ │
│       │            │              │         │
│  ┌────┴────────────┴──────────────┴──────┐  │
│  │ Provider State (Auth, Match, Theme)   │  │
│  │ Dio HTTP + JWT Interceptor            │  │
│  │ Socket.IO Client                       │  │
│  │ SQLite Offline Store (sqflite)         │  │
│  └───────────────────────────────────────┘  │
└──────────────────┬──────────────────────────┘
                   │ HTTP / WebSocket
┌──────────────────▼──────────────────────────┐
│  SERVER LAYER (Node.js + Express)            │
│  ┌────────────────────────────────────────┐  │
│  │ REST API Endpoints (7 modules)        │  │
│  │ JWT Auth + Role Guards                │  │
│  │ Round-Robin Fixture Engine            │  │
│  │ Zod Validation                        │  │
│  │ Socket.IO Real-Time Server            │  │
│  └────────────────────────────────────────┘  │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  DATA LAYER                                  │
│  ┌────────────────────────────────────────┐  │
│  │ Supabase PostgreSQL (Cloud)           │  │
│  │  + Row-Level Security Policies        │  │
│  │  + Supabase Auth (JWT)                │  │
│  │  + Storage (team-logos, avatars)      │  │
│  └────────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

---

## Frontend (Flutter)

**Location:** `frontend/`
**Entry point:** `frontend/lib/main.dart`

Initialises Supabase client (`wkhidacuzxscaquawzrx.supabase.co`), sets up `MultiProvider` with `AuthProvider`, `SocketClient`, `MatchState`, `AppState`, and routes to `SplashScreen`.

### State Management

| Provider | File | Responsibilities |
|---|---|---|
| `AuthProvider` | `lib/core/auth/auth_provider.dart` | Full auth lifecycle: signIn, signUp, signOut, role/approval checks, user/team/player CRUD |
| `OfflineAuthProvider` | `lib/core/auth/offline_auth_provider.dart` | Extends AuthProvider with SQLite caching, connectivity listening, auto-sync |
| `RoleRouter` | `lib/core/auth/role_router.dart` | Routes authenticated users to role-specific dashboards |
| `MatchState` | `lib/core/state/match_state.dart` | Match, MatchEvent, LineupPlayer models; live match state with Supabase realtime subscription; goal/card/substitution recording; lineup management; fixture generation |
| `AppState` | `lib/core/state/app_state.dart` | Dark mode toggle, English/Kiswahili translations, season label |

### Admin Dashboard (6,733 lines — largest file)

**File:** `lib/features/admin/admin_dashboard.dart`

Full admin panel with these sections:

| Section | Features |
|---|---|
| **Dashboard Overview** | Stat cards (teams, players, matches, users), goals-per-match chart, team performance bar chart, recent results widget |
| **Approvals** | Pending user approval list with accept/reject, role filter, sortable columns |
| **Communications** | Officials chat integration (DM between admins, coaches, referees) |
| **Notifications** | Real-time notification center (bell badge with unread count, mark-as-read, filter by type) from Supabase `notifications` table |
| **Fixtures** | Fixture generator panel (round-robin) + display generated fixtures |
| **Venues** | Venue CRUD (name, location, active toggle) |
| **Leagues** | League/season management (create, activate) |
| **Standings** | League standings table (auto-calculated) |
| **Match Results** | Recent results display |
| **Squad Approvals** | Coach-submitted squad review (approve/reject with notes) |
| **Teams** | Team CRUD with logo upload |
| **Players** | Player CRUD with search, sort |
| **Coaches** | Approved coach list |
| **Referees** | Approved referee list |
| **Player Stats** | Top scorers, charts |
| **Season Reports** | PDF generation, download, share |
| **Live Scores** | Live match scoreboard |
| **Settings** | Season name/start/end, email notifications, auto-approve spectators, maintenance mode, registration toggle, admin profile with avatar upload |

**Dashboard Components** (`dashboard_components.dart`): `ResponsiveWrapper` (mobile/tablet/desktop), `DashboardSidebar` (5 sections: MAIN, COMPETITIONS, MANAGEMENT, REPORTS & ANALYTICS, SYSTEM), stat cards, chart builders.

**Fixture Generator** (`fixture_generator.dart`): Standalone panel — date/time/venue/league selection, round-robin generation via `MatchState.generateRoundRobin()`, auto-assign referees, fixture list with edit/delete.

### Coach Dashboard (1,761 lines)

**File:** `lib/features/coach/coach_dashboard.dart`

| Section | Features |
|---|---|
| **Overview** | Welcome, upcoming fixtures, recent results, squad submission status |
| **My Matches** | Fixture list filtered by coach's team |
| **Lineup** | LineupBuilder — formation selection (4-3-3, 4-4-2, 3-5-2, 5-3-2), drag-to-swap starters/bench, pitch position visualisation |
| **Substitutions** | SubstitutionRequest — real-time sub requests sent to referee |
| **Squad** | Squad management — add/edit/remove players (name, reg no, university ID, course, year, jersey number, position, photo), position badges, submission status (draft/submitted/approved/rejected with rejection notes) |
| **Chat** | OfficialsChatWidget |
| **Settings** | Profile edit (name, phone, avatar), team name/logo change, password change |

**Lineup Builder** (`lineup_builder.dart`, 566 lines): Squad-driven tactical board — 4 formations, 11 starters auto-assigned by position priority (GK→DF→MF→FW), pitch position rendering, swap starter/bench via tap, share lineup.

**Substitution Request** (`substitution_request.dart`, 363 lines): Tap-to-swap — match selector, tap starter to mark as "out", select bench player as replacement, sends request to `MatchState.requestSubstitution()` with SnackBar confirmation.

### Referee Dashboard (2,304 lines)

**File:** `lib/features/referee/referee_dashboard.dart`

| Section | Features |
|---|---|
| **Console** | Match timer (start/stop), scoreboard display, quick event buttons (goal, yellow/red card, substitution, pause, full time). Persists match minute to `scheduled_matches.current_minute` every tick |
| **My Fixtures** | Assigned fixture list filtered by referee name |
| **Lineups** | View submitted lineups for active match |
| **Substitutions** | Approve/reject coach substitution requests with badge counter |
| **Events** | Event log display |
| **Report** | Match report generation |
| **Chat** | OfficialsChatWidget |
| **Settings** | Profile edit |

**Match Console** (`match_console.dart`, 138 lines): Score display, timer, 6 event buttons.

**Event Recorder** (`event_recorder.dart`, 56 lines): Player selection list for recording events (goal/card).

### Spectator Portal (3,276 lines)

**File:** `lib/features/spectator/spectator_home.dart`

| Section | Features |
|---|---|
| **Home** | Auto-rotating match carousel (4s timer), game feed (live/upcoming/completed), live score overlay popup |
| **Standings** | League table with team stats |
| **Discussion** | Full real-time chat (`spectator_chats` table) — Supabase Realtime stream, guest ID support (no login), sender names, reply-to (WhatsApp-style), online counter (unique senders in last 5 min), unread badge |
| **Settings** | Dark mode, match alerts toggle, nickname, guest ID display |

Realtime branding: subscribes to `teams` table for live name/logo updates with flash highlight effect.

**Standings Table** (`standings_table.dart`, 32 lines): Standings table + fixture list.

**Fixture List** (`fixture_list.dart`, 26 lines): Basic fixture list.

### Auth Screens

| Screen | File | Description |
|---|---|---|
| Login | `login_screen.dart` | Email + password login |
| Signup | `signup_screen.dart` | Registration with role selection (coach/referee/spectator) |
| Pending Approval | `pending_approval_screen.dart` | Shows "awaiting admin approval" status |

### Shared Widgets

| Widget | File | Description |
|---|---|---|
| Pitch Background | `pitch_background.dart` | Glowing dark-purple football pitch CustomPaint (lines, center circle, penalty areas) |
| Score Card | `score_card.dart` | Reusable match score card (team avatars, score, LIVE badge, minute) |
| Loading Overlay | `loading_overlay.dart` | Semi-transparent spinner with optional message |
| Profile Dropdown | `profile_dropdown.dart` | User avatar dropdown for header menus |
| Player Tile | `player_tile.dart` | Player list tile |
| Officials Chat | `officials_chat.dart` (926 lines) | Full DM widget — conversation list with unread badges, compose panel with role-grouped officials, thread view, Supabase Realtime subscription (`official_messages` table) |
| Splash Screen | `splash_screen.dart` | App splash/loading screen |

---

## Backend (Node.js + Express)

**Location:** `backend/`
**Entry point:** `backend/src/server.ts`
**Port:** 3000

### Server & App Setup

| File | Description |
|---|---|
| `src/server.ts` | HTTP server with Socket.IO init |
| `src/app.ts` | Express app — Helmet, CORS (`localhost:8080`, `127.0.0.1:8080`), JSON body parser, health check (`GET /api/health`), 7 route modules, global error handler |
| `src/config/env.ts` | Environment variables: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `JWT_SECRET`, `PORT` |
| `src/config/db.ts` | Dual Supabase clients: `supabase` (anon key, RLS-respecting) + `supabaseAdmin` (service role, bypasses RLS) |

### Middleware

| Middleware | File | Purpose |
|---|---|---|
| Auth | `auth.middleware.ts` | JWT verification via `supabase.auth.getUser()`, `requireRole(...)` role guard (admin, coach, referee) |
| Error | `error.middleware.ts` | `AppError` class (extends Error with statusCode), Express error handler |
| Validation | `validate.middleware.ts` | Zod schema validation for body/query/params |

### Types

**File:** `src/types/index.ts`

- `AuthUser`, `UserRole` (admin/coach/referee/spectator), `ApprovalStatus` (pending/approved/rejected)
- `MatchStatus` (scheduled/live/completed/cancelled)
- `MatchEventType` (goal/yellow_card/red_card/substitution/corner/penalty/assist)
- `NotificationType`, `StandingEntry`, `StandingRow`

### API Modules (7 modules)

#### 1. Auth Module
**Route prefix:** `/api/auth`

| Endpoint | Access | Description |
|---|---|---|
| `POST /signup` | Public | Register new user |
| `POST /signin` | Public | Login |
| `POST /signout` | Protected | Logout |
| `POST /reset-password` | Public | Password reset |
| `GET /profile` | Protected | Get user profile |

#### 2. Teams Module
**Route prefix:** `/api/teams`

| Endpoint | Access | Description |
|---|---|---|
| `GET /` | Public | List all teams |
| `GET /:id` | Public | Get team by ID |
| `POST /` | Admin | Create team |
| `PUT /:id` | Admin | Update team |
| `DELETE /:id` | Admin | Delete team |

SQL: `supabaseAdmin.from('teams')` CRUD.

#### 3. Players Module
**Route prefix:** `/api/players`

| Endpoint | Access | Description |
|---|---|---|
| `GET /` | Public | List all players |
| `GET /:id` | Public | Get player by ID |
| `GET /stats/:id` | Public | Player stats (goals/assists from match_events) |
| `POST /` | Admin/Coach | Create player |
| `PUT /:id` | Admin/Coach | Update player |
| `DELETE /:id` | Admin | Delete player |

#### 4. Fixtures Module
**Route prefix:** `/api/fixtures`

| Endpoint | Access | Description |
|---|---|---|
| `GET /` | Public | List fixtures |
| `GET /:id` | Public | Get fixture by ID |
| `POST /generate` | Admin | Generate round-robin fixtures |
| `DELETE /:id` | Admin | Delete fixture |

**Fixture Engine** (`fixture.engine.ts`): Round-robin "circle method" scheduler — handles odd/even team counts with bye weeks, home/away alternation per matchday. Generates `Fixture` and `Match` DB records.

#### 5. Matches Module
**Route prefix:** `/api/matches`

| Endpoint | Access | Description |
|---|---|---|
| `GET /` | Public | List matches |
| `GET /:id` | Public | Get match by ID |
| `GET /live` | Public | Get live matches |
| `PATCH /:id/score` | Referee/Admin | Update score |
| `PATCH /:id/status` | Referee/Admin | Update status |
| `POST /:id/events` | Referee | Record match event (broadcasts via Socket.IO) |

#### 6. Analytics Module
**Route prefix:** `/api/analytics`

| Endpoint | Access | Description |
|---|---|---|
| `GET /standings` | Public | League standings (points, GD, wins/draws/losses) |
| `GET /top-scorers` | Public | Top goal scorers |
| `GET /matches/:id/stats` | Public | Per-match stats |

#### 7. Notifications Module
**Route prefix:** `/api/notifications`

| Endpoint | Access | Description |
|---|---|---|
| `GET /` | Protected | User notifications |
| `PATCH /:id/read` | Protected | Mark one as read |
| `PATCH /read-all` | Protected | Mark all as read |
| `POST /send` | Admin | Send notification (DB + Socket.IO push) |

### Real-Time (Socket.IO)

**Location:** `src/realtime/`

| File | Description |
|---|---|
| `socket.server.ts` | Socket.IO server init with CORS, registers match + substitution event handlers |
| `match.events.ts` | `match:join` (room join), `match:leave`, `match:goal`, `match:card`, `match:score_update` — broadcasts to room members |
| `substitution.events.ts` | `sub:request` (coach→referee), `sub:confirm` (referee approval→broadcast) |

### Scripts

| Script | Description |
|---|---|
| `scripts/setup-admin.ts` | Create/update Supabase admin user |
| `scripts/promote-admin.ts` | Promote existing user to admin |
| `scripts/check-profiles.ts` | List all profiles with role/status |

---

## Database (Supabase PostgreSQL)

**Schema file:** `backend/db/full_schema.sql` (10+ tables)
**Prisma schema:** `backend/db/schema.prisma`
**Migration scripts:** 18+ SQL files covering leagues, match_reports, spectator_chat, official_messages, squad_persistence, live_match_state, player_stats, guest_id, reply_to_chat, storage_setup, profiles_sync, RLS fixes, and more.

### Core Tables

#### `public.profiles`
| Column | Type | Description |
|---|---|---|
| id (PK) | uuid | References `auth.users(id)` |
| full_name | text | User's full name |
| email | text | Email address |
| phone | text | Phone number |
| role | text | admin, coach, referee, player, spectator |
| approval_status | text | pending, approved, rejected |
| avatar_url | text | Profile photo URL |
| team_name | text | Coach's team name |
| created_at / updated_at | timestamptz | Timestamps |

#### `public.teams`
| Column | Type | Description |
|---|---|---|
| id (PK) | uuid | Auto-generated |
| name | text (UNIQUE) | Team name |
| coach_id (FK) | uuid | References profiles(id) |
| logo_url | text | Team badge URL |
| home_color, away_color | text | Jersey colours |
| is_active | boolean | Active in current season |
| submission_status | text | draft, submitted, approved, rejected |
| submitted_at | timestamptz | Squad submission timestamp |

#### `public.players`
| Column | Type | Description |
|---|---|---|
| id (PK) | uuid | Auto-generated |
| team_id (FK) | uuid | References teams(id) |
| full_name | text | Player name |
| jersey_number | integer | Shirt number |
| position | text | GK, DEF, MID, FWD |
| date_of_birth | date | DOB (eligibility) |
| reg_no | text | University reg number |
| university_id | text | Student ID card number |
| course | text | Academic programme |
| year_of_study | text | Current year |
| is_eligible | boolean | Cleared to play |
| goals, assists, yellow_cards, red_cards, matches_played | integer | Season stats |

#### `public.fixtures`
| Column | Type | Description |
|---|---|---|
| id (PK) | uuid | Auto-generated |
| season_id (FK) | uuid | References seasons(id) |
| home_team_id (FK) | uuid | References teams(id) |
| away_team_id (FK) | uuid | References teams(id) |
| referee_id (FK) | uuid | References profiles(id) |
| scheduled_at | timestamptz | Match date/time |
| venue | text | Venue name |
| status | text | scheduled, postponed, cancelled, completed |

#### `public.match_events`
| Column | Type | Description |
|---|---|---|
| id (PK) | uuid | Auto-generated |
| match_id (FK) | uuid | References matches(id) |
| team_id (FK) | uuid | References teams(id) |
| player_id (FK) | uuid | References players(id) |
| event_type | text | goal, own_goal, yellow_card, red_card, sub_in, sub_out |
| minute | integer | 0–120 |
| notes | text | Referee notes |

#### `public.scheduled_matches`
Live match state: scores, current_minute, status — persisted for spectator real-time clock.

#### `public.notifications`
Real-time notification center — user_id, title, body, type, read status.

#### `public.spectator_chat`
Public spectator discussion — sender_name, message, reply_to, guest_id, created_at.

#### `public.official_messages`
Private DM between officials (admins, coaches, referees) — sender_id, receiver_id, message, read status.

### RLS Policies
Row-Level Security configured per table — authenticated users see only permitted rows. Storage buckets for team-logos, player-photos, match-reports, avatars.

---

## Offline Support

**Location:** `frontend/lib/core/offline/`

| File | Description |
|---|---|
| `offline_manager.dart` | SQLite database via sqflite — tables: users, teams, players, matches, notifications, pending_operations. Connectivity monitoring via `connectivity_plus`; auto-sync on reconnect |
| `offline_data_service.dart` | Singleton data service wrapping OfflineManager — CRUD methods for teams, players, matches, notifications with fallback: Supabase first, then local cache |

Referees can record match events (goals, cards, substitutions) offline; events queue locally and sync when connectivity is restored.

---

## Key Features in Detail

### Round-Robin Fixture Generation

**Algorithm:** "Circle method" — each team plays every other team. Odd team count introduces a bye. Home/away alternates per matchday. Conflict detection flags duplicate team/venue assignments.

**Backend:** `backend/src/modules/fixtures/fixture.engine.ts`
**Frontend:** `frontend/lib/features/admin/fixture_generator.dart`

### Standings Calculations

```
Points = (3 × Wins) + (1 × Draws)
Goal Difference = Goals For - Goals Against
```

Ranking: Points → Goal Difference → Goals Scored → Head-to-Head → Administrative tie-breakers.

### Real-Time Match Updates

- Referee records event → backend stores in DB → Socket.IO broadcasts to all room members
- Spectators see live score updates instantly without refreshing
- Match minute timer persists to `scheduled_matches.current_minute` via Supabase
- Uses Supabase Realtime subscription as backup for chat and team data

### Substitution Requests

1. Coach selects player to substitute out + bench player as replacement
2. Sends `sub:request` via Socket.IO to referee
3. Referee sees badge counter and can approve/reject
4. On approval: `sub:confirm` broadcasts to all, event logged

### Spectator Chat

- `spectator_chat` table with Supabase Realtime stream
- Guest ID support (no login required — stored in SharedPreferences)
- Reply-to (WhatsApp-style threaded)
- Online counter (unique senders in last 5 minutes)
- Unread badge on nav bar
- Long-press to delete own messages

### Officials Chat (DM)

- `official_messages` table with Supabase Realtime subscription
- Conversation list with unread badges
- Centered compose panel with role-grouped officials
- Thread view for each conversation

### PDF Report Generation

- Uses `pdf` (Dart) + `file_saver` + `share_plus`
- Navy banner header with MMU logo
- Stat cards, bar charts, full data tables
- Report types: full season, team stats, player stats, match history
- Works on web (download) and mobile (share/save)

### Lineup Builder

- 4 formations: 4-3-3, 4-4-2, 3-5-2, 5-3-2
- 11 starters auto-assigned by priority: GK → DF → MF → FW
- Pitch position rendering with `PitchBackground` widget
- Tap to swap starter/bench
- Share lineup functionality

### Squad Approval Workflow

1. Coach builds squad (draft status)
2. Coach submits squad (submitted status)
3. Admin reviews in Squad Approvals tab → approve/reject with notes
4. Coach sees rejection reason or approval confirmation

---

## Testing & Evaluation

### Functional Test Results

| Test Case | Status |
|---|---|
| User login → role-based dashboard | ✅ Passed |
| Team registration | ✅ Passed |
| Player registration | ✅ Passed |
| Fixture creation | ✅ Passed |
| Result entry | ✅ Passed |
| Standings update | ✅ Passed |
| Offline event storage | ✅ Passed |
| Real-time update | ✅ Passed |
| Report generation | ✅ Passed |

### Usability Evaluation (System Usability Scale)

| Item | Positive Responses |
|---|---|
| Ease of login and navigation | 88% |
| Clarity of fixture information | 92% |
| Ease of result recording | 84% |
| Usefulness of standings | 94% |
| **Overall satisfaction** | **90%** |

### User Acceptance Testing (Scale 1–5)

| User Group | Ease of Use | Usefulness | Satisfaction |
|---|---|---|---|
| Coordinators | 4.4 | 4.6 | 4.5 |
| Coaches | 4.2 | 4.5 | 4.4 |
| Referees | 4.3 | 4.5 | 4.4 |
| Players/Spectators | 4.1 | 4.3 | 4.2 |
| **Overall** | **4.25** | **4.48** | **4.38** |

---

## Deployment & CI/CD

### Docker

- **Dockerfile:** Node 20 slim, OpenSSL install, TypeScript build
- **docker-compose.yml:** PostgreSQL 14.5 Alpine (port 5432) + backend (port 3000)

### GitHub Actions

**File:** `.github/workflows/build-apk.yml`

- Manual dispatch + push to main/master (frontend paths)
- Setup Java 17 (Zulu) + Flutter 3.27.4 stable
- `flutter build apk --release`
- Upload APK artifact (30-day retention)

### Scripts

| Script | Purpose |
|---|---|
| `run_app.sh` | Start backend + Flutter web on port 8080 |
| `setup_github_build.sh` | Init git, add remote, commit CI workflow |
| `cleanup_space.sh` | Disk cleanup (trash, caches, Flutter/Gradle build artifacts, logs) |

---

## Project Files

This project consists of:

### Frontend (`frontend/`)
- 38 Dart source files across `lib/`
- 29 Flutter build logs (`flutter_01.log` – `flutter_29.log`)
- `pubspec.yaml` with full dependency list

### Backend (`backend/`)
- 20+ TypeScript source files
- 18+ SQL migration/repair scripts in `backend/db/`
- Prisma schema, Dockerfile, docker-compose.yml

### Documentation & Reports
- `main_improved.tex` — Full 2,028-line LaTeX academic report (6 chapters, abstract, 9 figures, bibliography, appendices with project budget, Gantt chart, questionnaires, interview guides)
- `attend.tex` — MMU ICT internship attendance register template
- `generator.html` — 1,043-line standalone HTML page using PptxGenJS to generate a 15-slide deep-green themed defense PowerPoint
- **Images:** `system_architecture.png`, `context_diagram.png`, `use_case_diagram.png`, `erd.png`, `dsr_framework.png`, `agile_process.png`, `seq_login.png`, `seq_fixture.png`, `seq_match_event.png`
- **Presentations:** "Black and White Modern Startups Pitch Deck Presentation.pptx" (general pitch deck)
- **Guidelines:** "Department of CS Final Research defense Presentation Format 2025.pdf"

### Infrastructure
- `.github/workflows/build-apk.yml` — CI/CD
- `.gitignore`, `docker-compose.yml`, `cleanup_space.sh`, `run_app.sh`, `setup_github_build.sh`

### Empty/Placeholder Files
- `frontend/lib/features/admin/team_management.dart`
- `frontend/lib/features/admin/season_settings.dart`
- `frontend/lib/features/referee/match_report.dart`
- `frontend/lib/shared/offline_banner.dart`
- `frontend/lib/core/db/local_db.dart`
- `report/` directory (empty)

---

## Results & Achievements

1. **Centralised** team, player, fixture, result, and statistics records in one platform
2. **Replaced** informal WhatsApp/paper coordination with structured digital notifications
3. **Automated** fixture generation using round-robin algorithm with conflict detection
4. **Enabled** real-time match updates via Socket.IO for all stakeholders simultaneously
5. **Offline-first** SQLite support for match officials in low-connectivity environments
6. **Cross-platform** access: Android, iOS, and web browser from a single Flutter codebase
7. **Compared to competitors** — UniLeague outperforms TeamSnap, LeagueApps, and SportsEngine for MMU's context (lower cost, offline support, integrated features)

### Comparison with Existing Systems

| System | Fixture Auto. | Real-Time | Offline | Low-Cost Fit |
|---|---|---|---|---|
| TeamSnap | Partial | Yes | Limited | No |
| LeagueApps | Partial | Yes | Limited | No |
| SportsEngine | Yes | Yes | Limited | No |
| OpenTournament | Yes | No | No | Partial |
| Tourney Master | Yes | No | No | Partial |
| **UniLeague** | **Yes** | **Yes** | **Yes** | **Yes** |

---

## Limitations & Future Work

### Limitations
- Evaluated with selected users, not a full competitive season
- Some historical league data incomplete/unavailable
- Network connectivity limitations in field environments
- Time constraints limited advanced feature implementation

### Future Work
1. Multi-sport support (basketball, volleyball, netball, athletics)
2. AI-based fixture optimisation and match outcome prediction
3. Push notifications via Firebase Cloud Messaging
4. Integration with university student information system for automatic eligibility
5. Live commentary and media upload features
6. Automated referee assignment and venue booking
7. Dedicated public web portal for spectators and alumni
8. Cloud backup and disaster recovery
9. Multi-institution deployment across East African universities

---

## Project Budget (UGX)

| Category | Cost |
|---|---|
| Data Collection | 280,000 |
| Development & Infrastructure | 340,000 |
| Pilot Evaluation | 260,000 |
| Documentation | 240,000 |
| Contingency | 90,000 |
| **Grand Total** | **1,210,000 UGX** (~$325 USD) |

---

## Abbreviations

| Abbreviation | Meaning |
|---|---|
| API | Application Programming Interface |
| AUUS | Association of Uganda University Sports |
| DSR | Design Science Research |
| ERD | Entity Relationship Diagram |
| FASU | Federation of Africa University Sports |
| FEAUS | Federation of East African University Sports |
| FISU | International University Sports Federation |
| JWT | JSON Web Token |
| MMU | Mountains of the Moon University |
| RLS | Row-Level Security |
| SUS | System Usability Scale |
| UAT | User Acceptance Testing |
