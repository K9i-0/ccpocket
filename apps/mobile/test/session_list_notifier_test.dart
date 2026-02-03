import 'dart:async';

import 'package:ccpocket/features/session_list/state/session_list_notifier.dart';
import 'package:ccpocket/features/session_list/state/session_list_state.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_providers.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal mock for SessionListNotifier tests.
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
  late ProviderContainer container;
  late MockBridgeService mockBridge;

  setUp(() {
    mockBridge = MockBridgeService();
    container = ProviderContainer(
      overrides: [bridgeServiceProvider.overrideWithValue(mockBridge)],
    );
  });

  tearDown(() {
    container.dispose();
    mockBridge.dispose();
  });

  group('SessionListNotifier', () {
    test('initial state is empty', () {
      final state = container.read(sessionListNotifierProvider);
      expect(state.sessions, isEmpty);
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.selectedProject, isNull);
      expect(state.dateFilter, DateFilter.all);
      expect(state.searchQuery, isEmpty);
      expect(state.accumulatedProjectPaths, isEmpty);
    });

    test('sessions update from stream', () async {
      container.read(sessionListNotifierProvider);
      await Future.microtask(() {});

      mockBridge.emitSessions([_session(id: 's1'), _session(id: 's2')]);
      await Future.microtask(() {});

      final state = container.read(sessionListNotifierProvider);
      expect(state.sessions, hasLength(2));
      expect(state.sessions[0].sessionId, 's1');
    });

    test('hasMore reflects bridge state', () async {
      container.read(sessionListNotifierProvider);
      await Future.microtask(() {});

      mockBridge.emitSessions([_session(id: 's1')], hasMore: true);
      await Future.microtask(() {});

      final state = container.read(sessionListNotifierProvider);
      expect(state.hasMore, isTrue);
    });

    test('sessions update accumulates project paths', () async {
      container.read(sessionListNotifierProvider);
      await Future.microtask(() {});

      mockBridge.emitSessions([
        _session(id: 's1', projectPath: '/a/proj1'),
        _session(id: 's2', projectPath: '/b/proj2'),
      ]);
      await Future.microtask(() {});

      final state = container.read(sessionListNotifierProvider);
      expect(state.accumulatedProjectPaths, {'/a/proj1', '/b/proj2'});
    });

    test('project history merges into accumulated paths', () async {
      container.read(sessionListNotifierProvider);
      await Future.microtask(() {});

      // First, emit sessions to set some paths
      mockBridge.emitSessions([
        _session(id: 's1', projectPath: '/a/proj1'),
      ]);
      await Future.microtask(() {});

      // Then, project history adds more
      mockBridge.emitProjectHistory(['/a/proj1', '/c/proj3']);
      await Future.microtask(() {});

      final state = container.read(sessionListNotifierProvider);
      expect(state.accumulatedProjectPaths, {'/a/proj1', '/c/proj3'});
    });

    test('selectProject updates filter and calls bridge', () async {
      container.read(sessionListNotifierProvider);
      await Future.microtask(() {});

      container
          .read(sessionListNotifierProvider.notifier)
          .selectProject('/a/proj1');

      final state = container.read(sessionListNotifierProvider);
      expect(state.selectedProject, 'proj1');
    });

    test('selectProject(null) clears filter', () async {
      container.read(sessionListNotifierProvider);
      await Future.microtask(() {});

      // Set a filter first
      container
          .read(sessionListNotifierProvider.notifier)
          .selectProject('/a/proj1');
      // Then clear it
      container.read(sessionListNotifierProvider.notifier).selectProject(null);

      final state = container.read(sessionListNotifierProvider);
      expect(state.selectedProject, isNull);
    });

    test('setDateFilter updates filter', () {
      container.read(sessionListNotifierProvider);

      container
          .read(sessionListNotifierProvider.notifier)
          .setDateFilter(DateFilter.today);

      final state = container.read(sessionListNotifierProvider);
      expect(state.dateFilter, DateFilter.today);
    });

    test('setSearchQuery updates query', () {
      container.read(sessionListNotifierProvider);

      container
          .read(sessionListNotifierProvider.notifier)
          .setSearchQuery('hello');

      final state = container.read(sessionListNotifierProvider);
      expect(state.searchQuery, 'hello');
    });

    test('loadMore sets isLoadingMore and calls bridge', () async {
      container.read(sessionListNotifierProvider);
      await Future.microtask(() {});

      container.read(sessionListNotifierProvider.notifier).loadMore();

      final state = container.read(sessionListNotifierProvider);
      expect(state.isLoadingMore, isTrue);
      expect(mockBridge.sentMessages, isNotEmpty);
    });

    test('loadMore isLoadingMore resets when sessions arrive', () async {
      container.read(sessionListNotifierProvider);
      await Future.microtask(() {});

      container.read(sessionListNotifierProvider.notifier).loadMore();
      expect(
        container.read(sessionListNotifierProvider).isLoadingMore,
        isTrue,
      );

      // Sessions arrive, clearing loading state
      mockBridge.emitSessions([_session(id: 's1')]);
      await Future.microtask(() {});

      expect(
        container.read(sessionListNotifierProvider).isLoadingMore,
        isFalse,
      );
    });

    test('resetFilters clears all filter state', () {
      container.read(sessionListNotifierProvider);
      final notifier = container.read(sessionListNotifierProvider.notifier);

      notifier.selectProject('/a/proj1');
      notifier.setDateFilter(DateFilter.thisWeek);
      notifier.setSearchQuery('test');

      notifier.resetFilters();

      final state = container.read(sessionListNotifierProvider);
      expect(state.selectedProject, isNull);
      expect(state.dateFilter, DateFilter.all);
      expect(state.searchQuery, isEmpty);
      expect(state.accumulatedProjectPaths, isEmpty);
    });
  });
}
