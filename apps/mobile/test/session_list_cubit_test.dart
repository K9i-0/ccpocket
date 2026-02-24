import 'dart:async';

import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter/services.dart';
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
  String? get currentProjectFilter => _projectFilter;

  void emitSessions(List<RecentSession> sessions, {bool hasMore = false}) {
    _hasMore = hasMore;
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
  void loadMoreRecentSessions({int pageSize = 20}) {
    sentMessages.add(
      ClientMessage.listRecentSessions(offset: 0, limit: pageSize),
    );
  }

  @override
  void switchProjectFilter(String? projectPath, {int pageSize = 20}) {
    _projectFilter = projectPath;
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
    messageCount: 1,
    created: '2025-01-01T00:00:00Z',
    modified: '2025-01-01T00:00:00Z',
    gitBranch: 'main',
    projectPath: projectPath,
    isSidechain: false,
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
    test('initial state is empty', () {
      expect(cubit.state.sessions, isEmpty);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.isLoadingMore, isFalse);
      expect(cubit.state.selectedProject, isNull);
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

    test('selectProject updates filter and calls bridge', () async {
      cubit.selectProject('/a/proj1');

      expect(cubit.state.selectedProject, 'proj1');
    });

    test('selectProject(null) clears filter', () async {
      // Set a filter first
      cubit.selectProject('/a/proj1');
      // Then clear it
      cubit.selectProject(null);

      expect(cubit.state.selectedProject, isNull);
    });

    test('setSearchQuery updates query', () {
      cubit.setSearchQuery('hello');

      expect(cubit.state.searchQuery, 'hello');
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

    test('resetFilters clears all filter state', () {
      cubit.selectProject('/a/proj1');
      cubit.setSearchQuery('test');

      cubit.resetFilters();

      expect(cubit.state.selectedProject, isNull);
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
