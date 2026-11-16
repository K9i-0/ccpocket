import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/messages.dart';

part 'github_list_state.freezed.dart';

/// Why a GitHub request could not be answered.
enum GitHubFailureKind {
  /// `gh` is not installed on the Bridge host.
  ghMissing,

  /// `gh auth status` failed on the Bridge host.
  ghUnauthenticated,

  /// The project's `origin` is not a GitHub repository.
  notGithub,

  /// The connected Bridge predates `github_list` / `github_item`.
  unsupported,

  /// The Bridge did not answer in time.
  timeout,

  /// The Bridge connection was lost before an answer arrived.
  disconnected,

  /// Any other failure; see [GitHubFailure.message].
  failed;

  static GitHubFailureKind fromCode(String code) => switch (code) {
    GitHubError.ghMissing => GitHubFailureKind.ghMissing,
    GitHubError.ghUnauthenticated => GitHubFailureKind.ghUnauthenticated,
    GitHubError.notGithub => GitHubFailureKind.notGithub,
    _ => GitHubFailureKind.failed,
  };
}

@freezed
abstract class GitHubFailure with _$GitHubFailure {
  const factory GitHubFailure({
    required GitHubFailureKind kind,
    @Default('') String message,
  }) = _GitHubFailure;

  factory GitHubFailure.fromError(GitHubError error) => GitHubFailure(
    kind: GitHubFailureKind.fromCode(error.code),
    message: error.message,
  );
}

/// One tab (pull requests or issues).
@freezed
abstract class GitHubTabState with _$GitHubTabState {
  const factory GitHubTabState({
    @Default(false) bool loading,

    /// A successful result has been applied at least once.
    @Default(false) bool loaded,
    @Default([]) List<GitHubItemSummary> items,
    GitHubFailure? failure,
  }) = _GitHubTabState;
}

@freezed
abstract class GitHubFilters with _$GitHubFilters {
  const factory GitHubFilters({
    /// Pull requests only.
    @Default(false) bool hideDrafts,

    /// Pull requests only.
    @Default(false) bool dependabotOnly,
    String? label,
  }) = _GitHubFilters;
}

@freezed
abstract class GitHubListState with _$GitHubListState {
  const GitHubListState._();

  const factory GitHubListState({
    @Default(GitHubTabState()) GitHubTabState prs,
    @Default(GitHubTabState()) GitHubTabState issues,

    /// `owner/name`.
    String? repository,
    @Default(GitHubFilters()) GitHubFilters filters,
    @Default(false) bool selectionMode,

    /// Selected item numbers. Issues and pull requests share one number space,
    /// so a selection can span both tabs.
    @Default({}) Set<int> selected,
  }) = _GitHubListState;

  GitHubTabState tab(GitHubItemKind kind) => switch (kind) {
    GitHubItemKind.pr => prs,
    GitHubItemKind.issue => issues,
  };

  /// Items of [kind] after applying [filters].
  List<GitHubItemSummary> visibleItems(GitHubItemKind kind) {
    final label = filters.label;
    final isPr = kind == GitHubItemKind.pr;
    return [
      for (final item in tab(kind).items)
        if (!(isPr && filters.hideDrafts && item.isDraft) &&
            !(isPr && filters.dependabotOnly && !item.isDependabot) &&
            (label == null || item.labels.contains(label)))
          item,
    ];
  }

  /// Labels used by the items of [kind], sorted for the label filter.
  List<String> availableLabels(GitHubItemKind kind) {
    final labels = <String>{
      for (final item in tab(kind).items) ...item.labels,
      ?filters.label,
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return labels;
  }

  /// Selected numbers in ascending order, as sent to the triage skill.
  List<int> get selectedNumbers => selected.toList()..sort();
}
