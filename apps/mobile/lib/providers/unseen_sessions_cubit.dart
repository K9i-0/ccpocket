import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/messages.dart';

/// Tracks which running sessions have new activity the user hasn't seen yet.
///
/// A session is "unseen" when its [SessionInfo.lastActivityAt] is more recent
/// than the timestamp stored in [SharedPreferences] for that session ID.
/// Tapping into a session calls [markSeen], which persists the current time.
class UnseenSessionsCubit extends Cubit<Set<String>> {
  static const _prefsKey = 'unseen_sessions_seen_at';
  static const _seenBuffer = Duration(days: 1);

  /// sessionId → last-seen ISO-8601 timestamp.
  Map<String, String> _seenAt = {};
  final Set<String> _pendingInitialSeen = <String>{};
  final Map<String, String> _lastActivityAt = <String, String>{};

  UnseenSessionsCubit() : super(const {}) {
    _loadSeenAt();
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
      }

      final seenAt = _seenAt[session.id];
      if (seenAt == null || lastActivity.compareTo(seenAt) > 0) {
        unseen.add(session.id);
      }
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
