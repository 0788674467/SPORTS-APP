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
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rotating ball
                  RotationTransition(
                    turns: _rotation,
                    child: const Icon(Icons.sports_soccer, size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Hi, $name! 👋',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your ${role[0].toUpperCase()}${role.substring(1)} account is awaiting approval',
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.pending_actions_rounded, color: Colors.amber, size: 40),
                        const SizedBox(height: 16),
                        const Text(
                          'Pending Admin Review',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'The MMU Soccer admin will review and approve your account. This usually takes 1–24 hours.',
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(icon: Icons.email_outlined, text: authProvider.user?.email ?? ''),
                        const SizedBox(height: 6),
                        _InfoRow(icon: Icons.badge_outlined, text: '${role[0].toUpperCase()}${role.substring(1)} Registration'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
