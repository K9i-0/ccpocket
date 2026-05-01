import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';

class GitStatusEntry {
  static const remoteRefreshTtl = Duration(seconds: 60);

  final String sessionId;
  final String projectPath;
  final bool loading;
  final bool hasUncommittedChanges;
  final int stagedCount;
  final int unstagedCount;
  final int untrackedCount;
  final bool hasRemoteChanges;
  final int commitsAhead;
  final int commitsBehind;
  final bool hasUpstream;
  final String? branch;
  final String? remoteError;
  final DateTime? remoteCheckedAt;
  final String? error;

  const GitStatusEntry({
    required this.sessionId,
    required this.projectPath,
    this.loading = false,
    this.hasUncommittedChanges = false,
    this.stagedCount = 0,
    this.unstagedCount = 0,
    this.untrackedCount = 0,
    this.hasRemoteChanges = false,
    this.commitsAhead = 0,
    this.commitsBehind = 0,
    this.hasUpstream = false,
    this.branch,
    this.remoteError,
    this.remoteCheckedAt,
    this.error,
  });

  bool get showDirtyBadge => !loading && error == null && hasUncommittedChanges;

  bool showRemoteBadge({required bool enabled}) =>
      enabled &&
      !showDirtyBadge &&
      !loading &&
      error == null &&
      remoteError == null &&
      hasRemoteChanges;

  bool get showBadge => showDirtyBadge;

  bool shouldRefreshRemote({required bool force}) {
    if (force) return true;
    final checkedAt = remoteCheckedAt;
    if (checkedAt == null) return true;
    return DateTime.now().difference(checkedAt) >= remoteRefreshTtl;
  }

  GitStatusEntry copyWith({
    String? projectPath,
    bool? loading,
    bool? hasUncommittedChanges,
    int? stagedCount,
    int? unstagedCount,
    int? untrackedCount,
    bool? hasRemoteChanges,
    int? commitsAhead,
    int? commitsBehind,
    bool? hasUpstream,
    String? branch,
    String? remoteError,
    DateTime? remoteCheckedAt,
    String? error,
    bool clearError = false,
    bool clearRemoteError = false,
  }) {
    return GitStatusEntry(
      sessionId: sessionId,
      projectPath: projectPath ?? this.projectPath,
      loading: loading ?? this.loading,
      hasUncommittedChanges:
          hasUncommittedChanges ?? this.hasUncommittedChanges,
      stagedCount: stagedCount ?? this.stagedCount,
      unstagedCount: unstagedCount ?? this.unstagedCount,
      untrackedCount: untrackedCount ?? this.untrackedCount,
      hasRemoteChanges: hasRemoteChanges ?? this.hasRemoteChanges,
      commitsAhead: commitsAhead ?? this.commitsAhead,
      commitsBehind: commitsBehind ?? this.commitsBehind,
      hasUpstream: hasUpstream ?? this.hasUpstream,
      branch: branch ?? this.branch,
      remoteError: clearRemoteError ? null : remoteError ?? this.remoteError,
      remoteCheckedAt: remoteCheckedAt ?? this.remoteCheckedAt,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class GitStatusState {
  final Map<String, GitStatusEntry> entriesBySession;

  const GitStatusState({this.entriesBySession = const {}});

  GitStatusEntry? entryFor(String sessionId) => entriesBySession[sessionId];

  GitStatusState upsert(GitStatusEntry entry) {
    return GitStatusState(
      entriesBySession: {...entriesBySession, entry.sessionId: entry},
    );
  }

  GitStatusState remove(String sessionId) {
    if (!entriesBySession.containsKey(sessionId)) return this;
    return GitStatusState(
      entriesBySession: Map.of(entriesBySession)..remove(sessionId),
    );
  }
}

class GitStatusCubit extends Cubit<GitStatusState> {
  final BridgeService _bridge;
  final bool Function()? _remoteStatusBadgeEnabled;
  late final StreamSubscription<GitStatusResultMessage> _statusSub;
  late final StreamSubscription<String> _stoppedSub;

  GitStatusCubit({
    required BridgeService bridge,
    bool Function()? remoteStatusBadgeEnabled,
  }) : _bridge = bridge,
       _remoteStatusBadgeEnabled = remoteStatusBadgeEnabled,
       super(const GitStatusState()) {
    _statusSub = _bridge.gitStatusResults.listen(_onStatusResult);
    _stoppedSub = _bridge.stoppedSessions.listen(clearSession);
  }

  void refresh({
    required String sessionId,
    required String projectPath,
    bool? includeRemote,
    bool forceRemote = false,
  }) {
    if (projectPath.isEmpty) return;
    final current = state.entryFor(sessionId);
    final wantsRemote =
        includeRemote ?? _remoteStatusBadgeEnabled?.call() ?? false;
    final requestRemote =
        wantsRemote &&
        (current?.shouldRefreshRemote(force: forceRemote) ?? true);
    emit(
      state.upsert(
        (current ??
                GitStatusEntry(sessionId: sessionId, projectPath: projectPath))
            .copyWith(
              projectPath: projectPath,
              loading: true,
              clearError: true,
              clearRemoteError: requestRemote,
            ),
      ),
    );
    _bridge.send(
      ClientMessage.gitStatus(
        projectPath,
        sessionId: sessionId,
        includeRemote: requestRemote,
      ),
    );
  }

  void refreshIfKnown(String sessionId) {
    final current = state.entryFor(sessionId);
    if (current == null) return;
    refresh(sessionId: sessionId, projectPath: current.projectPath);
  }

  void clearSession(String sessionId) {
    emit(state.remove(sessionId));
  }

  void _onStatusResult(GitStatusResultMessage result) {
    final sessionId = result.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    final current = state.entryFor(sessionId);
    final remoteCheckedAt = result.remoteStatusIncluded
        ? DateTime.now()
        : current?.remoteCheckedAt;
    emit(
      state.upsert(
        GitStatusEntry(
          sessionId: sessionId,
          projectPath: result.projectPath,
          loading: false,
          hasUncommittedChanges: result.hasUncommittedChanges,
          stagedCount: result.stagedCount,
          unstagedCount: result.unstagedCount,
          untrackedCount: result.untrackedCount,
          hasRemoteChanges: result.remoteStatusIncluded
              ? result.hasRemoteChanges
              : current?.hasRemoteChanges ?? false,
          commitsAhead: result.remoteStatusIncluded
              ? result.commitsAhead
              : current?.commitsAhead ?? 0,
          commitsBehind: result.remoteStatusIncluded
              ? result.commitsBehind
              : current?.commitsBehind ?? 0,
          hasUpstream: result.remoteStatusIncluded
              ? result.hasUpstream
              : current?.hasUpstream ?? false,
          branch: result.remoteStatusIncluded ? result.branch : current?.branch,
          remoteError: result.remoteStatusIncluded
              ? result.remoteError
              : current?.remoteError,
          remoteCheckedAt: remoteCheckedAt,
          error: result.error,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _statusSub.cancel();
    await _stoppedSub.cancel();
    return super.close();
  }
}
