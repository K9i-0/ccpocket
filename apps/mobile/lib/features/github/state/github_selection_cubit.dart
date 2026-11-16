import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'github_selection_state.dart';

/// Issues and pull requests picked for each session, kept until they are sent
/// or removed (like `MediaFeedbackCubit`).
///
/// The Issues / PRs screen and the cards above the composer both read and
/// change this, so they always agree.
class GitHubSelectionCubit extends Cubit<GitHubSelectionState> {
  static const _prefix = 'github_selection_v1_';
  final SharedPreferences _prefs;
  final Map<String, String> _migrations = {};
  final Set<String> _openRequests = {};

  GitHubSelectionCubit(this._prefs) : super(const GitHubSelectionState()) {
    final sessions = <String, List<GitHubSelectedItem>>{};
    for (final key in _prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      try {
        final list = jsonDecode(_prefs.getString(key)!) as List;
        sessions[key.substring(_prefix.length)] = List.unmodifiable(
          list.map(
            (e) => GitHubSelectedItem.fromJson(e as Map<String, dynamic>),
          ),
        );
      } catch (_) {
        // A damaged entry must not prevent the remaining sessions from loading.
      }
    }
    emit(GitHubSelectionState(sessions: sessions));
  }

  String resolveSession(String id) {
    while (_migrations.containsKey(id)) {
      id = _migrations[id]!;
    }
    return id;
  }

  List<GitHubSelectedItem> items(String sessionId) =>
      state.sessions[resolveSession(sessionId)] ?? const [];

  bool isSelected(String sessionId, String url) =>
      items(sessionId).any((item) => item.url == url);

  void _save(String sessionId, List<GitHubSelectedItem> entries) {
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
    emit(GitHubSelectionState(sessions: sessions));
  }

  /// Selects [item], or deselects it when it is already selected.
  void toggle(String sessionId, GitHubSelectedItem item) =>
      isSelected(sessionId, item.url)
      ? remove(sessionId, item.url)
      : addAll(sessionId, [item]);

  /// Adds [added] after the current selection, skipping what is already there.
  void addAll(String sessionId, Iterable<GitHubSelectedItem> added) {
    final entries = [...items(sessionId)];
    for (final item in added) {
      if (!entries.any((e) => e.url == item.url)) entries.add(item);
    }
    _save(sessionId, entries);
  }

  void remove(String sessionId, String url) =>
      _save(sessionId, items(sessionId).where((e) => e.url != url).toList());

  void clear(String sessionId) => _save(sessionId, const []);

  /// Only removes what the send pipeline accepted; an item picked while the
  /// message was on its way stays for the next one.
  void removeSent(String sessionId, List<GitHubSelectedItem> sent) => _save(
    sessionId,
    items(sessionId).where((e) => !sent.any((s) => s.url == e.url)).toList(),
  );

  void migrate(String oldId, String newId) {
    oldId = resolveSession(oldId);
    newId = resolveSession(newId);
    if (oldId == newId) return;
    final old = items(oldId);
    final existing = items(newId);
    _save(newId, [
      ...existing,
      ...old.where((e) => !existing.any((v) => v.url == e.url)),
    ]);
    _save(oldId, const []);
    _migrations[oldId] = newId;
    if (_openRequests.remove(oldId)) _openRequests.add(newId);
  }

  /// Asks the chat of [sessionId] to open the Issues / PRs screen once it is
  /// ready. Used when a session is started from a project's Issues / PRs
  /// entry; not persisted.
  void requestOpen(String sessionId) =>
      _openRequests.add(resolveSession(sessionId));

  /// Consumes the request made by [requestOpen], if any.
  bool takeOpenRequest(String sessionId) =>
      _openRequests.remove(resolveSession(sessionId));
}
