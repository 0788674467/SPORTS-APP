import 'package:flutter_test/flutter_test.dart';
import 'package:sports_app/core/models/models.dart';

void main() {
  group('UserRole enum', () {
    test('has admin, coach, referee, spectator', () {
      expect(UserRole.values, hasLength(4));
      expect(UserRole.admin.name, 'admin');
      expect(UserRole.coach.name, 'coach');
      expect(UserRole.referee.name, 'referee');
      expect(UserRole.spectator.name, 'spectator');
    });
  });

  group('ApprovalStatus enum', () {
    test('has pending, approved, rejected', () {
      expect(ApprovalStatus.values, hasLength(3));
      expect(ApprovalStatus.pending.name, 'pending');
      expect(ApprovalStatus.approved.name, 'approved');
      expect(ApprovalStatus.rejected.name, 'rejected');
    });
  });

  group('UserProfile', () {
    final json = {
      'id': 'u1',
      'email': 'admin@test.com',
      'full_name': 'Admin User',
      'role': 'admin',
      'approval_status': 'approved',
      'phone': '+256700000000',
      'avatar_url': 'https://example.com/avatar.png',
      'team_name': 'Eagles FC',
    };

    test('fromJson parses role correctly', () {
      final profile = UserProfile.fromJson(json);
      expect(profile.id, 'u1');
      expect(profile.email, 'admin@test.com');
      expect(profile.fullName, 'Admin User');
      expect(profile.role, UserRole.admin);
      expect(profile.approvalStatus, ApprovalStatus.approved);
      expect(profile.phone, '+256700000000');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.teamName, 'Eagles FC');
    });

    test('fromJson defaults to spectator when role is null', () {
      final noRole = UserProfile.fromJson({'id': 'u2', 'email': 'a@b.com', 'full_name': 'A', 'approval_status': 'pending'});
      expect(noRole.role, UserRole.spectator);
    });

    test('fromJson defaults to pending when status is null', () {
      final noStatus = UserProfile.fromJson({'id': 'u3', 'email': 'a@b.com', 'full_name': 'B', 'role': 'coach'});
      expect(noStatus.approvalStatus, ApprovalStatus.pending);
    });

    test('toJson returns all fields including optionals', () {
      final profile = UserProfile.fromJson(json);
      final result = profile.toJson();
      expect(result['id'], 'u1');
      expect(result['email'], 'admin@test.com');
      expect(result['full_name'], 'Admin User');
      expect(result['role'], 'admin');
      expect(result['approval_status'], 'approved');
      expect(result['phone'], '+256700000000');
      expect(result['avatar_url'], 'https://example.com/avatar.png');
      expect(result['team_name'], 'Eagles FC');
    });

    test('toJson omits null optionals', () {
      final minimal = UserProfile(id: 'u4', email: 'x@y.com', fullName: 'X', role: UserRole.spectator, approvalStatus: ApprovalStatus.pending);
      final result = minimal.toJson();
      expect(result.containsKey('phone'), false);
      expect(result.containsKey('avatar_url'), false);
      expect(result.containsKey('team_name'), false);
    });

    test('roundtrip fromJson to toJson preserves data', () {
      final original = UserProfile.fromJson(json);
      final serialized = original.toJson();
      final restored = UserProfile.fromJson(serialized);
      expect(restored.id, original.id);
      expect(restored.email, original.email);
      expect(restored.fullName, original.fullName);
      expect(restored.role, original.role);
      expect(restored.approvalStatus, original.approvalStatus);
      expect(restored.phone, original.phone);
      expect(restored.avatarUrl, original.avatarUrl);
      expect(restored.teamName, original.teamName);
    });
  });

  group('PlayerPosition enum', () {
    test('has all four positions', () {
      expect(PlayerPosition.values, hasLength(4));
      expect(PlayerPosition.goalkeeper.name, 'goalkeeper');
      expect(PlayerPosition.defender.name, 'defender');
      expect(PlayerPosition.midfielder.name, 'midfielder');
      expect(PlayerPosition.forward.name, 'forward');
    });
  });

  group('Player', () {
    final json = {
      'id': 'p1',
      'name': 'John Doe',
      'team_id': 't1',
      'position': 'forward',
      'jersey_number': 10,
      'date_of_birth': '2000-01-15T00:00:00.000',
      'photo_url': 'https://example.com/photo.jpg',
    };

    test('fromJson parses all fields', () {
      final player = Player.fromJson(json);
      expect(player.id, 'p1');
      expect(player.name, 'John Doe');
      expect(player.teamId, 't1');
      expect(player.position, 'forward');
      expect(player.jerseyNumber, 10);
      expect(player.dateOfBirth, DateTime(2000, 1, 15));
      expect(player.photoUrl, 'https://example.com/photo.jpg');
    });

    test('fromJson handles null dateOfBirth', () {
      final noDob = Player.fromJson({'id': 'p2', 'name': 'Jane', 'team_id': 't1', 'position': 'midfielder', 'jersey_number': 8});
      expect(noDob.dateOfBirth, isNull);
    });

    test('toJson includes all fields', () {
      final player = Player.fromJson(json);
      final result = player.toJson();
      expect(result['id'], 'p1');
      expect(result['name'], 'John Doe');
      expect(result['team_id'], 't1');
      expect(result['position'], 'forward');
      expect(result['jersey_number'], 10);
      expect(result['date_of_birth'], '2000-01-15T00:00:00.000');
      expect(result['photo_url'], 'https://example.com/photo.jpg');
    });

    test('toJson omits null dateOfBirth and photoUrl', () {
      final minimal = Player(id: 'p3', name: 'Bob', teamId: 't1', position: 'defender', jerseyNumber: 5);
      final result = minimal.toJson();
      expect(result.containsKey('date_of_birth'), false);
      expect(result.containsKey('photo_url'), false);
    });

    test('roundtrip preserves data', () {
      final original = Player.fromJson(json);
      final restored = Player.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.jerseyNumber, original.jerseyNumber);
      expect(restored.position, original.position);
    });
  });

  group('Team', () {
    final baseJson = {
      'id': 't1',
      'name': 'Eagles FC',
      'logo_url': 'https://example.com/logo.png',
      'coach_id': 'c1',
      'submission_status': 'approved',
      'submitted_at': '2026-01-10T00:00:00.000',
      'rejection_note': null,
    };

    test('fromJson parses all fields', () {
      final team = Team.fromJson(baseJson);
      expect(team.id, 't1');
      expect(team.name, 'Eagles FC');
      expect(team.logoUrl, 'https://example.com/logo.png');
      expect(team.coachId, 'c1');
      expect(team.submissionStatus, 'approved');
      expect(team.submittedAt, DateTime(2026, 1, 10));
      expect(team.rejectionNote, isNull);
    });

    test('fromJson parses nested coach profile', () {
      final withCoach = Map<String, dynamic>.from(baseJson);
      withCoach['profiles'] = {
        'id': 'c1', 'email': 'coach@test.com', 'full_name': 'Coach A',
        'role': 'coach', 'approval_status': 'approved',
      };
      final team = Team.fromJson(withCoach);
      expect(team.coach, isNotNull);
      expect(team.coach!.fullName, 'Coach A');
    });

    test('toJson excludes null optionals', () {
      final minimal = Team(id: 't2', name: 'Lions FC');
      final result = minimal.toJson();
      expect(result.containsKey('logo_url'), false);
      expect(result.containsKey('coach_id'), false);
      expect(result.containsKey('submission_status'), false);
      expect(result.containsKey('submitted_at'), false);
      expect(result.containsKey('rejection_note'), false);
    });

    test('roundtrip preserves data', () {
      final original = Team.fromJson(baseJson);
      final restored = Team.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.logoUrl, original.logoUrl);
    });
  });

  group('MatchStatus enum', () {
    test('has all status values', () {
      expect(MatchStatus.values, hasLength(5));
      expect(MatchStatus.scheduled.name, 'scheduled');
      expect(MatchStatus.live.name, 'live');
      expect(MatchStatus.completed.name, 'completed');
      expect(MatchStatus.cancelled.name, 'cancelled');
      expect(MatchStatus.postponed.name, 'postponed');
    });
  });

  group('MatchEventType enum', () {
    test('has all event types', () {
      expect(MatchEventType.values, hasLength(8));
      expect(MatchEventType.goal.name, 'goal');
      expect(MatchEventType.yellowCard.name, 'yellowCard');
      expect(MatchEventType.redCard.name, 'redCard');
      expect(MatchEventType.substitution.name, 'substitution');
      expect(MatchEventType.corner.name, 'corner');
      expect(MatchEventType.penalty.name, 'penalty');
      expect(MatchEventType.assist.name, 'assist');
      expect(MatchEventType.shot.name, 'shot');
    });
  });

  group('Match', () {
    final json = {
      'id': 'm1',
      'fixture_id': 'f1',
      'home_team_id': 't1',
      'away_team_id': 't2',
      'scheduled_at': '2026-06-01T15:00:00.000',
      'venue': 'Main Stadium',
      'status': 'scheduled',
      'home_score': 2,
      'away_score': 1,
    };

    test('fromJson parses all fields', () {
      final match = Match.fromJson(json);
      expect(match.id, 'm1');
      expect(match.fixtureId, 'f1');
      expect(match.homeTeamId, 't1');
      expect(match.awayTeamId, 't2');
      expect(match.scheduledAt, DateTime(2026, 6, 1, 15, 0));
      expect(match.venue, 'Main Stadium');
      expect(match.status, MatchStatus.scheduled);
      expect(match.homeScore, 2);
      expect(match.awayScore, 1);
    });

    test('fromJson defaults scores to 0', () {
      final noScore = Match.fromJson({
        'id': 'm2', 'fixture_id': 'f1', 'home_team_id': 't1', 'away_team_id': 't2',
        'scheduled_at': '2026-06-01T15:00:00.000', 'status': 'scheduled',
      });
      expect(noScore.homeScore, 0);
      expect(noScore.awayScore, 0);
    });

    test('fromJson parses live status', () {
      final live = Match.fromJson({...json, 'status': 'live'});
      expect(live.status, MatchStatus.live);
    });

    test('fromJson parses completed status', () {
      final done = Match.fromJson({...json, 'status': 'completed'});
      expect(done.status, MatchStatus.completed);
    });

    test('fromJson defaults null venue to null', () {
      final noVenue = Match.fromJson({...json, 'venue': null});
      expect(noVenue.venue, isNull);
    });

    test('toJson only includes non-null venue', () {
      final match = Match.fromJson(json);
      final result = match.toJson();
      expect(result['id'], 'm1');
      expect(result['home_score'], 2);
      expect(result['away_score'], 1);
      expect(result.containsKey('venue'), true);
    });

    test('toJson omits venue when null', () {
      final noVenue = Match(id: 'm3', fixtureId: 'f1', homeTeamId: 't1', awayTeamId: 't2',
          scheduledAt: DateTime(2026, 6, 1), status: MatchStatus.scheduled);
      final result = noVenue.toJson();
      expect(result.containsKey('venue'), false);
    });

    test('roundtrip preserves data', () {
      final original = Match.fromJson(json);
      final restored = Match.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.status, original.status);
      expect(restored.homeScore, original.homeScore);
      expect(restored.awayScore, original.awayScore);
    });
  });

  group('Venue', () {
    final json = {
      'id': 'v1',
      'name': 'Main Stadium',
      'location': 'Kampala',
      'capacity': 5000,
      'is_active': true,
    };

    test('fromJson parses all fields', () {
      final venue = Venue.fromJson(json);
      expect(venue.id, 'v1');
      expect(venue.name, 'Main Stadium');
      expect(venue.location, 'Kampala');
      expect(venue.capacity, 5000);
      expect(venue.isActive, true);
    });

    test('fromJson defaults isActive to true when null', () {
      final noActive = Venue.fromJson({'id': 'v2', 'name': 'Small Grounds'});
      expect(noActive.isActive, true);
    });

    test('toJson omits null location and capacity', () {
      final minimal = Venue(id: 'v3', name: 'Field');
      final result = minimal.toJson();
      expect(result.containsKey('location'), false);
      expect(result.containsKey('capacity'), false);
    });

    test('roundtrip preserves data', () {
      final original = Venue.fromJson(json);
      final restored = Venue.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.location, original.location);
      expect(restored.capacity, original.capacity);
      expect(restored.isActive, original.isActive);
    });
  });

  group('NotificationType enum', () {
    test('has all notification types', () {
      expect(NotificationType.values, hasLength(6));
      expect(NotificationType.matchStart.name, 'matchStart');
      expect(NotificationType.matchEnd.name, 'matchEnd');
      expect(NotificationType.goal.name, 'goal');
      expect(NotificationType.card.name, 'card');
      expect(NotificationType.substitution.name, 'substitution');
      expect(NotificationType.general.name, 'general');
    });
  });

  group('Notification', () {
    final json = {
      'id': 'n1',
      'user_id': 'u1',
      'title': 'Match Started',
      'body': 'Eagles vs Lions is live!',
      'type': 'match_start',
      'data': {'fixture_id': 'f1'},
      'read': false,
      'created_at': '2026-06-01T15:00:00.000',
    };

    test('fromJson parses all fields', () {
      final notif = Notification.fromJson(json);
      expect(notif.id, 'n1');
      expect(notif.userId, 'u1');
      expect(notif.title, 'Match Started');
      expect(notif.body, 'Eagles vs Lions is live!');
      expect(notif.type, NotificationType.matchStart);
      expect(notif.data, {'fixture_id': 'f1'});
      expect(notif.read, false);
      expect(notif.createdAt, DateTime(2026, 6, 1, 15, 0));
    });

    test('fromJson defaults read to false', () {
      final noRead = Notification.fromJson({
        'id': 'n2', 'title': 'T', 'body': 'B', 'type': 'goal',
        'created_at': '2026-01-01T00:00:00.000',
      });
      expect(noRead.read, false);
    });

    test('fromJson defaults type to general when unknown', () {
      final unknown = Notification.fromJson({
        'id': 'n3', 'title': 'T', 'body': 'B', 'type': 'unknown_type',
        'created_at': '2026-01-01T00:00:00.000',
      });
      expect(unknown.type, NotificationType.general);
    });

    test('fromJson defaults user_id to null', () {
      final noUser = Notification.fromJson({
        'id': 'n4', 'title': 'T', 'body': 'B', 'type': 'card',
        'created_at': '2026-01-01T00:00:00.000',
      });
      expect(noUser.userId, isNull);
    });

    test('toJson includes all fields', () {
      final notif = Notification.fromJson(json);
      final result = notif.toJson();
      expect(result['id'], 'n1');
      expect(result['user_id'], 'u1');
      expect(result['title'], 'Match Started');
      expect(result['body'], 'Eagles vs Lions is live!');
      expect(result['type'], 'matchStart');
      expect(result['data'], {'fixture_id': 'f1'});
      expect(result['read'], false);
    });

    test('toJson omits null userId and data', () {
      final minimal = Notification(
        id: 'n5', title: 'T', body: 'B', type: NotificationType.general,
        createdAt: DateTime(2026, 1, 1),
      );
      final result = minimal.toJson();
      expect(result.containsKey('user_id'), false);
      expect(result.containsKey('data'), false);
    });

    test('roundtrip preserves data', () {
      final original = Notification.fromJson(json);
      final restored = Notification.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.type, original.type);
      expect(restored.read, original.read);
    });
  });
}
