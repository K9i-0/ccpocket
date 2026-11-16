/// Data models for the GitHub triage screen (`github_list` / `github_item`).
///
/// The wire contract is defined in `docs/github-triage.md`.
library;

enum GitHubItemKind {
  pr('pr'),
  issue('issue');

  final String value;
  const GitHubItemKind(this.value);

  static GitHubItemKind fromWire(Object? raw) =>
      raw == 'issue' ? GitHubItemKind.issue : GitHubItemKind.pr;
}

/// Combined CI state of a pull request (`statusCheckRollup`).
enum GitHubChecksState {
  success,
  failure,
  pending,
  none;

  static GitHubChecksState fromWire(Object? raw) => switch (raw) {
    'success' => GitHubChecksState.success,
    'failure' => GitHubChecksState.failure,
    'pending' => GitHubChecksState.pending,
    _ => GitHubChecksState.none,
  };
}

class GitHubAuthor {
  final String login;
  final bool isBot;

  const GitHubAuthor({required this.login, this.isBot = false});

  factory GitHubAuthor.fromJson(Object? json) {
    if (json is! Map) return const GitHubAuthor(login: '');
    return GitHubAuthor(
      login: json['login'] as String? ?? '',
      isBot: json['isBot'] as bool? ?? false,
    );
  }

  bool get isDependabot => isBot && login.startsWith('dependabot');
}

class GitHubItemSummary {
  final int number;
  final String title;
  final String url;
  final GitHubAuthor author;
  final List<String> labels;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Pull requests only.
  final bool isDraft;

  /// Pull requests only. `null` when the Bridge did not report a state.
  final GitHubChecksState? checks;

  const GitHubItemSummary({
    required this.number,
    required this.title,
    this.url = '',
    this.author = const GitHubAuthor(login: ''),
    this.labels = const [],
    this.createdAt,
    this.updatedAt,
    this.isDraft = false,
    this.checks,
  });

  factory GitHubItemSummary.fromJson(Map<String, dynamic> json) {
    return GitHubItemSummary(
      number: (json['number'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      author: GitHubAuthor.fromJson(json['author']),
      labels: _stringList(json['labels']),
      createdAt: _parseTime(json['createdAt']),
      updatedAt: _parseTime(json['updatedAt']),
      isDraft: json['isDraft'] as bool? ?? false,
      checks: json['checks'] == null
          ? null
          : GitHubChecksState.fromWire(json['checks']),
    );
  }

  bool get isDependabot => author.isDependabot;
}

class GitHubComment {
  final GitHubAuthor author;
  final String body;
  final DateTime? createdAt;

  const GitHubComment({
    required this.author,
    required this.body,
    this.createdAt,
  });

  factory GitHubComment.fromJson(Map<String, dynamic> json) => GitHubComment(
    author: GitHubAuthor.fromJson(json['author']),
    body: json['body'] as String? ?? '',
    createdAt: _parseTime(json['createdAt']),
  );
}

class GitHubItemDetail {
  final GitHubItemSummary summary;
  final String body;

  /// Latest comments, oldest first.
  final List<GitHubComment> comments;

  const GitHubItemDetail({
    required this.summary,
    this.body = '',
    this.comments = const [],
  });

  factory GitHubItemDetail.fromJson(Map<String, dynamic> json) {
    final comments = json['comments'];
    return GitHubItemDetail(
      summary: GitHubItemSummary.fromJson(json),
      body: json['body'] as String? ?? '',
      comments: comments is List
          ? [
              for (final comment in comments)
                if (comment is Map)
                  GitHubComment.fromJson(Map<String, dynamic>.from(comment)),
            ]
          : const [],
    );
  }
}

/// Typed failure reported by the Bridge's `gh` wrapper.
class GitHubError {
  static const ghMissing = 'gh_missing';
  static const ghUnauthenticated = 'gh_unauthenticated';
  static const notGithub = 'not_github';
  static const failed = 'failed';

  final String code;
  final String message;

  const GitHubError({required this.code, this.message = ''});

  static GitHubError? fromJson(Object? json) {
    if (json == null) return null;
    // Tolerate a bare string so an unexpected shape still surfaces as an error.
    if (json is String) return GitHubError(code: failed, message: json);
    if (json is! Map) return const GitHubError(code: failed);
    return GitHubError(
      code: json['code'] as String? ?? failed,
      message: json['message'] as String? ?? '',
    );
  }
}

List<String> _stringList(Object? raw) => raw is List
    ? [
        for (final value in raw)
          if (value is String) value,
      ]
    : const [];

DateTime? _parseTime(Object? raw) =>
    raw is String ? DateTime.tryParse(raw) : null;
