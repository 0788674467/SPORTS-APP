import 'package:flutter_test/flutter_test.dart';
import 'package:sports_app/core/state/match_state.dart';

void main() {
  group('MatchEvent', () {
    test('constructs with required fields', () {
      final event = MatchEvent(type: 'goal', team: 'Eagles FC', playerName: 'John Doe', minute: 23);
      expect(event.type, 'goal');
      expect(event.team, 'Eagles FC');
      expect(event.playerName, 'John Doe');
      expect(event.minute, 23);
      expect(event.detail, isNull);
    });

    test('toJson converts correctly', () {
      final event = MatchEvent(type: 'yellow', team: 'Lions FC', playerName: 'Jane Smith', minute: 45, detail: 'Foul');
      final json = event.toJson();
      expect(json['type'], 'yellow');
      expect(json['team'], 'Lions FC');
      expect(json['player_name'], 'Jane Smith');
      expect(json['minute'], 45);
      expect(json['detail'], 'Foul');
    });

    test('fromJson restores from map', () {
      final restored = MatchEvent.fromJson({
        'type': 'goal',
        'team': 'Eagles FC',
        'player_name': 'John Doe',
        'minute': 67,
        'detail': 'Header',
      });
      expect(restored.type, 'goal');
      expect(restored.team, 'Eagles FC');
      expect(restored.playerName, 'John Doe');
      expect(restored.minute, 67);
      expect(restored.detail, 'Header');
    });

    test('fromJson uses defaults for missing fields', () {
      final restored = MatchEvent.fromJson({});
      expect(restored.type, 'unknown');
      expect(restored.team, 'Unknown');
      expect(restored.playerName, 'Unknown');
      expect(restored.minute, 0);
      expect(restored.detail, isNull);
    });

    test('roundtrip preserves data', () {
      final original = MatchEvent(type: 'goal', team: 'Eagles', playerName: 'John', minute: 30, detail: 'Left foot');
      final restored = MatchEvent.fromJson(original.toJson());
      expect(restored.type, original.type);
      expect(restored.team, original.team);
      expect(restored.playerName, original.playerName);
      expect(restored.minute, original.minute);
      expect(restored.detail, original.detail);
    });
  });

  group('StandingEntry', () {
    test('initializes with zero values', () {
      final entry = StandingEntry('Eagles FC');
      expect(entry.team, 'Eagles FC');
      expect(entry.played, 0);
      expect(entry.wins, 0);
      expect(entry.draws, 0);
      expect(entry.losses, 0);
      expect(entry.goalsFor, 0);
      expect(entry.goalsAgainst, 0);
      expect(entry.points, 0);
    });

    test('goalDifference returns positive diff', () {
      final entry = StandingEntry('Eagles FC');
      entry.goalsFor = 10;
      entry.goalsAgainst = 3;
      expect(entry.goalDifference, 7);
    });

    test('goalDifference returns negative diff', () {
      final entry = StandingEntry('Lions FC');
      entry.goalsFor = 2;
      entry.goalsAgainst = 8;
      expect(entry.goalDifference, -6);
    });

    test('goalDifference returns zero for equal goals', () {
      final entry = StandingEntry('Draw FC');
      entry.goalsFor = 5;
      entry.goalsAgainst = 5;
      expect(entry.goalDifference, 0);
    });
  });

  group('GeneratedFixture', () {
    test('initializes with defaults', () {
      final fixture = GeneratedFixture(
        id: 'F1',
        homeTeam: 'Eagles FC',
        awayTeam: 'Lions FC',
        dateTime: DateTime(2026, 6, 1, 15, 0),
        venue: 'Main Stadium',
      );
      expect(fixture.id, 'F1');
      expect(fixture.homeTeam, 'Eagles FC');
      expect(fixture.awayTeam, 'Lions FC');
      expect(fixture.venueConfirmed, false);
      expect(fixture.homeScore, 0);
      expect(fixture.awayScore, 0);
      expect(fixture.currentMinute, 0);
      expect(fixture.status, 'scheduled');
      expect(fixture.events, isEmpty);
    });

    test('events list is mutable', () {
      final fixture = GeneratedFixture(
        id: 'F1', homeTeam: 'A', awayTeam: 'B',
        dateTime: DateTime(2026, 6, 1), venue: 'V',
      );
      fixture.events.add(MatchEvent(type: 'goal', team: 'A', playerName: 'P1', minute: 10));
      expect(fixture.events, hasLength(1));
    });

    test('toRow serializes correctly', () {
      final fixture = GeneratedFixture(
        id: 'F1', homeTeam: 'Eagles FC', awayTeam: 'Lions FC',
        dateTime: DateTime(2026, 6, 1, 15, 0), venue: 'Main Stadium',
        assignedReferee: 'Ref A', homeScore: 2, awayScore: 1,
        currentMinute: 75, status: 'live',
      );
      fixture.events.add(MatchEvent(type: 'goal', team: 'Eagles FC', playerName: 'John', minute: 30));

      final row = fixture.toRow();
      expect(row['id'], 'F1');
      expect(row['home_team'], 'Eagles FC');
      expect(row['away_team'], 'Lions FC');
      expect(row['venue'], 'Main Stadium');
      expect(row['referee'], 'Ref A');
      expect(row['status'], 'live');
      expect(row['home_score'], 2);
      expect(row['away_score'], 1);
      expect(row['current_minute'], 75);
      expect(row['events'], isA<List>());
      expect((row['events'] as List).first['type'], 'goal');
    });

    test('fromRow deserializes correctly', () {
      final fixture = GeneratedFixture.fromRow({
        'id': 'F1',
        'home_team': 'Eagles FC',
        'away_team': 'Lions FC',
        'date_time': '2026-06-01T15:00:00.000',
        'venue': 'Main Stadium',
        'referee': 'Ref A',
        'status': 'completed',
        'home_score': 3,
        'away_score': 2,
        'current_minute': 90,
        'events': [
          {'type': 'goal', 'team': 'Eagles FC', 'player_name': 'John', 'minute': 15, 'detail': null},
          {'type': 'yellow', 'team': 'Lions FC', 'player_name': 'Jane', 'minute': 40, 'detail': null},
        ],
      });

      expect(fixture.id, 'F1');
      expect(fixture.homeTeam, 'Eagles FC');
      expect(fixture.awayTeam, 'Lions FC');
      expect(fixture.venue, 'Main Stadium');
      expect(fixture.assignedReferee, 'Ref A');
      expect(fixture.status, 'completed');
      expect(fixture.homeScore, 3);
      expect(fixture.awayScore, 2);
      expect(fixture.currentMinute, 90);
      expect(fixture.events, hasLength(2));
    });

    test('fromRow defaults for missing fields', () {
      final fixture = GeneratedFixture.fromRow({
        'id': 'F1',
        'home_team': 'A',
        'away_team': 'B',
        'date_time': '2026-06-01T15:00:00.000',
        'venue': 'V',
      });
      expect(fixture.status, 'scheduled');
      expect(fixture.homeScore, 0);
      expect(fixture.awayScore, 0);
      expect(fixture.currentMinute, 0);
      expect(fixture.events, isEmpty);
      expect(fixture.assignedReferee, isNull);
    });

    test('roundtrip toRow/fromRow preserves data', () {
      final original = GeneratedFixture(
        id: 'F10', homeTeam: 'A', awayTeam: 'B',
        dateTime: DateTime(2026, 6, 5, 16, 0), venue: 'Stadium',
        assignedReferee: 'Ref X', homeScore: 1, awayScore: 0,
        currentMinute: 90, status: 'completed',
      );
      original.events.add(MatchEvent(type: 'goal', team: 'A', playerName: 'P1', minute: 55));

      final restored = GeneratedFixture.fromRow(original.toRow());
      expect(restored.id, original.id);
      expect(restored.homeTeam, original.homeTeam);
      expect(restored.awayTeam, original.awayTeam);
      expect(restored.venue, original.venue);
      expect(restored.assignedReferee, original.assignedReferee);
      expect(restored.status, original.status);
      expect(restored.homeScore, original.homeScore);
      expect(restored.awayScore, original.awayScore);
      expect(restored.currentMinute, original.currentMinute);
      expect(restored.events, hasLength(1));
      expect(restored.events.first.type, 'goal');
    });
  });

  group('Standings calculation', () {
    test('completed match updates both teams correctly', () {
      final f = GeneratedFixture(
        id: 'F1', homeTeam: 'Eagles FC', awayTeam: 'Lions FC',
        dateTime: DateTime(2026, 6, 1), venue: 'V',
        homeScore: 3, awayScore: 1, status: 'completed',
      );

      final home = StandingEntry('Eagles FC');
      final away = StandingEntry('Lions FC');

      home.played++; away.played++;
      home.goalsFor += f.homeScore; home.goalsAgainst += f.awayScore;
      away.goalsFor += f.awayScore; away.goalsAgainst += f.homeScore;
      home.wins++; home.points += 3;
      away.losses++;

      expect(home.played, 1);
      expect(home.wins, 1);
      expect(home.points, 3);
      expect(home.goalsFor, 3);
      expect(home.goalsAgainst, 1);
      expect(away.played, 1);
      expect(away.losses, 1);
      expect(away.points, 0);
      expect(away.goalsFor, 1);
      expect(away.goalsAgainst, 3);
    });

    test('draw gives both teams one point', () {
      final home = StandingEntry('Eagles FC');
      final away = StandingEntry('Lions FC');

      home.played++; away.played++;
      home.goalsFor += 1; home.goalsAgainst += 1;
      away.goalsFor += 1; away.goalsAgainst += 1;
      home.draws++; home.points++;
      away.draws++; away.points++;

      expect(home.points, 1);
      expect(away.points, 1);
      expect(home.wins, 0);
      expect(away.wins, 0);
    });

    test('away win gives away team 3 points', () {
      final home = StandingEntry('Home FC');
      final away = StandingEntry('Away FC');

      home.played++; away.played++;
      home.goalsFor += 0; home.goalsAgainst += 2;
      away.goalsFor += 2; away.goalsAgainst += 0;
      away.wins++; away.points += 3;
      home.losses++;

      expect(away.points, 3);
      expect(home.points, 0);
      expect(away.goalsFor, 2);
      expect(home.goalsAgainst, 2);
    });

    test('sorting by points then goal difference', () {
      final entries = [
        StandingEntry('Team C')..points = 3..goalDifference,
        StandingEntry('Team A')..points = 7..goalDifference,
        StandingEntry('Team B')..points = 7..goalDifference,
      ];
      entries[1].goalsFor = 10; entries[1].goalsAgainst = 2; // GD: +8
      entries[2].goalsFor = 6; entries[2].goalsAgainst = 1;  // GD: +5

      entries.sort((a, b) {
        final pc = b.points.compareTo(a.points);
        return pc != 0 ? pc : b.goalDifference.compareTo(a.goalDifference);
      });

      expect(entries[0].team, 'Team A'); // 7 pts, GD +8
      expect(entries[1].team, 'Team B'); // 7 pts, GD +5
      expect(entries[2].team, 'Team C'); // 3 pts
    });
  });

  group('LineupPlayer', () {
    test('constructs with defaults', () {
      final player = LineupPlayer(name: 'John', position: 'FWD', jerseyNo: 10, team: 'Eagles FC');
      expect(player.name, 'John');
      expect(player.position, 'FWD');
      expect(player.jerseyNo, 10);
      expect(player.team, 'Eagles FC');
      expect(player.hasYellow, false);
      expect(player.hasRed, false);
      expect(player.isSubstituted, false);
    });

    test('flags start false', () {
      final player = LineupPlayer(name: 'A', position: 'GK', jerseyNo: 1, team: 'T');
      expect(player.hasYellow, false);
      expect(player.hasRed, false);
      expect(player.isSubstituted, false);
    });
  });
}
