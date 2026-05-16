import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/auth/auth_provider.dart' as auth;
import '../../core/state/match_state.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';

// ─── Spectator & Player Portal — MMU Branded ─────────────────────────────────

class SpectatorHome extends StatefulWidget {
  const SpectatorHome({super.key});
  @override
  State<SpectatorHome> createState() => _SpectatorHomeState();
}

class _SpectatorHomeState extends State<SpectatorHome>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  final _pageCtrl = PageController();
  int _currentSlide = 0;
  Timer? _slideTimer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  // Discussion
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final Stream<List<Map<String, dynamic>>> _chatStream;

  // Live Score Overlay
  bool _showLiveOverlay = false;
  bool _liveOverlayExpanded = true;

  // Settings state
  bool _matchAlerts = true;
  bool _darkMode = false;

  // Chat Identity & Notifications
  String? _publicNickname;
  String? _guestId;
  int _unreadCount = 0;
  DateTime? _lastViewedChat;
  late final StreamSubscription _badgeSubscription;

  // ─ Reply-to state (WhatsApp style) ────────────────────────────────
  Map<String, dynamic>? _replyingTo; // the message being replied to

  // ─ Live online count ──────────────────────────────────────────────
  int _onlineCount = 0;
  Timer? _onlineTimer;

  // ─ Realtime team branding ──────────────────────────────────────────
  List<Map<String, dynamic>> _liveTeams = [];
  StreamSubscription<List<Map<String, dynamic>>>? _teamsStreamSub;
  String? _recentlyUpdatedTeamName; // for flash effect

  // Demo match slides
  static const _slides = [
    {'title': 'Lions FC vs Blue Sharks', 'sub': 'Sat 29 Mar · 14:00', 'venue': 'MMU Main Ground', 'emoji': '🦁🆚🦈', 'date': 'Matchday 7'},
    {'title': 'Red Eagles vs City Wolves', 'sub': 'Sat 29 Mar · 16:00', 'venue': 'Court B', 'emoji': '🦅🆚🐺', 'date': 'Matchday 7'},
    {'title': 'Green Foxes vs Yellow Stars', 'sub': 'Sun 30 Mar · 10:00', 'venue': 'MMU Main Ground', 'emoji': '🦊🆚⭐', 'date': 'Matchday 8'},
  ];

  @override
  void initState() {
    super.initState();
    _chatStream = Supabase.instance.client
        .from('spectator_chats')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .limit(50);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _slideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_pageCtrl.hasClients) {
        final next = (_currentSlide + 1) % _slides.length;
        _pageCtrl.animateToPage(next,
            duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
        setState(() => _currentSlide = next);
      }
    });

    // Badge listener
    _badgeSubscription = Supabase.instance.client
        .from('spectator_chats')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen((data) {
      if (!mounted || _currentIndex == 2) return;
      if (_lastViewedChat == null) {
        // First load, just set the reference
        if (data.isNotEmpty) {
          _lastViewedChat = DateTime.parse(data.first['created_at']);
        }
        return;
      }
      
      int count = 0;
      for (final m in data) {
        final dt = DateTime.parse(m['created_at']);
        if (dt.isAfter(_lastViewedChat!)) {
          count++;
        } else {
          break;
        }
      }
      if (count != _unreadCount) {
        setState(() => _unreadCount = count);
      }
    });

    _initGuestId();
    _refreshOnlineCount();
    // Refresh online count every 60 seconds
    _onlineTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshOnlineCount());

    // ─ Subscribe to teams table for live name/logo updates ───────────────
    _teamsStreamSub = Supabase.instance.client
        .from('teams')
        .stream(primaryKey: ['id'])
        .listen((rows) {
      if (!mounted) return;
      final prev = {for (final t in _liveTeams)
          (t['name'] as String? ?? ''): t};
      setState(() => _liveTeams = rows);
      // Detect name/logo change for flash effect
      for (final row in rows) {
        final name = row['name'] as String? ?? '';
        final old = prev[name];
        if (old != null &&
            (old['logo_url'] != row['logo_url'] ||
             old['name'] != row['name'])) {
          setState(() => _recentlyUpdatedTeamName = name);
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _recentlyUpdatedTeamName = null);
          });
        }
      }
    });
  }

  /// Count distinct senders who posted in the last 5 minutes.
  Future<void> _refreshOnlineCount() async {
    try {
      final since = DateTime.now().subtract(const Duration(minutes: 5)).toUtc().toIso8601String();
      // Fetch recent messages and count unique senders (profile_id OR guest_id)
      final rows = await Supabase.instance.client
          .from('spectator_chats')
          .select('profile_id, guest_id')
          .gte('created_at', since);
      final senders = <String>{};
      for (final r in rows) {
        final pid = r['profile_id'] as String?;
        final gid = r['guest_id'] as String?;
        if (pid != null) senders.add('u_$pid');
        if (gid != null) senders.add('g_$gid');
      }
      if (mounted) setState(() => _onlineCount = senders.length);
    } catch (_) {}
  }

  Future<void> _initGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    String? gid = prefs.getString('mmu_guest_id');
    if (gid == null) {
      gid = 'guest_${DateTime.now().millisecondsSinceEpoch}_${(100 + (DateTime.now().microsecond % 900))}';
      await prefs.setString('mmu_guest_id', gid);
    }
    if (mounted) setState(() => _guestId = gid);
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _onlineTimer?.cancel();
    _teamsStreamSub?.cancel();
    _pageCtrl.dispose();
    _pulseCtrl.dispose();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    _badgeSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
      extendBody: true,
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (_currentIndex) {
      case 1: return _buildStandingsPage();
      case 2: return _buildDiscussionPage();
      case 3: return _buildSettingsPage();
      default: return _buildHomePage();
    }
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.mmwNavy,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navyDark.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded, context.read<AppState>().translate('home')),
                _navItem(1, Icons.leaderboard_rounded, context.read<AppState>().translate('standings')),
                _navItem(2, Icons.chat_bubble_rounded, context.read<AppState>().translate('talk')),
                _navItem(3, Icons.settings_rounded, context.read<AppState>().translate('more')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.mmwGold.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: active ? AppColors.mmwGold : Colors.white,
                    size: 24,
                  ),
                  if (index == 2 && _unreadCount > 0 && !active)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          _unreadCount > 9 ? '9+' : '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.mmwGold : Colors.white70,
                fontSize: 9,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab 0: Home ─────────────────────────────────────────────────────────────
  Widget _buildHomePage() {
    final ap = context.watch<auth.AuthProvider>();
    final ms = context.watch<MatchState>();
    final appState = context.watch<AppState>();
    final liveF = ms.liveFixture;

    return Stack(
      children: [
        ListView(
          // Extra top padding when overlay is expanded so content isn't hidden under it
          padding: EdgeInsets.only(
            top: _showLiveOverlay && _liveOverlayExpanded ? 164 : (_showLiveOverlay ? 60 : 0),
            bottom: 130,
          ),
          children: [
            _buildHero(ap, appState),
            const SizedBox(height: 8),
            _buildSlideshow(appState, ms),
            _buildFeatureGrid(ms),
            _buildUpcomingList(ms),
          ],
        ),
        // ── Floating Live Score Overlay ─────────────────────────────────
        if (_showLiveOverlay)
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildFloatingLiveScore(ms),
          ),
      ],
    );
  }

  // ── Floating Live Score Panel ──────────────────────────────────────────────
  Widget _buildFloatingLiveScore(MatchState ms) {
    final liveF = ms.liveFixture;
    final homeTeam = liveF?.homeTeam ?? 'Lions FC';
    final awayTeam = liveF?.awayTeam ?? 'Eagles Utd';
    final homeScore = liveF?.homeScore ?? 0;
    final awayScore = liveF?.awayScore ?? 0;
    // Derive current minute from the last recorded event (MatchEvent has the minute field)
    final lastEvent = (liveF != null && liveF.events.isNotEmpty) ? liveF.events.last : null;
    final minuteLabel = lastEvent != null ? "${lastEvent.minute}'" : (liveF != null ? "LIVE" : "FT");

    return SafeArea(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF001A4D), Color(0xFF003087), Color(0xFF001A4D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF003087).withOpacity(0.6),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top bar: league + controls ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: AppColors.mmwGreen,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.mmwGreen.withOpacity(0.6), blurRadius: 4)],
                      ),
                    ),
                    const Text('MMU SOCCER LEAGUE',
                        style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Matchday ${liveF != null ? "1" : "–"}',
                          style: const TextStyle(color: Colors.white60, fontSize: 8)),
                    ),
                    const Spacer(),
                    // Collapse/Expand toggle
                    GestureDetector(
                      onTap: () => setState(() => _liveOverlayExpanded = !_liveOverlayExpanded),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _liveOverlayExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70, size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Close button
                    GestureDetector(
                      onTap: () => setState(() => _showLiveOverlay = false),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Score body (hidden when collapsed) ──
              if (_liveOverlayExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Home team
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _liveTeamLogo(homeTeam),
                            const SizedBox(height: 8),
                            Text(homeTeam,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),

                      // Score block
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Minute pill
                            AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (_, __) => Opacity(
                                opacity: _pulseAnim.value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.mmwGreen,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(minuteLabel,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Score
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text('$homeScore',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, height: 1)),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('-', style: TextStyle(color: Colors.white60, fontSize: 28, fontWeight: FontWeight.w300)),
                                ),
                                Text('$awayScore',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, height: 1)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('(0-0)', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
                          ],
                        ),
                      ),

                      // Away team
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _liveTeamLogo(awayTeam),
                            const SizedBox(height: 8),
                            Text(awayTeam,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Footer: venue + date (only when expanded) ──
              if (_liveOverlayExpanded)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _liveInfoChip(Icons.calendar_today_rounded, 'Season 2026'),
                      _liveInfoChip(Icons.location_on_rounded, liveF?.venue ?? 'MMU Main Ground'),
                      _liveInfoChip(Icons.sports_soccer_rounded, 'Live'),
                    ],
                  ),
                ),

              // ── Compact collapsed pill ──
              if (!_liveOverlayExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$homeTeam  $homeScore – $awayScore  $awayTeam',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Opacity(
                          opacity: _pulseAnim.value,
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.mmwGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(minuteLabel,
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liveTeamLogo(String team) {
    String? logoUrl;
    try {
      logoUrl = _liveTeams.firstWhere(
        (t) => (t['name'] as String?)?.toLowerCase() == team.toLowerCase(),
      )['logo_url'] as String?;
    } catch (_) {}

    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(logoUrl, width: 48, height: 48, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _liveTeamInitials(team)),
      );
    }
    return _liveTeamInitials(team);
  }

  Widget _liveTeamInitials(String team) {
    final initials = team.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join();
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(initials.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }

  Widget _liveInfoChip(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white38, size: 11),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ],
  );

  Widget _buildHero(auth.AuthProvider ap, AppState appState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = (MediaQuery.of(context).size.height * 0.35).clamp(240.0, 380.0);
        return SizedBox(
          height: heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Trophy background image ────────────────────
              Image.asset(
                'assets/trophy.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              // ── Dark navy gradient overlay ────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xCC001A4D),
                      Color(0xB3003087),
                      Color(0xD9001A4D),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // ── Content ──────────────────────────────────────
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/mmulogo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('MMU SOCCER LEAGUE',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 1.5)),
                              Text(appState.seasonLabel,
                                  style: const TextStyle(
                                      color: AppColors.mmwGold,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 9,
                                      letterSpacing: 1)),
                            ],
                          ),
                          const Spacer(),
                          if (ap.user == null)
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.mmwGold,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Sign In',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.mmwGold,
                              child: Text(
                                ap.user?.email?.substring(0, 1).toUpperCase() ?? 'S',
                                style: const TextStyle(color: AppColors.mmwNavy, fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(appState.translate('welcome_mmu'),
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Tappable LIVE badge — opens floating live score overlay
                          GestureDetector(
                            onTap: () => setState(() => _showLiveOverlay = !_showLiveOverlay),
                            child: AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (_, __) => Transform.scale(
                                scale: _pulseAnim.value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.mmwGreen,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.mmwGreen.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6, height: 6,
                                        margin: const EdgeInsets.only(right: 5),
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      ),
                                      Text(appState.translate('status_live'),
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(appState.translate('season_underway'),
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                          const SizedBox(width: 6),
                          Icon(Icons.touch_app_rounded, color: Colors.white.withOpacity(0.5), size: 12),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Tab 1: Standings ────────────────────────────────────────────────────────
  Widget _buildStandingsPage() {
    final ms       = context.watch<MatchState>();
    final appState = context.watch<AppState>();
    final entries  = ms.standings.isNotEmpty ? ms.standings : _demoStandings();
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          Text('Standings',
              style: TextStyle(color: isDark ? Colors.white : AppColors.textDark, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(appState.seasonLabel,
              style: TextStyle(color: isDark ? Colors.white70 : AppColors.textMid, fontSize: 13)),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mmwNavy.withOpacity(0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _standingHeader(),
                ...entries.asMap().entries.map((e) => _standingRow(e.key + 1, e.value)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          Row(
            children: [
              _legendItem(AppColors.mmwNavy, 'Top 4 — Playoffs'),
              const SizedBox(width: 16),
              _legendItem(Colors.redAccent, 'Bottom — Relegation'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) => Row(
    children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: AppColors.textMid, fontSize: 10)),
    ],
  );

  Widget _standingHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      color: AppColors.mmwNavy,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Row(
      children: [
        const SizedBox(width: 4), // left border placeholder
        const SizedBox(width: 24,
          child: Text('#', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1))),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('CLUB', style: TextStyle(color: Colors.white70, fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: 1)),
        ),
        ...['P', 'W', 'D', 'L', 'GF', 'GA', 'GD', 'PTS'].map(
          (h) => SizedBox(
            width: h == 'PTS' ? 36 : 28,
            child: Text(h,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: h == 'PTS' ? AppColors.mmwGold : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                )),
          ),
        ),
      ],
    ),
  );

  Widget _standingRow(int pos, StandingEntry s) {
    final isTop4    = pos <= 4;
    final isBottom  = pos >= 7;
    final zoneColor = isTop4 ? AppColors.mmwNavy : (isBottom ? Colors.redAccent : Colors.transparent);
    final gd        = s.goalDifference;
    final gdLabel   = gd > 0 ? '+$gd' : '$gd';
    final initials  = s.team.trim().isNotEmpty ? s.team.trim()[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(
        color: pos.isEven
            ? AppColors.mmwNavy.withOpacity(0.03)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.6),
          left:   BorderSide(color: zoneColor, width: 3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Position number
            SizedBox(
              width: 24,
              child: Text(
                '$pos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isTop4 ? AppColors.mmwNavy : (isBottom ? Colors.redAccent : AppColors.textMid),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Club avatar + name
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.mmwNavy.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(initials,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mmwNavy,
                          )),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s.team,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        )),
                  ),
                ],
              ),
            ),
            // Stats columns: P W D L GF GA GD PTS
            _statCell('${s.played}'),
            _statCell('${s.wins}'),
            _statCell('${s.draws}'),
            _statCell('${s.losses}'),
            _statCell('${s.goalsFor}'),
            _statCell('${s.goalsAgainst}'),
            _statCell(gdLabel),
            // PTS — gold + bold
            SizedBox(
              width: 36,
              child: Text(
                '${s.points}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mmwGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String val) => SizedBox(
    width: 28,
    child: Text(val,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
  );

  // ─── Tab 2: Discussions (functional) ─────────────────────────────────────────
  Widget _buildDiscussionPage() {
    // Clear badge when entering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_unreadCount > 0) {
        setState(() {
          _unreadCount = 0;
          _lastViewedChat = DateTime.now();
        });
      }
    });

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discussions',
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textDark, fontSize: 24, fontWeight: FontWeight.w900)),
                      Text('Fan Talk & Match Chatter',
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.textMid, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.mmwGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.mmwGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                          color: AppColors.mmwGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        _onlineCount == 0 ? 'Live Chat' : '$_onlineCount online',
                        style: const TextStyle(color: AppColors.mmwGreen, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.mmwNavy));
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textLight.withOpacity(0.3), size: 48),
                        const SizedBox(height: 16),
                        Text('No messages yet. Be the first to talk!', style: TextStyle(color: AppColors.textLight.withOpacity(0.5))),
                      ],
                    ),
                  );
                }

                // Auto-scroll to bottom when data arrives
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.animateTo(
                      _scrollCtrl.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _chatBubble(messages[i]),
                );
              },
            ),
          ),
          // Reply preview bar (shown when replying)
          if (_replyingTo != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.mmwNavy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  left: BorderSide(color: AppColors.mmwNavy, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Replying to ${_replyingTo!['user_name'] ?? 'Fan'}',
                          style: const TextStyle(
                            color: AppColors.mmwNavy,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (_replyingTo!['message'] as String? ?? '').length > 60
                              ? '${(_replyingTo!['message'] as String).substring(0, 60)}…'
                              : (_replyingTo!['message'] as String? ?? ''),
                          style: const TextStyle(color: AppColors.textMid, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(Icons.close_rounded, color: AppColors.textLight, size: 18),
                  ),
                ],
              ),
            ),
          // Functional input bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mmwNavy.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtrl,
                    style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.mmwNavy,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;

    final ap = context.read<auth.AuthProvider>();
    
    // Identity Check
    if (ap.user == null && _publicNickname == null) {
      final name = await _showIdentityModal();
      if (name == null || name.isEmpty) return;
      setState(() => _publicNickname = name);
    }

    final userName = ap.user != null 
        ? (ap.user?.userMetadata?['full_name'] ?? ap.user?.email?.split('@').first ?? 'User')
        : (_publicNickname ?? 'Guest Fan');
    final userId = ap.user?.id;

    // Capture reply context before clearing
    final replyId = _replyingTo?['id'] as String?;
    final replyPreview = _replyingTo != null
        ? '${_replyingTo!['user_name']}: ${_replyingTo!['message']}'
        : null;

    try {
      _chatCtrl.clear();
      setState(() => _replyingTo = null); // clear reply after send
      await Supabase.instance.client.from('spectator_chats').insert({
        'profile_id': userId, // NULL if not logged in
        'user_name': userName,
        'message': text,
        'guest_id': userId == null ? _guestId : null,
        if (replyId != null) 'reply_to_id': replyId,
        if (replyPreview != null) 'reply_to_preview': replyPreview,
      });
      // Force update last viewed when sending
      _lastViewedChat = DateTime.now();
      // Refresh online count immediately after sending
      _refreshOnlineCount();
      // Immediate scroll to bottom
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  Widget _chatBubble(Map<String, dynamic> m) {
    final ap = context.read<auth.AuthProvider>();
    
    // Identity logic:
    // 1. If profile_id matches current user's profile_id -> isMe
    // 2. If no profile_id (guest) AND guest_id matches current _guestId -> isMe
    bool isMe = false;
    if (m['profile_id'] != null && ap.user != null) {
      isMe = m['profile_id'] == ap.user?.id;
    } else if (m['profile_id'] == null && _guestId != null) {
      isMe = m['guest_id'] == _guestId;
    }
    
    // Format timestamp
    String timeStr = 'Just now';
    try {
      final dt = DateTime.parse(m['created_at']);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) timeStr = 'Just now';
      else if (diff.inMinutes < 60) timeStr = '${diff.inMinutes}m ago';
      else if (diff.inHours < 24) timeStr = '${diff.inHours}h ago';
      else timeStr = '${dt.day}/${dt.month}';

      // Update last viewed if this is the newest message and we're looking at it
      if (_currentIndex == 2 && (_lastViewedChat == null || dt.isAfter(_lastViewedChat!))) {
        _lastViewedChat = dt;
      }
    } catch (_) {}

    final userDisp = isMe ? 'You' : (m['user_name'] ?? 'Spectator');
    final replyPreview = m['reply_to_preview'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SwipeToReplyWrapper(
      onReply: () => setState(() => _replyingTo = m),
      isMe: isMe,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.mmwNavy.withOpacity(0.07) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isMe
              ? Border.all(color: AppColors.mmwNavy.withOpacity(0.15))
              : Border.all(color: AppColors.divider),
          boxShadow: isMe ? null : [
            BoxShadow(
              color: AppColors.mmwNavy.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Reply preview ──────────────────────────────────────
            if (replyPreview != null)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : AppColors.mmwNavy.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    left: BorderSide(color: AppColors.mmwGold, width: 3),
                  ),
                ),
                child: Text(
                  replyPreview.length > 80 ? '${replyPreview.substring(0, 80)}…' : replyPreview,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : AppColors.textMid,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // ── Main message body ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(userDisp,
                          style: TextStyle(
                            color: isMe ? AppColors.mmwNavy : AppColors.mmwGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          )),
                      const Spacer(),
                      Text(timeStr, style: const TextStyle(color: AppColors.textLight, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m['message']!,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textDark,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String?> _showIdentityModal() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.mmwNavy.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_pin_rounded, color: AppColors.mmwNavy),
            ),
            const SizedBox(width: 12),
            const Text('Choose a Nickname', 
                style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a simple name so fans can differentiate you in the chat.',
              style: TextStyle(color: AppColors.textMid, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textDark),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                hintText: 'e.g. SuperFan, GoalMachine',
                hintStyle: const TextStyle(color: AppColors.textLight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMid)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(ctx, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mmwNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Start Chatting'),
          ),
        ],
      ),
    );
  }

  // ─── Tab 3: Settings (functional) ────────────────────────────────────────────
  Widget _buildSettingsPage() {
    final appState = context.watch<AppState>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          Text(appState.translate('settings'),
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textDark, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          _sectionLabel(appState.translate('notifications')),
          _settingsTile(
            icon: Icons.notifications_active_rounded,
            title: appState.translate('match_alerts'),
            sub: 'Get notified when a goal is scored',
            trailing: Switch(
              value: _matchAlerts,
              onChanged: (v) => setState(() => _matchAlerts = v),
              activeColor: AppColors.mmwGreen,
            ),
          ),
          const SizedBox(height: 8),
          _sectionLabel(appState.translate('display')),
          _settingsTile(
            icon: Icons.dark_mode_rounded,
            title: appState.translate('dark_mode'),
            sub: appState.isDarkMode ? 'Enabled' : 'System default',
            trailing: Switch(
              value: appState.isDarkMode,
              onChanged: (v) => appState.toggleDarkMode(v),
              activeColor: AppColors.mmwGreen,
            ),
          ),
          const SizedBox(height: 8),
          _sectionLabel(appState.translate('general')),
          _settingsTile(
            icon: Icons.language_rounded,
            title: appState.translate('language'),
            sub: appState.language == AppLanguage.english ? 'English' : 'Kiswahili',
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textLight, size: 14),
            onTap: () => _showLanguagePicker(appState),
          ),
          _settingsTile(
            icon: Icons.help_outline_rounded,
            title: appState.translate('help_center'),
            sub: 'FAQs and Support',
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textLight, size: 14),
            onTap: () => _showHelpCenter(appState),
          ),
          _settingsTile(
            icon: Icons.info_outline_rounded,
            title: appState.translate('about'),
            sub: 'Mountains of the Moon University',
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textLight, size: 14),
            onTap: () => _showAboutDialog(),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('v2.0.4 — MMU Sports Platform',
                style: TextStyle(color: AppColors.textLight.withOpacity(0.6), fontSize: 10)),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(AppState appState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(appState.translate('choose_language'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              title: const Text('English', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: appState.language == AppLanguage.english ? const Icon(Icons.check_circle, color: AppColors.mmwGreen) : null,
              onTap: () {
                appState.setLanguage(AppLanguage.english);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('🇹🇿', style: TextStyle(fontSize: 24)),
              title: const Text('Kiswahili', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: appState.language == AppLanguage.kiswahili ? const Icon(Icons.check_circle, color: AppColors.mmwGreen) : null,
              onTap: () {
                appState.setLanguage(AppLanguage.kiswahili);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpCenter(AppState appState) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.help_center_rounded, color: AppColors.mmwNavy),
            const SizedBox(width: 12),
            Text(appState.translate('help_center'), style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Guide:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                _helpStep(1, 'Navigate', 'Use the bottom bar to switch between Home, Standings, and Talk.'),
                _helpStep(2, 'Join the Chat', 'Go to "Talk". If you are not signed in, choose a nickname to participate.'),
                _helpStep(3, 'Stay Updated', 'The "Live" pill at the bottom appears during active matches. Tap it for live events.'),
                _helpStep(4, 'Personalize', 'Head to "More" to toggle Dark Mode or change the language to Kiswahili.'),
                _helpStep(5, 'Fixtures & Scores', 'Tap on "Fixtures" or "Results" cards on Home to see historical and upcoming data.'),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text('Support Contact', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const Text('For issues, contact us at:', style: TextStyle(fontSize: 12, color: AppColors.textMid)),
                const Text('santorayern@gmail.com', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.mmwNavy, fontSize: 13)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(appState.translate('cancel'))),
        ],
      ),
    );
  }

  Widget _helpStep(int num, String title, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: AppColors.mmwNavy,
          child: Text('$num', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: AppColors.textMid, fontSize: 11)),
            ],
          ),
        ),
      ],
    ),
  );

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('About MMU Sports',
            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _aboutSection('About', 'MMU provides an environment that promotes student talent in the arts, music, dance, and drama. Through the Student’s Guild events like culture days, art exhibitions, public debates, and poetry recitals tickle the creative minds of students.'),
              const SizedBox(height: 16),
              _aboutSection('Accommodation', 'More than 10 hostels are available within a 10-minute walk from the University that offer comfortable units with assured security throughout the semester.'),
              const SizedBox(height: 16),
              _aboutSection('Sports', 'We also pride ourselves in promoting a vast number of Sports that our students excel in. This includes football, netball, volleyball, basketball, darts, and acrobatics, among others. MMU supports teams in both National and University leagues with representation in football, netball, basketball, handball, and volleyball. We are currently expanding this to include table tennis, lawn tennis, badminton, among others.'),
              const SizedBox(height: 16),
              _aboutSection('Guidance & Counselling', 'The Guidance and Counseling unit is here to help you address personal or emotional challenges that may affect you while studying or working at MMU.'),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              const Text('v2.1.0 • Season 2026', style: TextStyle(color: AppColors.textMid, fontSize: 10)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.mmwGold)),
          ),
        ],
      ),
    );
  }

  Widget _aboutSection(String title, String body) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: AppColors.mmwGold, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        Text(body, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textMid, fontSize: 12, height: 1.5)),
      ],
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
    child: Text(label,
        style: const TextStyle(color: AppColors.textLight, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String sub,
    required Widget trailing,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.mmwNavy.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.mmwNavy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.mmwNavy, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(sub,
                        style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.textMid, fontSize: 11)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      );

  // ─── Shared Components ───────────────────────────────────────────────────────

  Widget _buildSlideshow(AppState appState, MatchState ms) {
    // Use generated fixtures (scheduled only, sorted by date) if available,
    // otherwise fall back to hardcoded demo slides.
    final upcoming = List<GeneratedFixture>.from(
      ms.generatedFixtures.where((f) => f.status == 'scheduled'),
    )..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final int slideCount = upcoming.isNotEmpty ? upcoming.length : _slides.length;
    // clamp _currentSlide to avoid index errors when slide count changes
    final int safeSlide = _currentSlide.clamp(0, slideCount - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Container(width: 3, height: 14, color: AppColors.mmwNavy),
              const SizedBox(width: 8),
              Text(appState.translate('upcoming_matches'),
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  )),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _currentSlide = i),
            itemCount: slideCount,
            itemBuilder: (_, i) {
              // ── DB-backed fixture slide ──
              if (upcoming.isNotEmpty) {
                final f = upcoming[i];
                final dt = f.dateTime;
                final matchday = 'Matchday ${i + 1}';
                final dateStr =
                    '${_weekday(dt.weekday)} ${dt.day} ${_month(dt.month)} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [AppColors.mmwNavy, Color(0xFF005A90)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: AppColors.mmwGold.withOpacity(0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.mmwGold,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(matchday,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                            Row(children: [
                              const Icon(Icons.location_on_rounded, color: Colors.white54, size: 12),
                              const SizedBox(width: 3),
                              Text(f.venue,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ]),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _teamBadge(f.homeTeam),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('VS',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1)),
                              ),
                            ),
                            _teamBadge(f.awayTeam),
                          ],
                        ),
                        const Spacer(),
                        Text('${f.homeTeam} vs ${f.awayTeam}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.access_time_rounded, color: Colors.white54, size: 12),
                          const SizedBox(width: 4),
                          Text(dateStr,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.6), fontSize: 11)),
                        ]),
                      ],
                    ),
                  ),
                );
              }

              // ── Fallback demo slide ──
              final s = _slides[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [AppColors.mmwNavy, Color(0xFF005A90)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppColors.mmwGold.withOpacity(0.35)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.mmwGold,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(s['date']!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: Colors.white54, size: 12),
                              const SizedBox(width: 3),
                              Text(s['venue']!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s['emoji']!.split('\u{1F19A}').first.trim(),
                              style: const TextStyle(fontSize: 32)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('VS',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1)),
                            ),
                          ),
                          Text(s['emoji']!.split('\u{1F19A}').last.trim(),
                              style: const TextStyle(fontSize: 32)),
                        ],
                      ),
                      const Spacer(),
                      Text(s['title']!,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: Colors.white54, size: 12),
                          const SizedBox(width: 4),
                          Text(s['sub']!,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.6), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            slideCount,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: safeSlide == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: safeSlide == i ? AppColors.mmwGold : Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Returns a team badge: shows the Supabase logo if available, otherwise initials.
  /// Flashes a green ring when the branding was recently updated.
  Widget _teamBadge(String team) {
    String? logoUrl;
    try {
      logoUrl = _liveTeams.firstWhere(
        (t) => (t['name'] as String?)?.toLowerCase() == team.toLowerCase(),
      )['logo_url'] as String?;
    } catch (_) {}

    final isUpdated = _recentlyUpdatedTeamName?.toLowerCase() == team.toLowerCase();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 48, height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isUpdated ? const Color(0xFF00A651) : Colors.transparent,
          width: isUpdated ? 3 : 0,
        ),
        boxShadow: isUpdated
            ? [BoxShadow(color: const Color(0xFF00A651).withOpacity(0.5), blurRadius: 10)]
            : null,
      ),
      child: logoUrl != null
          ? ClipOval(
              child: Image.network(
                logoUrl,
                width: 48, height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initialsCircle(team),
              ),
            )
          : _initialsCircle(team),
    );
  }

  Widget _initialsCircle(String team) {
    final initials = team.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join();
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(initials.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }

  String _weekday(int wd) => const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][wd];
  String _month(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  Widget _buildFeatureGrid(MatchState ms) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _featureCard(
                  icon: Icons.emoji_events_rounded,
                  iconColor: const Color(0xFFF5A500),
                  iconBg: const Color(0xFFFFF3CD),
                  label: 'Standings',
                  sub: 'League Table',
                  accentColor: const Color(0xFFF5A500),
                  onTap: () => setState(() => _currentIndex = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _featureCard(
                  icon: Icons.format_list_bulleted_rounded,
                  iconColor: AppColors.mmwGreen,
                  iconBg: const Color(0xFFD4F5E5),
                  label: 'Lineup',
                  sub: 'Formations',
                  accentColor: AppColors.mmwGreen,
                  onTap: () => _showLineupModal(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _featureCard(
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xFF1A7FD4),
                  iconBg: const Color(0xFFD6EAFF),
                  label: 'Fixtures',
                  sub: 'Schedule',
                  accentColor: const Color(0xFF1A7FD4),
                  onTap: () => _showFixturesModal(ms),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _featureCardWithImage(
                  imagePath: 'assets/images/san.jpeg',
                  label: 'Results',
                  sub: 'Scores',
                  accentColor: const Color(0xFFE53935),
                  onTap: () => _showResultsModal(ms),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String sub,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(sub,
                      style: const TextStyle(
                          color: AppColors.textMid, fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accentColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _featureCardWithImage({
    required String imagePath,
    required String label,
    required String sub,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEAEA),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(sub,
                      style: const TextStyle(
                          color: AppColors.textMid, fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accentColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingList(MatchState ms) {
    final upcoming = ms.generatedFixtures.where((f) => f.status == 'scheduled').take(3).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 14, color: AppColors.mmwGreen),
              const SizedBox(width: 8),
              const Text('NEXT FIXTURES',
                  style: TextStyle(
                      color: AppColors.textDark, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 12),
          ...upcoming.map(
            (f) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mmwNavy.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(f.homeTeam,
                        style: const TextStyle(
                            color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 13),
                        textAlign: TextAlign.right),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.mmwNavy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('vs',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Text(f.awayTeam,
                        style: const TextStyle(
                            color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePill(GeneratedFixture f, MatchState ms) {
    return GestureDetector(
      onTap: () => _showLiveModal(f, ms),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 20),
            BoxShadow(color: AppColors.mmwNavy.withOpacity(0.08), blurRadius: 10, offset: const Offset(0,4)),
          ],
        ),
        child: Row(
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 10),
            const Text('LIVE',
                style: TextStyle(
                    color: Colors.red, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${f.homeTeam.split(' ').first} ${f.homeScore} – ${f.awayScore} ${f.awayTeam.split(' ').first}',
                style: const TextStyle(
                    color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── Modals ──────────────────────────────────────────────────────────────────

  void _showLiveModal(GeneratedFixture f, MatchState ms) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'LIVE FEED',
        child: f.events.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Waiting for kick-off...',
                      style: TextStyle(color: Colors.white54)),
                ),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: f.events.reversed.take(6).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Text(_eventEmoji(e.type), style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.playerName.isEmpty ? e.team : e.playerName,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        Text("${e.minute}'",
                            style: const TextStyle(
                                color: Colors.white38, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                  ),
                ).toList(),
              ),
      ),
    );
  }

  void _showFixturesModal(MatchState ms) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'FULL SCHEDULE',
        child: ms.generatedFixtures.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No fixtures generated yet.', style: TextStyle(color: Colors.white54))),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: ms.generatedFixtures.map(
                  (f) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(f.homeTeam,
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('vs', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        ),
                        Expanded(
                          child: Text(f.awayTeam,
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        Text(
                          '${f.dateTime.hour.toString().padLeft(2, '0')}:${f.dateTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              color: AppColors.mmwGold, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ).toList(),
              ),
      ),
    );
  }

  void _showResultsModal(MatchState ms) {
    final res = ms.generatedFixtures.where((f) => f.status == 'completed').toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'MATCH RESULTS',
        child: res.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No results recorded.', style: TextStyle(color: Colors.white54))),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: res.map(
                  (f) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(f.homeTeam,
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.mmwNavy,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${f.homeScore} – ${f.awayScore}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: Text(f.awayTeam,
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ).toList(),
              ),
      ),
    );
  }

  void _showLineupModal(BuildContext context) {
    final ms = context.read<MatchState>();
    final liveF = ms.liveFixture;
    
    // Load lineups for the live fixture if available
    if (liveF != null && !ms.lineups.containsKey(liveF.id)) {
      ms.loadLineupsForFixture(liveF.id);
    }
    
    final homeLineup = liveF != null ? ms.lineups[liveF.id]?.where((p) => p.team == liveF.homeTeam).toList() : null;
    final awayLineup = liveF != null ? ms.lineups[liveF.id]?.where((p) => p.team == liveF.awayTeam).toList() : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DefaultTabController(
        length: 2,
        child: _GlassSheet(
          title: 'LINEUPS',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                indicatorColor: AppColors.mmwGold,
                labelColor: AppColors.mmwGold,
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(text: liveF?.homeTeam.toUpperCase() ?? 'HOME'),
                  Tab(text: liveF?.awayTeam.toUpperCase() ?? 'AWAY')
                ],
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: TabBarView(
                  children: [
                    _buildSingleTeamLineup(context, liveF?.homeTeam ?? 'HOME', '4-3-3', AppColors.mmwNavy, _homePinsFull, true, homeLineup),
                    _buildSingleTeamLineup(context, liveF?.awayTeam ?? 'AWAY', '4-4-2', AppColors.mmwGreen, _awayPinsFull, false, awayLineup),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleTeamLineup(
    BuildContext context,
    String team,
    String formation,
    Color color,
    List<_PinAbs> fallbackPins,
    bool isHome,
    List<LineupPlayer>? actualLineup,
  ) {
    final starters = actualLineup?.where((p) => !p.isSubstituted).toList();
    final bench = actualLineup?.where((p) => p.isSubstituted).toList();

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (c, box) {
              if (starters != null && starters.isNotEmpty) {
                // Use actual lineup if available
                final formationsMap = {
                  '4-3-3': [
                    Offset(0.5, 0.88),
                    Offset(0.15, 0.70), Offset(0.38, 0.72), Offset(0.62, 0.72), Offset(0.85, 0.70),
                    Offset(0.25, 0.48), Offset(0.5, 0.46), Offset(0.75, 0.48),
                    Offset(0.15, 0.20), Offset(0.5, 0.16), Offset(0.85, 0.20),
                  ],
                  '4-4-2': [
                    Offset(0.5, 0.88),
                    Offset(0.15, 0.70), Offset(0.38, 0.72), Offset(0.62, 0.72), Offset(0.85, 0.70),
                    Offset(0.15, 0.50), Offset(0.38, 0.48), Offset(0.62, 0.48), Offset(0.85, 0.50),
                    Offset(0.35, 0.22), Offset(0.65, 0.22),
                  ],
                };
                final posList = formationsMap[formation] ?? formationsMap['4-3-3']!;
                
                return Stack(
                  children: [
                    CustomPaint(size: Size(box.maxWidth, box.maxHeight), painter: _PitchPainter()),
                    ...starters.asMap().entries.map((e) {
                      if (e.key >= posList.length) return const SizedBox.shrink();
                      final p = starters[e.key];
                      final offset = posList[e.key];
                      return _pin(p.name, p.jerseyNo, offset.dx * box.maxWidth,
                          offset.dy * box.maxHeight, isHome, p.hasYellow, p.hasRed, p.photoUrl, p.position);
                    }),
                  ],
                );
              }

              // Show message when no lineup is available instead of fallback data
              return Stack(
                children: [
                  CustomPaint(
                      size: Size(box.maxWidth, box.maxHeight),
                      painter: _PitchPainter()),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.group_off_rounded,
                            color: Colors.white70,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Squad Not Submitted',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Coach hasn\'t submitted the lineup yet',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SUBSTITUTES',
                  style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (bench != null && bench.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: bench.map((p) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _subPill('${p.jerseyNo}', p.name, p.photoUrl),
                    )).toList(),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  child: const Text(
                    'No substitutes available',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subPill(String num, String name, String? photoUrl) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        if (photoUrl != null && photoUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: CircleAvatar(radius: 8, backgroundImage: NetworkImage(photoUrl)),
          ),
        Text('#$num',
            style: const TextStyle(color: AppColors.mmwGold, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text(name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    ),
  );

  Widget _pin(String name, int num, double dx, double dy, bool isHome, bool yellow, bool red, String? photoUrl, String position) {
    return Positioned(
      left: dx - 16,
      top: dy - 32,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHome ? AppColors.mmwNavy : AppColors.mmwGreen,
              border: red
                  ? Border.all(color: Colors.red, width: 2.5)
                  : (yellow ? Border.all(color: Colors.amber, width: 2.5) : null),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
            ),
            child: Stack(alignment: Alignment.center, children: [
              ClipOval(
                child: (photoUrl != null && photoUrl.isNotEmpty)
                  ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(
                      child: Text('$num',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ))
                  : Center(
                      child: Text('$num',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
              ),
              // Position Badge
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.mmwNavy,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white, width: 0.5),
                  ),
                  child: Text(position, style: const TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 2),
          Text(
            name.split(' ').first,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  String _eventEmoji(String t) {
    const m = {
      'goal': '⚽', 'yellow': '🟡', 'red': '🔴', 'assist': '🅰️', 'sub': '↔️',
    };
    return m[t] ?? '📋';
  }

  List<StandingEntry> _demoStandings() {
    final teams = [
      'Lions FC', 'Blue Sharks', 'Red Eagles', 'City Wolves',
      'Green Foxes', 'Panthers', 'Yellow Stars', 'Purple Knights'
    ];
    final data = [
      [27, 8, 18, 27], [23, 7, 12, 23], [22, 6, 8, 22], [20, 5, 6, 20],
      [17, 5, 2, 17], [15, 4, -2, 15], [13, 3, -6, 13], [8, 2, -18, 8],
    ];
    return List.generate(teams.length, (i) {
      final s = StandingEntry(teams[i]);
      s.points = data[i][3];
      s.wins = data[i][1];
      s.goalsFor = data[i][2];
      s.goalsAgainst = 0;
      s.played = 12;
      return s;
    });
  }
}

// ─── Support Models ───────────────────────────────────────────────────────────

class _PinAbs {
  final String name;
  final int jerseyNo;
  final double ratioX, ratioY;
  final bool yellow, red;
  final String? photoUrl;
  final String position;
  _PinAbs(this.name, this.jerseyNo, this.ratioX, this.ratioY, this.yellow, this.red, {this.photoUrl, this.position = '??'});
}

class _Pin {
  final String name;
  final int jerseyNo;
  final double ratioX, ratioY;
  final bool yellow, red;
  final String? photoUrl;
  final String position;
  const _Pin(this.name, this.jerseyNo, this.ratioX, this.ratioY,
      {this.yellow = false, this.red = false, this.photoUrl, this.position = '??'});
}

final _homePinsFull = [
  const _Pin('Safe', 1, 0.50, 0.88),
  const _Pin('A', 3, 0.15, 0.72),
  const _Pin('B', 5, 0.38, 0.73),
  const _Pin('C', 6, 0.62, 0.73),
  const _Pin('D', 2, 0.85, 0.72),
  const _Pin('E', 8, 0.30, 0.52),
  const _Pin('F', 10, 0.50, 0.48, yellow: true),
  const _Pin('G', 4, 0.70, 0.52),
  const _Pin('H', 11, 0.18, 0.28),
  const _Pin('I', 9, 0.50, 0.22),
  const _Pin('J', 7, 0.82, 0.28),
].map((p) => _PinAbs(p.name, p.jerseyNo, p.ratioX, p.ratioY, p.yellow, p.red)).toList();

final _awayPinsFull = [
  const _Pin('Keeper', 1, 0.50, 0.88),
  const _Pin('X', 3, 0.15, 0.75),
  const _Pin('Y', 4, 0.38, 0.75),
  const _Pin('Z', 5, 0.62, 0.75),
  const _Pin('W', 2, 0.85, 0.75),
  const _Pin('M', 6, 0.35, 0.55),
  const _Pin('N', 8, 0.65, 0.55),
  const _Pin('O', 10, 0.50, 0.40, yellow: true),
  const _Pin('P', 11, 0.20, 0.22),
  const _Pin('Q', 9, 0.50, 0.18, red: true),
  const _Pin('R', 7, 0.80, 0.22),
].map((p) => _PinAbs(p.name, p.jerseyNo, p.ratioX, p.ratioY, p.yellow, p.red)).toList();

// ─── Glass Bottom Sheet ───────────────────────────────────────────────────────
class _GlassSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _GlassSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16,
                          letterSpacing: 0.5)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(child: child),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Pitch Painter ────────────────────────────────────────────────────────────
class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.greenDark, Color(0xFF004D20)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), base);

    // Alternating stripes
    for (int i = 0; i < 10; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * h / 10, w, h / 20),
        Paint()..color = Colors.white.withOpacity(0.025),
      );
    }

    final line = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.05, 20, w * 0.9, h - 40), const Radius.circular(4)), line);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.12, line);
    canvas.drawLine(Offset(w * 0.05, h / 2), Offset(w * 0.95, h / 2), line);
    canvas.drawRect(Rect.fromLTWH(w * 0.25, 20, w * 0.5, h * 0.18), line);
    canvas.drawRect(Rect.fromLTWH(w * 0.25, h - h * 0.18 - 20, w * 0.5, h * 0.18), line);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Navy Pattern Painter (hero background) ───────────────────────────────────
class _NavyPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.5),
        50.0 + i * 40,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Swipe-To-Reply Wrapper (WhatsApp style) ─────────────────────────────────
class _SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool isMe;

  const _SwipeToReplyWrapper({
    required this.child,
    required this.onReply,
    required this.isMe,
  });

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _triggered = false;
  static const double _threshold = 60.0;
  static const double _maxDrag = 80.0;

  late AnimationController _snapCtrl;
  late Animation<double> _snapAnim;
  double _snapFrom = 0;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _snapAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOut),
    );
    _snapCtrl.addListener(() => setState(() => _dragOffset = _snapAnim.value));
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onHorizontalUpdate(DragUpdateDetails d) {
    if (_snapCtrl.isAnimating) return;
    setState(() {
      _dragOffset = (_dragOffset + d.delta.dx).clamp(0.0, _maxDrag);
      if (!_triggered && _dragOffset >= _threshold) {
        _triggered = true;
      }
    });
  }

  void _onHorizontalEnd(DragEndDetails _) {
    if (_triggered) {
      widget.onReply();
      _triggered = false;
    }
    // Snap back to 0
    _snapFrom = _dragOffset;
    _snapAnim = Tween<double>(begin: _snapFrom, end: 0).animate(
      CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOut),
    );
    _snapCtrl.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final iconOpacity = (_dragOffset / _threshold).clamp(0.0, 1.0);
    final iconScale = 0.6 + 0.4 * iconOpacity;

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalUpdate,
      onHorizontalDragEnd: _onHorizontalEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reply icon that appears behind the bubble
          Positioned(
            left: -28,
            top: 0,
            bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: iconOpacity,
                duration: const Duration(milliseconds: 80),
                child: Transform.scale(
                  scale: iconScale,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.mmwNavy.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.reply_rounded,
                      color: AppColors.mmwNavy,
                      size: 17,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The actual message bubble, shifted right by drag
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
