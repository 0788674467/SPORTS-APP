import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth/auth_provider.dart' as auth;
import '../../core/state/match_state.dart';
import '../../shared/pitch_background.dart';
import '../../shared/profile_dropdown.dart';
import '../../shared/officials_chat.dart';

class RefereeDashboard extends StatefulWidget {
  const RefereeDashboard({super.key});
  @override
  State<RefereeDashboard> createState() => _RefereeDashboardState();
}

class _RefereeDashboardState extends State<RefereeDashboard> with TickerProviderStateMixin {
  int _selectedNav = 0;
  int _matchMinute = 0;
  String? _activeFixId;
  Timer? _matchTimer;
  bool _matchRunning = false;
  int _matchDuration = 90;

  // ─ Realtime team branding ───────────────────────────────────────────────
  List<Map<String, dynamic>> _liveTeams = [];
  StreamSubscription<List<Map<String, dynamic>>>? _teamsStreamSub;

  static const _navItems = [
    {'icon': Icons.sports_rounded, 'label': 'Console'},
    {'icon': Icons.calendar_today_rounded, 'label': 'My Fixtures'},
    {'icon': Icons.grid_view_rounded, 'label': 'Lineups'},
    {'icon': Icons.swap_horiz_rounded, 'label': 'Substitutions'},
    {'icon': Icons.receipt_long_rounded, 'label': 'Events'},
    {'icon': Icons.flag_rounded, 'label': 'Report'},
    {'icon': Icons.chat_bubble_rounded, 'label': 'Chat'},
    {'icon': Icons.settings_rounded, 'label': 'Settings'},
  ];

  Color get _accent => const Color(0xFF42A5F5);

  @override
  void initState() {
    super.initState();
    // Fetch user profile to get avatar_url
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ap = context.read<auth.AuthProvider>();
      await ap.fetchProfile();
      debugPrint('🔍 Referee Dashboard: Profile fetched');
      debugPrint('🔍 Avatar URL: ${ap.profile?['avatar_url']}');
      debugPrint('🔍 Full Name: ${ap.profile?['full_name']}');
    });
    // Subscribe to teams table for live name/logo updates
    _teamsStreamSub = Supabase.instance.client
        .from('teams')
        .stream(primaryKey: ['id'])
        .listen((rows) {
      if (mounted) setState(() => _liveTeams = rows);
    });
  }

  @override
  void dispose() {
    _teamsStreamSub?.cancel();
    _matchTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _matchTimer?.cancel();
    _matchRunning = true;
    _matchTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_matchMinute < _matchDuration) { _matchMinute++; }
        else { _matchTimer?.cancel(); _matchRunning = false; }
      });
    });
  }

  void _stopTimer() { _matchTimer?.cancel(); setState(() => _matchRunning = false); }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 840;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      drawer: isMobile ? _buildSidebar(context) : null,
      body: SafeArea(child: Row(children: [
        if (!isMobile) SizedBox(width: 256, child: _buildSidebar(context)),
        Expanded(child: Column(children: [
          _buildHeader(context, isMobile),
          Expanded(child: _buildContent()),
        ])),
      ])),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final ap = context.watch<auth.AuthProvider>();
    final profile = ap.profile;
    final name = profile?['full_name'] ?? ap.user?.userMetadata?['full_name'] ?? 'Referee';
    final avatarUrl = (profile?['avatar_url'] as String?)?.isNotEmpty == true
        ? profile!['avatar_url'] as String
        : ap.user?.userMetadata?['avatar_url'] as String?;
    
    debugPrint('🎨 _buildSidebar: Rebuilding sidebar');
    debugPrint('   - name: $name');
    debugPrint('   - avatarUrl: $avatarUrl');
    
    final ms = context.watch<MatchState>();
    final myFixtures = ms.fixturesForReferee(name);
    final liveCount = myFixtures.where((f) => f.status == 'live').length;
    final pendingSubs = ms.pendingSubstitutions.where((s) => s['status'] == 'pending').length;

    return Drawer(elevation: 0, child: PitchBackground(
      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Row(children: [
          Container(width: 36, height: 36,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
            )),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('UniLeague', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text('REFEREE', style: TextStyle(color: _accent, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700)),
          ]),
        ])),
        const SizedBox(height: 12),
        if (liveCount > 0) Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: Colors.red.shade300, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('$liveCount MATCH LIVE', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
        ),
        Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF003087),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              const Text('Match Referee', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ])),
          ]),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Text('MENU', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w600))),
        Expanded(child: ListView.builder(padding: EdgeInsets.zero, itemCount: _navItems.length, itemBuilder: (_, i) {
          final item = _navItems[i];
          final active = _selectedNav == i;
          final badge = (i == 3 && pendingSubs > 0) ? pendingSubs : 0;
          return GestureDetector(
            onTap: () { setState(() => _selectedNav = i); if (MediaQuery.of(context).size.width < 840) Navigator.pop(context); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF003087).withOpacity(0.22) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: active ? Border.all(color: const Color(0xFF003087).withOpacity(0.35)) : null),
              child: Row(children: [
                Icon(item['icon'] as IconData, size: 17, color: active ? _accent : Colors.white38),
                const SizedBox(width: 10),
                Expanded(child: Text(item['label'] as String,
                  style: TextStyle(color: active ? Colors.white : Colors.white54,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal, fontSize: 13))),
                if (badge > 0) Container(padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9))),
                if (active && badge == 0) Container(width: 4, height: 4, decoration: BoxDecoration(color: _accent, shape: BoxShape.circle)),
              ]),
            ),
          );
        })),
        Padding(padding: const EdgeInsets.all(12), child: OutlinedButton.icon(
          onPressed: () => context.read<auth.AuthProvider>().signOut(),
          icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 16),
          label: const Text('Sign Out', style: TextStyle(color: Colors.white54)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(double.infinity, 42)),
        )),
      ])),
    ));
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    final ap = context.watch<auth.AuthProvider>();
    final profile = ap.profile;
    final name = profile?['full_name'] ?? ap.user?.userMetadata?['full_name'] ?? 'Referee';
    final avatarUrl = (profile?['avatar_url'] as String?)?.isNotEmpty == true
        ? profile!['avatar_url'] as String
        : ap.user?.userMetadata?['avatar_url'] as String?;
    final ms = context.watch<MatchState>();
    final pendingSubs = ms.pendingSubstitutions.where((s) => s['status'] == 'pending').length;
    final f = _activeFixId != null ? ms.generatedFixtures.firstWhere((x) => x.id == _activeFixId, orElse: () => ms.generatedFixtures.first) : null;

    return Container(
      height: 64, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Row(children: [
        if (isMobile) Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(ctx).openDrawer())),
        // Greeting
        if (!isMobile) Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Hello, $name 👋', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (f != null && f.status == 'live')
            Text('${f.homeTeam} ${f.homeScore}–${f.awayScore} ${f.awayTeam}  $_matchMinute\'',
              style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.bold)),
        ]),
        const Spacer(),
        if (f != null && f.status == 'live')
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade200)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: Colors.red.shade400, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('LIVE  $_matchMinute\'', style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
        const SizedBox(width: 10),
        // Notification bell
        Stack(alignment: Alignment.topRight, children: [
          IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () => setState(() => _selectedNav = 3)),
          if (pendingSubs > 0) Positioned(right: 8, top: 8, child: Container(
            width: 14, height: 14,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: Center(child: Text('$pendingSubs', style: const TextStyle(color: Colors.white, fontSize: 8))))),
        ]),
        const SizedBox(width: 8),
        ProfileDropdown(
          name: name, avatarUrl: avatarUrl, avatarIndex: 0,
          accentColor: const Color(0xFF003087),
          onProfile: () => setState(() => _selectedNav = 7),
          onSignOut: () => ap.signOut(),
        ),
        const SizedBox(width: 8),
      ]),
    );
  }

  Widget _buildContent() {
    switch (_selectedNav) {
      case 1: return _buildMyFixtures();
      case 2: return _buildLineupView();
      case 3: return _buildSubstitutions();
      case 4: return _buildEventsLog();
      case 5: return _buildReport();
      case 6: return _buildChatTab();
      case 7: return _buildSettings();
      default: return _buildConsole();
    }
  }

  // ─── Console ────────────────────────────────────────────────────────────────
  Widget _buildConsole() {
    final ms = context.watch<MatchState>();
    GeneratedFixture? f;
    if (_activeFixId != null) try { f = ms.generatedFixtures.firstWhere((x) => x.id == _activeFixId); } catch (_) {}
    f ??= ms.liveFixture;
    if (f == null) return _buildConsoleEmpty(ms);

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      // Scoreboard
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0D0F2A), Color(0xFF1A0835)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: const Color(0xFF003087).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Column(children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.red.shade300, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
              ])),
            const Spacer(),
            // Timer controls
            Row(children: [
              GestureDetector(onTap: _matchRunning ? _stopTimer : _startTimer,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _matchRunning ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Icon(_matchRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: _matchRunning ? Colors.red : Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text('$_matchMinute\'', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ]))),
            ]),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _scoreTeam(f!.homeTeam, f.homeScore),
            Column(children: [const Text('—', style: TextStyle(color: Colors.white24, fontSize: 24)),
              Text(f.venue, style: const TextStyle(color: Colors.white30, fontSize: 9))]),
            _scoreTeam(f.awayTeam, f.awayScore),
          ]),
          const SizedBox(height: 14),
          // Match duration + set time
          Row(children: [
            const Icon(Icons.timer_rounded, color: Colors.white38, size: 15),
            const SizedBox(width: 6),
            Text('Match duration: $_matchDuration min', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const Spacer(),
            TextButton(onPressed: () => _showDurationDialog(ms), child: Text('Edit', style: TextStyle(color: _accent, fontSize: 11))),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      // Event buttons
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5,
        children: [
          _eventBtn('⚽ GOAL', const Color(0xFF00A651), () => _promptEvent(EventType.goal, f!)),
          _eventBtn('🅰️ ASSIST', const Color(0xFF003087), () => _promptEvent(EventType.assist, f!)),
          _eventBtn('🟡 YELLOW', const Color(0xFFF9A825), () => _promptEvent(EventType.yellow, f!)),
          _eventBtn('🔴 RED CARD', const Color(0xFFC62828), () => _promptEvent(EventType.red, f!)),
          _eventBtn('↩ CORNER', const Color(0xFF003087), () => _promptEvent(EventType.corner, f!)),
          _eventBtn('🎯 SHOT', const Color(0xFF00695C), () => _promptEvent(EventType.shot, f!)),
          _eventBtn('⚠️ PENALTY', const Color(0xFFF5A500), () => _promptEvent(EventType.penalty, f!)),
          _eventBtn('🏆 PKS', const Color(0xFF37474F), () => _showPenaltyShootout(f!)),
          _eventBtn('⏹ END', const Color(0xFF263238), () { ms.endMatch(f!.id); setState(() { _activeFixId = null; _matchMinute = 0; _matchRunning = false; _matchTimer?.cancel(); }); }),
        ]),
    ]));
  }

  Widget _buildConsoleEmpty(MatchState ms) {
    final ap = context.watch<auth.AuthProvider>();
    final name = ap.profile?['full_name'] ?? ap.user?.userMetadata?['full_name'] ?? 'Referee';
    final myFixtures = ms.fixturesForReferee(name);
    final upcomingCount = myFixtures.where((f) => f.status == 'scheduled').length;
    final completedCount = myFixtures.where((f) => f.status == 'completed').length;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D0F2A), Color(0xFF1A0835)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF003087).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sports_rounded, size: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, $name! 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ready to officiate some great matches?',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _refStatCard(
                        'Upcoming',
                        upcomingCount.toString(),
                        Icons.schedule_rounded,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _refStatCard(
                        'Completed',
                        completedCount.toString(),
                        Icons.check_circle_rounded,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _refStatCard(
                        'Total',
                        myFixtures.length.toString(),
                        Icons.sports_soccer_rounded,
                        _accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _quickActionCard(
                'My Fixtures',
                'View assigned matches',
                Icons.calendar_today_rounded,
                Colors.blue,
                () => setState(() => _selectedNav = 1),
              ),
              _quickActionCard(
                'Lineups',
                'Check team formations',
                Icons.grid_view_rounded,
                Colors.green,
                () => setState(() => _selectedNav = 2),
              ),
              _quickActionCard(
                'Substitutions',
                'Manage player changes',
                Icons.swap_horiz_rounded,
                Colors.orange,
                () => setState(() => _selectedNav = 3),
              ),
              _quickActionCard(
                'Match Report',
                'Generate reports',
                Icons.flag_rounded,
                Colors.purple,
                () => setState(() => _selectedNav = 5),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_rounded, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'How to Start a Match',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Go to "My Fixtures" to see your assigned matches\n'
                  '2. Click "Kick Off Match" when teams are ready\n'
                  '3. Use the console to record events during the match\n'
                  '4. Submit your match report when finished',
                  style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _refStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the logo_url for [teamName] from the live Supabase stream, or null.
  String? _teamLogoFor(String teamName) {
    try {
      return _liveTeams.firstWhere(
        (t) => (t['name'] as String?)?.toLowerCase() == teamName.toLowerCase(),
      )['logo_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  Widget _scoreTeam(String name, int score) {
    final logoUrl = _teamLogoFor(name);
    return Column(children: [
      if (logoUrl != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(logoUrl, width: 36, height: 36, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        )
      else
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      const SizedBox(height: 4),
      Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Text('$score', style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900)),
    ]);
  }

  Widget _eventBtn(String label, Color color, VoidCallback onTap) {
    return Material(color: color, borderRadius: BorderRadius.circular(14),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
        child: Center(child: Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, height: 1.3)))));
  }

  void _showDurationDialog(MatchState ms) {
    final ctrl = TextEditingController(text: '$_matchDuration');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Set Match Duration'),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Minutes', suffixText: 'min')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          final m = int.tryParse(ctrl.text) ?? 90;
          setState(() => _matchDuration = m);
          ms.setMatchDuration(m);
          Navigator.pop(ctx);
        }, child: const Text('Set')),
      ],
    ));
  }

  // ─── My Fixtures ────────────────────────────────────────────────────────────
  Widget _buildMyFixtures() {
    final ap = context.read<auth.AuthProvider>();
    final name = ap.user?.userMetadata?['full_name'] ?? 'Referee';
    final ms = context.watch<MatchState>();
    final myFixtures = ms.fixturesForReferee(name);

    if (myFixtures.isEmpty) return _empty(Icons.calendar_today_rounded, 'No assigned fixtures', 'Admin will assign fixtures to you.');

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
      children: myFixtures.map((f) {
        final dt = f.dateTime;
        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            border: Border.all(color: f.status == 'live' ? Colors.red.shade300 : Colors.transparent)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _statusBadge(f.status), const Spacer(),
              Text('${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Expanded(child: Text(f.homeTeam, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF0A1628), borderRadius: BorderRadius.circular(6)),
                child: const Text('vs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text(f.awayTeam, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey), const SizedBox(width: 4),
              Text(f.venue, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Spacer(),
              if (!f.venueConfirmed)
                TextButton.icon(onPressed: () => ms.confirmVenue(f.id),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                  label: const Text('Confirm Venue', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF003087)))
              else const Row(children: [Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF00A651)), SizedBox(width: 4), Text('Confirmed', style: TextStyle(fontSize: 12, color: Color(0xFF00A651)))]),
            ]),
            if (f.status == 'scheduled')
              Padding(padding: const EdgeInsets.only(top: 10), child: SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () { setState(() { _activeFixId = f.id; _selectedNav = 0; ms.setLiveFixture(f.id); _matchMinute = 0; _startTimer(); }); },
                  icon: const Icon(Icons.play_circle_rounded, size: 18),
                  label: const Text('Kick Off Match'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A651), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))))),
          ]),
        );
      }).toList()));
  }

  Widget _statusBadge(String status) {
    final configs = {'live': (Colors.red.shade600, Colors.red.shade50), 'completed': (Colors.green.shade600, Colors.green.shade50), 'scheduled': (Colors.blue.shade600, Colors.blue.shade50), 'postponed': (Colors.orange.shade600, Colors.orange.shade50)};
    final c = configs[status] ?? (Colors.grey, Colors.grey.shade50);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.$2, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: c.$1, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  // ─── Lineup View ─────────────────────────────────────────────────────────
  Widget _buildLineupView() {
    final ms = context.watch<MatchState>();
    
    // Auto-load lineups if not already loaded
    if (_activeFixId != null && !ms.lineups.containsKey(_activeFixId)) {
      ms.loadLineupsForFixture(_activeFixId!);
    }
    
    if (_activeFixId == null || !ms.lineups.containsKey(_activeFixId)) {
      return _empty(Icons.grid_view_rounded, 'No Lineup Yet', 'Coach has not submitted a lineup yet.');
    }
    final players = ms.lineups[_activeFixId]!;
    final starters = players.where((p) => !p.isSubstituted).toList();
    final bench = players.where((p) => p.isSubstituted).toList();

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Starting XI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      ...starters.map((p) => GestureDetector(
        onTap: () => _showCardAssignDialog(p),
        child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.hasRed ? Colors.red.shade50 : (p.hasYellow ? Colors.amber.shade50 : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.hasRed ? Colors.red.shade200 : (p.hasYellow ? Colors.amber.shade200 : Colors.grey.shade100))),
          child: Row(children: [
            _playerAvatar(p, radius: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Row(children: [
                Text('#${p.jerseyNo}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFF003087), borderRadius: BorderRadius.circular(4)),
                  child: Text(p.position, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ]),
            ])),
            if (p.hasYellow) const Padding(padding: EdgeInsets.only(left: 6), child: Text('🟡', style: TextStyle(fontSize: 14))),
            if (p.hasRed) const Padding(padding: EdgeInsets.only(left: 6), child: Text('🔴', style: TextStyle(fontSize: 14))),
            const SizedBox(width: 4),
            Icon(Icons.touch_app_rounded, size: 14, color: Colors.grey.shade400),
          ])),
      )),
      if (bench.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('Bench / Substituted', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...bench.map((p) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            _playerAvatar(p, radius: 16),
            const SizedBox(width: 10),
            Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4)),
              child: Text(p.position, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
            const Padding(padding: EdgeInsets.only(left: 4), child: Text('↔️', style: TextStyle(fontSize: 12))),
          ]))),
      ],
      const SizedBox(height: 12),
      Text('Tap a player to assign a card', style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
    ]));
  }

  Widget _playerAvatar(LineupPlayer p, {double radius = 20}) {
    final url = p.photoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        child: null);
    }
    return CircleAvatar(radius: radius, backgroundColor: const Color(0xFF003087).withOpacity(0.1),
      child: Text('${p.jerseyNo}', style: TextStyle(fontSize: radius * 0.6, fontWeight: FontWeight.bold, color: const Color(0xFF003087))));
  }



  void _showCardAssignDialog(LineupPlayer p) {
    if (_activeFixId == null) return;
    final ms = context.read<MatchState>();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Discipline — ${p.name}'),
      content: const Text('Assign a card to this player?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: () { ms.recordCard(fixtureId: _activeFixId!, team: p.team, player: p.name, minute: _matchMinute, isRed: false); Navigator.pop(ctx); },
          icon: const Text('🟡'), label: const Text('Yellow Card'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF9A825), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
        ElevatedButton.icon(
          onPressed: () { ms.recordCard(fixtureId: _activeFixId!, team: p.team, player: p.name, minute: _matchMinute, isRed: true); Navigator.pop(ctx); },
          icon: const Text('🔴'), label: const Text('Red Card'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      ],
    ));
  }

  // ─── Substitutions ──────────────────────────────────────────────────────────
  Widget _buildSubstitutions() {
    final ms = context.watch<MatchState>();
    final subs = ms.pendingSubstitutions;
    if (subs.isEmpty) return _empty(Icons.swap_horiz_rounded, 'No Substitution Requests', 'Coach will send substitution requests here.');

    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: subs.length, itemBuilder: (_, i) {
      final sub = subs[i];
      final isPending = sub['status'] == 'pending';
      return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isPending ? Colors.orange.shade200 : Colors.green.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: isPending ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text(isPending ? 'PENDING' : 'APPROVED',
                style: TextStyle(color: isPending ? Colors.orange.shade700 : Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold))),
            const Spacer(),
            Text(sub['team'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('OUT', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
              Text(sub['playerOut'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            ])),
            const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('IN', style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
              Text(sub['playerIn'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            ])),
          ]),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () { setState(() => subs[i]['status'] = 'rejected'); },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Reject'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: () => ms.approveSubstitution(i, _matchMinute),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A651), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Approve'))),
            ]),
          ],
        ]),
      );
    });
  }

  // ─── Events Log ─────────────────────────────────────────────────────────────
  Widget _buildEventsLog() {
    final ms = context.watch<MatchState>();
    GeneratedFixture? f;
    if (_activeFixId != null) try { f = ms.generatedFixtures.firstWhere((x) => x.id == _activeFixId); } catch (_) {}
    final events = f?.events ?? [];
    if (events.isEmpty) return _empty(Icons.receipt_long_outlined, 'No Events', 'Record events during a live match.');

    return ListView.separated(padding: const EdgeInsets.all(16), itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final e = events[i];
        return Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
          child: Row(children: [
            Text(_eventEmoji(e.type), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e.playerName.isEmpty ? e.team : e.playerName}  ${e.detail ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(e.team, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
            Text("${e.minute}'", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
          ]));
      });
  }

  String _eventEmoji(String type) {
    const m = {'goal':'⚽','yellow':'🟡','red':'🔴','assist':'🅰️','corner':'↩','shot':'🎯','penalty':'⚠️','sub':'↔️'};
    return m[type] ?? '📋';
  }

  // ─── Report ─────────────────────────────────────────────────────────────────
  Widget _buildReport() {
    final ms = context.watch<MatchState>();
    GeneratedFixture? f;
    if (_activeFixId != null) try { f = ms.generatedFixtures.firstWhere((x) => x.id == _activeFixId); } catch (_) {}
    final events = f?.events ?? [];
    final ap = context.read<auth.AuthProvider>();
    final refName = ap.user?.userMetadata?['full_name'] ?? 'Referee';

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // University header
        Center(child: Column(children: [
          const Text('MMU UNIVERSITY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
          Text('Department of Sports • Season 2026', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          const SizedBox(height: 4),
          Container(height: 2, width: 120, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF003087), Color(0xFF42A5F5)]))),
        ])),
        const SizedBox(height: 16),
        const Text('OFFICIAL MATCH REPORT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text('Referee: $refName', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 16),
        if (f != null) ...[
          _rRow('Match', '${f.homeTeam} vs ${f.awayTeam}'),
          _rRow('Final Score', '${f.homeScore} – ${f.awayScore}'),
          _rRow('Venue', f.venue),
          _rRow('Duration', '$_matchDuration minutes'),
          _rRow('Total Events', '${events.length}'),
          _rRow('Goals', '${events.where((e) => e.type == 'goal').length}'),
          _rRow('Yellow Cards', '${events.where((e) => e.type == 'yellow').length}'),
          _rRow('Red Cards', '${events.where((e) => e.type == 'red').length}'),
          _rRow('Corners', '${events.where((e) => e.type == 'corner').length}'),
          _rRow('Penalties', '${events.where((e) => e.type == 'penalty').length}'),
          _rRow('Substitutions', '${events.where((e) => e.type == 'sub').length}'),
          if (events.where((e) => e.type == 'goal').isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Goal Scorers', style: TextStyle(fontWeight: FontWeight.bold)),
            ...events.where((e) => e.type == 'goal').map((e) => Padding(padding: const EdgeInsets.only(top: 4),
              child: Text('• ${e.playerName} (${e.team}) ${e.minute}\'', style: const TextStyle(fontSize: 12)))),
          ],
        ] else const Text('No match selected. Start a match from My Fixtures.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: f == null ? null : () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Report submitted to Admin!'), backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16))),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Submit to Admin'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003087), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
      ]),
    ));
  }

  Widget _rRow(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
    Expanded(child: Text(k, style: TextStyle(color: Colors.grey.shade600))),
    Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
  ]));

  // ─── Penalty Shootout ────────────────────────────────────────────────────────
  void _showPenaltyShootout(GeneratedFixture f) {
    int homeScore = 0, awayScore = 0;
    final homeHistory = <bool>[], awayHistory = <bool>[];
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('⚠️ Penalty Shootout'),
      content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${f.homeTeam}  $homeScore – $awayScore  ${f.awayTeam}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(f.homeTeam, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 4, children: homeHistory.map((s) => Text(s ? '⚽' : '❌', style: const TextStyle(fontSize: 16))).toList()),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(onPressed: () => setS(() { homeHistory.add(true); homeScore++; }),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                child: const Text('⚽ Score', style: TextStyle(fontSize: 11))),
              const SizedBox(width: 4),
              ElevatedButton(onPressed: () => setS(() => homeHistory.add(false)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                child: const Text('❌ Miss', style: TextStyle(fontSize: 11))),
            ])
          ])),
          const SizedBox(width: 8),
          Container(width: 1, height: 80, color: Colors.grey.shade200),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(f.awayTeam, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 4, children: awayHistory.map((s) => Text(s ? '⚽' : '❌', style: const TextStyle(fontSize: 16))).toList()),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(onPressed: () => setS(() { awayHistory.add(true); awayScore++; }),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                child: const Text('⚽ Score', style: TextStyle(fontSize: 11))),
              const SizedBox(width: 4),
              ElevatedButton(onPressed: () => setS(() => awayHistory.add(false)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                child: const Text('❌ Miss', style: TextStyle(fontSize: 11))),
            ])
          ])),
        ]),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ElevatedButton(onPressed: () {
          final winner = homeScore > awayScore ? f.homeTeam : (awayScore > homeScore ? f.awayTeam : 'Draw');
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PKS Result: $winner wins! $homeScore–$awayScore'),
            backgroundColor: Colors.indigo, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16)));
        }, child: const Text('Confirm Result')),
      ],
    )));
  }

  // ─── Officials Communication Center ─────────────────────────────────────────
  Widget _buildChatTab() {
    return const OfficialsChatWidget();
  }

  // ─── Settings ───────────────────────────────────────────────────────────────
  final _sNameCtrl = TextEditingController();
  final _sPhoneCtrl = TextEditingController();
  final _sPassCtrl = TextEditingController();
  final _sConfirmCtrl = TextEditingController();
  bool _sLoading = false;
  Uint8List? _selectedProfileImage;
  bool _isUploadingProfile = false;

  Widget _buildSettings() {
    final ap = context.watch<auth.AuthProvider>();
    final profile = ap.profile;
    final avatarUrl = (profile?['avatar_url'] as String?)?.isNotEmpty == true
        ? profile!['avatar_url'] as String
        : ap.user?.userMetadata?['avatar_url'] as String?;
    final fullName = profile?['full_name'] ?? ap.user?.userMetadata?['full_name'] ?? 'Referee';
    
    if (_sNameCtrl.text.isEmpty) {
      _sNameCtrl.text = fullName;
      _sPhoneCtrl.text = profile?['phone'] ?? ap.user?.userMetadata?['phone'] ?? '';
    }
    
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      // Profile Picture Section
      _settingsCard('Profile Picture', Icons.photo_camera_rounded, const Color(0xFF003087), Column(children: [
        // Show alert if no photo
        if (avatarUrl == null || avatarUrl.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No profile picture uploaded. Tap below to add one!',
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                ),
              ),
            ]),
          ),
        Center(
          child: Stack(children: [
            GestureDetector(
              onTap: _showProfileImagePicker,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF003087).withOpacity(0.2), width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)],
                ),
                child: CircleAvatar(
                  radius: 47,
                  backgroundColor: const Color(0xFF003087),
                  backgroundImage: _selectedProfileImage != null 
                      ? MemoryImage(_selectedProfileImage!) as ImageProvider<Object>
                      : (avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) as ImageProvider<Object> : null),
                  child: (_selectedProfileImage == null && (avatarUrl == null || avatarUrl.isEmpty))
                      ? Text(fullName[0].toUpperCase(), 
                            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold))
                      : null,
                ),
              ),
            ),
            Positioned(
              bottom: 0, right: 0,
              child: GestureDetector(
                onTap: _showProfileImagePicker,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003087),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                  ),
                  child: _isUploadingProfile
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(
          avatarUrl == null || avatarUrl.isEmpty ? 'Tap to upload photo' : 'Tap to change photo',
          style: TextStyle(
            color: avatarUrl == null || avatarUrl.isEmpty ? Colors.orange.shade700 : Colors.grey,
            fontSize: 12,
            fontWeight: avatarUrl == null || avatarUrl.isEmpty ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        if (avatarUrl == null || avatarUrl.isEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showProfileImagePicker,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Upload Profile Picture'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ])),
      const SizedBox(height: 16),
      _settingsCard('Profile Settings', Icons.person_rounded, const Color(0xFF003087), Column(children: [
        _sField('Full Name', _sNameCtrl, Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _sField('Phone', _sPhoneCtrl, Icons.phone_rounded, keyboard: TextInputType.phone),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _sLoading ? null : () async {
            setState(() => _sLoading = true);
            final err = await ap.updateProfile(fullName: _sNameCtrl.text.trim(), phone: _sPhoneCtrl.text.trim());
            setState(() => _sLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err == null ? 'Profile saved!' : 'Error: $err'),
              backgroundColor: err == null ? Colors.green : Colors.red, behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16)));
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003087), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
          child: _sLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Profile'),
        )),
      ])),
      const SizedBox(height: 16),
      _settingsCard('Change Password', Icons.lock_rounded, Colors.purple, Column(children: [
        _sField('New Password', _sPassCtrl, Icons.lock_outline_rounded, obscure: true),
        const SizedBox(height: 12),
        _sField('Confirm Password', _sConfirmCtrl, Icons.lock_outline_rounded, obscure: true),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () async {
            if (_sPassCtrl.text != _sConfirmCtrl.text) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Passwords do not match!'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16))); return; }
            final err = await ap.updatePassword(_sPassCtrl.text);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err == null ? 'Password changed!' : 'Error: $err'), backgroundColor: err == null ? Colors.green : Colors.red, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16)));
            if (err == null) { _sPassCtrl.clear(); _sConfirmCtrl.clear(); }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Update Password'),
        )),
      ])),
    ]));
  }

  Widget _settingsCard(String title, IconData icon, Color color, Widget child) => Container(
    padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 2),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
      const Divider(height: 24), child,
    ]));

  TextField _sField(String label, TextEditingController ctrl, IconData icon, {TextInputType keyboard = TextInputType.text, bool obscure = false}) =>
    TextField(controller: ctrl, keyboardType: keyboard, obscureText: obscure, decoration: InputDecoration(
      labelText: label, prefixIcon: Icon(icon, size: 18), filled: true, fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF003087))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)));

  void _showProfileImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Update Profile Picture', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _imagePickerOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () => _pickProfileImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _imagePickerOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () => _pickProfileImage(ImageSource.gallery),
                ),
              ),
            ]),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _imagePickerOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, size: 32, color: const Color(0xFF003087)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      Navigator.pop(context); // Close bottom sheet
      
      debugPrint('📸 Starting image picker...');
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source, 
        maxWidth: 512, 
        maxHeight: 512, 
        imageQuality: 85
      );
      
      if (image == null) {
        debugPrint('❌ No image selected');
        return;
      }
      
      debugPrint('✅ Image selected: ${image.path}');
      final bytes = await image.readAsBytes();
      debugPrint('✅ Image bytes read: ${bytes.length} bytes');
      
      setState(() {
        _selectedProfileImage = bytes;
        _isUploadingProfile = true;
      });
      
      // Upload to Supabase
      debugPrint('📤 Uploading to Supabase...');
      final ap = context.read<auth.AuthProvider>();
      final error = await ap.uploadAvatar(image);
      
      debugPrint('📥 Upload response: ${error ?? "SUCCESS"}');
      
      setState(() => _isUploadingProfile = false);
      
      if (error == null) {
        debugPrint('✅ Profile picture uploaded successfully!');
        
        // Refresh profile to get new avatar URL
        await ap.fetchProfile();
        debugPrint('✅ Profile refreshed. New avatar URL: ${ap.profile?['avatar_url']}');
        
        // Force rebuild of the entire widget tree
        if (mounted) {
          setState(() {
            _selectedProfileImage = null;
          });
        }
        
        // Show success message using a simple dialog instead of SnackBar
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                  const SizedBox(height: 16),
                  const Text('Success!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Profile picture updated successfully!'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        debugPrint('❌ Upload error: $error');
        setState(() => _selectedProfileImage = null);
        
        // Show error message
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_rounded, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text('Error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Failed to upload: $error'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Exception in _pickProfileImage: $e');
      setState(() {
        _isUploadingProfile = false;
        _selectedProfileImage = null;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_rounded, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Unexpected error: $e'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _promptEvent(EventType type, GeneratedFixture f) {
    final ms = context.read<MatchState>();
    final playerCtrl = TextEditingController(), assistCtrl = TextEditingController();
    String selectedTeam = f.homeTeam;
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(_eventTitle(type)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (type != EventType.corner) ...[TextField(controller: playerCtrl, decoration: InputDecoration(labelText: 'Player Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 10)],
        if (type == EventType.goal || type == EventType.sub) ...[TextField(controller: assistCtrl, decoration: InputDecoration(labelText: type == EventType.goal ? 'Assisted By (optional)' : 'Player In', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 10)],
        DropdownButtonFormField<String>(value: selectedTeam,
          items: [f.homeTeam, f.awayTeam].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setS(() => selectedTeam = v!),
          decoration: InputDecoration(labelText: 'Team', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003087), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            final p = playerCtrl.text.trim().isEmpty ? 'Unknown' : playerCtrl.text.trim();
            switch (type) {
              case EventType.goal: ms.recordGoal(fixtureId: f.id, team: selectedTeam, player: p, minute: _matchMinute, assistBy: assistCtrl.text.trim().isEmpty ? null : assistCtrl.text.trim()); break;
              case EventType.assist: ms.recordAssist(fixtureId: f.id, team: selectedTeam, player: p, minute: _matchMinute); break;
              case EventType.yellow: ms.recordCard(fixtureId: f.id, team: selectedTeam, player: p, minute: _matchMinute, isRed: false); break;
              case EventType.red: ms.recordCard(fixtureId: f.id, team: selectedTeam, player: p, minute: _matchMinute, isRed: true); break;
              case EventType.corner: ms.recordCorner(fixtureId: f.id, team: selectedTeam, minute: _matchMinute); break;
              case EventType.shot: ms.recordShot(fixtureId: f.id, team: selectedTeam, player: p, minute: _matchMinute); break;
              case EventType.penalty: ms.recordPenalty(fixtureId: f.id, team: selectedTeam, player: p, minute: _matchMinute, scored: true); break;
              case EventType.sub: ms.recordSubstitution(fixtureId: f.id, team: selectedTeam, playerOut: p, playerIn: assistCtrl.text.trim().isEmpty ? 'Sub' : assistCtrl.text.trim(), minute: _matchMinute); break;
            }
            Navigator.pop(ctx);
          }, child: const Text('Record')),
      ])));
  }

  String _eventTitle(EventType t) {
    const m = {EventType.goal:'⚽ Record Goal', EventType.assist:'🅰️ Record Assist', EventType.yellow:'🟡 Yellow Card', EventType.red:'🔴 Red Card', EventType.corner:'↩ Corner', EventType.shot:'🎯 Shot on Target', EventType.penalty:'⚠️ Penalty', EventType.sub:'↔️ Substitution'};
    return m[t]!;
  }

  Widget _empty(IconData icon, String title, String sub) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 52, color: Colors.grey.shade300), const SizedBox(height: 12),
    Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade400)), const SizedBox(height: 4),
    Text(sub, style: TextStyle(color: Colors.grey.shade400, fontSize: 12), textAlign: TextAlign.center),
  ]));
}

enum EventType { goal, assist, yellow, red, corner, shot, penalty, sub }
