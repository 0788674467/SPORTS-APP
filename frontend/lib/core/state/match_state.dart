import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

/// Represents an event that occurred during a match.
class MatchEvent {
  /// Type of event (e.g., 'goal', 'yellow', 'red', 'assist', 'corner', 'shot', 'penalty', 'sub')
  final String type;
  
  /// Team involved in the event
  final String team;
  
  /// Name of the player involved
  final String playerName;
  
  /// Minute when the event occurred
  final int minute;
  
  /// Additional details about the event
  final String? detail;

  MatchEvent({
    required this.type,
    required this.team,
    required this.playerName,
    required this.minute,
    this.detail,
  });
}

/// Represents a player in a match lineup.
class LineupPlayer {
  /// Player's full name
  final String name;
  
  /// Player's position on the field
  final String position;
  
  /// Player's jersey number
  final int jerseyNo;
  
  /// Team the player belongs to
  final String team;
  
  /// URL to player's photo
  final String? photoUrl;
  
  /// Whether the player has received a yellow card
  bool hasYellow;
  
  /// Whether the player has received a red card
  bool hasRed;
  
  /// Whether the player has been substituted
  bool isSubstituted;

  LineupPlayer({
    required this.name,
    required this.position,
    required this.jerseyNo,
    required this.team,
    this.photoUrl,
    this.hasYellow = false,
    this.hasRed = false,
    this.isSubstituted = false,
  });
}

/// Represents a scheduled fixture/match.
class GeneratedFixture {
  /// Unique fixture identifier
  final String id;
  
  /// Home team name
  final String homeTeam;
  
  /// Away team name
  final String awayTeam;
  
  /// Match date and time
  DateTime dateTime;
  
  /// Venue name or location
  String venue;
  
  /// Assigned referee name
  String? assignedReferee;
  
  /// Whether the venue has been confirmed
  bool venueConfirmed;
  
  /// Home team score
  int homeScore;
  
  /// Away team score
  int awayScore;
  
  /// Match status ('scheduled', 'live', 'completed', 'postponed')
  String status;
  
  /// List of events that occurred during the match
  List<MatchEvent> events;

  GeneratedFixture({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.dateTime,
    required this.venue,
    this.assignedReferee,
    this.venueConfirmed = false,
    this.homeScore = 0,
    this.awayScore = 0,
    this.status = 'scheduled',
  }) : events = [];

  // ── Serialization ─────────────────────────────────────────────────────────
  
  /// Converts the fixture to a database row format.
  Map<String, dynamic> toRow() => {
        'id': id,
        'home_team': homeTeam,
        'away_team': awayTeam,
        'date_time': dateTime.toIso8601String(),
        'venue': venue,
        'referee': assignedReferee,
        'status': status,
        'home_score': homeScore,
        'away_score': awayScore,
      };

  /// Creates a fixture from a database row.
  static GeneratedFixture fromRow(Map<String, dynamic> r) => GeneratedFixture(
        id: r['id'] as String,
        homeTeam: r['home_team'] as String,
        awayTeam: r['away_team'] as String,
        dateTime: DateTime.parse(r['date_time'] as String),
        venue: r['venue'] as String,
        assignedReferee: r['referee'] as String?,
        status: r['status'] as String? ?? 'scheduled',
        homeScore: r['home_score'] as int? ?? 0,
        awayScore: r['away_score'] as int? ?? 0,
      );
}

/// Represents a team's standing in the league table.
class StandingEntry {
  /// Team name
  final String team;
  
  /// Matches played
  int played;
  
  /// Matches won
  int wins;
  
  /// Matches drawn
  int draws;
  
  /// Matches lost
  int losses;
  
  /// Goals scored
  int goalsFor;
  
  /// Goals conceded
  int goalsAgainst;
  
  /// Total points
  int points;

  StandingEntry(this.team)
      : played = 0,
        wins = 0,
        draws = 0,
        losses = 0,
        goalsFor = 0,
        goalsAgainst = 0,
        points = 0;

  /// Goal difference (goals for - goals against)
  int get goalDifference => goalsFor - goalsAgainst;
}

// ─── Shared Match State ───────────────────────────────────────────────────────

/// Manages all match-related state including fixtures, lineups, events, and standings.
/// 
/// Provides real-time synchronization with Supabase, handles match event recording,
/// generates round-robin schedules, and maintains league standings.
class MatchState extends ChangeNotifier {
  final _db = Supabase.instance.client;

  /// All generated fixtures
  List<GeneratedFixture> generatedFixtures = [];
  
  /// Team badge URLs mapped by team name
  Map<String, String?> teamBadges = {};
  
  /// Index of the currently live fixture
  int? liveFixtureIndex;

  // Realtime channel
  RealtimeChannel? _fixtureSubscription;

  bool _loading = false;
  
  /// Whether fixtures are being loaded
  bool get isLoading => _loading;

  MatchState() {
    _initRealtime();
    loadFixtures();
  }

  // ─── Realtime ─────────────────────────────────────────────────────────────

  void _initRealtime() {
    _fixtureSubscription = _db
        .channel('public:scheduled_matches')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'scheduled_matches',
          callback: (_) => loadFixtures(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'scheduled_matches',
          callback: (payload) => _handleUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'scheduled_matches',
          callback: (payload) => _handleDelete(payload.oldRecord),
        )
        // Keep old matches/fixtures channel for live-score realtime
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          callback: (payload) => _handleMatchChange(payload),
        )
        .subscribe();
  }

  void _handleUpdate(Map<String, dynamic> data) {
    final idx = generatedFixtures.indexWhere((f) => f.id == data['id']);
    if (idx == -1) return;
    generatedFixtures[idx] = GeneratedFixture.fromRow(data);
    notifyListeners();
  }

  void _handleDelete(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    if (id == null) return;
    generatedFixtures.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  void _handleMatchChange(PostgresChangePayload payload) {
    final data = payload.newRecord;
    if (data.isEmpty) return;
    final fixtureId = data['fixture_id'];
    final idx = generatedFixtures.indexWhere((f) => f.id == fixtureId);
    if (idx != -1) {
      final f = generatedFixtures[idx];
      f.homeScore = data['home_score'] ?? 0;
      f.awayScore = data['away_score'] ?? 0;
      final matchStatus = data['status'];
      if (matchStatus == 'first_half' || matchStatus == 'second_half' || matchStatus == 'half_time') {
        f.status = 'live';
        liveFixtureIndex = idx;
      } else if (matchStatus == 'completed') {
        f.status = 'completed';
        if (liveFixtureIndex == idx) liveFixtureIndex = null;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _fixtureSubscription?.unsubscribe();
    super.dispose();
  }

  // ─── Persistence ──────────────────────────────────────────────────────────

  /// Loads all fixtures from Supabase, ordered by date.
  Future<void> loadFixtures() async {
    try {
      _loading = true;
      notifyListeners();
      final rows = await _db
          .from('scheduled_matches')
          .select()
          .order('date_time', ascending: true);
      generatedFixtures = (rows as List)
          .map((r) => GeneratedFixture.fromRow(r as Map<String, dynamic>))
          .toList();
      // Rebuild standings from completed fixtures
      _rebuildStandings();
    } catch (e) {
      debugPrint('loadFixtures error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Persists a single fixture update (date/venue/referee/status/scores).
  /// 
  /// Returns null on success, or an error message on failure.
  Future<String?> updateFixture(String id, {
    DateTime? dateTime,
    String? venue,
    String? referee,
    String? status,
    int? homeScore,
    int? awayScore,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (dateTime != null) updates['date_time'] = dateTime.toIso8601String();
      if (venue != null)    updates['venue'] = venue;
      if (referee != null)  updates['referee'] = referee;
      if (status != null)   updates['status'] = status;
      if (homeScore != null) updates['home_score'] = homeScore;
      if (awayScore != null) updates['away_score'] = awayScore;
      if (updates.isEmpty) return null;

      await _db.from('scheduled_matches').update(updates).eq('id', id);
      // Local optimistic update (Realtime will also fire)
      _handleUpdate({..._fixture(id)!.toRow(), ...updates});
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Deletes a fixture from Supabase and local list.
  /// 
  /// Returns null on success, or an error message on failure.
  Future<String?> deleteFixture(String id) async {
    try {
      await _db.from('scheduled_matches').delete().eq('id', id);
      generatedFixtures.removeWhere((f) => f.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Deletes ALL fixtures (admin clear).
  Future<void> clearAllFixtures() async {
    try {
      await _db.from('scheduled_matches').delete().neq('id', '');
      generatedFixtures.clear();
      standings.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('clearAllFixtures error: $e');
    }
  }

  // ─── Fixture Generator ────────────────────────────────────────────────────

  /// Generates a round-robin schedule and persists it to Supabase.
  /// 
  /// Uses the circle method algorithm to create a fair schedule where each
  /// team plays every other team once. Automatically handles odd number of teams.
  Future<void> generateRoundRobin({
    required List<String> teams,
    required DateTime startDate,
    required int daysBetween,
    required int kickoffHour,
    required int kickoffMinute,
    required List<String> venues,
    Map<String, String?> badgeUrls = const {},
  }) async {
    generatedFixtures.clear();
    standings.clear();
    teamBadges = Map.from(badgeUrls);

    for (final t in teams) standings.add(StandingEntry(t));

    final n = teams.length;
    final List<String> ts = n % 2 == 0 ? List.from(teams) : [...teams, 'BYE'];
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
          generatedFixtures.add(GeneratedFixture(
            id: 'F${idCounter++}',
            homeTeam: home,
            awayTeam: away,
            dateTime: currentDate.copyWith(hour: kickoffHour, minute: kickoffMinute, second: 0),
            venue: venues[venueIdx % venues.length],
          ));
          venueIdx++;
        }
      }
      final last = ts.removeLast();
      ts.insert(1, last);
      currentDate = currentDate.add(Duration(days: daysBetween));
    }

    notifyListeners();

    // ── Persist to Supabase ────────────────────────────────────────────────
    try {
      // Clear old fixtures first then batch-insert new ones
      await _db.from('scheduled_matches').delete().neq('id', '');
      if (generatedFixtures.isNotEmpty) {
        await _db.from('scheduled_matches').insert(
          generatedFixtures.map((f) => f.toRow()).toList(),
        );
      }
    } catch (e) {
      debugPrint('generateRoundRobin persist error: $e');
    }
  }

  // ─── Referee Assignment ───────────────────────────────────────────────────

  /// Automatically assigns referees to all fixtures in a round-robin fashion.
  /// 
  /// Distributes referees evenly across all fixtures.
  Future<void> autoAssignReferees(List<String> approvedReferees) async {
    if (approvedReferees.isEmpty) return;
    for (int i = 0; i < generatedFixtures.length; i++) {
      generatedFixtures[i].assignedReferee =
          approvedReferees[i % approvedReferees.length];
    }
    notifyListeners();
    // Persist all referee assignments
    try {
      for (int i = 0; i < generatedFixtures.length; i++) {
        await _db
            .from('scheduled_matches')
            .update({'referee': generatedFixtures[i].assignedReferee})
            .eq('id', generatedFixtures[i].id);
      }
    } catch (e) {
      debugPrint('autoAssignReferees persist error: $e');
    }
  }

  /// Confirms the venue for a specific fixture.
  void confirmVenue(String fixtureId) {
    final f = _fixture(fixtureId);
    if (f != null) { f.venueConfirmed = true; notifyListeners(); }
  }

  // ─── Lineup ───────────────────────────────────────────────────────────────

  /// Stores lineups for each fixture, keyed by fixture ID.
  Map<String, List<LineupPlayer>> lineups = {};

  /// Submits a lineup for a specific fixture.
  /// 
  /// [fixtureId] - The fixture to submit the lineup for
  /// [players] - List of players in the lineup
  void submitLineup(String fixtureId, List<LineupPlayer> players) {
    lineups[fixtureId] = players;
    notifyListeners();
  }

  /// Loads lineups from approved team squads for a specific fixture
  Future<void> loadLineupsForFixture(String fixtureId) async {
    try {
      final fixture = _fixture(fixtureId);
      if (fixture == null) return;

      // Load approved squads for both teams
      final homeTeamSquad = await _loadTeamSquad(fixture.homeTeam);
      final awayTeamSquad = await _loadTeamSquad(fixture.awayTeam);

      final allPlayers = <LineupPlayer>[];
      if (homeTeamSquad != null) allPlayers.addAll(homeTeamSquad);
      if (awayTeamSquad != null) allPlayers.addAll(awayTeamSquad);

      if (allPlayers.isNotEmpty) {
        lineups[fixtureId] = allPlayers;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading lineups for fixture: $e');
    }
  }

  /// Loads squad players for a specific team
  Future<List<LineupPlayer>?> _loadTeamSquad(String teamName) async {
    try {
      final teamResponse = await _db
          .from('teams')
          .select('id, players(*)')
          .eq('name', teamName)
          .eq('submission_status', 'approved')
          .single();

      final players = (teamResponse['players'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (players.isEmpty) return null;

      return players.map((p) => LineupPlayer(
        name: p['full_name'] as String? ?? 'Unknown',
        position: p['position'] as String? ?? 'Unknown',
        jerseyNo: p['jersey_number'] as int? ?? 0,
        team: teamName,
        photoUrl: p['photo_url'] as String?,
      )).toList();
    } catch (e) {
      debugPrint('Error loading team squad for $teamName: $e');
      return null;
    }
  }

  // ─── Live Match Events ────────────────────────────────────────────────────

  /// Sets a fixture as the currently live match.
  void setLiveFixture(String fixtureId) {
    activeFixtureId = fixtureId;
    final idx = generatedFixtures.indexWhere((f) => f.id == fixtureId);
    if (idx != -1) {
      generatedFixtures[idx].status = 'live';
      liveFixtureIndex = idx;
    }
    notifyListeners();
  }

  /// Records a goal event and updates the score.
  void recordGoal({
    required String fixtureId,
    required String team,
    required String player,
    required int minute,
    String? assistBy,
  }) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: 'goal', team: team, playerName: player, minute: minute, detail: assistBy != null ? 'Assist: $assistBy' : null));
    if (team == f.homeTeam) f.homeScore++; else f.awayScore++;
    notifyListeners();
  }

  /// Records a card event (yellow or red).
  void recordCard({
    required String fixtureId,
    required String team,
    required String player,
    required int minute,
    required bool isRed,
  }) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: isRed ? 'red' : 'yellow', team: team, playerName: player, minute: minute));
    final lineup = lineups[fixtureId];
    if (lineup != null) {
      final lp = lineup.firstWhere((p) => p.name == player && p.team == team, orElse: () => LineupPlayer(name: '', position: '', jerseyNo: 0, team: ''));
      if (lp.name.isNotEmpty) { if (isRed) lp.hasRed = true; else lp.hasYellow = true; }
    }
    notifyListeners();
  }

  void recordAssist({required String fixtureId, required String team, required String player, required int minute}) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: 'assist', team: team, playerName: player, minute: minute));
    notifyListeners();
  }

  void recordCorner({required String fixtureId, required String team, required int minute}) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: 'corner', team: team, playerName: '', minute: minute));
    notifyListeners();
  }

  void recordShot({required String fixtureId, required String team, required String player, required int minute}) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: 'shot', team: team, playerName: player, minute: minute));
    notifyListeners();
  }

  void recordPenalty({required String fixtureId, required String team, required String player, required int minute, required bool scored}) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: 'penalty', team: team, playerName: player, minute: minute, detail: scored ? 'Scored' : 'Missed'));
    if (scored) { if (team == f.homeTeam) f.homeScore++; else f.awayScore++; }
    notifyListeners();
  }

  /// Records a substitution event.
  void recordSubstitution({
    required String fixtureId,
    required String team,
    required String playerOut,
    required String playerIn,
    required int minute,
  }) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: 'sub', team: team, playerName: playerOut, minute: minute, detail: 'In: $playerIn'));
    final lineup = lineups[fixtureId];
    if (lineup != null) {
      final out = lineup.firstWhere((p) => p.name == playerOut && p.team == team, orElse: () => LineupPlayer(name: '', position: '', jerseyNo: 0, team: ''));
      if (out.name.isNotEmpty) out.isSubstituted = true;
    }
    notifyListeners();
  }

  /// Ends a match, marks it as completed, and updates standings.
  void endMatch(String fixtureId) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.status = 'completed';
    _updateStandings(f);
    if (liveFixtureIndex != null && generatedFixtures[liveFixtureIndex!].id == fixtureId) {
      liveFixtureIndex = null;
    }
    notifyListeners();
    // Persist final score
    updateFixture(fixtureId, status: 'completed', homeScore: f.homeScore, awayScore: f.awayScore);
  }

  // ─── Standings ────────────────────────────────────────────────────────────

  /// League standings table
  List<StandingEntry> standings = [];

  /// Rebuilds the standings table from all completed fixtures.
  void _rebuildStandings() {
    standings.clear();
    final teams = <String>{};
    for (final f in generatedFixtures) {
      teams.add(f.homeTeam);
      teams.add(f.awayTeam);
    }
    for (final t in teams) standings.add(StandingEntry(t));
    for (final f in generatedFixtures) {
      if (f.status == 'completed') _updateStandings(f);
    }
  }

  /// Updates standings based on a completed fixture result.
  void _updateStandings(GeneratedFixture f) {
    final home = _standing(f.homeTeam);
    final away = _standing(f.awayTeam);
    if (home == null || away == null) return;
    home.played++; away.played++;
    home.goalsFor += f.homeScore; home.goalsAgainst += f.awayScore;
    away.goalsFor += f.awayScore; away.goalsAgainst += f.homeScore;
    if (f.homeScore > f.awayScore) { home.wins++; home.points += 3; away.losses++; }
    else if (f.homeScore < f.awayScore) { away.wins++; away.points += 3; home.losses++; }
    else { home.draws++; home.points++; away.draws++; away.points++; }
    standings.sort((a, b) { final pc = b.points.compareTo(a.points); return pc != 0 ? pc : b.goalDifference.compareTo(a.goalDifference); });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Currently active fixture ID
  String? activeFixtureId;
  
  /// Match duration in minutes (default: 90)
  int matchDurationMinutes = 90;
  
  /// Sets the match duration.
  void setMatchDuration(int minutes) {
    matchDurationMinutes = minutes;
    notifyListeners();
  }

  /// Gets the currently live fixture.
  GeneratedFixture? get liveFixture =>
      liveFixtureIndex != null ? generatedFixtures[liveFixtureIndex!] : null;

  /// Finds a fixture by ID.
  GeneratedFixture? _fixture(String id) {
    try { return generatedFixtures.firstWhere((f) => f.id == id); } catch (_) { return null; }
  }

  /// Finds a standing entry by team name.
  StandingEntry? _standing(String team) {
    try { return standings.firstWhere((s) => s.team == team); } catch (_) { return null; }
  }

  /// Gets all fixtures for a specific team.
  List<GeneratedFixture> fixturesForTeam(String teamName) =>
      generatedFixtures
          .where((f) => f.homeTeam == teamName || f.awayTeam == teamName)
          .toList();

  /// Gets all fixtures assigned to a specific referee.
  List<GeneratedFixture> fixturesForReferee(String refereeName) =>
      generatedFixtures
          .where((f) => f.assignedReferee == refereeName)
          .toList();

  /// Gets the squad size for a team based on submitted lineups.
  int teamSquadSize(String teamName) {
    int count = 0;
    for (final lineup in lineups.values) {
      final teamPlayers = lineup.where((p) => p.team == teamName).length;
      if (teamPlayers > count) count = teamPlayers;
    }
    return count > 0 ? count : 18;
  }

  // ─── Pending Substitutions ────────────────────────────────────────────────

  /// List of pending substitution requests from coaches
  final List<Map<String, dynamic>> pendingSubstitutions = [];

  /// Requests a substitution (coach action).
  void requestSubstitution({
    required String fixtureId,
    required String team,
    required String playerOut,
    required String playerIn,
  }) {
    pendingSubstitutions.add({
      'fixtureId': fixtureId, 'team': team,
      'playerOut': playerOut, 'playerIn': playerIn,
      'status': 'pending', 'requestedAt': DateTime.now().toIso8601String(),
    });
    notifyListeners();
  }

  /// Approves a pending substitution (referee action).
  /// 
  /// [index] - Index of the substitution in pendingSubstitutions list
  /// [minute] - Minute when the substitution is approved
  void approveSubstitution(int index, int minute) {
    if (index >= pendingSubstitutions.length) return;
    final sub = pendingSubstitutions[index];
    sub['status'] = 'approved';
    recordSubstitution(
      fixtureId: sub['fixtureId'], team: sub['team'],
      playerOut: sub['playerOut'], playerIn: sub['playerIn'], minute: minute,
    );
    notifyListeners();
  }
}
