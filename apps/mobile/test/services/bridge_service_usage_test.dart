import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/messages.dart';
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

    test(
      'requestSessionHistory uses delta when cached sequence exists',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();

        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
        });

        final outgoing = <ClientMessage>[];
        final bridge = BridgeService()..onOutgoingMessage = outgoing.add;
        bridge.connect('ws://127.0.0.1:${server.port}');

        final socket = await socketReady.future;
        socket.add(
          jsonEncode({
            'type': 'status',
            'status': 'running',
            'sessionId': 's1',
            'historySeq': 3,
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bridge.requestSessionHistory('s1');

        final request =
            jsonDecode(outgoing.last.toJson()) as Map<String, dynamic>;
        expect(request, {
          'type': 'get_history_delta',
          'sessionId': 's1',
          'sinceSeq': 3,
        });

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'requestSessionHistory falls back when delta is unsupported',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();

        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
        });

        final outgoing = <ClientMessage>[];
        final bridge = BridgeService()..onOutgoingMessage = outgoing.add;
        bridge.connect('ws://127.0.0.1:${server.port}');

        final socket = await socketReady.future;
        socket.add(
          jsonEncode({
            'type': 'status',
            'status': 'running',
            'sessionId': 's1',
            'historySeq': 3,
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bridge.requestSessionHistory('s1');
        socket.add(
          jsonEncode({
            'type': 'error',
            'errorCode': 'unsupported_message',
            'message': 'get_history_delta',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final requests = outgoing
            .map(
              (message) => jsonDecode(message.toJson()) as Map<String, dynamic>,
            )
            .toList();
        expect(
          requests.any(
            (request) =>
                request['type'] == 'get_history_delta' &&
                request['sessionId'] == 's1',
          ),
          isTrue,
        );
        expect(requests.last, {'type': 'get_history', 'sessionId': 's1'});

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );
  });
}
