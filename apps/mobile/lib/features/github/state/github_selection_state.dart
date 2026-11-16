import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/messages.dart';

part 'github_selection_state.freezed.dart';
part 'github_selection_state.g.dart';

/// An issue or pull request picked for a session. It keeps what the composer
/// card shows and the URL that is sent, so it does not depend on the list
/// still being loaded.
@freezed
abstract class GitHubSelectedItem with _$GitHubSelectedItem {
  const GitHubSelectedItem._();

  const factory GitHubSelectedItem({
    required int number,
    required String title,

    /// Identity of the item, and what the agent receives.
    required String url,
    @Default(false) bool isPullRequest,
  }) = _GitHubSelectedItem;

  factory GitHubSelectedItem.fromJson(Map<String, dynamic> json) =>
      _$GitHubSelectedItemFromJson(json);

  /// `null` when the item has no URL and none can be built from
  /// [repository] (`owner/name`). The Bridge always reports one.
  static GitHubSelectedItem? fromSummary(
    GitHubItemSummary summary,
    GitHubItemKind kind, {
    String? repository,
  }) {
    final url = githubItemUrl(summary, kind, repository: repository);
    if (url == null) return null;
    return GitHubSelectedItem(
      number: summary.number,
      title: summary.title,
      url: url,
      isPullRequest: kind == GitHubItemKind.pr,
    );
  }
}

/// URL of [summary], rebuilt from [repository] when the summary has none.
String? githubItemUrl(
  GitHubItemSummary summary,
  GitHubItemKind kind, {
  String? repository,
}) {
  if (summary.url.isNotEmpty) return summary.url;
  if (repository == null || repository.isEmpty) return null;
  final segment = switch (kind) {
    GitHubItemKind.pr => 'pull',
    GitHubItemKind.issue => 'issues',
  };
  return 'https://github.com/$repository/$segment/${summary.number}';
}

/// Selected items per session, in the order they were picked.
@freezed
abstract class GitHubSelectionState with _$GitHubSelectionState {
  const factory GitHubSelectionState({
    @Default({}) Map<String, List<GitHubSelectedItem>> sessions,
  }) = _GitHubSelectionState;
}

/// Appended once, immediately before sending: the user's text stays first so
/// a leading `/skill` or `$skill` still starts the message, followed by one
/// URL per line. Without text the message is only the URLs.
String appendGitHubSelection(String prompt, List<GitHubSelectedItem> items) {
  if (items.isEmpty) return prompt;
  return [
    if (prompt.isNotEmpty) prompt,
    ...items.map((item) => item.url),
  ].join('\n');
}
