import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/auth_provider.dart' as auth;

// ─── Responsive Breakpoints ───────────────────────────────────────────────────

class ResponsiveWrapper extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  const ResponsiveWrapper({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 840;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1100) return desktop;
    if (w >= 840) return tablet;
    return mobile;
  }
}

// ─── Sidebar Nav Item Definition ─────────────────────────────────────────────

class SidebarItem {
  final String id;
  final IconData icon;
  final String label;
  final int? badge;
  final bool isLogout;
  const SidebarItem(this.id, this.icon, this.label, {this.badge, this.isLogout = false});
}

// ─── Sidebar ─────────────────────────────────────────────────────────────────

class DashboardSidebar extends StatelessWidget {
  final String activeId;
  final ValueChanged<String> onNav;
  final int pendingCount;

  const DashboardSidebar({
    super.key,
    required this.activeId,
    required this.onNav,
    this.pendingCount = 0,
  });

  static final _sections = [
    {
      'title': 'MAIN',
      'items': [
        SidebarItem('dashboard', Icons.dashboard_rounded, 'Dashboard'),
        SidebarItem('approvals', Icons.pending_actions_rounded, 'Approvals'),
        SidebarItem('communications', Icons.forum_rounded, 'Communications'),
        SidebarItem('notifications', Icons.notifications_none_rounded, 'Notifications'),
      ],
    },
    {
      'title': 'COMPETITIONS',
      'items': [
        SidebarItem('fixtures', Icons.calendar_today_rounded, 'Fixtures'),
        SidebarItem('venues', Icons.stadium_rounded, 'Venues'),
        SidebarItem('leagues', Icons.emoji_events_rounded, 'Leagues'),
        SidebarItem('standings', Icons.format_list_numbered_rounded, 'Standings'),
        SidebarItem('results', Icons.sports_score_rounded, 'Match Results'),
      ],
    },
    {
      'title': 'MANAGEMENT',
      'items': [
        SidebarItem('squad_approvals', Icons.fact_check_rounded, 'Squad Approvals'),
        SidebarItem('teams', Icons.shield_rounded, 'Teams'),
        SidebarItem('players', Icons.group_rounded, 'Players'),
        SidebarItem('coaches', Icons.sports_rounded, 'Coaches'),
        SidebarItem('referees', Icons.sports_handball_rounded, 'Referees'),
      ],
    },
    {
      'title': 'REPORTS & ANALYTICS',
      'items': [
        SidebarItem('player_stats', Icons.bar_chart_rounded, 'Player Stats'),
        SidebarItem('season_report', Icons.analytics_rounded, 'Season Reports'),
        SidebarItem('live_scores', Icons.live_tv_rounded, 'Live Scores'),
      ],
    },
    {
      'title': 'SYSTEM',
      'items': [
        SidebarItem('profile', Icons.account_circle_rounded, 'My Profile'),
        SidebarItem('settings', Icons.settings_rounded, 'Settings'),
        SidebarItem('logout', Icons.logout_rounded, 'Sign Out', isLogout: true),
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 0,
      child: Container(
        color: const Color(0xFF0A1628),
        child: SafeArea(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
               Container(width: 40, height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Image.asset('assets/images/mmulogo.png', fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UniLeague', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                    Text('ADMIN PANEL', style: TextStyle(color: Color(0xFF00A651), fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700)),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 20),
            // Profile tile
            _buildProfileTile(context),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: _sections.map((section) {
                    final items = section['items'] as List<SidebarItem>;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(section['title'] as String, style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 4),
                        ...items.map((item) => _NavItem(
                          item: item,
                          isActive: activeId == item.id,
                          badge: item.id == 'approvals' ? pendingCount : (item.badge ?? 0),
                          onTap: () {
                            if (item.isLogout) {
                              _confirmLogout(context);
                              return;
                            }
                            onNav(item.id);
                            if (MediaQuery.of(context).size.width < 840) Navigator.pop(context);
                          },
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildProfileTile(BuildContext context) {
    final ap = context.watch<auth.AuthProvider>();
    final p = ap.profile;
    final name = p?['full_name'] as String? ??
        ap.user?.userMetadata?['full_name'] as String? ?? 'Admin';
    final avatarUrl = (p?['avatar_url'] as String?)?.isNotEmpty == true
        ? p!['avatar_url'] as String
        : ap.user?.userMetadata?['avatar_url'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF003087),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            onBackgroundImageError: avatarUrl != null ? (_, __) {} : null,
            child: avatarUrl == null
                ? Text(name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            const Text('Super Admin', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ])),
          GestureDetector(
            onTap: () => _confirmLogout(context),
            child: const Icon(Icons.logout_rounded, color: Colors.white24, size: 16),
          ),
        ]),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Sign Out'),
      content: const Text('Are you sure you want to sign out of the admin panel?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { Navigator.pop(context); context.read<auth.AuthProvider>().signOut(); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Sign Out'),
        ),
      ],
    ));
  }
}

class _NavItem extends StatelessWidget {
  final SidebarItem item;
  final bool isActive;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({required this.item, required this.isActive, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = item.isLogout ? Colors.red.shade300 : (isActive ? const Color(0xFF42A5F5) : Colors.white38);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF003087).withOpacity(0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: const Color(0xFF003087).withOpacity(0.35)) : null,
        ),
        child: Row(children: [
          Icon(item.icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(item.label, style: TextStyle(color: item.isLogout ? Colors.red.shade300 : (isActive ? Colors.white : Colors.white54), fontWeight: isActive ? FontWeight.w600 : FontWeight.normal, fontSize: 13))),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.orange.shade600, borderRadius: BorderRadius.circular(8)),
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          if (isActive && badge == 0 && !item.isLogout)
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF42A5F5), shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class DashboardHeader extends StatelessWidget {
  final bool isMobile;
  final String title;
  const DashboardHeader({super.key, required this.isMobile, this.title = 'Dashboard'});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        if (isMobile)
          Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(ctx).openDrawer(), padding: EdgeInsets.zero)),
        if (!isMobile)
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
        const Spacer(),
        SizedBox(
          width: isMobile ? 140 : 240,
          child: TextField(
            style: const TextStyle(color: Color(0xFF0D1B2A), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search...', hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade400),
              filled: true, fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF003087))),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Stack(children: [
          IconButton(icon: const Icon(Icons.notifications_none_rounded, size: 22), onPressed: () {}),
          Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF00A651), shape: BoxShape.circle))),
        ]),
        const SizedBox(width: 4),
        Consumer<auth.AuthProvider>(builder: (ctx, ap, _) {
          final p = ap.profile;
          final name = p?['full_name'] as String? ??
              ap.user?.userMetadata?['full_name'] as String? ?? 'A';
          final avatarUrl = (p?['avatar_url'] as String?)?.isNotEmpty == true
              ? p!['avatar_url'] as String
              : ap.user?.userMetadata?['avatar_url'] as String?;
          return CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFF003087),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            onBackgroundImageError: avatarUrl != null ? (_, __) {} : null,
            child: avatarUrl == null
                ? Text(name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))
                : null,
          );
        }),
        const SizedBox(width: 4),
      ]),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final String percent;
  final IconData icon;
  final Gradient gradient;
  final double? progress;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.percent,
    required this.icon,
    required this.gradient,
    this.progress,
    this.onTap,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isUp    = widget.percent.startsWith('+');
    final bool isZero  = widget.percent == '0';
    final Color accent = (widget.gradient as LinearGradient).colors.first;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -5.0 : 0.0, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered ? accent.withOpacity(0.35) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(color: accent.withOpacity(0.20), blurRadius: 28, offset: const Offset(0, 12)),
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4)),
                  ]
                : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row ──────────────────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: widget.gradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _hovered
                        ? [BoxShadow(color: accent.withOpacity(0.45), blurRadius: 12, offset: const Offset(0, 5))]
                        : [],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 18),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isZero
                          ? Colors.grey.shade100
                          : isUp ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        isZero ? Icons.remove_rounded
                            : isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 12,
                        color: isZero ? Colors.grey
                            : isUp ? Colors.green.shade600 : Colors.red.shade600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isZero ? 'No change' : widget.percent,
                        style: TextStyle(
                          color: isZero ? Colors.grey
                              : isUp ? Colors.green.shade700 : Colors.red.shade700,
                          fontSize: 11, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ]),
                  ),
                  if (widget.onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 16,
                        color: _hovered ? accent : Colors.grey.shade300),
                  ],
                ]),
              ]),
              const SizedBox(height: 14),
              // ── Value ────────────────────────────────────────────────────
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(widget.value,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              ),
              const SizedBox(height: 2),
              Text(widget.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(widget.subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              // ── Progress bar ─────────────────────────────────────────────
              if (widget.progress != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.progress!.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: accent.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${(widget.progress! * 100).round()}% capacity',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  if (widget.onTap != null)
                    Text('Tap to view →',
                        style: TextStyle(
                          fontSize: 10,
                          color: _hovered ? accent : Colors.grey.shade400,
                          fontWeight: _hovered ? FontWeight.bold : FontWeight.w600,
                        )),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

