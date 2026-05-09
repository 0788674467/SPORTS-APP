import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/match_state.dart';
import '../../core/auth/auth_provider.dart' as auth;

/// Coach UI for requesting substitutions — visual tap-to-swap style
class SubstitutionRequest extends StatefulWidget {
  const SubstitutionRequest({super.key});
  @override
  State<SubstitutionRequest> createState() => _SubstitutionRequestState();
}

class _SubstitutionRequestState extends State<SubstitutionRequest> {
  String? _selectedFixId;

  // Tap state
  LineupPlayer? _selectedStarter; // the player tapped to come off
  bool _showBench = false;

  List<LineupPlayer> _getTeamLineup(MatchState ms, String teamName) {
    if (_selectedFixId == null) return [];
    final all = ms.lineups[_selectedFixId] ?? [];
    return all.where((p) => p.team == teamName).toList();
  }

  List<LineupPlayer> _getStarters(MatchState ms, String teamName) =>
      _getTeamLineup(ms, teamName).where((p) => !p.isSubstituted).toList();

  List<LineupPlayer> _getBench(MatchState ms, String teamName) =>
      _getTeamLineup(ms, teamName).where((p) => p.isSubstituted).toList();

  void _tapStarter(LineupPlayer player) {
    setState(() {
      if (_selectedStarter == player) {
        _selectedStarter = null;
        _showBench = false;
      } else {
        _selectedStarter = player;
        _showBench = true;
      }
    });
  }

  void _tapBench(BuildContext context, LineupPlayer benchPlayer, MatchState ms, String teamName) {
    if (_selectedStarter == null || _selectedFixId == null) return;

    final playerOut = _selectedStarter!.name;
    final playerIn  = benchPlayer.name;

    // MatchState.requestSubstitution recorded for the referee to approve
    ms.requestSubstitution(
      fixtureId: _selectedFixId!,
      team: teamName,
      playerOut: playerOut,
      playerIn: playerIn,
    );

    setState(() {
      _selectedStarter = null;
      _showBench = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.swap_horiz_rounded, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text('$playerOut ➜ $playerIn · Sent to referee!')),
      ]),
      backgroundColor: const Color(0xFF00A651),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.watch<MatchState>();
    final ap = context.read<auth.AuthProvider>();
    final teamName = ap.profile?['team_name'] ?? ap.user?.userMetadata?['team_name'] ?? 'My Team';
    final myFixtures = ms.fixturesForTeam(teamName)
        .where((f) => f.status == 'live' || f.status == 'scheduled')
        .toList();
    final mySubs = ms.pendingSubstitutions.where((s) => s['team'] == teamName).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Match selector ────────────────────────────────────────────────────
        if (myFixtures.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFixId,
                isExpanded: true,
                hint: const Text('Select a match'),
                items: myFixtures.map((f) => DropdownMenuItem(
                  value: f.id,
                  child: Text('⚽ ${f.homeTeam} vs ${f.awayTeam}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                )).toList(),
                onChanged: (v) => setState(() => _selectedFixId = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('No live/scheduled matches found.', style: TextStyle(fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // ── Instruction banner ────────────────────────────────────────────────
        if (_selectedStarter == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF00A651).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00A651).withOpacity(0.25)),
            ),
            child: const Row(children: [
              Icon(Icons.touch_app_rounded, color: Color(0xFF00A651), size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Tap a starting player to swap them out',
                style: TextStyle(fontSize: 13, color: Color(0xFF00A651), fontWeight: FontWeight.w600))),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.arrow_downward_rounded, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${_selectedStarter!.name} selected — now tap a bench player to bring on',
                style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600))),
              GestureDetector(
                onTap: () => setState(() { _selectedStarter = null; _showBench = false; }),
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.orange),
              ),
            ]),
          ),

        const SizedBox(height: 16),

        // ── Starting 11 ───────────────────────────────────────────────────────
        _sectionLabel('STARTING XI', Icons.sports_soccer_rounded, const Color(0xFF00A651)),
        const SizedBox(height: 10),
        if (_selectedFixId == null)
          const Text('Select a match to see your lineup', style: TextStyle(color: Colors.grey, fontSize: 13))
        else if (_getStarters(ms, teamName).isEmpty)
          const Text('No submitted lineup found for this match.', style: TextStyle(color: Colors.grey, fontSize: 13))
        else
          Wrap(spacing: 10, runSpacing: 10, children: _getStarters(ms, teamName).map((p) {
            final isSelected = _selectedStarter == p;
            return GestureDetector(
              onTap: () => _tapStarter(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.orange : const Color(0xFF00A651).withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10),
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _playerAvatar(p, isSelected),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                        color: isSelected ? Colors.orange.shade800 : Colors.black87)),
                    if (isSelected)
                      const Text('Tap to deselect', style: TextStyle(fontSize: 9, color: Colors.orange)),
                  ]),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_downward_rounded, color: Colors.orange, size: 14),
                  ],
                ]),
              ),
            );
          }).toList()),

        const SizedBox(height: 20),

        // ── Bench ─────────────────────────────────────────────────────────────
        _sectionLabel('BENCH / RESERVES', Icons.chair_alt_rounded, Colors.blueGrey),
        const SizedBox(height: 10),
        if (_getBench(ms, teamName).isEmpty)
          Text(_selectedFixId == null ? 'Select a match to see reserves' : 'No reserves available.', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))
        else
          Wrap(spacing: 10, runSpacing: 10, children: _getBench(ms, teamName).map((p) {
            final canSelect = _showBench && _selectedStarter != null;
            return GestureDetector(
              onTap: canSelect ? () => _tapBench(context, p, ms, teamName) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: canSelect ? Colors.green.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canSelect ? const Color(0xFF00A651) : Colors.grey.shade300,
                    width: canSelect ? 1.8 : 1,
                  ),
                  boxShadow: [
                    if (canSelect)
                      BoxShadow(color: const Color(0xFF00A651).withOpacity(0.2), blurRadius: 8),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _playerAvatar(p, canSelect),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13,
                        color: canSelect ? Colors.black87 : Colors.grey.shade600)),
                    if (canSelect)
                      const Text('Tap to bring on', style: TextStyle(fontSize: 9, color: Color(0xFF00A651))),
                  ]),
                  if (canSelect) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_upward_rounded, color: Color(0xFF00A651), size: 14),
                  ],
                ]),
              ),
            );
          }).toList()),

        const SizedBox(height: 24),

        // ── Pending requests ──────────────────────────────────────────────────
        if (mySubs.isNotEmpty) ...[
          _sectionLabel('PENDING REQUESTS', Icons.pending_actions_rounded, Colors.orange.shade700),
          const SizedBox(height: 10),
          ...mySubs.map((s) {
            final status = s['status'] as String;
            final color = status == 'approved'
                ? Colors.green
                : (status == 'rejected' ? Colors.red : Colors.orange);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
              ),
              child: Row(children: [
                // Arrow icon between players
                Expanded(child: Row(children: [
                  _subTag(s['playerOut'], Colors.red.shade100, Colors.red.shade700, '↓ OUT'),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.swap_horiz_rounded, size: 20, color: Colors.grey),
                  ),
                  _subTag(s['playerIn'], Colors.green.shade100, Colors.green.shade700, '↑ IN'),
                ])),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status.toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  Widget _sectionLabel(String label, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(
        fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1, color: color)),
    ]);
  }

  Widget _playerAvatar(LineupPlayer p, bool highlighted) {
    final photo = p.photoUrl;
    ImageProvider? img;
    if (photo != null) {
      if (photo.startsWith('data:')) {
        img = MemoryImage(Uri.parse(photo).data!.contentAsBytes());
      } else {
        img = NetworkImage(photo);
      }
    }
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted ? Colors.orange : const Color(0xFF00A651),
        image: img != null ? DecorationImage(image: img, fit: BoxFit.cover) : null,
      ),
      child: img == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('#${p.jerseyNo}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
        Text(p.position,
          style: const TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.bold)),
      ]) : null,
    );
  }

  Widget _subTag(String? name, Color bg, Color fg, String label) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, color: fg, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(name ?? '—',
          style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
          overflow: TextOverflow.ellipsis),
      ),
    ]));
  }
}
