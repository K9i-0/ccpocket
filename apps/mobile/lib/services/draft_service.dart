import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists unsent chat input text and image attachments per session.
///
/// Uses an in-memory cache for fast reads and writes through to
/// [SharedPreferences] for persistence across app restarts.
class DraftService {
  final SharedPreferences _prefs;
  final Map<String, String> _cache = {};
  final Map<String, ({Uint8List bytes, String mimeType})> _imageCache = {};

  static const _prefix = 'draft_v1_';
  static const _imagePrefix = 'draft_image_v1_';

  DraftService(this._prefs) {
    _loadAll();
  }

  /// Load all persisted drafts into the memory cache.
  void _loadAll() {
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_imagePrefix)) {
        final sessionId = key.substring(_imagePrefix.length);
        final value = _prefs.getString(key);
        if (value != null && value.isNotEmpty) {
          final decoded = _decodeImageDraft(value);
          if (decoded != null) {
            _imageCache[sessionId] = decoded;
          }
        }
      } else if (key.startsWith(_prefix)) {
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

  // ---------------------------------------------------------------------------
  // Image draft persistence
  // ---------------------------------------------------------------------------

  /// Save an image draft for the given session.
  ///
  /// Stores the image bytes (Base64-encoded) and MIME type in
  /// [SharedPreferences] so the attachment survives navigation.
  void saveImageDraft(String sessionId, Uint8List bytes, String mimeType) {
    _imageCache[sessionId] = (bytes: bytes, mimeType: mimeType);
    final encoded = '${base64Encode(bytes)}|$mimeType';
    _prefs.setString('$_imagePrefix$sessionId', encoded);
  }

  /// Retrieve the image draft for [sessionId], or `null` if none exists.
  ({Uint8List bytes, String mimeType})? getImageDraft(String sessionId) =>
      _imageCache[sessionId];

  /// Remove the image draft for [sessionId] (e.g. after sending or clearing).
  void deleteImageDraft(String sessionId) {
    _imageCache.remove(sessionId);
    _prefs.remove('$_imagePrefix$sessionId');
  }

  /// Migrate an image draft from [oldId] to [newId].
  void migrateImageDraft(String oldId, String newId) {
    final data = _imageCache[oldId];
    if (data == null) return;
    _imageCache[newId] = data;
    final encoded = '${base64Encode(data.bytes)}|${data.mimeType}';
    _prefs.setString('$_imagePrefix$newId', encoded);
    deleteImageDraft(oldId);
  }

  /// Decode stored image draft string (`base64|mimeType`).
  static ({Uint8List bytes, String mimeType})? _decodeImageDraft(
    String value,
  ) {
    final sep = value.lastIndexOf('|');
    if (sep < 0) return null;
    try {
      final bytes = base64Decode(value.substring(0, sep));
      final mimeType = value.substring(sep + 1);
      return (bytes: bytes, mimeType: mimeType);
    } catch (_) {
      return null;
    }
  }
}
