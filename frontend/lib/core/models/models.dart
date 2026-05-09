/**
 * Centralized data models for the Sports Management Platform.
 * 
 * This file contains all shared data classes and enums used across
 * the Flutter application for consistency and type safety.
 */

// ─── User & Authentication Models ────────────────────────────────────────────

/// User roles supported by the system.
enum UserRole {
  /// System administrator with full access
  admin,
  
  /// Team coach with team management access
  coach,
  
  /// Match referee with match control access
  referee,
  
  /// Spectator with read-only access
  spectator,
}

/// User approval status for role-based access control.
enum ApprovalStatus {
  /// Awaiting admin approval
  pending,
  
  /// Approved by admin
  approved,
  
  /// Rejected by admin
  rejected,
}

/// Represents a user profile.
class UserProfile {
  /// User's unique identifier
  final String id;
  
  /// User's email address
  final String email;
  
  /// User's full name
  final String fullName;
  
  /// User's role
  final UserRole role;
  
  /// User's approval status
  final ApprovalStatus approvalStatus;
  
  /// User's phone number
  final String? phone;
  
  /// URL to user's avatar image
  final String? avatarUrl;
  
  /// Team name (for coaches)
  final String? teamName;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.approvalStatus,
    this.phone,
    this.avatarUrl,
    this.teamName,
  });

  /// Creates a UserProfile from a JSON map.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: _parseRole(json['role'] as String?),
      approvalStatus: _parseApprovalStatus(json['approval_status'] as String?),
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      teamName: json['team_name'] as String?,
    );
  }

  /// Converts the UserProfile to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'approval_status': approvalStatus.name,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (teamName != null) 'team_name': teamName,
    };
  }

  static UserRole _parseRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'coach':
        return UserRole.coach;
      case 'referee':
        return UserRole.referee;
      default:
        return UserRole.spectator;
    }
  }

  static ApprovalStatus _parseApprovalStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return ApprovalStatus.approved;
      case 'rejected':
        return ApprovalStatus.rejected;
      default:
        return ApprovalStatus.pending;
    }
  }
}

// ─── Team Models ─────────────────────────────────────────────────────────────

/// Represents a sports team.
class Team {
  /// Team's unique identifier
  final String id;
  
  /// Team name
  final String name;
  
  /// URL to team logo image
  final String? logoUrl;
  
  /// Coach user ID
  final String? coachId;
  
  /// Coach profile (if joined)
  final UserProfile? coach;
  
  /// Team submission status
  final String? submissionStatus;
  
  /// When the squad was submitted
  final DateTime? submittedAt;
  
  /// Rejection note from admin
  final String? rejectionNote;

  Team({
    required this.id,
    required this.name,
    this.logoUrl,
    this.coachId,
    this.coach,
    this.submissionStatus,
    this.submittedAt,
    this.rejectionNote,
  });

  /// Creates a Team from a JSON map.
  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      coachId: json['coach_id'] as String?,
      coach: json['profiles'] != null 
          ? UserProfile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
      submissionStatus: json['submission_status'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      rejectionNote: json['rejection_note'] as String?,
    );
  }

  /// Converts the Team to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (coachId != null) 'coach_id': coachId,
      if (submissionStatus != null) 'submission_status': submissionStatus,
      if (submittedAt != null) 'submitted_at': submittedAt!.toIso8601String(),
      if (rejectionNote != null) 'rejection_note': rejectionNote,
    };
  }
}

// ─── Player Models ───────────────────────────────────────────────────────────

/// Player positions on the field.
enum PlayerPosition {
  /// Goalkeeper
  goalkeeper,
  
  /// Defender
  defender,
  
  /// Midfielder
  midfielder,
  
  /// Forward/Striker
  forward,
}

/// Represents a player.
class Player {
  /// Player's unique identifier
  final String id;
  
  /// Player's full name
  final String name;
  
  /// Team the player belongs to
  final String teamId;
  
  /// Player's position
  final String position;
  
  /// Player's jersey number
  final int jerseyNumber;
  
  /// Player's date of birth
  final DateTime? dateOfBirth;
  
  /// URL to player's photo
  final String? photoUrl;
  
  /// Team details (if joined)
  final Team? team;

  Player({
    required this.id,
    required this.name,
    required this.teamId,
    required this.position,
    required this.jerseyNumber,
    this.dateOfBirth,
    this.photoUrl,
    this.team,
  });

  /// Creates a Player from a JSON map.
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      teamId: json['team_id'] as String,
      position: json['position'] as String,
      jerseyNumber: json['jersey_number'] as int,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      photoUrl: json['photo_url'] as String?,
      team: json['teams'] != null
          ? Team.fromJson(json['teams'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Converts the Player to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'team_id': teamId,
      'position': position,
      'jersey_number': jerseyNumber,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth!.toIso8601String(),
      if (photoUrl != null) 'photo_url': photoUrl,
    };
  }
}

// ─── Match Models ────────────────────────────────────────────────────────────

/// Match status types.
enum MatchStatus {
  /// Match is scheduled but not started
  scheduled,
  
  /// Match is currently in progress
  live,
  
  /// Match has finished
  completed,
  
  /// Match has been cancelled
  cancelled,
  
  /// Match is postponed
  postponed,
}

/// Match event types.
enum MatchEventType {
  /// Goal scored
  goal,
  
  /// Yellow card issued
  yellowCard,
  
  /// Red card issued
  redCard,
  
  /// Player substitution
  substitution,
  
  /// Corner kick
  corner,
  
  /// Penalty kick
  penalty,
  
  /// Assist
  assist,
  
  /// Shot on goal
  shot,
}

/// Represents a match.
class Match {
  /// Match's unique identifier
  final String id;
  
  /// Fixture the match belongs to
  final String fixtureId;
  
  /// Home team ID
  final String homeTeamId;
  
  /// Away team ID
  final String awayTeamId;
  
  /// Scheduled match date and time
  final DateTime scheduledAt;
  
  /// Venue name or location
  final String? venue;
  
  /// Match status
  final MatchStatus status;
  
  /// Home team score
  final int homeScore;
  
  /// Away team score
  final int awayScore;
  
  /// Home team details (if joined)
  final Team? homeTeam;
  
  /// Away team details (if joined)
  final Team? awayTeam;

  Match({
    required this.id,
    required this.fixtureId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.scheduledAt,
    this.venue,
    required this.status,
    this.homeScore = 0,
    this.awayScore = 0,
    this.homeTeam,
    this.awayTeam,
  });

  /// Creates a Match from a JSON map.
  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as String,
      fixtureId: json['fixture_id'] as String,
      homeTeamId: json['home_team_id'] as String,
      awayTeamId: json['away_team_id'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      venue: json['venue'] as String?,
      status: _parseMatchStatus(json['status'] as String?),
      homeScore: json['home_score'] as int? ?? 0,
      awayScore: json['away_score'] as int? ?? 0,
      homeTeam: json['home_team'] != null
          ? Team.fromJson(json['home_team'] as Map<String, dynamic>)
          : null,
      awayTeam: json['away_team'] != null
          ? Team.fromJson(json['away_team'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Converts the Match to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fixture_id': fixtureId,
      'home_team_id': homeTeamId,
      'away_team_id': awayTeamId,
      'scheduled_at': scheduledAt.toIso8601String(),
      if (venue != null) 'venue': venue,
      'status': status.name,
      'home_score': homeScore,
      'away_score': awayScore,
    };
  }

  static MatchStatus _parseMatchStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'live':
        return MatchStatus.live;
      case 'completed':
        return MatchStatus.completed;
      case 'cancelled':
        return MatchStatus.cancelled;
      case 'postponed':
        return MatchStatus.postponed;
      default:
        return MatchStatus.scheduled;
    }
  }
}

// ─── Venue Models ────────────────────────────────────────────────────────────

/// Represents a venue where matches are played.
class Venue {
  /// Venue's unique identifier
  final String id;
  
  /// Venue name
  final String name;
  
  /// Venue location/address
  final String? location;
  
  /// Venue capacity
  final int? capacity;
  
  /// Whether the venue is active
  final bool isActive;

  Venue({
    required this.id,
    required this.name,
    this.location,
    this.capacity,
    this.isActive = true,
  });

  /// Creates a Venue from a JSON map.
  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String?,
      capacity: json['capacity'] as int?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Converts the Venue to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (location != null) 'location': location,
      if (capacity != null) 'capacity': capacity,
      'is_active': isActive,
    };
  }
}

// ─── Notification Models ─────────────────────────────────────────────────────

/// Notification types.
enum NotificationType {
  /// Match has started
  matchStart,
  
  /// Match has ended
  matchEnd,
  
  /// Goal scored
  goal,
  
  /// Card issued
  card,
  
  /// Player substitution
  substitution,
  
  /// General announcement
  general,
}

/// Represents a notification.
class Notification {
  /// Notification's unique identifier
  final String id;
  
  /// Target user ID (null for broadcast)
  final String? userId;
  
  /// Notification title
  final String title;
  
  /// Notification body/message
  final String body;
  
  /// Notification type
  final NotificationType type;
  
  /// Additional metadata
  final Map<String, dynamic>? data;
  
  /// Whether the notification has been read
  final bool read;
  
  /// When the notification was created
  final DateTime createdAt;

  Notification({
    required this.id,
    this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.read = false,
    required this.createdAt,
  });

  /// Creates a Notification from a JSON map.
  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      type: _parseNotificationType(json['type'] as String?),
      data: json['data'] as Map<String, dynamic>?,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converts the Notification to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'title': title,
      'body': body,
      'type': type.name,
      if (data != null) 'data': data,
      'read': read,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static NotificationType _parseNotificationType(String? type) {
    switch (type?.toLowerCase()) {
      case 'match_start':
        return NotificationType.matchStart;
      case 'match_end':
        return NotificationType.matchEnd;
      case 'goal':
        return NotificationType.goal;
      case 'card':
        return NotificationType.card;
      case 'substitution':
        return NotificationType.substitution;
      default:
        return NotificationType.general;
    }
  }
}
