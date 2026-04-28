import '../models/messages.dart';

class ExplorerHistorySnapshot {
  const ExplorerHistorySnapshot({
    this.currentPath = '',
    this.recentPeekedFiles = const [],
  });

  final String currentPath;
  final List<String> recentPeekedFiles;
}

class SessionRuntimeSnapshot {
  const SessionRuntimeSnapshot({
    required this.sessionId,
    this.messages = const [],
    this.historySeq = 0,
    this.explorerHistory = const ExplorerHistorySnapshot(),
  });

  final String sessionId;
  final List<ServerMessage> messages;
  final int historySeq;
  final ExplorerHistorySnapshot explorerHistory;
}

class SessionRuntimeState {
  SessionRuntimeState({required this.sessionId});

  final String sessionId;
  final List<ServerMessage> _messages = [];
  int historySeq = 0;
  ExplorerHistorySnapshot explorerHistory = const ExplorerHistorySnapshot();

  List<ServerMessage> get messages => List.unmodifiable(_messages);
}

class SessionRuntimeStore {
  SessionRuntimeStore({this.maxMessagesPerSession = 200});

  final int maxMessagesPerSession;
  final Map<String, SessionRuntimeState> _sessions = {};

  SessionRuntimeSnapshot snapshot(String sessionId) {
    final state = _sessions[sessionId];
    if (state == null) {
      return SessionRuntimeSnapshot(sessionId: sessionId);
    }
    return SessionRuntimeSnapshot(
      sessionId: sessionId,
      messages: state.messages,
      historySeq: state.historySeq,
      explorerHistory: state.explorerHistory,
    );
  }

  List<ServerMessage> messages(String sessionId) =>
      snapshot(sessionId).messages;

  int latestHistorySeq(String sessionId) => snapshot(sessionId).historySeq;

  void applyServerMessage(
    String sessionId,
    ServerMessage message, {
    int? historySeq,
  }) {
    if (_shouldIgnore(message)) return;
    final state = _stateFor(sessionId);
    if (message is HistoryMessage) {
      state._messages
        ..clear()
        ..addAll(message.messages.where((m) => !_shouldIgnore(m)));
      state.historySeq = 0;
      _trim(state);
      return;
    }
    if (message is HistorySnapshotMessage) {
      state._messages
        ..clear()
        ..addAll(
          message.entries
              .map((entry) => entry.message)
              .where((m) => !_shouldIgnore(m)),
        );
      state.historySeq = message.toSeq;
      _trim(state);
      return;
    }
    if (message is HistoryDeltaMessage) {
      if (state.historySeq == 0 &&
          state._messages.isNotEmpty &&
          message.fromSeq <= 1) {
        state._messages.clear();
      }
      state._messages.addAll(
        message.entries
            .map((entry) => entry.message)
            .where((m) => !_shouldIgnore(m)),
      );
      state.historySeq = message.toSeq;
      _trim(state);
      return;
    }

    state._messages.add(message);
    if (historySeq != null && historySeq > state.historySeq) {
      state.historySeq = historySeq;
    }
    _trim(state);
  }

  ExplorerHistorySnapshot getExplorerHistory(String sessionId) =>
      snapshot(sessionId).explorerHistory;

  void setExplorerHistory(
    String sessionId, {
    required String currentPath,
    required List<String> recentPeekedFiles,
  }) {
    final normalizedPath = currentPath.trim();
    final normalizedFiles = recentPeekedFiles
        .map((file) => file.trim())
        .where((file) => file.isNotEmpty)
        .take(10)
        .toList();
    if (normalizedPath.isEmpty && normalizedFiles.isEmpty) {
      final state = _sessions[sessionId];
      if (state == null) return;
      state.explorerHistory = const ExplorerHistorySnapshot();
      _removeIfEmpty(state);
      return;
    }
    _stateFor(sessionId).explorerHistory = ExplorerHistorySnapshot(
      currentPath: normalizedPath,
      recentPeekedFiles: normalizedFiles,
    );
  }

  void migrateSession(String fromSessionId, String toSessionId) {
    if (fromSessionId == toSessionId) return;
    final source = _sessions.remove(fromSessionId);
    if (source == null) return;
    final target = _stateFor(toSessionId);
    if (source._messages.isNotEmpty) {
      target._messages
        ..clear()
        ..addAll(source._messages);
    }
    target.historySeq = source.historySeq;
    target.explorerHistory = source.explorerHistory;
    _trim(target);
  }

  void clearSession(String sessionId) {
    _sessions.remove(sessionId);
  }

  void clearAll() {
    _sessions.clear();
  }

  SessionRuntimeState _stateFor(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => SessionRuntimeState(sessionId: sessionId),
    );
  }

  bool _shouldIgnore(ServerMessage message) {
    return message is PastHistoryMessage ||
        message is StreamDeltaMessage ||
        message is ThinkingDeltaMessage;
  }

  void _trim(SessionRuntimeState state) {
    if (maxMessagesPerSession <= 0) {
      state._messages.clear();
      return;
    }
    final overflow = state._messages.length - maxMessagesPerSession;
    if (overflow > 0) {
      state._messages.removeRange(0, overflow);
    }
  }

  void _removeIfEmpty(SessionRuntimeState state) {
    if (state._messages.isEmpty &&
        state.explorerHistory.currentPath.isEmpty &&
        state.explorerHistory.recentPeekedFiles.isEmpty) {
      _sessions.remove(state.sessionId);
    }
  }
}
