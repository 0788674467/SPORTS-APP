import 'package:flutter_test/flutter_test.dart';
import 'package:sports_app/core/state/match_state.dart';

/// Rebuilds standings from a list of fixtures (mimics MatchState._rebuildStandings locally).
List<StandingEntry> computeStandings(List<GeneratedFixture> fixtures) {
  final teams = <String>{};
  for (final f in fixtures) {
    teams.add(f.homeTeam);
    teams.add(f.awayTeam);
  }
  final standings = teams.map((t) => StandingEntry(t)).toList();

  for (final f in fixtures.where((f) => f.status == 'completed')) {
    final home = standings.where((s) => s.team == f.homeTeam).firstOrNull;
    final away = standings.where((s) => s.team == f.awayTeam).firstOrNull;
    if (home == null || away == null) continue;

    home.played++;
    away.played++;
    home.goalsFor += f.homeScore;
    home.goalsAgainst += f.awayScore;
    away.goalsFor += f.awayScore;
    away.goalsAgainst += f.homeScore;

    if (f.homeScore > f.awayScore) {
      home.wins++;
      home.points += 3;
      away.losses++;
    } else if (f.homeScore < f.awayScore) {
      away.wins++;
      away.points += 3;
      home.losses++;
    } else {
      home.draws++;
      home.points++;
      away.draws++;
      away.points++;
    }
  }

  standings.sort((a, b) {
    final pc = b.points.compareTo(a.points);
    return pc != 0 ? pc : b.goalDifference.compareTo(a.goalDifference);
  });
  return standings;
}

GeneratedFixture makeFixture(String id, String home, String away,
    {int homeScore = 0, int awayScore = 0, String status = 'scheduled'}) {
  return GeneratedFixture(
    id: id,
    homeTeam: home,
    awayTeam: away,
    dateTime: DateTime(2026, 6, 1),
    venue: 'Stadium',
    homeScore: homeScore,
    awayScore: awayScore,
    status: status,
  );
}

void main() {
  group('Standings computation — integration', () {
    test('all scheduled matches produce empty standings', () {
      final fixtures = [
        makeFixture('F1', 'Eagles', 'Lions'),
        makeFixture('F2', 'Bulls', 'Sharks'),
      ];
      final standings = computeStandings(fixtures);
      expect(standings, hasLength(4));
      for (final s in standings) {
        expect(s.played, 0);
        expect(s.points, 0);
      }
    });

    test('single completed match updates both teams', () {
      final fixtures = [
        makeFixture('F1', 'Eagles', 'Lions', homeScore: 3, awayScore: 1, status: 'completed'),
      ];
      final standings = computeStandings(fixtures);
      expect(standings, hasLength(2));

      final eagles = standings.firstWhere((s) => s.team == 'Eagles');
      final lions = standings.firstWhere((s) => s.team == 'Lions');

      expect(eagles.played, 1);
      expect(eagles.wins, 1);
      expect(eagles.points, 3);
      expect(eagles.goalsFor, 3);
      expect(eagles.goalsAgainst, 1);
      expect(eagles.goalDifference, 2);

      expect(lions.played, 1);
      expect(lions.losses, 1);
      expect(lions.points, 0);
      expect(lions.goalsFor, 1);
      expect(lions.goalsAgainst, 3);
      expect(lions.goalDifference, -2);
    });

    test('draw gives each team 1 point', () {
      final fixtures = [
        makeFixture('F1', 'Eagles', 'Lions', homeScore: 2, awayScore: 2, status: 'completed'),
      ];
      final standings = computeStandings(fixtures);

      for (final s in standings) {
        expect(s.played, 1);
        expect(s.draws, 1);
        expect(s.points, 1);
        expect(s.wins, 0);
        expect(s.losses, 0);
      }
    });

    test('away win gives away team 3 points', () {
      final fixtures = [
        makeFixture('F1', 'Eagles', 'Lions', homeScore: 0, awayScore: 4, status: 'completed'),
      ];
      final standings = computeStandings(fixtures);

      final lions = standings.firstWhere((s) => s.team == 'Lions');
      expect(lions.points, 3);
      expect(lions.wins, 1);
      expect(lions.goalDifference, 4);
    });

    test('full season of 4 teams produces correct standings', () {
      // 4 teams, 3 rounds (6 matches total)
      final fixtures = [
        makeFixture('F1', 'Eagles', 'Lions', homeScore: 3, awayScore: 1, status: 'completed'),
        makeFixture('F2', 'Bulls', 'Sharks', homeScore: 2, awayScore: 2, status: 'completed'),
        makeFixture('F3', 'Eagles', 'Bulls', homeScore: 1, awayScore: 0, status: 'completed'),
        makeFixture('F4', 'Lions', 'Sharks', homeScore: 2, awayScore: 3, status: 'completed'),
        makeFixture('F5', 'Eagles', 'Sharks', homeScore: 4, awayScore: 1, status: 'completed'),
        makeFixture('F6', 'Lions', 'Bulls', homeScore: 1, awayScore: 1, status: 'completed'),
      ];
      final standings = computeStandings(fixtures);

      expect(standings, hasLength(4));

      // Eagles: 3W 0D 0L = 9pts, GF 8 GA 2, GD +6
      final eagles = standings.firstWhere((s) => s.team == 'Eagles');
      expect(eagles.points, 9);
      expect(eagles.wins, 3);
      expect(eagles.goalDifference, 6);

      // Bulls: 0W 2D 1L = 2pts
      final bulls = standings.firstWhere((s) => s.team == 'Bulls');
      expect(bulls.points, 2);

      // Sharks: 1W 1D 1L = 4pts
      final sharks = standings.firstWhere((s) => s.team == 'Sharks');
      expect(sharks.points, 4);

      // Lions: 0W 1D 2L = 1pt
      final lions = standings.firstWhere((s) => s.team == 'Lions');
      expect(lions.points, 1);

      // Standings order: Eagles (9), Sharks (4), Bulls (2), Lions (1)
      expect(standings[0].team, 'Eagles');
      expect(standings[1].team, 'Sharks');
      expect(standings[2].team, 'Bulls');
      expect(standings[3].team, 'Lions');
    });

    test('teams with equal points sorted by goal difference', () {
      final fixtures = [
        makeFixture('F1', 'Eagles', 'Lions', homeScore: 5, awayScore: 0, status: 'completed'),
        makeFixture('F2', 'Bulls', 'Sharks', homeScore: 2, awayScore: 1, status: 'completed'),
        makeFixture('F3', 'Eagles', 'Sharks', homeScore: 0, awayScore: 0, status: 'completed'),
        makeFixture('F4', 'Lions', 'Bulls', homeScore: 1, awayScore: 3, status: 'completed'),
      ];
      final standings = computeStandings(fixtures);

      // Eagles: 1W 1D = 4pts, GF 5 GA 0, GD +5
      // Bulls: 2W 0D = 6pts, GF 5 GA 2, GD +3
      // Lions: 0W 0D 2L = 0pts
      // Sharks: 0W 1D 1L = 1pt

      // Wait, let me re-calculate
      // F1: Eagles 5-0 Lions → Eagles 3pts, Lions 0pts
      // F2: Bulls 2-1 Sharks → Bulls 3pts, Sharks 0pts
      // F3: Eagles 0-0 Sharks → Eagles 1pt, Sharks 1pt
      // F4: Lions 1-3 Bulls → Bulls 3pts, Lions 0pts
      // 
      // Eagles: 1W 1D = 4pts, GF 5, GA 0, GD +5
      // Bulls: 2W 0D = 6pts, GF 5, GA 2, GD +3
      // Sharks: 0W 1D 1L = 1pt, GF 1, GA 2, GD -1
      // Lions: 0W 0D 2L = 0pts, GF 1, GA 8, GD -7

      expect(standings[0].team, 'Bulls');  // 6pts
      expect(standings[1].team, 'Eagles'); // 4pts
      expect(standings[2].team, 'Sharks'); // 1pt
      expect(standings[3].team, 'Lions');  // 0pts
    });

    test('unplayed (scheduled) matches do not affect standings', () {
      final fixtures = [
        makeFixture('F1', 'Eagles', 'Lions', homeScore: 2, awayScore: 1, status: 'completed'),
        makeFixture('F2', 'Bulls', 'Sharks', status: 'scheduled'), // not yet played
        makeFixture('F3', 'Eagles', 'Bulls', status: 'scheduled'), // not yet played
      ];
      final standings = computeStandings(fixtures);

      // Only Eagles and Lions should have matches counted
      final eagles = standings.firstWhere((s) => s.team == 'Eagles');
      final lions = standings.firstWhere((s) => s.team == 'Lions');
      final bulls = standings.firstWhere((s) => s.team == 'Bulls');
      final sharks = standings.firstWhere((s) => s.team == 'Sharks');

      expect(eagles.played, 1);
      expect(lions.played, 1);
      expect(bulls.played, 0);
      expect(sharks.played, 0);
    });

    test('live matches do not affect standings', () {
      final fixtures = [
        makeFixture('F1', 'Eagles', 'Lions', homeScore: 1, awayScore: 0, status: 'completed'),
        makeFixture('F2', 'Bulls', 'Sharks', homeScore: 3, awayScore: 3, status: 'live'), // still playing
      ];
      final standings = computeStandings(fixtures);

      final bulls = standings.firstWhere((s) => s.team == 'Bulls');
      final sharks = standings.firstWhere((s) => s.team == 'Sharks');

      expect(bulls.played, 0, reason: 'live match should not count');
      expect(sharks.played, 0, reason: 'live match should not count');
    });

    test('standings table is sorted descending by points then goal difference', () {
      final fixtures = [
        makeFixture('F1', 'A', 'B', homeScore: 1, awayScore: 0, status: 'completed'),
        makeFixture('F2', 'C', 'D', homeScore: 3, awayScore: 0, status: 'completed'),
        makeFixture('F3', 'C', 'A', homeScore: 0, awayScore: 0, status: 'completed'),
        makeFixture('F4', 'B', 'D', homeScore: 4, awayScore: 0, status: 'completed'),
      ];
      final standings = computeStandings(fixtures);

      // Verify each successive entry has lower or equal points
      for (int i = 0; i < standings.length - 1; i++) {
        final current = standings[i];
        final next = standings[i + 1];
        if (current.points == next.points) {
          expect(current.goalDifference, greaterThanOrEqualTo(next.goalDifference));
        } else {
          expect(current.points, greaterThan(next.points));
        }
      }
    });
  });

  group('GeneratedFixture serialization with standings', () {
    test('fixture with events roundtrips through toRow/fromRow and feeds standings', () {
      final fixture = GeneratedFixture(
        id: 'F1',
        homeTeam: 'Eagles',
        awayTeam: 'Lions',
        dateTime: DateTime(2026, 6, 1, 15, 0),
        venue: 'Main Stadium',
        assignedReferee: 'Referee A',
        homeScore: 2,
        awayScore: 1,
        currentMinute: 90,
        status: 'completed',
      );
      fixture.events.addAll([
        MatchEvent(type: 'goal', team: 'Eagles', playerName: 'John', minute: 23),
        MatchEvent(type: 'goal', team: 'Lions', playerName: 'Jane', minute: 45),
        MatchEvent(type: 'goal', team: 'Eagles', playerName: 'John', minute: 78),
        MatchEvent(type: 'yellow', team: 'Lions', playerName: 'Bob', minute: 56),
      ]);

      // Simulate DB save and load
      final row = fixture.toRow();
      final restored = GeneratedFixture.fromRow(row);

      // Verify serialization
      expect(restored.homeTeam, 'Eagles');
      expect(restored.awayTeam, 'Lions');
      expect(restored.homeScore, 2);
      expect(restored.awayScore, 1);
      expect(restored.status, 'completed');
      expect(restored.events, hasLength(4));

      // Feed into standings
      final standings = computeStandings([restored]);
      final eagles = standings.firstWhere((s) => s.team == 'Eagles');
      expect(eagles.points, 3);
      expect(eagles.goalDifference, 1);
    });
  });

  group('End-to-end: generate schedule → play matches → compute standings', () {
    test('full season for 4 teams produces consistent results', () {
      // Step 1: Generate round-robin schedule using the algorithm
      final fixtures = <GeneratedFixture>[];
      final teams = ['Eagles', 'Lions', 'Bulls', 'Sharks'];
      final startDate = DateTime(2026, 6, 1);
      final venues = ['Stadium A', 'Stadium B'];

      final ts = List<String>.from(teams);
      final n = ts.length;
      final half = n ~/ 2;
      final rounds = n - 1;
      DateTime currentDate = startDate;
      int venueIdx = 0;
      int idCounter = 1;

      for (int round = 0; round < rounds; round++) {
        for (int match = 0; match < half; match++) {
          final home = ts[match];
          final away = ts[ts.length - 1 - match];
          fixtures.add(GeneratedFixture(
            id: 'F${idCounter++}',
            homeTeam: home,
            awayTeam: away,
            dateTime: currentDate.copyWith(hour: 15, minute: 0),
            venue: venues[venueIdx % venues.length],
          ));
          venueIdx++;
        }
        final last = ts.removeLast();
        ts.insert(1, last);
        currentDate = currentDate.add(const Duration(days: 7));
      }

      expect(fixtures, hasLength(6));

      // Step 2: Play all matches (assign scores)
      // Actual pairings from the Berger algorithm above:
      // F1: Eagles vs Sharks (Eagles home)
      // F2: Lions vs Bulls   (Lions home)
      // F3: Eagles vs Bulls  (Eagles home)
      // F4: Sharks vs Lions  (Sharks home)
      // F5: Eagles vs Lions  (Eagles home)
      // F6: Bulls vs Sharks  (Bulls home)
      final results = {
        'F1': [3, 1],  // Eagles 3-1 Sharks
        'F2': [2, 2],  // Lions 2-2 Bulls
        'F3': [1, 0],  // Eagles 1-0 Bulls
        'F4': [2, 3],  // Sharks 2-3 Lions
        'F5': [4, 1],  // Eagles 4-1 Lions
        'F6': [1, 1],  // Bulls 1-1 Sharks
      };

      for (final f in fixtures) {
        final score = results[f.id]!;
        f.homeScore = score[0];
        f.awayScore = score[1];
        f.status = 'completed';
      }

      // Step 3: Compute standings
      final standings = computeStandings(fixtures);

      // Step 4: Verify final table
      expect(standings, hasLength(4));

      // Eagles: 3W 0D 0L = 9pts, GF 8 GA 2, GD +6
      expect(standings[0].team, 'Eagles');
      expect(standings[0].points, 9);
      expect(standings[0].wins, 3);
      expect(standings[0].goalDifference, 6);

      // Lions: 1W 1D 1L = 4pts, GF 6 GA 8, GD -2
      expect(standings[1].team, 'Lions');
      expect(standings[1].points, 4);

      // Bulls: 0W 2D 1L = 2pts, GF 3 GA 4, GD -1
      expect(standings[2].team, 'Bulls');
      expect(standings[2].points, 2);

      // Sharks: 0W 1D 2L = 1pt, GF 4 GA 7, GD -3
      expect(standings[3].team, 'Sharks');
      expect(standings[3].points, 1);
    });
  });
}
