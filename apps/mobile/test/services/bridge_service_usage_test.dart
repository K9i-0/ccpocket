import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BridgeService usage cache', () {
    test('disconnect clears last usage result cache', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      final socketReady = Completer<void>();

      server.transform(WebSocketTransformer()).listen((socket) {
        sockets.add(socket);
        socket.add(
          jsonEncode({
            'type': 'usage_result',
            'providers': [
              {
                'provider': 'codex',
                'fiveHour': {
                  'utilization': 0.08,
                  'resetsAt': '2026-04-12T10:19:42Z',
                },
              },
            ],
          }),
        );
        socketReady.complete();
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');

      await socketReady.future;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bridge.lastUsageResult, isNotNull);

      bridge.disconnect();

      expect(bridge.lastUsageResult, isNull);

      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
      bridge.dispose();
    });
  });
}
