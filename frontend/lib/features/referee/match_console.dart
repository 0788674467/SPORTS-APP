import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/state/match_state.dart';

class MatchConsole extends StatefulWidget {
  final String fixtureId;
  final void Function(GeneratedFixture)? onPenaltyShootout;

  const MatchConsole({super.key, required this.fixtureId, this.onPenaltyShootout});

  @override
  State<MatchConsole> createState() => _MatchConsoleState();
}

class _MatchConsoleState extends State<MatchConsole> {
  Timer? _matchTimer;
  bool _matchRunning = false;
  int _matchMinute = 0;
  int _matchDuration = 90;
  int _extraTime = 0;
  int _tickSeconds = 60;
  bool _isFirstHalf = true;

  static const _speedOptions = [1, 2, 5, 10, 60];

  String get _halfLabel => _isFirstHalf ? '1st Half' : '2nd Half';

  String get _timeDisplay {
    if (_extraTime > 0 && _matchMinute >= _matchDuration) {
      return '$_matchDuration+${_matchMinute - _matchDuration}\'';
    }
    return '$_matchMinute\'';
  }

  @override
  void initState() {
    super.initState();
    final ms = context.read<MatchState>();
    final f = _fixture(ms);
    if (f != null) {
      _matchMinute = f.currentMinute;
      if (f.status == 'live') {
        _matchRunning = true;
        _startTimer();
      }
    }
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    super.dispose();
  }

  GeneratedFixture? _fixture(MatchState ms) {
    try {
      return ms.generatedFixtures.firstWhere((x) => x.id == widget.fixtureId);
    } catch (_) {
      return null;
    }
  }

  void _startTimer() {
    _matchTimer?.cancel();
    setState(() => _matchRunning = true);
    _matchTimer = Timer.periodic(Duration(seconds: _tickSeconds), (_) {
      if (!mounted) return;
      setState(() {
        final limit = _matchDuration + (_extraTime > 0 ? _extraTime : 0);
        if (_matchMinute < limit) {
          _matchMinute++;
          final ms = context.read<MatchState>();
          final f = _fixture(ms);
          if (f != null) {
            f.currentMinute = _matchMinute;
            Supabase.instance.client
                .from('scheduled_matches')
                .update({'current_minute': _matchMinute})
                .eq('id', widget.fixtureId)
                .catchError((e) {});
          }
        } else {
          _matchTimer?.cancel();
          _matchRunning = false;
        }
      });
    });
  }

  void _stopTimer() {
    _matchTimer?.cancel();
    setState(() => _matchRunning = false);
  }

  void _addExtraTime(int minutes) {
    setState(() {
      _extraTime += minutes;
    });
  }

  void _halfTime() {
    _stopTimer();
    setState(() {
      _isFirstHalf = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Half time — ${_matchMinute}\' played'), backgroundColor: Colors.indigo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.watch<MatchState>();
    final f = _fixture(ms);
    if (f == null) {
      return const Center(child: Text('Fixture not found'));
    }

    final goalEvents = f.events.where((e) => e.type == 'goal' || (e.type == 'penalty' && (e.detail ?? '').contains('Scored'))).toList();
    final homeScorers = goalEvents.where((e) => e.team == f.homeTeam).map((e) => '${e.playerName} ${e.minute}\'').toList();
    final awayScorers = goalEvents.where((e) => e.team == f.awayTeam).map((e) => '${e.playerName} ${e.minute}\'').toList();

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ── Fixture header ────────────────────────────────────────────────
          Row(children: [
            Text('${f.homeTeam} vs ${f.awayTeam}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: f.status == 'live' ? Colors.red.shade600 : Colors.grey.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(f.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 14),
          // ── Scoreboard ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0D0F2A), Color(0xFF1A0835)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: const Color(0xFF003087).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.red.shade300, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                  ]),
                ),
                const Spacer(),
                Row(children: [
                  GestureDetector(
                    onTap: f.status == 'completed' ? null : (_matchRunning ? _stopTimer : _startTimer),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: f.status == 'completed' ? Colors.grey.withOpacity(0.2) : (_matchRunning ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(children: [
                        Icon(f.status == 'completed' ? Icons.stop : (_matchRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          color: f.status == 'completed' ? Colors.grey : (_matchRunning ? Colors.red : Colors.green), size: 16),
                        const SizedBox(width: 4),
                        Text(_timeDisplay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ]),
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Home team
                Expanded(child: Column(children: [
                  Text(f.homeScore.toString(), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                  Text(f.homeTeam, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                  if (homeScorers.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...homeScorers.map((s) => Text(s, style: const TextStyle(color: Colors.white54, fontSize: 10))),
                  ],
                ])),
                // Center: minute + venue
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    const SizedBox(height: 4),
                    Text(_timeDisplay, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(_halfLabel, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w500)),
                    Text(f.venue, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white30, fontSize: 8)),
                  ]),
                ),
                // Away team
                Expanded(child: Column(children: [
                  Text(f.awayScore.toString(), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                  Text(f.awayTeam, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                  if (awayScorers.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...awayScorers.map((s) => Text(s, style: const TextStyle(color: Colors.white54, fontSize: 10))),
                  ],
                ])),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.timer_rounded, color: Colors.white38, size: 15),
                const SizedBox(width: 6),
                Text('Match duration: $_matchDuration min${_extraTime > 0 ? ' +$_extraTime ET' : ''}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const Spacer(),
                const Icon(Icons.speed, color: Colors.white38, size: 15),
                const SizedBox(width: 4),
                Text('${_tickSeconds}s/min', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          // ── Event Buttons ─────────────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _eventBtn('GOAL', const Color(0xFF00A651), Icons.sports_soccer, f.status == 'completed' ? null : () => _recordEvent(ms, f, 'goal')),
              _eventBtn('YELLOW', const Color(0xFFF9A825), Icons.rectangle, f.status == 'completed' ? null : () => _recordEvent(ms, f, 'yellow')),
              _eventBtn('RED', const Color(0xFFC62828), Icons.rectangle, f.status == 'completed' ? null : () => _recordEvent(ms, f, 'red')),
              _eventBtn('SUB', const Color(0xFF1565C0), Icons.swap_horiz, f.status == 'completed' ? null : () => _recordEvent(ms, f, 'sub')),
              _eventBtn('CORNER', const Color(0xFF003087), Icons.flag, f.status == 'completed' ? null : () => ms.recordCorner(fixtureId: f.id, team: f.homeTeam, minute: _matchMinute)),
              _eventBtn('PENALTY', const Color(0xFFF5A500), Icons.warning, f.status == 'completed' ? null : () => _recordEvent(ms, f, 'penalty')),
              _eventBtn('SHOT', const Color(0xFF00695C), Icons.my_location, f.status == 'completed' ? null : () => _recordEvent(ms, f, 'shot')),
              _eventBtn('HALF', const Color(0xFF7B1FA2), Icons.pause_circle, f.status == 'completed' ? null : _halfTime),
              _eventBtn('END', const Color(0xFF263238), Icons.stop, f.status == 'completed' ? null : () {
                ms.endMatch(f.id);
                _stopTimer();
              }),
            ],
          ),
          const SizedBox(height: 12),
          // ── Clock Controls ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.speed, size: 16),
                const SizedBox(width: 6),
                const Text('Speed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(width: 8),
                ..._speedOptions.map((s) {
                  final active = _tickSeconds == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text('${s == 60 ? "1x" : s == 1 ? "FAST" : "${60 ~/ s}x"}', style: TextStyle(fontSize: 10, color: active ? Colors.white : Colors.black87)),
                      selected: active,
                      selectedColor: const Color(0xFF003087),
                      onSelected: (_) {
                        if (_matchRunning) return;
                        setState(() => _tickSeconds = s);
                      },
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                  );
                }),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.timer_outlined, size: 16),
                const SizedBox(width: 6),
                const Text('Extra Time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(width: 8),
                ...[1, 2, 3, 5].map((m) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ActionChip(
                    label: Text('+$m\'', style: const TextStyle(fontSize: 11)),
                    onPressed: _matchRunning ? () => _addExtraTime(m) : null,
                    visualDensity: VisualDensity.compact,
                  ),
                )),
                const Spacer(),
                if (_extraTime > 0)
                  ActionChip(
                    label: Text('Reset ET', style: const TextStyle(fontSize: 10, color: Colors.red)),
                    onPressed: () => setState(() => _extraTime = 0),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.red.shade50,
                  ),
              ]),
            ]),
          ),
          if (widget.onPenaltyShootout != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.emoji_events, color: Colors.white, size: 18),
                label: const Text('Penalty Shootout', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF37474F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => widget.onPenaltyShootout?.call(f),
              ),
            ),
          ],
        ]),
      );
  }

  Widget _eventBtn(String label, Color bgColor, IconData icon, VoidCallback? onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: onTap == null ? Colors.grey.shade400 : bgColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(8),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  void _recordEvent(MatchState ms, GeneratedFixture f, String type) {
    String? selectedTeam;
    String? selectedPlayer;
    String? selectedAssist;
    // Get lineups from MatchState
    final msLineups = ms.lineups[widget.fixtureId] ?? [];
    final allPlayers = <LineupPlayer>[];
    allPlayers.addAll(msLineups);

    showDialog(
      context: context,
      builder: (ctx) {
        String? team;
        String? player;
        String? assist;
        String? playerIn;
        return StatefulBuilder(builder: (ctx, setS) {
          final teamPlayers = allPlayers.where((p) => p.team == team).toList();
          final oppPlayers = allPlayers.where((p) => p.team != team && team != null).toList();
          final bothTeams = [...allPlayers.where((p) => p.team == f.homeTeam), ...allPlayers.where((p) => p.team == f.awayTeam)];
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(_eventTitle(type)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: team,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Team', border: OutlineInputBorder()),
                    items: [f.homeTeam, f.awayTeam].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setS(() { team = v; player = null; assist = null; playerIn = null; }),
                  ),
                  const SizedBox(height: 12),
                  if (teamPlayers.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: player,
                      isExpanded: true,
                      hint: const Text('Select Player'),
                      decoration: const InputDecoration(labelText: 'Player', border: OutlineInputBorder()),
                      items: teamPlayers.map((p) => DropdownMenuItem(
                        value: p.name,
                        child: Row(children: [
                          Container(width: 24, height: 24, margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(5)),
                            child: Center(child: Text('${p.jerseyNo}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                          ),
                          Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                          const SizedBox(width: 4),
                          Text('(${p.team.split(' ').first})', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ]),
                      )).toList(),
                      onChanged: (v) => setS(() => player = v),
                    )
                  else
                    TextField(
                      decoration: const InputDecoration(labelText: 'Player Name', border: OutlineInputBorder()),
                      onChanged: (v) => player = v,
                    ),
                  if (type == 'goal') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: assist,
                      isExpanded: true,
                      hint: const Text('None (optional)'),
                      decoration: const InputDecoration(labelText: 'Assisted By (optional)', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('— No assist —')),
                        ...bothTeams.map((p) => DropdownMenuItem(
                          value: p.name,
                          child: Row(children: [
                            Container(width: 24, height: 24, margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(5)),
                              child: Center(child: Text('${p.jerseyNo}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                            ),
                            Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                            const SizedBox(width: 4),
                            Text('(${p.team.split(' ').first})', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ]),
                        )),
                      ],
                      onChanged: (v) => setS(() => assist = v),
                    ),
                  ],
                  if (type == 'sub') ...[
                    const SizedBox(height: 12),
                    if (teamPlayers.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: playerIn,
                        isExpanded: true,
                        hint: const Text('Select Player In'),
                        decoration: const InputDecoration(labelText: 'Player In', border: OutlineInputBorder()),
                        items: teamPlayers.map((p) => DropdownMenuItem(
                          value: p.name,
                          child: Row(children: [
                            Container(width: 26, height: 26, margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(5)),
                              child: Center(child: Text('${p.jerseyNo}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                            ),
                            Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                          ]),
                        )).toList(),
                        onChanged: (v) => setS(() => playerIn = v),
                      )
                    else
                      TextField(
                        decoration: const InputDecoration(labelText: 'Player In', border: OutlineInputBorder()),
                        onChanged: (v) => playerIn = v,
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (team == null || (player == null && type != 'sub')) return;
                  final p = player ?? '';
                  switch (type) {
                    case 'goal':
                      ms.recordGoal(fixtureId: f.id, team: team!, player: p, minute: _matchMinute, assistBy: assist?.isEmpty ?? true ? null : assist);
                      break;
                    case 'yellow':
                      ms.recordCard(fixtureId: f.id, team: team!, player: p, minute: _matchMinute, isRed: false);
                      break;
                    case 'red':
                      ms.recordCard(fixtureId: f.id, team: team!, player: p, minute: _matchMinute, isRed: true);
                      break;
                    case 'sub':
                      ms.recordSubstitution(fixtureId: f.id, team: team!, playerOut: p, playerIn: playerIn ?? 'Sub', minute: _matchMinute);
                      break;
                    case 'corner':
                      ms.recordCorner(fixtureId: f.id, team: team!, minute: _matchMinute);
                      break;
                    case 'penalty':
                      ms.recordPenalty(fixtureId: f.id, team: team!, player: p, minute: _matchMinute, scored: true);
                      break;
                    case 'shot':
                      ms.recordShot(fixtureId: f.id, team: team!, player: p, minute: _matchMinute);
                      break;
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Record'),
              ),
            ],
          );
        });
      },
    );
  }

  String _eventTitle(String type) {
    const m = {'goal':'Record Goal', 'assist':'Record Assist', 'yellow':'Yellow Card', 'red':'Red Card', 'corner':'Corner', 'shot':'Shot on Target', 'penalty':'Penalty', 'sub':'Substitution'};
    return m[type] ?? 'Record Event';
  }
}
