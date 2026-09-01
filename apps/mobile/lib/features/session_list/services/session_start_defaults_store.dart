import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/messages.dart';
import '../../../widgets/new_session_sheet.dart';

const _legacyKey = 'session_start_defaults_v1';
const _lastProviderKey = 'session_start_defaults_last_provider_v1';
const _claudeKey = 'session_start_defaults_claude_v1';
const _codexKey = 'session_start_defaults_codex_v1';

/// Owns persistence and one-time migration of new-session defaults.
class SessionStartDefaultsStore {
  const SessionStartDefaultsStore();

  Future<NewSessionParams?> loadFor(Provider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await _removeObsoleteProjectlessDefaults(prefs);
    final scoped = _loadScoped(prefs, provider);
    if (scoped != null) return scoped;

    final legacy = _decode(prefs.getString(_legacyKey));
    if (legacy?.provider != provider) return null;
    await _migrateLegacy(prefs, legacy!);
    return legacy;
  }

  Future<NewSessionParams?> loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    await _removeObsoleteProjectlessDefaults(prefs);
    final lastProvider = _providerFromRaw(prefs.getString(_lastProviderKey));
    if (lastProvider != null) {
      final latest = _loadScoped(prefs, lastProvider);
      if (latest != null) return latest;
    }

    final legacy = _decode(prefs.getString(_legacyKey));
    if (legacy != null) {
      await _migrateLegacy(prefs, legacy);
      return legacy;
    }

    return _loadScoped(prefs, Provider.codex) ??
        _loadScoped(prefs, Provider.claude);
  }

  Future<void> save(NewSessionParams params) async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = _decode(prefs.getString(_legacyKey));
    var preservedLegacy = true;
    if (legacy != null &&
        legacy.provider != params.provider &&
        _loadScoped(prefs, legacy.provider) == null) {
      preservedLegacy = await _saveScoped(prefs, legacy);
    }

    final savedDefaults = await _saveScoped(prefs, params);
    final savedSelection = await _saveSelection(prefs, params.provider);
    if (preservedLegacy && savedDefaults && savedSelection) {
      await prefs.remove(_legacyKey);
    }
  }

  NewSessionParams? _loadScoped(SharedPreferences prefs, Provider provider) {
    final defaults = _decode(prefs.getString(_keyFor(provider)));
    return defaults?.provider == provider ? defaults : null;
  }

  NewSessionParams? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return sessionStartDefaultsFromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _migrateLegacy(
    SharedPreferences prefs,
    NewSessionParams params,
  ) async {
    final savedDefaults = await _saveScoped(prefs, params);
    if (!savedDefaults) return;

    final selectedProvider = _providerFromRaw(
      prefs.getString(_lastProviderKey),
    );
    final hasUsableSelection =
        selectedProvider != null &&
        _loadScoped(prefs, selectedProvider) != null;
    final savedSelection =
        hasUsableSelection || await _saveSelection(prefs, params.provider);
    if (savedSelection) {
      await prefs.remove(_legacyKey);
    }
  }

  Future<bool> _saveScoped(SharedPreferences prefs, NewSessionParams params) {
    return prefs.setString(
      _keyFor(params.provider),
      jsonEncode(sessionStartDefaultsToJson(params)),
    );
  }

  Future<bool> _saveSelection(SharedPreferences prefs, Provider provider) {
    return prefs.setString(_lastProviderKey, provider.value);
  }

  Future<void> _removeObsoleteProjectlessDefaults(
    SharedPreferences prefs,
  ) async {
    for (final key in [_legacyKey, _claudeKey, _codexKey]) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (json['workspaceKind'] == 'projectless') {
          await prefs.remove(key);
        }
      } catch (_) {
        // Existing decode behavior handles corrupt values as unusable defaults.
      }
    }
  }

  String _keyFor(Provider provider) => switch (provider) {
    Provider.claude => _claudeKey,
    Provider.codex => _codexKey,
  };

  Provider? _providerFromRaw(String? raw) => switch (raw) {
    'claude' => Provider.claude,
    'codex' => Provider.codex,
    _ => null,
  };
}
