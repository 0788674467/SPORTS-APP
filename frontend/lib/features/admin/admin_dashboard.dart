import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './widgets/dashboard_components.dart';
import './fixture_generator.dart';
import '../../core/state/match_state.dart';
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
  
  // Real-time match data
  List<Map<String, dynamic>> _liveMatches = [];
  List<Map<String, dynamic>> _recentResults = [];
  StreamSubscription<List<Map<String, dynamic>>>? _matchesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _fixturesSubscription;
  
  // ─── Search Controllers ────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // ─── Loading States ─────────────────────────────────────────────────────────
  bool _isLoadingPending = false;
  bool _isLoadingManagement = false;
  bool _isLoadingSquads = false;
  bool _isLoadingVenues = false;
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
      'player_stats': 'Player Statistics', 'season_report': 'Season Reports', 'live_scores': 'Live Scores',
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
    return ['teams', 'players', 'coaches', 'referees', 'venues', 'approvals', 'notifications'].contains(_activeSection);
  }

  String _getSearchHint() {
    switch (_activeSection) {
      case 'teams': return 'Search teams...';
      case 'players': return 'Search players...';
      case 'coaches': return 'Search coaches...';
      case 'referees': return 'Search referees...';
      case 'venues': return 'Search venues...';
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildWelcomeBanner(),
        const SizedBox(height: 24),
        _buildStatsGrid(),
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
            _pill('⚽ 3 Live Matches'),
            _pill('🏆 2 Leagues Active'),
            _pill('👤 ${_pending.length} Pending Approvals'),
          ]),
        ])),
        const SizedBox(width: 16),
        const Icon(Icons.sports_soccer, size: 64, color: Colors.white24),
      ]),
    );
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
  );

  Widget _buildStatsGrid() {
    final teamCount = _dynamicTeams.isEmpty ? _teams.length : _dynamicTeams.length;
    final coachCount = _dynamicCoaches.isEmpty ? _coaches.length : _dynamicCoaches.length;
    final refereeCount = _dynamicReferees.isEmpty ? _referees.length : _dynamicReferees.length;
    final playerCount = _dynamicPlayers.isNotEmpty ? _dynamicPlayers.length : (_players.length * 11);

    final cards = [
      _statCardData('Total Teams', '$teamCount', 'Registered this season', teamCount > 0 ? '+$teamCount' : '0', Icons.shield_rounded,
        const LinearGradient(colors: [Color(0xFF003087), Color(0xFF1A4FA0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        [1.0, 2, 3, 4, 6, 7, 8]),
      _statCardData('Live Matches', '${_liveMatches.length}', 'Currently in progress', _liveMatches.isNotEmpty ? '+${_liveMatches.length}' : '0', Icons.sports_soccer_rounded,
        const LinearGradient(colors: [Color(0xFF006B35), Color(0xFF00A651)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        [0.0, 1, 1, 2, 2, _liveMatches.length.toDouble(), _liveMatches.length.toDouble()]),
      _statCardData('Registered Players', '$playerCount', '${_dynamicPlayers.isNotEmpty ? "Live from database" : "No players yet"}', playerCount > 0 ? '+$playerCount' : '0', Icons.group_rounded,
        const LinearGradient(colors: [Color(0xFFC47A00), Color(0xFFF5A500)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        [1.0, 2, 4, 5, 6, 7, 8]),
      _statCardData('Pending Squads', '${_submittedSquads.length}', 'Awaiting your review', _submittedSquads.isNotEmpty ? '+${_submittedSquads.length}' : '0', Icons.fact_check_rounded,
        const LinearGradient(colors: [Color(0xFF001A4D), Color(0xFF003087)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        [0.0, 0, 1, 1, 1, _submittedSquads.length.toDouble(), _submittedSquads.length.toDouble()]),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 280, childAspectRatio: 1.15, crossAxisSpacing: 18, mainAxisSpacing: 18),
      itemCount: cards.length,
      itemBuilder: (_, i) => cards[i],
    );
  }

  StatCard _statCardData(String title, String value, String subtitle, String pct, IconData icon, Gradient grad, List<double> ys) {
    return StatCard(
      title: title, value: value, subtitle: subtitle, percent: pct, icon: icon, gradient: grad,
      spots: ys.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
    );
  }

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
    return _card(title: 'Team Registrations', subtitle: 'By league & division', child: SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
            const labels = ['Lions', 'Sharks', 'Eagles', 'Wolves', 'Foxes', 'Panthers', 'Stars', 'Knights'];
            final i = v.toInt();
            if (i < 0 || i >= labels.length) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 4), child: Text(labels[i], style: const TextStyle(fontSize: 8)));
          }, reservedSize: 22)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.grey)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _teams.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
            toY: (e.value.wins + e.value.draws + e.value.losses).toDouble(),
            gradient: const LinearGradient(colors: [Color(0xFF001A4D), Color(0xFF003087)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ])).toList(),
      )),
    ));
  }

  Widget _buildResultsChart() {
    return _card(
      title: 'Recent Match Scores', 
      subtitle: _recentResults.isEmpty ? 'No match data' : 'Goals scored per result', 
      child: _recentResults.isEmpty 
        ? const SizedBox(
            height: 200,
            child: Center(child: Text('No match data available', style: TextStyle(color: Colors.grey, fontSize: 14))),
          )
        : SizedBox(
            height: 200,
            child: BarChart(BarChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                  final labels = _recentResults.map((r) => (r['home_team'] as String).split(' ').first).toList();
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 4), child: Text(labels[i], style: const TextStyle(fontSize: 8)));
                }, reservedSize: 22)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.grey)))),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _recentResults.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(
                  toY: (e.value['home_score'] as int? ?? 0).toDouble(),
                  gradient: const LinearGradient(colors: [Color(0xFF001A4D), Color(0xFF003087)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(5))),
                BarChartRodData(
                  toY: (e.value['away_score'] as int? ?? 0).toDouble(),
                  gradient: const LinearGradient(colors: [Color(0xFFC47A00), Color(0xFFF5A500)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(5))),
              ])).toList(),
            )),
          )
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
      _actionLink(Icons.analytics_rounded, 'Season Report', Colors.purple, 'season_report'),
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
    return RefreshIndicator(
      onRefresh: _fetchPending,
      color: const Color(0xFF00A651),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _pendingHeader(),
          const SizedBox(height: 16),
          if (_pending.isEmpty)
            _emptyState(Icons.check_circle_outline_rounded, 'All caught up!', 'No pending approvals.')
          else
            ..._pending.asMap().entries.map((entry) => _approvalCard(entry.key, entry.value)),
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
    // We'll eventually pull this from a dedicated 'standings' table, 
    // but for now we use the dynamic teams list.
    final teamsToRank = _dynamicTeams.isEmpty ? [] : _dynamicTeams;
    final sorted = List<Map<String, dynamic>>.from(teamsToRank)
      ..sort((a, b) => (b['points'] ?? 0).compareTo(a['points'] ?? 0));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(title: '🏆 League Standings', subtitle: 'MMU Soccer League — Season 2026', child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: const Color(0xFF003087),
          child: Row(children: [
            const SizedBox(width: 28),
            const Expanded(child: Text('Club', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
            ...['P', 'W', 'D', 'L', 'Pts'].map((h) => SizedBox(width: 32, child: Text(h, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))),
          ]),
        ),
        ...sorted.asMap().entries.map((e) {
          final t = e.value;
          final pos = e.key + 1;
          final isTop4 = pos <= 4;
          final isRelegation = pos > sorted.length - 2;
          final name = t['name'] ?? 'Unknown';
          final wins = t['wins'] ?? 0;
          final draws = t['draws'] ?? 0;
          final losses = t['losses'] ?? 0;
          final points = t['points'] ?? 0;
          final played = wins + draws + losses;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: e.key % 2 == 0 ? Colors.grey.shade50 : Colors.white,
              border: Border(left: BorderSide(
                color: isTop4 ? const Color(0xFF003087) : (isRelegation ? Colors.red.shade400 : Colors.transparent),
                width: 3,
              )),
            ),
            child: Row(children: [
              SizedBox(width: 28, child: Text('$pos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isTop4 ? const Color(0xFF003087) : Colors.black87))),
              Expanded(child: Row(children: [
                CircleAvatar(radius: 12, backgroundColor: const Color(0xFF003087).withOpacity(0.15), child: Text(name[0], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF003087)))),
                const SizedBox(width: 8),
                Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ])),
              ...[played, wins, draws, losses, points].map((v) =>
                SizedBox(width: 32, child: Text('$v', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: v == points ? FontWeight.bold : FontWeight.normal, color: v == points ? const Color(0xFF00A651) : Colors.black87)))),
            ]),
          );
        }),
        const SizedBox(height: 12),
        Row(children: [
          _legendDot(const Color(0xFF003087)), const SizedBox(width: 6), const Text('UEFA / Promotion Zone', style: TextStyle(fontSize: 11)), const SizedBox(width: 16),
          _legendDot(Colors.red.shade400), const SizedBox(width: 6), const Text('Relegation Zone', style: TextStyle(fontSize: 11)),
        ]),
      ])),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(title: 'Registered Teams', subtitle: '${_dynamicTeams.length} teams in the system', child: Column(children: [
        _tableHeader(['Team', 'Coach', 'Status']),
        if (_dynamicTeams.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No teams found.'))
        else ..._dynamicTeams.map((t) => _tableRow([
          t['name'] ?? 'Unknown',
          t['profiles']?['full_name'] ?? 'No Coach',
          t['is_active'] == true ? 'Active' : 'Inactive'
        ], t['is_active'] == true ? Colors.green.shade600 : Colors.red.shade600)),
      ])),
    );
  }

  // ─── Players ────────────────────────────────────────────────────────────────
  Widget _buildPlayers() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));
    final players = _dynamicPlayers.isEmpty ? [] : _dynamicPlayers;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(
        title: 'Registered Players', 
        subtitle: 'All players across all teams - Click to view details', 
        child: Column(children: [
          // Fixed table header with consistent layout
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const SizedBox(width: 40), // Photo space
              const Expanded(flex: 3, child: Text('Player', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
              const Expanded(flex: 2, child: Text('Team', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
              const SizedBox(width: 60, child: Text('Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.center)),
              const SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.center)),
              const SizedBox(width: 80, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.center)),
            ]),
          ),
          const SizedBox(height: 8),
          if (players.isEmpty) 
            const Padding(padding: EdgeInsets.all(24), child: Text('No players found.'))
          else 
            ...players.map((p) => _buildPlayerRow(p)),
        ])
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(
        title: 'Registered Coaches',
        subtitle: '${_dynamicCoaches.length} coach accounts',
        child: Column(children: [
          _complexTableHeader(['Photo', 'Name', 'Email', 'Team', 'Actions']),
          const SizedBox(height: 8),
          if (_dynamicCoaches.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('No approved coaches.'))
          else
            ..._dynamicCoaches.map((c) => _coachRow(c)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _card(
        title: 'League Referees',
        subtitle: '${_dynamicReferees.length} registered referees',
        child: Column(children: [
          _complexTableHeader(['Photo', 'Name', 'Email', 'Phone', 'Actions']),
          const SizedBox(height: 8),
          if (_dynamicReferees.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('No approved referees.'))
          else
            ..._dynamicReferees.map((r) => _refereeRow(r)),
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
    final sorted = List<_Player>.from(_players)..sort((a, b) => b.goals.compareTo(a.goals));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        _card(title: '🥇 Top Scorers', subtitle: 'Goals this season', child: SizedBox(
          height: 220,
          child: BarChart(BarChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= sorted.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(sorted[i].name.split(' ').first, style: const TextStyle(fontSize: 9)));
              }, reservedSize: 22)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.grey)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: sorted.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(toY: e.value.goals.toDouble(), gradient: const LinearGradient(colors: [Color(0xFF00A651), Color(0xFF00A651)], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(5))),
            ])).toList(),
          )),
        )),
        const SizedBox(height: 18),
        _card(title: 'Player Performance Table', subtitle: 'Goals + Assists', child: Column(children: [
          _tableHeader(['Player', 'Team', 'Goals', 'Assists', 'Total']),
          ...sorted.map((p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              Expanded(child: Text(p.team, style: const TextStyle(fontSize: 12, color: Colors.grey))),
              SizedBox(width: 52, child: Text('${p.goals}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A651)))),
              SizedBox(width: 52, child: Text('${p.assists}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003087)))),
              SizedBox(width: 52, child: Text('${p.goals + p.assists}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
            ]),
          )),
        ])),
      ]),
    );
  }

  // ─── Season Report ────────────────────────────────────────────────────────────
  Widget _buildSeasonReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Row(children: [
          Expanded(child: _smallStatCard('Total Matches', '24', Icons.sports_soccer_rounded, const Color(0xFF003087))),
          const SizedBox(width: 12),
          Expanded(child: _smallStatCard('Total Goals', '67', Icons.emoji_events_rounded, const Color(0xFF00A651))),
          const SizedBox(width: 12),
          Expanded(child: _smallStatCard('Yellow Cards', '31', Icons.rectangle_rounded, const Color(0xFFF9A825))),
          const SizedBox(width: 12),
          Expanded(child: _smallStatCard('Red Cards', '4', Icons.rectangle_rounded, const Color(0xFFC62828))),
        ]),
        const SizedBox(height: 18),
        _card(title: 'Goals Per Team', subtitle: 'Cumulative goals scored season 2026', child: SizedBox(
          height: 240,
          child: BarChart(BarChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= _teams.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(_teams[i].name.split(' ').first, style: const TextStyle(fontSize: 8)));
              }, reservedSize: 22)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.grey)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: _teams.asMap().entries.map((e) {
              final goals = e.value.wins * 2 + e.value.draws; // demo calculation
              return BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(toY: goals.toDouble(), gradient: LinearGradient(
                  colors: [const Color(0xFF003087).withOpacity(0.7), const Color(0xFF1A4FA0)],
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                ), width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(5))),
              ]);
            }).toList(),
          )),
        )),
        const SizedBox(height: 18),
        _card(title: 'Season Summary Report', subtitle: 'Administrative summary', child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reportRow('Season', 'MMU Soccer League 2026'),
            _reportRow('Total Teams', '${_teams.length}'),
            _reportRow('Active Teams', '${_teams.where((t) => t.status == 'Active').length}'),
            _reportRow('Total Players', '${_players.length * 11}'),
            _reportRow('Matches Played', '24'),
            _reportRow('Upcoming Fixtures', '${_fixtures.length}'),
            _reportRow('Registered Coaches', '${_coaches.length}'),
            _reportRow('Registered Referees', '${_referees.length}'),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export PDF Report'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003087), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
            )),
          ],
        )),
      ]),
    );
  }

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
        _card(title: 'System Settings', subtitle: 'Platform configuration', child: Column(children: [
          _settingRow('Email Notifications', true),
          const Divider(height: 1),
          _settingRow('Auto-approve Spectators', true),
          const Divider(height: 1),
          _settingRow('Maintenance Mode', false),
          const Divider(height: 1),
          _settingRow('Allow New Registrations', true),
        ])),
        const SizedBox(height: 16),
        _card(title: 'Season Management', subtitle: 'Current season: 2026', child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileField('Season Name', 'MMU Soccer League 2026'),
            _profileField('Start Date', '01 Jan 2026'),
            _profileField('End Date', '30 Jun 2026'),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003087), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Update Season'),
            )),
          ],
        )),
      ]),
    );
  }

  Widget _settingRow(String label, bool initial) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Switch(value: initial, onChanged: (v) => setState(() {}), activeColor: const Color(0xFF003087)),
      ]),
    );
  }

  // ─── Shared helpers ──────────────────────────────────────────────────────────
  Widget _card({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
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
