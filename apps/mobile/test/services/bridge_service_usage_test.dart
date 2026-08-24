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

    test('auto-connect cancellation skips the saved Bridge URL', () async {
      SharedPreferences.setMockInitialValues({
        'bridge_url': 'ws://127.0.0.1:8765',
      });
      final bridge = BridgeService();
      var guardChecks = 0;

      final attempted = await bridge.autoConnect(
        shouldConnect: () => guardChecks++ == 0,
      );

      expect(attempted, isFalse);
      expect(guardChecks, 2);
      expect(
        bridge.currentBridgeConnectionState,
        BridgeConnectionState.disconnected,
      );
      bridge.dispose();
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

    test(
      'requestSessionHistory coalesces requests until history arrives',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();

        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
        });

        final outgoing = <ClientMessage>[];
        final bridge = BridgeService()..onOutgoingMessage = outgoing.add;
        final connected = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        bridge.connect('ws://127.0.0.1:${server.port}');

        final socket = await socketReady.future;
        await connected;
        bridge.requestSessionHistory('s1');
        bridge.requestSessionHistory('s1');

        expect(
          outgoing.where((message) => message.type == 'get_history'),
          hasLength(1),
        );

        socket.add(
          jsonEncode({
            'type': 'history',
            'sessionId': 's1',
            'messages': <Map<String, dynamic>>[],
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bridge.requestSessionHistory('s1');
        expect(
          outgoing.where((message) => message.type == 'get_history'),
          hasLength(2),
        );

        socket.add(
          jsonEncode({
            'type': 'error',
            'sessionId': 's1',
            'message': 'history read failed',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bridge.requestSessionHistory('s1');
        expect(
          outgoing.where(
            (message) =>
                message.type == 'get_history' ||
                message.type == 'get_history_delta',
          ),
          hasLength(3),
        );

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test('malformed history does not block the next retry', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();

      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
      });

      final outgoing = <ClientMessage>[];
      final bridge = BridgeService()..onOutgoingMessage = outgoing.add;
      final connected = bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      bridge.connect('ws://127.0.0.1:${server.port}');

      final socket = await socketReady.future;
      await connected;
      bridge.requestSessionHistory('s1');
      socket.add(
        jsonEncode({
          'type': 'history',
          'sessionId': 's1',
          'messages': 'malformed',
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bridge.requestSessionHistory('s1');
      expect(
        outgoing.where((message) => message.type == 'get_history'),
        hasLength(2),
      );

      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

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

    test('resolveSessionLink completes with the matching response', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();

      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final socket = await socketReady.future;
      final requestFuture = socket
          .where((event) {
            final json = jsonDecode(event as String) as Map<String, dynamic>;
            return json['type'] == 'resolve_session_link';
          })
          .map((event) => jsonDecode(event as String) as Map<String, dynamic>)
          .first;

      final resolutionFuture = bridge.resolveSessionLink(
        'claude-uuid',
        provider: 'claude',
      );
      final request = await requestFuture.timeout(const Duration(seconds: 2));
      socket.add(
        jsonEncode({
          'type': 'session_link_resolution',
          'requestId': request['requestId'],
          'sourceSessionId': 'claude-uuid',
          'status': 'live',
          'bridgeSessionId': 'bridge-1',
          'provider': 'claude',
        }),
      );

      final result = await resolutionFuture.timeout(const Duration(seconds: 2));
      expect(result.support, SessionLinkResolveSupport.resolved);
      expect(result.resolution?.bridgeSessionId, 'bridge-1');

      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test('push registration result stays out of session streams', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      server.transform(WebSocketTransformer()).listen(socketReady.complete);

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final connected = bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      final socket = await socketReady.future;
      await connected;
      final globalResult = bridge.messages
          .where((message) => message is PushRegistrationResultMessage)
          .cast<PushRegistrationResultMessage>()
          .first;
      final sessionResult = bridge
          .messagesForSession('s1')
          .where((message) => message is PushRegistrationResultMessage)
          .cast<PushRegistrationResultMessage>()
          .first
          .timeout(const Duration(milliseconds: 100));

      socket.add(
        jsonEncode({
          'type': 'push_registration_result',
          'token': 'sensitive-fcm-token',
          'requestId': 'push-request-1',
          'success': true,
        }),
      );

      expect((await globalResult).token, 'sensitive-fcm-token');
      await expectLater(sessionResult, throwsA(isA<TimeoutException>()));

      bridge.disconnect();
      bridge.dispose();
      await Future.any<void>([
        server.close(force: true).then<void>((_) {}),
        Future<void>.delayed(const Duration(seconds: 1)),
      ]);
    });

    test('resolveSessionLink degrades for an older Bridge', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();

      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final socket = await socketReady.future;
      final requestFuture = socket
          .where((event) {
            final json = jsonDecode(event as String) as Map<String, dynamic>;
            return json['type'] == 'resolve_session_link';
          })
          .map((event) => jsonDecode(event as String) as Map<String, dynamic>)
          .first;

      final resolutionFuture = bridge.resolveSessionLink('claude-uuid');
      await requestFuture.timeout(const Duration(seconds: 2));
      socket.add(
        jsonEncode({
          'type': 'error',
          'errorCode': 'unsupported_message',
          'message': 'resolve_session_link',
        }),
      );

      final result = await resolutionFuture.timeout(const Duration(seconds: 2));
      expect(result.support, SessionLinkResolveSupport.unsupported);

      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test('resolveSessionLink reconnects and retries a stale socket', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final firstSocketReady = Completer<WebSocket>();
      final secondSocketReady = Completer<WebSocket>();
      final firstRequestReady = Completer<void>();
      final resentInputReady = Completer<void>();
      var connectionCount = 0;

      server.transform(WebSocketTransformer()).listen((socket) {
        connectionCount++;
        if (connectionCount == 1) {
          firstSocketReady.complete(socket);
        } else if (connectionCount == 2) {
          secondSocketReady.complete(socket);
        }
        final socketNumber = connectionCount;
        socket.listen((event) {
          final json = jsonDecode(event as String) as Map<String, dynamic>;
          if (json['type'] == 'resolve_session_link') {
            if (socketNumber == 1 && !firstRequestReady.isCompleted) {
              firstRequestReady.complete();
            } else if (socketNumber == 2) {
              socket.add(
                jsonEncode({
                  'type': 'session_link_resolution',
                  'requestId': json['requestId'],
                  'sourceSessionId': 'claude-uuid',
                  'status': 'live',
                  'bridgeSessionId': 'bridge-1',
                  'provider': 'claude',
                }),
              );
            }
          }
          if (socketNumber == 2 &&
              json['type'] == 'input' &&
              json['clientMessageId'] == 'cm-during-reconnect' &&
              !resentInputReady.isCompleted) {
            resentInputReady.complete();
          }
        });
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      await firstSocketReady.future;

      final resolutionFuture = bridge.resolveSessionLink(
        'claude-uuid',
        provider: 'claude',
        timeout: const Duration(seconds: 2),
      );
      await firstRequestReady.future.timeout(const Duration(seconds: 1));
      bridge.send(
        ClientMessage.input(
          'keep this input',
          sessionId: 's1',
          clientMessageId: 'cm-during-reconnect',
        ),
      );

      // The first socket deliberately never answers. The resolver should
      // replace it, repeat the request, and preserve other in-flight input.
      final secondSocket = await secondSocketReady.future.timeout(
        const Duration(seconds: 2),
      );
      await resentInputReady.future.timeout(const Duration(seconds: 1));

      final result = await resolutionFuture.timeout(const Duration(seconds: 2));
      expect(result.support, SessionLinkResolveSupport.resolved);
      expect(result.resolution?.bridgeSessionId, 'bridge-1');
      expect(connectionCount, 2);

      bridge.disconnect();
      await secondSocket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test('stale reconnect does not interrupt an unresolved approval', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestReady = Completer<void>();
      final approvalReady = Completer<void>();
      var connectionCount = 0;

      server.transform(WebSocketTransformer()).listen((socket) {
        connectionCount++;
        socket.listen((event) {
          final json = jsonDecode(event as String) as Map<String, dynamic>;
          if (json['type'] == 'resolve_session_link' &&
              !requestReady.isCompleted) {
            requestReady.complete();
          }
          if (json['type'] == 'approve' && !approvalReady.isCompleted) {
            approvalReady.complete();
            socket.add(
              jsonEncode({
                'type': 'permission_resolved',
                'sessionId': 's2',
                'toolUseId': 'tool-1',
              }),
            );
          }
        });
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      await bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      final resolutionFuture = bridge.resolveSessionLink(
        'claude-uuid',
        timeout: const Duration(milliseconds: 700),
      );
      await requestReady.future.timeout(const Duration(seconds: 1));
      bridge.send(ClientMessage.approve('tool-1', sessionId: 's1'));
      await approvalReady.future.timeout(const Duration(seconds: 1));

      // A different session may legitimately reuse the same toolUseId. Its
      // response must not clear the guard for s1's unresolved approval.
      final result = await resolutionFuture;
      expect(result.support, SessionLinkResolveSupport.unavailable);
      expect(connectionCount, 1);

      bridge.disconnect();
      await server.close(force: true);
      bridge.dispose();
    });

    test(
      'clear-context session creation releases stale reconnect guard',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final firstRequestReady = Completer<void>();
        final clearContextReady = Completer<void>();
        var connectionCount = 0;

        server.transform(WebSocketTransformer()).listen((socket) {
          connectionCount++;
          final socketNumber = connectionCount;
          socket.listen((event) {
            final json = jsonDecode(event as String) as Map<String, dynamic>;
            if (json['type'] == 'resolve_session_link') {
              if (socketNumber == 1 && !firstRequestReady.isCompleted) {
                firstRequestReady.complete();
              } else if (socketNumber == 2) {
                socket.add(
                  jsonEncode({
                    'type': 'session_link_resolution',
                    'requestId': json['requestId'],
                    'sourceSessionId': 'claude-uuid',
                    'status': 'live',
                    'bridgeSessionId': 'bridge-after-clear',
                    'provider': 'claude',
                  }),
                );
              }
            }
            if (socketNumber == 1 && json['type'] == 'approve') {
              socket.add(
                jsonEncode({
                  'type': 'system',
                  'subtype': 'session_created',
                  'sessionId': 's2',
                  'sourceSessionId': 's1',
                  'clearContext': true,
                  'provider': 'claude',
                }),
              );
              if (!clearContextReady.isCompleted) {
                clearContextReady.complete();
              }
            }
          });
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${server.port}');
        await bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        final resolutionFuture = bridge.resolveSessionLink(
          'claude-uuid',
          timeout: const Duration(seconds: 2),
        );
        await firstRequestReady.future.timeout(const Duration(seconds: 1));
        bridge.send(
          ClientMessage.approve('tool-1', sessionId: 's1', clearContext: true),
        );
        await clearContextReady.future.timeout(const Duration(seconds: 1));

        final result = await resolutionFuture.timeout(
          const Duration(seconds: 3),
        );
        expect(result.support, SessionLinkResolveSupport.resolved);
        expect(result.resolution?.bridgeSessionId, 'bridge-after-clear');
        expect(connectionCount, 2);

        bridge.disconnect();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'correlated tool action error releases stale reconnect guard',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final firstRequestReady = Completer<void>();
        final actionErrorReady = Completer<void>();
        var connectionCount = 0;

        server.transform(WebSocketTransformer()).listen((socket) {
          connectionCount++;
          final socketNumber = connectionCount;
          socket.listen((event) {
            final json = jsonDecode(event as String) as Map<String, dynamic>;
            if (json['type'] == 'resolve_session_link') {
              if (socketNumber == 1 && !firstRequestReady.isCompleted) {
                firstRequestReady.complete();
              } else if (socketNumber == 2) {
                socket.add(
                  jsonEncode({
                    'type': 'session_link_resolution',
                    'requestId': json['requestId'],
                    'sourceSessionId': 'claude-uuid',
                    'status': 'live',
                    'bridgeSessionId': 'bridge-after-error',
                    'provider': 'claude',
                  }),
                );
              }
            }
            if (socketNumber == 1 && json['type'] == 'approve') {
              socket.add(
                jsonEncode({
                  'type': 'error',
                  'message': 'No matching pending tool action.',
                  'sessionId': 's1',
                  'toolUseId': 'tool-1',
                }),
              );
              if (!actionErrorReady.isCompleted) actionErrorReady.complete();
            }
          });
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${server.port}');
        await bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        final resolutionFuture = bridge.resolveSessionLink(
          'claude-uuid',
          timeout: const Duration(seconds: 2),
        );
        await firstRequestReady.future.timeout(const Duration(seconds: 1));
        bridge.send(ClientMessage.approve('tool-1', sessionId: 's1'));
        await actionErrorReady.future.timeout(const Duration(seconds: 1));

        final result = await resolutionFuture.timeout(
          const Duration(seconds: 3),
        );
        expect(result.support, SessionLinkResolveSupport.resolved);
        expect(result.resolution?.bridgeSessionId, 'bridge-after-error');
        expect(connectionCount, 2);

        bridge.disconnect();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'concurrent session link resolutions share one stale reconnect',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final twoInitialRequestsReady = Completer<void>();
        final secondSocketReady = Completer<WebSocket>();
        var connectionCount = 0;
        var initialRequestCount = 0;

        server.transform(WebSocketTransformer()).listen((socket) {
          connectionCount++;
          final socketNumber = connectionCount;
          if (socketNumber == 2) secondSocketReady.complete(socket);
          socket.listen((event) {
            final json = jsonDecode(event as String) as Map<String, dynamic>;
            if (json['type'] != 'resolve_session_link') return;
            if (socketNumber == 1) {
              initialRequestCount++;
              if (initialRequestCount == 2 &&
                  !twoInitialRequestsReady.isCompleted) {
                twoInitialRequestsReady.complete();
              }
              return;
            }
            socket.add(
              jsonEncode({
                'type': 'session_link_resolution',
                'requestId': json['requestId'],
                'sourceSessionId': json['sessionId'],
                'status': 'live',
                'bridgeSessionId': 'bridge-retried',
                'provider': 'claude',
              }),
            );
          });
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${server.port}');
        await bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        final first = bridge.resolveSessionLink(
          'claude-one',
          timeout: const Duration(seconds: 2),
        );
        final second = bridge.resolveSessionLink(
          'claude-two',
          timeout: const Duration(seconds: 2),
        );
        await twoInitialRequestsReady.future.timeout(
          const Duration(seconds: 1),
        );

        final results = await Future.wait([first, second]);
        expect(
          results.map((result) => result.support),
          unorderedEquals([
            SessionLinkResolveSupport.resolved,
            SessionLinkResolveSupport.unavailable,
          ]),
        );
        expect(connectionCount, 2);

        bridge.disconnect();
        await (await secondSocketReady.future).close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'resolveSessionLink keeps a responsive socket while resolution is slow',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();
        var connectionCount = 0;

        server.transform(WebSocketTransformer()).listen((socket) {
          connectionCount++;
          if (!socketReady.isCompleted) socketReady.complete(socket);
          socket.listen((event) {
            final json = jsonDecode(event as String) as Map<String, dynamic>;
            switch (json['type']) {
              case 'list_sessions':
                socket.add(
                  jsonEncode({
                    'type': 'session_list',
                    'sessions': <Object>[],
                    'allowedDirs': <Object>[],
                  }),
                );
              case 'resolve_session_link':
                Timer(const Duration(milliseconds: 550), () {
                  socket.add(
                    jsonEncode({
                      'type': 'session_link_resolution',
                      'requestId': json['requestId'],
                      'sourceSessionId': 'claude-uuid',
                      'status': 'live',
                      'bridgeSessionId': 'bridge-slow',
                      'provider': 'claude',
                    }),
                  );
                });
            }
          });
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${server.port}');
        final socket = await socketReady.future;

        final result = await bridge.resolveSessionLink(
          'claude-uuid',
          provider: 'claude',
          timeout: const Duration(milliseconds: 900),
        );

        expect(result.support, SessionLinkResolveSupport.resolved);
        expect(result.resolution?.bridgeSessionId, 'bridge-slow');
        expect(connectionCount, 1);

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test('resolveSessionLink respects an intentional disconnect', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      var connectionCount = 0;

      server.transform(WebSocketTransformer()).listen((socket) {
        connectionCount++;
        if (!socketReady.isCompleted) socketReady.complete(socket);
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final connected = bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      await socketReady.future;
      await connected;
      bridge.disconnect();

      final result = await bridge.resolveSessionLink(
        'claude-uuid',
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.support, SessionLinkResolveSupport.unavailable);
      expect(connectionCount, 1);

      bridge.dispose();
      await Future.any<void>([
        server.close(force: true).then<void>((_) {}),
        Future<void>.delayed(const Duration(seconds: 1)),
      ]);
    });

    test(
      'resolveSessionLink does not replace a newly selected Bridge',
      () async {
        final firstServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final secondServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final firstSocketReady = Completer<WebSocket>();
        final secondSocketReady = Completer<WebSocket>();
        final firstRequestReady = Completer<void>();
        var secondResolveRequests = 0;

        firstServer.transform(WebSocketTransformer()).listen((socket) {
          if (!firstSocketReady.isCompleted) {
            firstSocketReady.complete(socket);
          }
          socket.listen((event) {
            final json = jsonDecode(event as String) as Map<String, dynamic>;
            if (json['type'] == 'resolve_session_link' &&
                !firstRequestReady.isCompleted) {
              firstRequestReady.complete();
            }
          });
        });
        secondServer.transform(WebSocketTransformer()).listen((socket) {
          if (!secondSocketReady.isCompleted) {
            secondSocketReady.complete(socket);
          }
          socket.listen((event) {
            final json = jsonDecode(event as String) as Map<String, dynamic>;
            if (json['type'] == 'resolve_session_link') {
              secondResolveRequests++;
            }
          });
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${firstServer.port}');
        await firstSocketReady.future;
        final resolutionFuture = bridge.resolveSessionLink(
          'claude-uuid',
          timeout: const Duration(milliseconds: 600),
        );
        await firstRequestReady.future.timeout(const Duration(seconds: 1));

        bridge.connect('ws://127.0.0.1:${secondServer.port}');
        final secondConnected = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        await secondSocketReady.future;
        await secondConnected;

        final result = await resolutionFuture;
        expect(result.support, SessionLinkResolveSupport.unavailable);
        expect(secondResolveRequests, 0);
        expect(bridge.isConnected, isTrue);

        bridge.disconnect();
        bridge.dispose();
        await Future.any<void>([
          firstServer.close(force: true).then<void>((_) {}),
          Future<void>.delayed(const Duration(seconds: 1)),
        ]);
        await Future.any<void>([
          secondServer.close(force: true).then<void>((_) {}),
          Future<void>.delayed(const Duration(seconds: 1)),
        ]);
      },
    );

    test(
      'resolveSessionLink revalidates the Bridge after reconnect waiting',
      () async {
        final staleServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final selectedServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final firstSocketReady = Completer<WebSocket>();
        final firstRequestReady = Completer<void>();
        final reconnectAttemptStarted = Completer<void>();
        final allowStaleUpgrade = Completer<void>();
        final selectedSocketReady = Completer<WebSocket>();
        var staleConnectionCount = 0;
        var selectedResolveRequests = 0;

        staleServer.listen((request) async {
          staleConnectionCount++;
          final connectionNumber = staleConnectionCount;
          if (connectionNumber == 2) {
            reconnectAttemptStarted.complete();
            await allowStaleUpgrade.future;
          }
          try {
            final socket = await WebSocketTransformer.upgrade(request);
            if (connectionNumber == 1) firstSocketReady.complete(socket);
            socket.listen((event) {
              final json = jsonDecode(event as String) as Map<String, dynamic>;
              if (json['type'] == 'resolve_session_link' &&
                  !firstRequestReady.isCompleted) {
                firstRequestReady.complete();
              }
            });
          } on Object {
            // The delayed stale handshake may be cancelled by the switch.
          }
        });
        selectedServer.transform(WebSocketTransformer()).listen((socket) {
          if (!selectedSocketReady.isCompleted) {
            selectedSocketReady.complete(socket);
          }
          socket.listen((event) {
            final json = jsonDecode(event as String) as Map<String, dynamic>;
            if (json['type'] == 'resolve_session_link') {
              selectedResolveRequests++;
            }
          });
        });

        final bridge = BridgeService();
        bridge.connect('ws://127.0.0.1:${staleServer.port}');
        final firstSocket = await firstSocketReady.future;
        final resolutionFuture = bridge.resolveSessionLink(
          'claude-uuid',
          timeout: const Duration(seconds: 2),
        );
        await firstRequestReady.future.timeout(const Duration(seconds: 1));
        await reconnectAttemptStarted.future.timeout(
          const Duration(seconds: 2),
        );

        bridge.connect('ws://127.0.0.1:${selectedServer.port}');
        final selectedSocket = await selectedSocketReady.future;
        allowStaleUpgrade.complete();

        final result = await resolutionFuture;
        expect(result.support, SessionLinkResolveSupport.unavailable);
        expect(selectedResolveRequests, 0);
        expect(bridge.isConnected, isTrue);

        bridge.disconnect();
        await firstSocket.close();
        await selectedSocket.close();
        await staleServer.close(force: true);
        await selectedServer.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'resolveSessionLink returns unavailable when disposed while waiting',
      () async {
        final bridge = BridgeService();
        final resolutionFuture = bridge.resolveSessionLink(
          'claude-uuid',
          timeout: const Duration(seconds: 1),
        );
        await Future<void>.delayed(Duration.zero);

        bridge.dispose();

        final result = await resolutionFuture;
        expect(result.support, SessionLinkResolveSupport.unavailable);
      },
    );

    test('resolveSessionLink waits for a connection without queueing a stale request', () async {
      final bridge = BridgeService();
      final outgoing = <ClientMessage>[];
      bridge.onOutgoingMessage = outgoing.add;

      final result = await bridge.resolveSessionLink(
        'claude-uuid',
        timeout: const Duration(milliseconds: 20),
      );

      expect(result.support, SessionLinkResolveSupport.unavailable);
      expect(outgoing, isEmpty);
      bridge.dispose();
    });

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

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('bridge_offline_pending_messages_v1'),
        hasLength(1),
      );

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
      expect(prefs.getStringList('bridge_offline_pending_messages_v1'), isNull);

      final restoredBridge = BridgeService();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(restoredBridge.offlinePendingActions, isEmpty);
      restoredBridge.dispose();

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

    test('keeps an unacknowledged stop durable across a socket drop', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();

      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final socket = await socketReady.future;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bridge.stopSession('session-to-stop');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      var prefs = await SharedPreferences.getInstance();
      var raw = prefs.getStringList('bridge_offline_pending_messages_v1');
      expect(raw, hasLength(1));
      expect(jsonDecode(raw!.single), {
        'type': 'stop_session',
        'sessionId': 'session-to-stop',
      });

      await socket.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      prefs = await SharedPreferences.getInstance();
      raw = prefs.getStringList('bridge_offline_pending_messages_v1');
      expect(raw, hasLength(1));
      expect(jsonDecode(raw!.single), containsPair('type', 'stop_session'));

      bridge.disconnect();
      await server.close(force: true);
      bridge.dispose();
    });

    test(
      'clears a durable stop only after the Bridge acknowledges it',
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

        bridge.stopSession('session-to-stop');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        socket.add(
          jsonEncode({
            'type': 'result',
            'subtype': 'stopped',
            'sessionId': 'session-to-stop',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('bridge_offline_pending_messages_v1'),
          isNull,
        );

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

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
