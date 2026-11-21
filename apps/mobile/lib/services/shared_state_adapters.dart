import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/session_list/services/session_start_defaults_store.dart';
import 'bridge_service.dart';
import 'shared_state_sync.dart';

/// Shared keys (docs/shared-state.md). `name/id` keys are per session or
/// project; the Bridge keeps a limited number of them per name.
abstract final class SharedStateKeys {
  static const claudeSessionSettingsPrefix = 'claude_session_settings/';
  static const codexProfilePrefix = 'codex_profile/';
  static const seenAtPrefix = 'seen_at/';
  static const writableRootHistory = 'writable_root_history';
  static const newProjectParent = 'new_project_parent';
  static const sessionStartDefaultsPrefix = 'session_start_defaults.';
  static const sessionStartLastProvider =
      'session_start_defaults.last_provider';
  static const autoRenameClaude = 'auto_rename.claude';
  static const autoRenameCodex = 'auto_rename.codex';

  static String claudeSessionSettings(String sessionId) =>
      '$claudeSessionSettingsPrefix$sessionId';
  static String codexProfile(String projectKey) =>
      '$codexProfilePrefix$projectKey';
  static String seenAt(String sessionId) => '$seenAtPrefix$sessionId';
  static String sessionStartDefaults(String provider) =>
      '$sessionStartDefaultsPrefix$provider';
}

/// SharedPreferences keys of the local copies.
abstract final class SharedStatePrefs {
  static const claudeSessionSettingsPrefix = 'claude_session_settings_';
  static const codexProfiles = 'codex_profile_by_project_v1';
  static const writableRootHistory =
      'new_session_additional_writable_root_history';
  static const sessionStartLastProvider =
      'session_start_defaults_last_provider_v1';
  static const sessionStartProviders = ['claude', 'codex', 'antigravity'];

  static String sessionStartDefaults(String provider) =>
      'session_start_defaults_${provider}_v1';

  /// The parent directory is a path on the Bridge's machine, so the local
  /// copy is kept per Bridge.
  static String newProjectParent(String? bridgeUrl) =>
      'new_project_parent_${bridgeUrl ?? "default"}';
}

Map<String, dynamic>? _decodeObject(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Per-session Claude settings, used when a session is resumed.
class ClaudeSessionSettingsAdapter extends SharedStateAdapter {
  final SharedPreferences _prefs;
  ClaudeSessionSettingsAdapter(this._prefs);

  @override
  bool owns(String key) =>
      key.startsWith(SharedStateKeys.claudeSessionSettingsPrefix);

  @override
  Future<Map<String, Object>> readLocal() async {
    const prefix = SharedStatePrefs.claudeSessionSettingsPrefix;
    final result = <String, Object>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final settings = _decodeObject(_prefs.getString(key));
      if (settings == null) continue;
      result[SharedStateKeys.claudeSessionSettings(
            key.substring(prefix.length),
          )] =
          settings;
    }
    return result;
  }

  @override
  Future<void> applyRemote(String key, Object? value) async {
    final sessionId = key.substring(
      SharedStateKeys.claudeSessionSettingsPrefix.length,
    );
    final prefsKey =
        '${SharedStatePrefs.claudeSessionSettingsPrefix}$sessionId';
    if (value is Map) {
      await _prefs.setString(prefsKey, jsonEncode(value));
    } else {
      await _prefs.remove(prefsKey);
    }
  }
}

/// The Codex profile chosen for each project. An empty string is a cleared
/// choice; it stays on the Bridge so that an older copy is not offered again.
class CodexProfileAdapter extends SharedStateAdapter {
  final SharedPreferences _prefs;
  CodexProfileAdapter(this._prefs);

  Map<String, dynamic> _all() =>
      _decodeObject(_prefs.getString(SharedStatePrefs.codexProfiles)) ?? {};

  @override
  bool owns(String key) => key.startsWith(SharedStateKeys.codexProfilePrefix);

  @override
  Future<Map<String, Object>> readLocal() async => {
    for (final entry in _all().entries)
      if (entry.value is String && (entry.value as String).isNotEmpty)
        SharedStateKeys.codexProfile(entry.key): entry.value as String,
  };

  @override
  Future<void> applyRemote(String key, Object? value) async {
    final projectKey = key.substring(SharedStateKeys.codexProfilePrefix.length);
    final all = _all();
    if (value is String && value.isNotEmpty) {
      all[projectKey] = value;
    } else if (all.remove(projectKey) == null) {
      return;
    }
    await _prefs.setString(SharedStatePrefs.codexProfiles, jsonEncode(all));
  }
}

/// Recently used additional writable directories of the new-session sheet.
class WritableRootHistoryAdapter extends SharedStateAdapter {
  final SharedPreferences _prefs;
  WritableRootHistoryAdapter(this._prefs);

  @override
  bool owns(String key) => key == SharedStateKeys.writableRootHistory;

  @override
  Future<Map<String, Object>> readLocal() async {
    final history = _prefs.getStringList(SharedStatePrefs.writableRootHistory);
    return {
      if (history != null && history.isNotEmpty)
        SharedStateKeys.writableRootHistory: history,
    };
  }

  @override
  Future<void> applyRemote(String key, Object? value) async {
    if (value is List) {
      await _prefs.setStringList(
        SharedStatePrefs.writableRootHistory,
        value.whereType<String>().toList(),
      );
    } else {
      await _prefs.remove(SharedStatePrefs.writableRootHistory);
    }
  }
}

/// The parent directory last used to create a project.
class NewProjectParentAdapter extends SharedStateAdapter {
  final SharedPreferences _prefs;
  final BridgeService _bridge;
  NewProjectParentAdapter(this._prefs, this._bridge);

  String get _prefsKey => SharedStatePrefs.newProjectParent(_bridge.lastUrl);

  @override
  bool owns(String key) => key == SharedStateKeys.newProjectParent;

  @override
  Future<Map<String, Object>> readLocal() async {
    final parent = _prefs.getString(_prefsKey);
    return {
      if (parent != null && parent.isNotEmpty)
        SharedStateKeys.newProjectParent: parent,
    };
  }

  @override
  Future<void> applyRemote(String key, Object? value) async {
    if (value is String && value.isNotEmpty) {
      await _prefs.setString(_prefsKey, value);
    } else {
      await _prefs.remove(_prefsKey);
    }
  }
}

/// The options the new-session sheet starts with, per provider, and the
/// provider that was used last.
class SessionStartDefaultsAdapter extends SharedStateAdapter {
  final SharedPreferences _prefs;
  SessionStartDefaultsAdapter(this._prefs);

  @override
  bool owns(String key) =>
      key.startsWith(SharedStateKeys.sessionStartDefaultsPrefix);

  @override
  Future<Map<String, Object>> readLocal() async {
    // Moves defaults saved by old app versions to the per-provider keys, so
    // they are offered to the Bridge as well.
    await const SessionStartDefaultsStore().loadInitial();
    final result = <String, Object>{};
    for (final provider in SharedStatePrefs.sessionStartProviders) {
      final defaults = _decodeObject(
        _prefs.getString(SharedStatePrefs.sessionStartDefaults(provider)),
      );
      if (defaults != null) {
        result[SharedStateKeys.sessionStartDefaults(provider)] = defaults;
      }
    }
    final last = _prefs.getString(SharedStatePrefs.sessionStartLastProvider);
    if (last != null && last.isNotEmpty) {
      result[SharedStateKeys.sessionStartLastProvider] = last;
    }
    return result;
  }

  @override
  Future<void> applyRemote(String key, Object? value) async {
    if (key == SharedStateKeys.sessionStartLastProvider) {
      const prefsKey = SharedStatePrefs.sessionStartLastProvider;
      if (value is String && value.isNotEmpty) {
        await _prefs.setString(prefsKey, value);
      } else {
        await _prefs.remove(prefsKey);
      }
      return;
    }
    final provider = key.substring(
      SharedStateKeys.sessionStartDefaultsPrefix.length,
    );
    if (!SharedStatePrefs.sessionStartProviders.contains(provider)) return;
    final prefsKey = SharedStatePrefs.sessionStartDefaults(provider);
    if (value is Map) {
      await _prefs.setString(prefsKey, jsonEncode(value));
    } else {
      await _prefs.remove(prefsKey);
    }
  }
}

/// Registers the adapters whose data lives only in SharedPreferences. The
/// cubits that hold shared data in memory register their own.
void registerPrefsSharedStateAdapters(
  SharedStateSync sync, {
  required SharedPreferences prefs,
  required BridgeService bridge,
}) {
  sync
    ..register(ClaudeSessionSettingsAdapter(prefs))
    ..register(CodexProfileAdapter(prefs))
    ..register(WritableRootHistoryAdapter(prefs))
    ..register(NewProjectParentAdapter(prefs, bridge))
    ..register(SessionStartDefaultsAdapter(prefs));
}
