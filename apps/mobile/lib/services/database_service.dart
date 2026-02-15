import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton service managing the sqflite [Database] lifecycle.
///
/// Handles database creation and schema migrations.
/// Returns `null` on web platforms where sqflite is not supported.
class DatabaseService {
  Database? _database;
  bool _initialized = false;

  static const _dbName = 'ccpocket.db';
  static const _dbVersion = 1;

  /// Get the database instance, initializing it if needed.
  ///
  /// Returns `null` on web platforms or when sqflite is not available
  /// (e.g. in unit tests without sqflite_common_ffi).
  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_initialized) return _database;
    try {
      _database = await _initDatabase();
    } catch (e) {
      // sqflite factory not initialized (e.g. unit test environment)
      debugPrint('[DatabaseService] init failed (no-op): $e');
      _database = null;
    }
    _initialized = true;
    return _database;
  }

  Future<Database> _initDatabase() async {
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
  }

  /// Close the database connection.
  Future<void> close() async {
    await _database?.close();
    _database = null;
    _initialized = false;
  }
}
