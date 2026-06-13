import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/match_state.dart';

class EventRecorder extends StatefulWidget {
  final String fixtureId;
  final String eventType; // 'goal', 'yellow', 'red', 'sub', 'corner', 'penalty', 'shot'

  const EventRecorder({super.key, required this.fixtureId, required this.eventType});

  @override
  State<EventRecorder> createState() => _EventRecorderState();
}

class _EventRecorderState extends State<EventRecorder> {
  String? _selectedTeam;
  String? _selectedPlayer;
  String? _selectedAssist;
  String? _selectedPlayerIn;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final ms = context.read<MatchState>();
    final f = ms.generatedFixtures.firstWhereOrNull((x) => x.id == widget.fixtureId);
    if (f == null) return;
    // Trigger a rebuild after loading
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.watch<MatchState>();
    final f = ms.generatedFixtures.firstWhereOrNull((x) => x.id == widget.fixtureId);
    if (f == null) return Scaffold(appBar: AppBar(title: const Text('Event Recorder')), body: Center(child: const Text('Fixture not found')));

    // Get all players from lineups
    final lineups = ms.lineups[widget.fixtureId] ?? [];
    final allPlayers = <LineupPlayer>[];
    allPlayers.addAll(lineups);

    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('Event Recorder')), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Record ${widget.eventType.toUpperCase()}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedTeam,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Team', border: OutlineInputBorder()),
              items: [f.homeTeam, f.awayTeam].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedTeam = v;
                  _selectedPlayer = null;
                  _selectedAssist = null;
                  _selectedPlayerIn = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedTeam != null) ...[
              Text("Select Player:", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _getTeamPlayers(allPlayers, _selectedTeam!).length,
                  itemBuilder: (context, index) {
                    final p = _getTeamPlayers(allPlayers, _selectedTeam!)[index];
                    final isSelected = _selectedPlayer == p.name;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF00A651).withOpacity(0.1),
                        child: Text('#${p.jerseyNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF00A651))),
                      ),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${p.position}  •  ${p.team}'),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF00A651)) : null,
                      onTap: () => setState(() => _selectedPlayer = p.name),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (widget.eventType == 'goal') ...[
                DropdownButtonFormField<String>(
                  value: _selectedAssist,
                  isExpanded: true,
                  hint: const Text('None (optional)'),
                  decoration: const InputDecoration(labelText: 'Assisted By (optional)', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('— No assist —')),
                    ...allPlayers.map((p) => DropdownMenuItem(
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
                  onChanged: (v) => setState(() => _selectedAssist = v),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.eventType == 'sub') ...[
                DropdownButtonFormField<String>(
                  value: _selectedPlayerIn,
                  isExpanded: true,
                  hint: const Text('Select Player In'),
                  decoration: const InputDecoration(labelText: 'Player In', border: OutlineInputBorder()),
                  items: _getTeamPlayers(allPlayers, _selectedTeam!).map((p) => DropdownMenuItem(
                    value: p.name,
                    child: Row(children: [
                      Container(width: 26, height: 26, margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(5)),
                        child: Center(child: Text('${p.jerseyNo}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                      ),
                      Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                    ]),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedPlayerIn = v),
                ),
                const SizedBox(height: 16),
              ],
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit() ? () => _confirmEvent(ms, f) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<LineupPlayer> _getTeamPlayers(List<LineupPlayer> all, String team) {
    return all.where((p) => p.team == team).toList();
  }

  bool _canSubmit() {
    if (_selectedTeam == null) return false;
    if (widget.eventType == 'sub') return _selectedPlayer != null && _selectedPlayerIn != null;
    return _selectedPlayer != null;
  }

  void _confirmEvent(MatchState ms, GeneratedFixture f) {
    if (!_canSubmit()) return;
    final team = _selectedTeam!;
    final player = _selectedPlayer!;
    final minute = f.currentMinute;

    switch (widget.eventType) {
      case 'goal':
        ms.recordGoal(fixtureId: f.id, team: team, player: player, minute: minute, assistBy: _selectedAssist?.isEmpty ?? true ? null : _selectedAssist);
        break;
      case 'yellow':
        ms.recordCard(fixtureId: f.id, team: team, player: player, minute: minute, isRed: false);
        break;
      case 'red':
        ms.recordCard(fixtureId: f.id, team: team, player: player, minute: minute, isRed: true);
        break;
      case 'sub':
        ms.recordSubstitution(fixtureId: f.id, team: team, playerOut: player, playerIn: _selectedPlayerIn!, minute: minute);
        break;
      case 'corner':
        ms.recordCorner(fixtureId: f.id, team: team, minute: minute);
        break;
      case 'penalty':
        ms.recordPenalty(fixtureId: f.id, team: team, player: player, minute: minute, scored: true);
        break;
      case 'shot':
        ms.recordShot(fixtureId: f.id, team: team, player: player, minute: minute);
        break;
    }
    Navigator.pop(context);
  }
}