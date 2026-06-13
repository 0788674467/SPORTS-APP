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

  Map<String, dynamic> toJson() => {
        'type': type,
        'team': team,
        'player_name': playerName,
        'minute': minute,
        'detail': detail,
      };

  static MatchEvent fromJson(Map<String, dynamic> json) => MatchEvent(
        type: json['type'] as String? ?? 'unknown',
        team: json['team'] as String? ?? 'Unknown',
        playerName: json['player_name'] as String? ?? 'Unknown',
        minute: json['minute'] as int? ?? 0,
        detail: json['detail'] as String?,
      );
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
  
  /// Current minute of the live match
  int currentMinute;

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
    this.currentMinute = 0,
    this.status = 'scheduled',
    List<MatchEvent>? events,
  }) : events = events ?? [];

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
        'current_minute': currentMinute,
        'events': events.map((e) => e.toJson()).toList(),
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
        currentMinute: r['current_minute'] as int? ?? 0,
        events: (r['events'] as List<dynamic>?)
                ?.map((e) => MatchEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
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
        // The old matches table subscription has been removed to prevent channelError.
        // Live scores and statuses are now fully handled by the scheduled_matches table.
        .subscribe();
    initSubstitutionListener();
  }

  void _handleUpdate(Map<String, dynamic> data) {
    final idx = generatedFixtures.indexWhere((f) => f.id == data['id']);
    if (idx == -1) return;
    
    // Reconstruct fixture from DB data — events and currentMinute now come from DB
    generatedFixtures[idx] = GeneratedFixture.fromRow(data);
    
    // Update live fixture index if status changed
    if (generatedFixtures[idx].status == 'live') {
      liveFixtureIndex = idx;
    } else if (generatedFixtures[idx].status == 'completed' && liveFixtureIndex == idx) {
      liveFixtureIndex = null;
    }
    
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
    _substitutionChannel?.unsubscribe();
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
          
      // Restore live fixture index if a match is currently live
      final liveIdx = generatedFixtures.indexWhere((f) => f.status == 'live');
      liveFixtureIndex = liveIdx != -1 ? liveIdx : null;
      
      // Rebuild standings from completed fixtures
      await _rebuildStandings();
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

  /// Persists a coach's lineup to Supabase `lineups` table.
  /// [fixtureId] - The fixture ID
  /// [teamId] - The coach's team UUID
  /// [players] - All players with starter flag; first 11 = starters, rest = reserves
  Future<void> saveLineup(String fixtureId, String teamId, List<Map<String, dynamic>> players) async {
    if (players.isEmpty) return;
    try {
      // Delete any existing lineup for this fixture+team combo
      await _db.from('lineups').delete().match({'fixture_id': fixtureId, 'team_id': teamId});

      // Insert each player
      final rows = players.map((p) => {
        'fixture_id': fixtureId,
        'team_id': teamId,
        'player_id': p['id'],
        'jersey_number': int.tryParse(p['num'] ?? '0') ?? 0,
        'position': p['pos'] ?? 'MID',
        'is_starter': p['starter'] == true,
        'is_locked': false,
      }).toList();

      await _db.from('lineups').insert(rows);
      debugPrint('✅ Lineup saved for fixture $fixtureId team $teamId (${rows.length} players)');
    } catch (e) {
      debugPrint('⚠️ saveLineup error: $e');
    }
  }

  /// Loads a previously saved lineup for a fixture+team from Supabase.
  /// Returns a list of player maps matching the lineup_builder format, or empty.
  Future<List<Map<String, dynamic>>> loadSavedLineup(String fixtureId, String teamId) async {
    try {
      final rows = await _db
          .from('lineups')
          .select('player_id, jersey_number, position, is_starter, players!player_id(id, full_name, position, jersey_number, photo_url)')
          .match({'fixture_id': fixtureId, 'team_id': teamId})
          .order('is_starter', ascending: false);

      if (rows.isEmpty) return [];

      return (rows as List).map((r) {
        final p = r['players'] as Map<String, dynamic>? ?? {};
        return {
          'id': p['id'] ?? r['player_id'],
          'name': p['full_name'] ?? 'Unknown',
          'num': (r['jersey_number'] ?? p['jersey_number'] ?? 0).toString(),
          'pos': r['position'] ?? p['position'] ?? 'MID',
          'photoUrl': p['photo_url'],
          'starter': r['is_starter'] == true,
        };
      }).toList();
    } catch (e) {
      debugPrint('⚠️ loadSavedLineup error: $e');
      return [];
    }
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

  /// Removes a player from the local match lineup
  void removePlayerFromLineup(String fixtureId, String playerName) {
    if (lineups.containsKey(fixtureId)) {
      lineups[fixtureId]!.removeWhere((p) => p.name == playerName);
      notifyListeners();
    }
  }

  /// Loads squad players for a specific team
  Future<List<LineupPlayer>?> _loadTeamSquad(String teamName) async {
    try {
      // First try approved squads
      final teamResponse = await _db
          .from('teams')
          .select('id, submission_status, players(full_name, jersey_number, position, photo_url)')
          .eq('name', teamName)
          .maybeSingle();

      if (teamResponse == null) {
        debugPrint('⚠️ No team found with name: $teamName');
        return null;
      }

      final submissionStatus = teamResponse['submission_status'] as String? ?? 'draft';
      final players = (teamResponse['players'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (players.isEmpty) {
        debugPrint('⚠️ No players found for team: $teamName (status: $submissionStatus)');
        return null;
      }

      // Allow approved OR submitted squads to show (submitted = coach done, waiting admin)
      if (submissionStatus != 'approved' && submissionStatus != 'submitted') {
        debugPrint('⚠️ Squad for $teamName is still in draft — cannot show lineup');
        return null;
      }

      return players.map((p) => LineupPlayer(
        name: p['full_name'] as String? ?? 'Unknown',
        position: p['position'] as String? ?? '—',
        jerseyNo: p['jersey_number'] as int? ?? 0,
        team: teamName,
        photoUrl: p['photo_url'] as String?,
      )).toList();
    } catch (e) {
      debugPrint('Error loading team squad for $teamName: $e');
      return null;
    }
  }

  /// Saves both teams' lineups to the match report for spectator display
  Future<void> persistMatchLineups(String fixtureId, String homeTeamId, String awayTeamId) async {
    final home = lineups[fixtureId]?.where((p) => p.team.isNotEmpty).toList() ?? [];
    try {
      await _db.from('scheduled_matches').update({
        'home_lineup': home.where((p) => true).map((p) => p.name).toList(),
        'away_lineup': const <String>[],
      }).eq('id', fixtureId);
    } catch (_) {}
  }

  // ─── Live Match Events ────────────────────────────────────────────────────

  /// Marks a scheduled fixture's lineup as verified
  void verifyFixtureLineup(String fixtureId) {
    verifiedFixtures.add(fixtureId);
    notifyListeners();
  }

  /// Sets a fixture as the currently live match and persists the 'live' status to Supabase.
  void setLiveFixture(String fixtureId) {
    activeFixtureId = fixtureId;
    final idx = generatedFixtures.indexWhere((f) => f.id == fixtureId);
    if (idx != -1) {
      generatedFixtures[idx].status = 'live';
      liveFixtureIndex = idx;
      // Persist 'live' status immediately so returning users see the match is in progress
      _db.from('scheduled_matches').update({
        'status': 'live',
        'home_score': generatedFixtures[idx].homeScore,
        'away_score': generatedFixtures[idx].awayScore,
      }).eq('id', fixtureId).catchError((e) {
        debugPrint('⚠️ Failed to set live status: $e');
      });
    }
    notifyListeners();
  }

  /// Records a goal event and updates the score.
  /// Score is immediately persisted to Supabase so it survives app restarts.
  void recordGoal({
    required String fixtureId,
    required String team,
    required String player,
    required int minute,
    String? assistBy,
  }) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: 'goal', team: team, playerName: player, minute: minute, detail: assistBy != null ? 'Assist: \$assistBy' : null));
    if (team == f.homeTeam) f.homeScore++; else f.awayScore++;
    notifyListeners();
    // Persist immediately so score survives app exit/re-entry during a live match
    _persistLiveMatchState(f);
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
    _persistLiveMatchState(f);
  }

  void recordAssist({required String fixtureId, required String team, required String player, required int minute}) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: 'assist', team: team, playerName: player, minute: minute));
    notifyListeners();
    _persistLiveMatchState(f);
  }

  void recordCorner({required String fixtureId, required String team, required int minute}) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: 'corner', team: team, playerName: '', minute: minute));
    notifyListeners();
    _persistLiveMatchState(f);
  }

  void recordShot({required String fixtureId, required String team, required String player, required int minute}) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: 'shot', team: team, playerName: player, minute: minute));
    notifyListeners();
    _persistLiveMatchState(f);
  }

  void recordPenalty({required String fixtureId, required String team, required String player, required int minute, required bool scored}) {
    final f = _fixture(fixtureId);
    if (f == null) return;
    f.events.add(MatchEvent(type: 'penalty', team: team, playerName: player, minute: minute, detail: scored ? 'Scored' : 'Missed'));
    if (scored) {
      if (team == f.homeTeam) f.homeScore++; else f.awayScore++;
    }
    notifyListeners();
    _persistLiveMatchState(f);
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
    _persistLiveMatchState(f);
  }

  /// Persists the live score, events, and minute to Supabase during an ongoing match.
  /// Called after every event so data is never lost on app restart.
  void _persistLiveMatchState(GeneratedFixture f) {
    _db.from('scheduled_matches').update({
      'home_score': f.homeScore,
      'away_score': f.awayScore,
      'current_minute': f.currentMinute,
      'events': f.events.map((e) => e.toJson()).toList(),
      'status': 'live',
    }).eq('id', f.id).then((_) {
      debugPrint('✅ Live match state persisted: \${f.homeTeam} \${f.homeScore}–\${f.awayScore} \${f.awayTeam} (\${f.events.length} events)');
    }).catchError((e) {
      debugPrint('⚠️ Failed to persist live match state: $e');
    });
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
    // Persist final score and completed status
    updateFixture(fixtureId, status: 'completed', homeScore: f.homeScore, awayScore: f.awayScore);
  }

  /// Submits the final match report to Supabase.
  /// 
  /// Marks the fixture completed, persists the final score, and saves a
  /// detailed report row (with all events as JSON) to `match_reports`.
  /// Player stats are then aggregated by the referee dashboard UI.
  Future<void> submitMatchReport(String fixtureId) async {
    final f = _fixture(fixtureId);
    if (f == null) return;

    // 1. End the match (marks completed, updates standings & persists score)
    endMatch(fixtureId);

    // 2. Save detailed report to match_reports table
    try {
      final eventsJson = f.events.map((e) => {
        'type':        e.type,
        'team':        e.team,
        'player_name': e.playerName,
        'minute':      e.minute,
        'detail':      e.detail,
      }).toList();

      await _db.from('match_reports').upsert({
        'fixture_id':   fixtureId,
        'home_team':    f.homeTeam,
        'away_team':    f.awayTeam,
        'home_score':   f.homeScore,
        'away_score':   f.awayScore,
        'venue':        f.venue,
        'referee':      f.assignedReferee,
        'events':       eventsJson,
        'submitted_at': DateTime.now().toIso8601String(),
        'status':       'submitted',
      });
      debugPrint('✅ Match report saved for $fixtureId');
    } catch (e) {
      debugPrint('⚠️ submitMatchReport DB error: $e');
      // Non-fatal — player stat update in the UI still proceeds
    }
  }

  // ─── Standings ────────────────────────────────────────────────────────────

  /// League standings table
  List<StandingEntry> standings = [];

  /// Rebuilds the standings table from all completed fixtures.
  /// First tries the backend API, falls back to local computation.
  Future<void> _rebuildStandings() async {
    standings.clear();

    // Try backend API first
    try {
      final response = await _db.from('scheduled_matches').select('home_team, away_team, home_score, away_score, status').eq('status', 'completed');
      final teams = <String>{};
      for (final f in generatedFixtures) {
        teams.add(f.homeTeam);
        teams.add(f.awayTeam);
      }
      for (final t in teams) standings.add(StandingEntry(t));
      for (final r in response) {
        final home = _standing(r['home_team'] as String);
        final away = _standing(r['away_team'] as String);
        if (home == null || away == null) continue;
        final hs = r['home_score'] as int? ?? 0;
        final as = r['away_score'] as int? ?? 0;
        home.played++; away.played++;
        home.goalsFor += hs; home.goalsAgainst += as;
        away.goalsFor += as; away.goalsAgainst += hs;
        if (hs > as) { home.wins++; home.points += 3; away.losses++; }
        else if (hs < as) { away.wins++; away.points += 3; home.losses++; }
        else { home.draws++; home.points++; away.draws++; away.points++; }
      }
      standings.sort((a, b) { final pc = b.points.compareTo(a.points); return pc != 0 ? pc : b.goalDifference.compareTo(a.goalDifference); });
      return;
    } catch (_) {
      // Fallback to local
    }

    // Local fallback
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

  // The currently active live fixture
  String? activeFixtureId;
  
  // Set of fixture IDs that have had their lineups verified by the referee
  final Set<String> verifiedFixtures = {};

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

// ─── Pending Substitutions (Supabase Realtime) ──────────────────────────────
 
  /// List of pending substitution requests from coaches
  final List<Map<String, dynamic>> pendingSubstitutions = [];
 
  /// Internal: realtime subscription for substitution_requests
  RealtimeChannel? _substitutionChannel;
 
  /// Initializes realtime listener for substitution requests.
  void initSubstitutionListener() {
    _substitutionChannel?.unsubscribe();
    _substitutionChannel = Supabase.instance.client
        .channel('substitution-requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'substitution_requests',
          callback: (payload) {
            _onSubstitutionChange(payload);
          },
        )
        .subscribe();
  }
 
  void _onSubstitutionChange(dynamic payload) {
    final record = payload.newRecord;
    final oldRecord = payload.oldRecord;
    final eventType = payload.eventType;
 
    if (eventType == 'INSERT') {
      // New substitution request from coach
      final sub = _mapSubRecord(record);
      pendingSubstitutions.add(sub);
    } else if (eventType == 'UPDATE') {
      // Status change (approved/rejected)
      final index = pendingSubstitutions.indexWhere((s) => s['id'] == record['id']);
      if (index != -1) {
        pendingSubstitutions[index] = _mapSubRecord(record);
        // If approved, record the substitution event
        if (record['status'] == 'approved' && oldRecord?['status'] != 'approved') {
          _recordApprovedSubstitution(record);
        }
      }
    } else if (eventType == 'DELETE') {
      pendingSubstitutions.removeWhere((s) => s['id'] == oldRecord['id']);
    }
    notifyListeners();
  }
 
  Map<String, dynamic> _mapSubRecord(Map<String, dynamic> r) => {
    'id': r['id'],
    'fixtureId': r['match_id'],
    'teamId': r['team_id'],
    'playerOffId': r['player_off_id'],
    'playerOnId': r['player_on_id'],
    'status': r['status'],
    'minute': r['minute'],
    'requestedAt': r['requested_at'],
    'reviewedAt': r['reviewed_at'],
  };
 
  Future<void> _recordApprovedSubstitution(Map<String, dynamic> r) async {
    final playerOffName = await _resolvePlayerName(r['player_off_id'] as String);
    final playerOnName = await _resolvePlayerName(r['player_on_id'] as String);
    final teamName = await _resolveTeamName(r['team_id'] as String);

    if (playerOffName == null || playerOnName == null || teamName == null) return;

    recordSubstitution(
      fixtureId: r['match_id'] as String,
      team: teamName,
      playerOut: playerOffName,
      playerIn: playerOnName,
      minute: r['minute'] as int? ?? 0,
    );
  }

  Future<String?> _resolvePlayerName(String playerId) async {
    final res = await Supabase.instance.client
        .from('players')
        .select('full_name')
        .eq('id', playerId)
        .maybeSingle();
    return res?['full_name'] as String?;
  }

  Future<String?> _resolveTeamName(String teamId) async {
    final res = await Supabase.instance.client
        .from('teams')
        .select('name')
        .eq('id', teamId)
        .maybeSingle();
    return res?['name'] as String?;
  }
 
  /// Requests a substitution (coach action) — persists to Supabase.
  Future<void> requestSubstitution({
    required String fixtureId,
    required String team,
    required String playerOut,
    required String playerIn,
  }) async {
    // Resolve team_id and player IDs from names
    final teamId = await _resolveTeamId(team);
    if (teamId == null) throw Exception('Could not resolve team ID for $team');
    
    final playerOffId = await _resolvePlayerId(playerOut, teamId);
    if (playerOffId == null) throw Exception('Could not resolve player ID for $playerOut');
    
    final playerOnId = await _resolvePlayerId(playerIn, teamId);
    if (playerOnId == null) throw Exception('Could not resolve player ID for $playerIn');
 
    await Supabase.instance.client.from('substitution_requests').insert({
      'match_id': fixtureId,
      'team_id': teamId,
      'player_off_id': playerOffId,
      'player_on_id': playerOnId,
      'status': 'pending',
    });
    // Local optimistic update
    pendingSubstitutions.add({
      'fixtureId': fixtureId, 'team': team,
      'playerOut': playerOut, 'playerIn': playerIn,
      'status': 'pending', 'requestedAt': DateTime.now().toIso8601String(),
    });
    notifyListeners();
  }
 
  /// Approves a pending substitution (referee action) — updates Supabase.
  Future<void> approveSubstitution(String requestId, int minute) async {
    await Supabase.instance.client
        .from('substitution_requests')
        .update({'status': 'approved', 'minute': minute, 'reviewed_at': DateTime.now().toIso8601String()})
        .eq('id', requestId);
    // Local update handled by realtime listener
  }
 
  /// Rejects a pending substitution (referee action).
  Future<void> rejectSubstitution(String requestId) async {
    await Supabase.instance.client
        .from('substitution_requests')
        .update({'status': 'rejected', 'reviewed_at': DateTime.now().toIso8601String()})
        .eq('id', requestId);
  }
 
  Future<String?> _resolveTeamId(String teamName) async {
    final res = await Supabase.instance.client
        .from('teams')
        .select('id')
        .eq('name', teamName)
        .maybeSingle();
    return res?['id'] as String?;
  }
 
  Future<String?> _resolvePlayerId(String playerName, String teamId) async {
    final res = await Supabase.instance.client
        .from('players')
        .select('id')
        .eq('full_name', playerName)
        .eq('team_id', teamId)
        .maybeSingle();
    return res?['id'] as String?;
  }
 
}
