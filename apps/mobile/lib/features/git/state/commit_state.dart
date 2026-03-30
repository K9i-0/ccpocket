import 'package:freezed_annotation/freezed_annotation.dart';

part 'commit_state.freezed.dart';

/// Status of the commit flow.
enum CommitStatus { idle, committing, pushing, success, error }

/// State for the commit flow bottom sheet.
@freezed
abstract class CommitState with _$CommitState {
  const factory CommitState({
    /// Commit message entered by the user.
    @Default('') String message,

    /// Whether to auto-generate the commit message.
    @Default(true) bool autoGenerate,

    /// Current status of the multi-step commit flow.
    @Default(CommitStatus.idle) CommitStatus status,

    /// Error message if any step fails.
    String? error,

    /// Commit hash after successful commit.
    String? commitHash,

    /// Number of staged files.
    @Default(0) int stagedFileCount,

    /// Number of insertions across staged files.
    @Default(0) int insertions,

    /// Number of deletions across staged files.
    @Default(0) int deletions,
  }) = _CommitState;
}
