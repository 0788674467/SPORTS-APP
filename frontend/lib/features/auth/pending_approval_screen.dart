import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart' as auth;

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _rotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<auth.AuthProvider>();
    final role = authProvider.role ?? 'user';
    final name = authProvider.user?.userMetadata?['full_name'] ?? 'there';

    final size = MediaQuery.of(context).size;
    final ss = size.shortestSide;
    final iconSize = (ss * 0.18).clamp(48.0, 80.0);
    final titleFs = (ss * 0.055).clamp(18.0, 26.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2E0A), Color(0xFF1B5E20)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all((ss * 0.07).clamp(16.0, 32.0)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rotating ball
                  RotationTransition(
                    turns: _rotation,
                    child: Icon(Icons.sports_soccer, size: iconSize, color: Colors.white),
                  ),
                  SizedBox(height: (ss * 0.06).clamp(16.0, 32.0)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Hi, $name! 👋',
                      style: TextStyle(color: Colors.white, fontSize: titleFs, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your ${role[0].toUpperCase()}${role.substring(1)} account is awaiting approval',
                    style: TextStyle(color: Colors.white70, fontSize: (ss * 0.035).clamp(12.0, 16.0)),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: (ss * 0.06).clamp(16.0, 32.0)),
                  Container(
                    padding: EdgeInsets.all((ss * 0.05).clamp(14.0, 24.0)),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.pending_actions_rounded, color: Colors.amber, size: (ss * 0.09).clamp(28.0, 44.0)),
                        const SizedBox(height: 16),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Pending Admin Review',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: (ss * 0.04).clamp(13.0, 18.0)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'The MMU Soccer admin will review and approve your account. This usually takes 1–24 hours.',
                          style: TextStyle(color: Colors.white70, fontSize: (ss * 0.032).clamp(11.0, 14.0), height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(icon: Icons.email_outlined, text: authProvider.user?.email ?? ''),
                        const SizedBox(height: 6),
                        _InfoRow(icon: Icons.badge_outlined, text: '${role[0].toUpperCase()}${role.substring(1)} Registration'),
                      ],
                    ),
                  ),
                  SizedBox(height: (ss * 0.08).clamp(20.0, 40.0)),
                  SizedBox(
                    width: double.infinity,
                    height: (size.height * 0.06).clamp(44.0, 52.0),
                    child: OutlinedButton.icon(
                      onPressed: () => authProvider.signOut(),
                      icon: const Icon(Icons.logout_rounded, color: Colors.white),
                      label: const Text('Sign Out', style: TextStyle(color: Colors.white, fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}
