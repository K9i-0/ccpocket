import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'codex_profile_by_project_v1';

/// Persists the selected Codex profile for each project.
class CodexProjectProfileStore {
  const CodexProjectProfileStore();

  Future<String?> load(String projectPath, {String? projectId}) async {
    final normalizedPath = projectPath.trim();
    final key = _key(normalizedPath, projectId);
    if (key == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final profiles = _loadAll(prefs);
    return profiles[key] ??
        (projectId?.trim().isNotEmpty == true
            ? profiles[normalizedPath]
            : null);
  }

  Future<void> save(
    String projectPath,
    String? profile, {
    String? projectId,
  }) async {
    final normalizedPath = projectPath.trim();
    final key = _key(normalizedPath, projectId);
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();
    final profiles = _loadAll(prefs);
    if (profile == null || profile.isEmpty) {
      profiles.remove(key);
    } else {
      profiles[key] = profile;
    }
    await prefs.setString(_storageKey, jsonEncode(profiles));
  }

  String? _key(String normalizedPath, String? projectId) {
    final normalizedId = projectId?.trim();
    if (normalizedId != null && normalizedId.isNotEmpty) {
      return 'project:$normalizedId';
    }
    return normalizedPath.isEmpty ? null : normalizedPath;
  }

  Map<String, String> _loadAll(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Map.fromEntries(
        json.entries
            .where((entry) {
              final value = entry.value;
              return value is String && value.isNotEmpty;
            })
            .map((entry) => MapEntry(entry.key, entry.value as String)),
      );
    } catch (_) {
      return {};
    }
  }
}
