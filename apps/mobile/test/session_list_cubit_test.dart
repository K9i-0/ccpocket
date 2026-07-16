import 'dart:async';

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
  final sentMessages = <ClientMessage>[];

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

  @override
  void switchFilter({
    String? projectPath,
    String? provider,
    bool? namedOnly,
    String? searchQuery,
    int pageSize = 20,
  }) {
    _projectFilter = projectPath;
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
  }
}

RecentSession _session({
  required String id,
  String projectPath = '/home/user/project-a',
}) {
  return RecentSession(
    sessionId: id,
    firstPrompt: 'test prompt',
    created: '2025-01-01T00:00:00Z',
    modified: '2025-01-01T00:00:00Z',
    gitBranch: 'main',
    projectPath: projectPath,
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

    test(
      'non-project response keeps project show more available when more pages exist',
      () async {
        mockBridge.emitSessions([
          _session(id: 's1', projectPath: '/a/proj1'),
        ], hasMore: true);
        await Future.microtask(() {});

        expect(cubit.state.hasMore, isTrue);
        expect(cubit.state.exhaustedProjectPaths, isEmpty);
      },
    );

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
}
