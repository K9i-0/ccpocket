import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/messages.dart';

part 'branch_state.freezed.dart';

/// State for the branch selector sheet.
@freezed
abstract class BranchState with _$BranchState {
  const factory BranchState({
    /// Current branch name.
    String? current,

    /// All branches (unfiltered).
    @Default([]) List<String> branches,

    /// Search query for filtering.
    @Default('') String query,

    /// Whether a branch list request is in progress.
    @Default(false) bool loading,

    /// Error message.
    String? error,

    /// Whether a branch creation is in progress.
    @Default(false) bool creating,

    /// Branches checked out by main repo or worktrees (cannot switch to).
    @Default([]) List<String> checkedOutBranches,

    /// Ahead/behind information keyed by branch name.
    @Default({}) Map<String, GitBranchRemoteStatus> remoteStatusByBranch,
  }) = _BranchState;
}
