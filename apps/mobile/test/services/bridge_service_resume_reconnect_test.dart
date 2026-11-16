import 'dart:async';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket/testing.dart';
import 'package:web_socket/web_socket.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';

const _url = 'ws://192.168.1.20:8765';

void main() {
  final attempts = <Uri>[];
  final servers = <WebSocket>[];
  late BridgeService service;

  /// Sockets that never finish the handshake, like a SYN the OS drops while
  /// the app is in the background.
  BridgeService hangingService({required Duration staleConnectAttemptAge}) =>
      BridgeService(
        staleConnectAttemptAge: staleConnectAttemptAge,
        channelFactory: (uri) {
          attempts.add(uri);
          return AdapterWebSocketChannel(Completer<WebSocket>().future);
        },
      );

  setUp(() {
    attempts.clear();
    servers.clear();
  });
  tearDown(() => service.dispose());

  test('resume replaces a handshake that has been pending too long', () {
    service = hangingService(staleConnectAttemptAge: Duration.zero);
    service.connect(_url);

    service.ensureConnected();

    expect(attempts, hasLength(2));
    expect(service.isConnected, isFalse);
  });

  test('resume leaves a handshake that only just started', () {
    service = hangingService(
      staleConnectAttemptAge: const Duration(minutes: 1),
    );
    service.connect(_url);

    service.ensureConnected();
    service.ensureConnected();

    expect(attempts, hasLength(1));
  });

  test('resume reconnects now instead of waiting for the backoff', () async {
    service = BridgeService(
      channelFactory: (uri) {
        attempts.add(uri);
        final (client, server) = fakes();
        servers.add(server);
        return AdapterWebSocketChannel(client);
      },
    );
    service.connect(_url);
    final reconnecting = service.connectionStatus.firstWhere(
      (state) => state == BridgeConnectionState.reconnecting,
    );
    await servers.last.close(4000, 'restarting');
    await reconnecting.timeout(const Duration(seconds: 2));
    expect(attempts, hasLength(1));

    service.ensureConnected();

    expect(attempts, hasLength(2));
  });
}
