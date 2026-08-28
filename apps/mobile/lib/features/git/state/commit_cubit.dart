import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import 'commit_state.dart';

/// Manages the commit → push → PR creation flow.
class CommitCubit extends Cubit<CommitState> {
  static int _nextConsumerId = 0;
  static const _commitResponseFamily = 'git-commit';
  static const _pushResponseFamily = 'git-push';

  final BridgeService _bridge;
  final String _projectPath;
  final String? _sessionId;
  final String _consumerId = 'commit-${++_nextConsumerId}';
  String? _commitRequestId;
  String? _pushRequestId;

  StreamSubscription<GitCommitResultMessage>? _commitSub;
  StreamSubscription<GitPushResultMessage>? _pushSub;

  /// What to do after a successful commit.
  _PostCommitAction _postCommitAction = _PostCommitAction.none;

  CommitCubit({
    required BridgeService bridge,
    required String projectPath,
    String? sessionId,
  }) : _bridge = bridge,
       _projectPath = projectPath,
       _sessionId = sessionId,
       super(const CommitState()) {
    _commitSub = _bridge.gitCommitResults.listen(_onCommitResult);
    _pushSub = _bridge.gitPushResults.listen(_onPushResult);
  }

  // ---- Public API ----

  void setMessage(String message) => emit(state.copyWith(message: message));

  void toggleAutoGenerate() =>
      emit(state.copyWith(autoGenerate: !state.autoGenerate));

  /// Update staged file summary from GitViewCubit.
  void updateStagedSummary({
    required int fileCount,
    required int insertions,
    required int deletions,
  }) {
    emit(
      state.copyWith(
        stagedFileCount: fileCount,
        insertions: insertions,
        deletions: deletions,
      ),
    );
  }

  /// Commit only.
  void commit() {
    _postCommitAction = _PostCommitAction.none;
    _doCommit();
  }

  /// Commit then push.
  void commitAndPush() {
    _postCommitAction = _PostCommitAction.push;
    _doCommit();
  }

  /// Reset to idle state (e.g. after dismissing success/error).
  void reset() => emit(const CommitState());

  // ---- Internal ----

  void _doCommit() {
    emit(state.copyWith(status: CommitStatus.committing, error: null));
    final requestId = _bridge.createProjectRequestId('git-commit');
    _commitRequestId = requestId;
    _bridge.registerProjectResponseConsumer(_commitResponseFamily, _consumerId);
    _bridge.send(
      ClientMessage.gitCommit(
        _projectPath,
        sessionId: state.autoGenerate ? _sessionId : null,
        message: state.autoGenerate ? null : state.message,
        autoGenerate: state.autoGenerate ? true : null,
        requestId: _bridge.projectRequestIdForWire(requestId),
      ),
    );
  }

  void _onCommitResult(GitCommitResultMessage result) {
    if (!_accept(result, _commitRequestId, _commitResponseFamily)) return;
    _bridge.unregisterProjectResponseConsumer(
      _commitResponseFamily,
      _consumerId,
    );
    _commitRequestId = null;
    if (!result.success) {
      emit(state.copyWith(status: CommitStatus.error, error: result.error));
      return;
    }

    emit(state.copyWith(commitHash: result.commitHash));

    if (_postCommitAction == _PostCommitAction.push) {
      emit(state.copyWith(status: CommitStatus.pushing));
      final requestId = _bridge.createProjectRequestId('git-push');
      _pushRequestId = requestId;
      _bridge.registerProjectResponseConsumer(_pushResponseFamily, _consumerId);
      _bridge.send(
        ClientMessage.gitPush(
          _projectPath,
          requestId: _bridge.projectRequestIdForWire(requestId),
        ),
      );
    } else {
      emit(state.copyWith(status: CommitStatus.success));
    }
  }

  void _onPushResult(GitPushResultMessage result) {
    if (!_accept(result, _pushRequestId, _pushResponseFamily)) return;
    _bridge.unregisterProjectResponseConsumer(_pushResponseFamily, _consumerId);
    _pushRequestId = null;
    if (!result.success) {
      emit(state.copyWith(status: CommitStatus.error, error: result.error));
      return;
    }

    emit(state.copyWith(status: CommitStatus.success));
  }

  @override
  Future<void> close() {
    _bridge.unregisterProjectResponseConsumer(
      _commitResponseFamily,
      _consumerId,
      all: true,
    );
    _bridge.unregisterProjectResponseConsumer(
      _pushResponseFamily,
      _consumerId,
      all: true,
    );
    _commitSub?.cancel();
    _pushSub?.cancel();
    return super.close();
  }

  bool _accept(
    ProjectCorrelatedMessage result,
    String? pendingRequestId,
    String responseFamily,
  ) {
    if (result.projectPath != null && result.projectPath != _projectPath) {
      return false;
    }
    final requestId = result.requestId;
    if (requestId != null) return requestId == pendingRequestId;
    return pendingRequestId != null &&
        _bridge.canAcceptLegacyProjectResponse(responseFamily, _consumerId);
  }
}

enum _PostCommitAction { none, push }
