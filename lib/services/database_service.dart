// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:protognome/models/compat_tool.dart';
import 'package:protognome/models/steam_game.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

/// Points the sqlite3 package at the system library. Linux desktops ship
/// `libsqlite3.so.0` (package libsqlite3-0); the unversioned `libsqlite3.so`
/// the package looks for by default exists only with the -dev package.
///
/// Must be a top-level function: sqflite_common_ffi runs the database in a
/// background isolate and calls this there, where an override set in the
/// main isolate does not apply.
void protognomeSqliteInit() {
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so.0');
      } on Object {
        return DynamicLibrary.open('libsqlite3.so');
      }
    });
  }
}

/// Service managing SQLite local database caching using `sqflite_common_ffi`.
/// Handles persistent application settings, compatibility tools caches, and
/// detected Steam games.
class DatabaseService {
  /// Returns the shared DatabaseService instance.
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  static final DatabaseService _instance = DatabaseService._internal();

  Database? _db;

  /// Returns the active SQLite database instance, initializing it if necessary.
  Future<Database> get db async {
    _db ??= await _initDatabase();
    return _db!;
  }

  /// Initializes the SQLite database on local storage.
  ///
  /// Uses its own FFI factory with [protognomeSqliteInit] rather than the
  /// global `databaseFactory`. (1.0.11 set an override in main(), but this
  /// method then replaced the global factory with a plain one, so the override
  /// never took effect and the app failed with "libsqlite3.so: cannot open
  /// shared object file" on systems without libsqlite3-dev.)
  Future<Database> _initDatabase() async {
    final factory = createDatabaseFactoryFfi(ffiInit: protognomeSqliteInit);

    final supportDir = await getApplicationSupportDirectory();
    final dbPath = p.join(supportDir.path, 'protognome.db');

    return factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  /// Schema upgrades for existing installs.
  /// v2: GitHub's per-asset digest (`asset_digest`) for download verification.
  /// The release cache is cleared so every release is re-read with its digest.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE compat_tools ADD COLUMN asset_digest TEXT');
      await db.delete('compat_tools');
    }
  }

  /// Callback to execute the SQL table creation queries on new database
  /// instances.
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
        asset_digest TEXT,
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

  /// Retrieves a list of cached [CompatTool] entries for [toolType] if they are
  /// less than 1 hour old.
  Future<List<CompatTool>> getCachedTools(String toolType) async {
    final database = await db;
    // Only use cache if it's < 1 hour old
    final oneHourAgo = DateTime.now().millisecondsSinceEpoch - 3600000;
    final maps = await database.query(
      'compat_tools',
      where: 'tool_type = ? AND (cached_at IS NULL OR cached_at > ?)',
      whereArgs: [toolType, oneHourAgo],
    );
    return maps.map(CompatTool.fromMap).toList();
  }

  /// Caches a batch list of [CompatTool] instances in the local SQLite tables.
  Future<void> cacheTools(List<CompatTool> tools) async {
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = database.batch();
    for (final tool in tools) {
      final map = tool.toMap();
      map['cached_at'] = now;
      batch.insert(
        'compat_tools',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Updates or inserts a single [CompatTool] instance in the local cache.
  Future<void> upsertTool(CompatTool tool) async {
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = tool.toMap();
    map['cached_at'] = now;
    await database.insert(
      'compat_tools',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      batch.insert(
        'steam_games',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Returns all cached [SteamGame] entries sorted alphabetically by name.
  Future<List<SteamGame>> getAllCachedGames() async {
    final database = await db;
    final maps = await database.query('steam_games', orderBy: 'game_name ASC');
    return maps.map(SteamGame.fromMap).toList();
  }
}
