import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/match_state.dart';

// ─── Lineup Builder (Squad-Driven, Photo-Enabled) ─────────────────────────────
class LineupBuilder extends StatefulWidget {
  final bool darkMode;
  final List<Map<String, dynamic>> squad; // Passed in from coach dashboard
  const LineupBuilder({super.key, this.darkMode = false, this.squad = const []});
  @override
  State<LineupBuilder> createState() => _LineupBuilderState();
}

class _LineupBuilderState extends State<LineupBuilder> {
  String _formation = '4-3-3';
  bool _shared = false;

  static const _formations = ['4-3-3', '4-4-2', '3-5-2', '5-3-2'];

  // Internal mutable list — updated when squad changes.
  // Each entry has a 'starter' flag set automatically.
  late List<Map<String, dynamic>> _allPlayers;

  // Position priority for auto-filling lineup (GK → DF → MF → FW)
  static const _posPriority = {'GK': 0, 'DF': 1, 'MF': 2, 'FW': 3};

  @override
  void initState() {
    super.initState();
    _rebuildFromSquad(widget.squad);
  }

  @override
  void didUpdateWidget(LineupBuilder old) {
    super.didUpdateWidget(old);
    if (old.squad != widget.squad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildFromSquad(widget.squad);
      });
    }
  }

  /// Sorts squad by position priority, marks first 11 as starters, rest as reserves.
  void _rebuildFromSquad(List<Map<String, dynamic>> squad) {
    final sorted = List<Map<String, dynamic>>.from(squad);
    sorted.sort((a, b) {
      final pa = _posPriority[a['pos']] ?? 4;
      final pb = _posPriority[b['pos']] ?? 4;
      return pa.compareTo(pb);
    });
    if (mounted) {
      setState(() {
        _allPlayers = sorted.asMap().entries.map((e) {
          return {...e.value, 'starter': e.key < 11};
        }).toList();
      });
    }
  }

  List<Map<String, dynamic>> get _starters =>
      _allPlayers.where((p) => p['starter'] == true).take(11).toList();

  List<Map<String, dynamic>> get _reserves =>
      _allPlayers.where((p) => p['starter'] == false).toList();

  int? _swappingIndex; // index in _starters awaiting swap

  List<Offset> _getPositions() {
    switch (_formation) {
      case '4-4-2':
        return const [
          Offset(0.5, 0.88),
          Offset(0.15, 0.70), Offset(0.38, 0.72), Offset(0.62, 0.72), Offset(0.85, 0.70),
          Offset(0.15, 0.50), Offset(0.38, 0.48), Offset(0.62, 0.48), Offset(0.85, 0.50),
          Offset(0.35, 0.22), Offset(0.65, 0.22),
        ];
      case '3-5-2':
        return const [
          Offset(0.5, 0.88),
          Offset(0.25, 0.72), Offset(0.5, 0.73), Offset(0.75, 0.72),
          Offset(0.12, 0.52), Offset(0.3, 0.50), Offset(0.5, 0.48), Offset(0.7, 0.50), Offset(0.88, 0.52),
          Offset(0.35, 0.20), Offset(0.65, 0.20),
        ];
      case '5-3-2':
        return const [
          Offset(0.5, 0.88),
          Offset(0.12, 0.72), Offset(0.3, 0.73), Offset(0.5, 0.74), Offset(0.7, 0.73), Offset(0.88, 0.72),
          Offset(0.28, 0.50), Offset(0.5, 0.48), Offset(0.72, 0.50),
          Offset(0.35, 0.22), Offset(0.65, 0.22),
        ];
      default: // 4-3-3
        return const [
          Offset(0.5, 0.88),
          Offset(0.15, 0.70), Offset(0.38, 0.72), Offset(0.62, 0.72), Offset(0.85, 0.70),
          Offset(0.25, 0.48), Offset(0.5, 0.46), Offset(0.75, 0.48),
          Offset(0.15, 0.20), Offset(0.5, 0.16), Offset(0.85, 0.20),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Print squad data to see what's being passed
    debugPrint('LineupBuilder: Squad data: ${widget.squad}');
    
    if (widget.squad.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.group_add_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('No players in squad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
        const SizedBox(height: 8),
        Text('Register players in the Squad tab first.', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      ]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildFormationSelector(),
        const SizedBox(height: 16),
        _buildPitch(),
        const SizedBox(height: 16),
        _buildReserveSection(),
        const SizedBox(height: 16),
        _buildShareBar(),
        if (_swappingIndex != null) _buildSwapOverlay(),
      ]),
    );
  }

  Widget _buildFormationSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Formation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${_starters.length}/11 starters · ${_reserves.length} reserves',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: _formations.map((f) {
          final isSelected = _formation == f;
          return GestureDetector(
            onTap: () => setState(() => _formation = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00A651) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(f, style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          );
        }).toList()),
      ]),
    );
  }

  Widget _buildPitch() {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final h = w * 1.45;
      final positions = _getPositions();
      final starters = _starters;

      return Container(
        width: w, height: h,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFF00A651).withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20),
          ]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(children: [
            CustomPaint(size: Size(w, h), painter: _DarkPitchPainter()),
            Positioned(top: 12, left: 16, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Text('${_formation}  ·  ${starters.length}/11',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
            )),
            if (starters.isEmpty)
              const Center(child: Text('Register players to fill lineup',
                style: TextStyle(color: Colors.white60, fontSize: 13))),
            ...List.generate(starters.length, (i) {
              if (i >= positions.length) return const SizedBox.shrink();
              final p = positions[i];
              final player = starters[i];
              final photoBytes = player['photoBytes'] as Uint8List?;
              final photoUrl = player['photoUrl'] as String?;
              return Positioned(
                left: p.dx * w - 36,
                top: p.dy * h - 48,
                child: GestureDetector(
                  onTap: () => setState(() => _swappingIndex = i),
                  child: _PlayerPin(
                    name: player['name']!,
                    number: player['num']!,
                    position: player['pos']!,
                    photoBytes: photoBytes,
                    photoUrl: photoUrl,
                    isHighlighted: _swappingIndex == i,
                  ),
                ),
              );
            }),
          ]),
        ),
      );
    });
  }

  Widget _buildReserveSection() {
    final reserves = _reserves;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('RESERVES / BENCH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
          const Spacer(),
          Text('${reserves.length} players', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        if (reserves.isEmpty)
          Text('All players are in the starting lineup.', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))
        else
          ...reserves.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            final photoBytes = p['photoBytes'] as Uint8List?;
            // Find actual index in _allPlayers for swapping
            final allIdx = _allPlayers.indexOf(p);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade100,
                  backgroundImage: photoBytes != null 
                      ? MemoryImage(photoBytes) as ImageProvider
                      : (p['photoUrl'] != null ? NetworkImage(p['photoUrl']) as ImageProvider : null),
                  child: (photoBytes == null && p['photoUrl'] == null)
                    ? Text('#${p['num']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))
                    : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['name']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('#${p['num']} · ${p['pos']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ])),
                // Move to bench label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.airline_seat_recline_normal_rounded, size: 13, color: Colors.orange),
                    SizedBox(width: 4),
                    Text('Bench', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(width: 8),
                // Move to lineup (only if < 11 starters)
                if (_starters.length < 11)
                  IconButton(
                    icon: const Icon(Icons.arrow_circle_up_rounded, color: Color(0xFF00A651), size: 22),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    tooltip: 'Move to lineup',
                    onPressed: () => setState(() {
                      _allPlayers[allIdx]['starter'] = true;
                    }),
                  ),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _buildSwapOverlay() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF00A651).withOpacity(0.15), const Color(0xFF00A651).withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00A651).withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.swap_horiz_rounded, color: Color(0xFF00A651), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Replace ${_starters[_swappingIndex!]['name']} with:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00A651)))),
          GestureDetector(onTap: () => setState(() => _swappingIndex = null),
            child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey)),
        ]),
        const SizedBox(height: 12),
        if (_reserves.isEmpty)
          const Text('No reserves available.', style: TextStyle(color: Colors.grey))
        else
          Wrap(spacing: 8, runSpacing: 8, children: _reserves.asMap().entries.map((e) {
            final p = e.value;
            final photoBytes = p['photoBytes'] as Uint8List?;
            return GestureDetector(
              onTap: () => _doSwap(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00A651).withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(radius: 14,
                    backgroundColor: const Color(0xFF00A651).withOpacity(0.1),
                    backgroundImage: photoBytes != null 
                        ? MemoryImage(photoBytes) as ImageProvider
                        : (p['photoUrl'] != null ? NetworkImage(p['photoUrl']) as ImageProvider : null),
                    child: (photoBytes == null && p['photoUrl'] == null)
                      ? Text('#${p['num']}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00A651)))
                      : null,
                  ),
                  const SizedBox(width: 6),
                  Text(p['name']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  Text('(${p['pos']})', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ]),
              ),
            );
          }).toList()),
      ]),
    );
  }

  void _doSwap(int reserveIndex) {
    if (_swappingIndex == null) return;
    final starterActualIndex = _allPlayers.indexOf(_starters[_swappingIndex!]);
    final reserveActualIndex = _allPlayers.indexOf(_reserves[reserveIndex]);
    final incomingName = _allPlayers[reserveActualIndex]['name'];
    setState(() {
      _allPlayers[starterActualIndex]['starter'] = false;
      _allPlayers[reserveActualIndex]['starter'] = true;
      _swappingIndex = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$incomingName moved into the lineup!'),
      backgroundColor: const Color(0xFF00A651),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _buildShareBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(0xFF00A651).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.shield_rounded, color: Color(0xFF00A651), size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_starters.length < 11
            ? 'Lineup incomplete (${_starters.length}/11)'
            : 'Lineup Ready ✓',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Text('Tap a player on the pitch to swap. Share when ready.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _starters.length < 11 ? null : () {
            final ms = context.read<MatchState>();
            final lf = ms.liveFixture ?? (ms.generatedFixtures.isNotEmpty ? ms.generatedFixtures.first : null);
            if (lf != null) {
              final lineupPlayers = _starters.map((p) => LineupPlayer(
                name: p['name']!,
                position: p['pos']!,
                jerseyNo: int.tryParse(p['num'] ?? '0') ?? 0,
                team: 'My Team',
                photoUrl: p['photoUrl'] ?? _bytesToDataUri(p['photoBytes'] as Uint8List?),
              )).toList();
              ms.submitLineup(lf.id, lineupPlayers);
            }
            setState(() => _shared = true);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Row(children: [Icon(Icons.check_circle_rounded, color: Colors.white), SizedBox(width: 8), Text('Lineup shared with referee!')]),
              backgroundColor: const Color(0xFF00A651), behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
            ));
          },
          icon: Icon(_shared ? Icons.check_rounded : Icons.share_rounded, size: 16),
          label: Text(_shared ? 'Shared ✓' : 'Share with Ref'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _shared ? Colors.green.shade700 : const Color(0xFF00A651),
            disabledBackgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
        ),
      ]),
    );
  }

  String? _bytesToDataUri(Uint8List? bytes) {
    if (bytes == null) return null;
    final b64 = base64Encode(bytes);
    return 'data:image/jpeg;base64,$b64';
  }
}

// ─── Player Pin (with optional photo) ────────────────────────────────────────

class _PlayerPin extends StatelessWidget {
  final String name, number, position;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final bool isHighlighted;
  const _PlayerPin({required this.name, required this.number, required this.position, this.photoBytes, this.photoUrl, this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 72, child: Column(children: [
      Stack(alignment: Alignment.bottomRight, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHighlighted ? const Color(0xFFFFEB3B) : Colors.white,
            border: Border.all(
              color: isHighlighted ? const Color(0xFFFFEB3B) : const Color(0xFF00A651),
              width: isHighlighted ? 3 : 2.5),
            boxShadow: [
              if (isHighlighted)
                BoxShadow(color: const Color(0xFFFFEB3B).withOpacity(0.7), blurRadius: 16),
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3)),
            ],
          ),
          child: photoBytes != null
            ? ClipOval(child: Image.memory(photoBytes!, width: 48, height: 48, fit: BoxFit.cover))
            : (photoUrl != null
                ? ClipOval(child: Image.network(photoUrl!, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackPin()))
                : _fallbackPin()),
        ),
        // Position Badge Overlay
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF003087),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Text(position, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
        ),
      ]),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(6)),
        child: Text(name.split(' ').first,
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
      ),
    ]));
  }

  Widget _fallbackPin() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(number, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14,
        color: isHighlighted ? Colors.black87 : const Color(0xFF00A651))),
      Text(position, style: TextStyle(fontSize: 7,
        color: isHighlighted ? Colors.black54 : const Color(0xFF00A651),
        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    ]);
  }
}

// ─── Dark Purple Glowing Pitch Painter ───────────────────────────────────────

class _DarkPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;

    final bgPaint = Paint()..shader = const RadialGradient(
      colors: [Color(0xFF2A0A4A), Color(0xFF1A0835), Color(0xFF0D0A1E)],
      center: Alignment.center, radius: 1.0,
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    for (int i = 0; i < 12; i++) {
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(0, i * h / 12, w, h / 12),
          Paint()..color = Colors.white.withOpacity(0.015));
      }
    }

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = const RadialGradient(
        colors: [Color(0x181B5E20), Color(0x00000000)],
        center: Alignment.center, radius: 0.8,
      ).createShader(Rect.fromLTWH(0, 0, w, h)));

    final glow = Paint()
      ..color = const Color(0xFF00A651).withOpacity(0.25)
      ..style = PaintingStyle.stroke..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final line = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2;

    void drawLine(Offset a, Offset b) { canvas.drawLine(a, b, glow); canvas.drawLine(a, b, line); }
    void drawRectGlow(Rect r) { canvas.drawRect(r, glow); canvas.drawRect(r, line); }
    void drawCircleGlow(Offset c, double r) { canvas.drawCircle(c, r, glow); canvas.drawCircle(c, r, line); }

    drawRectGlow(Rect.fromLTWH(w * 0.04, h * 0.02, w * 0.92, h * 0.96));
    drawLine(Offset(w * 0.04, h * 0.5), Offset(w * 0.96, h * 0.5));
    drawCircleGlow(Offset(w / 2, h / 2), w * 0.14);
    canvas.drawCircle(Offset(w / 2, h / 2), 3, Paint()..color = Colors.white.withOpacity(0.6));
    drawRectGlow(Rect.fromLTWH(w * 0.22, h * 0.02, w * 0.56, h * 0.17));
    drawRectGlow(Rect.fromLTWH(w * 0.36, h * 0.02, w * 0.28, h * 0.08));
    drawRectGlow(Rect.fromLTWH(w * 0.22, h * 0.81, w * 0.56, h * 0.17));
    drawRectGlow(Rect.fromLTWH(w * 0.36, h * 0.90, w * 0.28, h * 0.08));
    canvas.drawRect(Rect.fromLTWH(w * 0.42, 0, w * 0.16, h * 0.025), line..color = Colors.white.withOpacity(0.3)..strokeWidth = 2);
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.975, w * 0.16, h * 0.025), line);
    canvas.drawCircle(Offset(w * 0.5, h * 0.13), 2.5, Paint()..color = Colors.white.withOpacity(0.5));
    canvas.drawCircle(Offset(w * 0.5, h * 0.87), 2.5, Paint()..color = Colors.white.withOpacity(0.5));
  }

  @override
  bool shouldRepaint(_) => false;
}
