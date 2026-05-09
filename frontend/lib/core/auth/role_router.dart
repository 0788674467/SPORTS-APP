import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import '../../features/admin/admin_dashboard.dart';
import '../../features/spectator/spectator_home.dart';
import '../../features/coach/coach_dashboard.dart';
import '../../features/referee/referee_dashboard.dart';
import '../../features/auth/pending_approval_screen.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  bool _welcomeShown = false;

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();

    if (authProv.isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A2E0A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_soccer, size: 64, color: Colors.white),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text('Loading MMU Soccer...', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            ],
          ),
        ),
      );
    }

    if (authProv.user == null) return const SpectatorHome();

    // Show welcome banner if just approved
    if (authProv.justApproved && !_welcomeShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _welcomeShown = true;
        authProv.clearJustApproved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            backgroundColor: const Color(0xFF1B5E20),
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Account Approved! ⚽', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Thanks for using the MMU Soccer League Management System.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ]),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      });
    }

    switch (authProv.role) {
      case 'admin':
        return const AdminDashboard();
      case 'coach':
        if (authProv.approvalStatus == 'pending') return const PendingApprovalScreen();
        return const CoachDashboard();
      case 'referee':
        if (authProv.approvalStatus == 'pending') return const PendingApprovalScreen();
        return const RefereeDashboard();
      case 'spectator':
      default:
        return const SpectatorHome();
    }
  }
}
