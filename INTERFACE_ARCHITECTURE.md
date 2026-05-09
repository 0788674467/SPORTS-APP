# Interface Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Sports Management Platform                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
         ┌──────▼──────┐            ┌──────▼──────┐
         │   Backend   │            │  Frontend   │
         │ (TypeScript)│◄──────────►│   (Dart)    │
         └──────┬──────┘   REST API └──────┬──────┘
                │          WebSocket        │
                │                           │
         ┌──────▼──────┐            ┌──────▼──────┐
         │  Supabase   │            │   Mobile    │
         │ (PostgreSQL)│            │     Web     │
         └─────────────┘            └─────────────┘
```

---

## Backend Interface Structure

```
backend/src/
│
├── types/
│   └── index.ts ◄─────────────────┐ Centralized Types
│       ├── UserRole               │ (Single Source of Truth)
│       ├── MatchStatus            │
│       ├── NotificationType       │
│       ├── AuthUser               │
│       ├── Team, Player, Match    │
│       └── StandingEntry          │
│                                   │
├── middleware/                     │
│   └── auth.middleware.ts          │
│       └── AuthRequest ────────────┤ Imports from types/
│                                   │
└── modules/                        │
    ├── auth/                       │
    │   └── auth.service.ts         │
    │       ├── SignUpDto ──────────┤
    │       └── SignInDto ──────────┤
    │                               │
    ├── teams/                      │
    │   └── teams.service.ts        │
    │       ├── CreateTeamDto ──────┤
    │       └── UpdateTeamDto ──────┤
    │                               │
    ├── players/                    │
    │   └── players.service.ts      │
    │       ├── CreatePlayerDto ────┤
    │       └── UpdatePlayerDto ────┤
    │                               │
    ├── matches/                    │
    │   └── matches.service.ts      │
    │       └── RecordEventPayload ─┤
    │                               │
    ├── fixtures/                   │
    │   ├── fixtures.service.ts     │
    │   │   └── GenerateFixtureDto ─┤
    │   └── fixture.engine.ts       │
    │       └── ScheduledMatch ─────┤
    │                               │
    ├── notifications/              │
    │   └── notifications.service.ts│
    │       └── NotificationPayload ┤
    │                               │
    └── analytics/                  │
        └── analytics.service.ts ───┘
```

---

## Frontend Model Structure

```
frontend/lib/
│
├── core/
│   ├── models/
│   │   └── models.dart ◄──────────────┐ Centralized Models
│   │       ├── UserRole (enum)        │ (Single Source of Truth)
│   │       ├── MatchStatus (enum)     │
│   │       ├── NotificationType (enum)│
│   │       ├── UserProfile (class)    │
│   │       ├── Team (class)           │
│   │       ├── Player (class)         │
│   │       ├── Match (class)          │
│   │       ├── Venue (class)          │
│   │       └── Notification (class)   │
│   │                                   │
│   ├── state/                          │
│   │   ├── app_state.dart              │
│   │   │   ├── AppLanguage (enum) ────┤
│   │   │   └── AppState (class) ──────┤
│   │   │                               │
│   │   └── match_state.dart            │
│   │       ├── MatchEvent (class) ────┤
│   │       ├── LineupPlayer (class) ──┤
│   │       ├── GeneratedFixture ──────┤
│   │       ├── StandingEntry (class) ─┤
│   │       └── MatchState (class) ────┤
│   │                                   │
│   ├── auth/                           │
│   │   └── auth_provider.dart          │
│   │       └── AuthProvider (class) ──┤
│   │                                   │
│   └── api/                            │
│       ├── api_client.dart             │
│       │   └── ApiClient (class) ─────┤
│       └── socket_client.dart          │
│           └── SocketClient (class) ──┘
│
└── features/
    ├── admin/
    ├── coach/
    ├── referee/
    └── spectator/
```

---

## Data Flow Architecture

### 1. Authentication Flow

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Flutter   │         │   Backend    │         │  Supabase   │
│     App     │         │   Express    │         │    Auth     │
└──────┬──────┘         └──────┬───────┘         └──────┬──────┘
       │                       │                        │
       │  SignInDto            │                        │
       ├──────────────────────►│  signInWithPassword   │
       │                       ├───────────────────────►│
       │                       │                        │
       │                       │  ◄─────────────────────┤
       │  ◄────────────────────┤  JWT Token             │
       │  AuthUser             │                        │
       │                       │                        │
```

### 2. Match Event Flow

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  Referee    │         │   Backend    │         │  Spectator  │
│     App     │         │   Socket.IO  │         │     App     │
└──────┬──────┘         └──────┬───────┘         └──────┬──────┘
       │                       │                        │
       │  RecordEventPayload   │                        │
       ├──────────────────────►│                        │
       │                       │  Broadcast Event       │
       │                       ├───────────────────────►│
       │                       │  MatchEvent            │
       │                       │                        │
       │  ◄────────────────────┤                        │
       │  Confirmation         │                        │
       │                       │                        │
```

### 3. Fixture Generation Flow

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│    Admin    │         │   Backend    │         │  Supabase   │
│     App     │         │   Service    │         │     DB      │
└──────┬──────┘         └──────┬───────┘         └──────┬──────┘
       │                       │                        │
       │  GenerateFixtureDto   │                        │
       ├──────────────────────►│                        │
       │                       │  Round-Robin Algorithm │
       │                       │  (Fixture Engine)      │
       │                       │                        │
       │                       │  Insert Matches        │
       │                       ├───────────────────────►│
       │                       │                        │
       │  ◄────────────────────┤  ◄─────────────────────┤
       │  Fixture + Matches    │  Confirmation          │
       │                       │                        │
```

---

## Interface Relationships

### Backend Type Dependencies

```
┌──────────────────────────────────────────────────────────┐
│                    types/index.ts                        │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │  UserRole  │  │ MatchStatus│  │NotificationType│     │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘        │
│        │               │               │                │
│  ┌─────▼──────┐  ┌─────▼──────┐  ┌─────▼──────┐        │
│  │  AuthUser  │  │   Match    │  │Notification│        │
│  └────────────┘  └────────────┘  └────────────┘        │
└──────────────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌─────▼─────┐   ┌────▼────┐
    │  Auth   │    │  Matches  │   │ Notif.  │
    │ Service │    │  Service  │   │ Service │
    └─────────┘    └───────────┘   └─────────┘
```

### Frontend Model Dependencies

```
┌──────────────────────────────────────────────────────────┐
│                 core/models/models.dart                  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │  UserRole  │  │ MatchStatus│  │PlayerPosition│       │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘        │
│        │               │               │                │
│  ┌─────▼──────┐  ┌─────▼──────┐  ┌─────▼──────┐        │
│  │UserProfile │  │   Match    │  │   Player   │        │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘        │
│        │               │               │                │
│        └───────────────┼───────────────┘                │
└────────────────────────┼──────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌─────▼─────┐   ┌────▼────┐
    │  Auth   │    │   Match   │   │   API   │
    │Provider │    │   State   │   │ Client  │
    └─────────┘    └───────────┘   └─────────┘
```

---

## Interface Communication Patterns

### 1. Request/Response Pattern (REST API)

```
Frontend                Backend                 Database
   │                       │                       │
   │  HTTP Request         │                       │
   │  (CreateTeamDto)      │                       │
   ├──────────────────────►│                       │
   │                       │  SQL Query            │
   │                       ├──────────────────────►│
   │                       │                       │
   │                       │  ◄────────────────────┤
   │  ◄────────────────────┤  Result               │
   │  HTTP Response        │                       │
   │  (Team)               │                       │
```

### 2. Real-time Pattern (WebSocket)

```
Client A              Socket.IO Server         Client B
   │                       │                       │
   │  Emit Event           │                       │
   │  (RecordEventPayload) │                       │
   ├──────────────────────►│                       │
   │                       │  Broadcast            │
   │                       ├──────────────────────►│
   │                       │  (MatchEvent)         │
   │                       │                       │
```

### 3. State Management Pattern

```
UI Component          State Provider          Backend API
   │                       │                       │
   │  Call Method          │                       │
   ├──────────────────────►│                       │
   │                       │  API Request          │
   │                       ├──────────────────────►│
   │                       │                       │
   │                       │  ◄────────────────────┤
   │  ◄────────────────────┤  Response             │
   │  notifyListeners()    │                       │
   │  (UI Rebuilds)        │                       │
```

---

## Type Safety Flow

### Backend (TypeScript)

```typescript
// 1. Define centralized type
export type UserRole = 'admin' | 'coach' | 'referee' | 'spectator';

// 2. Use in DTO
export interface SignUpDto {
    role: UserRole;  // ✅ Type-safe
}

// 3. Use in service
async signUp(dto: SignUpDto) {
    // TypeScript enforces dto.role is UserRole
}

// 4. Use in middleware
interface AuthRequest extends Request {
    user?: { role: UserRole };  // ✅ Type-safe
}
```

### Frontend (Dart)

```dart
// 1. Define centralized enum
enum UserRole { admin, coach, referee, spectator }

// 2. Use in model
class UserProfile {
    final UserRole role;  // ✅ Type-safe
}

// 3. Use in state
class AuthProvider {
    UserRole? get role => _role;  // ✅ Type-safe
}

// 4. Use in UI
if (authProvider.role == UserRole.admin) {
    // Show admin features
}
```

---

## Benefits of This Architecture

### 1. Single Source of Truth
- ✅ All types defined in one place
- ✅ No duplicate definitions
- ✅ Easy to update across codebase

### 2. Type Safety
- ✅ Compile-time error checking
- ✅ IDE autocomplete support
- ✅ Refactoring confidence

### 3. Clear Contracts
- ✅ Well-defined interfaces between layers
- ✅ Documentation at the type level
- ✅ Easy to understand data flow

### 4. Maintainability
- ✅ Changes propagate through type system
- ✅ Breaking changes caught early
- ✅ Self-documenting code

### 5. Scalability
- ✅ Easy to add new features
- ✅ Consistent patterns
- ✅ Modular architecture

---

## Summary

The interface architecture provides:

✅ **Centralized type definitions** in `types/index.ts` (backend) and `models.dart` (frontend)  
✅ **Clear data flow** through well-defined interfaces  
✅ **Type safety** at every layer of the application  
✅ **Consistent patterns** across the entire codebase  
✅ **Professional structure** for long-term maintainability  

This architecture ensures that the Sports Management Platform has a solid, scalable foundation for continued development.
