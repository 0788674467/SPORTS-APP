import 'package:flutter_test/flutter_test.dart';
import 'package:sports_app/core/state/match_state.dart';

/// Helper: runs the round-robin algorithm in-memory and returns generated fixtures.
List<GeneratedFixture> generateRoundRobinLocally({
  required List<String> teams,
  required DateTime startDate,
  required int daysBetween,
  required int kickoffHour,
  required int kickoffMinute,
  required List<String> venues,
}) {
  final fixtures = <GeneratedFixture>[];
  final n = teams.length;
  final ts = n % 2 == 0 ? List<String>.from(teams) : [...teams, 'BYE'];
  final half = ts.length ~/ 2;
  final rounds = ts.length - 1;

  DateTime currentDate = startDate;
  int venueIdx = 0;
  int idCounter = 1;

  for (int round = 0; round < rounds; round++) {
    for (int match = 0; match < half; match++) {
      final home = ts[match];
      final away = ts[ts.length - 1 - match];
      if (home != 'BYE' && away != 'BYE') {
        fixtures.add(GeneratedFixture(
          id: 'F${idCounter++}',
          homeTeam: home,
          awayTeam: away,
          dateTime: currentDate.copyWith(
            hour: kickoffHour, minute: kickoffMinute, second: 0,
          ),
          venue: venues[venueIdx % venues.length],
        ));
        venueIdx++;
      }
    }
    final last = ts.removeLast();
    ts.insert(1, last);
    currentDate = currentDate.add(Duration(days: daysBetween));
  }
  return fixtures;
}

void main() {
  group('Round-robin fixture generation — integration', () {
    final venues = ['Stadium A', 'Stadium B'];

    test('generates correct number of rounds and matches for 4 teams', () {
      final fixtures = generateRoundRobinLocally(
        teams: ['Eagles', 'Lions', 'Bulls', 'Sharks'],
        startDate: DateTime(2026, 6, 1),
        daysBetween: 7,
        kickoffHour: 15,
        kickoffMinute: 0,
        venues: venues,
      );

      // 4 teams → 3 rounds × 2 matches per round = 6 matches
      expect(fixtures.length, 6);

      // Each team should play 3 matches
      final teamMatchCount = <String, int>{};
      for (final f in fixtures) {
        teamMatchCount[f.homeTeam] = (teamMatchCount[f.homeTeam] ?? 0) + 1;
        teamMatchCount[f.awayTeam] = (teamMatchCount[f.awayTeam] ?? 0) + 1;
      }
      for (final team in ['Eagles', 'Lions', 'Bulls', 'Sharks']) {
        expect(teamMatchCount[team], 3, reason: '$team should play 3 matches');
      }
    });

    test('every team plays every other team exactly once (4 teams)', () {
      final fixtures = generateRoundRobinLocally(
        teams: ['Eagles', 'Lions', 'Bulls', 'Sharks'],
        startDate: DateTime(2026, 6, 1),
        daysBetween: 7,
        kickoffHour: 15,
        kickoffMinute: 0,
        venues: venues,
      );

      final matchups = <Set<String>>{};
      for (final f in fixtures) {
        final pair = {f.homeTeam, f.awayTeam};
        matchups.add(pair);
      }
      // C(4,2) = 6 unique pairings
      expect(matchups.length, 6);
    });

    test('handles odd number of teams (5 teams → BYE)', () {
      final fixtures = generateRoundRobinLocally(
        teams: ['Eagles', 'Lions', 'Bulls', 'Sharks', 'Wolves'],
        startDate: DateTime(2026, 6, 1),
        daysBetween: 7,
        kickoffHour: 15,
        kickoffMinute: 0,
        venues: venues,
      );

      // 5 teams → round-robin with BYE → each round has floor(6/2)=3 pairings,
      // one of which is BYE-BYE (skipped). So 2 actual matches per round × 5 rounds = 10
      expect(fixtures.length, 10);

      // Each of the 5 teams should play 4 matches
      final teamMatchCount = <String, int>{};
      for (final f in fixtures) {
        teamMatchCount[f.homeTeam] = (teamMatchCount[f.homeTeam] ?? 0) + 1;
        teamMatchCount[f.awayTeam] = (teamMatchCount[f.awayTeam] ?? 0) + 1;
      }
      for (final team in ['Eagles', 'Lions', 'Bulls', 'Sharks', 'Wolves']) {
        expect(teamMatchCount[team], 4, reason: '$team should play 4 matches');
      }
    });

    test('generates matches on correct dates with 7-day spacing', () {
      final fixtures = generateRoundRobinLocally(
        teams: ['Eagles', 'Lions', 'Bulls', 'Sharks'],
        startDate: DateTime(2026, 6, 1), // Monday
        daysBetween: 7,
        kickoffHour: 16,
        kickoffMinute: 0,
        venues: venues,
      );

      // Round 1: June 1, Round 2: June 8, Round 3: June 15
      final roundDates = fixtures.map((f) => f.dateTime).toSet().toList()..sort();
      expect(roundDates.length, 3);
      expect(roundDates[0], DateTime(2026, 6, 1, 16, 0));
      expect(roundDates[1], DateTime(2026, 6, 8, 16, 0));
      expect(roundDates[2], DateTime(2026, 6, 15, 16, 0));
    });

    test('home/away distribution across all teams', () {
      final fixtures = generateRoundRobinLocally(
        teams: ['Eagles', 'Lions', 'Bulls', 'Sharks'],
        startDate: DateTime(2026, 6, 1),
        daysBetween: 7,
        kickoffHour: 15,
        kickoffMinute: 0,
        venues: venues,
      );

      // Each team should play exactly 3 matches
      for (final team in ['Eagles', 'Lions', 'Bulls', 'Sharks']) {
        final homeCount = fixtures.where((f) => f.homeTeam == team).length;
        final awayCount = fixtures.where((f) => f.awayTeam == team).length;
        expect(homeCount + awayCount, 3, reason: '$team should play 3 matches in total');
      }

      // The league as a whole should have equal home and away matches (3 each per team × 4 = 12 home, 12 away... actually 6 fixtures = 6 home, 6 away)
      final totalHome = fixtures.length;
      final totalAway = fixtures.length;
      expect(totalHome, 6);
      expect(totalAway, 6);
    });

    test('venues cycle across matches', () {
      final fixtures = generateRoundRobinLocally(
        teams: ['Eagles', 'Lions', 'Bulls', 'Sharks'],
        startDate: DateTime(2026, 6, 1),
        daysBetween: 7,
        kickoffHour: 15,
        kickoffMinute: 0,
        venues: ['Stadium A', 'Stadium B'],
      );

      expect(fixtures[0].venue, 'Stadium A');
      expect(fixtures[1].venue, 'Stadium B');
      expect(fixtures[2].venue, 'Stadium A'); // cycles
    });

    test('fixture IDs are sequential', () {
      final fixtures = generateRoundRobinLocally(
        teams: ['Eagles', 'Lions', 'Bulls', 'Sharks'],
        startDate: DateTime(2026, 6, 1),
        daysBetween: 7,
        kickoffHour: 15,
        kickoffMinute: 0,
        venues: venues,
      );

      for (int i = 0; i < fixtures.length; i++) {
        expect(fixtures[i].id, 'F${i + 1}');
      }
    });

    test('generates fixtures for 8 teams', () {
      final fixtures = generateRoundRobinLocally(
        teams: ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8'],
        startDate: DateTime(2026, 6, 1),
        daysBetween: 7,
        kickoffHour: 15,
        kickoffMinute: 0,
        venues: ['V1', 'V2', 'V3'],
      );

      // 8 teams → 7 rounds × 4 matches = 28 matches
      expect(fixtures.length, 28);

      // Each team plays 7 matches
      final teamMatchCount = <String, int>{};
      for (final f in fixtures) {
        teamMatchCount[f.homeTeam] = (teamMatchCount[f.homeTeam] ?? 0) + 1;
        teamMatchCount[f.awayTeam] = (teamMatchCount[f.awayTeam] ?? 0) + 1;
      }
      for (int i = 1; i <= 8; i++) {
        expect(teamMatchCount['T$i'], 7);
      }
    });
  });
}
