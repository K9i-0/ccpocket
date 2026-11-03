import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _session(String id, {String provider = 'claude'}) => {
  'sessionId': id,
  'provider': provider,
  'projectPath': '/tmp/project',
};

class _Harness {
  _Harness._(this.server, this.bridge);

  final HttpServer server;
  final BridgeService bridge;
  final requests = <Map<String, dynamic>>[];
  final _socket = Completer<WebSocket>();
  final _requestWaiters = <int, Completer<void>>{};

  static Future<_Harness> start({List<String> capabilities = const []}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _Harness._(server, BridgeService());
    server.transform(WebSocketTransformer()).listen((socket) {
      socket.add(
        jsonEncode({
          'type': 'session_list',
          'sessions': <Object>[],
          'bridgeInstanceId': 'bridge-test',
          'protocolCapabilities': capabilities,
        }),
      );
      if (!harness._socket.isCompleted) harness._socket.complete(socket);
      socket.listen((data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        if (json['type'] != 'list_recent_sessions') return;
        harness.requests.add(json);
        harness._requestWaiters.remove(harness.requests.length)?.complete();
      });
    });
    harness.bridge.connect('ws://127.0.0.1:${server.port}');
    await harness.bridge.connectionStatus.firstWhere(
      (state) => state == BridgeConnectionState.connected,
    );
    await harness._socket.future;
    return harness;
  }

  Future<Map<String, dynamic>> nextRequest() async {
    final index = requests.length + 1;
    final waiter = _requestWaiters.putIfAbsent(index, Completer<void>.new);
    await waiter.future.timeout(const Duration(seconds: 1));
    return requests[index - 1];
  }

  Future<List<RecentSession>> respond(
    Map<String, dynamic> request, {
    required List<Map<String, dynamic>> sessions,
    List<Map<String, dynamic>>? pinnedSessions,
    bool hasMore = true,
  }) async {
    final update = bridge.recentSessionsStream.first;
    (await _socket.future).add(
      jsonEncode({
        'type': 'recent_sessions',
        'sessions': sessions,
        'hasMore': hasMore,
        'pinnedSessions': ?pinnedSessions,
        'offset': request['offset'],
        'requestScope': request['requestScope'],
        'requestId': request['requestId'],
      }),
    );
    return update.timeout(const Duration(seconds: 1));
  }

  Future<void> close() async {
    bridge.disconnect();
    if (_socket.isCompleted) await (await _socket.future).close();
    await server.close(force: true);
    bridge.dispose();
  }
}

List<String> _ids(List<RecentSession> sessions) =>
    sessions.map((s) => '${s.provider}:${s.sessionId}').toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('sends pinned sessions with first list pages only', () async {
    final harness = await _Harness.start();
    final bridge = harness.bridge;
    bridge.setPinnedRecentSessions(const [
      (provider: 'codex', sessionId: 'x1'),
      (provider: 'claude', sessionId: 'c1'),
    ]);

    bridge.switchFilter(provider: 'claude');
    final first = await harness.nextRequest();
    expect(first['offset'], 0);
    expect(first['pinnedSessions'], [
      {'provider': 'claude', 'sessionId': 'c1'},
      {'provider': 'codex', 'sessionId': 'x1'},
    ]);
    await harness.respond(first, sessions: [_session('page-1')]);

    bridge.loadMoreRecentSessions();
    final more = await harness.nextRequest();
    expect(more['offset'], 1);
    expect(more.containsKey('pinnedSessions'), isFalse);

    await harness.close();
  });

  test('re-sends an identical filter request when pins change', () async {
    final harness = await _Harness.start();
    final bridge = harness.bridge;

    bridge.switchFilter(searchQuery: 'q');
    final withoutPins = await harness.nextRequest();
    expect(withoutPins.containsKey('pinnedSessions'), isFalse);

    bridge.setPinnedRecentSessions(const [
      (provider: 'claude', sessionId: 'c1'),
    ]);
    bridge.switchFilter(searchQuery: 'q');
    final withPins = await harness.nextRequest();
    expect(withPins['pinnedSessions'], [
      {'provider': 'claude', 'sessionId': 'c1'},
    ]);

    await harness.close();
  });

  test('publishes pinned extras deduped, keeps them across pages and drops unpinned', () async {
    final harness = await _Harness.start();
    final bridge = harness.bridge;
    bridge.setPinnedRecentSessions(const [
      (provider: 'claude', sessionId: 'page-1'),
      (provider: 'claude', sessionId: 'old-pin'),
      (provider: 'codex', sessionId: 'codex-pin'),
    ]);

    bridge.switchFilter();
    final first = await harness.nextRequest();
    var visible = await harness.respond(
      first,
      sessions: [_session('page-1'), _session('page-2')],
      pinnedSessions: [
        _session('page-1'),
        _session('old-pin'),
        _session('codex-pin', provider: 'codex'),
      ],
    );
    expect(_ids(visible), [
      'claude:page-1',
      'claude:page-2',
      'claude:old-pin',
      'codex:codex-pin',
    ]);
    expect(bridge.isPinnedRecentExtra(visible[2]), isTrue);
    expect(bridge.isPinnedRecentExtra(visible[0]), isFalse);

    // Offsets count loaded page sessions only.
    bridge.loadMoreRecentSessions();
    final more = await harness.nextRequest();
    expect(more['offset'], 2);
    visible = await harness.respond(
      more,
      sessions: [_session('page-3'), _session('old-pin')],
    );
    expect(_ids(visible), [
      'claude:page-1',
      'claude:page-2',
      'claude:page-3',
      'claude:old-pin',
      'codex:codex-pin',
    ]);
    // Loaded through a page now, so it counts toward the offset.
    expect(bridge.isPinnedRecentExtra(visible[3]), isFalse);

    // Unpinning is local: no replay of the last response, and the extra
    // is dropped with the next published update.
    final emissions = <List<RecentSession>>[];
    final sub = bridge.recentSessionsStream.listen(emissions.add);
    bridge.setPinnedRecentSessions(const [
      (provider: 'claude', sessionId: 'page-1'),
      (provider: 'claude', sessionId: 'old-pin'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(emissions, isEmpty);
    expect(bridge.isPinnedRecentExtra(visible[4]), isTrue);
    bridge.loadMoreRecentSessions();
    final afterUnpin = await harness.nextRequest();
    expect(afterUnpin['offset'], 4);
    visible = await harness.respond(afterUnpin, sessions: [_session('page-5')]);
    expect(_ids(visible), [
      'claude:page-1',
      'claude:page-2',
      'claude:page-3',
      'claude:old-pin',
      'claude:page-5',
    ]);
    await sub.cancel();

    // A new first page without pinnedSessions (older Bridge) resets extras.
    bridge.switchFilter(provider: 'claude');
    final refreshed = await harness.nextRequest();
    visible = await harness.respond(refreshed, sessions: [_session('page-1')]);
    expect(_ids(visible), ['claude:page-1']);

    await harness.close();
  });

  test('parses pinnedSessions from recent_sessions', () {
    final message = ServerMessage.fromJson({
      'type': 'recent_sessions',
      'sessions': [_session('page')],
      'pinnedSessions': [_session('pin', provider: 'codex')],
    });
    expect(message, isA<RecentSessionsMessage>());
    final recent = message as RecentSessionsMessage;
    expect(recent.pinnedSessions?.single.sessionId, 'pin');
    expect(recent.pinnedSessions?.single.provider, 'codex');

    final legacy = ServerMessage.fromJson({
      'type': 'recent_sessions',
      'sessions': [],
    }) as RecentSessionsMessage;
    expect(legacy.pinnedSessions, isNull);
  });

  group('recent_sessions_filters_v1', () {
    const extra = RecentSessionsExtraFilters(
      projectKeys: ['/tmp/a', 'project:p1'],
      modifiedAfter: '2026-11-01T00:00:00.000Z',
      modifiedBefore: '2026-11-02T00:00:00.000Z',
      dateField: 'created',
      pinnedOnly: true,
      pinnedProjectKeys: ['project:fav'],
      searchContent: true,
    );

    test('sends extra filters when the Bridge advertises them', () async {
      final harness = await _Harness.start(
        capabilities: const ['recent_sessions_filters_v1'],
      );
      final bridge = harness.bridge;
      bridge.setPinnedRecentSessions(const [
        (provider: 'claude', sessionId: 'c1'),
      ]);
      bridge.switchFilter(searchQuery: 'q', extraFilters: extra);
      final first = await harness.nextRequest();
      expect(first['projectFilters'], [
        {'projectPath': '/tmp/a'},
        {'projectId': 'p1', 'workspaceKind': 'project'},
      ]);
      expect(first['modifiedAfter'], '2026-11-01T00:00:00.000Z');
      expect(first['modifiedBefore'], '2026-11-02T00:00:00.000Z');
      expect(first['dateField'], 'created');
      expect(first['pinnedOnly'], isTrue);
      expect(first['pinnedProjects'], [
        {'projectId': 'fav', 'workspaceKind': 'project'},
      ]);
      expect(first['searchContent'], isTrue);
      await harness.respond(
        first,
        sessions: [_session('a'), _session('b')],
        hasMore: true,
      );

      // Later pages and project-scoped pages keep the filters; pinned only
      // keeps sending the pins because they define the result set.
      bridge.loadMoreRecentSessions();
      final next = await harness.nextRequest();
      expect(next['offset'], 2);
      expect(next['modifiedAfter'], '2026-11-01T00:00:00.000Z');
      expect(next['pinnedSessions'], [
        {'provider': 'claude', 'sessionId': 'c1'},
      ]);
      expect(next['projectFilters'], isNotNull);
      await harness.respond(next, sessions: const [], hasMore: false);

      bridge.loadMoreRecentSessions(
        projectPath: '/tmp/a',
        offset: 1,
        requestScope: 'project',
      );
      final project = await harness.nextRequest();
      expect(project['projectPath'], '/tmp/a');
      expect(project.containsKey('projectFilters'), isFalse);
      expect(project['dateField'], 'created');
      expect(project['pinnedOnly'], isTrue);
      expect(project['searchContent'], isTrue);
      await harness.close();
    });

    test('omits extra filters for Bridges without the capability', () async {
      final harness = await _Harness.start();
      harness.bridge.switchFilter(extraFilters: extra);
      final first = await harness.nextRequest();
      for (final key in [
        'projectFilters',
        'modifiedAfter',
        'modifiedBefore',
        'dateField',
        'pinnedOnly',
        'pinnedProjects',
        'searchContent',
      ]) {
        expect(first.containsKey(key), isFalse, reason: key);
      }
      await harness.close();
    });

    test('parses searchMatch on recent sessions', () {
      final session = RecentSession.fromJson({
        ..._session('m1'),
        'searchMatch': {'field': 'content', 'snippet': 'hello world'},
      });
      expect(session.searchMatch?.field, RecentSessionSearchField.content);
      expect(session.searchMatch?.snippet, 'hello world');
      expect(
        RecentSession.fromJson({
          ..._session('m2'),
          'searchMatch': {'field': 'unknown'},
        }).searchMatch,
        isNull,
      );
      expect(
        session.copyWithName(name: 'n').searchMatch?.field,
        RecentSessionSearchField.content,
      );
    });
  });
}
