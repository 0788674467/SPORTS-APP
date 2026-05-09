import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_manager.dart';

class OfflineDataService {
  static final OfflineDataService _instance = OfflineDataService._internal();
  factory OfflineDataService() => _instance;
  OfflineDataService._internal();

  final OfflineManager _offlineManager = OfflineManager();

  Future<void> initialize() async {
    await _offlineManager.initialize();
  }

  // Teams
  Future<List<Map<String, dynamic>>> getTeams({bool forceRefresh = false}) async {
    if (_offlineManager.isOnline && forceRefresh) {
      try {
        final response = await Supabase.instance.client
            .from('teams')
            .select('*')
            .order('created_at', ascending: false);

        final teams = List<Map<String, dynamic>>.from(response);
        
        // Store each team locally
        for (final team in teams) {
          await _offlineManager.storeData('teams', team['id'].toString(), team, syncToServer: false);
        }
        
        return teams;
      } catch (e) {
        debugPrint('Error fetching teams from server: $e');
        // Fall back to local data
      }
    }

    // Return local data
    return await _offlineManager.getAllData('teams');
  }

  Future<void> createTeam(Map<String, dynamic> teamData) async {
    final id = teamData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    teamData['id'] = id;
    teamData['created_at'] = DateTime.now().toIso8601String();
    
    await _offlineManager.storeData('teams', id, teamData);
  }

  Future<void> updateTeam(String id, Map<String, dynamic> updates) async {
    final existingTeam = await _offlineManager.getData('teams', id);
    if (existingTeam != null) {
      final updatedTeam = {...existingTeam, ...updates};
      updatedTeam['updated_at'] = DateTime.now().toIso8601String();
      await _offlineManager.storeData('teams', id, updatedTeam);
    }
  }

  Future<void> deleteTeam(String id) async {
    await _offlineManager.deleteData('teams', id);
  }

  // Players
  Future<List<Map<String, dynamic>>> getPlayers({bool forceRefresh = false}) async {
    if (_offlineManager.isOnline && forceRefresh) {
      try {
        final response = await Supabase.instance.client
            .from('players')
            .select('*')
            .order('created_at', ascending: false);

        final players = List<Map<String, dynamic>>.from(response);
        
        // Store each player locally
        for (final player in players) {
          await _offlineManager.storeData('players', player['id'].toString(), player, syncToServer: false);
        }
        
        return players;
      } catch (e) {
        debugPrint('Error fetching players from server: $e');
      }
    }

    return await _offlineManager.getAllData('players');
  }

  Future<void> createPlayer(Map<String, dynamic> playerData) async {
    final id = playerData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    playerData['id'] = id;
    playerData['created_at'] = DateTime.now().toIso8601String();
    
    await _offlineManager.storeData('players', id, playerData);
  }

  Future<void> updatePlayer(String id, Map<String, dynamic> updates) async {
    final existingPlayer = await _offlineManager.getData('players', id);
    if (existingPlayer != null) {
      final updatedPlayer = {...existingPlayer, ...updates};
      updatedPlayer['updated_at'] = DateTime.now().toIso8601String();
      await _offlineManager.storeData('players', id, updatedPlayer);
    }
  }

  Future<void> approvePlayer(String id) async {
    await updatePlayer(id, {
      'status': 'approved',
      'approved_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deletePlayer(String id) async {
    await _offlineManager.deleteData('players', id);
  }

  // Users/Profiles
  Future<List<Map<String, dynamic>>> getPendingUsers({bool forceRefresh = false}) async {
    if (_offlineManager.isOnline && forceRefresh) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('status', 'pending')
            .order('created_at', ascending: false);

        final users = List<Map<String, dynamic>>.from(response);
        
        // Store each user locally
        for (final user in users) {
          await _offlineManager.storeData('users', user['id'].toString(), user, syncToServer: false);
        }
        
        return users;
      } catch (e) {
        debugPrint('Error fetching pending users from server: $e');
      }
    }

    // Return local pending users
    final allUsers = await _offlineManager.getAllData('users');
    return allUsers.where((user) => user['status'] == 'pending').toList();
  }

  Future<void> approveUser(String userId) async {
    await updateUser(userId, {
      'status': 'approved',
      'approved_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateUser(String id, Map<String, dynamic> updates) async {
    final existingUser = await _offlineManager.getData('users', id);
    if (existingUser != null) {
      final updatedUser = {...existingUser, ...updates};
      updatedUser['updated_at'] = DateTime.now().toIso8601String();
      await _offlineManager.storeData('users', id, updatedUser);
    }
  }

  // Matches
  Future<List<Map<String, dynamic>>> getMatches({bool forceRefresh = false}) async {
    if (_offlineManager.isOnline && forceRefresh) {
      try {
        final response = await Supabase.instance.client
            .from('scheduled_matches')
            .select('*')
            .order('date_time', ascending: false);

        final matches = List<Map<String, dynamic>>.from(response);
        
        // Store each match locally
        for (final match in matches) {
          await _offlineManager.storeData('matches', match['id'].toString(), match, syncToServer: false);
        }
        
        return matches;
      } catch (e) {
        debugPrint('Error fetching matches from server: $e');
      }
    }

    return await _offlineManager.getAllData('matches');
  }

  Future<void> createMatch(Map<String, dynamic> matchData) async {
    final id = matchData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    matchData['id'] = id;
    matchData['created_at'] = DateTime.now().toIso8601String();
    
    await _offlineManager.storeData('matches', id, matchData);
  }

  Future<void> updateMatch(String id, Map<String, dynamic> updates) async {
    final existingMatch = await _offlineManager.getData('matches', id);
    if (existingMatch != null) {
      final updatedMatch = {...existingMatch, ...updates};
      updatedMatch['updated_at'] = DateTime.now().toIso8601String();
      await _offlineManager.storeData('matches', id, updatedMatch);
    }
  }

  // Notifications
  Future<List<Map<String, dynamic>>> getNotifications({bool forceRefresh = false}) async {
    if (_offlineManager.isOnline && forceRefresh) {
      try {
        final response = await Supabase.instance.client
            .from('notifications')
            .select('*')
            .order('created_at', ascending: false)
            .limit(50);

        final notifications = List<Map<String, dynamic>>.from(response);
        
        // Store each notification locally
        for (final notification in notifications) {
          await _offlineManager.storeData('notifications', notification['id'].toString(), notification, syncToServer: false);
        }
        
        return notifications;
      } catch (e) {
        debugPrint('Error fetching notifications from server: $e');
      }
    }

    return await _offlineManager.getAllData('notifications');
  }

  Future<void> createNotification(Map<String, dynamic> notificationData) async {
    final id = notificationData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    notificationData['id'] = id;
    notificationData['created_at'] = DateTime.now().toIso8601String();
    
    await _offlineManager.storeData('notifications', id, notificationData);
  }

  Future<void> markNotificationAsRead(String id) async {
    await updateNotification(id, {
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateNotification(String id, Map<String, dynamic> updates) async {
    final existingNotification = await _offlineManager.getData('notifications', id);
    if (existingNotification != null) {
      final updatedNotification = {...existingNotification, ...updates};
      updatedNotification['updated_at'] = DateTime.now().toIso8601String();
      await _offlineManager.storeData('notifications', id, updatedNotification);
    }
  }

  // Venues
  Future<List<Map<String, dynamic>>> getVenues({bool forceRefresh = false}) async {
    if (_offlineManager.isOnline && forceRefresh) {
      try {
        final response = await Supabase.instance.client
            .from('venues')
            .select('*')
            .order('created_at', ascending: false);

        final venues = List<Map<String, dynamic>>.from(response);
        
        // Store each venue locally
        for (final venue in venues) {
          await _offlineManager.storeData('venues', venue['id'].toString(), venue, syncToServer: false);
        }
        
        return venues;
      } catch (e) {
        debugPrint('Error fetching venues from server: $e');
      }
    }

    return await _offlineManager.getAllData('venues');
  }

  Future<void> createVenue(Map<String, dynamic> venueData) async {
    final id = venueData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    venueData['id'] = id;
    venueData['created_at'] = DateTime.now().toIso8601String();
    
    await _offlineManager.storeData('venues', id, venueData);
  }

  Future<void> updateVenue(String id, {Map<String, dynamic>? updates}) async {
    final existingVenue = await _offlineManager.getData('venues', id);
    if (existingVenue != null) {
      final updatedVenue = {...existingVenue};
      if (updates != null) updatedVenue.addAll(updates);
      updatedVenue['updated_at'] = DateTime.now().toIso8601String();
      await _offlineManager.storeData('venues', id, updatedVenue);
    }
  }

  Future<void> deleteVenue(String id) async {
    await _offlineManager.deleteData('venues', id);
  }
  Future<Map<String, int>> getSyncStatus() async {
    return await _offlineManager.getSyncStatus();
  }

  bool get isOnline => _offlineManager.isOnline;
  
  Stream<bool> get connectivityStream => _offlineManager.connectivityStream;
  
  Stream<Map<String, dynamic>> get dataUpdateStream => _offlineManager.dataUpdateStream;

  // Force sync all data
  Future<void> syncAll() async {
    if (!_offlineManager.isOnline) return;

    await Future.wait([
      getTeams(forceRefresh: true),
      getPlayers(forceRefresh: true),
      getPendingUsers(forceRefresh: true),
      getMatches(forceRefresh: true),
      getNotifications(forceRefresh: true),
    ]);
  }
}