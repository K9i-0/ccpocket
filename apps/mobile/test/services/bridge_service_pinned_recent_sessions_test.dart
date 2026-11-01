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

  static Future<_Harness> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _Harness._(server, BridgeService());
    server.transform(WebSocketTransformer()).listen((socket) {
      socket.add(
        jsonEncode({
          'type': 'session_list',
          'sessions': <Object>[],
          'bridgeInstanceId': 'bridge-test',
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

    final unpinned = bridge.recentSessionsStream.first;
    bridge.setPinnedRecentSessions(const [
      (provider: 'claude', sessionId: 'page-1'),
      (provider: 'claude', sessionId: 'old-pin'),
    ]);
    expect(_ids(await unpinned), [
      'claude:page-1',
      'claude:page-2',
      'claude:page-3',
      'claude:old-pin',
    ]);

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
}
