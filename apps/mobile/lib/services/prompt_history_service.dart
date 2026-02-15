import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

/// Sort order for prompt history queries.
enum PromptSortOrder {
  /// Most recently used first.
  recency,

  /// Most frequently used first.
  frequency,

  /// Favorites first, then by recency.
  favoritesFirst,
}

/// A single prompt history entry.
class PromptHistoryEntry {
  final int id;
  final String text;
  final String projectPath;
  final int useCount;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  const PromptHistoryEntry({
    required this.id,
    required this.text,
    required this.projectPath,
    required this.useCount,
    required this.isFavorite,
    required this.createdAt,
    required this.lastUsedAt,
  });

  factory PromptHistoryEntry.fromMap(Map<String, dynamic> map) {
    return PromptHistoryEntry(
      id: map['id'] as int,
      text: map['text'] as String,
      projectPath: map['project_path'] as String,
      useCount: map['use_count'] as int,
      isFavorite: (map['is_favorite'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastUsedAt: DateTime.fromMillisecondsSinceEpoch(
        map['last_used_at'] as int,
      ),
    );
  }

  /// Display name for the project (last path component or empty string).
  String get projectName {
    if (projectPath.isEmpty) return '';
    return projectPath.split('/').last;
  }
}

/// Service for managing prompt history using sqflite.
///
/// On web platforms all methods are no-ops (returning empty results).
class PromptHistoryService {
  final DatabaseService _dbService;

  PromptHistoryService(this._dbService);

  Future<Database?> get _db => _dbService.database;

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  /// Record a sent prompt.
  ///
  /// Skips recording for:
  /// - Slash commands (`/` prefix)
  /// - Short texts (< 5 characters)
  /// - Long texts (> 2000 characters)
  ///
  /// If the same text+projectPath already exists, updates `use_count` and
  /// `last_used_at` instead of inserting a duplicate.
  Future<void> recordPrompt(String text, {String projectPath = ''}) async {
    final db = await _db;
    if (db == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.startsWith('/')) return;
    if (trimmed.length < 5) return;
    if (trimmed.length > 2000) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Try UPDATE first (upsert pattern)
    final updated = await db.rawUpdate(
      '''
      UPDATE prompt_history
      SET use_count = use_count + 1, last_used_at = ?
      WHERE text = ? AND project_path = ?
      ''',
      [now, trimmed, projectPath],
    );

    if (updated == 0) {
      // No existing row — insert
      try {
        await db.insert('prompt_history', {
          'text': trimmed,
          'project_path': projectPath,
          'use_count': 1,
          'is_favorite': 0,
          'created_at': now,
          'last_used_at': now,
        });
      } catch (e) {
        // UNIQUE constraint violation (race condition) — update instead
        debugPrint('[PromptHistory] insert conflict, updating: $e');
        await db.rawUpdate(
          '''
          UPDATE prompt_history
          SET use_count = use_count + 1, last_used_at = ?
          WHERE text = ? AND project_path = ?
          ''',
          [now, trimmed, projectPath],
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Querying
  // ---------------------------------------------------------------------------

  /// Retrieve prompt history with optional filtering and sorting.
  Future<List<PromptHistoryEntry>> getPrompts({
    PromptSortOrder sort = PromptSortOrder.recency,
    String? projectPath,
    String? searchQuery,
    int limit = 50,
  }) async {
    final db = await _db;
    if (db == null) return const [];

    final where = <String>[];
    final args = <dynamic>[];

    if (projectPath != null) {
      where.add('project_path = ?');
      args.add(projectPath);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Escape LIKE wildcards in the search query
      final escaped = searchQuery
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      where.add("text LIKE ? ESCAPE '\\'");
      args.add('%$escaped%');
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final orderBy = switch (sort) {
      PromptSortOrder.recency => 'last_used_at DESC',
      PromptSortOrder.frequency => 'use_count DESC, last_used_at DESC',
      PromptSortOrder.favoritesFirst => 'is_favorite DESC, last_used_at DESC',
    };

    final rows = await db.rawQuery(
      'SELECT * FROM prompt_history $whereClause ORDER BY $orderBy LIMIT ?',
      [...args, limit],
    );

    return rows.map(PromptHistoryEntry.fromMap).toList();
  }

  /// Get distinct project paths that have prompt history.
  Future<List<String>> getProjectPaths() async {
    final db = await _db;
    if (db == null) return const [];

    final rows = await db.rawQuery(
      "SELECT DISTINCT project_path FROM prompt_history WHERE project_path != '' ORDER BY project_path",
    );

    return rows.map((r) => r['project_path'] as String).toList();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Toggle the favorite status of a prompt. Returns the new favorite state.
  Future<bool> toggleFavorite(int id) async {
    final db = await _db;
    if (db == null) return false;

    final rows = await db.query(
      'prompt_history',
      columns: ['is_favorite'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (rows.isEmpty) return false;

    final current = (rows.first['is_favorite'] as int) == 1;
    final newValue = current ? 0 : 1;

    await db.update(
      'prompt_history',
      {'is_favorite': newValue},
      where: 'id = ?',
      whereArgs: [id],
    );

    return newValue == 1;
  }

  /// Delete a prompt history entry.
  Future<void> delete(int id) async {
    final db = await _db;
    if (db == null) return;

    await db.delete('prompt_history', where: 'id = ?', whereArgs: [id]);
  }
}
