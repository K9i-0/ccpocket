// ignore_for_file: altive_lints_plugin/avoid_hardcoded_japanese

import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/chat_session_state.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/features/github/github_screen.dart';
import 'package:ccpocket/features/github/state/github_item_cubit.dart';
import 'package:ccpocket/features/github/state/github_list_cubit.dart';
import 'package:ccpocket/features/github/state/github_list_state.dart';
import 'package:ccpocket/features/github/state/github_view_cache_service.dart';
import 'package:ccpocket/features/github/triage_prompt.dart';
import 'package:ccpocket/features/github/widgets/empty_chat_github_button.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/mock/mock_github.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/mock_bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the app sends and lets a test answer by hand.
class _Bridge extends BridgeService {
  final responses = StreamController<ServerMessage>.broadcast(sync: true);
  final connection = StreamController<BridgeConnectionState>.broadcast(
    sync: true,
  );
  final sent = <Map<String, dynamic>>[];
  bool connected = true;

  @override
  Stream<ServerMessage> get messages => responses.stream;

  @override
  Stream<BridgeConnectionState> get connectionStatus => connection.stream;

  @override
  bool get isConnected => connected;

  void setConnection(BridgeConnectionState state) {
    connected = state == BridgeConnectionState.connected;
    connection.add(state);
  }

  @override
  void send(ClientMessage message) =>
      sent.add(jsonDecode(message.toJson()) as Map<String, dynamic>);

  String get lastRequestId => sent.last['requestId'] as String;

  @override
  void dispose() {
    responses.close();
    connection.close();
    super.dispose();
  }
}

const _project = '/work/app';

GitHubItemSummary _pr(
  int number, {
  bool draft = false,
  bool dependabot = false,
  List<String> labels = const [],
}) => GitHubItemSummary(
  number: number,
  title: 'PR $number',
  author: dependabot
      ? const GitHubAuthor(login: 'dependabot', isBot: true)
      : const GitHubAuthor(login: 'octocat'),
  labels: labels,
  isDraft: draft,
);

GitHubListResultMessage _list(
  _Bridge bridge,
  GitHubItemKind kind,
  List<GitHubItemSummary> items, {
  String? requestId,
  String projectPath = _project,
  GitHubError? error,
}) => GitHubListResultMessage(
  requestId: requestId ?? bridge.lastRequestId,
  projectPath: projectPath,
  kind: kind,
  repository: 'owner/app',
  items: items,
  error: error,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late _Bridge bridge;
  late GitHubListCubit cubit;

  setUp(() {
    bridge = _Bridge();
    cubit = GitHubListCubit(bridge: bridge, projectPath: _project);
    addTearDown(() async {
      await cubit.close();
      bridge.dispose();
    });
  });

  group('message parsing', () {
    test('github_list_result maps summaries and derived flags', () {
      final message = ServerMessage.fromJson({
        'type': 'github_list_result',
        'requestId': 'github-list-1',
        'projectPath': _project,
        'kind': 'pr',
        'repository': 'owner/app',
        'items': [
          {
            'number': 338,
            'title': 'bump vitest',
            'url': 'https://github.com/owner/app/pull/338',
            'author': {'login': 'dependabot', 'isBot': true},
            'labels': ['dependencies'],
            'createdAt': '2026-11-10T01:02:03Z',
            'updatedAt': '2026-11-11T01:02:03Z',
            'isDraft': true,
            'checks': 'failure',
          },
          {
            'number': 7,
            'title': 'human named dependabot-fan',
            'url': '',
            'author': {'login': 'dependabot-fan', 'isBot': false},
            'labels': <String>[],
            'createdAt': 'not a date',
            'updatedAt': '2026-11-11T01:02:03Z',
          },
        ],
      });

      expect(message, isA<GitHubListResultMessage>());
      final result = message as GitHubListResultMessage;
      expect(result.requestId, 'github-list-1');
      expect(result.projectPath, _project);
      expect(result.kind, GitHubItemKind.pr);
      expect(result.repository, 'owner/app');
      expect(result.error, isNull);
      final bot = result.items.first;
      expect(bot.number, 338);
      expect(bot.isDraft, isTrue);
      expect(bot.isDependabot, isTrue);
      expect(bot.checks, GitHubChecksState.failure);
      expect(bot.labels, ['dependencies']);
      expect(bot.createdAt, DateTime.utc(2026, 11, 10, 1, 2, 3));
      final human = result.items.last;
      expect(human.isDependabot, isFalse, reason: 'isBot is required');
      expect(human.isDraft, isFalse);
      expect(human.checks, isNull);
      expect(human.createdAt, isNull);
    });

    test('github_list_result carries a typed error without items', () {
      final result = ServerMessage.fromJson({
        'type': 'github_list_result',
        'requestId': 'github-list-2',
        'projectPath': _project,
        'kind': 'issue',
        'error': {'code': 'gh_unauthenticated', 'message': 'login'},
      }) as GitHubListResultMessage;

      expect(result.kind, GitHubItemKind.issue);
      expect(result.items, isEmpty);
      expect(result.error?.code, GitHubError.ghUnauthenticated);
      expect(result.error?.message, 'login');
    });

    test('github_item_result maps the body and comments', () {
      final result = ServerMessage.fromJson({
        'type': 'github_item_result',
        'requestId': 'github-item-1',
        'projectPath': _project,
        'kind': 'issue',
        'number': 327,
        'item': {
          'number': 327,
          'title': 'Crash',
          'url': 'https://github.com/owner/app/issues/327',
          'author': {'login': 'mona', 'isBot': false},
          'labels': ['bug'],
          'createdAt': '2026-11-10T01:02:03Z',
          'updatedAt': '2026-11-10T01:02:03Z',
          'body': 'It crashes.',
          'comments': [
            {
              'author': {'login': 'octocat', 'isBot': false},
              'body': 'Which version?',
              'createdAt': '2026-11-10T02:00:00Z',
            },
          ],
        },
      }) as GitHubItemResultMessage;

      expect(result.number, 327);
      expect(result.item?.summary.title, 'Crash');
      expect(result.item?.body, 'It crashes.');
      expect(result.item?.comments.single.author.login, 'octocat');
      expect(result.item?.comments.single.body, 'Which version?');
    });

    test('requests always carry requestId, projectPath, and kind', () {
      final listId = bridge.requestGitHubList(
        projectPath: _project,
        kind: GitHubItemKind.issue,
      );
      final itemId = bridge.requestGitHubItem(
        projectPath: _project,
        kind: GitHubItemKind.pr,
        number: 12,
      );

      expect(bridge.sent[0], {
        'type': 'github_list',
        'projectPath': _project,
        'kind': 'issue',
        'requestId': listId,
      });
      expect(bridge.sent[1], {
        'type': 'github_item',
        'projectPath': _project,
        'kind': 'pr',
        'number': 12,
        'requestId': itemId,
      });
      expect(listId, isNot(itemId));
    });
  });

  group('GitHubListCubit loading', () {
    test('loads a tab once and applies the matching result', () {
      cubit.ensureLoaded(GitHubItemKind.pr);
      cubit.ensureLoaded(GitHubItemKind.pr);

      expect(bridge.sent, hasLength(1));
      expect(bridge.sent.single['kind'], 'pr');
      expect(cubit.state.prs.loading, isTrue);

      bridge.responses.add(_list(bridge, GitHubItemKind.pr, [_pr(1), _pr(2)]));

      expect(cubit.state.prs.loading, isFalse);
      expect(cubit.state.prs.loaded, isTrue);
      expect(cubit.state.prs.items.map((item) => item.number), [1, 2]);
      expect(cubit.state.repository, 'owner/app');
      expect(cubit.state.issues.loaded, isFalse);

      cubit.ensureLoaded(GitHubItemKind.pr);
      expect(bridge.sent, hasLength(1), reason: 'already loaded');
    });

    test('refresh completes when the result arrives', () async {
      var done = false;
      unawaited(cubit.refresh(GitHubItemKind.issue).then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);

      bridge.responses.add(_list(bridge, GitHubItemKind.issue, [_pr(5)]));
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
      expect(cubit.state.issues.items.single.number, 5);
    });

    test('rejects a stale response after a newer request', () {
      unawaited(cubit.refresh(GitHubItemKind.pr));
      final stale = bridge.lastRequestId;
      unawaited(cubit.refresh(GitHubItemKind.pr));
      final latest = bridge.lastRequestId;
      expect(stale, isNot(latest));

      bridge.responses.add(
        _list(bridge, GitHubItemKind.pr, [_pr(1)], requestId: stale),
      );
      expect(cubit.state.prs.loaded, isFalse);
      expect(cubit.state.prs.loading, isTrue);

      bridge.responses.add(
        _list(bridge, GitHubItemKind.pr, [_pr(2)], requestId: latest),
      );
      expect(cubit.state.prs.items.single.number, 2);

      // A duplicate of an already answered request changes nothing.
      bridge.responses.add(
        _list(bridge, GitHubItemKind.pr, [_pr(3)], requestId: latest),
      );
      expect(cubit.state.prs.items.single.number, 2);
    });

    test('rejects a response for another project, kind, or request', () {
      unawaited(cubit.refresh(GitHubItemKind.pr));
      final requestId = bridge.lastRequestId;

      bridge.responses
        ..add(
          _list(bridge, GitHubItemKind.pr, [
            _pr(1),
          ], projectPath: '/work/other'),
        )
        ..add(_list(bridge, GitHubItemKind.issue, [_pr(1)]))
        ..add(
          _list(bridge, GitHubItemKind.pr, [_pr(1)], requestId: 'unknown-9'),
        )
        ..add(
          GitHubListResultMessage(
            projectPath: _project,
            kind: GitHubItemKind.pr,
            items: [_pr(1)],
          ),
        );

      expect(cubit.state.prs.loaded, isFalse);
      expect(cubit.state.prs.loading, isTrue);
      expect(cubit.state.issues.loaded, isFalse);

      bridge.responses.add(
        _list(bridge, GitHubItemKind.pr, [_pr(4)], requestId: requestId),
      );
      expect(cubit.state.prs.items.single.number, 4);
    });

    test('two projects only accept their own results', () async {
      final other = GitHubListCubit(bridge: bridge, projectPath: '/work/b');
      addTearDown(other.close);
      unawaited(cubit.refresh(GitHubItemKind.pr));
      final first = bridge.lastRequestId;
      unawaited(other.refresh(GitHubItemKind.pr));
      final second = bridge.lastRequestId;

      // Delivered in reverse order.
      bridge.responses
        ..add(
          _list(
            bridge,
            GitHubItemKind.pr,
            [_pr(20)],
            requestId: second,
            projectPath: '/work/b',
          ),
        )
        ..add(_list(bridge, GitHubItemKind.pr, [_pr(10)], requestId: first));

      expect(cubit.state.prs.items.single.number, 10);
      expect(other.state.prs.items.single.number, 20);
    });
  });

  group('GitHubListCubit errors', () {
    for (final (code, kind) in [
      (GitHubError.ghMissing, GitHubFailureKind.ghMissing),
      (GitHubError.ghUnauthenticated, GitHubFailureKind.ghUnauthenticated),
      (GitHubError.notGithub, GitHubFailureKind.notGithub),
      (GitHubError.failed, GitHubFailureKind.failed),
      ('something_new', GitHubFailureKind.failed),
    ]) {
      test('maps $code', () {
        unawaited(cubit.refresh(GitHubItemKind.pr));
        bridge.responses.add(
          _list(
            bridge,
            GitHubItemKind.pr,
            const [],
            error: GitHubError(code: code, message: 'details'),
          ),
        );

        expect(cubit.state.prs.loading, isFalse);
        expect(cubit.state.prs.loaded, isFalse);
        expect(cubit.state.prs.failure?.kind, kind);
        expect(cubit.state.prs.failure?.message, 'details');
      });
    }

    test('an older Bridge answering unsupported_message is reported', () {
      unawaited(cubit.refresh(GitHubItemKind.pr));
      unawaited(cubit.refresh(GitHubItemKind.issue));

      // Unrelated unsupported messages are not ours.
      bridge.responses.add(
        const ErrorMessage(
          message: 'list_directory',
          errorCode: 'unsupported_message',
        ),
      );
      expect(cubit.state.prs.failure, isNull);

      bridge.responses.add(
        const ErrorMessage(
          message: 'github_list',
          errorCode: 'unsupported_message',
        ),
      );

      expect(cubit.state.prs.failure?.kind, GitHubFailureKind.unsupported);
      expect(cubit.state.issues.failure?.kind, GitHubFailureKind.unsupported);
      expect(cubit.state.prs.loading, isFalse);
      expect(cubit.state.issues.loading, isFalse);
    });

    test('unsupported_message without a pending request is ignored', () {
      bridge.responses.add(
        const ErrorMessage(
          message: 'github_list',
          errorCode: 'unsupported_message',
        ),
      );
      expect(cubit.state.prs.failure, isNull);
    });

    test('a correlated generic error clears the pending request', () {
      unawaited(cubit.refresh(GitHubItemKind.pr));
      bridge.responses
        ..add(const ErrorMessage(message: 'other', requestId: 'git-status-3'))
        ..add(ErrorMessage(message: 'boom', requestId: bridge.lastRequestId));

      expect(cubit.state.prs.loading, isFalse);
      expect(cubit.state.prs.failure?.kind, GitHubFailureKind.failed);
      expect(cubit.state.prs.failure?.message, 'boom');
    });

    test('times out when the Bridge never answers', () async {
      final quick = GitHubListCubit(
        bridge: bridge,
        projectPath: _project,
        timeout: const Duration(milliseconds: 10),
      );
      addTearDown(quick.close);

      await quick.refresh(GitHubItemKind.pr);

      expect(quick.state.prs.loading, isFalse);
      expect(quick.state.prs.failure?.kind, GitHubFailureKind.timeout);
    });

    test('a disconnect fails the pending request and a retry recovers', () {
      unawaited(cubit.refresh(GitHubItemKind.pr));
      final lost = bridge.lastRequestId;

      // A new connection attempt alone is not a loss.
      bridge.setConnection(BridgeConnectionState.connecting);
      expect(cubit.state.prs.loading, isTrue);

      bridge.setConnection(BridgeConnectionState.disconnected);
      expect(cubit.state.prs.loading, isFalse);
      expect(cubit.state.prs.failure?.kind, GitHubFailureKind.disconnected);

      // Requesting while offline fails at once instead of waiting.
      unawaited(cubit.refresh(GitHubItemKind.pr));
      expect(cubit.state.prs.loading, isFalse);
      expect(cubit.state.prs.failure?.kind, GitHubFailureKind.disconnected);
      final offline = bridge.lastRequestId;

      bridge.setConnection(BridgeConnectionState.connected);
      unawaited(cubit.refresh(GitHubItemKind.pr));
      expect(cubit.state.prs.loading, isTrue);
      expect(cubit.state.prs.failure, isNull);

      // Answers to the requests of the lost transport are ignored.
      bridge.responses
        ..add(_list(bridge, GitHubItemKind.pr, [_pr(1)], requestId: lost))
        ..add(_list(bridge, GitHubItemKind.pr, [_pr(2)], requestId: offline));
      expect(cubit.state.prs.loaded, isFalse);

      bridge.responses.add(_list(bridge, GitHubItemKind.pr, [_pr(3)]));
      expect(cubit.state.prs.items.single.number, 3);
      expect(cubit.state.prs.failure, isNull);
    });

    test('a reconnecting transport also fails the pending request', () {
      unawaited(cubit.refresh(GitHubItemKind.issue));
      bridge.setConnection(BridgeConnectionState.reconnecting);
      expect(cubit.state.issues.loading, isFalse);
      expect(cubit.state.issues.failure?.kind, GitHubFailureKind.disconnected);
    });

    test('GitHub reads are not queued for replay while offline', () async {
      SharedPreferences.setMockInitialValues({});
      final offline = BridgeService();
      addTearDown(offline.dispose);

      offline
        ..requestGitHubList(projectPath: _project, kind: GitHubItemKind.pr)
        ..requestGitHubItem(
          projectPath: _project,
          kind: GitHubItemKind.pr,
          number: 1,
        )
        // Other offline requests are still kept for the reconnect.
        ..send(ClientMessage.listWorktrees(_project));

      expect(offline.debugQueuedMessageTypes, ['list_worktrees']);
    });

    test('a failed refresh keeps the last list and a retry clears it', () {
      unawaited(cubit.refresh(GitHubItemKind.pr));
      bridge.responses.add(_list(bridge, GitHubItemKind.pr, [_pr(1)]));
      unawaited(cubit.refresh(GitHubItemKind.pr));
      bridge.responses.add(
        _list(
          bridge,
          GitHubItemKind.pr,
          const [],
          error: const GitHubError(code: GitHubError.failed),
        ),
      );

      expect(cubit.state.prs.loaded, isTrue);
      expect(cubit.state.prs.items.single.number, 1);
      expect(cubit.state.prs.failure, isNotNull);

      unawaited(cubit.refresh(GitHubItemKind.pr));
      bridge.responses.add(_list(bridge, GitHubItemKind.pr, [_pr(2)]));
      expect(cubit.state.prs.failure, isNull);
      expect(cubit.state.prs.items.single.number, 2);
    });
  });

  group('GitHubListCubit filters', () {
    setUp(() {
      unawaited(cubit.refresh(GitHubItemKind.pr));
      bridge.responses.add(
        _list(bridge, GitHubItemKind.pr, [
          _pr(1, labels: ['bug']),
          _pr(2, draft: true),
          _pr(3, dependabot: true, labels: ['dependencies']),
          _pr(4, dependabot: true, draft: true, labels: ['dependencies']),
        ]),
      );
      unawaited(cubit.refresh(GitHubItemKind.issue));
      bridge.responses.add(
        _list(bridge, GitHubItemKind.issue, [
          _pr(10, labels: ['bug']),
          _pr(11, draft: true, dependabot: true),
        ]),
      );
    });

    List<int> visible(GitHubItemKind kind) =>
        cubit.state.visibleItems(kind).map((item) => item.number).toList();

    test('hide drafts', () {
      cubit.setHideDrafts(true);
      expect(visible(GitHubItemKind.pr), [1, 3]);
    });

    test('dependabot only', () {
      cubit.setDependabotOnly(true);
      expect(visible(GitHubItemKind.pr), [3, 4]);
      cubit.setHideDrafts(true);
      expect(visible(GitHubItemKind.pr), [3]);
    });

    test('draft and dependabot filters do not apply to issues', () {
      cubit
        ..setHideDrafts(true)
        ..setDependabotOnly(true);
      expect(visible(GitHubItemKind.issue), [10, 11]);
    });

    test('label filter applies to both tabs and lists known labels', () {
      expect(cubit.state.availableLabels(GitHubItemKind.pr), [
        'bug',
        'dependencies',
      ]);
      cubit.setLabel('bug');
      expect(visible(GitHubItemKind.pr), [1]);
      expect(visible(GitHubItemKind.issue), [10]);
      cubit.setLabel(null);
      expect(visible(GitHubItemKind.pr), [1, 2, 3, 4]);
    });

    test('a label that disappears after a refresh is cleared', () {
      cubit.setLabel('bug');
      unawaited(cubit.refresh(GitHubItemKind.pr));
      bridge.responses.add(_list(bridge, GitHubItemKind.pr, [_pr(2)]));
      expect(cubit.state.filters.label, 'bug', reason: 'issues still use it');

      unawaited(cubit.refresh(GitHubItemKind.issue));
      bridge.responses.add(_list(bridge, GitHubItemKind.issue, [_pr(11)]));
      expect(cubit.state.filters.label, isNull);
    });
  });

  group('GitHubListCubit selection', () {
    setUp(() {
      unawaited(cubit.refresh(GitHubItemKind.pr));
      bridge.responses.add(
        _list(bridge, GitHubItemKind.pr, [
          _pr(342),
          _pr(340, draft: true),
          _pr(338, dependabot: true),
        ]),
      );
    });

    test('long press starts multi-select and taps toggle', () {
      cubit.startSelection(342);
      expect(cubit.state.selectionMode, isTrue);
      expect(cubit.state.selected, {342});

      cubit.toggleSelected(338);
      expect(cubit.state.selectedNumbers, [338, 342]);
      cubit.toggleSelected(342);
      expect(cubit.state.selected, {338});
    });

    test('select all skips drafts, which stay selectable one by one', () {
      cubit.startSelection(342);
      cubit.selectAllVisible(GitHubItemKind.pr);
      expect(cubit.state.selectedNumbers, [338, 342]);

      cubit.toggleSelected(340);
      expect(cubit.state.selectedNumbers, [338, 340, 342]);

      // Selecting all again keeps a draft that was picked on purpose.
      cubit.selectAllVisible(GitHubItemKind.pr);
      expect(cubit.state.selectedNumbers, [338, 340, 342]);
    });

    test('select all only adds what the filters show', () {
      cubit
        ..setDependabotOnly(true)
        ..selectAllVisible(GitHubItemKind.pr);
      expect(cubit.state.selected, {338});
    });

    test('clearing leaves multi-select', () {
      cubit
        ..startSelection(342)
        ..clearSelection();
      expect(cubit.state.selectionMode, isFalse);
      expect(cubit.state.selected, isEmpty);
    });

    test('items that left the list are dropped from the selection', () {
      unawaited(cubit.refresh(GitHubItemKind.issue));
      bridge.responses.add(_list(bridge, GitHubItemKind.issue, [_pr(327)]));
      cubit
        ..startSelection(342)
        ..toggleSelected(338)
        ..toggleSelected(327);

      unawaited(cubit.refresh(GitHubItemKind.pr));
      bridge.responses.add(_list(bridge, GitHubItemKind.pr, [_pr(342)]));

      expect(cubit.state.selectedNumbers, [327, 342]);
    });
  });

  group('GitHubItemCubit', () {
    GitHubItemCubit open() {
      final item = GitHubItemCubit(
        bridge: bridge,
        projectPath: _project,
        kind: GitHubItemKind.issue,
        summary: _pr(327),
      );
      addTearDown(item.close);
      return item;
    }

    GitHubItemResultMessage result({
      String? requestId,
      int number = 327,
      GitHubItemKind kind = GitHubItemKind.issue,
      String projectPath = _project,
      GitHubError? error,
    }) => GitHubItemResultMessage(
      requestId: requestId ?? bridge.lastRequestId,
      projectPath: projectPath,
      kind: kind,
      number: number,
      item: error == null
          ? GitHubItemDetail(summary: _pr(number), body: 'Body $number')
          : null,
      error: error,
    );

    test('requests the item and applies the matching detail', () {
      final item = open();
      expect(bridge.sent.single['type'], 'github_item');
      expect(bridge.sent.single['number'], 327);
      expect(item.state.loading, isTrue);

      bridge.responses.add(result());

      expect(item.state.loading, isFalse);
      expect(item.state.detail?.body, 'Body 327');
    });

    test('rejects mismatched results', () {
      final item = open();
      bridge.responses
        ..add(result(requestId: 'github-item-999'))
        ..add(result(number: 1))
        ..add(result(kind: GitHubItemKind.pr))
        ..add(result(projectPath: '/work/other'));

      expect(item.state.loading, isTrue);
      expect(item.state.detail, isNull);
    });

    test('reports typed errors and retries', () {
      final item = open();
      bridge.responses.add(
        result(error: const GitHubError(code: GitHubError.ghMissing)),
      );
      expect(item.state.failure?.kind, GitHubFailureKind.ghMissing);

      item.load();
      expect(item.state.failure, isNull);
      bridge.responses.add(result());
      expect(item.state.detail?.body, 'Body 327');
    });

    test('a disconnect fails the pending item and a retry recovers', () {
      final item = open();
      bridge.setConnection(BridgeConnectionState.disconnected);
      expect(item.state.loading, isFalse);
      expect(item.state.failure?.kind, GitHubFailureKind.disconnected);

      item.load();
      expect(item.state.failure?.kind, GitHubFailureKind.disconnected);

      bridge.setConnection(BridgeConnectionState.connected);
      item.load();
      expect(item.state.loading, isTrue);
      bridge.responses.add(result());
      expect(item.state.detail?.body, 'Body 327');
    });

    test('an older Bridge answering unsupported_message is reported', () {
      final item = open();
      bridge.responses.add(
        const ErrorMessage(
          message: 'github_item',
          errorCode: 'unsupported_message',
        ),
      );
      expect(item.state.loading, isFalse);
      expect(item.state.failure?.kind, GitHubFailureKind.unsupported);
    });
  });

  group('GitHubViewCacheService', () {
    test('keeps one cubit per project for its own Bridge', () async {
      final cache = GitHubViewCacheService(bridge: bridge);
      addTearDown(cache.dispose);

      final first = cache.getOrCreate(_project);
      final again = cache.getOrCreate(_project);
      final other = cache.getOrCreate('/work/b');

      expect(first.created, isTrue);
      expect(again.created, isFalse);
      expect(again.cubit, same(first.cubit));
      expect(other.cubit, isNot(same(first.cubit)));
      expect(cache.serves(bridge), isTrue);

      final foreign = _Bridge();
      addTearDown(foreign.dispose);
      expect(cache.serves(foreign), isFalse);
    });
  });

  group('triage prompt', () {
    test('the default preset adds nothing after the numbers', () {
      expect(buildTriagePrompt(numbers: [327, 332]), '/triage 327 332');
    });

    test('appends the preset instruction and trimmed free text', () {
      expect(
        buildTriagePrompt(
          numbers: [327, 332],
          preset: TriagePreset.handleAndRelease,
        ),
        '/triage 327 332 対応してリリースまで',
      );
      expect(
        buildTriagePrompt(
          numbers: [5],
          preset: TriagePreset.contentOnly,
          note: '  英語で  ',
        ),
        '/triage 5 内容だけ教えて 英語で',
      );
      expect(
        buildTriagePrompt(
          numbers: [5],
          preset: TriagePreset.checkResolvedAndClose,
        ),
        '/triage 5 解決済みか確認してコメントしてクローズ',
      );
      expect(
        buildTriagePrompt(numbers: [5], note: 'squash merge'),
        '/triage 5 squash merge',
      );
    });

    test('is empty without a selection', () {
      expect(buildTriagePrompt(numbers: const [], note: 'x'), isEmpty);
    });

    test('uses the trigger of the agent that starts the session', () {
      const prompt = '/triage 327 332 対応してリリースまで';
      expect(triagePromptForProvider(prompt, Provider.claude), prompt);
      expect(
        triagePromptForProvider(prompt, Provider.codex),
        r'$triage 327 332 対応してリリースまで',
      );
    });
  });

  group('empty chat entry visibility', () {
    const idle = ChatSessionState(
      status: ProcessStatus.idle,
      sessionContextLoaded: true,
    );
    final assistant = ServerChatEntry(
      AssistantServerMessage(
        message: AssistantMessage(
          id: 'a1',
          role: 'assistant',
          content: const [TextContent(text: 'Hello')],
          model: 'mock',
        ),
      ),
    );
    final system = ServerChatEntry(
      const SystemMessage(subtype: 'init', sessionId: 's1'),
    );

    test('shown for an empty idle chat', () {
      expect(showsEmptyChatGitHubEntry(idle), isTrue);
    });

    test('assistant-only and system entries do not hide it', () {
      expect(
        showsEmptyChatGitHubEntry(idle.copyWith(entries: [system, assistant])),
        isTrue,
      );
    });

    test('hidden once any user message exists', () {
      for (final status in MessageStatus.values) {
        expect(
          showsEmptyChatGitHubEntry(
            idle.copyWith(
              entries: [
                system,
                UserChatEntry('hi', status: status),
              ],
            ),
          ),
          isFalse,
          reason: '$status',
        );
      }
    });

    test('hidden while an input is queued or pending delivery', () {
      expect(
        showsEmptyChatGitHubEntry(
          idle.copyWith(
            queuedInput: const QueuedInputItem(
              itemId: 'q1',
              text: 'later',
              createdAt: '2026-11-16T00:00:00Z',
            ),
          ),
        ),
        isFalse,
      );
    });

    test('hidden until the session is idle and its context has arrived', () {
      expect(showsEmptyChatGitHubEntry(const ChatSessionState()), isFalse);
      expect(
        showsEmptyChatGitHubEntry(idle.copyWith(status: ProcessStatus.running)),
        isFalse,
      );
      expect(
        showsEmptyChatGitHubEntry(
          const ChatSessionState(status: ProcessStatus.idle),
        ),
        isFalse,
        reason: 'a resumed session has no entries before its context',
      );
    });

    test('hidden when earlier turns were trimmed from the live history', () {
      expect(
        showsEmptyChatGitHubEntry(
          idle.copyWith(entries: [assistant], olderHistoryAvailable: true),
        ),
        isFalse,
      );
    });
  });

  group('sending from an empty chat', () {
    late MockBridgeService service;
    late StreamingStateCubit streaming;

    setUp(() {
      service = MockBridgeService();
      streaming = StreamingStateCubit();
      addTearDown(() async {
        await streaming.close();
        service.dispose();
      });
    });

    Future<ChatSessionCubit> session(Provider provider) async {
      final chat = ChatSessionCubit(
        sessionId: 's1',
        provider: provider,
        bridge: service,
        streamingCubit: streaming,
        initialProjectPath: _project,
      );
      addTearDown(chat.close);
      service.loadHistory(const [StatusMessage(status: ProcessStatus.idle)]);
      await Future<void>.delayed(Duration.zero);
      return chat;
    }

    List<String> userTexts(ChatSessionCubit chat) => [
      for (final entry in chat.state.entries)
        if (entry is UserChatEntry) entry.text,
    ];

    test('Codex gets the dollar trigger without a skill list', () async {
      final chat = await session(Provider.codex);
      expect(chat.state.slashCommands, isEmpty);
      expect(showsEmptyChatGitHubEntry(chat.state), isTrue);

      expect(await sendTriageAsFirstMessage(chat, '/triage 5 6'), isTrue);
      expect(userTexts(chat), [r'$triage 5 6']);
    });

    test('Claude keeps the slash trigger', () async {
      final chat = await session(Provider.claude);
      expect(await sendTriageAsFirstMessage(chat, '/triage 5'), isTrue);
      expect(userTexts(chat), ['/triage 5']);
    });

    test('refuses once the chat is no longer empty', () async {
      final chat = await session(Provider.claude);
      expect(await chat.sendMessage('hello'), isTrue);

      expect(await sendTriageAsFirstMessage(chat, '/triage 5'), isFalse);
      expect(userTexts(chat), ['hello']);
    });

    test('refuses when the session is not ready or is closed', () async {
      final starting = ChatSessionCubit(
        sessionId: 's2',
        provider: Provider.claude,
        bridge: service,
        streamingCubit: streaming,
      );
      expect(await sendTriageAsFirstMessage(starting, '/triage 5'), isFalse);
      expect(userTexts(starting), isEmpty);

      await starting.close();
      expect(await sendTriageAsFirstMessage(starting, '/triage 5'), isFalse);
    });
  });

  group('GitHubScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required BridgeService service,
      required String projectPath,
      GitHubTriageSubmit? onSubmitTriage,
      GitHubViewCacheService? cache,
      GitHubTriageTarget target = GitHubTriageTarget.newSession,
    }) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<BridgeService>.value(value: service),
            if (cache != null)
              RepositoryProvider<GitHubViewCacheService>.value(value: cache),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.lightTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GitHubScreen(
              projectPath: projectPath,
              triageTarget: target,
              embedded: true,
              onSubmitTriage: onSubmitTriage ?? (_) async => true,
            ),
          ),
        ),
      );
      // The mock Bridge answers after a short delay.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    }

    testWidgets('lists PRs, selects all but drafts, and composes the request', (
      tester,
    ) async {
      final service = MockBridgeService();
      addTearDown(service.dispose);
      String? submitted;
      await pumpScreen(
        tester,
        service: service,
        projectPath: MockGitHubProjects.repository,
        onSubmitTriage: (prompt) async {
          submitted = prompt;
          return true;
        },
        target: GitHubTriageTarget.currentSession,
      );

      // Issues is the first tab.
      expect(find.byKey(const ValueKey('github_item_341')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('github_tab_prs')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('github_item_342')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('github_draft_badge_340')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('github_dependabot_badge_338')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('github_checks_335')), findsOneWidget);

      await tester.longPress(find.byKey(const ValueKey('github_item_342')));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('github_select_all_button')));
      await tester.pumpAndSettle();
      expect(find.text('4 selected'), findsOneWidget, reason: 'draft skipped');

      await tester.tap(
        find.byKey(const ValueKey('github_request_triage_button')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('github_triage_preview')))
            .data,
        '/triage 331 335 338 342',
      );

      await tester.tap(
        find.byKey(const ValueKey('github_triage_preset_handleAndRelease')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('github_triage_note_field')),
        'squash',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('github_triage_send_button')));
      await tester.pumpAndSettle();

      expect(submitted, '/triage 331 335 338 342 対応してリリースまで squash');
      expect(find.byKey(const ValueKey('github_selected_count')), findsNothing);
    });

    testWidgets('a rejected request keeps the sheet open with an error', (
      tester,
    ) async {
      final service = MockBridgeService();
      addTearDown(service.dispose);
      var accept = false;
      final prompts = <String>[];
      await pumpScreen(
        tester,
        service: service,
        projectPath: MockGitHubProjects.repository,
        target: GitHubTriageTarget.currentSession,
        onSubmitTriage: (prompt) async {
          prompts.add(prompt);
          return accept;
        },
      );
      await tester.longPress(find.byKey(const ValueKey('github_item_341')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('github_request_triage_button')),
      );
      await tester.pumpAndSettle();

      final send = find.byKey(const ValueKey('github_triage_send_button'));
      final error = find.byKey(const ValueKey('github_triage_send_error'));
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(send, findsOneWidget, reason: 'sheet stays open');
      expect(error, findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget, reason: 'selection kept');

      accept = true;
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(send, findsNothing);
      expect(prompts, ['/triage 341', '/triage 341']);
      expect(find.byKey(const ValueKey('github_selected_count')), findsNothing);
    });

    testWidgets('closing the screen drops the selection but keeps the cache', (
      tester,
    ) async {
      final service = MockBridgeService();
      addTearDown(service.dispose);
      final cache = GitHubViewCacheService(bridge: service);
      addTearDown(cache.dispose);
      await pumpScreen(
        tester,
        service: service,
        projectPath: MockGitHubProjects.repository,
        cache: cache,
      );
      await tester.longPress(find.byKey(const ValueKey('github_item_341')));
      await tester.pumpAndSettle();
      final cached = cache.getOrCreate(MockGitHubProjects.repository).cubit;
      expect(cached.state.selected, {341});

      // Any way of leaving the screen disposes it (pane close button, back).
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));

      expect(cached.isClosed, isFalse);
      expect(cached.state.selectionMode, isFalse);
      expect(cached.state.selected, isEmpty);
      expect(cached.state.issues.items, isNotEmpty);
    });

    testWidgets('the refresh button stays usable while a request is stuck', (
      tester,
    ) async {
      final stuck = _Bridge();
      addTearDown(stuck.dispose);
      await pumpScreen(tester, service: stuck, projectPath: _project);
      expect(stuck.sent, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('github_refresh_button')));
      await tester.pump();

      expect(stuck.sent, hasLength(2));
      // Unmount before the fake Bridge is disposed.
      await tester.pumpWidget(const SizedBox());
    });

    for (final (projectPath, key, text) in [
      (
        MockGitHubProjects.ghMissing,
        'github_error_ghMissing',
        'GitHub CLI not found',
      ),
      (
        MockGitHubProjects.ghUnauthenticated,
        'github_error_ghUnauthenticated',
        'gh auth login',
      ),
      (
        MockGitHubProjects.notGithub,
        'github_error_notGithub',
        'Not a GitHub repository',
      ),
      (MockGitHubProjects.failed, 'github_error_failed', 'HTTP 502'),
      (
        MockGitHubProjects.oldBridge,
        'github_error_unsupported',
        'Bridge update required',
      ),
    ]) {
      testWidgets('explains $key inside the screen', (tester) async {
        final service = MockBridgeService();
        addTearDown(service.dispose);
        await pumpScreen(tester, service: service, projectPath: projectPath);

        expect(find.byKey(ValueKey(key)), findsOneWidget);
        expect(find.textContaining(text), findsWidgets);
        expect(find.byKey(const ValueKey('github_retry_button')), findsOne);
      });
    }
  });
}
