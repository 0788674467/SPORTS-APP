/**
 * Centralized type definitions for the Sports Management Platform.
 * 
 * This file contains all shared interfaces, types, and enums used across
 * the backend application for consistency and type safety.
 */

// ─── User & Authentication Types ─────────────────────────────────────────────

/**
 * User role types supported by the system.
 */
export type UserRole = 'admin' | 'coach' | 'referee' | 'spectator';

/**
 * User approval status for role-based access control.
 */
export type ApprovalStatus = 'pending' | 'approved' | 'rejected';

/**
 * Authenticated user information.
 */
export interface AuthUser {
    /** User's unique identifier */
    id: string;
    /** User's email address */
    email: string;
    /** User's role in the system */
    role: UserRole;
}

// ─── Match Types ─────────────────────────────────────────────────────────────

/**
 * Possible states of a match.
 */
export type MatchStatus = 
    | 'scheduled'  // Match is scheduled but not started
    | 'live'       // Match is currently in progress
    | 'completed'  // Match has finished
    | 'cancelled'; // Match has been cancelled

/**
 * Types of events that can occur during a match.
 */
export type MatchEventType = 
    | 'goal' 
    | 'yellow_card' 
    | 'red_card' 
    | 'substitution'
    | 'corner'
    | 'penalty'
    | 'assist';

// ─── Notification Types ──────────────────────────────────────────────────────

/**
 * Types of notifications that can be sent to users.
 */
export type NotificationType = 
    | 'match_start'    // Match has started
    | 'match_end'      // Match has ended
    | 'goal'           // Goal scored
    | 'card'           // Card issued (yellow/red)
    | 'substitution'   // Player substitution
    | 'general';       // General announcement

// ─── Player Types ────────────────────────────────────────────────────────────

/**
 * Player positions on the field.
 */
export type PlayerPosition = 
    | 'Goalkeeper' 
    | 'Defender' 
    | 'Midfielder' 
    | 'Forward';

// ─── Database Entity Interfaces ──────────────────────────────────────────────

/**
 * Team entity from the database.
 */
export interface Team {
    id: string;
    name: string;
    logo_url?: string;
    coach_id?: string;
    created_at: string;
    updated_at: string;
}

/**
 * Player entity from the database.
 */
export interface Player {
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

/**
 * Match entity from the database.
 */
export interface Match {
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

/**
 * Match event entity from the database.
 */
export interface MatchEvent {
    id: string;
    match_id: string;
    player_id: string;
    team_id: string;
    event_type: MatchEventType;
    minute: number;
    notes?: string;
    created_at: string;
}

/**
 * Fixture entity from the database.
 */
export interface Fixture {
    id: string;
    name: string;
    season: string;
    created_at: string;
    updated_at: string;
}

/**
 * Notification entity from the database.
 */
export interface Notification {
    id: string;
    user_id?: string;
    title: string;
    body: string;
    type: NotificationType;
    data?: Record<string, unknown>;
    read: boolean;
    created_at: string;
}

// ─── API Response Types ──────────────────────────────────────────────────────

/**
 * Standard API success response.
 */
export interface ApiSuccessResponse<T = unknown> {
    success: true;
    data: T;
    message?: string;
}

/**
 * Standard API error response.
 */
export interface ApiErrorResponse {
    success: false;
    error: string;
    statusCode: number;
}

/**
 * Paginated API response.
 */
export interface PaginatedResponse<T> {
    data: T[];
    pagination: {
        page: number;
        limit: number;
        total: number;
        totalPages: number;
    };
}

// ─── Analytics Types ─────────────────────────────────────────────────────────

/**
 * Team standing in the league table.
 */
export interface StandingEntry {
    teamId: string;
    played: number;
    won: number;
    drawn: number;
    lost: number;
    gf: number;  // Goals for
    ga: number;  // Goals against
    gd: number;  // Goal difference
    points: number;
}

/**
 * Top scorer statistics.
 */
export interface TopScorer {
    playerId: string;
    playerName: string;
    teamId: string;
    teamName: string;
    goals: number;
}

/**
 * Match statistics summary.
 */
export interface MatchStats {
    matchId: string;
    homeTeamStats: TeamMatchStats;
    awayTeamStats: TeamMatchStats;
}

/**
 * Team statistics for a specific match.
 */
export interface TeamMatchStats {
    teamId: string;
    goals: number;
    shots: number;
    corners: number;
    yellowCards: number;
    redCards: number;
    possession?: number;
}
