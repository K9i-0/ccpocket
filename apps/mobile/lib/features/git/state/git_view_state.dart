import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../utils/diff_parser.dart';

part 'git_view_state.freezed.dart';

/// Which diff to display: unstaged (working-tree) or staged (index).
enum GitViewMode { unstaged, staged }

/// State for the diff viewer screen.
@freezed
abstract class GitViewState with _$GitViewState {
  const factory GitViewState({
    /// Parsed diff files.
    @Default([]) List<DiffFile> files,

    /// Indices of files hidden by the filter.
    @Default({}) Set<int> hiddenFileIndices,

    /// Indices of files whose hunks are collapsed.
    @Default({}) Set<int> collapsedFileIndices,

    /// Whether a diff request is in progress.
    @Default(false) bool loading,

    /// Error message from parsing or server request.
    String? error,

    /// Error code for categorized error handling (e.g. 'git_not_available').
    String? errorCode,

    /// Whether selection mode is active.
    @Default(false) bool selectionMode,

    /// Selected hunk keys in the format "$fileIdx:$hunkIdx".
    @Default({}) Set<String> selectedHunkKeys,

    /// Indices of image files currently loading on demand.
    @Default({}) Set<int> loadingImageIndices,

    /// Current diff view mode: unstaged (working-tree) or staged (index).
    @Default(GitViewMode.unstaged) GitViewMode viewMode,

    /// Whether long diff lines should wrap instead of horizontal scrolling.
    @Default(false) bool lineWrapEnabled,

    /// Whether a stage/unstage operation is in progress.
    @Default(false) bool staging,

    /// Commits ahead of upstream (pushable).
    @Default(0) int commitsAhead,

    /// Commits behind upstream (pullable).
    @Default(0) int commitsBehind,

    /// Whether the branch has a configured upstream.
    @Default(false) bool hasUpstream,

    /// Whether a fetch is in progress.
    @Default(false) bool fetching,

    /// Whether a pull is in progress.
    @Default(false) bool pulling,

    /// Whether a push is in progress.
    @Default(false) bool pushing,

    /// Current branch name.
    String? currentBranch,

    /// Whether the project is in a worktree.
    @Default(false) bool isWorktree,
  }) = _GitViewState;
}
