import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'media_feedback_state.dart';

class MediaFeedbackCubit extends Cubit<MediaFeedbackState> {
  static const _prefix = 'media_feedback_v1_';
  final SharedPreferences _prefs;
  final Map<String, String> _migrations = {};

  MediaFeedbackCubit(this._prefs) : super(const MediaFeedbackState()) {
    final sessions = <String, List<MediaFeedback>>{};
    for (final key in _prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      try {
        final list = jsonDecode(_prefs.getString(key)!) as List;
        sessions[key.substring(_prefix.length)] = list
            .map((e) => MediaFeedback.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // A damaged draft must not prevent the remaining sessions from loading.
      }
    }
    emit(MediaFeedbackState(sessions: sessions));
  }

  String resolveSession(String id) {
    while (_migrations.containsKey(id)) {
      id = _migrations[id]!;
    }
    return id;
  }

  List<MediaFeedback> items(String sessionId) =>
      state.sessions[resolveSession(sessionId)] ?? const [];

  void _save(String sessionId, List<MediaFeedback> entries) {
    final id = resolveSession(sessionId);
    final sessions = {...state.sessions};
    if (entries.isEmpty) {
      sessions.remove(id);
      _prefs.remove('$_prefix$id');
    } else {
      sessions[id] = List.unmodifiable(entries);
      _prefs.setString(
        '$_prefix$id',
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      );
    }
    emit(MediaFeedbackState(sessions: sessions));
  }

  void put(String sessionId, MediaFeedback entry) {
    final entries = [...items(sessionId)];
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (entry.text.trim().isEmpty) {
      if (index >= 0) entries.removeAt(index);
    } else if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
    _save(sessionId, entries);
  }

  void remove(String sessionId, String id) =>
      _save(sessionId, items(sessionId).where((e) => e.id != id).toList());

  /// Only remove the exact revisions accepted by the send pipeline.
  void removeSent(String sessionId, List<MediaFeedback> sent) => _save(
    sessionId,
    items(sessionId).where((e) => !sent.contains(e)).toList(),
  );

  void migrate(String oldId, String newId) {
    oldId = resolveSession(oldId);
    newId = resolveSession(newId);
    if (oldId == newId) return;
    final old = items(oldId);
    final existing = items(newId);
    _save(newId, [
      ...existing,
      ...old.where((e) => !existing.any((v) => v.id == e.id)),
    ]);
    _save(oldId, []);
    _migrations[oldId] = newId;
  }
}
