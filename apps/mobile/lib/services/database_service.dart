import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/logger.dart';
import 'database_platform.dart';

/// Singleton service managing the sqflite [Database] lifecycle.
///
/// Handles database creation and schema migrations.
/// Returns `null` when the current platform has no available database backend.
class DatabaseService {
  Database? _database;
  bool _initialized = false;

  static const _dbName = 'ccpocket.db';
  static const _dbVersion = 2;

  /// Get the database instance, initializing it if needed.
  ///
  /// Returns `null` on web platforms or when the database backend is not
  /// available in the current runtime.
  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_initialized) return _database;
    try {
      _database = await _initDatabase();
    } catch (e) {
      // sqflite factory not initialized (e.g. unit test environment)
      logger.warning('[DatabaseService] init failed (no-op)', e);
      _database = null;
    }
    _initialized = true;
    return _database;
  }

  Future<Database> _initDatabase() async {
    final platformConfig = await getPlatformDatabaseOpenConfig(_dbName);
    if (platformConfig != null) {
      return platformConfig.open(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }

    final path = await getDatabasesPath();
    final dbPath = '$path/$_dbName';
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createPromptHistoryV1(db);
    await _createPromptHistoryV2(db);
  }

  Future<void> _createPromptHistoryV1(Database db) async {
    await db.execute('''
      CREATE TABLE prompt_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        project_path TEXT NOT NULL DEFAULT '',
        use_count INTEGER NOT NULL DEFAULT 1,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        last_used_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_prompt_text_project
      ON prompt_history (text, project_path)
    ''');

    await db.execute('''
      CREATE INDEX idx_prompt_last_used
      ON prompt_history (last_used_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_prompt_project
      ON prompt_history (project_path)
    ''');
  }

  Future<void> _createPromptHistoryV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prompt_history_cache (
        id TEXT NOT NULL,
        bridge_id TEXT NOT NULL,
        bridge_url TEXT NOT NULL,
        bridge_name TEXT NOT NULL DEFAULT '',
        text TEXT NOT NULL,
        project_path TEXT NOT NULL DEFAULT '',
        total_use_count INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_used_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        favorite_updated_at TEXT,
        deleted_at TEXT,
        command_kind TEXT NOT NULL DEFAULT 'none',
        client_stats_json TEXT NOT NULL DEFAULT '{}',
        session_stats_json TEXT NOT NULL DEFAULT '{}',
        synced_revision INTEGER NOT NULL DEFAULT 0,
        synced_at TEXT NOT NULL,
        PRIMARY KEY (id, bridge_id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_prompt_history_cache_last_used
      ON prompt_history_cache (last_used_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_prompt_history_cache_project
      ON prompt_history_cache (project_path)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_prompt_history_cache_bridge
      ON prompt_history_cache (bridge_id)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS prompt_history_sync_status (
        bridge_id TEXT PRIMARY KEY,
        bridge_url TEXT NOT NULL,
        bridge_name TEXT NOT NULL DEFAULT '',
        last_sync_at TEXT,
        revision INTEGER NOT NULL DEFAULT 0,
        entry_count INTEGER NOT NULL DEFAULT 0,
        error TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPromptHistoryV2(db);
    }
  }

  /// Get the absolute path to the database file.
  Future<String> getDbPath() async {
    final platformConfig = await getPlatformDatabaseOpenConfig(_dbName);
    if (platformConfig != null) return platformConfig.path;

    final path = await getDatabasesPath();
    return '$path/$_dbName';
  }

  /// Close the database connection.
  Future<void> close() async {
    await _database?.close();
    _database = null;
    _initialized = false;
  }
}
