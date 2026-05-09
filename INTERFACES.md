# Sports Management Platform - Interface Documentation

This document provides a comprehensive overview of all interfaces, types, and data models used throughout the Sports Management Platform.

## Table of Contents

- [Backend TypeScript Interfaces](#backend-typescript-interfaces)
  - [Centralized Types](#centralized-types)
  - [Authentication](#authentication)
  - [Teams](#teams)
  - [Players](#players)
  - [Matches](#matches)
  - [Fixtures](#fixtures)
  - [Notifications](#notifications)
  - [Analytics](#analytics)
- [Frontend Dart Models](#frontend-dart-models)
  - [Centralized Models](#centralized-models)
  - [State Management](#state-management)
  - [API Clients](#api-clients)

---

## Backend TypeScript Interfaces

### Centralized Types

**Location:** `backend/src/types/index.ts`

This file contains all shared type definitions used across the backend.

#### User & Authentication Types

```typescript
// User roles
type UserRole = 'admin' | 'coach' | 'referee' | 'spectator';

// Approval status
type ApprovalStatus = 'pending' | 'approved' | 'rejected';

// Authenticated user
interface AuthUser {
    id: string;
    email: string;
    role: UserRole;
}
```

#### Match Types

```typescript
// Match status
type MatchStatus = 'scheduled' | 'live' | 'completed' | 'cancelled';

// Match event types
type MatchEventType = 
    | 'goal' 
    | 'yellow_card' 
    | 'red_card' 
    | 'substitution'
    | 'corner'
    | 'penalty'
    | 'assist';
```

#### Notification Types

```typescript
// Notification types
type NotificationType = 
    | 'match_start'
    | 'match_end'
    | 'goal'
    | 'card'
    | 'substitution'
    | 'general';
```

#### Database Entities

```typescript
interface Team {
    id: string;
    name: string;
    logo_url?: string;
    coach_id?: string;
    created_at: string;
    updated_at: string;
}

interface Player {
    id: string;
    name: string;
    team_id: string;
    position: string;
    jersey_number: number;
    date_of_birth?: string;
    photo_url?: string;
    created_at: string;
    updated_at: string;
}

interface Match {
    id: string;
    fixture_id: string;
    home_team_id: string;
    away_team_id: string;
    scheduled_at: string;
    venue?: string;
    status: MatchStatus;
    home_score: number;
    away_score: number;
    created_at: string;
    updated_at: string;
}
```

---

### Authentication

**Location:** `backend/src/modules/auth/auth.service.ts`

```typescript
// Sign up data transfer object
interface SignUpDto {
    email: string;
    password: string;
    fullName: string;
    role: UserRole;
}

// Sign in data transfer object
interface SignInDto {
    email: string;
    password: string;
}
```

**Middleware:** `backend/src/middleware/auth.middleware.ts`

```typescript
// Extended Express request with user info
interface AuthRequest extends Request {
    user?: AuthUser;
}
```

---

### Teams

**Location:** `backend/src/modules/teams/teams.service.ts`

```typescript
// Create team payload
interface CreateTeamDto {
    name: string;
    logo_url?: string;
    coach_id?: string;
}

// Update team payload
interface UpdateTeamDto {
    name?: string;
    logo_url?: string;
    coach_id?: string;
}
```

**Service Methods:**
- `getAll()` - Get all teams
- `getById(id)` - Get team by ID with players
- `create(payload)` - Create new team
- `update(id, payload)` - Update team
- `delete(id)` - Delete team

---

### Players

**Location:** `backend/src/modules/players/players.service.ts`

```typescript
// Create player payload
interface CreatePlayerDto {
    name: string;
    team_id: string;
    position: string;
    jersey_number: number;
    date_of_birth?: string;
    photo_url?: string;
}

// Update player payload
interface UpdatePlayerDto {
    name?: string;
    team_id?: string;
    position?: string;
    jersey_number?: number;
    date_of_birth?: string;
    photo_url?: string;
}
```

**Service Methods:**
- `getAll(teamId?)` - Get all players, optionally filtered by team
- `getById(id)` - Get player by ID
- `create(payload)` - Create new player
- `update(id, payload)` - Update player
- `delete(id)` - Delete player
- `getStats(playerId)` - Get player statistics

---

### Matches

**Location:** `backend/src/modules/matches/matches.service.ts`

```typescript
// Record match event payload
interface RecordEventPayload {
    match_id: string;
    player_id: string;
    team_id: string;
    event_type: MatchEventType;
    minute: number;
    notes?: string;
}
```

**Service Methods:**
- `getAll(status?)` - Get all matches, optionally filtered by status
- `getById(id)` - Get match by ID with events
- `updateScore(id, homeScore, awayScore)` - Update match score
- `updateStatus(id, status)` - Update match status
- `recordEvent(payload)` - Record a match event
- `getLiveMatches()` - Get all live matches

---

### Fixtures

**Location:** `backend/src/modules/fixtures/fixtures.service.ts`

```typescript
// Generate fixture payload
interface GenerateFixtureDto {
    name: string;
    season: string;
    teamIds: string[];
    startDate: string;
    matchDayIntervalDays?: number;
    venue?: string;
}

// Scheduled match (from fixture engine)
interface ScheduledMatch {
    homeTeamId: string;
    awayTeamId: string;
    scheduledAt: string;
    round: number;
}
```

**Service Methods:**
- `getAll()` - Get all fixtures
- `getById(id)` - Get fixture by ID with matches
- `generate(payload)` - Generate round-robin fixture
- `delete(id)` - Delete fixture

**Fixture Engine:** `backend/src/modules/fixtures/fixture.engine.ts`
- Uses circle method (polygon rotation) algorithm
- Handles odd/even number of teams
- Alternates home/away for fairness

---

### Notifications

**Location:** `backend/src/modules/notifications/notifications.service.ts`

```typescript
// Notification payload
interface NotificationPayload {
    userId?: string;  // null = broadcast
    title: string;
    body: string;
    type: NotificationType;
    data?: Record<string, unknown>;
}
```

**Service Methods:**
- `send(payload)` - Send notification (DB + Socket.IO)
- `getUserNotifications(userId, unreadOnly?)` - Get user notifications
- `markAsRead(notificationId, userId)` - Mark notification as read
- `markAllAsRead(userId)` - Mark all notifications as read

---

### Analytics

**Location:** `backend/src/modules/analytics/analytics.service.ts`

```typescript
// Standing entry
interface StandingEntry {
    teamId: string;
    played: number;
    won: number;
    drawn: number;
    lost: number;
    gf: number;      // Goals for
    ga: number;      // Goals against
    gd: number;      // Goal difference
    points: number;
}
```

**Service Methods:**
- `getStandings(fixtureId)` - Get league standings table
- `getTopScorers(fixtureId, limit?)` - Get top scorers
- `getMatchStats(matchId)` - Get match statistics

---

## Frontend Dart Models

### Centralized Models

**Location:** `frontend/lib/core/models/models.dart`

This file contains all shared data models used across the Flutter app.

#### Enums

```dart
// User roles
enum UserRole { admin, coach, referee, spectator }

// Approval status
enum ApprovalStatus { pending, approved, rejected }

// Match status
enum MatchStatus { scheduled, live, completed, cancelled, postponed }

// Match event types
enum MatchEventType {
    goal, yellowCard, redCard, substitution,
    corner, penalty, assist, shot
}

// Notification types
enum NotificationType {
    matchStart, matchEnd, goal, card, substitution, general
}

// Player positions
enum PlayerPosition { goalkeeper, defender, midfielder, forward }
```

#### Data Classes

```dart
// User profile
class UserProfile {
    final String id;
    final String email;
    final String fullName;
    final UserRole role;
    final ApprovalStatus approvalStatus;
    final String? phone;
    final String? avatarUrl;
    final String? teamName;
    
    factory UserProfile.fromJson(Map<String, dynamic> json);
    Map<String, dynamic> toJson();
}

// Team
class Team {
    final String id;
    final String name;
    final String? logoUrl;
    final String? coachId;
    final UserProfile? coach;
    final String? submissionStatus;
    final DateTime? submittedAt;
    final String? rejectionNote;
    
    factory Team.fromJson(Map<String, dynamic> json);
    Map<String, dynamic> toJson();
}

// Player
class Player {
    final String id;
    final String name;
    final String teamId;
    final String position;
    final int jerseyNumber;
    final DateTime? dateOfBirth;
    final String? photoUrl;
    final Team? team;
    
    factory Player.fromJson(Map<String, dynamic> json);
    Map<String, dynamic> toJson();
}

// Match
class Match {
    final String id;
    final String fixtureId;
    final String homeTeamId;
    final String awayTeamId;
    final DateTime scheduledAt;
    final String? venue;
    final MatchStatus status;
    final int homeScore;
    final int awayScore;
    final Team? homeTeam;
    final Team? awayTeam;
    
    factory Match.fromJson(Map<String, dynamic> json);
    Map<String, dynamic> toJson();
}

// Venue
class Venue {
    final String id;
    final String name;
    final String? location;
    final int? capacity;
    final bool isActive;
    
    factory Venue.fromJson(Map<String, dynamic> json);
    Map<String, dynamic> toJson();
}

// Notification
class Notification {
    final String id;
    final String? userId;
    final String title;
    final String body;
    final NotificationType type;
    final Map<String, dynamic>? data;
    final bool read;
    final DateTime createdAt;
    
    factory Notification.fromJson(Map<String, dynamic> json);
    Map<String, dynamic> toJson();
}
```

---

### State Management

#### AppState

**Location:** `frontend/lib/core/state/app_state.dart`

Manages global app settings (theme, language).

```dart
enum AppLanguage { english, kiswahili }

class AppState extends ChangeNotifier {
    bool isDarkMode;
    AppLanguage language;
    
    void toggleDarkMode(bool value);
    void setLanguage(AppLanguage language);
    String translate(String key);
}
```

#### MatchState

**Location:** `frontend/lib/core/state/match_state.dart`

Manages all match-related state with real-time sync.

```dart
// Match event
class MatchEvent {
    final String type;
    final String team;
    final String playerName;
    final int minute;
    final String? detail;
}

// Lineup player
class LineupPlayer {
    final String name;
    final String position;
    final int jerseyNo;
    final String team;
    final String? photoUrl;
    bool hasYellow;
    bool hasRed;
    bool isSubstituted;
}

// Generated fixture
class GeneratedFixture {
    final String id;
    final String homeTeam;
    final String awayTeam;
    DateTime dateTime;
    String venue;
    String? assignedReferee;
    bool venueConfirmed;
    int homeScore;
    int awayScore;
    String status;
    List<MatchEvent> events;
    
    Map<String, dynamic> toRow();
    static GeneratedFixture fromRow(Map<String, dynamic> r);
}

// Standing entry
class StandingEntry {
    final String team;
    int played, wins, draws, losses;
    int goalsFor, goalsAgainst, points;
    int get goalDifference;
}

class MatchState extends ChangeNotifier {
    // Fixture management
    Future<void> loadFixtures();
    Future<String?> updateFixture(String id, {...});
    Future<String?> deleteFixture(String id);
    Future<void> clearAllFixtures();
    
    // Fixture generation
    Future<void> generateRoundRobin({...});
    Future<void> autoAssignReferees(List<String> referees);
    
    // Lineup management
    void submitLineup(String fixtureId, List<LineupPlayer> players);
    
    // Match events
    void setLiveFixture(String fixtureId);
    void recordGoal({...});
    void recordCard({...});
    void recordSubstitution({...});
    void endMatch(String fixtureId);
    
    // Substitution requests
    void requestSubstitution({...});
    void approveSubstitution(int index, int minute);
    
    // Helpers
    List<GeneratedFixture> fixturesForTeam(String teamName);
    List<GeneratedFixture> fixturesForReferee(String refereeName);
}
```

#### AuthProvider

**Location:** `frontend/lib/core/auth/auth_provider.dart`

Manages authentication and user data.

```dart
class AuthProvider extends ChangeNotifier {
    User? user;
    String? role;
    String? approvalStatus;
    bool isLoading;
    Map<String, dynamic>? profile;
    
    // Authentication
    Future<String?> signIn(String email, String password);
    Future<String?> signUp(...);
    Future<void> signOut();
    
    // Profile management
    Future<void> fetchProfile();
    Future<String?> updateProfile({...});
    Future<String?> uploadAvatar(dynamic imageSource);
    
    // Admin functions
    Future<List<Map<String, dynamic>>> getPendingUsers();
    Future<void> approveUser(String userId);
    Future<List<Map<String, dynamic>>> getApprovedUsers(String role);
    
    // Team management
    Future<List<Map<String, dynamic>>> getTeams();
    Future<String?> updateTeam(String teamId, {...});
    Future<String?> uploadTeamLogo(String teamId, dynamic imageSource);
    
    // Player management
    Future<List<Map<String, dynamic>>> getPlayers();
    
    // Squad submission workflow
    Future<String?> submitSquad(String teamId);
    Future<List<Map<String, dynamic>>> getSubmittedSquads();
    Future<String?> reviewSquad(String teamId, {...});
    
    // Venue management
    Future<List<Map<String, dynamic>>> getVenues();
    Future<String?> addVenue({...});
    Future<String?> updateVenue(String id, {...});
    Future<String?> deleteVenue(String id);
}
```

---

### API Clients

#### ApiClient

**Location:** `frontend/lib/core/api/api_client.dart`

HTTP client with automatic JWT token attachment.

```dart
class ApiClient {
    final Dio dio;
    
    Future<Response> get(String path, {...});
    Future<Response> post(String path, {...});
    Future<Response> put(String path, {...});
    Future<Response> delete(String path);
    Future<Response> patch(String path, {...});
}
```

#### SocketClient

**Location:** `frontend/lib/core/api/socket_client.dart`

WebSocket client for real-time updates.

```dart
class SocketClient extends ChangeNotifier {
    IO.Socket socket;
    bool isConnected;
    
    void init(String url, String? token);
    void joinMatch(String matchId);
    void leaveMatch(String matchId);
}
```

---

## Best Practices

### Backend

1. **Use centralized types** from `backend/src/types/index.ts`
2. **Add JSDoc comments** to all interfaces and service methods
3. **Use DTOs** for request/response payloads
4. **Export interfaces** for reuse across modules
5. **Type all service methods** with proper return types

### Frontend

1. **Use centralized models** from `frontend/lib/core/models/models.dart`
2. **Add documentation comments** (///) to all classes and methods
3. **Implement fromJson/toJson** for all data classes
4. **Use enums** for fixed sets of values
5. **Extend ChangeNotifier** for state management classes

---

## Migration Guide

If you need to add a new interface:

### Backend

1. Add the type/interface to `backend/src/types/index.ts`
2. Import and use it in your service file
3. Add JSDoc documentation
4. Export any DTOs specific to that module

### Frontend

1. Add the model to `frontend/lib/core/models/models.dart`
2. Implement `fromJson` and `toJson` methods
3. Add documentation comments
4. Use the model in your state management classes

---

## Summary

All interfaces have been polished with:

✅ **Comprehensive documentation** - JSDoc (TypeScript) and dartdoc (Dart) comments  
✅ **Centralized types** - Single source of truth for shared types  
✅ **Consistent naming** - Clear, descriptive names following conventions  
✅ **Type safety** - Proper typing throughout the codebase  
✅ **Reusability** - Interfaces designed for reuse across modules  
✅ **Best practices** - Following TypeScript and Dart standards  

The codebase now has a solid foundation for type-safe development with clear contracts between components.
