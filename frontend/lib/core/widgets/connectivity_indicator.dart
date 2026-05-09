import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/offline_auth_provider.dart';

class ConnectivityIndicator extends StatelessWidget {
  final Widget child;
  
  const ConnectivityIndicator({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineAuthProvider>(
      builder: (context, authProvider, _) {
        return Stack(
          children: [
            child,
            StreamBuilder<bool>(
              stream: authProvider.connectivityStream,
              initialData: authProvider.isOnline,
              builder: (context, snapshot) {
                final isOnline = snapshot.data ?? true;
                
                if (isOnline) {
                  return const SizedBox.shrink();
                }
                
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.orange.shade600,
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Working offline - Changes will sync when connected',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineAuthProvider>(
      builder: (context, authProvider, _) {
        return StreamBuilder<bool>(
          stream: authProvider.connectivityStream,
          initialData: authProvider.isOnline,
          builder: (context, snapshot) {
            final isOnline = snapshot.data ?? true;
            
            return FutureBuilder<Map<String, int>>(
              future: authProvider.getSyncStatus(),
              builder: (context, syncSnapshot) {
                if (!syncSnapshot.hasData) {
                  return const SizedBox.shrink();
                }
                
                final syncStatus = syncSnapshot.data!;
                final totalPending = syncStatus.values.fold<int>(0, (sum, count) => sum + count);
                
                if (totalPending == 0) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: isOnline ? Colors.green : Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnline ? 'Synced' : 'Offline',
                        style: TextStyle(
                          color: isOnline ? Colors.green : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOnline ? Colors.blue : Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$totalPending pending',
                      style: TextStyle(
                        color: isOnline ? Colors.blue : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class SyncButton extends StatefulWidget {
  const SyncButton({super.key});

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineAuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isOnline) {
          return const SizedBox.shrink();
        }

        return IconButton(
          onPressed: _isSyncing ? null : () async {
            setState(() => _isSyncing = true);
            try {
              await authProvider.syncAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Data synced successfully'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.error_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Sync failed: $e')),
                      ],
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            } finally {
              if (mounted) {
                setState(() => _isSyncing = false);
              }
            }
          },
          icon: _isSyncing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                )
              : Icon(
                  Icons.sync_rounded,
                  color: Theme.of(context).primaryColor,
                ),
          tooltip: 'Sync data',
        );
      },
    );
  }
}