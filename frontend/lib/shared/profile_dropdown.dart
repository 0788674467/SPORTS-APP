import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/auth_provider.dart' as auth;

/// Profile photo top-right widget with dropdown for Sign Out, Profile, Help.
/// 
/// Reads live name + avatar_url from [auth.AuthProvider] directly so it always
/// reflects the latest profile state — no stale captures.
class ProfileDropdown extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onSignOut;
  final VoidCallback onProfile;
  final VoidCallback? onHelp;

  // These stay for call-site compatibility but are now used only as initial fallbacks
  final String name;
  final String? avatarUrl;
  final int avatarIndex;

  const ProfileDropdown({
    super.key,
    required this.name,
    this.avatarUrl,
    this.avatarIndex = 0,
    required this.accentColor,
    required this.onSignOut,
    required this.onProfile,
    this.onHelp,
  });

  @override
  State<ProfileDropdown> createState() => _ProfileDropdownState();
}

class _ProfileDropdownState extends State<ProfileDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _entry;
  late AnimationController _animCtrl;
  late Animation<double> _fadeScale;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _fadeScale = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _removeOverlay();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── live resolved name / avatarUrl from provider ─────────────────────────
  String _liveName(BuildContext ctx) {
    try {
      final ap = ctx.read<auth.AuthProvider>();
      final p = ap.profile;
      return p?['full_name'] as String? ??
          ap.user?.userMetadata?['full_name'] as String? ??
          widget.name;
    } catch (_) {
      return widget.name;
    }
  }

  String? _liveAvatarUrl(BuildContext ctx) {
    try {
      final ap = ctx.read<auth.AuthProvider>();
      final p = ap.profile;
      final fromProfile = p?['avatar_url'] as String?;
      if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
      return ap.user?.userMetadata?['avatar_url'] as String? ?? widget.avatarUrl;
    } catch (_) {
      return widget.avatarUrl;
    }
  }

  // ── overlay ───────────────────────────────────────────────────────────────
  void _toggleOverlay() =>
      _entry != null ? _removeOverlay() : _showOverlay();

  void _showOverlay() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(builder: (ctx) {
      // Re-read provider on every overlay rebuild
      final name = _liveName(context);
      final avatarUrl = _liveAvatarUrl(context);
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(children: [
          CompositedTransformFollower(
            link: _layerLink,
            offset: const Offset(-160, 44),
            child: FadeTransition(
              opacity: _fadeScale,
              child: ScaleTransition(
                scale: _fadeScale,
                alignment: Alignment.topRight,
                child: _buildDropdownCard(ctx, name, avatarUrl),
              ),
            ),
          ),
        ]),
      );
    });
    overlay.insert(_entry!);
    _animCtrl.forward(from: 0);
    setState(() {});
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
    _animCtrl.reverse();
    if (mounted) setState(() {});
  }

  Widget _buildDropdownCard(
      BuildContext ctx, String name, String? avatarUrl) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 210,
        decoration: BoxDecoration(
          color: const Color(0xFF141428),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 8)),
            BoxShadow(
                color: widget.accentColor.withOpacity(0.15),
                blurRadius: 15),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              _avatarWidget(avatarUrl, name, 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  Text('Signed in',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10)),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1, color: Colors.white10),
          _item(Icons.person_rounded, 'Profile',
              () { _removeOverlay(); widget.onProfile(); }),
          const Divider(height: 1, color: Colors.white10),
          _item(Icons.help_outline_rounded, 'Help',
              () { _removeOverlay(); widget.onHelp?.call(); }),
          const Divider(height: 1, color: Colors.white10),
          _item(Icons.logout_rounded, 'Sign Out',
              () { _removeOverlay(); widget.onSignOut(); },
              color: Colors.red.shade400),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }

  Widget _item(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? Colors.white;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(icon, size: 16, color: c.withOpacity(0.8)),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: c, fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  /// Shared avatar builder: photo → initials.  Never uses emojis.
  Widget _avatarWidget(String? url, String name, double radius) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: widget.accentColor,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: widget.accentColor.withOpacity(0.25),
      child: Text(initial,
          style: TextStyle(
              fontSize: radius * 0.75,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider so the button avatar rebuilds when profile changes
    final ap = context.watch<auth.AuthProvider>();
    final p = ap.profile;
    final liveUrl = (p?['avatar_url'] as String?)?.isNotEmpty == true
        ? p!['avatar_url'] as String
        : ap.user?.userMetadata?['avatar_url'] as String?;
    final liveName = p?['full_name'] as String? ??
        ap.user?.userMetadata?['full_name'] as String? ??
        widget.name;

    // Rebuild the overlay entry after the current build completes
    if (_entry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_entry != null && mounted) {
          _entry!.markNeedsBuild();
        }
      });
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleOverlay,
        child: Stack(children: [
          _avatarWidget(liveUrl, liveName, 20),
          if (_entry != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black38, width: 1),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
