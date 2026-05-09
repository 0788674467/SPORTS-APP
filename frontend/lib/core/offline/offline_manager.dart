import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineManager {
  static final OfflineManager _instance = OfflineManager._internal();
  factory OfflineManager() => _instance;
  OfflineManager._internal();

  Database? _database;
  bool _isOnline = true;
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _dataUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Pending operations queue for when back online
  final List<Map<String, dynamic>> _pendingOperations = [];

  Stream<bool> get connectivityStream => _connectivityController.stream;
  Stream<Map<String, dynamic>> get dataUpdateStream => _dataUpdateController.stream;
  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    await _initDatabase();
    await _initConnectivity();
    _startSyncTimer();
  }

  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'sports_app_offline.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create tables for offline storage
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            last_updated INTEGER NOT NULL,
            is_dirty INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE teams (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            last_updated INTEGER NOT NULL,
            is_dirty INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE players (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            last_updated INTEGER NOT NULL,
            is_dirty INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE matches (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            last_updated INTEGER NOT NULL,
            is_dirty INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE notifications (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            last_updated INTEGER NOT NULL,
            is_dirty INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE pending_operations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation_type TEXT NOT NULL,
            table_name TEXT NOT NULL,
            record_id TEXT NOT NULL,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    
    // Check initial connectivity
    final result = await connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    _connectivityController.add(_isOnline);

    // Listen for connectivity changes
    connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      _connectivityController.add(_isOnline);

      if (!wasOnline && _isOnline) {
        // Just came back online, sync pending operations
        _syncPendingOperations();
      }
    });
  }

  void _startSyncTimer() {
    // Sync every 30 seconds when online
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isOnline) {
        _syncWithServer();
      }
    });
  }

  // Store data locally with optional server sync
  Future<void> storeData(String table, String id, Map<String, dynamic> data, {bool syncToServer = true}) async {
    if (_database == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final dataJson = jsonEncode(data);

    await _database!.insert(
      table,
      {
        'id': id,
        'data': dataJson,
        'last_updated': now,
        'is_dirty': syncToServer ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Emit data update event
    _dataUpdateController.add({
      'table': table,
      'id': id,
      'data': data,
      'action': 'store'
    });

    if (syncToServer && _isOnline) {
      await _syncRecordToServer(table, id, data);
    } else if (syncToServer) {
      // Store as pending operation
      await _addPendingOperation('upsert', table, id, data);
    }
  }

  // Retrieve data from local storage
  Future<Map<String, dynamic>?> getData(String table, String id) async {
    if (_database == null) return null;

    final result = await _database!.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      final dataJson = result.first['data'] as String;
      return jsonDecode(dataJson) as Map<String, dynamic>;
    }

    return null;
  }

  // Get all data from a table
  Future<List<Map<String, dynamic>>> getAllData(String table) async {
    if (_database == null) return [];

    final result = await _database!.query(table, orderBy: 'last_updated DESC');
    
    return result.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      data['_offline_id'] = row['id'];
      data['_last_updated'] = row['last_updated'];
      data['_is_dirty'] = row['is_dirty'] == 1;
      return data;
    }).toList();
  }

  // Delete data locally and sync to server
  Future<void> deleteData(String table, String id) async {
    if (_database == null) return;

    await _database!.delete(table, where: 'id = ?', whereArgs: [id]);

    _dataUpdateController.add({
      'table': table,
      'id': id,
      'action': 'delete'
    });

    if (_isOnline) {
      await _syncDeleteToServer(table, id);
    } else {
      await _addPendingOperation('delete', table, id, {});
    }
  }

  // Add pending operation for offline sync
  Future<void> _addPendingOperation(String operationType, String table, String id, Map<String, dynamic> data) async {
    if (_database == null) return;

    await _database!.insert('pending_operations', {
      'operation_type': operationType,
      'table_name': table,
      'record_id': id,
      'data': jsonEncode(data),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Sync pending operations when back online
  Future<void> _syncPendingOperations() async {
    if (_database == null || !_isOnline) return;

    final pendingOps = await _database!.query('pending_operations', orderBy: 'timestamp ASC');

    for (final op in pendingOps) {
      try {
        final operationType = op['operation_type'] as String;
        final tableName = op['table_name'] as String;
        final recordId = op['record_id'] as String;
        final data = jsonDecode(op['data'] as String) as Map<String, dynamic>;

        if (operationType == 'upsert') {
          await _syncRecordToServer(tableName, recordId, data);
        } else if (operationType == 'delete') {
          await _syncDeleteToServer(tableName, recordId);
        }

        // Remove completed operation
        await _database!.delete('pending_operations', where: 'id = ?', whereArgs: [op['id']]);
      } catch (e) {
        debugPrint('Error syncing pending operation: $e');
        // Keep the operation for retry later
      }
    }
  }

  // Sync record to server
  Future<void> _syncRecordToServer(String table, String id, Map<String, dynamic> data) async {
    try {
      final supabaseTable = _getSupabaseTableName(table);
      if (supabaseTable == null) return;

      await Supabase.instance.client
          .from(supabaseTable)
          .upsert(data);

      // Mark as clean in local storage
      if (_database != null) {
        await _database!.update(
          table,
          {'is_dirty': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } catch (e) {
      debugPrint('Error syncing to server: $e');
      // Keep as dirty for retry later
    }
  }

  // Sync delete to server
  Future<void> _syncDeleteToServer(String table, String id) async {
    try {
      final supabaseTable = _getSupabaseTableName(table);
      if (supabaseTable == null) return;

      await Supabase.instance.client
          .from(supabaseTable)
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('Error deleting from server: $e');
    }
  }

  // Map local table names to Supabase table names
  String? _getSupabaseTableName(String localTable) {
    const mapping = {
      'users': 'profiles',
      'teams': 'teams',
      'players': 'players',
      'matches': 'scheduled_matches',
      'notifications': 'notifications',
    };
    return mapping[localTable];
  }

  // Sync all data with server
  Future<void> _syncWithServer() async {
    if (!_isOnline || _database == null) return;

    try {
      // Sync dirty records to server first
      await _syncDirtyRecords();
      
      // Then pull latest data from server
      await _pullLatestData();
    } catch (e) {
      debugPrint('Error during sync: $e');
    }
  }

  Future<void> _syncDirtyRecords() async {
    if (_database == null) return;

    final tables = ['users', 'teams', 'players', 'matches', 'notifications'];
    
    for (final table in tables) {
      final dirtyRecords = await _database!.query(
        table,
        where: 'is_dirty = ?',
        whereArgs: [1],
      );

      for (final record in dirtyRecords) {
        final id = record['id'] as String;
        final data = jsonDecode(record['data'] as String) as Map<String, dynamic>;
        await _syncRecordToServer(table, id, data);
      }
    }
  }

  Future<void> _pullLatestData() async {
    // Pull latest data from server and update local storage
    // This would be implemented based on your specific sync strategy
    // For now, we'll just mark this as a placeholder
    debugPrint('Pulling latest data from server...');
  }

  // Get sync status
  Future<Map<String, int>> getSyncStatus() async {
    if (_database == null) return {};

    final tables = ['users', 'teams', 'players', 'matches', 'notifications'];
    final status = <String, int>{};

    for (final table in tables) {
      final dirtyCount = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM $table WHERE is_dirty = 1'
      );
      status[table] = (dirtyCount.first['count'] as int?) ?? 0;
    }

    final pendingOps = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM pending_operations'
    );
    status['pending_operations'] = (pendingOps.first['count'] as int?) ?? 0;

    return status;
  }

  void dispose() {
    _connectivityController.close();
    _dataUpdateController.close();
    _database?.close();
  }
}