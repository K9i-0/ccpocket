import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/session_list/state/recent_session_filters.dart';
import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/features/session_list/state/session_list_state.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/new_session_tab.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal mock for SessionListCubit tests.
class MockBridgeService extends BridgeService {
  final _recentSessionsController =
      StreamController<List<RecentSession>>.broadcast();
  final _projectHistoryController = StreamController<List<String>>.broadcast();
  final _messageController = StreamController<ServerMessage>.broadcast();
  final sentMessages = <ClientMessage>[];
  List<RecentSessionRef>? pushedPins;
  Set<String> pinnedExtraIds = {};

  @override
  void setPinnedRecentSessions(Iterable<RecentSessionRef> pins) {
    pushedPins = pins.toList();
    super.setPinnedRecentSessions(pins);
  }

  @override
  bool isPinnedRecentExtra(RecentSession session) =>
      pinnedExtraIds.contains(session.sessionId);

  bool _hasMore = false;
  String? _projectFilter;
  RecentSessionsMessage? _lastRecentSessionsMessage;

  @override
  Stream<List<RecentSession>> get recentSessionsStream =>
      _recentSessionsController.stream;

  @override
  Stream<List<String>> get projectHistoryStream =>
      _projectHistoryController.stream;

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  bool get recentSessionsHasMore => _hasMore;
  set recentSessionsHasMore(bool v) => _hasMore = v;

  @override
  RecentSessionsMessage? get lastRecentSessionsMessage =>
      _lastRecentSessionsMessage;

  @override
  String? get currentProjectFilter => _projectFilter;

  void emitSessions(List<RecentSession> sessions, {bool hasMore = false}) {
    _hasMore = hasMore;
    _lastRecentSessionsMessage = RecentSessionsMessage(
      sessions: sessions,
      hasMore: hasMore,
    );
    _recentSessionsController.add(sessions);
  }

  void emitProjectSessions(
    String projectPath,
    List<RecentSession> sessions, {
    bool hasMore = false,
  }) {
    _lastRecentSessionsMessage = RecentSessionsMessage(
      sessions: sessions,
      hasMore: hasMore,
      projectPath: projectPath,
      requestScope: 'project',
    );
    _recentSessionsController.add(sessions);
  }

  void emitProjectHistory(List<String> paths) {
    _projectHistoryController.add(paths);
  }

  void emitRecentSessionsFailure({
    String requestScope = 'list',
    String? projectPath,
  }) {
    _messageController.add(
      ErrorMessage(
        message: 'Recent sessions failed',
        errorCode: 'recent_sessions_failed',
        path: projectPath,
        requestScope: requestScope,
      ),
    );
  }

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  @override
  void requestSessionList() {}

  @override
  void requestRecentSessions({int? limit, int? offset, String? projectPath}) {
    sentMessages.add(
      ClientMessage.listRecentSessions(
        limit: limit,
        offset: offset,
        projectPath: projectPath,
      ),
    );
  }

  @override
  void requestProjectHistory() {}

  @override
  void loadMoreRecentSessions({
    int pageSize = 20,
    String? projectPath,
    int? offset,
    String requestScope = 'list',
  }) {
    sentMessages.add(
      ClientMessage.listRecentSessions(
        offset: offset ?? 0,
        limit: pageSize,
        projectPath: projectPath,
        requestScope: requestScope,
      ),
    );
  }

  @override
  void switchProjectFilter(String? projectPath, {int pageSize = 20}) {
    _projectFilter = projectPath;
  }

  bool supportsFilters = false;
  final _filtersAvailable = StreamController<void>.broadcast();

  @override
  Stream<void> get recentSessionFiltersAvailable => _filtersAvailable.stream;

  void announceRecentFilters() => _filtersAvailable.add(null);

  Map<String, dynamic> get lastJson =>
      jsonDecode(sentMessages.last.toJson()) as Map<String, dynamic>;
  RecentSessionsExtraFilters lastExtraFilters = RecentSessionsExtraFilters.none;

  @override
  bool get supportsRecentSessionFilters => supportsFilters;

  @override
  void switchFilter({
    String? projectPath,
    String? provider,
    bool? namedOnly,
    String? searchQuery,
    int pageSize = 20,
    RecentSessionsExtraFilters extraFilters = RecentSessionsExtraFilters.none,
  }) {
    _projectFilter = projectPath;
    lastExtraFilters = extraFilters;
    sentMessages.add(
      ClientMessage.listRecentSessions(
        limit: pageSize,
        offset: 0,
        projectPath: projectPath,
        provider: provider,
        namedOnly: namedOnly,
        searchQuery: searchQuery,
      ),
    );
  }

  @override
  void dispose() {
    _recentSessionsController.close();
    _projectHistoryController.close();
    _messageController.close();
  }
}

RecentSession _session({
  required String id,
  String projectPath = '/home/user/project-a',
  SessionWorkspaceInfo? workspace,
}) {
  return RecentSession(
    sessionId: id,
    firstPrompt: 'test prompt',
    created: '2025-01-01T00:00:00Z',
    modified: '2025-01-01T00:00:00Z',
    gitBranch: 'main',
    projectPath: projectPath,
    workspace: workspace,
    isSidechain: false,
  );
}

SessionInfo _runningSession({String? providerSessionId}) {
  return SessionInfo(
    id: 'bridge-session',
    provider: Provider.claude.value,
    projectPath: '/a/proj1',
    claudeSessionId: providerSessionId,
    status: 'idle',
    createdAt: '2025-01-01T00:00:00Z',
    lastActivityAt: '2025-01-01T00:00:00Z',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionListCubit cubit;
  late MockBridgeService mockBridge;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockBridge = MockBridgeService();
    cubit = SessionListCubit(bridge: mockBridge);
  });

  tearDown(() {
    cubit.close();
    mockBridge.dispose();
  });

  group('SessionListCubit', () {
    test('prioritizePinned keeps stable priority buckets', () {
      final ordered = prioritizePinned(
        const ['normal-a', 'project-pinned', 'session-pinned', 'normal-b'],
        isPinned: (item) => item == 'session-pinned',
        isProjectPinned: (item) => item == 'project-pinned',
      );

      expect(ordered, const [
        'session-pinned',
        'project-pinned',
        'normal-a',
        'normal-b',
      ]);
    });

    test('session and project pins are persisted', () async {
      final session = _session(id: 'pinned-session', projectPath: '/a/proj1');

      await cubit.toggleRecentSessionPinned(session);
      await cubit.toggleProjectPinned('/a/proj1');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.isRecentSessionPinned(session), isTrue);
      expect(cubit.isProjectPinned('/a/proj1'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('session_list_pinned_session_keys_v1'),
        contains(recentSessionPinKey(session)),
      );
      expect(
        prefs.getStringList('session_list_pinned_project_paths_v1'),
        contains('/a/proj1'),
      );
    });

    test('persisted session and project pins are restored', () async {
      final session = _session(id: 'restored-pin', projectPath: '/a/proj1');
      await cubit.close();
      mockBridge.dispose();
      SharedPreferences.setMockInitialValues({
        'session_list_pinned_session_keys_v1': [recentSessionPinKey(session)],
        'session_list_pinned_project_paths_v1': ['/a/proj1'],
      });
      mockBridge = MockBridgeService();
      cubit = SessionListCubit(bridge: mockBridge);

      await Future<void>.delayed(Duration.zero);

      expect(cubit.isRecentSessionPinned(session), isTrue);
      expect(cubit.isProjectPinned('/a/proj1'), isTrue);
    });

    test(
      'pin toggle waits for preference restoration before updating',
      () async {
        final restored = _session(id: 'restored-pin', projectPath: '/a/proj1');
        final added = _session(id: 'added-pin', projectPath: '/a/proj2');
        await cubit.close();
        mockBridge.dispose();
        SharedPreferences.setMockInitialValues({
          'session_list_pinned_session_keys_v1': [
            recentSessionPinKey(restored),
          ],
        });
        mockBridge = MockBridgeService();
        cubit = SessionListCubit(bridge: mockBridge);

        await cubit.toggleRecentSessionPinned(added);

        expect(cubit.isRecentSessionPinned(restored), isTrue);
        expect(cubit.isRecentSessionPinned(added), isTrue);
      },
    );

    test('pin toggles push provider session refs to the bridge', () async {
      final claude = _session(id: 'claude-pin', projectPath: '/a/proj1');
      final codex = RecentSession(
        sessionId: 'codex-pin',
        provider: 'codex',
        firstPrompt: 'p',
        created: '2025-01-01T00:00:00Z',
        modified: '2025-01-01T00:00:00Z',
        gitBranch: 'main',
        projectPath: '/a/proj2',
        isSidechain: false,
      );

      await cubit.toggleRecentSessionPinned(claude);
      await cubit.toggleRecentSessionPinned(codex);
      expect(
        mockBridge.pushedPins,
        unorderedEquals([
          (provider: 'claude', sessionId: 'claude-pin'),
          (provider: 'codex', sessionId: 'codex-pin'),
        ]),
      );

      await cubit.toggleRecentSessionPinned(claude);
      expect(mockBridge.pushedPins, [
        (provider: 'codex', sessionId: 'codex-pin'),
      ]);
    });

    test(
      'restored pins are pushed and re-request a page sent before restore',
      () async {
        final session = _session(id: 'restored-pin', projectPath: '/a/proj1');
        await cubit.close();
        mockBridge.dispose();
        SharedPreferences.setMockInitialValues({
          'session_list_pinned_session_keys_v1': [recentSessionPinKey(session)],
        });
        mockBridge = MockBridgeService();
        cubit = SessionListCubit(bridge: mockBridge);

        // Connect-time refresh can run before preferences finish loading.
        cubit.refresh();
        int listRequests() => mockBridge.sentMessages
            .where((m) => m.type == 'list_recent_sessions')
            .length;
        expect(listRequests(), 1);
        expect(mockBridge.pushedPins, isNull);

        await Future<void>.delayed(Duration.zero);

        expect(mockBridge.pushedPins, [
          (provider: 'claude', sessionId: 'restored-pin'),
        ]);
        expect(listRequests(), 2);
      },
    );

    test('restoring without pins does not re-request the list', () async {
      cubit.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(mockBridge.pushedPins, isEmpty);
      expect(
        mockBridge.sentMessages.where((m) => m.type == 'list_recent_sessions'),
        hasLength(1),
      );
    });

    test('pin key parsing extracts provider and session id', () {
      expect(
        recentSessionRefFromPinKey(
          sessionPinKey(
            provider: 'codex',
            projectPath: '/a/proj',
            sessionId: 'thread-1',
          ),
        ),
        (provider: 'codex', sessionId: 'thread-1'),
      );
      expect(recentSessionRefFromPinKey('garbage'), isNull);
      expect(recentSessionRefFromPinKey('gemini\n/a\nid'), isNull);
    });

    test(
      'running session can only be pinned after provider ID resolves',
      () async {
        final pending = _runningSession();

        await cubit.toggleRunningSessionPinned(pending);
        expect(cubit.isRunningSessionPinned(pending), isFalse);
        expect(cubit.state.pinnedSessionKeys, isEmpty);

        final resolved = _runningSession(providerSessionId: 'provider-session');
        await cubit.toggleRunningSessionPinned(resolved);

        expect(cubit.isRunningSessionPinned(resolved), isTrue);
        expect(
          runningSessionPinKey(resolved),
          sessionPinKey(
            provider: Provider.claude.value,
            projectPath: '/a/proj1',
            sessionId: 'provider-session',
          ),
        );
      },
    );

    test('initial state is empty', () {
      expect(cubit.state.sessions, isEmpty);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.isLoadingMore, isFalse);
      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.accumulatedProjectPaths, isEmpty);
    });

    test('sessions update from stream', () async {
      mockBridge.emitSessions([_session(id: 's1'), _session(id: 's2')]);
      await Future.microtask(() {});

      expect(cubit.state.sessions, hasLength(2));
      expect(cubit.state.sessions[0].sessionId, 's1');
    });

    test('hasMore reflects bridge state', () async {
      mockBridge.emitSessions([_session(id: 's1')], hasMore: true);
      await Future.microtask(() {});

      expect(cubit.state.hasMore, isTrue);
    });

    test(
      'non-project response marks loaded projects exhausted when no more pages',
      () async {
        mockBridge.emitSessions([
          _session(id: 's1', projectPath: '/a/proj1'),
          _session(id: 's2', projectPath: '/b/proj2'),
        ]);
        await Future.microtask(() {});

        expect(cubit.state.hasMore, isFalse);
        expect(cubit.state.exhaustedProjectPaths, {'/a/proj1', '/b/proj2'});
      },
    );

    test('non-project response keeps project show more available when more pages exist', () async {
      mockBridge.emitSessions([
        _session(id: 's1', projectPath: '/a/proj1'),
      ], hasMore: true);
      await Future.microtask(() {});

      expect(cubit.state.hasMore, isTrue);
      expect(cubit.state.exhaustedProjectPaths, isEmpty);
    });

    test('sessions update accumulates project paths', () async {
      mockBridge.emitSessions([
        _session(id: 's1', projectPath: '/a/proj1'),
        _session(id: 's2', projectPath: '/b/proj2'),
      ]);
      await Future.microtask(() {});

      expect(cubit.state.accumulatedProjectPaths, {'/a/proj1', '/b/proj2'});
    });

    test('project history merges into accumulated paths', () async {
      // First, emit sessions to set some paths
      mockBridge.emitSessions([_session(id: 's1', projectPath: '/a/proj1')]);
      await Future.microtask(() {});

      // Then, project history adds more
      mockBridge.emitProjectHistory(['/a/proj1', '/c/proj3']);
      await Future.microtask(() {});

      expect(cubit.state.accumulatedProjectPaths, {'/a/proj1', '/c/proj3'});
    });

    test('selectProject triggers server re-fetch with isInitialLoading', () {
      cubit.selectProject('/a/proj1');

      expect(cubit.state.isInitialLoading, isTrue);
      expect(mockBridge.sentMessages, isNotEmpty);
    });

    test('selectProject(null) triggers re-fetch', () {
      cubit.selectProject('/a/proj1');
      mockBridge.sentMessages.clear();
      cubit.selectProject(null);

      expect(cubit.state.isInitialLoading, isTrue);
      expect(mockBridge.sentMessages, isNotEmpty);
    });

    test('setSearchQuery updates query', () {
      cubit.setSearchQuery('hello');

      expect(cubit.state.searchQuery, 'hello');
    });

    test('setSearchQuery triggers server request after debounce', () async {
      cubit.setSearchQuery('hello');

      // Before debounce, no server request yet (beyond initial state)
      final beforeDebounce = mockBridge.sentMessages.length;

      // Wait for debounce
      await Future.delayed(const Duration(milliseconds: 350));

      expect(mockBridge.sentMessages.length, greaterThan(beforeDebounce));
      expect(cubit.state.isInitialLoading, isTrue);
    });

    test('toggleProviderFilter triggers server re-fetch', () {
      cubit.toggleProviderFilter();

      expect(cubit.state.providerFilter, isNot(equals(null)));
      expect(cubit.state.isInitialLoading, isTrue);
      expect(mockBridge.sentMessages, isNotEmpty);
    });

    test('enabled agents constrain provider filter', () {
      cubit.applyEnabledAgents(const [NewSessionTab.codex]);

      expect(cubit.state.providerFilter, ProviderFilter.codex);
      expect(
        mockBridge.sentMessages.last.toJson(),
        contains('"provider":"codex"'),
      );

      mockBridge.sentMessages.clear();
      cubit.toggleProviderFilter(
        allowedFilters: providerFiltersForEnabledTabs(const [
          NewSessionTab.codex,
        ]),
      );

      expect(cubit.state.providerFilter, ProviderFilter.codex);
      expect(mockBridge.sentMessages, isEmpty);
    });

    test('toggleNamedOnly triggers server re-fetch', () {
      cubit.toggleNamedOnly();

      expect(cubit.state.namedOnly, isTrue);
      expect(cubit.state.isInitialLoading, isTrue);
      expect(mockBridge.sentMessages, isNotEmpty);
    });

    test('loadMore sets isLoadingMore and calls bridge', () async {
      cubit.loadMore();

      expect(cubit.state.isLoadingMore, isTrue);
      expect(mockBridge.sentMessages, isNotEmpty);
    });

    test('loadMore isLoadingMore resets when sessions arrive', () async {
      cubit.loadMore();
      expect(cubit.state.isLoadingMore, isTrue);

      // Sessions arrive, clearing loading state
      mockBridge.emitSessions([_session(id: 's1')]);
      await Future.microtask(() {});

      expect(cubit.state.isLoadingMore, isFalse);
    });

    test(
      'recent sessions failure stops loading without clearing rows',
      () async {
        mockBridge.emitSessions([_session(id: 'existing')], hasMore: true);
        await Future.microtask(() {});
        cubit.loadMore();
        expect(cubit.state.isLoadingMore, isTrue);

        mockBridge.emitRecentSessionsFailure();
        await Future.microtask(() {});

        expect(cubit.state.isInitialLoading, isFalse);
        expect(cubit.state.isLoadingMore, isFalse);
        expect(cubit.state.sessions.single.sessionId, 'existing');
      },
    );

    test(
      'project recent sessions failure only clears that project loader',
      () async {
        mockBridge.emitSessions([
          _session(id: 'one', projectPath: '/a/project'),
        ], hasMore: true);
        await Future.microtask(() {});
        cubit.loadMoreProject('/a/project');
        expect(cubit.state.loadingProjectPaths, contains('/a/project'));

        mockBridge.emitRecentSessionsFailure(
          requestScope: 'project',
          projectPath: '/a/project',
        );
        await Future.microtask(() {});

        expect(cubit.state.loadingProjectPaths, isNot(contains('/a/project')));
        expect(cubit.state.sessions.single.sessionId, 'one');
      },
    );

    test('loadMoreProject offset ignores pinned extras', () async {
      mockBridge.pinnedExtraIds = {'pinned-extra'};
      mockBridge.emitSessions([
        _session(id: 's1', projectPath: '/a/proj1'),
        _session(id: 'pinned-extra', projectPath: '/a/proj1'),
      ], hasMore: true);
      await Future.microtask(() {});

      cubit.loadMoreProject('/a/proj1');

      final json = mockBridge.sentMessages.last.toJson();
      expect(json, contains('"requestScope":"project"'));
      expect(json, contains('"offset":1'));
    });

    test(
      'loadMoreProject requests project-scoped page from current count',
      () async {
        mockBridge.emitSessions([
          _session(id: 's1', projectPath: '/a/proj1'),
          _session(id: 's2', projectPath: '/a/proj1'),
          _session(id: 's3', projectPath: '/b/proj2'),
        ], hasMore: true);
        await Future.microtask(() {});

        cubit.loadMoreProject('/a/proj1');

        expect(cubit.state.loadingProjectPaths, contains('/a/proj1'));
        expect(cubit.state.projectSessionDisplayLimits['/a/proj1'], 25);
        final json = mockBridge.sentMessages.last.toJson();
        expect(json, contains('"projectPath":"/a/proj1"'));
        expect(json, contains('"offset":2'));
        expect(json, contains('"limit":20'));
        expect(json, contains('"requestScope":"project"'));
      },
    );

    test(
      'loadMoreProject reveals already loaded hidden sessions without fetch',
      () async {
        mockBridge.emitSessions([
          for (var i = 0; i < 7; i++)
            _session(id: 's$i', projectPath: '/a/proj1'),
        ]);
        await Future.microtask(() {});

        cubit.loadMoreProject('/a/proj1');

        expect(cubit.state.projectSessionDisplayLimits['/a/proj1'], 25);
        expect(cubit.state.loadingProjectPaths, isNot(contains('/a/proj1')));
        expect(mockBridge.sentMessages, isEmpty);
      },
    );

    test(
      'loadMoreProject scopes custom Projects by stable Project id',
      () async {
        const workspace = SessionWorkspaceInfo(
          kind: 'project',
          projectId: 'project-a',
          projectName: 'Flutter apps',
          rootPaths: ['/shared/primary', '/workspace/api'],
        );
        mockBridge.emitSessions([
          _session(
            id: 's1',
            projectPath: '/shared/primary',
            workspace: workspace,
          ),
          _session(
            id: 's2',
            projectPath: '/shared/primary',
            workspace: workspace,
          ),
        ], hasMore: true);
        await Future.microtask(() {});

        cubit.loadMoreProject('project:project-a');

        final json = mockBridge.sentMessages.last.toJson();
        expect(json, contains('"projectPath":"project:project-a"'));
        expect(json, contains('"offset":2'));
        expect(cubit.state.loadingProjectPaths, contains('project:project-a'));
      },
    );

    test('custom Project response clears its stable loading key', () async {
      cubit.loadMoreProject('project:project-a');
      mockBridge._lastRecentSessionsMessage = const RecentSessionsMessage(
        sessions: [],
        hasMore: false,
        projectId: 'project-a',
        workspaceKind: 'project',
        requestScope: 'project',
      );
      mockBridge._recentSessionsController.add(const []);
      await Future.microtask(() {});

      expect(
        cubit.state.loadingProjectPaths,
        isNot(contains('project:project-a')),
      );
      expect(cubit.state.exhaustedProjectPaths, contains('project:project-a'));
    });

    test(
      'project-scoped response clears loading and marks exhausted',
      () async {
        cubit.loadMoreProject('/a/proj1');
        expect(cubit.state.loadingProjectPaths, contains('/a/proj1'));

        mockBridge.emitProjectSessions('/a/proj1', const [], hasMore: false);
        await Future.microtask(() {});

        expect(cubit.state.loadingProjectPaths, isNot(contains('/a/proj1')));
        expect(cubit.state.exhaustedProjectPaths, contains('/a/proj1'));
      },
    );

    test('toggleProjectCollapsed persists collapsed project path', () async {
      cubit.toggleProjectCollapsed('/a/proj1');
      await Future.microtask(() {});

      expect(cubit.state.collapsedProjectPaths, contains('/a/proj1'));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('session_list_collapsed_project_paths'),
        contains('/a/proj1'),
      );
    });

    test('resetFilters clears all filter state', () {
      cubit.setSearchQuery('test');

      cubit.resetFilters();

      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.accumulatedProjectPaths, isEmpty);
    });

    test('initial state has isInitialLoading true', () {
      expect(cubit.state.isInitialLoading, isTrue);
    });

    test('isInitialLoading becomes false when sessions arrive', () async {
      expect(cubit.state.isInitialLoading, isTrue);

      mockBridge.emitSessions([_session(id: 's1')]);
      await Future.microtask(() {});

      expect(cubit.state.isInitialLoading, isFalse);
    });

    test('isInitialLoading becomes false even with empty sessions', () async {
      expect(cubit.state.isInitialLoading, isTrue);

      mockBridge.emitSessions([]);
      await Future.microtask(() {});

      expect(cubit.state.isInitialLoading, isFalse);
    });

    test('resetFilters restores isInitialLoading to true', () async {
      mockBridge.emitSessions([_session(id: 's1')]);
      await Future.microtask(() {});
      expect(cubit.state.isInitialLoading, isFalse);

      cubit.resetFilters();

      expect(cubit.state.isInitialLoading, isTrue);
    });

    test('resetFilters clears sessions list', () async {
      mockBridge.emitSessions([_session(id: 's1'), _session(id: 's2')]);
      await Future.microtask(() {});
      expect(cubit.state.sessions, hasLength(2));

      cubit.resetFilters();

      expect(cubit.state.sessions, isEmpty);
    });

    test(
      'skeleton condition: sessions empty + isInitialLoading after reset',
      () async {
        // Simulate: connected, sessions loaded
        mockBridge.emitSessions([_session(id: 's1')]);
        await Future.microtask(() {});
        expect(cubit.state.sessions, isNotEmpty);
        expect(cubit.state.isInitialLoading, isFalse);

        // Simulate: disconnect → resetFilters
        cubit.resetFilters();

        // After reset, skeleton condition should be met:
        // sessions empty + isInitialLoading true
        expect(cubit.state.sessions, isEmpty);
        expect(cubit.state.isInitialLoading, isTrue);

        // Simulate: reconnect → sessions arrive again
        mockBridge.emitSessions([_session(id: 's2')]);
        await Future.microtask(() {});

        expect(cubit.state.sessions, hasLength(1));
        expect(cubit.state.isInitialLoading, isFalse);
      },
    );
  });

  group('pin identity', () {
    test('matches pins across project paths and toggles off cleanly', () async {
      // Pinned while running in a worktree; listed under the repository root.
      final worktreeKey = sessionPinKey(
        provider: 'claude',
        projectPath: '/repo/.worktrees/feature',
        sessionId: 'abc',
      );
      final listed = _session(id: 'abc', projectPath: '/repo');
      expect(pinIdentitiesOf({worktreeKey}), {'claude:abc'});
      expect(
        pinIdentitiesOf({worktreeKey})
            .contains(recentSessionPinIdentity(listed)),
        isTrue,
      );

      await cubit.toggleRunningSessionPinned(
        _runningSession(providerSessionId: 'abc'),
      );
      expect(cubit.isRecentSessionPinned(listed), isTrue);
      await cubit.toggleRecentSessionPinned(listed);
      expect(cubit.state.pinnedSessionKeys, isEmpty);
      expect(cubit.isRecentSessionPinned(listed), isFalse);
    });

    test('togglePinKey removes every key with the same identity', () {
      final a = sessionPinKey(
        provider: 'codex',
        projectPath: '/a',
        sessionId: 't',
      );
      final b = sessionPinKey(
        provider: 'codex',
        projectPath: '/b',
        sessionId: 't',
      );
      expect(togglePinKey({a, b}, a), isEmpty);
      expect(togglePinKey({}, a), {a});
    });
  });

  group('recent session filters', () {
    test('multi-project selection is sent as extra project keys', () {
      mockBridge.supportsFilters = true;
      cubit.setProjectFilters({'/b', 'project:p1'});
      final sent = mockBridge.lastJson;
      expect(sent['projectPath'], isNull);
      expect(mockBridge.lastExtraFilters.projectKeys, ['/b', 'project:p1']);

      cubit.setProjectFilters({'/b'});
      expect(mockBridge.lastJson['projectPath'], '/b');
      expect(mockBridge.lastExtraFilters.projectKeys, isEmpty);
    });

    test('without the capability only one project is sent', () {
      cubit.setProjectFilters({'/b', '/a'});
      expect(mockBridge.lastJson['projectPath'], '/a');
      // Kept so the request is repeated once the capability arrives;
      // BridgeService drops it for old Bridges.
      expect(mockBridge.lastExtraFilters.projectKeys, ['/a', '/b']);
    });

    test('period, pinned only and content search are forwarded', () async {
      mockBridge.supportsFilters = true;
      await cubit.toggleProjectPinned('project:fav');
      cubit.setDateFilter(const RecentDateFilter(RecentDatePreset.yesterday));
      var extra = mockBridge.lastExtraFilters;
      // Resolved at send time so presets follow the clock.
      final range = extra.resolveDateRange!();
      expect(range.after, isNotNull);
      expect(range.before, isNotNull);
      expect(
        DateTime.parse(range.before!)
            .difference(DateTime.parse(range.after!))
            .inHours,
        inInclusiveRange(23, 25),
      );
      expect(extra.dateField, isNull);

      cubit.togglePinnedOnly();
      extra = mockBridge.lastExtraFilters;
      expect(extra.pinnedOnly, isTrue);
      expect(extra.pinnedProjectKeys, ['project:fav']);

      // Content search needs a query.
      cubit.applyAdvancedSearch(
        searchQuery: '',
        filters: cubit.state.filters.copyWith(
          searchContent: true,
          dateField: RecentDateField.created,
        ),
        providerFilter: ProviderFilter.all,
        namedOnly: false,
      );
      expect(mockBridge.lastExtraFilters.searchContent, isFalse);
      expect(mockBridge.lastExtraFilters.dateField, 'created');
      cubit.applyAdvancedSearch(
        searchQuery: 'needle',
        filters: cubit.state.filters,
        providerFilter: ProviderFilter.claude,
        namedOnly: true,
      );
      expect(mockBridge.lastExtraFilters.searchContent, isTrue);
      final sent = mockBridge.lastJson;
      expect(sent['searchQuery'], 'needle');
      expect(sent['provider'], 'claude');
      expect(sent['namedOnly'], isTrue);

      cubit.clearFilters();
      expect(cubit.state.filters, const RecentSessionFilters());
      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.namedOnly, isFalse);
      expect(cubit.state.providerFilter, ProviderFilter.claude);
      expect(mockBridge.lastExtraFilters.pinnedOnly, isFalse);
    });

    test('pin changes re-request while pinned only is active', () async {
      mockBridge.supportsFilters = true;
      cubit.togglePinnedOnly();
      final before = mockBridge.sentMessages.length;
      await cubit.toggleRecentSessionPinned(_session(id: 'x'));
      expect(mockBridge.sentMessages.length, before + 1);
    });

    test('re-requests with filters once the Bridge announces them', () async {
      cubit.setProjectFilters({'/a', '/b'});
      // Without the capability only the first project is sent.
      expect(mockBridge.lastJson['projectPath'], '/a');
      mockBridge.supportsFilters = true;
      final before = mockBridge.sentMessages.length;
      mockBridge.announceRecentFilters();
      await Future<void>.delayed(Duration.zero);
      expect(mockBridge.sentMessages.length, before + 1);
      expect(mockBridge.lastJson['projectPath'], isNull);
      expect(mockBridge.lastExtraFilters.projectKeys, ['/a', '/b']);
    });

    test('resetFilters clears the extra filters', () {
      cubit.togglePinnedOnly();
      cubit.resetFilters();
      expect(cubit.state.filters.isActive, isFalse);
    });
  });

  group('RecentDateFilter', () {
    final now = DateTime(2026, 11, 3, 15, 30);

    test('presets resolve to local day ranges', () {
      expect(const RecentDateFilter(RecentDatePreset.today).resolve(now), (
        start: DateTime(2026, 11, 3),
        end: null,
      ));
      expect(const RecentDateFilter(RecentDatePreset.yesterday).resolve(now), (
        start: DateTime(2026, 11, 2),
        end: DateTime(2026, 11, 3),
      ));
      expect(
        const RecentDateFilter(RecentDatePreset.dayBeforeYesterday)
            .resolve(now),
        (start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 2)),
      );
      expect(
        const RecentDateFilter(RecentDatePreset.last7Days).resolve(now).start,
        DateTime(2026, 10, 28),
      );
    });

    test('custom range is inclusive of the end day', () {
      final filter = RecentDateFilter.custom(
        start: DateTime(2026, 10, 30, 9),
        end: DateTime(2026, 10, 31, 22),
      );
      expect(filter.resolve(now), (
        start: DateTime(2026, 10, 30),
        end: DateTime(2026, 11, 1),
      ));
      expect(
        filter,
        RecentDateFilter.custom(
          start: DateTime(2026, 10, 30),
          end: DateTime(2026, 10, 31),
        ),
      );
    });
  });
}
