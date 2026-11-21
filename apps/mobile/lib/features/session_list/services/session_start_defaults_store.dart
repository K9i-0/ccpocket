import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/messages.dart';
import '../../../services/shared_state_adapters.dart';
import '../../../services/shared_state_sync.dart';
import '../../../widgets/new_session_sheet.dart';

const _legacyKey = 'session_start_defaults_v1';
const _lastProviderKey = 'session_start_defaults_last_provider_v1';
const _claudeKey = 'session_start_defaults_claude_v1';
const _codexKey = 'session_start_defaults_codex_v1';
const _antigravityKey = 'session_start_defaults_antigravity_v1';

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

    final savedDefaults = await _saveScoped(
      prefs,
      _preserveUnchangedCodexModel(prefs, params),
      share: true,
    );
    final savedSelection = await _saveSelection(
      prefs,
      params.provider,
      share: true,
    );
    if (preservedLegacy && savedDefaults && savedSelection) {
      await prefs.remove(_legacyKey);
    }
  }

  /// Keeps the saved Codex model unless the user picked one in the sheet.
  ///
  /// The sheet falls back to the first catalog model when the saved model is
  /// missing from the catalog it received (for example the Bridge's fallback
  /// catalog right after a restart). That fallback must not replace the
  /// user's preference.
  NewSessionParams _preserveUnchangedCodexModel(
    SharedPreferences prefs,
    NewSessionParams params,
  ) {
    if (params.provider != Provider.codex || params.codexModelOverridden) {
      return params;
    }
    final savedModel = _loadScoped(prefs, Provider.codex)?.model;
    if (savedModel == null || savedModel.isEmpty) return params;
    return params.copyWith(model: savedModel);
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

  /// [share] is false for the one-time move of old local data, which is
  /// offered to the Bridge by `SessionStartDefaultsAdapter` instead.
  Future<bool> _saveScoped(
    SharedPreferences prefs,
    NewSessionParams params, {
    bool share = false,
  }) {
    final json = sessionStartDefaultsToJson(params);
    if (share) {
      SharedStateSync.instance?.set(
        SharedStateKeys.sessionStartDefaults(params.provider.value),
        json,
      );
    }
    return prefs.setString(_keyFor(params.provider), jsonEncode(json));
  }

  Future<bool> _saveSelection(
    SharedPreferences prefs,
    Provider provider, {
    bool share = false,
  }) {
    if (share) {
      SharedStateSync.instance?.set(
        SharedStateKeys.sessionStartLastProvider,
        provider.value,
      );
    }
    return prefs.setString(_lastProviderKey, provider.value);
  }

  Future<void> _removeObsoleteProjectlessDefaults(
    SharedPreferences prefs,
  ) async {
    for (final key in [_legacyKey, _claudeKey, _codexKey, _antigravityKey]) {
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
    Provider.antigravity => _antigravityKey,
  };

  Provider? _providerFromRaw(String? raw) => Provider.fromValue(raw);
}
