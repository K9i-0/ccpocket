import 'dart:async';

class ArchiveRequestTracker {
  final Duration timeout;
  final void Function(String sessionId) onTimeout;
  final Map<String, Timer> _timers = {};

  ArchiveRequestTracker({required this.timeout, required this.onTimeout});

  Set<String> get pendingSessionIds => Set.unmodifiable(_timers.keys);

  bool contains(String sessionId) => _timers.containsKey(sessionId);

  void start(String sessionId) {
    _timers.remove(sessionId)?.cancel();
    _timers[sessionId] = Timer(timeout, () {
      if (_timers.remove(sessionId) == null) return;
      onTimeout(sessionId);
    });
  }

  bool complete(String sessionId) {
    final timer = _timers.remove(sessionId);
    timer?.cancel();
    return timer != null;
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
