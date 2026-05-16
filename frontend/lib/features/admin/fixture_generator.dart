import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/match_state.dart';

/// Standalone fixture generator widget injected into admin Fixtures section.
class FixtureGeneratorPanel extends StatefulWidget {
  final List<String> teams;
  final List<String> referees;
  /// Full team DB rows (has 'name', 'logo_url', etc.)
  final List<Map<String, dynamic>> teamMaps;
  /// Venues from the DB: each map has 'id', 'name', 'location', 'is_active'.
  final List<Map<String, dynamic>> venues;
  /// Leagues from the DB: each map has 'id', 'name', 'season', 'is_active'.
  final List<Map<String, dynamic>> leagues;

  const FixtureGeneratorPanel({
    super.key,
    required this.teams,
    required this.referees,
    this.teamMaps = const [],
    this.venues = const [],
    this.leagues = const [],
  });

  @override
  State<FixtureGeneratorPanel> createState() => _FixtureGeneratorPanelState();
}

class _FixtureGeneratorPanelState extends State<FixtureGeneratorPanel> {
  DateTime _startDate = DateTime.now().add(const Duration(days: 3));
  int _daysBetween = 3;
  int _kickoffHour = 14;
  int _kickoffMinute = 0;
  bool _generated = false;
  bool _saving = false;
  String? _selectedLeagueId;
  String? _selectedLeagueName;

  // Selected venues (by name) — chip multi-select
  final Set<String> _selectedVenues = {};

  @override
  void initState() {
    super.initState();
    final active = widget.venues
        .where((v) => v['is_active'] == true)
        .map((v) => v['name'] as String)
        .toSet();
    _selectedVenues.addAll(active);
    // Auto-select first active league
    final activeLeague = widget.leagues.where((l) => l['is_active'] == true).firstOrNull;
    if (activeLeague != null) {
      _selectedLeagueId   = activeLeague['id'] as String?;
      _selectedLeagueName = activeLeague['name'] as String?;
    }
  }

  List<String> get _selectedVenueList =>
      widget.venues.isEmpty
          ? _selectedVenues.toList()
          : widget.venues
              .where((v) => _selectedVenues.contains(v['name']))
              .map((v) => v['name'] as String)
              .toList();

  Future<void> _generate(MatchState ms) async {
    if (widget.teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Need at least 2 teams to generate fixtures.')));
      return;
    }
    final venueList = _selectedVenueList;
    final badgeUrls = <String, String?>{};
    for (final t in widget.teamMaps) {
      final name = t['name'] as String?;
      final logo = t['logo_url'] as String?;
      if (name != null) badgeUrls[name] = logo;
    }
    setState(() => _saving = true);
    await ms.generateRoundRobin(
      teams: widget.teams,
      startDate: _startDate,
      daysBetween: _daysBetween,
      kickoffHour: _kickoffHour,
      kickoffMinute: _kickoffMinute,
      venues: venueList.isEmpty ? ['Main Ground'] : venueList,
      badgeUrls: badgeUrls,
    );
    if (!mounted) return;
    setState(() { _saving = false; _generated = true; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ ${ms.generatedFixtures.length} fixtures generated & saved!'),
      backgroundColor: const Color(0xFF1B5E20),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _autoAssign(MatchState ms) async {
    setState(() => _saving = true);
    await ms.autoAssignReferees(widget.referees);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Referees assigned to ${ms.generatedFixtures.length} fixtures & saved!'),
      backgroundColor: const Color(0xFF1565C0),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) setState(() => _startDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.watch<MatchState>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ─── Config Card ──────────────────────────────────────────────────────
      _card(
        title: '⚙️ Schedule Configuration',
        child: Column(children: [
          // Teams badge row
          if (widget.teams.isNotEmpty) ...[
            Wrap(
              spacing: 8, runSpacing: 8,
              children: widget.teams.map((t) {
                final tmap = widget.teamMaps.where((m) => m['name'] == t).firstOrNull;
                final logoUrl = tmap?['logo_url'] as String?;
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  _teamBadgeMini(t, logoUrl, size: 28),
                  const SizedBox(width: 6),
                  Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                ]);
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          Row(children: [
            Expanded(child: _configTile(
              icon: Icons.calendar_today_rounded, label: 'Start Date',
              value: '${_startDate.day}/${_startDate.month}/${_startDate.year}',
              onTap: _pickDate,
            )),
            const SizedBox(width: 12),
            Expanded(child: _configTile(
              icon: Icons.schedule_rounded, label: 'Kickoff Time',
              value: '${_kickoffHour.toString().padLeft(2, '0')}:${_kickoffMinute.toString().padLeft(2, '0')}',
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: _kickoffHour, minute: _kickoffMinute));
                if (t != null) setState(() { _kickoffHour = t.hour; _kickoffMinute = t.minute; });
              },
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Days Between Rounds:', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: _daysBetween.toDouble(),
                min: 1, max: 14, divisions: 13,
                activeColor: const Color(0xFF1565C0),
                label: '$_daysBetween days',
                onChanged: (v) => setState(() => _daysBetween = v.round()),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('$_daysBetween d', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
            ),
          ]),
          const SizedBox(height: 14),

          // ─── League Selector ─────────────────────────────────────────────
          _buildLeagueSelector(),
          const SizedBox(height: 14),

          // ─── Venue Multi-Select Chips ────────────────────────────────────
          _buildVenueSelector(),

          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _saving ? null : () => _generate(ms),
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: Text(_saving ? 'Saving...' : 'Generate & Save'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
            )),
            if (ms.generatedFixtures.isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _autoAssign(ms),
                icon: const Icon(Icons.person_pin_rounded, size: 18),
                label: const Text('Auto-Assign Refs'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1565C0), side: const BorderSide(color: Color(0xFF1565C0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
              )),
            ],
          ]),
        ]),
      ),
      // ─── Generated Fixtures ───────────────────────────────────────────────
      if (ms.generatedFixtures.isNotEmpty) ...[
        const SizedBox(height: 16),
        _card(
          title: '📅 Generated Fixtures (${ms.generatedFixtures.length} matches)',
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(children: [
                for (final h in ['#', 'Home', 'Away', 'Date', 'Time', 'Venue', 'Referee'])
                  Expanded(child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
              ]),
            ),
            const Divider(height: 1),
            ...ms.generatedFixtures.asMap().entries.map((e) {
              final f = e.value;
              final dt = f.dateTime;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                color: e.key % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                child: Row(children: [
                  Expanded(child: Text('${e.key + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                  Expanded(child: Text(f.homeTeam, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  Expanded(child: Text(f.awayTeam, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  Expanded(child: Text('${dt.day}/${dt.month}/${dt.year}', style: const TextStyle(fontSize: 11))),
                  Expanded(child: Text('${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 11))),
                  Expanded(child: Text(f.venue, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                  Expanded(child: Text(f.assignedReferee ?? '—', style: TextStyle(fontSize: 11, color: f.assignedReferee != null ? const Color(0xFF1565C0) : Colors.grey), overflow: TextOverflow.ellipsis)),
                ]),
              );
            }),
          ]),
        ),
      ],
    ]);
  }

  Widget _buildLeagueSelector() {
    final activeLeagues = widget.leagues.where((l) => l['is_active'] == true).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.emoji_events_rounded, size: 16, color: Color(0xFFFF8F00)),
        const SizedBox(width: 6),
        const Text('League', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (_selectedLeagueName != null)
          Text(_selectedLeagueName!, style: const TextStyle(fontSize: 11, color: Color(0xFF003087), fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      if (activeLeagues.isEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text('No active leagues. Add leagues in the Leagues section.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700))),
          ]),
        )
      else
        DropdownButtonFormField<String>(
          value: _selectedLeagueId,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            prefixIcon: const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFFF8F00)),
          ),
          hint: const Text('Select a league'),
          items: activeLeagues.map((l) {
            final lName   = (l['name'] as String?) ?? 'Unnamed';
            final lSeason = (l['season'] as String?);
            return DropdownMenuItem<String>(
              value: l['id'] as String,
              child: Text(lSeason != null ? '$lName ($lSeason)' : lName,
                  style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (id) {
            final league = activeLeagues.firstWhere((l) => l['id'] == id);
            setState(() {
              _selectedLeagueId   = id;
              _selectedLeagueName = (league['name'] as String?) ?? '';
            });
          },
        ),
    ]);
  }

  Widget _buildVenueSelector() {
    final hasDbVenues = widget.venues.isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.stadium_rounded, size: 16, color: Colors.teal),
        const SizedBox(width: 6),
        const Text('Venues for this Schedule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (_selectedVenues.isNotEmpty)
          Text('${_selectedVenues.length} selected', style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      if (hasDbVenues) ...[
        // DB-backed chip selector
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: widget.venues
            .where((v) => v['is_active'] == true)
            .map((v) {
              final name = v['name'] as String;
              final selected = _selectedVenues.contains(name);
              return FilterChip(
                label: Text(name, style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : Colors.teal.shade700,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                )),
                selected: selected,
                onSelected: (val) => setState(() {
                  if (val) _selectedVenues.add(name);
                  else _selectedVenues.remove(name);
                }),
                selectedColor: Colors.teal,
                backgroundColor: Colors.teal.withOpacity(0.08),
                checkmarkColor: Colors.white,
                side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
        ),
        if (widget.venues.where((v) => v['is_active'] == true).isEmpty)
          Text('No active venues. Add venues in the Venues section.', style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
      ] else ...[
        // Fallback: freeform text entry (pre-DB)
        _FallbackVenueInput(onChanged: (names) {
          setState(() {
            _selectedVenues.clear();
            _selectedVenues.addAll(names);
          });
        }),
      ],
    ]);
  }

  /// Mini team badge: shows logo if available, else coloured initials circle.
  Widget _teamBadgeMini(String teamName, String? logoUrl, {double size = 28}) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: Image.network(
          logoUrl,
          width: size, height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _teamInitials(teamName, size),
        ),
      );
    }
    return _teamInitials(teamName, size);
  }

  Widget _teamInitials(String teamName, double size) {
    final initials = teamName.split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withOpacity(0.15),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Center(
        child: Text(initials,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1565C0),
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _configTile({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: const Color(0xFF1565C0)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
        ]),
      ),
    );
  }
}

// ─── Fallback text-based venue input (used when DB venues not yet available) ──

class _FallbackVenueInput extends StatefulWidget {
  final ValueChanged<List<String>> onChanged;
  const _FallbackVenueInput({required this.onChanged});
  @override
  State<_FallbackVenueInput> createState() => _FallbackVenueInputState();
}

class _FallbackVenueInputState extends State<_FallbackVenueInput> {
  final _ctrl = TextEditingController(text: 'MMU Main Ground, Court A, Court B');
  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_notify);
    // Defer initial notification — must NOT call parent setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notify();
    });
  }
  void _notify() {
    final list = _ctrl.text.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
    widget.onChanged(list);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        labelText: 'Venues (comma-separated)',
        hintText: 'e.g. Main Ground, Court A',
        prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
        filled: true, fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
