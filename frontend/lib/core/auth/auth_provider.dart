import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages user authentication, authorization, and profile data.
/// 
/// Handles sign-in/sign-up, role-based access control, approval workflows,
/// and provides methods for managing users, teams, players, and venues.
class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? _user;
  
  /// Currently authenticated user
  User? get user => _user;

  String? _role;
  
  /// User's role (admin, coach, referee, spectator)
  String? get role => _role;

  String? _approvalStatus;
  
  /// User's approval status (pending, approved, rejected)
  String? get approvalStatus => _approvalStatus;

  bool _isLoading = true;
  
  /// Whether authentication state is being initialized
  bool get isLoading => _isLoading;

  /// Set to true when a coach/referee is approved for the first time this session
  bool _justApproved = false;
  
  /// Whether the user was just approved in this session
  bool get justApproved => _justApproved;
  
  /// Clears the just-approved flag
  void clearJustApproved() {
    _justApproved = false;
    notifyListeners();
  }

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    _user = _supabase.auth.currentUser;
    if (_user != null) {
      _role = _user!.userMetadata?['role'] ?? 'spectator';
      _approvalStatus = _user!.userMetadata?['approval_status'] ?? _defaultApproval(_role);

      // Always fetch profile from DB so avatar_url and latest data are loaded
      await fetchProfile();
      if (_profile != null && _profile!['approval_status'] != null) {
        _approvalStatus = _profile!['approval_status'];
      }

      final session = _supabase.auth.currentSession;
      if (session != null) {
        await _storage.write(key: 'jwt', value: session.accessToken);
      }
    }
    _isLoading = false;
    notifyListeners();

    _supabase.auth.onAuthStateChange.listen((data) async {
      final prevStatus = _approvalStatus;
      _user = data.session?.user;
      if (_user != null) {
        _role = _user!.userMetadata?['role'] ?? 'spectator';
        _approvalStatus = _user!.userMetadata?['approval_status'] ?? _defaultApproval(_role);

        // Always fetch profile from DB on auth change to get fresh avatar_url etc.
        await fetchProfile();
        if (_profile != null && _profile!['approval_status'] != null) {
          _approvalStatus = _profile!['approval_status'];
        }

        await _storage.write(key: 'jwt', value: data.session?.accessToken);
        // Detect first approved login
        if (prevStatus == 'pending' && _approvalStatus == 'approved') {
          _justApproved = true;
        }
      } else {
        _role = null;
        _approvalStatus = null;
        _profile = null;
        await _storage.delete(key: 'jwt');
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Spectators are auto-approved; coaches and referees need admin approval.
  String _defaultApproval(String? role) {
    if (role == 'coach' || role == 'referee') return 'pending';
    return 'approved';
  }

  /// Translates raw Supabase / Dart exceptions into plain user-facing messages.
  String? _friendlyError(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('user already registered') || raw.contains('already been registered') || raw.contains('already in use')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (raw.contains('invalid login credentials') || raw.contains('invalid credentials') || raw.contains('wrong password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (raw.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (raw.contains('email') && raw.contains('invalid')) {
      return 'Please enter a valid email address.';
    }
    if (raw.contains('password') && (raw.contains('short') || raw.contains('weak') || raw.contains('characters'))) {
      return 'Password must be at least 6 characters long.';
    }
    if (raw.contains('network') || raw.contains('socketexception') || raw.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    if (raw.contains('too many requests') || raw.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (raw.contains('row-level security') || raw.contains('unauthorized') || raw.contains('403') || raw.contains('storageexception')) {
      // Avatar upload failed via RLS — account was still created, treat as success
      return null;
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return _friendlyError(e);
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> signUp(String email, String password, String fullName,
      String role, {String? phone, String? teamName, Uint8List? profileImage}) async {
    try {
      final approvalStatus = (role == 'coach' || role == 'referee') ? 'pending' : 'approved';
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
          'phone': phone ?? '',
          'approval_status': approvalStatus,
          if (teamName != null && teamName.isNotEmpty) 'team_name': teamName,
        },
      );

      final newUser = res.user;
      if (newUser != null && profileImage != null) {
        // Upload profile image if provided
        final String fileName = '${newUser.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('avatars').uploadBinary(
              fileName,
              profileImage,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
            );
        final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
        
        // Save avatar_url to profiles table.
        // Retry up to 3× because the DB trigger that creates the profiles row
        // may not have fired yet immediately after signUp.
        for (int attempt = 0; attempt < 3; attempt++) {
          if (attempt > 0) await Future.delayed(const Duration(milliseconds: 600));
          final affected = await _supabase
              .from('profiles')
              .update({'avatar_url': publicUrl})
              .eq('id', newUser.id)
              .select('id');
          if ((affected as List).isNotEmpty) break;
          // Last attempt: upsert to guarantee the row exists
          if (attempt == 2) {
            await _supabase.from('profiles').upsert({
              'id': newUser.id,
              'avatar_url': publicUrl,
              'full_name': fullName,
              'role': role,
            }, onConflict: 'id');
          }
        }
      }

      return null;
    } on AuthException catch (e) {
      return _friendlyError(e);
    } catch (e) {
      return _friendlyError(e); // returns null for StorageException/RLS = avatar failed but account OK
    }
  }

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? get profile => _profile;

  /// Fetches the profile for the current logged-in user.
  Future<void> fetchProfile() async {
    if (_user == null) {
      debugPrint('❌ fetchProfile: No user logged in');
      return;
    }
    try {
      debugPrint('📥 fetchProfile: Fetching profile for user ${_user!.id}');
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .single();
      _profile = res;
      debugPrint('✅ fetchProfile: Profile fetched successfully');
      debugPrint('   - full_name: ${_profile?['full_name']}');
      debugPrint('   - avatar_url: ${_profile?['avatar_url']}');
      debugPrint('   - role: ${_profile?['role']}');
      notifyListeners();
      debugPrint('✅ fetchProfile: notifyListeners() called');
    } catch (e) {
      debugPrint('❌ fetchProfile Error: $e');
    }
  }

  /// Uploads an avatar image and updates the profile.
  Future<String?> uploadAvatar(dynamic imageSource) async {
    if (_user == null) {
      return 'Not logged in';
    }
    
    try {
      final String fileName = '${_user!.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await imageSource.readAsBytes();
      
      await _supabase.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      final String cacheBustedUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await _supabase.from('profiles').update({'avatar_url': cacheBustedUrl}).eq('id', _user!.id);
      await _supabase.auth.updateUser(UserAttributes(data: {'avatar_url': cacheBustedUrl}));

      await fetchProfile();
      return null;
    } catch (e) {
      debugPrint('❌ uploadAvatar Error: $e');
      return 'Failed to upload avatar: $e';
    }
  }

  /// Fetches users with 'pending' status from the public.profiles table.
  /// This requires the profiles table and sync trigger to be set up.
  Future<List<Map<String, dynamic>>> getPendingUsers() async {
    try {
      debugPrint('🔍 AuthProvider: Fetching pending users...');
      final res = await _supabase
          .from('profiles')
          .select()
          .ilike('approval_status', 'pending'); // Case-insensitive just in case
      
      debugPrint('✅ AuthProvider: Found ${res.length} pending users.');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('❌ AuthProvider Error fetching pending users: $e');
      return [];
    }
  }

  /// Called by admin to approve a pending user.
  Future<void> approveUser(String userId) async {
    try {
      // 1. Update the public profiles status (immediate feedback)
      await _supabase
          .from('profiles')
          .update({'approval_status': 'approved'})
          .eq('id', userId);

      // 2. Call the RPC to update auth.user_metadata (privileged action)
      await _supabase.rpc('approve_user', params: {'user_id': userId});
    } catch (e) {
      debugPrint('Error approving user: $e');
    }
  }

  /// Fetches approved users by role.
  Future<List<Map<String, dynamic>>> getApprovedUsers(String role) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('role', role)
          .eq('approval_status', 'approved');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching approved $role: $e');
      return [];
    }
  }

  /// Allows admins to update ANY user profile.
  Future<String?> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('profiles').update(updates).eq('id', userId);
      return null;
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      return e.toString();
    }
  }

  /// Allows admins to delete a user profile.
  Future<String?> deleteUser(String userId) async {
    try {
      // 1. Delete assigned team if any (to avoid foreign key issues)
      await _supabase.from('teams').delete().eq('coach_id', userId);
      // 2. Delete profile
      await _supabase.from('profiles').delete().eq('id', userId);
      return null;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return e.toString();
    }
  }

  /// Fetches all teams from the public.teams table, joined with coach profiles.
  Future<List<Map<String, dynamic>>> getTeams() async {
    try {
      // Primary: PostgREST join (works once teams_coach_id_fkey FK exists)
      final res = await _supabase
          .from('teams')
          .select('*, profiles!coach_id(full_name, email, phone)');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('AuthProvider: Join query failed — enriching manually. $e');
      try {
        // Fallback: fetch teams then batch-fetch coach profiles by ID
        final teams = List<Map<String, dynamic>>.from(
          await _supabase.from('teams').select(),
        );
        final coachIds = teams
            .map((t) => t['coach_id'] as String?)
            .where((id) => id != null)
            .toSet()
            .toList();
        final Map<String, Map<String, dynamic>> profileMap = {};
        if (coachIds.isNotEmpty) {
          final profiles = await _supabase
              .from('profiles')
              .select('id, full_name, email, phone')
              .inFilter('id', coachIds.cast<Object>());
          for (final p in profiles) {
            profileMap[p['id'] as String] = Map<String, dynamic>.from(p);
          }
        }
        return teams.map((t) {
          final cid = t['coach_id'] as String?;
          return <String, dynamic>{
            ...t,
            'profiles': cid != null ? profileMap[cid] : null,
          };
        }).toList();
      } catch (e2) {
        debugPrint('AuthProvider Error fetching teams (fallback): $e2');
        return [];
      }
    }
  }

  /// Uploads a team logo and updates the team record.
  Future<String?> uploadTeamLogo(String teamId, dynamic imageSource) async {
    if (_user == null) return 'Not logged in';
    try {
      final String fileName = 'team_$teamId/logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await imageSource.readAsBytes();
      
      // 1. Upload to Supabase Storage
      await _supabase.storage.from('team_logos').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      // 2. Get Public URL
      final String publicUrl = _supabase.storage.from('team_logos').getPublicUrl(fileName);

      // 3. Update Team Table
      await updateTeam(teamId, logoUrl: publicUrl);
      return null;
    } catch (e) {
      debugPrint('Error uploading team logo: $e');
      return e.toString();
    }
  }

  /// Update team details in the database and synchronize with profile.
  Future<String?> updateTeam(String teamId, {String? name, String? logoUrl}) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) {
        updates['name'] = name;
        // 1. Sync back to profiles table so trigger/identities stay consistent
        await _supabase.from('profiles').update({'team_name': name}).eq('id', _user!.id);
        // 2. Update auth user metadata
        await _supabase.auth.updateUser(UserAttributes(data: {'team_name': name}));
      }
      if (logoUrl != null) updates['logo_url'] = logoUrl;

      if (updates.isNotEmpty) {
        await _supabase.from('teams').update(updates).eq('id', teamId);
      }
      return null;
    } catch (e) {
      debugPrint('Error updating team: $e');
      return e.toString();
    }
  }

  /// Fetches all players from the public.players table.
  Future<List<Map<String, dynamic>>> getPlayers() async {
    try {
      final res = await _supabase
          .from('players')
          .select('*, teams!team_id(name)');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('AuthProvider: Error fetching players: $e');
      try {
        final res = await _supabase.from('players').select();
        return List<Map<String, dynamic>>.from(res);
      } catch (e2) {
        return [];
      }
    }
  }

  /// Update profile fields — syncs to profiles table + auth metadata.
  Future<String?> updateProfile({String? fullName, String? phone, int? avatarIndex}) async {
    if (_user == null) return 'Not logged in';
    try {
      final updates = <String, dynamic>{};
      if (fullName != null && fullName.isNotEmpty) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (avatarIndex != null) updates['avatar_index'] = avatarIndex;

      if (updates.isNotEmpty) {
        // Update profiles table
        await _supabase.from('profiles').update(updates).eq('id', _user!.id);
        // Update auth user metadata
        await _supabase.auth.updateUser(UserAttributes(data: updates));
      }
      await fetchProfile();
      return null;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return e.toString();
    }
  }

  /// Update password.
  Future<String?> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ─── Squad Submission Workflow ───────────────────────────────────────────────

  /// Coach submits their squad for admin review.
  Future<String?> submitSquad(String teamId) async {
    if (_user == null) return 'Not logged in';
    try {
      // Get team name for notification
      final teamResponse = await _supabase
          .from('teams')
          .select('name')
          .eq('id', teamId)
          .single();
      
      final teamName = teamResponse['name'] as String;
      
      // Update team submission status
      await _supabase.from('teams').update({
        'submission_status': 'submitted',
        'submitted_at': DateTime.now().toIso8601String(),
        'rejection_note': null,
      }).eq('id', teamId);
      
      // Send notification to admin about squad submission
      await _supabase.from('notifications').insert({
        'recipient_id': null, // Broadcast to all admins
        'title': 'New Squad Submission',
        'body': '$teamName has submitted their squad for approval',
        'type': 'squad_submission',
        'is_read': false,
        'related_table': 'teams',
        'related_id': teamId,
      });
      
      return null;
    } catch (e) {
      debugPrint('Error submitting squad: $e');
      return e.toString();
    }
  }

  /// Admin fetches all teams whose squads are submitted, including players.
  Future<List<Map<String, dynamic>>> getSubmittedSquads() async {
    try {
      // Fetch submitted teams joined with coach profile
      final teams = await _supabase
          .from('teams')
          .select('*, profiles!coach_id(full_name, email)')
          .eq('submission_status', 'submitted')
          .order('submitted_at', ascending: false);

      final result = <Map<String, dynamic>>[];
      for (final team in teams) {
        // Fetch players for this team
        final players = await _supabase
            .from('players')
            .select()
            .eq('team_id', team['id'])
            .order('jersey_number');
        result.add({
          ...team,
          'players': players,
        });
      }
      return result;
    } catch (e) {
      debugPrint('Error fetching submitted squads: $e');
      // Fallback: fetch without join
      try {
        final teams = await _supabase
            .from('teams')
            .select()
            .eq('submission_status', 'submitted');
        return List<Map<String, dynamic>>.from(teams);
      } catch (_) {
        return [];
      }
    }
  }

  /// Admin approves or rejects a submitted squad.
  /// Pass [approve: true] to approve, [approve: false] to reject with a [note].
  Future<String?> reviewSquad(String teamId, {required bool approve, String? note}) async {
    if (_user == null) return 'Not logged in';
    try {
      // Get team name and coach info for notification
      final teamResponse = await _supabase
          .from('teams')
          .select('name, coach_id, profiles!teams_coach_id_fkey(full_name)')
          .eq('id', teamId)
          .single();
      
      final teamName = teamResponse['name'] as String;
      final coachId = teamResponse['coach_id'] as String?;
      final coachName = teamResponse['profiles']?['full_name'] as String? ?? 'Coach';
      
      // Update team submission status
      await _supabase.from('teams').update({
        'submission_status': approve ? 'approved' : 'rejected',
        'rejection_note': approve ? null : (note ?? 'Rejected by admin'),
      }).eq('id', teamId);
      
      // Send notification to coach about squad review result
      if (coachId != null) {
        await _supabase.from('notifications').insert({
          'recipient_id': coachId,
          'title': approve ? 'Squad Approved' : 'Squad Rejected',
          'body': approve 
              ? 'Your $teamName squad has been approved and is ready for matches!'
              : 'Your $teamName squad was rejected. ${note ?? 'Please review and resubmit.'}',
          'type': approve ? 'squad_approved' : 'squad_rejected',
          'is_read': false,
          'related_table': 'teams',
          'related_id': teamId,
        });
      }
      
      // Also send broadcast notification for approved squads
      if (approve) {
        await _supabase.from('notifications').insert({
          'recipient_id': null, // Broadcast
          'title': 'Squad Ready for Matches',
          'body': '$teamName squad approved by admin - lineup available for spectators',
          'type': 'squad_ready',
          'is_read': false,
          'related_table': 'teams',
          'related_id': teamId,
        });
      }
      
      return null;
    } catch (e) {
      debugPrint('Error reviewing squad: $e');
      return e.toString();
    }
  }

  // ─── Venue Management ────────────────────────────────────────────────────────

  /// Fetch all venues ordered by name.
  Future<List<Map<String, dynamic>>> getVenues() async {
    try {
      final res = await _supabase
          .from('venues')
          .select()
          .order('name');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching venues: $e');
      return [];
    }
  }

  /// Add a new venue.
  Future<String?> addVenue({required String name, String? location, int? capacity}) async {
    if (_user == null) return 'Not logged in';
    try {
      await _supabase.from('venues').insert({
        'name': name,
        if (location != null && location.isNotEmpty) 'location': location,
        if (capacity != null) 'capacity': capacity,
      });
      return null;
    } catch (e) {
      debugPrint('Error adding venue: $e');
      return e.toString();
    }
  }

  /// Update an existing venue.
  Future<String?> updateVenue(String id, {String? name, String? location, int? capacity, bool? isActive}) async {
    if (_user == null) return 'Not logged in';
    try {
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (location != null) updates['location'] = location;
      if (capacity != null) updates['capacity'] = capacity;
      if (isActive != null) updates['is_active'] = isActive;
      if (updates.isNotEmpty) {
        await _supabase.from('venues').update(updates).eq('id', id);
      }
      return null;
    } catch (e) {
      debugPrint('Error updating venue: $e');
      return e.toString();
    }
  }

  /// Delete a venue.
  Future<String?> deleteVenue(String id) async {
    if (_user == null) return 'Not logged in';
    try {
      await _supabase.from('venues').delete().eq('id', id);
      return null;
    } catch (e) {
      debugPrint('Error deleting venue: $e');
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
