// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/compat_tool.dart';
import '../models/steam_game.dart';

/// Service managing SQLite local database caching using `sqflite_common_ffi`.
/// Handles persistent application settings, compatibility tools caches, and detected Steam games.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  /// Returns the active SQLite database instance, initializing it if necessary.
  Future<Database> get db async {
    _db ??= await _initDatabase();
    return _db!;
  }

  /// Initializes the SQLite database on local storage.
  Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final supportDir = await getApplicationSupportDirectory();
    final dbPath = p.join(supportDir.path, 'protognome.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// Callback to execute the SQL table creation queries on new database instances.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE compat_tools (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        version TEXT NOT NULL,
        tool_type TEXT NOT NULL,
        release_date TEXT,
        download_url TEXT,
        download_size INTEGER,
        checksum TEXT,
        is_installed INTEGER NOT NULL DEFAULT 0,
        cached_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE steam_games (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        app_id INTEGER NOT NULL UNIQUE,
        game_name TEXT NOT NULL,
        compat_tool TEXT,
        is_shortcut INTEGER NOT NULL DEFAULT 0,
        library_path TEXT,
        cached_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Default settings
    await db.insert('settings', {'key': 'install_dir', 'value': ''});
    await db.insert('settings', {'key': 'launcher', 'value': 'steam'});
    await db.insert('settings', {'key': 'github_token', 'value': ''});
  }

  // ---- Settings ----

  /// Retrieves a persistent configuration value for the given [key].
  Future<String?> getSetting(String key) async {
    final database = await db;
    final result = await database.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String?;
    }
    return null;
  }

  /// Updates or inserts a persistent configuration [value] for [key].
  Future<void> setSetting(String key, String value) async {
    final database = await db;
    await database.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- Compat Tools ----

  /// Retrieves a list of cached [CompatTool] entries for [toolType] if they are less than 1 hour old.
  Future<List<CompatTool>> getCachedTools(String toolType) async {
    final database = await db;
    // Only use cache if it's < 1 hour old
    final oneHourAgo = DateTime.now().millisecondsSinceEpoch - 3600000;
    final maps = await database.query(
      'compat_tools',
      where: 'tool_type = ? AND (cached_at IS NULL OR cached_at > ?)',
      whereArgs: [toolType, oneHourAgo],
    );
    return maps.map((m) => CompatTool.fromMap(m)).toList();
  }

  /// Caches a batch list of [CompatTool] instances in the local SQLite tables.
  Future<void> cacheTools(List<CompatTool> tools) async {
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = database.batch();
    for (final tool in tools) {
      final map = tool.toMap();
      map['cached_at'] = now;
      batch.insert('compat_tools', map,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Updates or inserts a single [CompatTool] instance in the local cache.
  Future<void> upsertTool(CompatTool tool) async {
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = tool.toMap();
    map['cached_at'] = now;
    await database.insert('compat_tools', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Deletes the cached compatibility tool entry matching the given [name].
  Future<void> deleteTool(String name) async {
    final database = await db;
    await database.delete('compat_tools', where: 'name = ?', whereArgs: [name]);
  }

  // ---- Steam Games ----

  /// Caches a batch list of [SteamGame] instances in the database.
  Future<void> cacheGames(List<SteamGame> games) async {
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = database.batch();
    for (final game in games) {
      final map = game.toMap();
      map['cached_at'] = now;
      batch.insert('steam_games', map,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Returns all cached [SteamGame] entries sorted alphabetically by name.
  Future<List<SteamGame>> getAllCachedGames() async {
    final database = await db;
    final maps = await database.query('steam_games', orderBy: 'game_name ASC');
    return maps.map((m) => SteamGame.fromMap(m)).toList();
  }
}
