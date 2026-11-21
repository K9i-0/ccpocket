import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/messages.dart';
import '../services/shared_state_adapters.dart';
import '../services/shared_state_sync.dart';

/// Tracks which running sessions have new activity the user hasn't seen yet.
///
/// A session is "unseen" when its [SessionInfo.lastActivityAt] is more recent
/// than the timestamp stored in [SharedPreferences] for that session ID.
/// Tapping into a session calls [markSeen], which persists the current time.
///
/// Seen-at timestamps are shared through the Bridge (docs/shared-state.md),
/// so a session read on one device is not unseen on another. The later
/// timestamp always wins. Dropping records of ended sessions stays local.
class UnseenSessionsCubit extends Cubit<Set<String>> {
  static const _prefsKey = 'unseen_sessions_seen_at';
  static const _seenBuffer = Duration(days: 1);

  /// sessionId → last-seen ISO-8601 timestamp.
  Map<String, String> _seenAt = {};
  final Set<String> _pendingInitialSeen = <String>{};
  final Map<String, String> _lastActivityAt = <String, String>{};

  final SharedStateSync? _sync;
  late final SharedStateAdapter _adapter = _SeenAtAdapter(this);

  UnseenSessionsCubit({SharedStateSync? sync})
    : _sync = sync ?? SharedStateSync.instance,
      super(const {}) {
    _loaded = _loadSeenAt();
    _sync?.register(_adapter);
  }

  late final Future<void> _loaded;

  @override
  Future<void> close() {
    _sync?.unregister(_adapter);
    return super.close();
  }

  void _share(String sessionId) {
    final seenAt = _seenAt[sessionId];
    if (seenAt == null) return;
    _sync?.set(SharedStateKeys.seenAt(sessionId), seenAt, max: true);
  }

  /// Another device saw [sessionId] up to [seenAt].
  void _applySharedSeenAt(String sessionId, String seenAt) {
    final current = _seenAt[sessionId];
    if (current != null && current.compareTo(seenAt) >= 0) return;
    _seenAt[sessionId] = seenAt;
    _saveSeenAt();
    final lastActivity = _lastActivityAt[sessionId];
    if (isClosed || !state.contains(sessionId)) return;
    if (lastActivity != null && lastActivity.compareTo(seenAt) > 0) return;
    emit(Set<String>.from(state)..remove(sessionId));
  }

  // ------------------------------------------------------------------
  // Persistence
  // ------------------------------------------------------------------

  Future<void> _loadSeenAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _seenAt = decoded.map((k, v) => MapEntry(k, v as String));
    }
  }

  Future<void> _saveSeenAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(_seenAt));
  }

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  /// Called whenever the active session list updates.
  /// Compares each session's [lastActivityAt] with the stored seen-at
  /// timestamp to determine unseen state.
  void updateSessions(List<SessionInfo> sessions) {
    final unseen = <String>{};

    for (final session in sessions) {
      if (session.lastActivityAt.isNotEmpty) {
        _lastActivityAt[session.id] = session.lastActivityAt;
      }

      // Only Ready (idle) sessions can be "unseen".
      // Working / NeedsYou sessions have their own visual indicators.
      if (session.status != 'idle') continue;

      final lastActivity = session.lastActivityAt;
      if (lastActivity.isEmpty) continue;

      if (_pendingInitialSeen.remove(session.id)) {
        _seenAt[session.id] = _bufferedTimestamp(lastActivity);
        _share(session.id);
      }

      final seenAt = _seenAt[session.id];
      if (seenAt == null || lastActivity.compareTo(seenAt) > 0) {
        unseen.add(session.id);
      }
    }

    // An empty list is published on disconnect / protocol incompatibility,
    // not because every session ended. Keep seen-at records so sessions are
    // not all marked unseen again after reconnecting.
    if (sessions.isEmpty) {
      emit(unseen);
      return;
    }

    // Clean up stale entries: remove IDs not in the current running list.
    final currentIds = sessions.map((s) => s.id).toSet();
    _seenAt.removeWhere((id, _) => !currentIds.contains(id));
    _lastActivityAt.removeWhere((id, _) => !currentIds.contains(id));
    _pendingInitialSeen.removeWhere((id) => !currentIds.contains(id));

    emit(unseen);
  }

  /// Mark a session as seen (user tapped into it).
  ///
  /// Uses a timestamp far in the future (+1 day) so that activity generated
  /// immediately after the user sends a message (before the session transitions
  /// to "working") does not re-trigger the unseen indicator.
  void markSeen(String sessionId) {
    final lastActivityAt = _lastActivityAt[sessionId];
    if (lastActivityAt != null && lastActivityAt.isNotEmpty) {
      _seenAt[sessionId] = _bufferedTimestamp(lastActivityAt);
      _pendingInitialSeen.remove(sessionId);
      _share(sessionId);
    } else {
      // A newly created session can be marked seen before it first appears
      // in the list. Suppress unseen exactly once when that first activity
      // timestamp arrives.
      _pendingInitialSeen.add(sessionId);
    }
    _saveSeenAt();

    final next = Set<String>.from(state)..remove(sessionId);
    emit(next);
  }

  /// Whether [sessionId] has unseen activity.
  bool isUnseen(String sessionId) => state.contains(sessionId);

  String _bufferedTimestamp(String timestamp) {
    final parsed = DateTime.tryParse(timestamp);
    if (parsed == null) return timestamp;
    return parsed.toUtc().add(_seenBuffer).toIso8601String();
  }
}

class _SeenAtAdapter extends SharedStateAdapter {
  final UnseenSessionsCubit _cubit;
  _SeenAtAdapter(this._cubit);

  @override
  bool owns(String key) => key.startsWith(SharedStateKeys.seenAtPrefix);

  /// Session IDs do not outlive a Bridge run, so old local records are not
  /// worth offering to a Bridge.
  @override
  bool get seedable => false;

  @override
  Future<Map<String, Object>> readLocal() async {
    await _cubit._loaded;
    return {
      for (final entry in _cubit._seenAt.entries)
        SharedStateKeys.seenAt(entry.key): entry.value,
    };
  }

  @override
  Future<void> applyRemote(String key, Object? value) async {
    // An absent key only means the Bridge dropped an old record.
    if (value is! String) return;
    await _cubit._loaded;
    _cubit._applySharedSeenAt(
      key.substring(SharedStateKeys.seenAtPrefix.length),
      value,
    );
  }
}
