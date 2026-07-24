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

    test(
      'transport failures use reconnect state without chat errors',
      () async {
        final closedServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final port = closedServer.port;
        await closedServer.close(force: true);

        final bridge = BridgeService();
        final messages = <ServerMessage>[];
        final connectionStates = <BridgeConnectionState>[];
        final reconnecting = Completer<void>();
        final subscription = bridge.messages.listen(messages.add);
        final connectionSubscription = bridge.connectionStatus.listen((state) {
          connectionStates.add(state);
          if (state == BridgeConnectionState.reconnecting &&
              !reconnecting.isCompleted) {
            reconnecting.complete();
          }
        });

        bridge.connect('ws://127.0.0.1:$port');
        await reconnecting.future.timeout(const Duration(seconds: 5));

        expect(
          messages.whereType<ErrorMessage>().where(
            (message) =>
                message.message.startsWith('WebSocket error:') ||
                message.message.startsWith('Connection failed:'),
          ),
          isEmpty,
        );
        expect(
          connectionStates,
          isNot(contains(BridgeConnectionState.connected)),
        );
        expect(
          bridge.currentBridgeConnectionState,
          BridgeConnectionState.reconnecting,
        );

        bridge.disconnect();
        await subscription.cancel();
        await connectionSubscription.cancel();
        bridge.dispose();
      },
    );

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

    test('disconnect clears bridge-scoped metadata caches', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      final socketReady = Completer<void>();

      server.transform(WebSocketTransformer()).listen((socket) {
        sockets.add(socket);
        socket.add(
          jsonEncode({
            'type': 'session_list',
            'sessions': [],
            'allowedDirs': ['/old-bridge'],
            'claudeModels': ['sonnet'],
            'codexModels': ['gpt-5.2'],
            'codexProfiles': ['old-profile'],
            'defaultCodexProfile': 'old-profile',
            'bridgeVersion': '1.2.3',
          }),
        );
        socket.add(
          jsonEncode({
            'type': 'project_history',
            'projects': ['/old-bridge/project'],
          }),
        );
        socketReady.complete();
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');

      await socketReady.future;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bridge.allowedDirs, ['/old-bridge']);
      expect(bridge.projectHistory, ['/old-bridge/project']);
      expect(bridge.codexProfiles, ['old-profile']);
      expect(bridge.bridgeVersion, '1.2.3');

      bridge.disconnect();

      expect(bridge.allowedDirs, isEmpty);
      expect(bridge.projectHistory, isEmpty);
      expect(bridge.codexProfiles, isEmpty);
      expect(bridge.bridgeVersion, isNull);

      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
      bridge.dispose();
    });

    test(
      'switching bridge drops pending starts from previous target',
      () async {
        final oldServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final oldSocketReady = Completer<WebSocket>();
        oldServer.transform(WebSocketTransformer()).listen((socket) {
          oldSocketReady.complete(socket);
        });

        final newServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final newSocketReady = Completer<WebSocket>();
        final newReceived = <Map<String, dynamic>>[];
        final firstNewMessage = Completer<void>();
        newServer.transform(WebSocketTransformer()).listen((socket) {
          newSocketReady.complete(socket);
          socket.listen((data) {
            newReceived.add(jsonDecode(data as String) as Map<String, dynamic>);
            if (!firstNewMessage.isCompleted) firstNewMessage.complete();
          });
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${oldServer.port}');

        final oldSocket = await oldSocketReady.future;
        await oldSocket.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bridge.send(
          ClientMessage.start(
            '/old-bridge/project',
            provider: Provider.codex.value,
          ),
        );
        expect(bridge.offlinePendingActions, hasLength(1));

        bridge.connect('ws://127.0.0.1:${newServer.port}');

        final newSocket = await newSocketReady.future;
        await firstNewMessage.future;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          newReceived.map((message) => message['type']),
          isNot(contains('start')),
        );
        expect(bridge.offlinePendingActions, isEmpty);

        await newSocket.close();
        await oldServer.close(force: true);
        await newServer.close(force: true);
        bridge.dispose();
      },
    );

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
            'type': 'history_delta',
            'sessionId': 's1',
            'fromSeq': 1,
            'toSeq': 1,
            'messages': [
              {
                'seq': 1,
                'message': {'type': 'status', 'status': 'running'},
              },
            ],
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bridge.requestSessionHistory('s1');

        final request =
            jsonDecode(outgoing.last.toJson()) as Map<String, dynamic>;
        expect(request, {
          'type': 'get_history_delta',
          'sessionId': 's1',
          'sinceSeq': 1,
        });

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test('requestSessionHistory uses last complete cached sequence', () async {
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
          'type': 'history_delta',
          'sessionId': 's1',
          'fromSeq': 1,
          'toSeq': 3,
          'messages': [
            {
              'seq': 1,
              'message': {'type': 'status', 'status': 'starting'},
            },
            {
              'seq': 2,
              'message': {'type': 'status', 'status': 'running'},
            },
            {
              'seq': 3,
              'message': {'type': 'status', 'status': 'idle'},
            },
          ],
        }),
      );
      socket.add(
        jsonEncode({
          'type': 'assistant',
          'message': {
            'id': 'msg-1',
            'role': 'assistant',
            'content': [
              {'type': 'text', 'text': 'Hi. What do you want to work on?'},
            ],
            'model': 'gpt-5.5',
          },
          'sessionId': 's1',
          'historySeq': 6,
        }),
      );
      socket.add(
        jsonEncode({
          'type': 'result',
          'subtype': 'success',
          'sessionId': 's1',
          'historySeq': 7,
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
    });

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

    test('session list preserves visible delivery pending input', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();

      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
      });

      final bridge = BridgeService();
      bridge.setDeliveryPendingInput(
        's1',
        const QueuedInputItem(
          itemId: 'pending:cm-1',
          text: 'Pending delivery',
          createdAt: '2026-04-28T00:00:00.000Z',
        ),
      );
      bridge.connect('ws://127.0.0.1:${server.port}');

      final socket = await socketReady.future;
      socket.add(
        jsonEncode({
          'type': 'session_list',
          'sessions': [
            {
              'id': 's1',
              'provider': 'codex',
              'projectPath': '/tmp/project',
              'status': 'running',
            },
          ],
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bridge.sessions.single.queuedInput?.itemId, 'pending:cm-1');
      expect(bridge.sessions.single.queuedInput?.text, 'Pending delivery');

      socket.add(
        jsonEncode({
          'type': 'input_ack',
          'sessionId': 's1',
          'clientMessageId': 'cm-1',
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bridge.sessions.single.queuedInput, isNull);

      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test('conversation queue updates cached session queued input', () async {
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
          'type': 'session_list',
          'sessions': [
            {
              'id': 's1',
              'provider': 'codex',
              'projectPath': '/tmp/project',
              'status': 'running',
            },
          ],
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      socket.add(
        jsonEncode({
          'type': 'conversation_queue',
          'sessionId': 's1',
          'limit': 1,
          'items': [
            {
              'itemId': 'q1',
              'text': 'Queued while busy',
              'createdAt': '2026-04-28T00:00:00.000Z',
            },
          ],
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bridge.sessions.single.queuedInput?.itemId, 'q1');
      expect(bridge.sessions.single.queuedInput?.text, 'Queued while busy');

      socket.add(
        jsonEncode({
          'type': 'conversation_queue',
          'sessionId': 's1',
          'limit': 1,
          'items': [],
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bridge.sessions.single.queuedInput, isNull);

      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test('input_ack alone does not advance cached history sequence', () async {
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

      expect(bridge.cachedSessionHistorySeq('s1'), 0);

      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test(
      'input_ack caches accepted in-flight user input for re-entry',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();

        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${server.port}');
        final socket = await socketReady.future;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        socket.add(
          jsonEncode({
            'type': 'history_delta',
            'sessionId': 's1',
            'fromSeq': 1,
            'toSeq': 7,
            'messages': List.generate(7, (index) {
              return {
                'seq': index + 1,
                'message': {'type': 'status', 'status': 'running'},
              };
            }),
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bridge.send(
          ClientMessage.input('hi', sessionId: 's1', clientMessageId: 'cm-hi'),
        );
        socket.add(
          jsonEncode({
            'type': 'input_ack',
            'sessionId': 's1',
            'clientMessageId': 'cm-hi',
            'acceptedSeq': 8,
            'queued': false,
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final cachedUserInputs = bridge
            .cachedSessionMessages('s1')
            .whereType<UserInputMessage>()
            .toList();
        expect(cachedUserInputs, hasLength(1));
        expect(cachedUserInputs.single.text, 'hi');
        expect(cachedUserInputs.single.clientMessageId, 'cm-hi');
        expect(bridge.cachedSessionHistorySeq('s1'), 8);

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'image input ack does not hide canonical history image refs',
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
        await Future<void>.delayed(const Duration(milliseconds: 50));

        socket.add(
          jsonEncode({
            'type': 'history_delta',
            'sessionId': 's1',
            'fromSeq': 1,
            'toSeq': 7,
            'messages': List.generate(7, (index) {
              return {
                'seq': index + 1,
                'message': {'type': 'status', 'status': 'running'},
              };
            }),
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bridge.send(
          ClientMessage.input(
            '',
            sessionId: 's1',
            clientMessageId: 'cm-img',
            images: const [
              {'base64': 'aW1hZ2U=', 'mimeType': 'image/png'},
            ],
          ),
        );
        socket.add(
          jsonEncode({
            'type': 'input_ack',
            'sessionId': 's1',
            'clientMessageId': 'cm-img',
            'acceptedSeq': 8,
            'queued': false,
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          bridge.cachedSessionMessages('s1').whereType<UserInputMessage>(),
          isEmpty,
        );
        expect(bridge.cachedSessionHistorySeq('s1'), 7);

        outgoing.clear();
        bridge.requestSessionHistory('s1');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final historyRequest =
            jsonDecode(outgoing.single.toJson()) as Map<String, dynamic>;
        expect(historyRequest, {
          'type': 'get_history_delta',
          'sessionId': 's1',
          'sinceSeq': 7,
        });

        socket.add(
          jsonEncode({
            'type': 'history_delta',
            'sessionId': 's1',
            'fromSeq': 8,
            'toSeq': 8,
            'messages': [
              {
                'seq': 8,
                'message': {
                  'type': 'user_input',
                  'text': '',
                  'clientMessageId': 'cm-img',
                  'imageCount': 1,
                  'images': [
                    {
                      'id': 'img-1',
                      'url': '/images/img-1',
                      'mimeType': 'image/png',
                    },
                  ],
                },
              },
            ],
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final cachedUserInputs = bridge
            .cachedSessionMessages('s1')
            .whereType<UserInputMessage>()
            .toList();
        expect(cachedUserInputs, hasLength(1));
        expect(cachedUserInputs.single.imageCount, 1);
        expect(cachedUserInputs.single.imageUrls, ['/images/img-1']);
        expect(bridge.cachedSessionHistorySeq('s1'), 8);

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test('unacked in-flight input is requeued when socket closes', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();

      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final socket = await socketReady.future;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bridge.send(
        ClientMessage.input(
          'retry after reconnect',
          sessionId: 's1',
          clientMessageId: 'cm-retry',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await socket.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('bridge_offline_pending_messages_v1');
      expect(raw, hasLength(1));
      expect(jsonDecode(raw!.single), {
        'type': 'input',
        'text': 'retry after reconnect',
        'sessionId': 's1',
        'clientMessageId': 'cm-retry',
      });

      bridge.disconnect();
      await server.close(force: true);
      bridge.dispose();
    });

    test('acked in-flight input is not requeued when socket closes', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();

      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final socket = await socketReady.future;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bridge.send(
        ClientMessage.input(
          'already accepted',
          sessionId: 's1',
          clientMessageId: 'cm-acked',
        ),
      );
      socket.add(
        jsonEncode({
          'type': 'input_ack',
          'sessionId': 's1',
          'clientMessageId': 'cm-acked',
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await socket.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('bridge_offline_pending_messages_v1'), isNull);

      bridge.disconnect();
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

      expect(bridge.offlinePendingActions, isEmpty);
      expect(
        received.where((message) => message['type'] == 'start'),
        hasLength(1),
      );

      await Future<void>.delayed(const Duration(milliseconds: 650));

      expect(bridge.offlinePendingActions, hasLength(1));
      expect(
        bridge.offlinePendingActions.single.kind,
        OfflinePendingActionKind.start,
      );
      expect(bridge.offlinePendingActions.single.canCancel, isFalse);

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

    test(
      'resume failure clears the processing action and allows retry',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();

        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${server.port}');
        final socket = await socketReady.future;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bridge.send(
          ClientMessage.resumeSession(
            'thread-with-images',
            '/home/user/app',
            provider: 'codex',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bridge.offlinePendingActions, isEmpty);

        socket.add(
          jsonEncode({
            'type': 'system',
            'subtype': 'session_resume_started',
            'sourceSessionId': 'thread-with-images',
            'provider': 'codex',
            'projectPath': '/home/user/app',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bridge.offlinePendingActions, hasLength(1));
        expect(
          bridge.offlinePendingActions.single.state,
          OfflinePendingActionState.processing,
        );
        expect(bridge.offlinePendingActions.single.canCancel, isFalse);

        socket.add(
          jsonEncode({
            'type': 'system',
            'subtype': 'session_resume_failed',
            'sourceSessionId': 'thread-with-images',
            'provider': 'codex',
            'projectPath': '/home/user/app',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bridge.offlinePendingActions, isEmpty);

        bridge.send(
          ClientMessage.resumeSession(
            'thread-with-images',
            '/home/user/app',
            provider: 'codex',
          ),
        );
        socket.add(
          jsonEncode({
            'type': 'system',
            'subtype': 'session_resume_started',
            'sourceSessionId': 'thread-with-images',
            'provider': 'codex',
            'projectPath': '/home/user/app',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bridge.offlinePendingActions, hasLength(1));
        expect(
          bridge.offlinePendingActions.single.state,
          OfflinePendingActionState.processing,
        );

        socket.add(
          jsonEncode({
            'type': 'system',
            'subtype': 'session_created',
            'sessionId': 'running-1',
            'claudeSessionId': 'thread-with-images',
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
      },
    );

    test(
      'clears connected pending start when session_created path differs',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();

        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${server.port}');
        final socket = await socketReady.future;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bridge.send(
          ClientMessage.start(
            '/mnt/obsidian-data/obsidian-vault',
            provider: 'codex',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 650));

        expect(bridge.offlinePendingActions, hasLength(1));

        socket.add(
          jsonEncode({
            'type': 'system',
            'subtype': 'session_created',
            'sessionId': 'running-1',
            'provider': 'codex',
            'projectPath': '/home/user/obsidian-vault',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bridge.offlinePendingActions, isEmpty);

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'session_list clears stale pending start for active session',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();

        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${server.port}');
        final socket = await socketReady.future;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bridge.send(
          ClientMessage.start(
            '/mnt/obsidian-data/obsidian-vault',
            provider: 'codex',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 650));

        expect(bridge.offlinePendingActions, hasLength(1));

        socket.add(
          jsonEncode({
            'type': 'session_list',
            'sessions': [
              {
                'id': 'running-1',
                'provider': 'codex',
                'projectPath': '/home/user/obsidian-vault',
                'status': 'running',
              },
            ],
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bridge.offlinePendingActions, isEmpty);
        expect(bridge.sessions.single.id, 'running-1');

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test('session_list keeps pending start for a different project', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();

      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final socket = await socketReady.future;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bridge.send(
        ClientMessage.start('/home/user/project-a', provider: 'codex'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 650));

      expect(bridge.offlinePendingActions, hasLength(1));

      socket.add(
        jsonEncode({
          'type': 'session_list',
          'sessions': [
            {
              'id': 'running-1',
              'provider': 'codex',
              'projectPath': '/home/user/project-b',
              'status': 'running',
            },
          ],
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bridge.offlinePendingActions, hasLength(1));
      expect(
        bridge.offlinePendingActions.single.projectPath,
        '/home/user/project-a',
      );

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
      expect(bridge.offlinePendingActions, isEmpty);

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
