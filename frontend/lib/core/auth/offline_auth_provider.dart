import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../offline/offline_data_service.dart';
import 'auth_provider.dart';

/// Offline-aware authentication provider that extends the base AuthProvider
/// with local data caching and offline functionality.
class OfflineAuthProvider extends AuthProvider {
  final OfflineDataService _offlineService = OfflineDataService();
  bool _isInitialized = false;

  OfflineAuthProvider() {
    _initOfflineAuth();
  }

  Future<void> _initOfflineAuth() async {
    // Initialize offline service first
    if (!_isInitialized) {
      await _offlineService.initialize();
      _isInitialized = true;
    }
    
    // Listen to connectivity changes
    _offlineService.connectivityStream.listen((isOnline) {
      if (isOnline) {
        // When back online, sync all data
        _syncAllData();
      }
      notifyListeners();
    });

    // Listen to data updates
    _offlineService.dataUpdateStream.listen((update) {
      // Notify listeners when data changes
      notifyListeners();
    });
  }

  bool get isOnline => _offlineService.isOnline;

  Future<void> _syncAllData() async {
    try {
      await _offlineService.syncAll();
    } catch (e) {
      debugPrint('Error syncing data: $e');
    }
  }

  // Override methods to use offline service

  /// Get pending users with offline support
  Future<List<Map<String, dynamic>>> getPendingUsers({bool forceRefresh = false}) async {
    return await _offlineService.getPendingUsers(forceRefresh: forceRefresh);
  }

  /// Get approved users by role with offline support
  @override
  Future<List<Map<String, dynamic>>> getApprovedUsers(String role) async {
    // Always hit Supabase directly so avatar_url is always fresh
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', role)
          .eq('approval_status', 'approved');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('OfflineAuthProvider: getApprovedUsers fallback for $role: $e');
      // Fallback to offline cache with correct field name
      try {
        final allUsers = await _offlineService.getPendingUsers();
        return allUsers.where((user) =>
          user['role']?.toString().toLowerCase() == role.toLowerCase() &&
          user['approval_status'] == 'approved'
        ).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Approve user with offline support
  Future<String?> approveUser(String userId) async {
    try {
      await _offlineService.approveUser(userId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Get teams with offline support
  Future<List<Map<String, dynamic>>> getTeams({bool forceRefresh = false}) async {
    return await _offlineService.getTeams(forceRefresh: forceRefresh);
  }

  /// Create team with offline support
  Future<String?> createTeam(Map<String, dynamic> teamData) async {
    try {
      await _offlineService.createTeam(teamData);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Update team with offline support
  Future<String?> updateTeam(String teamId, {String? name, String? logoUrl}) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (logoUrl != null) updates['logo_url'] = logoUrl;
      
      await _offlineService.updateTeam(teamId, updates);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Get players with offline support
  Future<List<Map<String, dynamic>>> getPlayers({bool forceRefresh = false}) async {
    return await _offlineService.getPlayers(forceRefresh: forceRefresh);
  }

  /// Create player with offline support
  Future<String?> createPlayer(Map<String, dynamic> playerData) async {
    try {
      await _offlineService.createPlayer(playerData);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Update player with offline support
  Future<String?> updatePlayer(String id, Map<String, dynamic> updates) async {
    try {
      await _offlineService.updatePlayer(id, updates);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Approve player with offline support
  Future<String?> approvePlayer(String playerId) async {
    try {
      await _offlineService.approvePlayer(playerId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Get submitted squads with offline support
  Future<List<Map<String, dynamic>>> getSubmittedSquads({bool forceRefresh = false}) async {
    // For now, return teams with their players
    final teams = await getTeams(forceRefresh: forceRefresh);
    final players = await getPlayers(forceRefresh: forceRefresh);
    
    // Group players by team
    final squads = <Map<String, dynamic>>[];
    for (final team in teams) {
      final teamPlayers = players.where((p) => p['team_id'] == team['id']).toList();
      if (teamPlayers.isNotEmpty) {
        squads.add({
          ...team,
          'players': teamPlayers,
          'submitted_at': team['created_at'],
        });
      }
    }
    
    return squads;
  }

  /// Review squad with offline support
  Future<String?> reviewSquad(String teamId, {required bool approve, String? note}) async {
    try {
      final status = approve ? 'approved' : 'rejected';
      final updates = {
        'status': status,
        'reviewed_at': DateTime.now().toIso8601String(),
      };
      if (note != null) updates['review_note'] = note;
      
      await _offlineService.updateTeam(teamId, updates);
      
      // Also update all players in the squad
      final players = await getPlayers();
      final teamPlayers = players.where((p) => p['team_id'] == teamId).toList();
      
      for (final player in teamPlayers) {
        await _offlineService.updatePlayer(player['id'].toString(), {
          'status': status,
          'reviewed_at': DateTime.now().toIso8601String(),
        });
      }
      
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Get venues with offline support
  Future<List<Map<String, dynamic>>> getVenues({bool forceRefresh = false}) async {
    if (isOnline && forceRefresh) {
      try {
        final response = await Supabase.instance.client
            .from('venues')
            .select('*')
            .order('created_at', ascending: false);

        final venues = List<Map<String, dynamic>>.from(response);
        
        // Store venues locally using the offline data service
        for (final venue in venues) {
          await _offlineService.createVenue(venue);
        }
        
        return venues;
      } catch (e) {
        debugPrint('Error fetching venues from server: $e');
      }
    }

    // Return local venues data
    return await _offlineService.getVenues();
  }

  /// Update venue with offline support
  Future<String?> updateVenue(String id, {String? name, String? location, int? capacity, bool? isActive}) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (location != null) updates['location'] = location;
      if (capacity != null) updates['capacity'] = capacity;
      if (isActive != null) updates['is_active'] = isActive;
      
      await _offlineService.updateVenue(id, updates: updates);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Delete venue with offline support
  Future<String?> deleteVenue(String id) async {
    try {
      await _offlineService.deleteVenue(id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
  Future<List<Map<String, dynamic>>> getMatches({bool forceRefresh = false}) async {
    return await _offlineService.getMatches(forceRefresh: forceRefresh);
  }

  /// Create match with offline support
  Future<String?> createMatch(Map<String, dynamic> matchData) async {
    try {
      await _offlineService.createMatch(matchData);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Get notifications with offline support
  Future<List<Map<String, dynamic>>> getNotifications({bool forceRefresh = false}) async {
    return await _offlineService.getNotifications(forceRefresh: forceRefresh);
  }

  /// Send notification with offline support
  Future<void> sendNotification({
    required String title,
    required String message,
    required String type,
    String? userId,
  }) async {
    final notificationData = {
      'recipient_id': userId,
      'title': title,
      'body': message,
      'type': type,
      'is_read': false,
      'related_table': null,
      'related_id': null,
    };
    
    await _offlineService.createNotification(notificationData);
  }

  /// Mark notification as read with offline support
  Future<void> markNotificationAsRead(String notificationId) async {
    await _offlineService.markNotificationAsRead(notificationId);
  }

  /// Get sync status
  Future<Map<String, int>> getSyncStatus() async {
    return await _offlineService.getSyncStatus();
  }

  /// Force sync all data
  Future<void> syncAll() async {
    await _offlineService.syncAll();
  }

  /// Get connectivity stream
  Stream<bool> get connectivityStream => _offlineService.connectivityStream;

  /// Get data update stream
  Stream<Map<String, dynamic>> get dataUpdateStream => _offlineService.dataUpdateStream;

  /// Update password (delegate to parent)
  Future<String?> updatePassword(String newPassword) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Create venue with offline support
  Future<String?> createVenue({
    required String name,
    required String location,
    required int capacity,
  }) async {
    try {
      final venueData = {
        'name': name,
        'location': location,
        'capacity': capacity,
        'is_active': true,
      };
      await _offlineService.createVenue(venueData);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Helper method to access supabase client
  SupabaseClient get supabase => Supabase.instance.client;
}