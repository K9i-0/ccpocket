import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/offline_pending_action.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BridgeService usage cache', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

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

    test('input_ack acceptedSeq advances cached history sequence', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();

      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');

      final socket = await socketReady.future;
      socket.add(
        jsonEncode({
          'type': 'input_ack',
          'sessionId': 's1',
          'clientMessageId': 'cm-1',
          'acceptedSeq': 8,
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bridge.cachedSessionHistorySeq('s1'), 8);

      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test(
      'persists selected offline messages and excludes transient reads',
      () async {
        final bridge = BridgeService();

        bridge.send(
          ClientMessage.input(
            'offline',
            sessionId: 's1',
            clientMessageId: 'cm-1',
            baseSeq: 4,
          ),
        );
        bridge.send(ClientMessage.getHistory('s1'));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getStringList('bridge_offline_pending_messages_v1');
        expect(raw, isNotNull);
        expect(raw, hasLength(1));
        expect(jsonDecode(raw!.single), {
          'type': 'input',
          'text': 'offline',
          'sessionId': 's1',
          'clientMessageId': 'cm-1',
          'baseSeq': 4,
        });

        bridge.dispose();
      },
    );

    test(
      'publishes offline pending start and resume actions with dedupe',
      () async {
        final bridge = BridgeService();
        await pumpEventQueue();

        bridge.send(ClientMessage.start('/home/user/app', provider: 'codex'));
        bridge.send(ClientMessage.start('/home/user/app', provider: 'codex'));
        bridge.send(
          ClientMessage.resumeSession(
            'session-1',
            '/home/user/app',
            provider: 'claude',
          ),
        );
        bridge.send(
          ClientMessage.resumeSession(
            'session-1',
            '/home/user/app',
            provider: 'claude',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bridge.offlinePendingActions, hasLength(2));
        expect(
          bridge.offlinePendingActions.map((action) => action.kind),
          containsAll([
            OfflinePendingActionKind.start,
            OfflinePendingActionKind.resume,
          ]),
        );

        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getStringList('bridge_offline_pending_messages_v1');
        expect(raw, hasLength(2));

        bridge.dispose();
      },
    );

    test('tracks connected start as pending until session_created', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      final received = <Map<String, dynamic>>[];

      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
        socket.listen((data) {
          received.add(jsonDecode(data as String) as Map<String, dynamic>);
        });
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final socket = await socketReady.future;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bridge.send(ClientMessage.start('/home/user/app', provider: 'codex'));
      bridge.send(ClientMessage.start('/home/user/app', provider: 'codex'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bridge.offlinePendingActions, hasLength(1));
      expect(
        bridge.offlinePendingActions.single.kind,
        OfflinePendingActionKind.start,
      );
      expect(bridge.offlinePendingActions.single.canCancel, isFalse);
      expect(
        received.where((message) => message['type'] == 'start'),
        hasLength(1),
      );

      socket.add(
        jsonEncode({
          'type': 'system',
          'subtype': 'session_created',
          'sessionId': 'running-1',
          'provider': 'codex',
          'projectPath': '/home/user/app',
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bridge.offlinePendingActions, isEmpty);

      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test('requeues in-flight pending start when socket closes', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();

      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final socket = await socketReady.future;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bridge.send(ClientMessage.start('/home/user/app', provider: 'codex'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bridge.offlinePendingActions.single.canCancel, isFalse);

      await socket.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(bridge.offlinePendingActions, hasLength(1));
      expect(bridge.offlinePendingActions.single.canCancel, isTrue);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('bridge_offline_pending_messages_v1');
      expect(raw, hasLength(1));
      expect(jsonDecode(raw!.single), containsPair('type', 'start'));

      bridge.disconnect();
      await server.close(force: true);
      bridge.dispose();
    });

    test(
      'cancelOfflinePendingAction removes queued action and persistence',
      () async {
        final bridge = BridgeService();
        await pumpEventQueue();

        bridge.send(
          ClientMessage.resumeSession(
            'session-1',
            '/home/user/app',
            provider: 'claude',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final actionId = bridge.offlinePendingActions.single.id;
        await bridge.cancelOfflinePendingAction(actionId);

        expect(bridge.offlinePendingActions, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('bridge_offline_pending_messages_v1'),
          isNull,
        );

        bridge.dispose();
      },
    );

    test(
      'updates and cancels offline pending input by clientMessageId',
      () async {
        final bridge = BridgeService();
        await pumpEventQueue();

        bridge.send(
          ClientMessage.input(
            'Original',
            sessionId: 's1',
            clientMessageId: 'cm-1',
            baseSeq: 2,
            skills: const [
              {'name': 'skill-a', 'path': '/tmp/skill-a/SKILL.md'},
            ],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final updated = await bridge.updateOfflinePendingInput(
          sessionId: 's1',
          clientMessageId: 'cm-1',
          text: 'Edited',
          mentions: const [
            {'name': 'Demo App', 'path': 'app://demo'},
          ],
        );
        expect(updated, isTrue);

        var prefs = await SharedPreferences.getInstance();
        var raw = prefs.getStringList('bridge_offline_pending_messages_v1');
        expect(raw, hasLength(1));
        expect(jsonDecode(raw!.single), {
          'type': 'input',
          'text': 'Edited',
          'sessionId': 's1',
          'clientMessageId': 'cm-1',
          'baseSeq': 2,
          'mentions': [
            {'name': 'Demo App', 'path': 'app://demo'},
          ],
        });

        final canceled = await bridge.cancelOfflinePendingInput(
          sessionId: 's1',
          clientMessageId: 'cm-1',
        );
        expect(canceled, isTrue);
        prefs = await SharedPreferences.getInstance();
        raw = prefs.getStringList('bridge_offline_pending_messages_v1');
        expect(raw, isNull);

        bridge.dispose();
      },
    );

    test(
      'restores persisted offline messages and clears them after flush',
      () async {
        SharedPreferences.setMockInitialValues({
          'bridge_offline_pending_messages_v1': [
            jsonEncode({
              'type': 'rename_session',
              'sessionId': 's1',
              'name': 'Renamed',
            }),
          ],
        });
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final received = <Map<String, dynamic>>[];
        final sawRename = Completer<void>();

        server.transform(WebSocketTransformer()).listen((socket) {
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            received.add(json);
            if (json['type'] == 'rename_session' && !sawRename.isCompleted) {
              sawRename.complete();
            }
          });
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${server.port}');

        await sawRename.future.timeout(const Duration(seconds: 2));
        expect(
          received.any(
            (message) =>
                message['type'] == 'client_capabilities' &&
                message['supportedServerMessages'] is List,
          ),
          isTrue,
        );
        expect(
          received.any(
            (message) =>
                message['type'] == 'rename_session' &&
                message['sessionId'] == 's1' &&
                message['name'] == 'Renamed',
          ),
          isTrue,
        );

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('bridge_offline_pending_messages_v1'),
          isNull,
        );

        bridge.disconnect();
        await server.close(force: true);
        bridge.dispose();
      },
    );
  });
}
