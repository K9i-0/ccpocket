import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import 'commit_state.dart';

/// Manages the commit → push → PR creation flow.
class CommitCubit extends Cubit<CommitState> {
  final BridgeService _bridge;
  final String _projectPath;

  StreamSubscription<GitCommitResultMessage>? _commitSub;
  StreamSubscription<GitPushResultMessage>? _pushSub;

  /// What to do after a successful commit.
  _PostCommitAction _postCommitAction = _PostCommitAction.none;

  CommitCubit({required BridgeService bridge, required String projectPath})
    : _bridge = bridge,
      _projectPath = projectPath,
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
    _bridge.send(
      ClientMessage.gitCommit(
        _projectPath,
        message: state.autoGenerate ? null : state.message,
        autoGenerate: state.autoGenerate ? true : null,
      ),
    );
  }

  void _onCommitResult(GitCommitResultMessage result) {
    if (!result.success) {
      emit(state.copyWith(status: CommitStatus.error, error: result.error));
      return;
    }

    emit(state.copyWith(commitHash: result.commitHash));

    if (_postCommitAction == _PostCommitAction.push) {
      emit(state.copyWith(status: CommitStatus.pushing));
      _bridge.send(ClientMessage.gitPush(_projectPath));
    } else {
      emit(state.copyWith(status: CommitStatus.success));
    }
  }

  void _onPushResult(GitPushResultMessage result) {
    if (!result.success) {
      emit(state.copyWith(status: CommitStatus.error, error: result.error));
      return;
    }

    emit(state.copyWith(status: CommitStatus.success));
  }

  @override
  Future<void> close() {
    _commitSub?.cancel();
    _pushSub?.cancel();
    return super.close();
  }
}

enum _PostCommitAction { none, push }
