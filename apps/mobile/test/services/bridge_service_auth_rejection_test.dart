import 'dart:async';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket/testing.dart';
import 'package:web_socket/web_socket.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';

/// Creates a [BridgeService] whose sockets are in-memory fakes. Every
/// connection attempt is recorded so tests can assert on reconnect behavior.
class _Harness {
  final List<Uri> attempts = [];
  final List<WebSocket> servers = [];
  late final BridgeService service = BridgeService(
    channelFactory: (uri) {
      attempts.add(uri);
      final (client, server) = fakes();
      servers.add(server);
      return AdapterWebSocketChannel(client);
    },
  );

  Future<BridgeConnectionState> closeLatest(int code, String reason) async {
    final next = service.connectionStatus.firstWhere(
      (state) =>
          state == BridgeConnectionState.disconnected ||
          state == BridgeConnectionState.reconnecting,
    );
    await servers.last.close(code, reason);
    return next.timeout(const Duration(seconds: 2));
  }
}

void main() {
  late _Harness harness;

  setUp(() => harness = _Harness());
  tearDown(() => harness.service.dispose());

  test(
    'close code 4001 records an auth rejection and stops reconnecting',
    () async {
      final rejections = <BridgeAuthRejection?>[];
      final sub = harness.service.authRejectionStream.listen(rejections.add);
      harness.service.connect('ws://192.168.1.20:8765?token=old');

      final states = <BridgeConnectionState>[];
      final stateSub = harness.service.connectionStatus.listen(states.add);
      await harness.closeLatest(4001, 'Unauthorized');
      await pumpEventQueue();

      expect(states.last, BridgeConnectionState.disconnected);
      expect(states, isNot(contains(BridgeConnectionState.reconnecting)));
      expect(
        harness.service.authRejection,
        const BridgeAuthRejection(host: '192.168.1.20', port: 8765),
      );
      expect(rejections.last?.label, '192.168.1.20:8765');

      // Returning to the foreground must not retry the rejected key.
      harness.service.ensureConnected();
      expect(harness.attempts, hasLength(1));
      await sub.cancel();
      await stateSub.cancel();
    },
  );

  test('other close codes keep the reconnect loop', () async {
    harness.service.connect('ws://192.168.1.20:8765');
    final reconnecting = harness.service.connectionStatus.firstWhere(
      (state) => state == BridgeConnectionState.reconnecting,
    );

    await harness.servers.last.close(4000, 'restarting');

    await reconnecting.timeout(const Duration(seconds: 2));
    expect(harness.service.authRejection, isNull);
  });

  test('a new connect clears the rejection', () async {
    harness.service.connect('ws://192.168.1.20:8765');
    await harness.closeLatest(4001, 'Unauthorized');
    expect(harness.service.authRejection, isNotNull);

    harness.service.connect('ws://192.168.1.20:8765?token=new');

    expect(harness.service.authRejection, isNull);
    expect(harness.attempts, hasLength(2));
  });

  test('explicit disconnect clears the rejection', () async {
    harness.service.connect('ws://192.168.1.20:8765');
    await harness.closeLatest(4001, 'Unauthorized');

    harness.service.disconnect();

    expect(harness.service.authRejection, isNull);
  });

  group('bridgeHttpUri', () {
    test('adds the current API key as a token query parameter', () {
      harness.service.connect('ws://192.168.1.20:8765?token=k%2B1');

      expect(
        harness.service.bridgeHttpUri('/api/gallery/abc').toString(),
        'http://192.168.1.20:8765/api/gallery/abc?token=k%2B1',
      );
    });

    test('leaves the URL untouched without an API key', () {
      harness.service.connect('wss://bridge.example.com');

      expect(
        harness.service.bridgeHttpUri('/api/gallery/upload').toString(),
        'https://bridge.example.com/api/gallery/upload',
      );
    });
  });
}
