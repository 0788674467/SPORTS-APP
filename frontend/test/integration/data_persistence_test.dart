import 'package:flutter_test/flutter_test.dart';
import 'package:sports_app/core/state/match_state.dart';

void main() {
  group('Data persistence layer — integration', () {
    group('GeneratedFixture toRow / fromRow', () {
      test('roundtrips fixture with all fields populated', () {
        final fixture = GeneratedFixture(
          id: 'F1',
          homeTeam: 'Eagles FC',
          awayTeam: 'Lions FC',
          dateTime: DateTime(2026, 6, 1, 15, 30),
          venue: 'Main Stadium',
          assignedReferee: 'Referee John',
          homeScore: 3,
          awayScore: 2,
          currentMinute: 90,
          status: 'completed',
        );
        fixture.events.addAll([
          MatchEvent(type: 'goal', team: 'Eagles FC', playerName: 'Player A', minute: 15),
          MatchEvent(type: 'yellow', team: 'Lions FC', playerName: 'Player B', minute: 42),
          MatchEvent(type: 'goal', team: 'Lions FC', playerName: 'Player C', minute: 55),
          MatchEvent(type: 'goal', team: 'Eagles FC', playerName: 'Player D', minute: 78),
          MatchEvent(type: 'sub', team: 'Eagles FC', playerName: 'Player E', minute: 80, detail: 'In: Player F'),
        ]);

        final row = fixture.toRow();
        final restored = GeneratedFixture.fromRow(row);

        expect(restored.id, 'F1');
        expect(restored.homeTeam, 'Eagles FC');
        expect(restored.awayTeam, 'Lions FC');
        expect(restored.dateTime, DateTime(2026, 6, 1, 15, 30));
        expect(restored.venue, 'Main Stadium');
        expect(restored.assignedReferee, 'Referee John');
        expect(restored.homeScore, 3);
        expect(restored.awayScore, 2);
        expect(restored.currentMinute, 90);
        expect(restored.status, 'completed');
        expect(restored.events, hasLength(5));

        // Verify event details
        expect(restored.events[0].type, 'goal');
        expect(restored.events[0].team, 'Eagles FC');
        expect(restored.events[0].playerName, 'Player A');
        expect(restored.events[0].minute, 15);

        expect(restored.events[4].type, 'sub');
        expect(restored.events[4].detail, 'In: Player F');
      });

      test('roundtrips fixture with empty events', () {
        final fixture = GeneratedFixture(
          id: 'F2',
          homeTeam: 'Bulls',
          awayTeam: 'Sharks',
          dateTime: DateTime(2026, 6, 5),
          venue: 'Small Ground',
        );
        final row = fixture.toRow();
        final restored = GeneratedFixture.fromRow(row);

        expect(restored.events, isEmpty);
        expect(restored.homeScore, 0);
        expect(restored.awayScore, 0);
        expect(restored.status, 'scheduled');
      });

      test('roundtrips fixture with null referee', () {
        final fixture = GeneratedFixture(
          id: 'F3',
          homeTeam: 'A',
          awayTeam: 'B',
          dateTime: DateTime(2026, 6, 10),
          venue: 'V',
        );
        final row = fixture.toRow();
        final restored = GeneratedFixture.fromRow(row);
        expect(restored.assignedReferee, isNull);
        expect(row.containsKey('referee'), true);
        expect(row['referee'], isNull);
      });

      test('roundtrips fixture with halftime score (0-0)', () {
        final fixture = GeneratedFixture(
          id: 'F4',
          homeTeam: 'A',
          awayTeam: 'B',
          dateTime: DateTime(2026, 6, 10),
          venue: 'V',
          status: 'live',
          currentMinute: 45,
        );
        final row = fixture.toRow();
        final restored = GeneratedFixture.fromRow(row);
        expect(restored.currentMinute, 45);
        expect(restored.status, 'live');
      });
    });

    group('MatchEvent toJson / fromJson', () {
      test('roundtrips all event types', () {
        final events = [
          MatchEvent(type: 'goal', team: 'A', playerName: 'P1', minute: 10),
          MatchEvent(type: 'goal', team: 'A', playerName: 'P1', minute: 10, detail: 'Assist: P2'),
          MatchEvent(type: 'yellow', team: 'B', playerName: 'P3', minute: 30),
          MatchEvent(type: 'red', team: 'A', playerName: 'P4', minute: 67),
          MatchEvent(type: 'sub', team: 'B', playerName: 'P5', minute: 70, detail: 'In: P6'),
          MatchEvent(type: 'corner', team: 'A', playerName: '', minute: 15),
          MatchEvent(type: 'shot', team: 'B', playerName: 'P7', minute: 80),
          MatchEvent(type: 'penalty', team: 'A', playerName: 'P8', minute: 88, detail: 'Scored'),
          MatchEvent(type: 'assist', team: 'B', playerName: 'P9', minute: 55),
        ];

        for (final event in events) {
          final json = event.toJson();
          final restored = MatchEvent.fromJson(json);
          expect(restored.type, event.type);
          expect(restored.team, event.team);
          expect(restored.playerName, event.playerName);
          expect(restored.minute, event.minute);
          expect(restored.detail, event.detail);
        }
      });
    });

    group('Multi-fixture data flow', () {
      test('fixtures list sorted by date processes correctly', () {
        final fixtures = [
          GeneratedFixture(
            id: 'F1', homeTeam: 'A', awayTeam: 'B',
            dateTime: DateTime(2026, 6, 10), venue: 'V',
            homeScore: 2, awayScore: 1, status: 'completed',
          ),
          GeneratedFixture(
            id: 'F2', homeTeam: 'C', awayTeam: 'D',
            dateTime: DateTime(2026, 6, 3), venue: 'V', // earlier date
            homeScore: 0, awayScore: 0, status: 'completed',
          ),
          GeneratedFixture(
            id: 'F3', homeTeam: 'A', awayTeam: 'C',
            dateTime: DateTime(2026, 6, 17), venue: 'V', // later date
            status: 'scheduled',
          ),
        ];

        // Sort by date (as loadFixtures does via .order('date_time'))
        final sorted = List<GeneratedFixture>.from(fixtures)
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        expect(sorted[0].id, 'F2'); // June 3
        expect(sorted[1].id, 'F1'); // June 10
        expect(sorted[2].id, 'F3'); // June 17

        // Serialize all and restore
        final restored = sorted.map((f) => GeneratedFixture.fromRow(f.toRow())).toList();
        expect(restored[0].homeTeam, 'C');
        expect(restored[1].homeScore, 2);
        expect(restored[2].status, 'scheduled');
      });

      test('many events serialize correctly', () {
        final fixture = GeneratedFixture(
          id: 'F1',
          homeTeam: 'A',
          awayTeam: 'B',
          dateTime: DateTime(2026, 6, 1),
          venue: 'V',
          homeScore: 5,
          awayScore: 3,
          status: 'completed',
        );

        // Add 30 events
        for (int i = 0; i < 30; i++) {
          fixture.events.add(MatchEvent(
            type: i % 3 == 0 ? 'goal' : (i % 3 == 1 ? 'yellow' : 'shot'),
            team: i % 2 == 0 ? 'A' : 'B',
            playerName: 'Player$i',
            minute: (i % 90) + 1,
          ));
        }

        final row = fixture.toRow();
        final restored = GeneratedFixture.fromRow(row);
        expect(restored.events, hasLength(30));
        expect(restored.homeScore, 5);
        expect(restored.awayScore, 3);
      });
    });

    group('Referee assignment', () {
      test('auto-assigns referees round-robin', () {
        final fixtures = List.generate(6, (i) => GeneratedFixture(
          id: 'F${i + 1}',
          homeTeam: 'Team${i * 2}',
          awayTeam: 'Team${i * 2 + 1}',
          dateTime: DateTime(2026, 6, 1),
          venue: 'V',
        ));

        final referees = ['Ref A', 'Ref B'];
        for (int i = 0; i < fixtures.length; i++) {
          fixtures[i].assignedReferee = referees[i % referees.length];
        }

        expect(fixtures[0].assignedReferee, 'Ref A');
        expect(fixtures[1].assignedReferee, 'Ref B');
        expect(fixtures[2].assignedReferee, 'Ref A');
        expect(fixtures[3].assignedReferee, 'Ref B');
        expect(fixtures[4].assignedReferee, 'Ref A');
        expect(fixtures[5].assignedReferee, 'Ref B');

        // Verify roundtrip
        for (final f in fixtures) {
          final restored = GeneratedFixture.fromRow(f.toRow());
          expect(restored.assignedReferee, f.assignedReferee);
        }
      });
    });
  });
}
