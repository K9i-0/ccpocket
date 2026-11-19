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

/// A Bridge that records `list_recent_sessions` requests.
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
    // Let the announced capabilities reach the service.
    final expectsAntigravity = capabilities.contains('antigravity_v1');
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (harness.bridge.supportsAntigravity == expectsAntigravity && i >= 2) {
        break;
      }
    }
    return harness;
  }

  Future<Map<String, dynamic>> nextRequest() async {
    final index = requests.length + 1;
    final waiter = _requestWaiters.putIfAbsent(index, Completer<void>.new);
    await waiter.future.timeout(const Duration(seconds: 1));
    return requests[index - 1];
  }

  Future<void> respond(
    Map<String, dynamic> request, {
    required List<Map<String, dynamic>> sessions,
    bool hasMore = true,
  }) async {
    final update = bridge.recentSessionsStream.first;
    (await _socket.future).add(
      jsonEncode({
        'type': 'recent_sessions',
        'sessions': sessions,
        'hasMore': hasMore,
        'offset': request['offset'],
        'requestScope': request['requestScope'],
        'requestId': request['requestId'],
      }),
    );
    await update.timeout(const Duration(seconds: 1));
  }

  Future<void> announce(List<String> capabilities) async {
    (await _socket.future).add(
      jsonEncode({
        'type': 'session_list',
        'sessions': <Object>[],
        'bridgeInstanceId': 'bridge-test',
        'protocolCapabilities': capabilities,
      }),
    );
  }

  Future<void> close() async {
    bridge.disconnect();
    if (_socket.isCompleted) await (await _socket.future).close();
    await server.close(force: true);
    bridge.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'unfiltered requests ask for Antigravity rows with the capability',
    () async {
      final harness = await _Harness.start(capabilities: ['antigravity_v1']);
      expect(harness.bridge.supportsAntigravity, isTrue);

      harness.bridge.switchFilter();
      final request = await harness.nextRequest();

      expect(request['includeAntigravity'], isTrue);
      expect(request.containsKey('provider'), isFalse);
      await harness.close();
    },
  );

  test('a provider filter never sends includeAntigravity', () async {
    final harness = await _Harness.start(capabilities: ['antigravity_v1']);

    harness.bridge.switchFilter(provider: 'antigravity');
    final antigravity = await harness.nextRequest();
    expect(antigravity['provider'], 'antigravity');
    expect(antigravity.containsKey('includeAntigravity'), isFalse);

    harness.bridge.switchFilter(provider: 'claude');
    final claude = await harness.nextRequest();
    expect(claude.containsKey('includeAntigravity'), isFalse);
    await harness.close();
  });

  test('includeAntigravity is not sent without the capability', () async {
    final harness = await _Harness.start();
    expect(harness.bridge.supportsAntigravity, isFalse);

    harness.bridge.switchFilter();
    final request = await harness.nextRequest();

    expect(request.containsKey('includeAntigravity'), isFalse);
    await harness.close();
  });

  test('announces a capability that arrives after the list request', () async {
    final harness = await _Harness.start();
    final bridge = harness.bridge;
    bridge.switchFilter();
    final first = await harness.nextRequest();
    expect(first.containsKey('includeAntigravity'), isFalse);
    await harness.respond(first, sessions: [_session('c1')]);

    final changed = bridge.antigravityAvailabilityChanged.first;
    await harness.announce(['antigravity_v1']);
    expect(await changed.timeout(const Duration(seconds: 1)), isTrue);

    // The list owner asks again; the same query now includes Antigravity.
    bridge.switchFilter();
    final second = await harness.nextRequest();
    expect(second['includeAntigravity'], isTrue);
    await harness.close();
  });

  test('the next unfiltered page skips merged Antigravity rows', () async {
    final harness = await _Harness.start(capabilities: ['antigravity_v1']);
    final bridge = harness.bridge;

    bridge.switchFilter();
    final first = await harness.nextRequest();
    // Antigravity rows come on top of the Claude / Codex page.
    await harness.respond(
      first,
      sessions: [
        _session('c1'),
        _session('a1', provider: 'antigravity'),
        _session('x1', provider: 'codex'),
        _session('a2', provider: 'antigravity'),
      ],
    );
    expect(bridge.recentSessionsPagingOffset, 2);

    bridge.loadMoreRecentSessions();
    final more = await harness.nextRequest();

    expect(more['offset'], 2);
    await harness.close();
  });

  test('the Antigravity filter pages over all of its rows', () async {
    final harness = await _Harness.start(capabilities: ['antigravity_v1']);
    final bridge = harness.bridge;

    bridge.switchFilter(provider: 'antigravity');
    final first = await harness.nextRequest();
    await harness.respond(
      first,
      sessions: [
        _session('a1', provider: 'antigravity'),
        _session('a2', provider: 'antigravity'),
      ],
    );

    bridge.loadMoreRecentSessions();
    final more = await harness.nextRequest();

    expect(more['offset'], 2);
    expect(more['provider'], 'antigravity');
    await harness.close();
  });
}
