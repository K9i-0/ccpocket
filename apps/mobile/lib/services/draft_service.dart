import 'package:shared_preferences/shared_preferences.dart';

/// Persists unsent chat input text per session.
///
/// Uses an in-memory cache for fast reads and writes through to
/// [SharedPreferences] for persistence across app restarts.
class DraftService {
  final SharedPreferences _prefs;
  final Map<String, String> _cache = {};

  static const _prefix = 'draft_v1_';

  DraftService(this._prefs) {
    _loadAll();
  }

  /// Load all persisted drafts into the memory cache.
  void _loadAll() {
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final sessionId = key.substring(_prefix.length);
        final value = _prefs.getString(key);
        if (value != null && value.isNotEmpty) {
          _cache[sessionId] = value;
        }
      }
    }
  }

  /// Save a draft for the given session.
  ///
  /// If [text] is empty the draft is deleted instead.
  void saveDraft(String sessionId, String text) {
    if (text.isEmpty) {
      deleteDraft(sessionId);
      return;
    }
    _cache[sessionId] = text;
    _prefs.setString('$_prefix$sessionId', text);
  }

  /// Retrieve the draft for [sessionId], or `null` if none exists.
  String? getDraft(String sessionId) => _cache[sessionId];

  /// Remove the draft for [sessionId] (e.g. after a successful send).
  void deleteDraft(String sessionId) {
    _cache.remove(sessionId);
    _prefs.remove('$_prefix$sessionId');
  }

  /// Migrate a draft from [oldId] (e.g. `pending_*`) to [newId].
  ///
  /// This is called when the Bridge Server assigns a real session ID.
  void migrateDraft(String oldId, String newId) {
    final text = _cache[oldId];
    if (text == null) return;
    _cache[newId] = text;
    _prefs.setString('$_prefix$newId', text);
    deleteDraft(oldId);
  }

  /// All cached drafts keyed by session ID.
  Map<String, String> get allDrafts => Map.unmodifiable(_cache);
}
