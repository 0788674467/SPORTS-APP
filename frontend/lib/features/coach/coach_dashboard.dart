import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart' as auth;
import '../../core/state/match_state.dart';
import '../../shared/pitch_background.dart';
import '../../shared/profile_dropdown.dart';
import 'lineup_builder.dart';
import 'substitution_request.dart';

// ─── Coach Dashboard (Full Overhaul) ─────────────────────────────────────────
class CoachDashboard extends StatefulWidget {
  const CoachDashboard({super.key});
  @override
  State<CoachDashboard> createState() => _CoachDashboardState();
}

class _CoachDashboardState extends State<CoachDashboard> with TickerProviderStateMixin {
  int _selectedNav = 0;
  bool _darkMode = true;
  TabController? _squadTabController;

  final _client = Supabase.instance.client;
  String? _teamId;
  String? _teamLogoUrl;
  XFile? _pendingTeamLogo;
  Uint8List? _pendingTeamLogoBytes;
  bool _isSquadLoading = false;
  bool _isSubmitting = false;
  String _submissionStatus = 'draft'; // draft | submitted | approved | rejected
  String? _rejectionNote;
  final List<Map<String, dynamic>> _squad = [];

  // Settings Controllers
  final _settingsNameCtrl = TextEditingController();
  final _settingsPhoneCtrl = TextEditingController();
  final _settingsTeamNameCtrl = TextEditingController();
  final _settingsPasswordCtrl = TextEditingController();
  final _settingsConfirmCtrl = TextEditingController();
  bool _settingsLoading = false;
  bool _settingsProfileLoading = false;
  bool _settingsPasswordLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  Uint8List? _pendingAvatarBytes;
  bool _profileInitialized = false;

  @override
  void initState() {
    super.initState();
    _squadTabController = TabController(length: 2, vsync: this);
    _loadSquad();
    // Fetch profile immediately so avatar_url shows in sidebar/header
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ap = context.read<auth.AuthProvider>();
      await ap.fetchProfile();
    });
  }

  Future<void> _loadSquad() async {
    setState(() => _isSquadLoading = true);
    try {
      final coachId = _client.auth.currentUser?.id;
      if (coachId == null) return;

      // 1. Get/Confirm Team
      final teamRes = await _client.from('teams').select().eq('coach_id', coachId).maybeSingle();
      if (teamRes != null) {
        _teamId = teamRes['id'];
        _teamLogoUrl = teamRes['logo_url'];
        _settingsTeamNameCtrl.text = teamRes['name'] ?? '';
        // Load submission status
        setState(() {
          _submissionStatus = teamRes['submission_status'] ?? 'draft';
          _rejectionNote = teamRes['rejection_note'];
        });
      }

      // 2. Load Players
      if (_teamId != null) {
        final playersRes = await _client.from('players').select().eq('team_id', _teamId!).order('created_at');
        setState(() {
          _squad.clear();
          for (var p in playersRes) {
            _squad.add({
              'id': p['id'],
              'name': p['full_name'],
              'regNo': p['reg_no'],
              'uniId': p['university_id'],
              'course': p['course'],
              'year': p['year_of_study'],
              'num': p['jersey_number'].toString(),
              'pos': p['position'],
              'photoUrl': p['photo_url'],
            });
          }
        });
      }

      // 3. Pre-fill coach profile from Supabase profile table
      if (!_profileInitialized) {
        final profileRes = await _client
            .from('profiles')
            .select()
            .eq('id', coachId)
            .maybeSingle();
        if (profileRes != null && mounted) {
          setState(() {
            _settingsNameCtrl.text = profileRes['full_name'] ?? '';
            _settingsPhoneCtrl.text = profileRes['phone'] ?? '';
            _profileInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading squad: $e');
    } finally {
      setState(() => _isSquadLoading = false);
    }
  }

  @override
  void dispose() {
    _squadTabController?.dispose();
    super.dispose();
  }

  static const _navItems = [
    {'icon': Icons.dashboard_rounded, 'label': 'Overview'},
    {'icon': Icons.calendar_today_rounded, 'label': 'My Matches'},
    {'icon': Icons.sports_soccer_rounded, 'label': 'Lineup'},
    {'icon': Icons.swap_horiz_rounded, 'label': 'Substitutions'},
    {'icon': Icons.group_rounded, 'label': 'Squad'},
    {'icon': Icons.chat_bubble_rounded, 'label': 'Chat'},
    {'icon': Icons.settings_rounded, 'label': 'Settings'},
  ];

  Color get _accent => const Color(0xFF00A651);
  Color get _dark => const Color(0xFF0A1628);
  Color get _bgColor => _darkMode ? const Color(0xFFF0F2F8) : Colors.white;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 840;
    return Scaffold(
      backgroundColor: _bgColor,
      drawer: isMobile ? _buildSidebar(context) : null,
      body: SafeArea(child: Row(children: [
        if (!isMobile) SizedBox(width: 252, child: _buildSidebar(context)),
        Expanded(child: Column(children: [
          _buildHeader(context, isMobile),
          Expanded(child: _buildContent()),
        ])),
      ])),
    );
  }

  // ─── Sidebar ────────────────────────────────────────────────────────────────
  Widget _buildSidebar(BuildContext context) {
    final ap = context.watch<auth.AuthProvider>();
    final profile = ap.profile;
    final name = profile?['full_name'] ?? ap.user?.userMetadata?['full_name'] ?? 'Coach';
    final teamName = profile?['team_name'] ?? ap.user?.userMetadata?['team_name'] ?? 'My Team';
    // Check profile table first, fall back to signup user_metadata
    final avatarUrl = (profile?['avatar_url'] as String?)?.isNotEmpty == true
        ? profile!['avatar_url'] as String
        : ap.user?.userMetadata?['avatar_url'] as String?;
    final avatarIndex = 0; // unused — kept for _buildAvatarWidget signature

    return Drawer(elevation: 0, child: PitchBackground(
      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
            )),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('UniLeague', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text('COACH PORTAL', style: TextStyle(color: _accent, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700)),
          ]),
        ])),
        const SizedBox(height: 12),
        // Profile card
        Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: Row(children: [
            _buildAvatarWidget(avatarUrl, avatarIndex, name, 22),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              Text(teamName, style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w500)),
            ])),
            GestureDetector(
              onTap: () { setState(() => _selectedNav = 6); if (MediaQuery.of(context).size.width < 840) Navigator.pop(context); },
              child: Icon(Icons.edit_rounded, color: Colors.white.withOpacity(0.3), size: 14),
            ),
          ]),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Text('MENU', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w600))),
        Expanded(child: ListView.builder(padding: EdgeInsets.zero, itemCount: _navItems.length, itemBuilder: (_, i) {
          final item = _navItems[i];
          final active = _selectedNav == i;
          return GestureDetector(
            onTap: () { setState(() => _selectedNav = i); if (MediaQuery.of(context).size.width < 840) Navigator.pop(context); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: active ? _accent.withOpacity(0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: active ? Border.all(color: _accent.withOpacity(0.35)) : null,
              ),
              child: Row(children: [
                Icon(item['icon'] as IconData, size: 17, color: active ? _accent : Colors.white38),
                const SizedBox(width: 10),
                Expanded(child: Text(item['label'] as String,
                  style: TextStyle(color: active ? Colors.white : Colors.white54,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal, fontSize: 13))),
                if (active) Container(width: 4, height: 4, decoration: BoxDecoration(color: _accent, shape: BoxShape.circle)),
              ]),
            ),
          );
        })),
        Padding(padding: const EdgeInsets.all(12), child: OutlinedButton.icon(
          onPressed: () => ap.signOut(),
          icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 16),
          label: const Text('Sign Out', style: TextStyle(color: Colors.white54)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(double.infinity, 42)),
        )),
      ])),
    ));
  }

  Widget _buildAvatarWidget(String? url, int index, String name, double radius) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    // Fallback: show first initial
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF00A651).withOpacity(0.3),
      child: Text(initial, style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isMobile) {
    final ap = context.watch<auth.AuthProvider>();
    final profile = ap.profile;
    final name = profile?['full_name'] ?? ap.user?.userMetadata?['full_name'] ?? 'Coach';
    // Same dual-source lookup as sidebar
    final avatarUrl = (profile?['avatar_url'] as String?)?.isNotEmpty == true
        ? profile!['avatar_url'] as String
        : ap.user?.userMetadata?['avatar_url'] as String?;
    final avatarIndex = 0;
    final labels = _navItems.map((e) => e['label'] as String).toList();

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(children: [
        if (isMobile) 
          Builder(
            builder: (ctx) => SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: const Icon(Icons.menu_rounded, size: 24),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        if (!isMobile) 
          Expanded(
            child: Text(
              labels[_selectedNav],
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (isMobile) const Spacer(),
        // Notification icon
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.grey, size: 22),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        ProfileDropdown(
          name: name,
          avatarUrl: avatarUrl,
          avatarIndex: avatarIndex,
          accentColor: const Color(0xFF00A651),
          onProfile: () => setState(() => _selectedNav = 6),
          onSignOut: () => ap.signOut(),
        ),
      ]),
    );
  }

  // ─── Content Router ──────────────────────────────────────────────────────────
  Widget _buildContent() {
    switch (_selectedNav) {
      case 1: return _buildMyMatches();
      case 2: return LineupBuilder(darkMode: _darkMode, squad: _squad);
      case 3: return const SubstitutionRequest();
      case 4: return _buildSquad();
      case 5: return _buildChatPlaceholder();
      case 6: return _buildSettings();
      default: return _buildOverview();
    }
  }

  // ─── Overview ─────────────────────────────────────────────────────────────
  Widget _buildOverview() {
    final ap = context.watch<auth.AuthProvider>();
    final profile = ap.profile;
    final name = profile?['full_name'] ?? ap.user?.userMetadata?['full_name'] ?? 'Coach';
    final teamName = profile?['team_name'] ?? ap.user?.userMetadata?['team_name'] ?? 'My Team';
    // Dual-source avatar lookup (profile table OR signup user_metadata)
    final avatarUrl = (profile?['avatar_url'] as String?)?.isNotEmpty == true
        ? profile!['avatar_url'] as String
        : ap.user?.userMetadata?['avatar_url'] as String?;
    final ms = context.watch<MatchState>();
    final myFixtures = ms.fixturesForTeam(teamName);
    final nextMatch = myFixtures.where((f) => f.status == 'scheduled').isNotEmpty
        ? myFixtures.where((f) => f.status == 'scheduled').first : null;
    final completedMatches = myFixtures.where((f) => f.status == 'completed').toList();
    final seasonWins = completedMatches.where((f) =>
      (f.homeTeam == teamName && f.homeScore > f.awayScore) ||
      (f.awayTeam == teamName && f.awayScore > f.homeScore)).length;
    final squadSize = _squad.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Welcome banner ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF00A651), Color(0xFF2E7D32)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFF00A651).withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            // ── Coach photo ────────────────────────────
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2.5),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                onBackgroundImageError: avatarUrl != null ? (_, __) {} : null,
                child: avatarUrl == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'C',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome, $name 👋', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 3),
              Text(teamName, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              if (nextMatch != null) ...[
                const SizedBox(height: 10),
                Text('NEXT: ${nextMatch.homeTeam} vs ${nextMatch.awayTeam}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                Text('${nextMatch.dateTime.day}/${nextMatch.dateTime.month}  ${nextMatch.dateTime.hour.toString().padLeft(2,'0')}:${nextMatch.dateTime.minute.toString().padLeft(2,'0')} · ${nextMatch.venue}',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
              ],
            ])),
            const SizedBox(width: 10),
            // ── Team badge ─────────────────────────────
            Container(width: 52, height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                image: _teamLogoUrl != null
                    ? DecorationImage(image: NetworkImage(_teamLogoUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: _teamLogoUrl == null
                  ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.shield_rounded, color: Colors.white, size: 24),
                      Text('BADGE', style: TextStyle(color: Colors.white60, fontSize: 7, letterSpacing: 1)),
                    ])
                  : null),
          ]),
        ),
        const SizedBox(height: 20),
        // Stats
        Row(children: [
          _statMini('Squad Size', '$squadSize', Icons.group_rounded, const Color(0xFF003087)),
          const SizedBox(width: 12),
          _statMini('Season Wins', '$seasonWins', Icons.emoji_events_rounded, const Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          _statMini('Matches', '${myFixtures.length}', Icons.sports_soccer_rounded, const Color(0xFF00A651)),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Quick Actions'),
        const SizedBox(height: 10),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.2,
          children: [
            _quickCard(Icons.calendar_today_rounded, 'My Fixtures', const Color(0xFF003087), () => setState(() => _selectedNav = 1)),
            _quickCard(Icons.sports_soccer_rounded, 'Set Lineup', const Color(0xFF00A651), () => setState(() => _selectedNav = 2)),
            _quickCard(Icons.swap_horiz_rounded, 'Substitutions', const Color(0xFF003087), () => setState(() => _selectedNav = 3)),
            _quickCard(Icons.group_rounded, 'My Squad', const Color(0xFFF5A500), () => setState(() => _selectedNav = 4)),
          ]),
        if (completedMatches.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle('Match History'),
          const SizedBox(height: 10),
          ...completedMatches.map((f) {
            final isHome = f.homeTeam == teamName;
            final myScore = isHome ? f.homeScore : f.awayScore;
            final oppScore = isHome ? f.awayScore : f.homeScore;
            final won = myScore > oppScore;
            final drew = myScore == oppScore;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
              child: Row(children: [
                Container(width: 4, height: 40,
                  decoration: BoxDecoration(
                    color: won ? Colors.green : (drew ? Colors.orange : Colors.red),
                    borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${f.homeTeam} vs ${f.awayTeam}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${f.dateTime.day}/${f.dateTime.month}/${f.dateTime.year}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF0A1628), borderRadius: BorderRadius.circular(8)),
                  child: Text('${f.homeScore} – ${f.awayScore}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  Widget _statMini(String label, String value, IconData icon, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
      ])));
  }

  Widget _quickCard(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Colors.grey.shade400),
      ])));
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));

  // ─── My Matches ────────────────────────────────────────────────────────────
  Widget _buildMyMatches() {
    final ap = context.watch<auth.AuthProvider>();
    final teamName = ap.profile?['team_name'] ?? ap.user?.userMetadata?['team_name'] ?? 'My Team';
    final ms = context.watch<MatchState>();
    final myFixtures = ms.fixturesForTeam(teamName);

    if (myFixtures.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.calendar_today_rounded, size: 52, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('No fixtures assigned yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
      const SizedBox(height: 4),
      Text('Admin will generate your match schedule.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
    ]));

    // Sorting/Filtering
    final scheduled = myFixtures.where((f) => f.status == 'scheduled').toList();
    final completed = myFixtures.where((f) => f.status == 'completed').toList();
    final live = myFixtures.where((f) => f.status == 'live').toList();

    return DefaultTabController(length: 3, child: Column(children: [
      Container(color: Colors.white, child: const TabBar(
        labelColor: Color(0xFF00A651), unselectedLabelColor: Colors.grey,
        indicatorColor: Color(0xFF00A651),
        tabs: [Tab(text: 'Upcoming'), Tab(text: 'Live'), Tab(text: 'Results')],
      )),
      Expanded(child: TabBarView(children: [
        _matchList(scheduled, 'No upcoming fixtures'),
        _matchList(live, 'No live matches'),
        _matchList(completed, 'No completed matches'),
      ])),
    ]));
  }

  Widget _matchList(List<GeneratedFixture> fixtures, String emptyMsg) {
    final ap = context.watch<auth.AuthProvider>();
    final teamName = ap.profile?['team_name'] ?? ap.user?.userMetadata?['team_name'] ?? 'My Team';

    if (fixtures.isEmpty) return Center(child: Text(emptyMsg, style: TextStyle(color: Colors.grey.shade400)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: fixtures.length,
      itemBuilder: (_, i) {
        final f = fixtures[i];
        final dt = f.dateTime;
        final isHome = f.homeTeam == teamName;
        final opponent = isHome ? f.awayTeam : f.homeTeam;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            border: Border.all(color: f.status == 'live' ? Colors.red.shade200 : Colors.transparent)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _fixtureStatusBadge(f.status),
              const Spacer(),
              Text('${dt.day}/${dt.month}/${dt.year}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isHome ? 'HOME' : 'AWAY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                  letterSpacing: 1.5, color: isHome ? const Color(0xFF00A651) : const Color(0xFF003087))),
                const SizedBox(height: 2),
                Text('vs $opponent', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              const Spacer(),
              if (f.status == 'completed')
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF0A1628), borderRadius: BorderRadius.circular(8)),
                  child: Text('${f.homeScore} – ${f.awayScore}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(f.venue, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 14),
              const Icon(Icons.schedule_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF00A651), fontWeight: FontWeight.bold)),
            ]),
            if (f.assignedReferee != null)
              Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
                const Icon(Icons.sports_handball_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Referee: ${f.assignedReferee}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
            if (f.status == 'scheduled')
              Padding(padding: const EdgeInsets.only(top: 12), child: Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedNav = 2),
                  icon: const Icon(Icons.sports_soccer_rounded, size: 15),
                  label: const Text('Set Lineup', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00A651),
                    side: const BorderSide(color: Color(0xFF00A651)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: const Text('Send to Ref', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A651), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                )),
              ])),
          ]),
        );
      },
    );
  }

  Widget _fixtureStatusBadge(String status) {
    final configs = {
      'live': (Colors.red.shade600, Colors.red.shade50),
      'completed': (Colors.green.shade600, Colors.green.shade50),
      'scheduled': (Colors.blue.shade600, Colors.blue.shade50),
      'postponed': (Colors.orange.shade600, Colors.orange.shade50),
    };
    final c = configs[status] ?? (Colors.grey, Colors.grey.shade50);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.$2, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: c.$1, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  // ─── Squad (FULL CRUD) ──────────────────────────────────────────────────────
  // Starts empty — players are registered by the coach.
  // Each entry: name, num, pos, course, year, regNo, photoBytes (Uint8List?)
  Widget _buildSquad() {
    return Column(children: [
      Container(color: Colors.white, child: TabBar(
        controller: _squadTabController,
        labelColor: const Color(0xFF00A651), unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF00A651),
        tabs: const [Tab(text: 'Registered Players'), Tab(text: 'Register Player')],
      )),
      Expanded(child: TabBarView(
        controller: _squadTabController,
        children: [_buildSquadList(), _buildPlayerForm()])),
    ]);
  }

  Widget _buildSquadList() {
    if (_isSquadLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));
    if (_squad.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.group_add_rounded, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No players registered yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
        const SizedBox(height: 4),
        Text('Use the Register Player tab to add your squad.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      ]));
    }
    return Column(children: [
      // Player list
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: _squad.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = _squad[i];
          final photoBytes = p['photoBytes'] as Uint8List?;
          final photoUrl = p['photoUrl'] as String?;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // First row: Avatar, Name, Position
              Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF00A651).withOpacity(0.1),
                  backgroundImage: photoBytes != null 
                      ? MemoryImage(photoBytes) as ImageProvider
                      : (photoUrl != null ? NetworkImage(photoUrl) as ImageProvider : null),
                  child: (photoBytes == null && photoUrl == null) ? Text(p['name'][0], style: const TextStyle(color: Color(0xFF00A651), fontWeight: FontWeight.bold)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                  Text('${p['regNo']}  ·  ${p['course']} ${p['year']} Year',
                    style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF00A651).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(p['pos']!, style: const TextStyle(color: Color(0xFF00A651), fontWeight: FontWeight.bold, fontSize: 11))),
              ]),
              // Second row: Edit and Delete buttons (on small screens)
              if (_submissionStatus != 'approved')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                        onPressed: () => _showEditPlayerDialog(i),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Edit player',
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        icon: Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade400),
                        onPressed: () => _confirmDeletePlayer(i),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Delete player',
                      ),
                    ),
                  ]),
                ),
            ]),
          );
        },
      )),
      // Submit Squad Banner
      _buildSubmitBanner(),
    ]);
  }

  Widget _buildSubmitBanner() {
    // Config per status
    final configs = {
      'draft':     (const Color(0xFF00A651), Colors.green.shade50,    Icons.send_rounded,           'Submit Squad to Admin',     'Your squad is ready to submit for review.'),
      'submitted': (Colors.amber.shade700,  Colors.amber.shade50,    Icons.hourglass_top_rounded,   'Squad Submitted ⏳',         'Awaiting admin review. You can re-submit after edits.'),
      'approved':  (const Color(0xFF003087), Colors.blue.shade50,    Icons.verified_rounded,        'Squad Approved ✅',          'Your squad has been officially approved by the admin.'),
      'rejected':  (Colors.red.shade700,    Colors.red.shade50,      Icons.cancel_rounded,          'Squad Rejected ❌',          _rejectionNote ?? 'Please review and re-submit your squad.'),
    };
    final cfg = configs[_submissionStatus] ?? configs['draft']!;
    final canSubmit = _submissionStatus == 'draft' || _submissionStatus == 'rejected';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cfg.$2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cfg.$1.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(cfg.$3, color: cfg.$1, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cfg.$4, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: cfg.$1)),
            const SizedBox(height: 2),
            Text(cfg.$5, style: TextStyle(fontSize: 11, color: cfg.$1.withOpacity(0.8))),
          ])),
          // Squad count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: cfg.$1.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Text('${_squad.length} players', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cfg.$1)),
          ),
        ]),
        if (canSubmit) ...[    
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : () async {
              if (_teamId == null) return;
              setState(() => _isSubmitting = true);
              final ap = context.read<auth.AuthProvider>();
              final err = await ap.submitSquad(_teamId!);
              if (mounted) {
                setState(() {
                  _isSubmitting = false;
                  if (err == null) _submissionStatus = 'submitted';
                });
                ScaffoldMessenger.of(context).showSnackBar(_snack(
                  err == null ? '✓ Squad submitted! Awaiting admin review.' : 'Error: $err',
                  err == null ? const Color(0xFF00A651) : Colors.red,
                ));
              }
            },
            icon: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_submissionStatus == 'rejected' ? Icons.refresh_rounded : Icons.send_rounded, size: 16),
            label: Text(
              _isSubmitting
                  ? 'Submitting…'
                  : (_submissionStatus == 'rejected' ? 'Re-submit Squad' : 'Submit Squad to Admin'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: cfg.$1,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
          )),
        ],
      ]),
    );
  }

  void _showEditPlayerDialog(int index) {
    final p = Map<String, dynamic>.from(_squad[index]);
    final nameCtrl = TextEditingController(text: p['name']);
    final regCtrl = TextEditingController(text: p['regNo']);
    final courseCtrl = TextEditingController(text: p['course']);
    final yearCtrl = TextEditingController(text: p['year']);
    final jerseyCtrl = TextEditingController(text: p['num']);
    String pos = p['pos']!;
    
    // Photo Edit State
    Uint8List? newPhotoBytes;
    bool photoChanged = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Player', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Photo editing trigger
          GestureDetector(
            onTap: () async {
              final picker = ImagePicker();
              final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
              if (image != null) {
                final bytes = await image.readAsBytes();
                setS(() {
                  newPhotoBytes = bytes;
                  photoChanged = true;
                });
              }
            },
            child: Stack(alignment: Alignment.bottomRight, children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF00A651).withOpacity(0.1),
                backgroundImage: photoChanged 
                    ? MemoryImage(newPhotoBytes!) as ImageProvider
                    : (p['photoUrl'] != null ? NetworkImage(p['photoUrl']!) as ImageProvider : null),
                child: (!photoChanged && p['photoUrl'] == null) 
                    ? Text(p['name'][0], style: const TextStyle(fontSize: 24, color: Color(0xFF00A651))) 
                    : null,
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFF00A651), shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _editField('Full Name', nameCtrl),
          const SizedBox(height: 10),
          _editField('Registration No.', regCtrl),
          const SizedBox(height: 10),
          _editField('Course', courseCtrl),
          const SizedBox(height: 10),
          _editField('Year', yearCtrl),
          const SizedBox(height: 10),
          _editField('Jersey No.', jerseyCtrl, keyboard: TextInputType.number),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: pos,
            items: ['GK', 'DF', 'MF', 'FW'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setS(() => pos = v!),
            decoration: InputDecoration(labelText: 'Position',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A651), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              setState(() => _isSquadLoading = true);
              Navigator.pop(ctx);
              
              try {
                String? photoUrl = p['photoUrl'];
                if (photoChanged && newPhotoBytes != null) {
                  final fileName = 'player_${_teamId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  await _client.storage.from('player_photos').uploadBinary(fileName, newPhotoBytes!);
                  photoUrl = _client.storage.from('player_photos').getPublicUrl(fileName);
                }

                final updatedData = {
                  'full_name': nameCtrl.text,
                  'reg_no': regCtrl.text,
                  'course': courseCtrl.text,
                  'year_of_study': yearCtrl.text,
                  'jersey_number': int.tryParse(jerseyCtrl.text) ?? 0,
                  'position': pos,
                  'photo_url': photoUrl,
                };
                
                await _client.from('players').update(updatedData).eq('id', _squad[index]['id']);
                
                if (!mounted) return;
                setState(() {
                  _squad[index] = {
                    ..._squad[index],
                    'name': nameCtrl.text, 'regNo': regCtrl.text,
                    'course': courseCtrl.text, 'year': yearCtrl.text,
                    'num': jerseyCtrl.text, 'pos': pos, 'photoUrl': photoUrl,
                  };
                });
                ScaffoldMessenger.of(context).showSnackBar(_snack('Player updated successfully!', Colors.green));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Error updating player', Colors.red));
              } finally {
                if (mounted) setState(() => _isSquadLoading = false);
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    ));
  }

  void _confirmDeletePlayer(int index) {
    final name = _squad[index]['name'];
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Remove Player'),
      content: Text('Are you sure you want to remove $name from the squad?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            try {
              await _client.from('players').delete().eq('id', _squad[index]['id']);
              if (!mounted) return;
              Navigator.pop(ctx);
              setState(() => _squad.removeAt(index));
              ScaffoldMessenger.of(context).showSnackBar(_snack('$name removed from squad.', Colors.red));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Error removing player', Colors.red));
            }
          },
          child: const Text('Remove'),
        ),
      ],
    ));
  }

  TextField _editField(String label, TextEditingController ctrl, {TextInputType keyboard = TextInputType.text}) {
    return TextField(controller: ctrl, keyboardType: keyboard, decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ));
  }

  final _formName = TextEditingController();
  final _formReg = TextEditingController();
  final _formUniId = TextEditingController();
  final _formCourse = TextEditingController();
  final _formYear = TextEditingController();
  String _formPos = 'FW';
  final _formJersey = TextEditingController();
  Uint8List? _formPhotoBytes;

  Future<void> _pickPlayerPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        const Text('Player Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        ListTile(leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00A651)),
          title: const Text('Take a Photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF003087)),
          title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        const SizedBox(height: 8),
      ])),
    );
    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 400);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _formPhotoBytes = bytes);
  }

  Widget _buildPlayerForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Register New Player', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Fill in details from the student\'s university ID card',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 20),
          // Photo picker
          Center(child: GestureDetector(
            onTap: _pickPlayerPhoto,
            child: Stack(alignment: Alignment.bottomRight, children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFF00A651).withOpacity(0.08),
                backgroundImage: _formPhotoBytes != null ? MemoryImage(_formPhotoBytes!) : null,
                child: _formPhotoBytes == null
                  ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.camera_alt_rounded, color: Color(0xFF00A651), size: 26),
                      SizedBox(height: 4),
                      Text('Photo', style: TextStyle(fontSize: 10, color: Color(0xFF00A651))),
                    ])
                  : null,
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Color(0xFF00A651), shape: BoxShape.circle),
                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
              ),
            ]),
          )),
          const SizedBox(height: 20),
          _field('Full Name', _formName, Icons.person_rounded),
          const SizedBox(height: 12),
          _field('Registration Number', _formReg, Icons.badge_rounded),
          const SizedBox(height: 12),
          _field('University ID No.', _formUniId, Icons.credit_card_rounded),
          const SizedBox(height: 12),
          _field('Course', _formCourse, Icons.school_rounded),
          const SizedBox(height: 12),
          _field('Year of Study', _formYear, Icons.calendar_month_rounded, hint: 'e.g. 2nd Year'),
          const SizedBox(height: 12),
          _field('Jersey Number', _formJersey, Icons.sports_soccer_rounded, keyboard: TextInputType.number),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _formPos,
            items: ['GK', 'DF', 'MF', 'FW'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _formPos = v!),
            decoration: InputDecoration(labelText: 'Field Position', prefixIcon: const Icon(Icons.grid_on_rounded, size: 18),
              filled: true, fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              if (_formName.text.trim().isEmpty || _formJersey.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(_snack('Name and jersey number are required.', Colors.orange));
                return;
              }
              if (_teamId == null) {
                ScaffoldMessenger.of(context).showSnackBar(_snack('Team data not found. Please try again.', Colors.red));
                await _loadSquad();
                return;
              }

              setState(() => _isSquadLoading = true);
              try {
                String? uploadedUrl;
                if (_formPhotoBytes != null) {
                  final fileName = 'player_${_teamId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  await _client.storage.from('player_photos').uploadBinary(fileName, _formPhotoBytes!);
                  uploadedUrl = _client.storage.from('player_photos').getPublicUrl(fileName);
                }

                final newPlayerDB = {
                  'team_id': _teamId,
                  'full_name': _formName.text.trim(),
                  'reg_no': _formReg.text.trim(),
                  'university_id': _formUniId.text.trim(),
                  'course': _formCourse.text.trim(),
                  'year_of_study': _formYear.text.trim(),
                  'jersey_number': int.tryParse(_formJersey.text.trim()) ?? 0,
                  'position': _formPos,
                  'photo_url': uploadedUrl,
                };

                final inserted = await _client.from('players').insert(newPlayerDB).select().single();

                setState(() {
                  _squad.add({
                    'id': inserted['id'],
                    'name': inserted['full_name'],
                    'regNo': inserted['reg_no'],
                    'uniId': inserted['university_id'],
                    'course': inserted['course'],
                    'year': inserted['year_of_study'],
                    'num': inserted['jersey_number'].toString(),
                    'pos': inserted['position'],
                    'photoUrl': inserted['photo_url'],
                  });
                });

                ScaffoldMessenger.of(context).showSnackBar(_snack('${_formName.text} registered successfully!', Colors.green));
                _formName.clear(); _formReg.clear(); _formUniId.clear();
                _formCourse.clear(); _formYear.clear(); _formJersey.clear();
                setState(() => _formPhotoBytes = null);
                _squadTabController?.animateTo(0);
              } catch (e) {
                debugPrint('Registration error: $e');
                ScaffoldMessenger.of(context).showSnackBar(_snack('Error registering player', Colors.red));
              } finally {
                setState(() => _isSquadLoading = false);
              }
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Register Player'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A651), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {String? hint, TextInputType keyboard = TextInputType.text}) {
    return TextField(controller: ctrl, keyboardType: keyboard, decoration: InputDecoration(
      labelText: label, hintText: hint, prefixIcon: Icon(icon, size: 18),
      filled: true, fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00A651))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ));
  }

  // ─── Chat Placeholder ───────────────────────────────────────────────────────
  Widget _buildChatPlaceholder() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF00A651).withOpacity(0.1), shape: BoxShape.circle),
        child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(0xFF00A651))),
      const SizedBox(height: 16),
      const Text('Team Chat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Chat with referees and officials', style: TextStyle(color: Colors.grey.shade500)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded),
        label: const Text('Start a Conversation'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A651), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
      ),
    ]));
  }

  // ─── Settings ──────────────────────────────────────────────────────────────
  Widget _buildSettings() {
    final ap = context.watch<auth.AuthProvider>();

    // Sync profile fields from provider if not yet initialized via DB load
    final profile = ap.profile;
    if (!_profileInitialized && profile != null) {
      _settingsNameCtrl.text = profile['full_name'] ?? '';
      _settingsPhoneCtrl.text = profile['phone'] ?? '';
      _profileInitialized = true;
    }
    final avatarUrl = profile?['avatar_url'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Page Header
        Padding(padding: const EdgeInsets.only(bottom: 20), child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00A651), Color(0xFF007A3D)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
            Text('Manage your team & account', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ])),

        // ── 1. Team Branding ─────────────────────────────────────────────────
        _settingsCard(
          title: 'Team Branding',
          subtitle: 'Upload your badge and team name',
          icon: Icons.shield_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF00A651), Color(0xFF007A3D)]),
          child: Column(children: [
            // Logo Upload Zone
            Center(child: GestureDetector(
              onTap: () async {
                if (_teamId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    _snack('Team not found. Please wait for data to load.', Colors.orange));
                  return;
                }
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 500);
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  setState(() {
                    _pendingTeamLogo = image;
                    _pendingTeamLogoBytes = bytes;
                  });
                }
              },
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: _pendingTeamLogoBytes != null
                          ? const Color(0xFF00A651)
                          : Colors.grey.shade200,
                      width: _pendingTeamLogoBytes != null ? 2.5 : 1.5,
                    ),
                    image: _pendingTeamLogoBytes != null
                        ? DecorationImage(image: MemoryImage(_pendingTeamLogoBytes!), fit: BoxFit.cover)
                        : (_teamLogoUrl != null
                            ? DecorationImage(image: NetworkImage(_teamLogoUrl!), fit: BoxFit.cover)
                            : null),
                    boxShadow: [
                      BoxShadow(
                        color: (_pendingTeamLogoBytes != null
                            ? const Color(0xFF00A651)
                            : Colors.black).withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: (_pendingTeamLogoBytes == null && _teamLogoUrl == null)
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_rounded, color: Colors.grey.shade400, size: 32),
                          const SizedBox(height: 6),
                          Text('TAP TO UPLOAD', style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        ])
                      : null,
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _pendingTeamLogoBytes != null
                      ? Container(
                          key: const ValueKey('preview'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.info_outline_rounded, size: 12, color: Colors.orange.shade800),
                            const SizedBox(width: 4),
                            Text('Preview – tap Save to apply', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                          ]),
                        )
                      : Text(
                          key: const ValueKey('hint'),
                          'Tap the badge to change',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                ),
              ]),
            )),
            const SizedBox(height: 24),
            _settingsField('Team Name', _settingsTeamNameCtrl, Icons.shield_outlined),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _settingsLoading ? null : () async {
                if (_teamId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    _snack('Team not found. Please reload and try again.', Colors.red));
                  return;
                }
                setState(() => _settingsLoading = true);
                try {
                  if (_pendingTeamLogo != null) {
                    await ap.uploadTeamLogo(_teamId!, _pendingTeamLogo!);
                    setState(() {
                      _pendingTeamLogo = null;
                      _pendingTeamLogoBytes = null;
                    });
                  }
                  final err = await ap.updateTeam(_teamId!, name: _settingsTeamNameCtrl.text.trim());
                  if (!mounted) return;
                  if (err == null) {
                    await _loadSquad();
                    ScaffoldMessenger.of(context).showSnackBar(_snack('✓ Team branding saved!', const Color(0xFF00A651)));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(_snack('Error: $err', Colors.red));
                  }
                } finally {
                  if (mounted) setState(() => _settingsLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A651),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF00A651).withOpacity(0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _settingsLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.save_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Save Team Branding', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
            )),
          ]),
        ),
        const SizedBox(height: 18),

        // ── 2. Coach Profile ─────────────────────────────────────────────────
        _settingsCard(
          title: 'Coach Profile',
          subtitle: 'Your personal information & photo',
          icon: Icons.person_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF003087), Color(0xFF1A52A8)]),
          child: Column(children: [
            // ── Profile Photo ────────────────────────────────────────────────
            Center(child: GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final source = await showModalBottomSheet<ImageSource>(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(height: 12),
                    const Text('Update Profile Photo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    ListTile(
                      leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF003087)),
                      title: const Text('Take a Photo'),
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF003087)),
                      title: const Text('Choose from Gallery'),
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                    const SizedBox(height: 8),
                  ])),
                );
                if (source == null) return;
                final picked = await picker.pickImage(
                  source: source, imageQuality: 80, maxWidth: 400);
                if (picked == null) return;
                final bytes = await picked.readAsBytes();
                setState(() => _pendingAvatarBytes = bytes);
                // Upload immediately
                setState(() => _settingsProfileLoading = true);
                final err = await ap.uploadAvatar(picked);
                if (mounted) {
                  setState(() {
                    _settingsProfileLoading = false;
                    _pendingAvatarBytes = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(_snack(
                    err == null ? '✓ Profile photo updated!' : 'Error: $err',
                    err == null ? const Color(0xFF00A651) : Colors.red,
                  ));
                }
              },
              child: Stack(alignment: Alignment.bottomRight, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF003087),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF003087).withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF003087).withOpacity(0.1),
                    backgroundImage: _pendingAvatarBytes != null
                        ? MemoryImage(_pendingAvatarBytes!) as ImageProvider
                        : (avatarUrl != null
                            ? NetworkImage(avatarUrl) as ImageProvider
                            : null),
                    child: (_pendingAvatarBytes == null && avatarUrl == null)
                        ? Text(
                            (_settingsNameCtrl.text.isNotEmpty
                                ? _settingsNameCtrl.text[0]
                                : '?').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003087),
                            ),
                          )
                        : null,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003087),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: _settingsProfileLoading
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 14),
                ),
              ]),
            )),
            const SizedBox(height: 8),
            Text('Tap to change photo',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            const SizedBox(height: 24),
            _settingsField('Full Name', _settingsNameCtrl, Icons.person_outline_rounded),
            const SizedBox(height: 14),
            _settingsField('Phone Number', _settingsPhoneCtrl, Icons.phone_android_rounded,
              keyboard: TextInputType.phone),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _settingsProfileLoading ? null : () async {
                setState(() => _settingsProfileLoading = true);
                final error = await ap.updateProfile(
                  fullName: _settingsNameCtrl.text.trim(),
                  phone: _settingsPhoneCtrl.text.trim(),
                );
                if (mounted) setState(() => _settingsProfileLoading = false);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(_snack(
                  error == null ? '✓ Profile updated!' : 'Error: $error',
                  error == null ? const Color(0xFF00A651) : Colors.red,
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF003087).withOpacity(0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _settingsProfileLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.save_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Save Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
            )),
          ]),
        ),
        const SizedBox(height: 18),

        // ── 3. Change Password ───────────────────────────────────────────────
        _settingsCard(
          title: 'Change Password',
          subtitle: 'Update your account password',
          icon: Icons.lock_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)]),
          child: Column(children: [
            // New password with visibility toggle
            TextField(
              controller: _settingsPasswordCtrl,
              obscureText: !_showPassword,
              decoration: _settingsInputDecoration(
                label: 'New Password',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18, color: Colors.grey.shade500),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Confirm password with visibility toggle
            TextField(
              controller: _settingsConfirmCtrl,
              obscureText: !_showConfirmPassword,
              decoration: _settingsInputDecoration(
                label: 'Confirm New Password',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(_showConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18, color: Colors.grey.shade500),
                  onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Password requirements hint
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Minimum 6 characters', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _settingsPasswordLoading ? null : () async {
                if (_settingsPasswordCtrl.text != _settingsConfirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(_snack('Passwords do not match!', Colors.red));
                  return;
                }
                if (_settingsPasswordCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(_snack('Password must be at least 6 characters.', Colors.orange));
                  return;
                }
                setState(() => _settingsPasswordLoading = true);
                final error = await ap.updatePassword(_settingsPasswordCtrl.text);
                if (mounted) setState(() => _settingsPasswordLoading = false);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(_snack(
                  error == null ? '✓ Password updated successfully!' : 'Error: $error',
                  error == null ? const Color(0xFF00A651) : Colors.red,
                ));
                if (error == null) {
                  _settingsPasswordCtrl.clear();
                  _settingsConfirmCtrl.clear();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF1E293B).withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _settingsPasswordLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.lock_reset_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Update Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
            )),
          ]),
        ),
        const SizedBox(height: 18),

        // ── 4. Appearance ────────────────────────────────────────────────────
        _settingsCard(
          title: 'Appearance',
          subtitle: 'Theme and display preferences',
          icon: Icons.palette_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: const Color(0xFF7C3AED),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_darkMode ? 'Light Background' : 'White Background',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('Toggle dashboard background', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
            Switch(
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v),
              activeColor: const Color(0xFF7C3AED),
              activeTrackColor: const Color(0xFF7C3AED).withOpacity(0.3),
            ),
          ]),
        ),

        const SizedBox(height: 18),
        // Sign out prompt card
        InkWell(
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              await ap.signOut();
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.red.shade700)),
                Text('You will be redirected to login', style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
              ])),
              Icon(Icons.chevron_right_rounded, color: Colors.red.shade300),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Card template ────────────────────────────────────────────────────────────
  Widget _settingsCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Gradient header strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
            ]),
          ]),
        ),
        // Body content
        Padding(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ]),
    );
  }

  // ── Input decoration factory ─────────────────────────────────────────────────
  InputDecoration _settingsInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00A651), width: 1.5),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  Widget _settingsField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType keyboard = TextInputType.text, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: _settingsInputDecoration(label: label, icon: icon),
    );
  }

  SnackBar _snack(String msg, Color color) => SnackBar(
    content: Row(children: [
      const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
    ]),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    duration: const Duration(seconds: 3),
  );
}
