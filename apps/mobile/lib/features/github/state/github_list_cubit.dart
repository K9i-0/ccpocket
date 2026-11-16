import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import 'github_list_state.dart';

/// Open pull requests and issues of one project, plus the triage selection.
///
/// Every request carries a `requestId`. A result is applied only when it
/// answers the latest request of its tab and echoes this project's path, so a
/// late or foreign response can never overwrite the list
/// (`docs/request-correlation.md`).
class GitHubListCubit extends Cubit<GitHubListState> {
  static const requestTimeout = Duration(seconds: 30);

  final BridgeService _bridge;
  final String projectPath;
  final Duration _timeout;
  final _pending = <GitHubItemKind, _PendingList>{};
  late final StreamSubscription<ServerMessage> _sub;
  late final StreamSubscription<BridgeConnectionState> _connectionSub;

  GitHubListCubit({
    required BridgeService bridge,
    required this.projectPath,
    Duration timeout = requestTimeout,
  }) : _bridge = bridge,
       _timeout = timeout,
       super(const GitHubListState()) {
    _sub = _bridge.messages.listen(_onMessage);
    _connectionSub = _bridge.connectionStatus.listen(_onConnection);
  }

  static const _disconnected = GitHubFailure(
    kind: GitHubFailureKind.disconnected,
  );

  /// An answer to a request sent on a lost transport never arrives, and the
  /// Bridge does not replay these reads, so pending requests fail at once and
  /// the user retries when connected again.
  void _onConnection(BridgeConnectionState status) {
    if (status == BridgeConnectionState.connected ||
        status == BridgeConnectionState.connecting) {
      return;
    }
    for (final entry in _pending.entries.toList()) {
      _fail(entry.key, entry.value.requestId, _disconnected);
    }
  }

  /// Loads [kind] unless it is already loaded or loading.
  void ensureLoaded(GitHubItemKind kind) {
    final tab = state.tab(kind);
    if (tab.loaded || tab.loading) return;
    unawaited(refresh(kind));
  }

  /// Reloads [kind]. Completes when the request is answered, fails, or is
  /// replaced by a newer one.
  Future<void> refresh(GitHubItemKind kind) {
    _pending.remove(kind)?.dispose();
    final requestId = _bridge.requestGitHubList(
      projectPath: projectPath,
      kind: kind,
    );
    final pending = _PendingList(
      requestId,
      Timer(_timeout, () => _fail(kind, requestId, _timeoutFailure)),
    );
    _pending[kind] = pending;
    _emitTab(kind, state.tab(kind).copyWith(loading: true, failure: null));
    if (!_bridge.isConnected) _fail(kind, requestId, _disconnected);
    return pending.done.future;
  }

  static const _timeoutFailure = GitHubFailure(kind: GitHubFailureKind.timeout);

  void _onMessage(ServerMessage message) {
    switch (message) {
      case GitHubListResultMessage():
        _onResult(message);
      case ErrorMessage(
        errorCode: 'unsupported_message',
        message: 'github_list',
      ):
        // An older Bridge names the message type and echoes no requestId, so
        // every list request still waiting was rejected.
        for (final entry in _pending.entries.toList()) {
          _fail(
            entry.key,
            entry.value.requestId,
            const GitHubFailure(kind: GitHubFailureKind.unsupported),
          );
        }
      case ErrorMessage(:final requestId?, message: final text):
        for (final entry in _pending.entries.toList()) {
          if (entry.value.requestId != requestId) continue;
          _fail(
            entry.key,
            requestId,
            GitHubFailure(kind: GitHubFailureKind.failed, message: text),
          );
        }
      default:
        break;
    }
  }

  void _onResult(GitHubListResultMessage message) {
    final kind = message.kind;
    final pending = _pending[kind];
    if (pending == null ||
        message.requestId != pending.requestId ||
        message.projectPath != projectPath) {
      return;
    }
    final error = message.error;
    if (error != null) {
      _fail(kind, pending.requestId, GitHubFailure.fromError(error));
      return;
    }
    _pending.remove(kind)?.dispose();
    final previous = state.tab(kind).items.map((item) => item.number).toSet();
    final current = message.items.map((item) => item.number).toSet();
    final closed = previous.difference(current);
    final label = state.filters.label;
    final next = _withTab(
      kind,
      GitHubTabState(loaded: true, items: message.items),
    );
    emit(
      next.copyWith(
        repository: message.repository ?? state.repository,
        // Items that left the open list can no longer be triaged from here.
        selected: closed.isEmpty
            ? state.selected
            : state.selected.difference(closed),
        filters: label != null && !_labelInUse(next, label)
            ? state.filters.copyWith(label: null)
            : state.filters,
      ),
    );
  }

  bool _labelInUse(GitHubListState next, String label) =>
      GitHubItemKind.values.any(
        (kind) =>
            next.tab(kind).items.any((item) => item.labels.contains(label)),
      );

  void _fail(GitHubItemKind kind, String requestId, GitHubFailure failure) {
    final pending = _pending[kind];
    if (pending == null || pending.requestId != requestId) return;
    _pending.remove(kind)?.dispose();
    if (isClosed) return;
    // Keep the last good list visible behind the error when there is one.
    _emitTab(kind, state.tab(kind).copyWith(loading: false, failure: failure));
  }

  GitHubListState _withTab(GitHubItemKind kind, GitHubTabState tab) =>
      switch (kind) {
        GitHubItemKind.pr => state.copyWith(prs: tab),
        GitHubItemKind.issue => state.copyWith(issues: tab),
      };

  void _emitTab(GitHubItemKind kind, GitHubTabState tab) =>
      emit(_withTab(kind, tab));

  // ---- Filters ----

  void setHideDrafts(bool value) =>
      emit(state.copyWith(filters: state.filters.copyWith(hideDrafts: value)));

  void setDependabotOnly(bool value) => emit(
    state.copyWith(filters: state.filters.copyWith(dependabotOnly: value)),
  );

  void setLabel(String? label) =>
      emit(state.copyWith(filters: state.filters.copyWith(label: label)));

  // ---- Selection ----

  /// Enters multi-select with [number] selected (long press on a row).
  void startSelection(int number) => emit(
    state.copyWith(selectionMode: true, selected: {...state.selected, number}),
  );

  /// Toggles one item. Drafts can be picked here even though
  /// [selectAllVisible] skips them.
  void toggleSelected(int number) {
    final selected = {...state.selected};
    if (!selected.remove(number)) selected.add(number);
    emit(state.copyWith(selectionMode: true, selected: selected));
  }

  /// Adds every visible item of [kind] except drafts, which are not ready for
  /// triage unless picked on purpose.
  void selectAllVisible(GitHubItemKind kind) => emit(
    state.copyWith(
      selectionMode: true,
      selected: {
        ...state.selected,
        for (final item in state.visibleItems(kind))
          if (!item.isDraft) item.number,
      },
    ),
  );

  void clearSelection() =>
      emit(state.copyWith(selectionMode: false, selected: const {}));

  @override
  Future<void> close() async {
    await _sub.cancel();
    await _connectionSub.cancel();
    for (final pending in _pending.values.toList()) {
      pending.dispose();
    }
    _pending.clear();
    return super.close();
  }
}

class _PendingList {
  final String requestId;
  final Timer timer;
  final done = Completer<void>();

  _PendingList(this.requestId, this.timer);

  void dispose() {
    timer.cancel();
    if (!done.isCompleted) done.complete();
  }
}
