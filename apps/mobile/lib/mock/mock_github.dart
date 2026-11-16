// ignore_for_file: altive_lints_plugin/avoid_hardcoded_japanese

import '../models/messages.dart';

/// Project paths understood by the mock Bridge for the Issues / PRs screen.
///
/// The path selects the answer, so each state of the screen can be opened
/// without a real Bridge.
abstract final class MockGitHubProjects {
  static const repository = '/mock/ccpocket';
  static const ghMissing = '/mock/github-gh-missing';
  static const ghUnauthenticated = '/mock/github-gh-unauthenticated';
  static const notGithub = '/mock/github-not-github';
  static const failed = '/mock/github-failed';

  /// Answers like a Bridge that predates `github_list`.
  static const oldBridge = '/mock/github-old-bridge';
}

GitHubError? _mockGitHubError(String projectPath) => switch (projectPath) {
  MockGitHubProjects.ghMissing => const GitHubError(
    code: GitHubError.ghMissing,
    message: 'gh: command not found',
  ),
  MockGitHubProjects.ghUnauthenticated => const GitHubError(
    code: GitHubError.ghUnauthenticated,
    message: 'You are not logged into any GitHub hosts.',
  ),
  MockGitHubProjects.notGithub => const GitHubError(
    code: GitHubError.notGithub,
    message: 'origin is git@gitlab.com:example/app.git',
  ),
  MockGitHubProjects.failed => const GitHubError(
    code: GitHubError.failed,
    message: 'HTTP 502: Bad Gateway (https://api.github.com/graphql)',
  ),
  _ => null,
};

DateTime _ago(Duration duration) => DateTime.now().toUtc().subtract(duration);

List<GitHubItemSummary> mockGitHubPullRequests() => [
  GitHubItemSummary(
    number: 342,
    title: 'feat(mobile): add Issues / PRs screen',
    url: 'https://github.com/K9i-0/ccpocket/pull/342',
    author: const GitHubAuthor(login: 'K9i-0'),
    labels: const ['enhancement'],
    createdAt: _ago(const Duration(hours: 2)),
    updatedAt: _ago(const Duration(minutes: 20)),
    checks: GitHubChecksState.success,
  ),
  GitHubItemSummary(
    number: 340,
    title: 'WIP: rework session list grouping',
    url: 'https://github.com/K9i-0/ccpocket/pull/340',
    author: const GitHubAuthor(login: 'octocat'),
    createdAt: _ago(const Duration(hours: 9)),
    updatedAt: _ago(const Duration(hours: 3)),
    isDraft: true,
    checks: GitHubChecksState.pending,
  ),
  GitHubItemSummary(
    number: 338,
    title: 'chore(deps): bump vitest from 3.2.3 to 3.2.4',
    url: 'https://github.com/K9i-0/ccpocket/pull/338',
    author: const GitHubAuthor(login: 'dependabot', isBot: true),
    labels: const ['dependencies', 'javascript'],
    createdAt: _ago(const Duration(days: 1)),
    updatedAt: _ago(const Duration(days: 1)),
    checks: GitHubChecksState.success,
  ),
  GitHubItemSummary(
    number: 335,
    title: 'chore(deps): bump flutter_bloc from 9.1.0 to 9.1.1',
    url: 'https://github.com/K9i-0/ccpocket/pull/335',
    author: const GitHubAuthor(login: 'dependabot', isBot: true),
    labels: const ['dependencies', 'dart'],
    createdAt: _ago(const Duration(days: 2)),
    updatedAt: _ago(const Duration(days: 2)),
    checks: GitHubChecksState.failure,
  ),
  GitHubItemSummary(
    number: 331,
    title: 'fix(bridge): keep the WebSocket alive behind nginx',
    url: 'https://github.com/K9i-0/ccpocket/pull/331',
    author: const GitHubAuthor(login: 'hubot-contributor'),
    labels: const ['bug'],
    createdAt: _ago(const Duration(days: 4)),
    updatedAt: _ago(const Duration(days: 3)),
    checks: GitHubChecksState.none,
  ),
];

List<GitHubItemSummary> mockGitHubIssues() => [
  GitHubItemSummary(
    number: 341,
    title: 'Approval sheet is cut off on small phones',
    url: 'https://github.com/K9i-0/ccpocket/issues/341',
    author: const GitHubAuthor(login: 'octocat'),
    labels: const ['bug', 'mobile'],
    createdAt: _ago(const Duration(minutes: 40)),
    updatedAt: _ago(const Duration(minutes: 40)),
  ),
  GitHubItemSummary(
    number: 339,
    title: 'Support opening a session from a notification on macOS',
    url: 'https://github.com/K9i-0/ccpocket/issues/339',
    author: const GitHubAuthor(login: 'mona'),
    labels: const ['enhancement'],
    createdAt: _ago(const Duration(hours: 20)),
    updatedAt: _ago(const Duration(hours: 5)),
  ),
  GitHubItemSummary(
    number: 327,
    title: 'Bridgeの自動起動がmacOS 27で失敗する',
    url: 'https://github.com/K9i-0/ccpocket/issues/327',
    author: const GitHubAuthor(login: 'hubot-contributor'),
    createdAt: _ago(const Duration(days: 6)),
    updatedAt: _ago(const Duration(days: 1)),
  ),
];

/// Answer of the mock Bridge to `github_list`.
ServerMessage mockGitHubListResult({
  required String? requestId,
  required String projectPath,
  required GitHubItemKind kind,
}) {
  if (projectPath == MockGitHubProjects.oldBridge) {
    return const ErrorMessage(
      message: 'github_list',
      errorCode: 'unsupported_message',
    );
  }
  final error = _mockGitHubError(projectPath);
  if (error != null) {
    return GitHubListResultMessage(
      requestId: requestId,
      projectPath: projectPath,
      kind: kind,
      error: error,
    );
  }
  return GitHubListResultMessage(
    requestId: requestId,
    projectPath: projectPath,
    kind: kind,
    repository: 'K9i-0/ccpocket',
    items: switch (kind) {
      GitHubItemKind.pr => mockGitHubPullRequests(),
      GitHubItemKind.issue => mockGitHubIssues(),
    },
  );
}

/// Answer of the mock Bridge to `github_item`.
ServerMessage mockGitHubItemResult({
  required String? requestId,
  required String projectPath,
  required GitHubItemKind kind,
  required int number,
}) {
  if (projectPath == MockGitHubProjects.oldBridge) {
    return const ErrorMessage(
      message: 'github_item',
      errorCode: 'unsupported_message',
    );
  }
  final items = switch (kind) {
    GitHubItemKind.pr => mockGitHubPullRequests(),
    GitHubItemKind.issue => mockGitHubIssues(),
  };
  final summary = items.where((item) => item.number == number).firstOrNull;
  final error = _mockGitHubError(projectPath);
  if (error != null || summary == null) {
    return GitHubItemResultMessage(
      requestId: requestId,
      projectPath: projectPath,
      kind: kind,
      number: number,
      error:
          error ??
          GitHubError(
            code: GitHubError.failed,
            message: 'Could not resolve #$number',
          ),
    );
  }
  return GitHubItemResultMessage(
    requestId: requestId,
    projectPath: projectPath,
    kind: kind,
    number: number,
    item: GitHubItemDetail(
      summary: summary,
      body:
          '## Summary\n\n'
          '${summary.title}\n\n'
          '- Reproduced on the latest release\n'
          '- See `packages/bridge/src/websocket.ts`\n\n'
          '```sh\nnpx @ccpocket/bridge@latest\n```\n\n'
          'Related: [docs](https://github.com/K9i-0/ccpocket#readme)',
      comments: [
        GitHubComment(
          author: const GitHubAuthor(login: 'K9i-0'),
          body:
              'Thanks for the report. Could you share the **Bridge version**?',
          createdAt: _ago(const Duration(hours: 5)),
        ),
        GitHubComment(
          author: const GitHubAuthor(login: 'github-actions', isBot: true),
          body: 'CI finished: `flutter test` passed.',
          createdAt: _ago(const Duration(hours: 1)),
        ),
      ],
    ),
  );
}
