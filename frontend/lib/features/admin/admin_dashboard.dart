import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';
import './widgets/dashboard_components.dart';
import './fixture_generator.dart';
import '../../core/state/match_state.dart';
import '../../core/state/app_state.dart';
import '../../core/auth/auth_provider.dart' as auth;
import '../../shared/officials_chat.dart';

// ─── Enhanced Data models ────────────────────────────────────────────────────

class _Notification {
  final String id, title, message, type;
  final DateTime timestamp;
  final bool isRead;
  const _Notification(this.id, this.title, this.message, this.type, this.timestamp, this.isRead);
}

class _Team {
  final String name;
  final int wins, draws, losses, points;
  final String status;
  const _Team(this.name, this.wins, this.draws, this.losses, this.points, this.status);
}

class _Player {
  final String name, team;
  final int goals, assists;
  const _Player(this.name, this.team, this.goals, this.assists);
}

class _Coach {
  final String name, email, team;
  const _Coach(this.name, this.email, this.team);
}

class _Referee {
  final String name, email, phone;
  const _Referee(this.name, this.email, this.phone);
}

class _Fixture {
  final String homeTeam, awayTeam, venue, referee;
  final DateTime dateTime;
  const _Fixture(this.homeTeam, this.awayTeam, this.venue, this.referee, this.dateTime);
}

// ─── Enhanced Admin Dashboard ─────────────────────────────────────────────────

// ─── Enhanced Notifications Data ──────────────────────────────────────────────
// Real notifications will be loaded from Supabase
final List<_Notification> _initialNotifications = [];

// ─── Dummy Data for Fallback ──────────────────────────────────────────────────
final List<_Team> _teams = [
  const _Team('Lions FC', 8, 2, 1, 26, 'Active'),
  const _Team('Blue Sharks', 7, 3, 1, 24, 'Active'),
  const _Team('Red Eagles', 6, 4, 1, 22, 'Active'),
  const _Team('Green Foxes', 5, 3, 3, 18, 'Active'),
  const _Team('Yellow Stars', 4, 4, 3, 16, 'Active'),
  const _Team('Black Panthers', 3, 5, 3, 14, 'Active'),
  const _Team('Purple Knights', 2, 4, 5, 10, 'Active'),
  const _Team('City Wolves', 1, 3, 7, 6, 'Active'),
];

final List<_Player> _players = [
  const _Player('John Doe', 'Lions FC', 12, 5),
  const _Player('Mike Smith', 'Blue Sharks', 10, 8),
  const _Player('David Wilson', 'Red Eagles', 9, 6),
  const _Player('Chris Brown', 'Green Foxes', 8, 4),
  const _Player('Alex Johnson', 'Yellow Stars', 7, 7),
  const _Player('Sam Davis', 'Black Panthers', 6, 3),
  const _Player('Tom Miller', 'Purple Knights', 5, 5),
  const _Player('Jake Wilson', 'City Wolves', 4, 2),
];

final List<_Coach> _coaches = [
  const _Coach('Robert Martinez', 'robert@mmu.ac.ke', 'Lions FC'),
  const _Coach('Sarah Johnson', 'sarah@mmu.ac.ke', 'Blue Sharks'),
  const _Coach('Michael Brown', 'michael@mmu.ac.ke', 'Red Eagles'),
  const _Coach('Lisa Davis', 'lisa@mmu.ac.ke', 'Green Foxes'),
];

final List<_Referee> _referees = [
  const _Referee('James Wilson', 'james@mmu.ac.ke', '+254700123456'),
  const _Referee('Mary Smith', 'mary@mmu.ac.ke', '+254700123457'),
  const _Referee('Peter Jones', 'peter@mmu.ac.ke', '+254700123458'),
];

final List<_Fixture> _fixtures = [
  _Fixture('Lions FC', 'Blue Sharks', 'Main Stadium', 'James Wilson', DateTime.now().add(const Duration(days: 7))),
  _Fixture('Red Eagles', 'Green Foxes', 'Sports Complex', 'Mary Smith', DateTime.now().add(const Duration(days: 14))),
  _Fixture('Yellow Stars', 'Black Panthers', 'Main Stadium', 'Peter Jones', DateTime.now().add(const Duration(days: 21))),
];

// ─── Admin Dashboard ──────────────────────────────────────────────────────────

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  String _activeSection = 'dashboard';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ─── Enhanced State Management ─────────────────────────────────────────────
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _dynamicCoaches = [];
  List<Map<String, dynamic>> _dynamicReferees = [];
  List<Map<String, dynamic>> _dynamicTeams = [];
  List<Map<String, dynamic>> _dynamicPlayers = [];
  // ─── Real-time Data ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _submittedSquads = [];
  List<Map<String, dynamic>> _venues = [];
  List<_Notification> _liveNotifications = List.from(_initialNotifications);
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;
  List<Map<String, dynamic>> _leagues = [];
  
  // Real-time match data
  List<Map<String, dynamic>> _liveMatches = [];
  List<Map<String, dynamic>> _recentResults = [];
  StreamSubscription<List<Map<String, dynamic>>>? _matchesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _fixturesSubscription;
  
  // ─── Search Controllers ────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ─── Sort State (per table) ──────────────────────────────────────────────────
  String _coachesSortCol  = 'name';   bool _coachesSortAsc  = true;
  String _refereesSortCol = 'name';   bool _refereesSortAsc = true;
  String _playersSortCol  = 'name';   bool _playersSortAsc  = true;
  String _teamsSortCol    = 'name';   bool _teamsSortAsc    = true;
  String _approvalsSortCol= 'name';   bool _approvalsSortAsc= true;
  String _venuesSortCol   = 'name';   bool _venuesSortAsc   = true;
  // Role filter for approvals
  String _approvalsRoleFilter = 'all';

  // ─── Loading States ─────────────────────────────────────────────────────────
  bool _isLoadingPending = false;
  bool _isLoadingManagement = false;
  bool _isLoadingSquads = false;
  bool _isLoadingVenues = false;
  bool _isLoadingLeagues = false;
  bool _isLoadingNotifications = false;
  
  // ─── UI State ───────────────────────────────────────────────────────────────
  final Set<String> _expandedSquads = {};
  bool _showNotificationPanel = false;
  String _selectedNotificationFilter = '';
  
  // ─── Profile Enhancement ────────────────────────────────────────────────────
  Uint8List? _selectedProfileImage;
  bool _isUploadingProfile = false;

  // ─ Realtime team branding stream ──────────────────────────────────────────
  StreamSubscription<List<Map<String, dynamic>>>? _teamsStreamSub;
  String? _recentlyUpdatedTeamId; // used to flash-highlight changed team

  // ─── Settings State ─────────────────────────────────────────────────────────
  bool _settingEmailNotifications = true;
  bool _settingAutoApproveSpectators = true;
  bool _settingMaintenanceMode = false;
  bool _settingAllowRegistrations = true;
  bool _settingsSaving = false;
  final _seasonNameCtrl = TextEditingController(text: 'MMU Soccer League 2026');
  final _seasonStartCtrl = TextEditingController(text: '01 Jan 2026');
  final _seasonEndCtrl = TextEditingController(text: '30 Jun 2026');

  Future<void> _fetchPending() async {
    if (!mounted) return;
    setState(() => _isLoadingPending = true);
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    final users = await ap.getPendingUsers();
    if (mounted) {
      setState(() {
        _pending = users;
        _isLoadingPending = false;
      });
      // Sync pending users as notifications so the bell & notification centre reflect them
      await _syncPendingAsNotifications(users);
    }
  }

  /// Inserts a notification row for each pending user that doesn't yet have one,
  /// ensuring the notification centre always reflects the Approvals sidebar badge.
  Future<void> _syncPendingAsNotifications(List<Map<String, dynamic>> pending) async {
    if (pending.isEmpty) return;
    try {
      final db = Supabase.instance.client;
      for (final user in pending) {
        final uid  = user['id'] as String? ?? '';
        final name = (user['full_name'] as String?) ?? 'Unknown';
        final role = (user['role'] as String?) ?? 'user';

        // Check if a notification for this user already exists
        final existing = await db
            .from('notifications')
            .select('id')
            .eq('type', 'approval')
            .ilike('title', '%$uid%')
            .limit(1);

        if ((existing as List).isEmpty) {
          await db.from('notifications').insert({
            'recipient_id': null, // admin-only broadcast
            'title': '[$uid] New ${role[0].toUpperCase()}${role.substring(1)} Registration',
            'body': '$name has registered as a $role and is awaiting your approval.',
            'type': 'approval',
            'is_read': false,
          });
        }
      }
      // Reload notifications so the bell badge and panel update
      await _loadNotifications();
    } catch (e) {
      debugPrint('_syncPendingAsNotifications error: $e');
    }
  }

  Future<void> _fetchManagementData() async {
    if (!mounted) return;
    setState(() => _isLoadingManagement = true);
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    
    final coaches = await ap.getApprovedUsers('coach');
    final referees = await ap.getApprovedUsers('referee');
    final teams = await ap.getTeams();
    final players = await ap.getPlayers();

    if (mounted) {
      setState(() {
        _dynamicCoaches = coaches;
        _dynamicReferees = referees;
        _dynamicTeams = teams;
        _dynamicPlayers = players;
        _isLoadingManagement = false;
      });
    }
  }

  Future<void> _fetchSquadSubmissions() async {
    if (!mounted) return;
    setState(() => _isLoadingSquads = true);
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    final squads = await ap.getSubmittedSquads();
    if (mounted) setState(() { _submittedSquads = squads; _isLoadingSquads = false; });
  }

  Future<void> _fetchVenues() async {
    if (!mounted) return;
    setState(() => _isLoadingVenues = true);
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    final v = await ap.getVenues();
    if (mounted) setState(() { _venues = v; _isLoadingVenues = false; });
  }

  // ─── Real-time Notifications Loading ────────────────────────────────────────
  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() => _isLoadingNotifications = true);
    
    try {
      // Load existing notifications
      final response = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);
      
      final notifications = (response as List).map((row) => _Notification(
        row['id'].toString(),
        row['title'] as String,
        row['body'] as String,
        row['type'] as String,
        DateTime.parse(row['created_at'] as String),
        row['is_read'] as bool? ?? false, // Fixed: use is_read instead of read
      )).toList();
      
      if (mounted) {
        setState(() {
          _liveNotifications = notifications;
          _isLoadingNotifications = false;
        });
      }
      
      // Set up real-time subscription for new notifications
      _notificationSubscription = Supabase.instance.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(50)
          .listen((data) {
        if (!mounted) return;
        final notifications = data.map((row) => _Notification(
          row['id'].toString(),
          row['title'] as String,
          row['body'] as String,
          row['type'] as String,
          DateTime.parse(row['created_at'] as String),
          row['is_read'] as bool? ?? false, // Fixed: use is_read instead of read
        )).toList();
        
        setState(() => _liveNotifications = notifications);
      });
      
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) setState(() => _isLoadingNotifications = false);
    }
  }

  // ─── Send Notification ──────────────────────────────────────────────────────
  Future<void> _sendNotification({
    required String title,
    required String message,
    required String type,
    String? userId,
  }) async {
    try {
      await Supabase.instance.client.from('notifications').insert({
        'recipient_id': userId, // Fixed: use recipient_id instead of user_id
        'title': title,
        'body': message,
        'type': type,
        'is_read': false, // Fixed: use is_read instead of read
        'related_table': null,
        'related_id': null,
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  // ─── Real-time Match Data Loading ───────────────────────────────────────────
  Future<void> _loadLiveMatches() async {
    try {
      // Load live matches from scheduled_matches table
      final response = await Supabase.instance.client
          .from('scheduled_matches')
          .select('*')
          .eq('status', 'live')
          .order('date_time', ascending: false);
      
      if (mounted) {
        setState(() => _liveMatches = List<Map<String, dynamic>>.from(response));
      }
      
      // Set up real-time subscription for live matches
      _matchesSubscription = Supabase.instance.client
          .from('scheduled_matches')
          .stream(primaryKey: ['id'])
          .eq('status', 'live')
          .listen((data) {
        if (!mounted) return;
        setState(() => _liveMatches = data);
      });
      
    } catch (e) {
      debugPrint('Error loading live matches: $e');
    }
  }

  Future<void> _loadRecentResults() async {
    try {
      // Load recent completed matches
      final response = await Supabase.instance.client
          .from('scheduled_matches')
          .select('*')
          .eq('status', 'completed')
          .order('date_time', ascending: false)
          .limit(10);
      
      if (mounted) {
        setState(() => _recentResults = List<Map<String, dynamic>>.from(response));
      }
      
      // Set up real-time subscription for completed matches
      _fixturesSubscription = Supabase.instance.client
          .from('scheduled_matches')
          .stream(primaryKey: ['id'])
          .eq('status', 'completed')
          .order('date_time', ascending: false)
          .limit(10)
          .listen((data) {
        if (!mounted) return;
        setState(() => _recentResults = data);
      });
      
    } catch (e) {
      debugPrint('Error loading recent results: $e');
    }
  }

  String _sectionTitle(String id) {
    const map = {
      'dashboard': 'Dashboard', 'approvals': 'Pending Approvals', 'notifications': 'Notifications',
      'communications': 'Communications',
      'fixtures': 'Fixtures', 'venues': 'Venues', 'leagues': 'Leagues', 'standings': 'Standings', 'results': 'Match Results',
      'squad_approvals': 'Squad Approvals',
      'teams': 'Teams', 'players': 'Players', 'coaches': 'Coaches', 'referees': 'Referees',
      'player_stats': 'Player Statistics', 'season_report': 'MMU Report Centre', 'live_scores': 'Live Scores',
      'profile': 'My Profile', 'settings': 'Settings',
    };
    return map[id] ?? id;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    
    // Fetch initial data
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    ap.fetchProfile(); 
    _fetchPending();
    _fetchManagementData();
    _fetchSquadSubmissions();
    _fetchVenues();
    _fetchLeagues();
    _loadNotifications();
    _loadLiveMatches();
    _loadRecentResults();

    // ─ Supabase Realtime: subscribe to teams table for live branding updates ─
    _teamsStreamSub = Supabase.instance.client
        .from('teams')
        .stream(primaryKey: ['id'])
        .listen((rows) {
      if (!mounted) return;
      final previous = {for (final t in _dynamicTeams) t['id'] as String: t};
      setState(() => _dynamicTeams = rows);
      // Detect which team changed logo or name
      for (final row in rows) {
        final id = row['id'] as String?;
        if (id == null) continue;
        final prev = previous[id];
        if (prev == null) continue;
        if (prev['name'] != row['name'] || prev['logo_url'] != row['logo_url']) {
          setState(() => _recentlyUpdatedTeamId = id);
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _recentlyUpdatedTeamId = null);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _teamsStreamSub?.cancel();
    _notificationSubscription?.cancel();
    _matchesSubscription?.cancel();
    _fixturesSubscription?.cancel();
    _animController.dispose();
    _searchController.dispose();
    _seasonNameCtrl.dispose();
    _seasonStartCtrl.dispose();
    _seasonEndCtrl.dispose();
    super.dispose();
  }

  void _navigate(String id) {
    setState(() => _activeSection = id);
    _animController.reset();
    _animController.forward();
    if (id == 'dashboard' || id == 'approvals') _fetchPending();
    if (['coaches', 'referees', 'teams', 'players'].contains(id)) _fetchManagementData();
    if (id == 'squad_approvals') _fetchSquadSubmissions();
    if (id == 'venues' || id == 'fixtures') _fetchVenues();
    if (id == 'leagues') _fetchLeagues();
    if (id == 'live_scores' || id == 'dashboard') {
      _loadLiveMatches();
      _loadRecentResults();
    }
    if (id == 'notifications') _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWrapper.isMobile(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // MMU light grey background
      drawer: isMobile ? DashboardSidebar(activeId: _activeSection, onNav: _navigate, pendingCount: _pending.length) : null,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Row(children: [
            if (!isMobile)
              SizedBox(width: 240, child: DashboardSidebar(activeId: _activeSection, onNav: _navigate, pendingCount: _pending.length)),
            Expanded(
              child: Column(children: [
                _buildEnhancedHeader(),
                Expanded(child: _buildSection()),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSection() {
    switch (_activeSection) {
      case 'approvals': return _buildApprovals();
      case 'squad_approvals': return _buildSquadApprovals();
      case 'fixtures': return _buildFixtures();
      case 'venues': return _buildVenues();
      case 'leagues': return _buildLeagues();
      case 'standings': return _buildStandings();
      case 'results': return _buildResults();
      case 'teams': return _buildTeams();
      case 'players': return _buildPlayers();
      case 'coaches': return _buildCoaches();
      case 'referees': return _buildReferees();
      case 'player_stats': return _buildPlayerStats();
      case 'season_report': return _buildSeasonReport();
      case 'live_scores': return _buildLiveScores();
      case 'notifications': return _buildNotifications();
      case 'communications': return const OfficialsChatWidget();
      case 'profile': return _buildProfile();
      case 'settings': return _buildSettings();
      default: return _buildDashboardHome();
    }
  }

  // ─── Enhanced Header with Search & Notifications ──────────────────────────────
  Widget _buildEnhancedHeader() {
    final isMobile = ResponsiveWrapper.isMobile(context);
    final unreadCount = _liveNotifications.where((n) => !n.isRead).length;
    
    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 16, isMobile ? 12 : 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        if (isMobile)
          SizedBox(
            width: 48,
            height: 48,
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF003087), size: 24),
                onPressed: () => Scaffold.of(context).openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        
        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _sectionTitle(_activeSection),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF001A4D)),
                overflow: TextOverflow.ellipsis,
              ),
              if (!isMobile)
                Text('MMU Sports Management Console',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
        
        // Search Bar (for applicable sections, hidden on mobile)
        if (_shouldShowSearch() && !isMobile)
          Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: _getSearchHint(),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        
        // Notifications Bell
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded, color: Color(0xFF003087), size: 24),
                onPressed: () => setState(() => _showNotificationPanel = !_showNotificationPanel),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$unreadCount', 
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Profile Menu
        _buildProfileMenu(),
      ]),
    );
  }

  bool _shouldShowSearch() {
    return ['teams', 'players', 'coaches', 'referees', 'venues', 'leagues', 'approvals', 'notifications'].contains(_activeSection);
  }

  String _getSearchHint() {
    switch (_activeSection) {
      case 'teams': return 'Search teams...';
      case 'players': return 'Search players...';
      case 'coaches': return 'Search coaches...';
      case 'referees': return 'Search referees...';
      case 'venues': return 'Search venues...';
      case 'leagues': return 'Search leagues...';
      case 'approvals': return 'Search pending approvals...';
      case 'notifications': return 'Search notifications...';
      default: return 'Search...';
    }
  }

  Widget _buildProfileMenu() {
    final ap = Provider.of<auth.AuthProvider>(context);
    final profile = ap.profile;
    final avatarUrl = profile?['avatar_url'];
    final fullName = profile?['full_name'] ?? 'Admin';

    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'profile':
            _navigate('profile');
            break;
          case 'settings':
            _navigate('settings');
            break;
          case 'logout':
            _showLogoutDialog();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(children: [
            const Icon(Icons.person_rounded, size: 18, color: Color(0xFF003087)),
            const SizedBox(width: 12),
            const Text('My Profile'),
          ]),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(children: [
            const Icon(Icons.settings_rounded, size: 18, color: Colors.grey),
            const SizedBox(width: 12),
            const Text('Settings'),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout_rounded, size: 18, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Text('Sign Out', style: TextStyle(color: Colors.red.shade600)),
          ]),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF003087).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF003087),
            backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null || avatarUrl.toString().isEmpty
                ? Text(fullName[0].toUpperCase(), 
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 8),
          Text(fullName.split(' ').first, 
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF003087))),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF003087), size: 18),
        ]),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final ap = Provider.of<auth.AuthProvider>(context, listen: false);
              ap.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  // ─── Enhanced Notifications ─────────────────────────────────────────────────
  Widget _buildNotifications() {
    final filteredNotifications = _searchQuery.isEmpty 
        ? _liveNotifications
        : _liveNotifications.where((n) => 
            n.title.toLowerCase().contains(_searchQuery) ||
            n.message.toLowerCase().contains(_searchQuery) ||
            n.type.toLowerCase().contains(_searchQuery)
          ).toList();

    return Stack(children: [
      RefreshIndicator(
        onRefresh: () async {
          setState(() => _isLoadingNotifications = true);
          // Simulate API call
          await Future.delayed(const Duration(seconds: 1));
          setState(() => _isLoadingNotifications = false);
        },
        color: const Color(0xFF003087),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Header with actions
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF003087).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_rounded, color: Color(0xFF003087)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${_liveNotifications.where((n) => !n.isRead).length} unread notifications',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ]),
              ),
              TextButton.icon(
                onPressed: () async {
                  try {
                    // Update all unread notifications in database
                    await Supabase.instance.client
                        .from('notifications')
                        .update({'is_read': true})
                        .eq('is_read', false);
                    
                    // Update local state
                    setState(() {
                      for (int i = 0; i < _liveNotifications.length; i++) {
                        final notification = _liveNotifications[i];
                        _liveNotifications[i] = _Notification(
                          notification.id, notification.title, notification.message, 
                          notification.type, notification.timestamp, true
                        );
                      }
                    });
                  } catch (e) {
                    debugPrint('Error marking all notifications as read: $e');
                  }
                },
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('Mark All Read'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF003087)),
              ),
            ]),
            const SizedBox(height: 16),
            
            // Notification filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _notificationFilter('All', ''),
                _notificationFilter('Approvals', 'approval'),
                _notificationFilter('Matches', 'match'),
                _notificationFilter('Squads', 'squad'),
                _notificationFilter('System', 'system'),
                _notificationFilter('Venues', 'venue'),
              ]),
            ),
            const SizedBox(height: 16),
            
            // Notifications list
            if (_isLoadingNotifications)
              const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF003087)),
              ))
            else if (filteredNotifications.isEmpty)
              _emptyState(Icons.notifications_none_rounded, 'No Notifications', 
                         _searchQuery.isEmpty ? 'You\'re all caught up!' : 'No notifications match your search.')
            else
              ...filteredNotifications.map((notification) => _buildNotificationCard(notification)),
          ],
        ),
      ),
      
      // Floating notification panel
      if (_showNotificationPanel)
        Positioned(
          top: 0, right: 24,
          child: _buildNotificationPanel(),
        ),
    ]);
  }

  Widget _notificationFilter(String label, String type) {
    final isSelected = _selectedNotificationFilter == type;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedNotificationFilter = selected ? type : '');
        },
        selectedColor: const Color(0xFF003087).withOpacity(0.1),
        checkmarkColor: const Color(0xFF003087),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF003087) : Colors.grey.shade600,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(_Notification notification) {
    final typeColors = {
      'approval': Colors.orange,
      'match': Colors.green,
      'squad': Colors.blue,
      'system': Colors.purple,
      'venue': Colors.teal,
    };
    
    final typeIcons = {
      'approval': Icons.pending_actions_rounded,
      'match': Icons.sports_soccer_rounded,
      'squad': Icons.group_rounded,
      'system': Icons.settings_rounded,
      'venue': Icons.stadium_rounded,
    };

    final color = typeColors[notification.type] ?? Colors.grey;
    final icon = typeIcons[notification.type] ?? Icons.notifications_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.isRead ? Colors.grey.shade200 : color.withOpacity(0.3),
          width: notification.isRead ? 1 : 2,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
            ]),
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatNotificationTime(notification.timestamp),
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
              ),
            ),
          ]),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'mark_read':
                _markNotificationAsRead(notification.id);
                break;
              case 'delete':
                _deleteNotification(notification.id);
                break;
            }
          },
          itemBuilder: (context) => [
            if (!notification.isRead)
              PopupMenuItem(
                value: 'mark_read',
                child: Row(children: [
                  const Icon(Icons.done_rounded, size: 16),
                  const SizedBox(width: 8),
                  const Text('Mark as Read'),
                ]),
              ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_rounded, size: 16, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red.shade600)),
              ]),
            ),
          ],
          child: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400, size: 18),
        ),
      ]),
    );
  }

  Widget _buildNotificationPanel() {
    final unreadNotifications = _liveNotifications.where((n) => !n.isRead).take(5).toList();
    
    return Container(
      width: 320,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Panel header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF003087).withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            const Icon(Icons.notifications_rounded, color: Color(0xFF003087)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Recent Notifications', style: TextStyle(fontWeight: FontWeight.bold))),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setState(() => _showNotificationPanel = false),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ]),
        ),
        
        // Notifications list
        if (unreadNotifications.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Column(children: [
              Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('All caught up!', style: TextStyle(color: Colors.grey)),
            ]),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: unreadNotifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final notification = unreadNotifications[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF003087).withOpacity(0.1),
                    child: Icon(Icons.notifications_rounded, size: 16, color: const Color(0xFF003087)),
                  ),
                  title: Text(notification.title, 
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(notification.message, 
                      style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text(_formatNotificationTime(notification.timestamp),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  onTap: () {
                    setState(() => _showNotificationPanel = false);
                    _navigate('notifications');
                  },
                );
              },
            ),
          ),
        
        // View all button
        if (unreadNotifications.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: TextButton(
              onPressed: () {
                setState(() => _showNotificationPanel = false);
                _navigate('notifications');
              },
              child: const Text('View All Notifications'),
            ),
          ),
      ]),
    );
  }

  String _formatNotificationTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  void _markNotificationAsRead(String id) async {
    try {
      // Update in database
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
      
      // Update local state
      setState(() {
        final index = _liveNotifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          final notification = _liveNotifications[index];
          _liveNotifications[index] = _Notification(
            notification.id, notification.title, notification.message,
            notification.type, notification.timestamp, true,
          );
        }
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  void _deleteNotification(String id) async {
    try {
      // Delete from database
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', id);
      
      // Update local state
      setState(() {
        _liveNotifications.removeWhere((n) => n.id == id);
      });
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }
  Widget _buildDashboardHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildWelcomeBanner(),
        const SizedBox(height: 24),
        _buildStatsGrid(),
        const SizedBox(height: 24),
        _buildSeasonGauge(),
        const SizedBox(height: 24),
        _buildChartsRow(),
        const SizedBox(height: 24),
        _buildBottomRow(),
      ]),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF001A4D), Color(0xFF003087), Color(0xFF1A4FA0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: const Color(0xFF003087).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Welcome Back, Admin 👋', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('MMU Soccer League — Season 2026 is live.', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _tappablePill('⚽ ${_liveMatches.length} Live Matches', 'live_scores'),
            _tappablePill('🏆 2 Leagues Active', 'leagues'),
            _tappablePill('👤 ${_pending.length} Pending Approvals', 'approvals'),
          ]),
        ])),
        const SizedBox(width: 16),
        if (MediaQuery.of(context).size.width > 400)
          const Icon(Icons.sports_soccer, size: 48, color: Colors.white24),
      ]),
    );
  }

  Widget _tappablePill(String text, String route) => GestureDetector(
    onTap: () => _navigate(route),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Colors.white70),
      ]),
    ),
  );

  Widget _buildStatsGrid() {
    final teamCount   = _dynamicTeams.isEmpty   ? _teams.length   : _dynamicTeams.length;
    final playerCount = _dynamicPlayers.isNotEmpty ? _dynamicPlayers.length : (_players.length * 11);
    final liveCount   = _liveMatches.length;
    final squadCount  = _submittedSquads.length;

    final cards = [
      _statCardData('Total Teams', '$teamCount', 'Registered this season',
          teamCount > 0 ? '+$teamCount' : '0', Icons.shield_rounded,
          const LinearGradient(colors: [Color(0xFF003087), Color(0xFF1A4FA0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          (teamCount / 8).clamp(0.0, 1.0), onTap: () => _navigate('teams')),
      _statCardData('Live Matches', '$liveCount', 'Currently in progress',
          liveCount > 0 ? '+$liveCount' : '0', Icons.sports_soccer_rounded,
          const LinearGradient(colors: [Color(0xFF006B35), Color(0xFF00A651)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          (liveCount / 20).clamp(0.0, 1.0), onTap: () => _navigate('live_scores')),
      _statCardData('Registered Players', '$playerCount',
          _dynamicPlayers.isNotEmpty ? 'Live from database' : 'No players yet',
          playerCount > 0 ? '+$playerCount' : '0', Icons.group_rounded,
          const LinearGradient(colors: [Color(0xFFC47A00), Color(0xFFF5A500)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          (playerCount / 100).clamp(0.0, 1.0), onTap: () => _navigate('players')),
      _statCardData('Pending Squads', '$squadCount', 'Awaiting your review',
          squadCount > 0 ? '+$squadCount' : '0', Icons.fact_check_rounded,
          const LinearGradient(colors: [Color(0xFF001A4D), Color(0xFF003087)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          (squadCount / 10).clamp(0.0, 1.0), onTap: () => _navigate('squad_approvals')),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      // 1 col < 480, 2 col < 760, 4 col otherwise
      final crossCount = w < 480 ? 1 : w < 760 ? 2 : 4;
      final ratio = w < 480 ? 1.6 : w < 760 ? 1.25 : 1.15;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          childAspectRatio: ratio,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => cards[i],
      );
    });
  }

  StatCard _statCardData(String title, String value, String subtitle, String pct, IconData icon, Gradient grad, double progress, {VoidCallback? onTap}) {
    return StatCard(
      title: title, value: value, subtitle: subtitle, percent: pct, icon: icon, gradient: grad,
      progress: progress,
      onTap: onTap,
    );
  }

  // ─── Season Progress Gauge ───────────────────────────────────────────────────
  Widget _buildSeasonGauge() {
    final ms = context.watch<MatchState>();
    final total     = ms.generatedFixtures.length;
    final completed = ms.generatedFixtures.where((f) => f.status == 'completed').length;
    final live      = ms.generatedFixtures.where((f) => f.status == 'live').length;
    final pending   = total - completed - live;
    final pct       = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final pctInt    = (pct * 100).round();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: LayoutBuilder(builder: (_, box) {
        final isWide = box.maxWidth > 500;
        return isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Gauge
                SizedBox(
                  width: 200, height: 130,
                  child: CustomPaint(painter: _SeasonGaugePainter(progress: pct)),
                ),
                const SizedBox(width: 28),
                Expanded(child: _gaugeInfo(pctInt, completed, live, pending, total)),
              ])
            : Column(children: [
                SizedBox(
                  width: double.infinity, height: 160,
                  child: CustomPaint(painter: _SeasonGaugePainter(progress: pct)),
                ),
                const SizedBox(height: 16),
                _gaugeInfo(pctInt, completed, live, pending, total),
              ]);
      }),
    );
  }

  Widget _gaugeInfo(int pctInt, int completed, int live, int pending, int total) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Season Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF003087).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Season 2026', style: TextStyle(fontSize: 11, color: const Color(0xFF003087), fontWeight: FontWeight.bold)),
        ),
      ]),
      const SizedBox(height: 4),
      Text(total == 0 ? 'Generate fixtures to track progress' : '$completed of $total matches played',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      const SizedBox(height: 16),
      // Legend row
      Wrap(spacing: 20, runSpacing: 8, children: [
        _gaugeLegend(const Color(0xFF00A651), 'Completed', '$completed'),
        _gaugeLegend(const Color(0xFFF9A825), 'In Progress', '$live'),
        _gaugeLegend(Colors.grey.shade300, 'Pending', '$pending'),
      ]),
      if (total > 0) ...[ 
        const SizedBox(height: 14),
        // Mini breakdown bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(children: [
            if (completed > 0) Expanded(flex: completed, child: Container(height: 8, color: const Color(0xFF00A651))),
            if (live > 0) Expanded(flex: live, child: Container(height: 8, color: const Color(0xFFF9A825))),
            if (pending > 0) Expanded(flex: pending > 0 ? pending : 1, child: Container(height: 8, color: Colors.grey.shade200)),
          ]),
        ),
        const SizedBox(height: 6),
        Text('$pctInt% of season completed', style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
      ],
    ]);
  }

  Widget _gaugeLegend(Color color, String label, String count) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text('$label ', style: const TextStyle(fontSize: 12)),
    Text(count, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
  ]);

  Widget _buildChartsRow() {
    return LayoutBuilder(builder: (_, c) {
      final twoCol = c.maxWidth > 600;
      return twoCol
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _buildTeamRegistrationChart()),
              const SizedBox(width: 18),
              Expanded(child: _buildResultsChart()),
            ])
          : Column(children: [_buildTeamRegistrationChart(), const SizedBox(height: 18), _buildResultsChart()]);
    });
  }

  Widget _buildTeamRegistrationChart() {
    // Use real teams; fall back to dummy only if DB is empty
    final teams = _dynamicTeams.isNotEmpty ? _dynamicTeams : _teams.map((t) => {
      'name': t.name,
      'player_count': t.wins + t.draws + t.losses,
      'status': t.status,
    }).toList();

    // Max player count for progress bar scaling
    final maxVal = teams.fold<int>(1, (m, t) {
      final v = ((t['player_count'] ?? t['wins']) as int? ?? 1);
      return v > m ? v : m;
    });

    return _card(
      title: 'Team Registrations',
      subtitle: teams.isEmpty ? 'No teams yet' : '${teams.length} team${teams.length == 1 ? '' : 's'} registered',
      child: teams.isEmpty
          ? const SizedBox(
              height: 160,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shield_outlined, size: 40, color: Color(0xFFD0D8E8)),
                  SizedBox(height: 8),
                  Text('No teams registered yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ),
            )
          : Column(
              children: teams.take(8).toList().asMap().entries.map((e) {
                final t = e.value;
                final name   = (t['name'] as String?) ?? 'Unknown';
                final count  = ((t['player_count'] ?? t['wins']) as int? ?? 0);
                final status = (t['status'] as String?) ?? 'Active';
                final isActive = status.toLowerCase() == 'active';
                final ratio  = maxVal > 0 ? (count / maxVal).clamp(0.0, 1.0) : 0.0;
                final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
                // Cycle through a set of accent colours
                final accent = const [
                  Color(0xFF003087), Color(0xFF00A651), Color(0xFFC47A00),
                  Color(0xFF8B0000), Color(0xFF006B6B), Color(0xFF4A0072),
                  Color(0xFF004D40), Color(0xFF37474F),
                ][e.key % 8];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    // Avatar
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(initials,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: accent)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name + bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(status,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: isActive ? Colors.green.shade700 : Colors.grey,
                                      letterSpacing: 0.5,
                                    )),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          LayoutBuilder(builder: (_, bc) => Stack(
                            children: [
                              Container(
                                height: 6, width: bc.maxWidth,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                height: 6,
                                width: bc.maxWidth * ratio,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [accent, accent.withOpacity(0.6)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Player count badge
                    Text('$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        )),
                  ]),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildResultsChart() {
    return _card(
      title: 'Recent Match Scores',
      subtitle: _recentResults.isEmpty ? 'No match data' : '${_recentResults.length} result${_recentResults.length == 1 ? '' : 's'} this season',
      child: _recentResults.isEmpty
          ? const SizedBox(
              height: 160,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.sports_score_outlined, size: 40, color: Color(0xFFD0D8E8)),
                  SizedBox(height: 8),
                  Text('No results yet — matches underway', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ),
            )
          : Column(
              children: _recentResults.take(5).map((r) {
                final home     = (r['home_team'] as String?) ?? 'Home';
                final away     = (r['away_team'] as String?) ?? 'Away';
                final hs       = (r['home_score'] as int?) ?? 0;
                final as_      = (r['away_score'] as int?) ?? 0;
                final homeWon  = hs > as_;
                final awayWon  = as_ > hs;
                final isDraw   = hs == as_;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(children: [
                    // Home team
                    Expanded(
                      child: Text(home.split(' ').first,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: homeWon ? FontWeight.w800 : FontWeight.w500,
                            color: homeWon ? const Color(0xFF003087) : Colors.black87,
                          )),
                    ),
                    const SizedBox(width: 8),
                    // Score pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDraw
                              ? [const Color(0xFF555555), const Color(0xFF888888)]
                              : [const Color(0xFF003087), const Color(0xFF1A4FA0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF003087).withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text('$hs – $as_',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1,
                          )),
                    ),
                    const SizedBox(width: 8),
                    // Away team
                    Expanded(
                      child: Text(away.split(' ').first,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: awayWon ? FontWeight.w800 : FontWeight.w500,
                            color: awayWon ? const Color(0xFF003087) : Colors.black87,
                          )),
                    ),
                  ]),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildBottomRow() {
    return LayoutBuilder(builder: (_, c) {
      final twoCol = c.maxWidth > 600;
      return twoCol
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _buildRecentResults()),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: _buildQuickActions()),
            ])
          : Column(children: [_buildRecentResults(), const SizedBox(height: 18), _buildQuickActions()]);
    });
  }

  Widget _buildRecentResults() {
    return _card(
      title: 'Recent Match Results', 
      subtitle: _recentResults.isEmpty ? 'No completed matches' : 'Last ${_recentResults.length} completed matches', 
      child: _recentResults.isEmpty 
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No match results available yet', style: TextStyle(color: Colors.grey, fontSize: 14)),
          )
        : Column(
            children: _recentResults.take(4).map((result) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(child: Text(result['home_team'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF003087), borderRadius: BorderRadius.circular(6)),
                  child: Text('${result['home_score'] ?? 0} – ${result['away_score'] ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(result['away_team'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              ]),
            )).toList(),
          )
    );
  }

  String _formatDate(String dateTimeStr) {
    try {
      final date = DateTime.parse(dateTimeStr);
      return '${date.day}/${date.month}';
    } catch (e) {
      return '';
    }
  }

  Widget _buildQuickActions() {
    return _card(title: 'Quick Actions', subtitle: '', child: Column(children: [
      _actionLink(Icons.pending_actions_rounded, 'Review Approvals', Colors.orange, 'approvals'),
      const Divider(height: 1),
      _actionLink(Icons.fact_check_rounded, 'Squad Approvals', const Color(0xFF003087), 'squad_approvals'),
      const Divider(height: 1),
      _actionLink(Icons.stadium_rounded, 'Manage Venues', Colors.teal, 'venues'),
      const Divider(height: 1),
      _actionLink(Icons.calendar_today_rounded, 'Schedule Fixture', Colors.blue, 'fixtures'),
      const Divider(height: 1),
      _actionLink(Icons.format_list_numbered_rounded, 'View Standings', Colors.green, 'standings'),
      const Divider(height: 1),
      _actionLink(Icons.analytics_rounded, 'Report Centre', Colors.purple, 'season_report'),
    ]));
  }

  Widget _actionLink(IconData icon, String label, Color color, String navId) {
    return InkWell(
      onTap: () => _navigate(navId),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
        Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Colors.grey.shade400),
      ])),
    );
  }

  // ─── Approvals ──────────────────────────────────────────────────────────────
  Widget _buildApprovals() {
    if (_isLoadingPending) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));

    // Filter by role chip
    var pending = _pending.where((p) {
      final role = (p['role'] as String? ?? '').toLowerCase();
      if (_approvalsRoleFilter != 'all' && role != _approvalsRoleFilter) return false;
      if (_searchQuery.isEmpty) return true;
      return (p['full_name'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
             (p['email'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
             role.contains(_searchQuery);
    }).toList();

    // Sort
    pending.sort((a, b) {
      int cmp;
      switch (_approvalsSortCol) {
        case 'email': cmp = (a['email'] ?? '').toString().compareTo((b['email'] ?? '').toString()); break;
        case 'role':  cmp = (a['role'] ?? '').toString().compareTo((b['role'] ?? '').toString()); break;
        default:      cmp = (a['full_name'] ?? '').toString().compareTo((b['full_name'] ?? '').toString());
      }
      return _approvalsSortAsc ? cmp : -cmp;
    });

    return RefreshIndicator(
      onRefresh: _fetchPending,
      color: const Color(0xFF00A651),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _pendingHeader(),
          const SizedBox(height: 12),
          // Role filter chips
          Row(children: [
            _filterChips(['all', 'coach', 'referee', 'player'], _approvalsRoleFilter,
                (v) => setState(() { _approvalsRoleFilter = v; })),
            const Spacer(),
            _resultCount(pending.length, _pending.length),
          ]),
          const SizedBox(height: 12),
          // Sort bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(flex: 3, child: _sortableColHeader('Name', 'name', _approvalsSortCol, _approvalsSortAsc,
                () => setState(() { if (_approvalsSortCol == 'name') _approvalsSortAsc = !_approvalsSortAsc; else { _approvalsSortCol = 'name'; _approvalsSortAsc = true; } }))),
              Expanded(flex: 3, child: _sortableColHeader('Email', 'email', _approvalsSortCol, _approvalsSortAsc,
                () => setState(() { if (_approvalsSortCol == 'email') _approvalsSortAsc = !_approvalsSortAsc; else { _approvalsSortCol = 'email'; _approvalsSortAsc = true; } }))),
              Expanded(flex: 2, child: _sortableColHeader('Role', 'role', _approvalsSortCol, _approvalsSortAsc,
                () => setState(() { if (_approvalsSortCol == 'role') _approvalsSortAsc = !_approvalsSortAsc; else { _approvalsSortCol = 'role'; _approvalsSortAsc = true; } }))),
            ]),
          ),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            _emptyState(Icons.check_circle_outline_rounded,
                _searchQuery.isEmpty && _approvalsRoleFilter == 'all' ? 'All caught up!' : 'No matches',
                _searchQuery.isEmpty && _approvalsRoleFilter == 'all' ? 'No pending approvals.' : 'Try a different filter or search.')
          else
            ...pending.asMap().entries.map((e) => _approvalCard(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _sidebar() {
    final ap = Provider.of<auth.AuthProvider>(context);
    final profile = ap.profile;
    final avatarUrl = profile?['avatar_url'];
    final fullName = profile?['full_name'] ?? 'Admin';

    return Container(
      width: 280, color: const Color(0xFF001A4D),
      child: Column(children: [
        // Sidebar Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: Row(children: [
            InkWell(
              onTap: () => _navigate('profile'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF003087), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('UNILEAGUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.1)),
              Text('Management Console', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
        
        // Admin Profile Preview
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: InkWell(
            onTap: () => _navigate('profile'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF003087),
                  backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null || avatarUrl.toString().isEmpty ? Text(fullName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fullName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text('Super Administrator', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                ])),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 16),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _pendingHeader() {
    return Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.pending_actions_rounded, color: Colors.orange.shade700)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pending Approvals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text('${_pending.length} account(s) awaiting review', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ]),
    ]);
  }

  Widget _approvalCard(int index, Map<String, dynamic> p) {
    final name = p['full_name'] ?? 'Unknown Account';
    final role = p['role'] ?? 'User';
    final email = p['email'] ?? 'No Email';
    final team = p['team_name'] ?? '—';
    final userId = p['id'] as String;
    final avatarUrl = p['avatar_url'] as String?;

    final isCoach = role.toLowerCase() == 'coach';
    final color = isCoach ? const Color(0xFF00A651) : const Color(0xFF003087);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.12),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null || avatarUrl.isEmpty ? Text(name[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)) : null,
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('$role · $email', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            if (role == 'Coach' || role == 'coach') Text('Team: $team', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
            child: Text(role.toUpperCase(), style: TextStyle(color: Colors.orange.shade800, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () async {
              final ap = Provider.of<auth.AuthProvider>(context, listen: false);
              await ap.approveUser(userId);
              _fetchPending(); // Refresh list
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [const Icon(Icons.check_circle_rounded, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text('$name approved! Access granted.'))]),
                backgroundColor: const Color(0xFF00A651), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16), duration: const Duration(seconds: 4),
              ));
            },
            icon: const Icon(Icons.check_rounded, size: 16), label: const Text('Approve'),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00A651), side: const BorderSide(color: Color(0xFF00A651)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          )),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(
            onPressed: () { 
              // Rejection logic could go here
              setState(() => _pending.removeAt(index)); 
            },
            icon: const Icon(Icons.close_rounded, size: 16), label: const Text('Reject'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade600, side: BorderSide(color: Colors.red.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          )),
        ]),
      ]),
    );
  }

  // ─── Squad Approvals ────────────────────────────────────────────────────────
  Widget _buildSquadApprovals() {
    if (_isLoadingSquads) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));
    return RefreshIndicator(
      onRefresh: _fetchSquadSubmissions,
      color: const Color(0xFF003087),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF003087).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.fact_check_rounded, color: Color(0xFF003087))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Squad Approvals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${_submittedSquads.length} squad(s) pending review', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ]),
          ]),
          const SizedBox(height: 16),
          if (_submittedSquads.isEmpty)
            _emptyState(Icons.check_circle_outline_rounded, 'No Submitted Squads', 'Coaches haven\'t submitted any squads yet.')
          else
            ..._submittedSquads.map((squad) => _buildSquadApprovalCard(squad)),
        ],
      ),
    );
  }

  Widget _buildSquadApprovalCard(Map<String, dynamic> squad) {
    final teamId = squad['id'] as String;
    final teamName = squad['name'] ?? 'Unknown Team';
    final coachName = squad['profiles']?['full_name'] ?? 'Unknown Coach';
    final submittedAt = squad['submitted_at'] != null
        ? DateTime.tryParse(squad['submitted_at'] as String)
        : null;
    final players = (squad['players'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final isExpanded = _expandedSquads.contains(teamId);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF003087).withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0,3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Card header
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) _expandedSquads.remove(teamId);
            else _expandedSquads.add(teamId);
          }),
          borderRadius: BorderRadius.vertical(top: const Radius.circular(18), bottom: isExpanded ? Radius.zero : const Radius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF003087).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: squad['logo_url'] != null
                      ? DecorationImage(image: NetworkImage(squad['logo_url'] as String), fit: BoxFit.cover)
                      : null,
                ),
                child: squad['logo_url'] == null
                    ? Center(child: Text(teamName[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003087), fontSize: 18)))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 400),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _recentlyUpdatedTeamId == teamId
                        ? const Color(0xFF00A651)
                        : Colors.black87,
                  ),
                  child: Text(teamName),
                ),
                Text('Coach: $coachName', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                if (submittedAt != null)
                  Text('Submitted ${submittedAt.day}/${submittedAt.month}/${submittedAt.year}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.shade200)),
                child: Text('${players.length} players', style: TextStyle(color: Colors.amber.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.grey.shade400),
            ]),
          ),
        ),

        // Expandable player roster
        if (isExpanded) ...[
          const Divider(height: 1),
          // Player table header
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(children: [
              const SizedBox(width: 36),
              const Expanded(child: Text('Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
              const SizedBox(width: 50, child: Text('Pos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey), textAlign: TextAlign.center)),
              const SizedBox(width: 40, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey), textAlign: TextAlign.center)),
            ]),
          ),
          ...players.map((p) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF003087).withOpacity(0.1),
                backgroundImage: p['photo_url'] != null ? NetworkImage(p['photo_url'] as String) : null,
                child: p['photo_url'] == null
                    ? Text((p['full_name'] ?? '?')[0], style: const TextStyle(fontSize: 12, color: Color(0xFF003087), fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(p['reg_no'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ])),
              SizedBox(width: 50, child: Center(child: _posBadge(p['position'] ?? 'FW'))),
              SizedBox(width: 40, child: Text('${p['jersey_number'] ?? 0}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ]),
          )),
          const Divider(height: 1),
          // Approve / Reject buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                SizedBox(
                  width: 160,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ap = Provider.of<auth.AuthProvider>(context, listen: false);
                      final err = await ap.reviewSquad(teamId, approve: true);
                      if (!mounted) return;
                      if (err == null) {
                        // Send notification about squad approval
                        await _sendNotification(
                          title: 'Squad Approved',
                          message: '$teamName squad has been approved and is ready for matches',
                          type: 'squad_approval',
                        );
                        
                        _fetchSquadSubmissions();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Row(children: [const Icon(Icons.verified_rounded, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text('$teamName squad approved!'))]),
                          backgroundColor: const Color(0xFF00A651), behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
                        ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red));
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A651), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final noteCtrl = TextEditingController();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: const Text('Reject Squad', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('Provide a reason so $coachName can fix and re-submit.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: noteCtrl, maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'e.g. Missing GK, incomplete player details...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                          ]),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        final ap = Provider.of<auth.AuthProvider>(context, listen: false);
                        final err = await ap.reviewSquad(teamId, approve: false, note: noteCtrl.text);
                        if (!mounted) return;
                        if (err == null) {
                          _fetchSquadSubmissions();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Row(children: [const Icon(Icons.cancel_rounded, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text('$teamName squad rejected'))]),
                            backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
                          ));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  // ─── Fixtures ───────────────────────────────────────────────────────────────
  Widget _buildFixtures() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));
    final ms = context.watch<MatchState>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Generator panel ─────────────────────────────────────────────────
        FixtureGeneratorPanel(
          teams: _dynamicTeams.map((t) => t['name'] as String).toList(),
          referees: _dynamicReferees.map((r) => r['full_name'] as String).toList(),
          teamMaps: _dynamicTeams,
          venues: _venues,
          leagues: _leagues,
        ),
        const SizedBox(height: 24),
        // ── Manage saved fixtures ────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Saved Fixtures', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${ms.generatedFixtures.length} fixture(s) — persisted to database',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
          ),
          // Refresh
          IconButton(
            tooltip: 'Refresh from database',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF003087)),
            onPressed: () => ms.loadFixtures(),
          ),
          // Clear all
          if (ms.generatedFixtures.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmClearAll(ms),
              icon: Icon(Icons.delete_sweep_rounded, color: Colors.red.shade400, size: 18),
              label: Text('Clear All', style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
            ),
        ]),
        const SizedBox(height: 12),
        if (ms.isLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: Color(0xFF003087)),
          ))
        else if (ms.generatedFixtures.isEmpty)
          _emptyState(Icons.calendar_today_rounded, 'No Fixtures Yet',
              'Generate a schedule above — it will be saved to the database.')
        else
          ...ms.generatedFixtures.asMap().entries.map((e) {
            final f = e.value;
            final num = e.key + 1;
            return _buildFixtureRow(f, num, ms);
          }),
      ]),
    );
  }

  Widget _buildFixtureRow(GeneratedFixture f, int num, MatchState ms) {
    final statusColor = f.status == 'live'
        ? Colors.green
        : f.status == 'completed'
            ? Colors.grey
            : f.status == 'postponed'
                ? Colors.orange
                : const Color(0xFF003087);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Row(children: [
        // Index
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text('$num', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor))),
        ),
        const SizedBox(width: 12),
        // Teams + meta
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${f.homeTeam}  vs  ${f.awayTeam}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 3),
            Wrap(spacing: 8, children: [
              _metaChip(Icons.calendar_today_rounded,
                  '${f.dateTime.day}/${f.dateTime.month}/${f.dateTime.year}'),
              _metaChip(Icons.access_time_rounded,
                  '${f.dateTime.hour.toString().padLeft(2,'0')}:${f.dateTime.minute.toString().padLeft(2,'0')}'),
              _metaChip(Icons.location_on_rounded, f.venue),
              if (f.assignedReferee != null)
                _metaChip(Icons.person_rounded, f.assignedReferee!),
            ]),
          ]),
        ),
        // Status badge
        Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(f.status[0].toUpperCase() + f.status.substring(1),
              style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
        ),
        // Edit
        IconButton(
          tooltip: 'Edit fixture',
          icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF003087)),
          onPressed: () => _showFixtureEditDialog(f, ms),
          constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
        // Delete
        IconButton(
          tooltip: 'Delete fixture',
          icon: Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade400),
          onPressed: () => _confirmDeleteFixture(f, ms),
          constraints: const BoxConstraints(), padding: const EdgeInsets.only(left: 2),
        ),
      ]),
    );
  }

  Widget _metaChip(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: Colors.grey.shade500),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
    ],
  );

  Future<void> _showFixtureEditDialog(GeneratedFixture f, MatchState ms) async {
    DateTime pickedDate = f.dateTime;
    TimeOfDay pickedTime = TimeOfDay(hour: f.dateTime.hour, minute: f.dateTime.minute);
    final venueCtrl = TextEditingController(text: f.venue);
    // Build referee list from loaded referees
    String? selectedReferee = f.assignedReferee;
    final refereeNames = _dynamicReferees.map((r) => r['full_name'] as String).toList();
    String? editError;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF003087).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF003087), size: 20)),
            const SizedBox(width: 10),
            const Text('Edit Fixture', style: TextStyle(fontSize: 17)),
          ]),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Match info (read-only)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text('${f.homeTeam}  vs  ${f.awayTeam}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              // Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF003087)),
                title: Text('${pickedDate.day}/${pickedDate.month}/${pickedDate.year}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Match date', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  final d = await showDatePicker(context: ctx,
                    initialDate: pickedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030));
                  if (d != null) setS(() => pickedDate = d);
                },
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ),
              // Time
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_rounded, size: 20, color: Color(0xFF003087)),
                title: Text(pickedTime.format(ctx), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Kickoff time', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: pickedTime);
                  if (t != null) setS(() => pickedTime = t);
                },
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ),
              // Venue
              const SizedBox(height: 8),
              TextField(
                controller: venueCtrl,
                decoration: InputDecoration(
                  labelText: 'Venue',
                  prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              // Referee dropdown
              if (refereeNames.isNotEmpty) ...{
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: refereeNames.contains(selectedReferee) ? selectedReferee : null,
                  decoration: InputDecoration(
                    labelText: 'Assigned Referee',
                    prefixIcon: const Icon(Icons.person_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— Unassigned —')),
                    ...refereeNames.map((r) => DropdownMenuItem(value: r, child: Text(r))),
                  ],
                  onChanged: (v) => setS(() => selectedReferee = v),
                ),
              },
              if (editError != null) ...{
                const SizedBox(height: 8),
                Text(editError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              },
            ]),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving ? null : () async {
                setS(() { saving = true; editError = null; });
                final newDt = DateTime(
                  pickedDate.year, pickedDate.month, pickedDate.day,
                  pickedTime.hour, pickedTime.minute,
                );
                final err = await ms.updateFixture(f.id,
                  dateTime: newDt,
                  venue: venueCtrl.text.trim(),
                  referee: selectedReferee,
                );
                if (!ctx.mounted) return;
                if (err != null) {
                  setS(() { saving = false; editError = err; });
                } else {
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Fixture updated!'),
                        backgroundColor: Color(0xFF1B5E20),
                        behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ],
        );
      }),
    );
    venueCtrl.dispose();
  }

  void _confirmDeleteFixture(GeneratedFixture f, MatchState ms) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete Fixture'),
      content: Text('Delete  "${f.homeTeam} vs ${f.awayTeam}"?\nThis cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            final err = await ms.deleteFixture(f.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(err == null ? '🗑️ Fixture deleted.' : 'Error: $err'),
                backgroundColor: err == null ? Colors.red.shade700 : Colors.orange,
                behavior: SnackBarBehavior.floating,
              ));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Delete'),
        ),
      ],
    ));
  }

  void _confirmClearAll(MatchState ms) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Clear All Fixtures'),
      content: Text('This will permanently delete all ${ms.generatedFixtures.length} fixtures. Are you sure?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await ms.clearAllFixtures();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('🗑️ All fixtures cleared.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Clear All'),
        ),
      ],
    ));
  }



  // ─── Venues ─────────────────────────────────────────────────────────────────
  // ─── Leagues ─────────────────────────────────────────────────────────────────
  Future<void> _fetchLeagues() async {
    if (!mounted) return;
    setState(() => _isLoadingLeagues = true);
    try {
      final res = await Supabase.instance.client
          .from('leagues')
          .select()
          .order('created_at', ascending: true);
      if (mounted) setState(() { _leagues = List<Map<String, dynamic>>.from(res); _isLoadingLeagues = false; });
    } catch (e) {
      debugPrint('Error fetching leagues: $e');
      if (mounted) setState(() => _isLoadingLeagues = false);
    }
  }

  Widget _buildLeagues() {
    if (_isLoadingLeagues) return const Center(child: CircularProgressIndicator(color: Color(0xFF003087)));
    final filtered = _leagues.where((l) {
      if (_searchQuery.isEmpty) return true;
      return (l['name'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
             (l['description'] as String? ?? '').toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFF8F00)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('League Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${_leagues.length} league(s) — select when generating fixtures',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ])),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showLeagueDialog(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add League'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _emptyState(Icons.emoji_events_rounded, 'No Leagues Yet',
              'Add a league to use when scheduling fixtures.')
        else
          ...filtered.map((l) => _buildLeagueCard(l)),
      ],
    );
  }

  Widget _buildLeagueCard(Map<String, dynamic> l) {
    final id       = l['id'] as String;
    final name     = (l['name'] as String?) ?? 'Unnamed';
    final desc     = (l['description'] as String?);
    final season   = (l['season'] as String?);
    final isActive = (l['is_active'] as bool?) ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF003087).withOpacity(0.2) : Colors.grey.shade200,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFFC107).withOpacity(0.15)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.emoji_events_rounded,
              color: isActive ? const Color(0xFFFF8F00) : Colors.grey, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          if (desc != null && desc.isNotEmpty)
            Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ])),
        if (season != null && season.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF003087).withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(season,
                style: const TextStyle(fontSize: 11, color: Color(0xFF003087), fontWeight: FontWeight.bold)),
          ),
        // Active toggle
        Switch(
          value: isActive,
          activeColor: const Color(0xFF003087),
          onChanged: (val) async {
            try {
              await Supabase.instance.client
                  .from('leagues')
                  .update({'is_active': val})
                  .eq('id', id);
              _fetchLeagues();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating));
            }
          },
        ),
        // Edit
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
          onPressed: () => _showLeagueDialog(existing: l),
          constraints: const BoxConstraints(), padding: const EdgeInsets.only(left: 4),
        ),
        // Delete
        IconButton(
          icon: Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade400),
          constraints: const BoxConstraints(), padding: const EdgeInsets.only(left: 4),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Delete League'),
                content: Text('Remove "$name"? This cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              try {
                await Supabase.instance.client.from('leagues').delete().eq('id', id);
                _fetchLeagues();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ League deleted.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating));
              }
            }
          },
        ),
      ]),
    );
  }

  Future<void> _showLeagueDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl   = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl   = TextEditingController(text: existing?['description'] ?? '');
    final seasonCtrl = TextEditingController(text: existing?['season'] ?? '2026');
    final isEdit = existing != null;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isEdit ? 'Edit League' : 'Add League',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: 'League Name *',
              prefixIcon: const Icon(Icons.emoji_events_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            decoration: InputDecoration(
              labelText: 'Description',
              prefixIcon: const Icon(Icons.description_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: seasonCtrl,
            decoration: InputDecoration(
              labelText: 'Season (e.g. 2026)',
              prefixIcon: const Icon(Icons.date_range_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final name   = nameCtrl.text.trim();
              final desc   = descCtrl.text.trim();
              final season = seasonCtrl.text.trim();
              Navigator.pop(ctx);
              try {
                if (isEdit) {
                  await Supabase.instance.client.from('leagues').update({
                    'name': name,
                    'description': desc.isEmpty ? null : desc,
                    'season': season.isEmpty ? null : season,
                  }).eq('id', existing!['id'] as String);
                } else {
                  await Supabase.instance.client.from('leagues').insert({
                    'name': name,
                    if (desc.isNotEmpty) 'description': desc,
                    if (season.isNotEmpty) 'season': season,
                  });
                }
                _fetchLeagues();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEdit ? '✅ League updated.' : '✅ League added.'),
                  backgroundColor: const Color(0xFF003087),
                  behavior: SnackBarBehavior.floating,
                ));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.toString().contains('leagues')
                      ? '⚠️ Leagues table not found. Run the SQL in backend/db/leagues.sql in Supabase first.'
                      : 'Error: $e'),
                  backgroundColor: Colors.red.shade700,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(isEdit ? 'Save Changes' : 'Add League'),
          ),
        ],
      ),
    );
  }

  Widget _buildVenues() {
    if (_isLoadingVenues) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Header row with Add button
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.stadium_rounded, color: Colors.teal)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Venues', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${_venues.length} venue(s) — used when creating fixtures', style: TextStyle(color: Colors.grey.shade500, fontSize: 12), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showVenueDialog(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Venue'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
          ),
        ]),
        const SizedBox(height: 16),
        if (_venues.isEmpty)
          _emptyState(Icons.stadium_rounded, 'No Venues Yet', 'Add a venue to use when scheduling fixtures.')
        else
          ..._venues.map((v) => _buildVenueCard(v)),
      ],
    );
  }

  Widget _buildVenueCard(Map<String, dynamic> v) {
    final id = v['id'] as String;
    final name = v['name'] as String? ?? 'Unnamed';
    final location = v['location'] as String?;
    final capacity = v['capacity'] as int?;
    final isActive = v['is_active'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? Colors.teal.withOpacity(0.2) : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.stadium_rounded, color: Colors.teal, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          if (location != null && location.isNotEmpty)
            Text(location, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ])),
        if (capacity != null)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Text('Cap: $capacity', style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
          ),
        // Active toggle
        Switch(
          value: isActive,
          activeColor: Colors.teal,
          onChanged: (val) async {
            final ap = Provider.of<auth.AuthProvider>(context, listen: false);
            final err = await ap.updateVenue(id, isActive: val);
            if (err == null) _fetchVenues();
          },
        ),
        // Edit
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
          onPressed: () => _showVenueDialog(existing: v),
          constraints: const BoxConstraints(), padding: const EdgeInsets.only(left: 4),
        ),
        // Delete
        IconButton(
          icon: Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade400),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Delete Venue'),
                content: Text('Remove "$name" from the venues list?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Delete')),
                ],
              ),
            );
            if (confirmed == true) {
              final ap = Provider.of<auth.AuthProvider>(context, listen: false);
              await ap.deleteVenue(id);
              _fetchVenues();
            }
          },
          constraints: const BoxConstraints(), padding: const EdgeInsets.only(left: 4),
        ),
      ]),
    );
  }

  Future<void> _showVenueDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final locationCtrl = TextEditingController(text: existing?['location'] ?? '');
    final capacityCtrl = TextEditingController(text: existing?['capacity']?.toString() ?? '');
    final isEdit = existing != null;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isEdit ? 'Edit Venue' : 'Add Venue', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: 'Venue Name *',
              prefixIcon: const Icon(Icons.stadium_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: locationCtrl,
            decoration: InputDecoration(
              labelText: 'Location',
              prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: capacityCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Capacity (optional)',
              prefixIcon: const Icon(Icons.people_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              // Close dialog THEN perform DB operation
              final name = nameCtrl.text.trim();
              final location = locationCtrl.text.trim();
              final cap = int.tryParse(capacityCtrl.text.trim());
              Navigator.pop(ctx);
              final ap = Provider.of<auth.AuthProvider>(context, listen: false);
              String? err;
              if (isEdit) {
                err = await ap.updateVenue(existing!['id'] as String,
                    name: name, location: location, capacity: cap);
              } else {
                err = await ap.addVenue(name: name, location: location, capacity: cap);
              }
              if (!mounted) return;
              if (err != null) {
                // Show the DB error — usually means SQL migration hasn't been run
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(err.contains('venues') || err.contains('schema')
                      ? '⚠️ Venues table not found. Please run the SQL migration in Supabase first.'
                      : 'Error: $err'),
                  backgroundColor: Colors.red.shade700,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEdit ? '✅ Venue updated.' : '✅ Venue added.'),
                  backgroundColor: Colors.teal,
                  behavior: SnackBarBehavior.floating,
                ));
              }
              _fetchVenues();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(isEdit ? 'Save Changes' : 'Add Venue'),
          ),
        ],
      ),
    );
  }

  // ─── Standings ──────────────────────────────────────────────────────────────
  Widget _buildStandings() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));
    final ms = context.read<MatchState>();
    // Prefer MatchState standings (from real fixtures); fallback to dynamic teams
    final List<Map<String, dynamic>> rows;
    if (ms.standings.isNotEmpty) {
      rows = ms.standings.map((s) => {
        'name': s.team,
        'played': s.played,
        'wins': s.wins,
        'draws': s.draws,
        'losses': s.losses,
        'gf': s.goalsFor,
        'ga': s.goalsAgainst,
        'gd': s.goalDifference,
        'pts': s.points,
      }).toList();
    } else {
      final sorted = List<Map<String, dynamic>>.from(_dynamicTeams)
        ..sort((a, b) => ((b['points'] ?? 0) as int).compareTo((a['points'] ?? 0) as int));
      rows = sorted.map((t) {
        final w = (t['wins'] ?? 0) as int;
        final d = (t['draws'] ?? 0) as int;
        final l = (t['losses'] ?? 0) as int;
        return {
          'name': t['name'] ?? 'Unknown',
          'played': w + d + l,
          'wins': w, 'draws': d, 'losses': l,
          'gf': 0, 'ga': 0, 'gd': 0,
          'pts': (t['points'] ?? 0) as int,
        };
      }).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(
        title: '🏆 League Standings',
        subtitle: 'MMU Soccer League — Season 2026',
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
            decoration: const BoxDecoration(color: Color(0xFF003087)),
            child: Row(children: [
              const SizedBox(width: 3), // left-bar placeholder
              const SizedBox(width: 28,
                child: Text('#', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1))),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('CLUB',
                    style: TextStyle(color: Colors.white70, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              ...[('P', 28), ('W', 28), ('D', 28), ('L', 28), ('GF', 28), ('GA', 28), ('GD', 28), ('PTS', 36)].map(
                (e) => SizedBox(
                  width: e.$2.toDouble(),
                  child: Text(e.$1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: e.$1 == 'PTS' ? const Color(0xFFFFC107) : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      )),
                ),
              ),
            ]),
          ),
          // ── Rows ───────────────────────────────────────────────────────
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No standings data yet', style: TextStyle(color: Colors.grey))),
            )
          else
            ...rows.asMap().entries.map((e) {
              final pos    = e.key + 1;
              final t      = e.value;
              final total  = rows.length;
              final isTop4 = pos <= 4;
              final isRel  = pos > total - 2;
              final zoneC  = isTop4 ? const Color(0xFF003087) : (isRel ? Colors.red.shade400 : Colors.transparent);
              final name   = (t['name'] as String?) ?? 'Unknown';
              final gd     = (t['gd'] as int?) ?? 0;
              final gdStr  = gd > 0 ? '+$gd' : '$gd';
              final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

              return Container(
                decoration: BoxDecoration(
                  color: pos.isEven ? Colors.grey.shade50 : Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100, width: 0.8),
                    left:  BorderSide(color: zoneC, width: 3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Row(children: [
                    // Pos
                    SizedBox(width: 28,
                      child: Text('$pos',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13,
                            color: isTop4 ? const Color(0xFF003087) : (isRel ? Colors.red.shade500 : Colors.black87),
                          ))),
                    const SizedBox(width: 8),
                    // Club
                    Expanded(child: Row(children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: const Color(0xFF003087).withOpacity(0.12),
                        child: Text(initials,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF003087))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    ])),
                    // Stat columns
                    ...[
                      (t['played'] as int? ?? 0, 28),
                      (t['wins']   as int? ?? 0, 28),
                      (t['draws']  as int? ?? 0, 28),
                      (t['losses'] as int? ?? 0, 28),
                      (t['gf']     as int? ?? 0, 28),
                      (t['ga']     as int? ?? 0, 28),
                    ].map((s) => SizedBox(
                      width: s.$2.toDouble(),
                      child: Text('${s.$1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    )),
                    // GD
                    SizedBox(width: 28,
                      child: Text(gdStr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: gd > 0 ? Colors.green.shade700 : (gd < 0 ? Colors.red.shade600 : Colors.black54),
                          ))),
                    // PTS — gold bold
                    SizedBox(width: 36,
                      child: Text('${t['pts'] ?? 0}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFC107),
                          ))),
                  ]),
                ),
              );
            }),
          const SizedBox(height: 12),
          // ── Legend ─────────────────────────────────────────────────────
          Row(children: [
            _legendDot(const Color(0xFF003087)), const SizedBox(width: 6),
            const Text('Top 4 — Playoffs', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 16),
            _legendDot(Colors.red.shade400), const SizedBox(width: 6),
            const Text('Relegation Zone', style: TextStyle(fontSize: 11)),
          ]),
        ]),
      ),
    );
  }

  Widget _legendDot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  // ─── Match Results ───────────────────────────────────────────────────────────
  Widget _buildResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(title: 'Match Results', subtitle: 'Submitted by referees', child: Column(children: [
        // Table header — 5 equal Expanded columns
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(flex: 3, child: Text('Home', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
            Expanded(flex: 2, child: Text('Score', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.center)),
            Expanded(flex: 3, child: Text('Away', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
            Expanded(flex: 2, child: Text('Date', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
            Expanded(flex: 3, child: Text('Referee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          ]),
        ),
        if (_recentResults.isEmpty) 
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No match results available yet', style: TextStyle(color: Colors.grey, fontSize: 14)),
          )
        else
          ..._recentResults.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(flex: 3, child: Text(r['home_team'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Expanded(flex: 2, child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF003087), borderRadius: BorderRadius.circular(6)),
                child: Text('${r['home_score'] ?? 0} – ${r['away_score'] ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ))),
              Expanded(flex: 3, child: Text(r['away_team'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Expanded(flex: 2, child: Text(_formatDate(r['date_time'] as String), style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
              Expanded(flex: 3, child: Text(r['referee'] as String? ?? 'TBD', style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
            ]),
          )),
      ])),
    );
  }


  // ─── Teams ──────────────────────────────────────────────────────────────────
  Widget _buildTeams() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));

    var rows = _dynamicTeams.where((t) {
      if (_searchQuery.isEmpty) return true;
      return (t['name'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
             (t['profiles']?['full_name'] as String? ?? '').toLowerCase().contains(_searchQuery);
    }).toList();

    rows.sort((a, b) {
      int cmp;
      switch (_teamsSortCol) {
        case 'coach':  cmp = (a['profiles']?['full_name'] ?? '').toString().compareTo((b['profiles']?['full_name'] ?? '').toString()); break;
        case 'status': cmp = (a['is_active'] == true ? 'Active' : 'Inactive').compareTo(b['is_active'] == true ? 'Active' : 'Inactive'); break;
        default:       cmp = (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      }
      return _teamsSortAsc ? cmp : -cmp;
    });

    void toggleSort(String col) => setState(() {
      if (_teamsSortCol == col) _teamsSortAsc = !_teamsSortAsc;
      else { _teamsSortCol = col; _teamsSortAsc = true; }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(
        title: 'Registered Teams',
        subtitle: '${_dynamicTeams.length} teams in the system',
        child: Column(children: [
          Row(children: [
            const Spacer(),
            _resultCount(rows.length, _dynamicTeams.length),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(flex: 3, child: _sortableColHeader('Team', 'name', _teamsSortCol, _teamsSortAsc, () => toggleSort('name'))),
              Expanded(flex: 3, child: _sortableColHeader('Coach', 'coach', _teamsSortCol, _teamsSortAsc, () => toggleSort('coach'))),
              Expanded(flex: 2, child: _sortableColHeader('Status', 'status', _teamsSortCol, _teamsSortAsc, () => toggleSort('status'))),
            ]),
          ),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(_searchQuery.isEmpty ? 'No teams found.' : 'No teams match "$_searchQuery".'))
          else
            ...rows.asMap().entries.map((e) {
              final t = e.value;
              final isActive = t['is_active'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: e.key % 2 == 0 ? Colors.white : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(t['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  Expanded(flex: 3, child: Text(t['profiles']?['full_name'] ?? 'No Coach', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                  Expanded(flex: 2, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(isActive ? 'Active' : 'Inactive',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                            color: isActive ? Colors.green.shade700 : Colors.red.shade700)),
                  )),
                ]),
              );
            }),
        ]),
      ),
    );
  }

  // ─── Players ────────────────────────────────────────────────────────────────
  Widget _buildPlayers() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));

    // Search filter
    var players = _dynamicPlayers.where((p) {
      if (_searchQuery.isEmpty) return true;
      return (p['full_name'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
             (p['teams']?['name'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
             (p['position'] as String? ?? '').toLowerCase().contains(_searchQuery);
    }).toList();

    // Sort
    players.sort((a, b) {
      int cmp;
      switch (_playersSortCol) {
        case 'team':     cmp = (a['teams']?['name'] ?? '').toString().compareTo((b['teams']?['name'] ?? '').toString()); break;
        case 'position': cmp = (a['position'] ?? '').toString().compareTo((b['position'] ?? '').toString()); break;
        case 'number':   cmp = ((a['jersey_number'] as int?) ?? 0).compareTo((b['jersey_number'] as int?) ?? 0); break;
        default:         cmp = (a['full_name'] ?? '').toString().compareTo((b['full_name'] ?? '').toString());
      }
      return _playersSortAsc ? cmp : -cmp;
    });

    void toggleSort(String col) => setState(() {
      if (_playersSortCol == col) _playersSortAsc = !_playersSortAsc;
      else { _playersSortCol = col; _playersSortAsc = true; }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(
        title: 'Registered Players',
        subtitle: '${_dynamicPlayers.length} players — tap to view details',
        child: Column(children: [
          // Toolbar
          Row(children: [
            _filterChips(['all', 'gk', 'def', 'mid', 'fw'], 'all', (_) {}),
            const Spacer(),
            _resultCount(players.length, _dynamicPlayers.length),
          ]),
          const SizedBox(height: 10),
          // Sortable header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const SizedBox(width: 40),
              Expanded(flex: 3, child: _sortableColHeader('Player', 'name', _playersSortCol, _playersSortAsc, () => toggleSort('name'))),
              Expanded(flex: 2, child: _sortableColHeader('Team', 'team', _playersSortCol, _playersSortAsc, () => toggleSort('team'))),
              SizedBox(width: 70, child: _sortableColHeader('Position', 'position', _playersSortCol, _playersSortAsc, () => toggleSort('position'))),
              SizedBox(width: 40, child: _sortableColHeader('#', 'number', _playersSortCol, _playersSortAsc, () => toggleSort('number'), align: TextAlign.center)),
              const SizedBox(width: 80, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.center)),
            ]),
          ),
          const SizedBox(height: 8),
          if (players.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(_searchQuery.isEmpty ? 'No players found.' : 'No players match "$_searchQuery".'))
          else
            ...players.map((p) => _buildPlayerRow(p)),
        ]),
      ),
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> player) {
    final name = player['full_name'] ?? 'Unknown';
    final teamName = player['teams']?['name'] ?? 'No Team';
    final position = player['position'] ?? 'FW';
    final jerseyNumber = player['jersey_number'] ?? 0;
    final photoUrl = player['photo_url'] as String?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        // Player photo
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF00A651).withOpacity(0.1),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null 
              ? Text(name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF00A651), fontWeight: FontWeight.bold, fontSize: 12))
              : null,
        ),
        const SizedBox(width: 12),
        // Player name and details
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (player['reg_no'] != null)
                Text('Reg: ${player['reg_no']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
        // Team
        Expanded(
          flex: 2,
          child: Text(teamName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        // Position badge
        SizedBox(
          width: 60,
          child: Center(child: _posBadge(position)),
        ),
        // Jersey number
        SizedBox(
          width: 40,
          child: Text('$jerseyNumber', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        // Actions
        SizedBox(
          width: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF003087)),
                onPressed: () => _showPlayerDetailsModal(player),
                tooltip: 'View Details',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.orange),
                onPressed: () => _showPlayerEditModal(player),
                tooltip: 'Edit Player',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  void _showPlayerDetailsModal(Map<String, dynamic> player) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A651).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF00A651)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Player Details', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Complete player information', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: 20),
              
              // Player photo and basic info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo
                  Container(
                    width: 100,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      image: player['photo_url'] != null
                          ? DecorationImage(image: NetworkImage(player['photo_url']), fit: BoxFit.cover)
                          : null,
                    ),
                    child: player['photo_url'] == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_rounded, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 4),
                              Text('No Photo', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                            ],
                          )
                        : null,
                  ),
                  const SizedBox(width: 20),
                  // Basic info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow('Full Name', player['full_name'] ?? 'Not provided'),
                        _detailRow('Registration No.', player['reg_no'] ?? 'Not provided'),
                        _detailRow('University ID', player['university_id'] ?? 'Not provided'),
                        _detailRow('Course', player['course'] ?? 'Not provided'),
                        _detailRow('Year of Study', player['year_of_study']?.toString() ?? 'Not provided'),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              
              // Team and position info
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('Team', player['teams']?['name'] ?? 'No Team'),
                      _detailRow('Position', player['position'] ?? 'Not set'),
                      _detailRow('Jersey Number', player['jersey_number']?.toString() ?? 'Not assigned'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('Date of Birth', player['date_of_birth'] ?? 'Not provided'),
                      _detailRow('Eligibility', player['is_eligible'] == true ? 'Eligible' : 'Not Eligible'),
                      _detailRow('Registered', _formatDate(player['created_at'] ?? '')),
                    ],
                  ),
                ),
              ]),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showPlayerEditModal(player);
                    },
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit Player'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF003087),
                      side: const BorderSide(color: Color(0xFF003087)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _approvePlayer(player);
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Approve Player'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A651),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Edit Player Stats Dialog ────────────────────────────────────────────────
  Future<void> _showEditStatsDialog(Map<String, dynamic> p) async {
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    int goals   = (p['goals']   as int?) ?? 0;
    int assists = (p['assists'] as int?) ?? 0;
    int yellow  = (p['yellow_cards'] as int?) ?? 0;
    int red     = (p['red_cards']    as int?) ?? 0;
    int played  = (p['matches_played'] as int?) ?? 0;
    final name  = p['name'] as String? ?? p['full_name'] as String? ?? 'Player';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Widget counter(String label, Color color, int value, VoidCallback inc, VoidCallback dec) =>
              Row(children: [
                SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13))),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: Colors.grey.shade500,
                  onPressed: value > 0 ? dec : null,
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: color,
                  onPressed: inc,
                ),
              ]);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Edit Player Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(name, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.normal)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              counter('Goals ⚽',        const Color(0xFF00A651), goals,   () => setDlg(() => goals++),   () => setDlg(() => goals--)),
              counter('Assists 🅰️',      const Color(0xFF003087), assists, () => setDlg(() => assists++), () => setDlg(() => assists--)),
              counter('Yellow Cards 🟨',  const Color(0xFFF9A825), yellow,  () => setDlg(() => yellow++),  () => setDlg(() => yellow--)),
              counter('Red Cards 🟥',     const Color(0xFFC62828), red,     () => setDlg(() => red++),     () => setDlg(() => red--)),
              counter('Matches Played 📅', Colors.grey.shade600,  played,  () => setDlg(() => played++),  () => setDlg(() => played--)),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final pid = p['id']?.toString() ?? '';
                  if (pid.isEmpty) return;
                  final err = await ap.updatePlayerStats(
                    pid,
                    goals: goals, assists: assists,
                    yellowCards: yellow, redCards: red, matchesPlayed: played,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(err == null ? '✅ Stats updated for $name' : '❌ $err'),
                      backgroundColor: err == null ? const Color(0xFF00A651) : Colors.red,
                    ));
                    if (err == null) _fetchManagementData();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPlayerEditModal(Map<String, dynamic> player) {
    final nameCtrl = TextEditingController(text: player['full_name'] ?? '');
    final regNoCtrl = TextEditingController(text: player['reg_no'] ?? '');
    final uniIdCtrl = TextEditingController(text: player['university_id'] ?? '');
    final courseCtrl = TextEditingController(text: player['course'] ?? '');
    final yearCtrl = TextEditingController(text: player['year_of_study']?.toString() ?? '');
    final jerseyCtrl = TextEditingController(text: player['jersey_number']?.toString() ?? '');
    String selectedPosition = player['position'] ?? 'FW';
    bool isEligible = player['is_eligible'] ?? true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Player', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Update player information', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
                const SizedBox(height: 20),
                
                // Form fields
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: regNoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Registration No.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: uniIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'University ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school_rounded),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                
                TextField(
                  controller: courseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.book_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: yearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Year of Study',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedPosition,
                      decoration: const InputDecoration(
                        labelText: 'Position',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sports_soccer_rounded),
                      ),
                      items: ['GK', 'DF', 'MF', 'FW'].map((pos) => DropdownMenuItem(
                        value: pos,
                        child: Text(pos),
                      )).toList(),
                      onChanged: (value) => setState(() => selectedPosition = value!),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: jerseyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jersey Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Eligible to Play'),
                      value: isEligible,
                      onChanged: (value) => setState(() => isEligible = value!),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ]),
                
                const SizedBox(height: 24),
                
                // Action buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        setState(() => isSaving = true);
                        await _updatePlayer(player['id'], {
                          'full_name': nameCtrl.text.trim(),
                          'reg_no': regNoCtrl.text.trim(),
                          'university_id': uniIdCtrl.text.trim(),
                          'course': courseCtrl.text.trim(),
                          'year_of_study': int.tryParse(yearCtrl.text.trim()),
                          'position': selectedPosition,
                          'jersey_number': int.tryParse(jerseyCtrl.text.trim()),
                          'is_eligible': isEligible,
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          _fetchManagementData(); // Refresh the data
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A651),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approvePlayer(Map<String, dynamic> player) async {
    try {
      await Supabase.instance.client
          .from('players')
          .update({'is_eligible': true})
          .eq('id', player['id']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text('${player['full_name']} approved successfully!'),
            ]),
            backgroundColor: const Color(0xFF00A651),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _fetchManagementData(); // Refresh the data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving player: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updatePlayer(String playerId, Map<String, dynamic> updates) async {
    try {
      await Supabase.instance.client
          .from('players')
          .update(updates)
          .eq('id', playerId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Player updated successfully!'),
            ]),
            backgroundColor: Color(0xFF00A651),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating player: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── Coaches ────────────────────────────────────────────────────────────────
  Widget _buildCoaches() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));

    var coaches = _dynamicCoaches.where((c) {
      if (_searchQuery.isEmpty) return true;
      return (c['full_name'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
             (c['email'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
             (c['team_name'] as String? ?? '').toLowerCase().contains(_searchQuery);
    }).toList();

    coaches.sort((a, b) {
      int cmp;
      switch (_coachesSortCol) {
        case 'email': cmp = (a['email'] ?? '').toString().compareTo((b['email'] ?? '').toString()); break;
        case 'team':  cmp = (a['team_name'] ?? '').toString().compareTo((b['team_name'] ?? '').toString()); break;
        default:      cmp = (a['full_name'] ?? '').toString().compareTo((b['full_name'] ?? '').toString());
      }
      return _coachesSortAsc ? cmp : -cmp;
    });

    void toggleSort(String col) => setState(() {
      if (_coachesSortCol == col) _coachesSortAsc = !_coachesSortAsc;
      else { _coachesSortCol = col; _coachesSortAsc = true; }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(
        title: 'Registered Coaches',
        subtitle: '${_dynamicCoaches.length} coach accounts',
        child: Column(children: [
          Row(children: [
            const Spacer(),
            _resultCount(coaches.length, _dynamicCoaches.length),
          ]),
          const SizedBox(height: 10),
          // Sortable header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Expanded(flex: 1, child: Text('Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
              Expanded(flex: 2, child: _sortableColHeader('Name', 'name', _coachesSortCol, _coachesSortAsc, () => toggleSort('name'))),
              Expanded(flex: 2, child: _sortableColHeader('Email', 'email', _coachesSortCol, _coachesSortAsc, () => toggleSort('email'))),
              Expanded(flex: 2, child: _sortableColHeader('Team', 'team', _coachesSortCol, _coachesSortAsc, () => toggleSort('team'))),
              const Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
            ]),
          ),
          const SizedBox(height: 8),
          if (coaches.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(_searchQuery.isEmpty ? 'No approved coaches.' : 'No coaches match "$_searchQuery".'))
          else
            ...coaches.map((c) => _coachRow(c)),
        ]),
      ),
    );
  }

  Widget _complexTableHeader(List<String> labels) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        ...labels.map((l) => Expanded(
          flex: (l == 'Photo' || l == 'Actions') ? 1 : 2,
          child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        )).toList(),
      ]),
    );
  }

  Widget _coachRow(Map<String, dynamic> c) {
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    final name = c['full_name'] ?? 'Unknown';
    final email = c['email'] ?? 'No Email';
    final team = c['team_name'] ?? '—';
    final avatar = c['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        // Photo
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF00A651).withOpacity(0.1),
              backgroundImage: avatar != null && avatar.isNotEmpty
                  ? NetworkImage('$avatar?v=${avatar.hashCode}')
                  : null,
              child: avatar == null || avatar.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF00A651), fontWeight: FontWeight.bold, fontSize: 12)) : null,
            ),
          ),
        ),
        // Name
        Expanded(flex: 2, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        // Email
        Expanded(flex: 2, child: Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
        // Team
        Expanded(flex: 2, child: Text(team, style: const TextStyle(fontSize: 12))),
        // Actions
        Expanded(
          flex: 1,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
              onPressed: () => _showCoachEditDialog(c),
              constraints: const BoxConstraints(), padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade400),
              onPressed: () => _confirmDeleteCoach(c),
              constraints: const BoxConstraints(), padding: EdgeInsets.zero,
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _showCoachEditDialog(Map<String, dynamic> c) async {
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    final nameCtrl = TextEditingController(text: c['full_name']);
    final phoneCtrl = TextEditingController(text: c['phone']);
    final teamCtrl = TextEditingController(text: c['team_name']);
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Coach Profile'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_rounded))),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded))),
            const SizedBox(height: 12),
            TextField(controller: teamCtrl, decoration: const InputDecoration(labelText: 'Team Name', prefixIcon: Icon(Icons.shield_rounded))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving ? null : () async {
                setS(() => saving = true);
                final err = await ap.updateUserProfile(c['id'], {
                  'full_name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'team_name': teamCtrl.text.trim(),
                });
                if (!mounted) return;
                if (err == null) {
                  Navigator.pop(ctx);
                  _fetchManagementData();
                } else {
                  setS(() => saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A651), foregroundColor: Colors.white),
              child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
            ),
          ],
        );
      }),
    );
    nameCtrl.dispose(); phoneCtrl.dispose(); teamCtrl.dispose();
  }

  void _confirmDeleteCoach(Map<String, dynamic> c) {
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Coach'),
        content: Text('Are you sure you want to delete ${c['full_name']}? This will also remove their team.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await ap.deleteUser(c['id']);
              if (mounted) {
                if (err == null) {
                  _fetchManagementData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coach deleted.')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── Referees ───────────────────────────────────────────────────────────────
  Widget _buildReferees() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));

    var referees = _dynamicReferees.where((r) {
      if (_searchQuery.isEmpty) return true;
      return (r['full_name'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
             (r['email'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
             (r['phone'] as String? ?? '').toLowerCase().contains(_searchQuery);
    }).toList();

    referees.sort((a, b) {
      int cmp;
      switch (_refereesSortCol) {
        case 'email': cmp = (a['email'] ?? '').toString().compareTo((b['email'] ?? '').toString()); break;
        case 'phone': cmp = (a['phone'] ?? '').toString().compareTo((b['phone'] ?? '').toString()); break;
        default:      cmp = (a['full_name'] ?? '').toString().compareTo((b['full_name'] ?? '').toString());
      }
      return _refereesSortAsc ? cmp : -cmp;
    });

    void toggleSort(String col) => setState(() {
      if (_refereesSortCol == col) _refereesSortAsc = !_refereesSortAsc;
      else { _refereesSortCol = col; _refereesSortAsc = true; }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(
        title: 'League Referees',
        subtitle: '${_dynamicReferees.length} registered referees',
        child: Column(children: [
          Row(children: [
            const Spacer(),
            _resultCount(referees.length, _dynamicReferees.length),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Expanded(flex: 1, child: Text('Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
              Expanded(flex: 2, child: _sortableColHeader('Name', 'name', _refereesSortCol, _refereesSortAsc, () => toggleSort('name'))),
              Expanded(flex: 2, child: _sortableColHeader('Email', 'email', _refereesSortCol, _refereesSortAsc, () => toggleSort('email'))),
              Expanded(flex: 2, child: _sortableColHeader('Phone', 'phone', _refereesSortCol, _refereesSortAsc, () => toggleSort('phone'))),
              const Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
            ]),
          ),
          const SizedBox(height: 8),
          if (referees.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(_searchQuery.isEmpty ? 'No approved referees.' : 'No referees match "$_searchQuery".'))
          else
            ...referees.map((r) => _refereeRow(r)),
        ]),
      ),
    );
  }

  Widget _refereeRow(Map<String, dynamic> r) {
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    final name = r['full_name'] ?? 'Unknown';
    final email = r['email'] ?? 'No Email';
    final phone = r['phone'] ?? '—';
    final avatar = r['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
      ),
      child: Row(children: [
        // Photo
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF003087).withOpacity(0.1),
              backgroundImage: avatar != null && avatar.isNotEmpty
                  ? NetworkImage('$avatar?v=${avatar.hashCode}')
                  : null,
              child: avatar == null || avatar.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF003087), fontWeight: FontWeight.bold, fontSize: 12)) : null,
            ),
          ),
        ),
        // Name
        Expanded(flex: 2, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        // Email
        Expanded(flex: 2, child: Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
        // Phone
        Expanded(flex: 2, child: Text(phone, style: const TextStyle(fontSize: 12))),
        // Actions
        Expanded(
          flex: 1,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
              onPressed: () => _showRefereeEditDialog(r),
              constraints: const BoxConstraints(), padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade400),
              onPressed: () => _confirmDeleteReferee(r),
              constraints: const BoxConstraints(), padding: EdgeInsets.zero,
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _showRefereeEditDialog(Map<String, dynamic> r) async {
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    final nameCtrl = TextEditingController(text: r['full_name']);
    final phoneCtrl = TextEditingController(text: r['phone']);
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Referee Profile'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_rounded))),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving ? null : () async {
                setS(() => saving = true);
                final err = await ap.updateUserProfile(r['id'], {
                  'full_name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                });
                if (!mounted) return;
                if (err == null) {
                  Navigator.pop(ctx);
                  _fetchManagementData();
                } else {
                  setS(() => saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003087), foregroundColor: Colors.white),
              child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
            ),
          ],
        );
      }),
    );
    nameCtrl.dispose(); phoneCtrl.dispose();
  }

  void _confirmDeleteReferee(Map<String, dynamic> r) {
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Referee'),
        content: Text('Are you sure you want to delete ${r['full_name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await ap.deleteUser(r['id']);
              if (mounted) {
                if (err == null) {
                  _fetchManagementData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referee deleted.')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── Player Stats ────────────────────────────────────────────────────────────
  Widget _buildPlayerStats() {
    if (_isLoadingManagement) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));
    }

    // Build stat rows from live Supabase data
    final rawPlayers = _dynamicPlayers.map((p) {
      return {
        'name':    p['full_name'] ?? 'Unknown',
        'team':    p['teams']?['name'] ?? '—',
        'photo':   p['photo_url'] as String?,
        'pos':     p['position'] ?? 'FW',
        'number':  p['jersey_number'] ?? 0,
        'goals':   (p['goals']   as num?)?.toInt() ?? 0,
        'assists': (p['assists'] as num?)?.toInt() ?? 0,
      };
    }).toList();

    // Sort by goals desc, then assists
    rawPlayers.sort((a, b) {
      final cmp = (b['goals'] as int).compareTo(a['goals'] as int);
      return cmp != 0 ? cmp : (b['assists'] as int).compareTo(a['assists'] as int);
    });

    final bool hasData = rawPlayers.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── Top Scorers bar chart ────────────────────────────────────────────
        _card(title: '🥇 Top Scorers', subtitle: 'Goals this season — live from database',
          child: hasData
            ? SizedBox(
                height: 220,
                child: BarChart(BarChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= rawPlayers.length) return const SizedBox.shrink();
                        final firstName = (rawPlayers[i]['name'] as String).split(' ').first;
                        return Padding(padding: const EdgeInsets.only(top: 4),
                            child: Text(firstName, style: const TextStyle(fontSize: 9)));
                      },
                      reservedSize: 22,
                    )),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}',
                            style: const TextStyle(fontSize: 9, color: Colors.grey)))),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: rawPlayers.asMap().entries.map((e) => BarChartGroupData(
                    x: e.key,
                    barRods: [BarChartRodData(
                      toY: (e.value['goals'] as int).toDouble(),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF00A651), Color(0xFF00C853)],
                          begin: Alignment.bottomCenter, end: Alignment.topCenter),
                      width: 22,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    )],
                  )).toList(),
                )),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(children: [
                  Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No player data yet', style: TextStyle(color: Colors.grey.shade400)),
                  Text('Add players to teams to see stats here',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade300)),
                ]),
              ),
        ),
        const SizedBox(height: 18),
        // ── Player Performance Table ─────────────────────────────────────────
        _card(title: 'Player Performance Table', subtitle: 'Auto-updated from referee match reports',
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const SizedBox(width: 36),
                const Expanded(flex: 3, child: Text('Player',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                const Expanded(flex: 3, child: Text('Team',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                const Expanded(flex: 1, child: Text('Goals',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                const Expanded(flex: 1, child: Text('Assists',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                const Expanded(flex: 1, child: Text('Total',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
              ]),
            ),
            const SizedBox(height: 4),
            // Rows
            if (!hasData)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No players registered yet.',
                    style: TextStyle(color: Colors.grey.shade400)),
              )
            else
              ...rawPlayers.asMap().entries.map((e) {
                final p      = e.value;
                final pid    = p['id']?.toString() ?? '';
                final name   = p['name'] as String;
                final photo  = p['photo'] as String?;
                final goals   = p['goals'] as int;
                final assists = p['assists'] as int;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: e.key % 2 == 0 ? Colors.white : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    // Avatar
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: const Color(0xFF00A651).withOpacity(0.1),
                      backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo == null || photo.isEmpty
                          ? Text(name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF00A651), fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(flex: 3, child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    Expanded(flex: 3, child: Text(p['team'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                    Expanded(flex: 1, child: Text('$goals',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00A651)))),
                    Expanded(flex: 1, child: Text('$assists',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF003087)))),
                    Expanded(flex: 1, child: Text('${goals + assists}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),

                  ]),
                );
              }),
          ]),
        ),
      ]),
    );
  }

  // ─── Report Centre ────────────────────────────────────────────────────────────
  String _reportType = 'season'; // season | players | coaches | referees | teams | fixtures

  Widget _buildSeasonReport() => _ReportCentre(
    reportType: _reportType,
    onTypeChanged: (t) => setState(() => _reportType = t),
    dynamicPlayers:  _dynamicPlayers,
    dynamicCoaches:  _dynamicCoaches,
    dynamicReferees: _dynamicReferees,
    dynamicTeams:    _dynamicTeams,
    recentResults:   _recentResults,
    liveMatches:     _liveMatches,
    standings:       Provider.of<MatchState>(context, listen: false).standings,
    generatedFixtures: Provider.of<MatchState>(context, listen: false).generatedFixtures,
  );


  Widget _reportRow(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(k, style: TextStyle(color: Colors.grey.shade600))),
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _smallStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
      ]),
    );
  }

  // ─── Live Scores ─────────────────────────────────────────────────────────────
  Widget _buildLiveScores() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // Live Match Display
        if (_liveMatches.isNotEmpty) ...[
          ..._liveMatches.map((match) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0D0D1A), Color(0xFF1A1A3A)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.red.shade400, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('LIVE NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), 
                  child: Text(
                    _formatMatchTime(match['date_time'] as String),
                    style: const TextStyle(color: Colors.white, fontSize: 12)
                  )
                ),
              ]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _liveTeamCol(match['home_team'] as String, _getTeamEmoji(match['home_team'] as String), '${match['home_score'] ?? 0}'),
                Text('vs', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 18)),
                _liveTeamCol(match['away_team'] as String, _getTeamEmoji(match['away_team'] as String), '${match['away_score'] ?? 0}'),
              ]),
            ]),
          )),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0D0D1A), Color(0xFF1A1A3A)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              const Icon(Icons.sports_soccer_outlined, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              const Text('No Live Matches', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('All matches are currently completed or scheduled', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Recent Results
        _card(
          title: 'Recent Match Results', 
          subtitle: _recentResults.isEmpty ? 'No completed matches yet' : 'Latest ${_recentResults.length} results', 
          child: _recentResults.isEmpty 
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No match results available yet', style: TextStyle(color: Colors.grey, fontSize: 14)),
              )
            : Column(
                children: _recentResults.map((result) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(child: Text(result['home_team'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.right)),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12), 
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), 
                      decoration: BoxDecoration(color: const Color(0xFF003087), borderRadius: BorderRadius.circular(8)), 
                      child: Text('${result['home_score'] ?? 0} – ${result['away_score'] ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    ),
                    Expanded(child: Text(result['away_team'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  ]),
                )).toList(),
              )
        ),
      ]),
    );
  }

  String _formatMatchTime(String dateTimeStr) {
    try {
      final matchTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final diff = now.difference(matchTime);
      
      if (diff.inMinutes < 90) {
        return '${diff.inMinutes}\'';
      } else {
        return 'FT';
      }
    } catch (e) {
      return 'LIVE';
    }
  }

  String _getTeamEmoji(String teamName) {
    final emojiMap = {
      'Lions FC': '🦁',
      'Blue Sharks': '🦈',
      'Red Eagles': '🦅',
      'Green Foxes': '🦊',
      'Yellow Stars': '⭐',
      'Black Panthers': '🐾',
      'Purple Knights': '⚔️',
      'City Wolves': '🐺',
    };
    return emojiMap[teamName] ?? '⚽';
  }

  Widget _liveTeamCol(String name, String emoji, String score) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 28)),
      const SizedBox(height: 4),
      Text(name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      Text(score, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
    ]);
  }

  // ─── Enhanced Profile ───────────────────────────────────────────────────────
  Widget _buildProfile() {
    final ap = Provider.of<auth.AuthProvider>(context);
    final profile = ap.profile;
    // Try profile table first, fall back to auth user metadata
    final avatarUrl = (profile?['avatar_url'] as String?)?.isNotEmpty == true
        ? profile!['avatar_url'] as String
        : ap.user?.userMetadata?['avatar_url'] as String?;
    final fullName = (profile?['full_name'] as String?)?.isNotEmpty == true
        ? profile!['full_name'] as String
        : ap.user?.userMetadata?['full_name'] as String? ?? 'Admin';
    final email = (profile?['email'] as String?)?.isNotEmpty == true
        ? profile!['email'] as String
        : ap.user?.email ?? 'admin@mmu.ac.ke';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(
        title: 'Admin Profile', 
        subtitle: 'Manage your account details and preferences', 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Profile Picture Section
            Center(
              child: Column(children: [
                Stack(children: [
                  GestureDetector(
                    onTap: _showProfileImagePicker,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF003087).withOpacity(0.2), width: 3),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                      ),
                      child: CircleAvatar(
                        radius: 57,
                        backgroundColor: const Color(0xFF003087),
                        backgroundImage: _selectedProfileImage != null
                            ? MemoryImage(_selectedProfileImage!) as ImageProvider<Object>
                            : (avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage('$avatarUrl&cb=${_isUploadingProfile ? '' : ''}') as ImageProvider<Object>
                                : null),
                        onBackgroundImageError: _selectedProfileImage == null && avatarUrl != null
                            ? (_, __) {} // silently fallback to child
                            : null,
                        child: (_selectedProfileImage == null && (avatarUrl == null || avatarUrl.isEmpty))
                            ? Text(fullName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: _showProfileImagePicker,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF003087),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                        ),
                        child: _isUploadingProfile
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Text(fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(email, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003087).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'SUPER ADMINISTRATOR',
                    style: const TextStyle(
                      color: Color(0xFF003087),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ]),
            ),
            
            const SizedBox(height: 32),
            
            // Profile Form
            _buildProfileForm(ap, profile),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _saveProfileChanges(ap),
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showChangePasswordDialog,
                  icon: const Icon(Icons.lock_rounded, size: 18),
                  label: const Text('Change Password'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF003087),
                    side: const BorderSide(color: Color(0xFF003087)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileForm(auth.AuthProvider ap, Map<String, dynamic>? profile) {
    return Column(children: [
      _enhancedProfileField('Full Name', profile?['full_name'] ?? '', Icons.person_rounded),
      const SizedBox(height: 16),
      _enhancedProfileField('Email Address', profile?['email'] ?? '', Icons.email_rounded, enabled: false),
      const SizedBox(height: 16),
      _enhancedProfileField('Phone Number', profile?['phone'] ?? '', Icons.phone_rounded),
      const SizedBox(height: 16),
      _enhancedProfileField('Department', 'Information Technology', Icons.business_rounded, enabled: false),
      const SizedBox(height: 16),
      _enhancedProfileField('Employee ID', 'ADM001', Icons.badge_rounded, enabled: false),
    ]);
  }

  Widget _enhancedProfileField(String label, String value, IconData icon, {bool enabled = true}) {
    return TextField(
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: value,
        prefixIcon: Icon(icon, size: 20, color: enabled ? const Color(0xFF003087) : Colors.grey),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF003087), width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  void _showProfileImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Update Profile Picture', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          Row(children: [
            Expanded(
              child: _imagePickerOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _imagePickerOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ]),
          
          if (_selectedProfileImage != null || 
              Provider.of<auth.AuthProvider>(context, listen: false).profile?['avatar_url'] != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _removeProfileImage,
                icon: Icon(Icons.delete_rounded, color: Colors.red.shade600),
                label: Text('Remove Photo', style: TextStyle(color: Colors.red.shade600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
        ]),
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

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet
    
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedProfileImage = bytes;
      });
    }
  }

  void _removeProfileImage() {
    Navigator.pop(context); // Close bottom sheet
    setState(() {
      _selectedProfileImage = null;
    });
  }

  Future<void> _saveProfileChanges(auth.AuthProvider ap) async {
    setState(() => _isUploadingProfile = true);

    String? errorMsg;
    try {
      if (_selectedProfileImage != null) {
        // Upload using XFile wrapper (auth_provider.uploadAvatar reads bytes from it)
        final tempFile = XFile.fromData(
          _selectedProfileImage!,
          name: 'avatar.jpg',
          mimeType: 'image/jpeg',
        );
        errorMsg = await ap.uploadAvatar(tempFile);
      }

      if (errorMsg == null) {
        // Force a profile refresh so sidebar + top bar avatars update immediately
        await ap.fetchProfile();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(
                errorMsg == null ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(errorMsg == null
                  ? 'Profile photo updated!'
                  : 'Upload failed: $errorMsg'),
            ]),
            backgroundColor: errorMsg == null ? const Color(0xFF00A651) : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProfile = false;
          _selectedProfileImage = null;
        });
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isChanging = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF003087).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_rounded, color: Color(0xFF003087)),
            ),
            const SizedBox(width: 12),
            const Text('Change Password'),
          ]),
          content: SizedBox(
            width: 320,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: isChanging ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isChanging ? null : () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }
                
                setDialogState(() => isChanging = true);
                
                final ap = Provider.of<auth.AuthProvider>(context, listen: false);
                final error = await ap.updatePassword(newPasswordController.text);
                
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error == null ? 'Password changed successfully!' : 'Error: $error'),
                      backgroundColor: error == null ? const Color(0xFF00A651) : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isChanging
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        decoration: InputDecoration(
          labelText: label, labelStyle: const TextStyle(fontSize: 12),
          hintText: value,
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // ─── Settings ───────────────────────────────────────────────────────────────
  Widget _buildSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // System Settings card
        _card(
          title: 'System Settings',
          subtitle: 'Platform configuration',
          child: Column(children: [
            _settingRow(
              label: 'Email Notifications',
              value: _settingEmailNotifications,
              description: 'Send email alerts for approvals & events',
              onChanged: (v) {
                setState(() => _settingEmailNotifications = v);
                _showSettingsSaved('Email notifications ${v ? 'enabled' : 'disabled'}');
              },
            ),
            const Divider(height: 1),
            _settingRow(
              label: 'Auto-approve Spectators',
              value: _settingAutoApproveSpectators,
              description: 'New spectator accounts are approved instantly',
              onChanged: (v) {
                setState(() => _settingAutoApproveSpectators = v);
                _showSettingsSaved('Auto-approve spectators ${v ? 'enabled' : 'disabled'}');
              },
            ),
            const Divider(height: 1),
            _settingRow(
              label: 'Maintenance Mode',
              value: _settingMaintenanceMode,
              description: 'Spectator portal shows maintenance message',
              onChanged: (v) {
                setState(() => _settingMaintenanceMode = v);
                _showSettingsSaved('Maintenance mode ${v ? 'ON — spectators will see a notice' : 'OFF'}');
              },
            ),
            const Divider(height: 1),
            _settingRow(
              label: 'Allow New Registrations',
              value: _settingAllowRegistrations,
              description: 'Accept new coach/referee sign-ups',
              onChanged: (v) {
                setState(() => _settingAllowRegistrations = v);
                _showSettingsSaved('New registrations ${v ? 'opened' : 'closed'}');
              },
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // Season Management card
        _card(
          title: 'Season Management',
          subtitle: 'Configure the active season details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _labeledField('Season Name', _seasonNameCtrl, 'e.g. MMU Soccer League 2026'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _labeledField('Start Date', _seasonStartCtrl, 'e.g. 01 Jan 2026')),
                const SizedBox(width: 12),
                Expanded(child: _labeledField('End Date', _seasonEndCtrl, 'e.g. 30 Jun 2026')),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _settingsSaving ? null : _saveSeasonSettings,
                  icon: _settingsSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_settingsSaving ? 'Saving…' : 'Update Season'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Danger Zone card
        _card(
          title: 'Danger Zone',
          subtitle: 'Irreversible administrative actions',
          child: Column(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.delete_sweep_rounded, color: Colors.red.shade600, size: 20),
              ),
              title: Text('Clear All Fixtures', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade700, fontSize: 13)),
              subtitle: const Text('Remove all scheduled matches from the season', style: TextStyle(fontSize: 11)),
              trailing: OutlinedButton(
                onPressed: _confirmClearFixtures,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _settingRow({
    required String label,
    required bool value,
    required String description,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF003087),
          ),
        ],
      ),
    );
  }

  Widget _labeledField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF003087), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _showSettingsSaved(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ]),
        backgroundColor: const Color(0xFF003087),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveSeasonSettings() async {
    final name = _seasonNameCtrl.text.trim();
    final start = _seasonStartCtrl.text.trim();
    final end = _seasonEndCtrl.text.trim();
    if (name.isEmpty || start.isEmpty || end.isEmpty) {
      _showSettingsSaved('Please fill in all season fields');
      return;
    }
    setState(() => _settingsSaving = true);
    try {
      await Supabase.instance.client.from('season_settings').upsert({
        'id': 1,
        'name': name,
        'start_date': start,
        'end_date': end,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Table may not exist yet — still update the live label
    } finally {
      if (mounted) {
        // ── Push the new season label to AppState so the spectator
        //    hero text and standings subtitle update instantly ──────
        context.read<AppState>().setSeasonLabel(name);
        setState(() => _settingsSaving = false);
        _showSettingsSaved('Season label updated to "$name"');
      }
    }
  }

  void _confirmClearFixtures() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Fixtures?'),
        content: const Text('This will permanently delete all scheduled matches. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<MatchState>().clearAllFixtures();
              if (mounted) _showSettingsSaved('All fixtures cleared.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  // ─── Shared helpers ──────────────────────────────────────────────────────────
  Widget _card({required String title, required String subtitle, required Widget child}) {
    return _HoverCard(title: title, subtitle: subtitle, child: child);
  }

  Widget _posBadge(String pos) {
    final colors = {'GK': Colors.purple, 'DF': Colors.blue, 'MF': Colors.green, 'FW': Colors.orange};
    final c = colors[pos] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(4)), 
      child: Text(pos, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold))
    );
  }

  // ─── Shared Table Helpers ─────────────────────────────────────────────────

  /// Sortable column header — tap to toggle asc/desc.
  Widget _sortableColHeader(String label, String col, String currentCol, bool asc,
      VoidCallback onTap, {TextAlign align = TextAlign.left}) {
    final isActive = currentCol == col;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: align == TextAlign.center
            ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 12,
            color: isActive ? const Color(0xFF003087) : Colors.grey,
          )),
          const SizedBox(width: 2),
          Icon(
            isActive ? (asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                     : Icons.unfold_more_rounded,
            size: 12,
            color: isActive ? const Color(0xFF003087) : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  /// Filter chip row (e.g. All / Coach / Referee / Player).
  Widget _filterChips(List<String> options, String current, ValueChanged<String> onSelect) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((o) {
          final isActive = o == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF003087) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  o[0].toUpperCase() + o.substring(1),
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Small result count indicator.
  Widget _resultCount(int n, int total) {
    if (n == total) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF003087).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$n of $total', style: const TextStyle(fontSize: 11, color: Color(0xFF003087), fontWeight: FontWeight.bold)),
    );
  }

  Widget _tableHeader(List<String> cols) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: cols.map((c) => Expanded(child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)))).toList()),
    );
  }

  Widget _tableRow(List<String> cells, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: cells.asMap().entries.map((e) {
          final isLast = e.key == cells.length - 1;
          return Expanded(child: isLast
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(e.value, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                )
              : Text(e.value, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis));
        }).toList(),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade400)),
        ]),
      ),
    );
  }
}

// ─── Season Gauge CustomPainter ───────────────────────────────────────────────

class _SeasonGaugePainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  const _SeasonGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    // Cap radius so the arc never overflows the canvas on small screens
    final radius = math.min(size.width * 0.42, size.height * 0.78);
    final cy     = size.height * 0.94;

    const startAngle = math.pi;       // 180° — left side
    const sweepFull  = math.pi;       // 180° sweep — full semicircle

    // ── Grey track ───────────────────────────────────────────────────────────
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle, sweepFull, false,
      Paint()
        ..color = const Color(0xFFF0F2F5)
        ..strokeWidth = 18
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── Green completed arc ───────────────────────────────────────────────────
    if (progress > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweepFull * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF006B35), Color(0xFF00C853)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..strokeWidth = 18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Needle dot at arc tip ─────────────────────────────────────────────────
    final angle = startAngle + sweepFull * progress.clamp(0.0, 1.0);
    final tipX  = cx + radius * math.cos(angle);
    final tipY  = cy + radius * math.sin(angle);

    canvas.drawCircle(Offset(tipX, tipY), 12,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(tipX, tipY), 7,
        Paint()..color = const Color(0xFF00A651)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(tipX, tipY), 12,
        Paint()
          ..color = const Color(0xFF00A651).withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);

    // ── Centre percentage text ────────────────────────────────────────────────
    final pct = (progress * 100).round();

    final bigTp = TextPainter(
      text: TextSpan(
        text: '$pct%',
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    bigTp.paint(canvas, Offset(cx - bigTp.width / 2, cy - 52));

    final subTp = TextPainter(
      text: const TextSpan(
        text: 'Season Ended',
        style: TextStyle(fontSize: 11, color: Color(0xFF9BA3B4)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(canvas, Offset(cx - subTp.width / 2, cy - 14));
  }

  @override
  bool shouldRepaint(_SeasonGaugePainter old) => old.progress != progress;
}

// ─── Hover Card ───────────────────────────────────────────────────────────────

class _HoverCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _HoverCard({required this.title, required this.subtitle, required this.child});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -4.0 : 0.0, 0),
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered
                ? const Color(0xFF003087).withOpacity(0.18)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: const Color(0xFF003087).withOpacity(0.10),
                    blurRadius: 24, offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 3),
                  ),
                ]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  if (widget.subtitle.isNotEmpty)
                    Text(widget.subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ]),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  color: _hovered
                      ? const Color(0xFF003087)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _ReportCentre extends StatefulWidget {
  final String reportType;
  final ValueChanged<String> onTypeChanged;
  final List<Map<String,dynamic>> dynamicPlayers, dynamicCoaches, dynamicReferees, dynamicTeams, recentResults, liveMatches;
  final List<StandingEntry> standings;
  final List<GeneratedFixture> generatedFixtures;
  const _ReportCentre({required this.reportType, required this.onTypeChanged, required this.dynamicPlayers, required this.dynamicCoaches, required this.dynamicReferees, required this.dynamicTeams, required this.recentResults, required this.liveMatches, required this.standings, required this.generatedFixtures});
  @override State<_ReportCentre> createState() => _ReportCentreState();
}

class _ReportCentreState extends State<_ReportCentre> {
  static const navy = Color(0xFF003087);
  static const green = Color(0xFF00A651);

  final types = [
    ('season','Full Season','📊'), ('players','Players','👟'), ('coaches','Coaches','🧑‍💼'),
    ('referees','Referees','🦺'), ('teams','Teams','🏆'), ('fixtures','Fixtures','📅'),
  ];

  Widget _header(String title, String subtitle) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [navy, Color(0xFF1A4FA0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Image.asset('assets/images/mmulogo.png', height: 56, errorBuilder: (_,__,___) => const Icon(Icons.school, color: Colors.white, size: 48)),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('MMU UNIVERSITY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5)),
          Text('Department of Sports', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
          Text('Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
        ]),
      ]),
      Container(height: 1, color: Colors.white.withOpacity(0.3), margin: const EdgeInsets.symmetric(vertical: 12)),
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12), textAlign: TextAlign.center),
    ]),
  );

  Widget _intro(String text) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: navy.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: navy.withOpacity(0.12))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.format_quote_rounded, color: navy.withOpacity(0.5), size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.6))),
    ]),
  );

  Widget _card(String title, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      child,
    ]),
  );

  Widget _statRow(List<(String,String,IconData,Color)> items) => GridView.count(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2, childAspectRatio: 2.4, mainAxisSpacing: 10, crossAxisSpacing: 10,
    children: items.map((e) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: e.$4.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: e.$4.withOpacity(0.15))),
      child: Row(children: [
        Icon(e.$3, color: e.$4, size: 22),
        const SizedBox(width: 10),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.$2, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: e.$4)),
          Text(e.$1, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ]),
      ]),
    )).toList(),
  );

  Widget _table(List<String> cols, List<List<String>> rows, {List<double>? flex}) {
    final f = flex ?? List.generate(cols.length, (_) => 1.0);
    return Column(children: [
      Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(8)),
        child: Row(children: cols.asMap().entries.map((e) => Expanded(flex: f[e.key].toInt(), child: Text(e.value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)))).toList())),
      const SizedBox(height: 4),
      ...rows.asMap().entries.map((re) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        color: re.key % 2 == 0 ? Colors.white : Colors.grey.shade50,
        child: Row(children: re.value.asMap().entries.map((ce) => Expanded(flex: f[ce.key].toInt(), child: Text(ce.value, style: const TextStyle(fontSize: 12)))).toList()),
      )),
    ]);
  }

  Widget _barChart(List<String> labels, List<double> values, Color color) {
    if (values.isEmpty) return const SizedBox(height: 160, child: Center(child: Text('No data', style: TextStyle(color: Colors.grey))));
    return SizedBox(height: 200, child: BarChart(BarChartData(
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, _) {
          final i = v.toInt(); if (i < 0 || i >= labels.length) return const SizedBox.shrink();
          return Text(labels[i].split(' ').first, style: const TextStyle(fontSize: 9));
        })),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.grey)))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      barGroups: values.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: e.value, color: color, width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(5))),
      ])).toList(),
    )));
  }

  Widget _buildSeason() {
    final fp = _filteredPlayers;
    final fc = _filteredCoaches;
    final fr = _filteredReferees;
    final fx = _filteredFixtures;
    final rs = _filteredResults;
    final total = rs.length + widget.liveMatches.length;
    final goals  = rs.fold(0, (s, r) => s + ((r['home_score'] as int? ?? 0) + (r['away_score'] as int? ?? 0)));
    final yellow = fp.fold(0, (s, p) => s + ((p['yellow_cards'] as int?) ?? 0));
    final red    = fp.fold(0, (s, p) => s + ((p['red_cards']    as int?) ?? 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header('MMU Soccer League 2026 — Full Season Report',
          'Period: $_periodLabel  •  Comprehensive overview of all league activities, statistics and outcomes.'),
      _intro('This report provides an authoritative summary of the MMU University Sports Department soccer league activities. It covers all registered teams, player performances, match results, and administrative statistics for the 2026 season, compiled from data entered by appointed referees and team officials.'),
      _statRow([
        ('Total Matches', '$total',         Icons.sports_soccer_rounded,  navy),
        ('Total Goals',   '$goals',         Icons.emoji_events_rounded,   green),
        ('Yellow Cards',  '$yellow',        Icons.rectangle_rounded,      const Color(0xFFF9A825)),
        ('Red Cards',     '$red',           Icons.rectangle_rounded,      const Color(0xFFC62828)),
        ('Teams',         '${widget.dynamicTeams.length}', Icons.shield_rounded, const Color(0xFF7B1FA2)),
        ('Players',       '${fp.length}',   Icons.people_rounded,         const Color(0xFF0288D1)),
        ('Coaches',       '${fc.length}',   Icons.sports_rounded,         const Color(0xFF00796B)),
        ('Referees',      '${fr.length}',   Icons.gavel_rounded,          const Color(0xFF5D4037)),
      ]),
      const SizedBox(height: 16),
      _card('League Standings', _table(
        ['#', 'Team', 'P', 'W', 'D', 'L', 'GF', 'GA', 'Pts'],
        widget.standings.asMap().entries.map((e) => [(e.key+1).toString(), e.value.team, '${e.value.played}',
            '${e.value.wins}', '${e.value.draws}', '${e.value.losses}',
            '${e.value.goalsFor}', '${e.value.goalsAgainst}', '${e.value.points}']).toList(),
        flex: [1,3,1,1,1,1,1,1,1],
      )),
      _card('Goals Per Team', _barChart(
        widget.standings.map((s) => s.team).toList(),
        widget.standings.map((s) => s.goalsFor.toDouble()).toList(),
        navy,
      )),
      _card('Points Per Team', _barChart(
        widget.standings.map((s) => s.team).toList(),
        widget.standings.map((s) => s.points.toDouble()).toList(),
        green,
      )),
      _buildFooter(),
    ]);
  }

  Widget _buildPlayers() {
    final fp = _filteredPlayers;
    final sorted = List<Map<String, dynamic>>.from(fp)
      ..sort((a, b) => ((b['goals'] as int? ?? 0)).compareTo((a['goals'] as int? ?? 0)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header('Player Performance Report',
          'Period: $_periodLabel  •  Individual player statistics including goals, assists, cards, and appearances.'),
      _intro('This section details the performance of all registered players across the season. Data is automatically aggregated from referee match reports submitted after each official fixture.'),
      _statRow([
        ('Players Registered', '${fp.length}', Icons.people_rounded, navy),
        ('Total Goals',   '${fp.fold(0, (s,p) => s + (p['goals']        as int? ?? 0))}', Icons.sports_soccer_rounded,  green),
        ('Total Assists', '${fp.fold(0, (s,p) => s + (p['assists']      as int? ?? 0))}', Icons.assistant_rounded,       const Color(0xFF0288D1)),
        ('Yellow Cards',  '${fp.fold(0, (s,p) => s + (p['yellow_cards'] as int? ?? 0))}', Icons.rectangle_rounded, const Color(0xFFF9A825)),
      ]),
      const SizedBox(height: 16),
      _card('Top Scorers Chart', _barChart(
        sorted.take(8).map((p) => p['full_name'] as String? ?? '?').toList(),
        sorted.take(8).map((p) => (p['goals'] as int? ?? 0).toDouble()).toList(),
        green,
      )),
      _card('Full Player Statistics', _table(
        ['Player', 'Team', 'Pos', 'G', 'A', 'YC', 'RC'],
        sorted.map((p) => <String>[p['full_name'] ?? '—', (p['teams'] as Map?)?['name'] ?? '—',
            p['position'] ?? '—', '${p['goals'] ?? 0}', '${p['assists'] ?? 0}',
            '${p['yellow_cards'] ?? 0}', '${p['red_cards'] ?? 0}']).toList(),
        flex: [3,3,1,1,1,1,1],
      )),
    ]);
  }

  Widget _buildCoaches() {
    final fc = _filteredCoaches;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header('Coaching Staff Report',
          'Period: $_periodLabel  •  Registered coaches, team assignments, and contact information.'),
      _intro('This section lists all coaches registered with the MMU Sports Department. Coaches are responsible for player squad management and lineup submissions for each fixture.'),
      _statRow([
        ('Total Coaches', '${fc.length}',                Icons.sports_rounded, navy),
        ('Active Teams',  '${widget.dynamicTeams.length}', Icons.shield_rounded, green),
        ('', '', Icons.circle, Colors.transparent),
        ('', '', Icons.circle, Colors.transparent),
      ]),
      const SizedBox(height: 16),
      _card('Registered Coaches', _table(
        ['Name', 'Email', 'Team', 'Status'],
        fc.map((c) => <String>[c['full_name'] ?? '—', c['email'] ?? '—',
            c['team_name'] ?? (c['teams'] as Map?)?['name'] ?? '—', 'Active']).toList(),
        flex: [3,3,2,1],
      )),
      _buildFooter(),
    ]);
  }

  Widget _buildReferees() {
    final fr = _filteredReferees;
    final fx = _filteredFixtures;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header('Referee Report',
          'Period: $_periodLabel  •  Registered officials and fixture assignments for the season.'),
      _intro('This section covers all referees approved by the Sports Department. Referees are responsible for officiating fixtures, recording match events, and submitting official match reports.'),
      _statRow([
        ('Total Referees', '${fr.length}',  Icons.gavel_rounded,          navy),
        ('Fixtures',       '${fx.length}',  Icons.calendar_month_rounded, green),
        ('', '', Icons.circle, Colors.transparent),
        ('', '', Icons.circle, Colors.transparent),
      ]),
      const SizedBox(height: 16),
      _card('Registered Referees', _table(
        ['Name', 'Email', 'Phone', 'Status'],
        fr.map((r) => <String>[r['full_name'] ?? '—', r['email'] ?? '—', r['phone'] ?? '—', 'Active']).toList(),
        flex: [3,3,2,1],
      )),
      _buildFooter(),
    ]);
  }

  Widget _buildTeams() {
    final rs = _filteredResults;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header('Team Performance Report',
          'Period: $_periodLabel  •  Team standings, wins/losses, goals, and squad sizes for the season.'),
      _intro('This section provides a comparative analysis of all registered teams in the MMU Soccer League. Data reflects cumulative performance across all completed fixtures.'),
      _statRow([
        ('Total Teams',       '${widget.dynamicTeams.length}', Icons.shield_rounded,        navy),
        ('Completed Matches', '${rs.length}',                  Icons.check_circle_rounded,  green),
        ('', '', Icons.circle, Colors.transparent),
        ('', '', Icons.circle, Colors.transparent),
      ]),
      const SizedBox(height: 16),
      _card('Team Standings', _table(
        ['Team', 'P', 'W', 'D', 'L', 'GF', 'GA', 'GD', 'Pts'],
        widget.standings.map((s) => [s.team, '${s.played}', '${s.wins}', '${s.draws}', '${s.losses}',
            '${s.goalsFor}', '${s.goalsAgainst}', '${s.goalDifference}', '${s.points}']).toList(),
        flex: [3,1,1,1,1,1,1,1,1],
      )),
      _card('Goals Scored Per Team', _barChart(widget.standings.map((s) => s.team).toList(), widget.standings.map((s) => s.goalsFor.toDouble()).toList(), green)),
      _card('Points Per Team',       _barChart(widget.standings.map((s) => s.team).toList(), widget.standings.map((s) => s.points.toDouble()).toList(), navy)),
      _buildFooter(),
    ]);
  }

  Widget _buildFixtures() {
    final fx        = _filteredFixtures;
    final completed = fx.where((f) => f.status == 'completed').toList();
    final upcoming  = fx.where((f) => f.status == 'scheduled').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header('Fixtures & Results Report',
          'Period: $_periodLabel  •  All scheduled and completed fixtures for the current season.'),
      _intro('This section presents the full fixture list for the MMU Soccer League 2026 season including scheduled matches, results, venues, and assigned referees.'),
      _statRow([
        ('Total Fixtures', '${fx.length}',              Icons.calendar_month_rounded, navy),
        ('Completed',      '${completed.length}',       Icons.check_circle_rounded,   green),
        ('Upcoming',       '${upcoming.length}',        Icons.schedule_rounded,       const Color(0xFF0288D1)),
        ('Live',           '${widget.liveMatches.length}', Icons.circle,             Colors.red),
      ]),
      const SizedBox(height: 16),
      _card('Completed Results', _table(
        ['Home', 'Score', 'Away', 'Venue', 'Ref'],
        completed.map((f) => [f.homeTeam, '${f.homeScore}–${f.awayScore}', f.awayTeam, f.venue, f.assignedReferee ?? '—']).toList(),
        flex: [2,1,2,2,2],
      )),
      _card('Upcoming Fixtures', _table(
        ['Home', 'Away', 'Date', 'Venue'],
        upcoming.map((f) => [f.homeTeam, f.awayTeam, '${f.dateTime.day}/${f.dateTime.month}/${f.dateTime.year}', f.venue]).toList(),
        flex: [2,2,1,2],
      )),
      _buildFooter(),
    ]);
  }

  Widget _buildFooter() => Container(
    margin: const EdgeInsets.only(top: 32, bottom: 40),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OFFICIAL REPORT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          const Text('MMU Department of Sports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navy)),
          const Text('Athletics & Competitions Office', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: navy.withOpacity(0.2), width: 2)),
          child: const Icon(Icons.verified_user_rounded, color: navy, size: 32),
        ),
      ]),
      const SizedBox(height: 20),
      const Text(
        'This document is an electronically generated official record of the Multi-Media University Sports Department. All data contained herein is verified against referee match reports and official league records as of the timestamp provided at the head of this document.',
        style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.email_outlined, size: 14, color: Colors.grey),
        SizedBox(width: 4),
        Text('mmusport@mmu.ac.ug', style: TextStyle(fontSize: 11, color: Colors.grey)),
        SizedBox(width: 20),
        Icon(Icons.language_rounded, size: 14, color: Colors.grey),
        SizedBox(width: 4),
        Text('www.mmu.ac.ke/sports', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    ]),
  );

  // ── PDF generation ────────────────────────────────────────────────────────
  bool _generatingPdf = false;

  // ── Date range filter ─────────────────────────────────────────────────────
  DateTime? _fromDate;
  DateTime? _toDate;

  bool _inRange(DateTime? dt) {
    if (dt == null) return true; // no date field → always include
    final from = _fromDate;
    final to   = _toDate != null
        ? DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59)
        : null;
    if (from != null && dt.isBefore(from)) return false;
    if (to   != null && dt.isAfter(to))   return false;
    return true;
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    try { return DateTime.parse(val.toString()); } catch (_) { return null; }
  }

  List<Map<String, dynamic>> get _filteredPlayers => (_fromDate == null && _toDate == null)
      ? widget.dynamicPlayers
      : widget.dynamicPlayers.where((p) => _inRange(_parseDate(p['created_at']))).toList();

  List<Map<String, dynamic>> get _filteredCoaches => (_fromDate == null && _toDate == null)
      ? widget.dynamicCoaches
      : widget.dynamicCoaches.where((c) => _inRange(_parseDate(c['created_at']))).toList();

  List<Map<String, dynamic>> get _filteredReferees => (_fromDate == null && _toDate == null)
      ? widget.dynamicReferees
      : widget.dynamicReferees.where((r) => _inRange(_parseDate(r['created_at']))).toList();

  List<Map<String, dynamic>> get _filteredResults => (_fromDate == null && _toDate == null)
      ? widget.recentResults
      : widget.recentResults.where((r) => _inRange(_parseDate(r['date_time'] ?? r['created_at']))).toList();

  List<GeneratedFixture> get _filteredFixtures => (_fromDate == null && _toDate == null)
      ? widget.generatedFixtures
      : widget.generatedFixtures.where((f) => _inRange(f.dateTime)).toList();

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  String get _periodLabel {
    if (_fromDate == null && _toDate == null) return 'Full Season';
    if (_fromDate != null && _toDate != null) return '${_fmtDate(_fromDate!)} – ${_fmtDate(_toDate!)}';
    if (_fromDate != null) return 'From ${_fmtDate(_fromDate!)}';
    return 'Until ${_fmtDate(_toDate!)}';
  }

  Future<void> _pickFrom(BuildContext ctx) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _toDate ?? DateTime(2030),
      helpText: 'Report From Date',
    );
    if (picked != null) setState(() => _fromDate = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickTo(BuildContext ctx) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Report To Date',
    );
    if (picked != null) setState(() => _toDate = DateTime(picked.year, picked.month, picked.day));
  }

  void _clearDates() => setState(() { _fromDate = null; _toDate = null; });

  Widget _dateFilterBar() {
    final bool active = _fromDate != null || _toDate != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF003087).withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? const Color(0xFF003087).withOpacity(0.2) : Colors.grey.shade200),
      ),
      child: Row(children: [
        const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF003087)),
        const SizedBox(width: 8),
        const Text('Period:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(width: 8),
        // FROM chip
        GestureDetector(
          onTap: () => _pickFrom(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _fromDate != null ? const Color(0xFF003087) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _fromDate != null ? const Color(0xFF003087) : Colors.grey.shade300),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: _fromDate != null ? Colors.white : Colors.grey),
              const SizedBox(width: 4),
              Text(
                _fromDate != null ? _fmtDate(_fromDate!) : 'From',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _fromDate != null ? Colors.white : Colors.grey.shade600),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('→', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
        ),
        // TO chip
        GestureDetector(
          onTap: () => _pickTo(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _toDate != null ? const Color(0xFF003087) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _toDate != null ? const Color(0xFF003087) : Colors.grey.shade300),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_rounded, size: 12, color: _toDate != null ? Colors.white : Colors.grey),
              const SizedBox(width: 4),
              Text(
                _toDate != null ? _fmtDate(_toDate!) : 'To',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _toDate != null ? Colors.white : Colors.grey.shade600),
              ),
            ]),
          ),
        ),
        if (active) ...[
          const SizedBox(width: 8),
          // Active badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00A651).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Filtered', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
          ),
          const SizedBox(width: 6),
          // Clear button
          GestureDetector(
            onTap: _clearDates,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Icon(Icons.close_rounded, size: 14, color: Colors.red.shade600),
            ),
          ),
        ],
        const Spacer(),
        if (active)
          Text(_periodLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  Future<void> _generateAndDownloadPdf() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildPdfBytes();
      final label = _reportLabel();
      final fileName = 'MMU_${label}_Report';
      // Works on Web (browser download), Android (Downloads folder), iOS (Files app)
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF downloaded successfully'),
            backgroundColor: Color(0xFF003087),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _generateAndSharePdf() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildPdfBytes();
      final label = _reportLabel();
      // On web this will download; on mobile it opens the share sheet
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'MMU_${label}_Report.pdf', mimeType: 'application/pdf')],
        subject: 'MMU $label Report',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  String _reportLabel() {
    switch (widget.reportType) {
      case 'players':  return 'Players';
      case 'coaches':  return 'Coaches';
      case 'referees': return 'Referees';
      case 'teams':    return 'Teams';
      case 'fixtures': return 'Fixtures';
      default:         return 'Season';
    }
  }

  Future<Uint8List> _buildPdfBytes() async {
    final doc   = pw.Document();
    final now   = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    final label   = _reportLabel();
    final navy    = PdfColors.blue900;
    final green   = PdfColor.fromHex('#00A651');
    final yellow  = PdfColor.fromHex('#F9A825');
    final red2    = PdfColor.fromHex('#C62828');
    final purple2 = PdfColor.fromHex('#7B1FA2');
    final blue2   = PdfColor.fromHex('#0288D1');
    final teal2   = PdfColor.fromHex('#00796B');
    final brown2  = PdfColor.fromHex('#5D4037');

    // ── helpers ──────────────────────────────────────────────────────────────

    pw.Widget statCard(String lbl, String val, PdfColor color) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 6),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border(left: pw.BorderSide(color: color, width: 4)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(val, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(lbl, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        ]),
      ),
    );

    pw.Widget barChart(String title, List<String> labels, List<double> values, PdfColor color) {
      if (values.isEmpty || values.every((v) => v == 0)) return pw.SizedBox();
      final maxVal = values.reduce((a, b) => a > b ? a : b);
      const chartH = 70.0;
      const barW   = 26.0;
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navy)),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: values.asMap().entries.map((e) {
            final bH  = maxVal > 0 ? (e.value / maxVal * chartH).clamp(3.0, chartH) : 3.0;
            final lbl = labels.length > e.key ? labels[e.key].split(' ').first : '';
            return pw.Container(
              width: barW,
              margin: const pw.EdgeInsets.only(right: 4),
              child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Text('${e.value.toInt()}', style: pw.TextStyle(fontSize: 7, color: color)),
                pw.SizedBox(height: 2),
                pw.Container(width: barW - 4, height: bH, color: color),
                pw.SizedBox(height: 3),
                pw.Text(lbl, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
              ]),
            );
          }).toList(),
        ),
        pw.SizedBox(height: 14),
      ]);
    }

    pw.Widget dataTable(List<String> headers, List<List<String>> rows) {
      if (rows.isEmpty) return pw.Text('No data available.', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8));
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 7),
        headerDecoration: pw.BoxDecoration(color: navy),
        cellStyle: const pw.TextStyle(fontSize: 7),
        oddRowDecoration: pw.BoxDecoration(color: PdfColors.grey100),
        border: null,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      );
    }

    pw.Widget sectionTitle(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 5),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navy)),
    );

    pw.Widget introBox(String text) => pw.Container(
      padding: const pw.EdgeInsets.all(9),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(left: pw.BorderSide(color: navy, width: 3)),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    );

    pw.Widget footer() => pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: PdfColors.grey100),
      child: pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('MMU Department of Sports — Official Report',
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: navy)),
          pw.Text('Period: $_periodLabel', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ]),
        pw.SizedBox(height: 5),
        pw.Text(
          'This document is an electronically generated official record of the Multi-Media University Sports Department. All data is verified against referee match reports and official league records as of the timestamp provided above.',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.Text('mmusport@mmu.ac.ug  |  www.mmu.ac.ke/sports',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
        ]),
      ]),
    );

    // ── data ─────────────────────────────────────────────────────────────────

    final fp = _filteredPlayers;
    final fc = _filteredCoaches;
    final fr = _filteredReferees;
    final fx = _filteredFixtures;
    final rs = _filteredResults;
    final st = widget.standings;
    final totalGoals  = rs.fold(0, (s, r) => s + ((r['home_score'] as int? ?? 0) + (r['away_score'] as int? ?? 0)));
    final totalYellow = fp.fold(0, (s, p) => s + ((p['yellow_cards'] as int?) ?? 0));
    final totalRed    = fp.fold(0, (s, p) => s + ((p['red_cards']    as int?) ?? 0));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('OFFICIAL REPORT', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey, letterSpacing: 1.5)),
            pw.SizedBox(height: 2),
            pw.Text('MMU Department of Sports',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: navy)),
            pw.Text('$label Report  •  Period: $_periodLabel',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            pw.Text('mmusport@mmu.ac.ug', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ]),
        ]),
        pw.SizedBox(height: 6),
        pw.Divider(color: navy, thickness: 2),
        pw.SizedBox(height: 8),
      ]),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('MMU UniLeague — Confidential', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
      ]),
      build: (_) {
        switch (widget.reportType) {

          // ── PLAYERS ──────────────────────────────────────────────────────
          case 'players':
            final sorted = List<Map<String, dynamic>>.from(fp)
              ..sort((a, b) => ((b['goals'] as int? ?? 0)).compareTo((a['goals'] as int? ?? 0)));
            final pGoals   = fp.fold<int>(0, (s, p) => s + (p['goals']        as int? ?? 0));
            final pAssists = fp.fold<int>(0, (s, p) => s + (p['assists']      as int? ?? 0));
            final pYellow  = fp.fold<int>(0, (s, p) => s + (p['yellow_cards'] as int? ?? 0));
            return [
              introBox('This section details the performance of all registered players across the season. Data is automatically aggregated from referee match reports submitted after each official fixture.'),
              pw.Row(children: [
                statCard('Players Registered', '${fp.length}', navy),
                statCard('Total Goals',         '$pGoals',      green),
                statCard('Total Assists',        '$pAssists',    blue2),
                statCard('Yellow Cards',         '$pYellow',     yellow),
              ]),
              pw.SizedBox(height: 12),
              barChart('Top Scorers',
                sorted.take(8).map((p) => p['full_name'] as String? ?? '?').toList(),
                sorted.take(8).map((p) => (p['goals'] as int? ?? 0).toDouble()).toList(),
                green,
              ),
              sectionTitle('Full Player Statistics'),
              dataTable(
                ['Player', 'Team', 'Pos', 'Goals', 'Assists', 'YC', 'RC'],
                sorted.map((p) => <String>[
                  p['full_name']?.toString() ?? '—',
                  (p['teams'] as Map?)?['name']?.toString() ?? '—',
                  p['position']?.toString() ?? '—',
                  '${p['goals'] ?? 0}', '${p['assists'] ?? 0}',
                  '${p['yellow_cards'] ?? 0}', '${p['red_cards'] ?? 0}',
                ]).toList(),
              ),
              footer(),
            ];

          // ── COACHES ──────────────────────────────────────────────────────
          case 'coaches':
            return [
              introBox('This section lists all coaches registered with the MMU Sports Department. Coaches are responsible for player squad management and lineup submissions for each fixture.'),
              pw.Row(children: [
                statCard('Total Coaches', '${fc.length}',                  navy),
                statCard('Active Teams',  '${widget.dynamicTeams.length}', green),
                statCard('', '', teal2),
                statCard('', '', teal2),
              ]),
              sectionTitle('Registered Coaches'),
              dataTable(
                ['Name', 'Email', 'Team', 'Status'],
                fc.map((c) => <String>[
                  c['full_name']?.toString() ?? '—',
                  c['email']?.toString() ?? '—',
                  (c['team_name'] ?? (c['teams'] as Map?)?['name'])?.toString() ?? '—',
                  'Active',
                ]).toList(),
              ),
              footer(),
            ];

          // ── REFEREES ─────────────────────────────────────────────────────
          case 'referees':
            return [
              introBox('This section covers all referees approved by the Sports Department. Referees are responsible for officiating fixtures and submitting official match reports.'),
              pw.Row(children: [
                statCard('Total Referees', '${fr.length}', navy),
                statCard('Fixtures',        '${fx.length}', green),
                statCard('', '', blue2),
                statCard('', '', blue2),
              ]),
              sectionTitle('Registered Referees'),
              dataTable(
                ['Name', 'Email', 'Phone', 'Status'],
                fr.map((r) => <String>[
                  r['full_name']?.toString() ?? '—',
                  r['email']?.toString() ?? '—',
                  r['phone']?.toString() ?? '—',
                  'Active',
                ]).toList(),
              ),
              footer(),
            ];

          // ── TEAMS ────────────────────────────────────────────────────────
          case 'teams':
            return [
              introBox('This section provides a comparative analysis of all registered teams in the MMU Soccer League. Data reflects cumulative performance across all completed fixtures.'),
              pw.Row(children: [
                statCard('Total Teams',       '${widget.dynamicTeams.length}', navy),
                statCard('Completed Matches', '${rs.length}',                  green),
                statCard('Total Goals',        '$totalGoals',                   blue2),
                statCard('', '', teal2),
              ]),
              sectionTitle('Team Standings'),
              dataTable(
                ['Team', 'P', 'W', 'D', 'L', 'GF', 'GA', 'GD', 'Pts'],
                st.map((s) => <String>[
                  s.team, '${s.played}', '${s.wins}', '${s.draws}',
                  '${s.losses}', '${s.goalsFor}', '${s.goalsAgainst}',
                  '${s.goalDifference}', '${s.points}',
                ]).toList(),
              ),
              pw.SizedBox(height: 12),
              barChart('Goals Scored Per Team',
                st.map((s) => s.team).toList(),
                st.map((s) => s.goalsFor.toDouble()).toList(),
                green,
              ),
              barChart('Points Per Team',
                st.map((s) => s.team).toList(),
                st.map((s) => s.points.toDouble()).toList(),
                navy,
              ),
              footer(),
            ];

          // ── FIXTURES ─────────────────────────────────────────────────────
          case 'fixtures':
            final completed = fx.where((f) => f.status == 'completed').toList();
            final upcoming  = fx.where((f) => f.status == 'scheduled').toList();
            return [
              introBox('This section presents the full fixture list for the MMU Soccer League 2026 season including scheduled matches, results, venues, and assigned referees.'),
              pw.Row(children: [
                statCard('Total Fixtures', '${fx.length}',              navy),
                statCard('Completed',      '${completed.length}',       green),
                statCard('Upcoming',       '${upcoming.length}',        blue2),
                statCard('Live',           '${widget.liveMatches.length}', red2),
              ]),
              sectionTitle('Completed Results'),
              dataTable(
                ['Home Team', 'Score', 'Away Team', 'Venue', 'Referee'],
                completed.map((f) => <String>[
                  f.homeTeam, '${f.homeScore}–${f.awayScore}',
                  f.awayTeam, f.venue, f.assignedReferee ?? '—',
                ]).toList(),
              ),
              sectionTitle('Upcoming Fixtures'),
              dataTable(
                ['Home Team', 'Away Team', 'Date', 'Venue'],
                upcoming.map((f) => <String>[
                  f.homeTeam, f.awayTeam,
                  '${f.dateTime.day}/${f.dateTime.month}/${f.dateTime.year}',
                  f.venue,
                ]).toList(),
              ),
              footer(),
            ];

          // ── FULL SEASON (default — must be last) ─────────────────────────
          case 'full':
          default:
            final totalMatches = rs.length + widget.liveMatches.length;
            return [
              introBox('This report provides an authoritative summary of the MMU University Sports Department soccer league activities. It covers all registered teams, player performances, match results, and administrative statistics for the 2026 season.'),
              pw.Row(children: [
                statCard('Total Matches', '$totalMatches', navy),
                statCard('Total Goals',   '$totalGoals',   green),
                statCard('Yellow Cards',  '$totalYellow',  yellow),
                statCard('Red Cards',     '$totalRed',     red2),
              ]),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                statCard('Teams',    '${widget.dynamicTeams.length}', purple2),
                statCard('Players',  '${fp.length}',                  blue2),
                statCard('Coaches',  '${fc.length}',                  teal2),
                statCard('Referees', '${fr.length}',                  brown2),
              ]),
              sectionTitle('League Standings'),
              dataTable(
                ['#', 'Team', 'P', 'W', 'D', 'L', 'GF', 'GA', 'GD', 'Pts'],
                st.asMap().entries.map((e) => <String>[
                  '${e.key + 1}', e.value.team, '${e.value.played}',
                  '${e.value.wins}', '${e.value.draws}', '${e.value.losses}',
                  '${e.value.goalsFor}', '${e.value.goalsAgainst}',
                  '${e.value.goalDifference}', '${e.value.points}',
                ]).toList(),
              ),
              pw.SizedBox(height: 12),
              barChart('Goals Per Team',
                st.map((s) => s.team).toList(),
                st.map((s) => s.goalsFor.toDouble()).toList(),
                green,
              ),
              barChart('Points Per Team',
                st.map((s) => s.team).toList(),
                st.map((s) => s.points.toDouble()).toList(),
                navy,
              ),
              footer(),
            ];
        }        // close switch
      },         // close build: callback
    ));          // close pw.MultiPage + doc.addPage

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (widget.reportType) {
      case 'players':  body = _buildPlayers(); break;
      case 'coaches':  body = _buildCoaches(); break;
      case 'referees': body = _buildReferees(); break;
      case 'teams':    body = _buildTeams(); break;
      case 'fixtures': body = _buildFixtures(); break;
      default:         body = _buildSeason();
    }
    return Column(children: [
      // ── Report type selector ──────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Report Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
            children: types.map((t) {
              final active = widget.reportType == t.$1;
              return GestureDetector(
                onTap: () => widget.onTypeChanged(t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8, bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF003087) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${t.$3} ${t.$2}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : Colors.grey.shade700)),
                ),
              );
            }).toList(),
          )),
          // ── Date Range Filter Bar ───────────────────────────────────────
          _dateFilterBar(),
          // ── PDF Action Bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _generatingPdf
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003087)))
                : Row(children: [
                    // Download / Print
                    Tooltip(
                      message: 'Download / Print PDF',
                      child: InkWell(
                        onTap: _generateAndDownloadPdf,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003087),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 15),
                            SizedBox(width: 6),
                            Text('Export PDF', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Share
                    Tooltip(
                      message: 'Share PDF',
                      child: InkWell(
                        onTap: _generateAndSharePdf,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A651),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.share_rounded, color: Colors.white, size: 15),
                            SizedBox(width: 6),
                            Text('Share', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
            ]),
          ),
        ]),
      ),
      // ── Report body ───────────────────────────────────────────────────────
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: body,
      )),
    ]);
  }
}
