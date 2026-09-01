import 'dart:async';
import 'dart:convert';
import 'dart:io' hide WebSocketTransformer;
import 'dart:io' as io show WebSocketTransformer;

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/offline_pending_action.dart';
import 'package:ccpocket/models/protocol_version.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _galleryImageJson(
  String id, {
  String? sessionId,
  String projectPath = '/tmp/project',
}) => {
  'id': id,
  'url': '/api/gallery/$id',
  'mimeType': 'image/png',
  'projectPath': projectPath,
  'projectName': projectPath.split('/').last,
  'sessionId': ?sessionId,
  'addedAt': '2026-08-25T00:00:00Z',
  'sizeBytes': 100,
};

bool _automaticallyAnnounceLegacyProtocol = true;

/// Mirrors the production Bridge handshake for test servers that only care
/// about the request or response under test. Protocol-specific tests can opt
/// out and control the handshake themselves.
class WebSocketTransformer
    extends StreamTransformerBase<HttpRequest, WebSocket> {
  @override
  Stream<WebSocket> bind(Stream<HttpRequest> stream) {
    return io.WebSocketTransformer().bind(stream).map((socket) {
      if (_automaticallyAnnounceLegacyProtocol) {
        socket.add(
          jsonEncode({'type': 'session_list', 'sessions': <Object>[]}),
        );
      }
      return socket;
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BridgeService usage cache', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      _automaticallyAnnounceLegacyProtocol = true;
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
      expect(bridge.protocolCompatibility?.isCompatible, isTrue);
      expect(bridge.protocolCompatibility?.assumedLegacyBridge, isTrue);

      bridge.disconnect();

      expect(bridge.allowedDirs, isEmpty);
      expect(bridge.projectHistory, isEmpty);
      expect(bridge.codexProfiles, isEmpty);
      expect(bridge.bridgeVersion, isNull);
      expect(bridge.protocolCompatibility, isNull);

      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
      bridge.dispose();
    });

    test('rejects a Bridge with a non-overlapping protocol range', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<void>();

      server.transform(WebSocketTransformer()).listen((socket) {
        socket.add(
          jsonEncode({
            'type': 'session_list',
            'sessions': <Object>[],
            'protocolVersion': 2,
            'minimumProtocolVersion': 2,
          }),
        );
        socket.add(
          jsonEncode({
            'type': 'project_history',
            'projects': ['/must-not-be-accepted'],
          }),
        );
        socketReady.complete();
      });

      final bridge = BridgeService();
      final incompatible = bridge.messages
          .where((message) => message is ErrorMessage)
          .cast<ErrorMessage>()
          .firstWhere(
            (message) => message.errorCode == 'incompatible_protocol',
          );
      bridge.connect('ws://127.0.0.1:${server.port}');

      await socketReady.future;
      final error = await incompatible.timeout(const Duration(seconds: 1));

      expect(error.message, contains('Bridge protocol range 2-2'));
      expect(bridge.protocolCompatibility?.isCompatible, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bridge.projectHistory, isEmpty);
      expect(
        bridge.currentBridgeConnectionState,
        BridgeConnectionState.disconnected,
      );

      bridge.dispose();
      await server.close(force: true);
    });

    test(
      'Bridge protocol rejection is terminal and does not reconnect',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var connectionCount = 0;
        final firstConnection = Completer<void>();

        server.transform(WebSocketTransformer()).listen((socket) {
          connectionCount++;
          socket.add(
            jsonEncode({
              'type': 'error',
              'errorCode': 'incompatible_protocol',
              'message': 'Client protocol is not supported by this Bridge.',
              'protocolVersion': 2,
              'minimumProtocolVersion': 2,
            }),
          );
          unawaited(socket.close(4406, 'Incompatible protocol version'));
          if (!firstConnection.isCompleted) firstConnection.complete();
        });

        final bridge = BridgeService();
        final incompatible = bridge.messages
            .where((message) => message is ErrorMessage)
            .cast<ErrorMessage>()
            .firstWhere(
              (message) => message.errorCode == 'incompatible_protocol',
            );
        bridge.connect('ws://127.0.0.1:${server.port}');

        await firstConnection.future;
        final error = await incompatible.timeout(const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 2200));

        expect(error.message, contains('not supported'));
        expect(connectionCount, 1);
        expect(bridge.protocolCompatibility?.isCompatible, isFalse);
        expect(
          bridge.protocolCompatibility?.updateTarget,
          ProtocolUpdateTarget.app,
        );
        expect(
          bridge.currentBridgeConnectionState,
          BridgeConnectionState.disconnected,
        );

        bridge.dispose();
        await server.close(force: true);
      },
    );

    test(
      'malformed Bridge protocol rejections fail closed without reconnecting',
      () async {
        final declarations = <Map<String, dynamic>>[
          <String, dynamic>{},
          {'minimumProtocolVersion': 1},
          {'protocolVersion': '2', 'minimumProtocolVersion': 1},
          {'protocolVersion': 1, 'minimumProtocolVersion': 2},
          {'protocolVersion': 0, 'minimumProtocolVersion': 0},
        ];

        for (var index = 0; index < declarations.length; index++) {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          var connectionCount = 0;
          server.transform(WebSocketTransformer()).listen((socket) {
            connectionCount++;
            socket.add(
              jsonEncode({
                'type': 'error',
                'errorCode': 'incompatible_protocol',
                'message': 'Malformed protocol rejection.',
                ...declarations[index],
              }),
            );
          });

          final bridge = BridgeService();
          final errorFuture = bridge.messages
              .where((message) => message is ErrorMessage)
              .cast<ErrorMessage>()
              .firstWhere(
                (message) => message.errorCode == 'incompatible_protocol',
              );
          bridge.connect('ws://127.0.0.1:${server.port}');
          await errorFuture.timeout(const Duration(seconds: 1));

          expect(
            bridge.protocolCompatibility?.malformedBridgeRange,
            isTrue,
            reason: '${declarations[index]} must fail closed',
          );
          expect(
            bridge.protocolCompatibility?.updateTarget,
            ProtocolUpdateTarget.both,
          );
          expect(
            bridge.currentBridgeConnectionState,
            BridgeConnectionState.disconnected,
          );
          if (index == declarations.length - 1) {
            await Future<void>.delayed(const Duration(milliseconds: 1200));
            expect(connectionCount, 1);
          }

          bridge.dispose();
          await server.close(force: true);
        }
      },
    );

    test(
      'protocol rejection requeues in-flight input for a manual reconnect',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var connectionCount = 0;
        var matchingInputCount = 0;
        final firstRejected = Completer<void>();
        final resentInput = Completer<void>();

        server.transform(WebSocketTransformer()).listen((socket) {
          connectionCount++;
          final socketNumber = connectionCount;
          if (socketNumber == 2) {
            socket.add(
              jsonEncode({
                'type': 'session_list',
                'sessions': <Object>[],
                'protocolVersion': 1,
                'minimumProtocolVersion': 1,
              }),
            );
          }
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] != 'input' ||
                json['clientMessageId'] != 'cm-protocol-retry') {
              return;
            }
            matchingInputCount++;
            if (socketNumber == 1) {
              socket.add(
                jsonEncode({
                  'type': 'session_list',
                  'sessions': <Object>[],
                  'protocolVersion': 2,
                  'minimumProtocolVersion': 2,
                }),
              );
              if (!firstRejected.isCompleted) firstRejected.complete();
            } else if (!resentInput.isCompleted) {
              resentInput.complete();
            }
          });
        });

        final bridge = BridgeService();
        bridge.send(
          ClientMessage.input(
            'preserve me',
            sessionId: 's1',
            clientMessageId: 'cm-protocol-retry',
          ),
        );
        bridge.connect('ws://127.0.0.1:${server.port}');

        await firstRejected.future.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bridge.connect('ws://127.0.0.1:${server.port}');
        await resentInput.future.timeout(const Duration(seconds: 2));

        expect(connectionCount, 2);
        expect(matchingInputCount, 2);

        bridge.disconnect();
        await server.close(force: true);
        bridge.dispose();
      },
    );

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
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('bridge_offline_pending_messages_v1'),
          isNull,
        );

        final restoredBridge = BridgeService();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(restoredBridge.offlinePendingActions, isEmpty);
        restoredBridge.dispose();

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

    test('unscoped global errors stay out of session streams', () async {
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
      final globalError = bridge.messages
          .where((message) => message is ErrorMessage)
          .cast<ErrorMessage>()
          .first
          .timeout(const Duration(seconds: 2));
      final sessionError = bridge
          .messagesForSession('s1')
          .where((message) => message is ErrorMessage)
          .cast<ErrorMessage>()
          .first
          .timeout(const Duration(milliseconds: 100));

      socket.add(
        jsonEncode({
          'type': 'error',
          'message': 'Failed to list files',
          'errorCode': 'file_list_failed',
        }),
      );

      expect((await globalError).message, 'Failed to list files');
      await expectLater(sessionError, throwsA(isA<TimeoutException>()));

      bridge.disconnect();
      bridge.dispose();
      await Future.any<void>([
        server.close(force: true).then<void>((_) {}),
        Future<void>.delayed(const Duration(seconds: 1)),
      ]);
    });

    test('scoped errors reach only their addressed session', () async {
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
      final addressed = bridge
          .messagesForSession('s1')
          .where((message) => message is ErrorMessage)
          .cast<ErrorMessage>()
          .first;
      final other = bridge
          .messagesForSession('s2')
          .where((message) => message is ErrorMessage)
          .cast<ErrorMessage>()
          .first
          .timeout(const Duration(milliseconds: 100));

      socket.add(
        jsonEncode({
          'type': 'error',
          'sessionId': 's1',
          'message': 'No active session.',
        }),
      );

      expect((await addressed).sessionId, 's1');
      await expectLater(other, throwsA(isA<TimeoutException>()));

      bridge.disconnect();
      bridge.dispose();
      await Future.any<void>([
        server.close(force: true).then<void>((_) {}),
        Future<void>.delayed(const Duration(seconds: 1)),
      ]);
    });

    test('file lists are routed to their requested projects', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      final requests = <Map<String, dynamic>>[];
      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
        socket.listen((data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] == 'list_files') requests.add(json);
        });
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final connected = bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      final socket = await socketReady.future;
      await connected;
      socket.add(
        jsonEncode({
          'type': 'session_list',
          'sessions': <Object>[],
          'protocolCapabilities': ['project_request_correlation_v1'],
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final projectA = bridge.fileListMessagesForProject('/project-a').first;
      final projectB = bridge.fileListMessagesForProject('/project-b').first;
      bridge.requestFileList('/project-a');
      bridge.requestFileList('/project-b');
      while (requests.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      for (final request in requests.reversed) {
        socket.add(
          jsonEncode({
            'type': 'file_list',
            'projectPath': request['projectPath'],
            'requestId': request['requestId'],
            'files': ['${request['projectPath']}/only.dart'],
          }),
        );
      }

      expect((await projectA).projectPath, '/project-a');
      expect((await projectB).projectPath, '/project-b');
      expect(bridge.fileListForProject('/project-a'), ['/project-a/only.dart']);
      expect(bridge.fileListForProject('/project-b'), ['/project-b/only.dart']);

      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test('legacy file lists are serialized across projects', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      final requests = <Map<String, dynamic>>[];
      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
        socket.listen((data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] == 'list_files') requests.add(json);
        });
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final connected = bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      final socket = await socketReady.future;
      await connected;
      socket.add(jsonEncode({'type': 'session_list', 'sessions': <Object>[]}));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final projectA = bridge.fileListMessagesForProject('/project-a').first;
      final projectB = bridge.fileListMessagesForProject('/project-b').first;
      bridge.requestFileList('/project-a');
      bridge.requestFileList('/project-b');
      while (requests.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(requests, hasLength(1));
      expect(requests.single['requestId'], isNull);

      socket.add(
        jsonEncode({
          'type': 'file_list',
          'files': ['a.dart'],
        }),
      );
      expect((await projectA).files, ['a.dart']);
      while (requests.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(requests[1]['projectPath'], '/project-b');

      socket.add(
        jsonEncode({
          'type': 'file_list',
          'files': ['b.dart'],
        }),
      );
      expect((await projectB).files, ['b.dart']);

      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test('worktree lists are routed to their requested projects', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      final requests = <Map<String, dynamic>>[];
      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
        socket.listen((data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] == 'list_worktrees') requests.add(json);
        });
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final connected = bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      final socket = await socketReady.future;
      await connected;
      // Advertise correlation support, as the current Bridge does.
      socket.add(
        jsonEncode({
          'type': 'session_list',
          'sessions': <Object>[],
          'protocolCapabilities': ['project_request_correlation_v1'],
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final updates = <WorktreeListMessage>[];
      final subscription = bridge.worktreeList.listen(updates.add);
      bridge.requestWorktreeList('/project-a');
      bridge.requestWorktreeList('/project-b');
      while (requests.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      socket.add(
        jsonEncode({
          'type': 'worktree_list',
          'worktrees': <Object>[],
          'mainBranch': 'ambiguous',
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(updates, isEmpty);

      for (final request in requests.reversed) {
        socket.add(
          jsonEncode({
            'type': 'worktree_list',
            'projectPath': request['projectPath'],
            'requestId': request['requestId'],
            'worktrees': <Object>[],
            'mainBranch': 'main',
          }),
        );
      }
      while (updates.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(updates.map((message) => message.projectPath), [
        '/project-b',
        '/project-a',
      ]);

      await subscription.cancel();
      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test('legacy worktree lists are serialized across projects', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      final requests = <Map<String, dynamic>>[];
      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
        socket.listen((data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] == 'list_worktrees') requests.add(json);
        });
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final connected = bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      final socket = await socketReady.future;
      await connected;
      socket.add(jsonEncode({'type': 'session_list', 'sessions': <Object>[]}));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final updates = <WorktreeListMessage>[];
      final subscription = bridge.worktreeList.listen(updates.add);
      bridge.requestWorktreeList('/project-a');
      bridge.requestWorktreeList('/project-b');
      while (requests.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(requests, hasLength(1));

      socket.add(
        jsonEncode({
          'type': 'worktree_list',
          'worktrees': <Object>[],
          'mainBranch': 'main-a',
        }),
      );
      while (updates.isEmpty || requests.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(updates.single.projectPath, '/project-a');
      expect(requests[1]['projectPath'], '/project-b');

      socket.add(
        jsonEncode({
          'type': 'worktree_list',
          'worktrees': <Object>[],
          'mainBranch': 'main-b',
        }),
      );
      while (updates.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(updates.last.projectPath, '/project-b');

      await subscription.cancel();
      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test('legacy worktree removals are serialized across projects', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      final requests = <Map<String, dynamic>>[];
      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
        socket.listen((data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] == 'remove_worktree') requests.add(json);
        });
      });

      final bridge = BridgeService();
      bridge.connect('ws://127.0.0.1:${server.port}');
      final connected = bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      final socket = await socketReady.future;
      await connected;
      socket.add(jsonEncode({'type': 'session_list', 'sessions': <Object>[]}));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final updates = <WorktreeRemovedMessage>[];
      final subscription = bridge.messages
          .where((message) => message is WorktreeRemovedMessage)
          .cast<WorktreeRemovedMessage>()
          .listen(updates.add);
      bridge.removeWorktree('/project-a', '/worktree-a');
      bridge.removeWorktree('/project-b', '/worktree-b');
      while (requests.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(requests, hasLength(1));
      expect(requests.single['projectPath'], '/project-a');

      socket.add(
        jsonEncode({'type': 'worktree_removed', 'worktreePath': '/worktree-a'}),
      );
      while (updates.isEmpty || requests.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(updates.single.projectPath, '/project-a');
      expect(requests[1]['projectPath'], '/project-b');

      socket.add(
        jsonEncode({'type': 'worktree_removed', 'worktreePath': '/worktree-b'}),
      );
      while (updates.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(updates.last.projectPath, '/project-b');

      await subscription.cancel();
      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test(
      'legacy ambiguous worktree errors wait for timeout before releasing',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();
        final sockets = <WebSocket>[];
        final requests = <Map<String, dynamic>>[];
        final fileListRequests = <Map<String, dynamic>>[];
        final worktreeListRequests = <Map<String, dynamic>>[];
        server.transform(WebSocketTransformer()).listen((socket) {
          sockets.add(socket);
          if (!socketReady.isCompleted) {
            socketReady.complete(socket);
          } else {
            socket.add(
              jsonEncode({'type': 'session_list', 'sessions': <Object>[]}),
            );
          }
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'remove_worktree') requests.add(json);
            if (json['type'] == 'list_files') fileListRequests.add(json);
            if (json['type'] == 'list_worktrees') {
              worktreeListRequests.add(json);
            }
          });
        });

        final bridge = BridgeService(
          legacyWorktreeRemoveRequestTimeout: const Duration(milliseconds: 30),
        );
        bridge.connect('ws://127.0.0.1:${server.port}');
        final connected = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        final socket = await socketReady.future;
        await connected;
        socket.add(
          jsonEncode({'type': 'session_list', 'sessions': <Object>[]}),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final failures = <WorktreeRemovedMessage>[];
        final subscription = bridge.messages
            .where((message) => message is WorktreeRemovedMessage)
            .cast<WorktreeRemovedMessage>()
            .listen(failures.add);
        bridge.requestFileList('/files-a');
        bridge.requestFileList('/files-b');
        bridge.requestWorktreeList('/trees-a');
        bridge.requestWorktreeList('/trees-b');
        bridge.removeWorktree('/project-a', '/worktree-a');
        bridge.removeWorktree('/project-b', '/worktree-b');
        while (requests.isEmpty ||
            fileListRequests.isEmpty ||
            worktreeListRequests.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(requests, hasLength(1));
        expect(fileListRequests, hasLength(1));
        expect(worktreeListRequests, hasLength(1));

        socket.add(
          jsonEncode({
            'type': 'error',
            'errorCode': 'path_not_allowed',
            'message': 'Project path not allowed',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(failures, isEmpty);
        while (failures.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        while (failures.length < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(sockets, hasLength(1));
        expect(requests, hasLength(1));
        final failure = failures.first;
        expect(failure.projectPath, '/project-a');
        expect(failure.worktreePath, '/worktree-a');
        expect(failure.error, contains('did not complete in time'));
        expect(failures[1].projectPath, '/project-b');
        expect(failures[1].error, contains('was not sent'));

        socket.add(jsonEncode({'type': 'file_list', 'files': <String>[]}));
        socket.add(
          jsonEncode({
            'type': 'worktree_list',
            'worktrees': <Object>[],
            'mainBranch': 'main',
          }),
        );
        while (fileListRequests.length < 2 || worktreeListRequests.length < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(fileListRequests[1]['projectPath'], '/files-b');
        expect(worktreeListRequests[1]['projectPath'], '/trees-b');

        bridge.removeWorktree('/project-c', '/worktree-c');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(requests, hasLength(1));
        expect(failures, hasLength(3));
        expect(failures.last.error, contains('unavailable on this connection'));

        final reconnected = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        bridge.connect('ws://127.0.0.1:${server.port}');
        await reconnected;
        while (sockets.length < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        bridge.removeWorktree('/project-d', '/worktree-d');
        while (requests.length < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        sockets.last.add(
          jsonEncode({
            'type': 'error',
            'message': 'Failed to remove worktree: branch is checked out',
          }),
        );
        while (failures.length < 4) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(failures.last.projectPath, '/project-d');
        expect(failures.last.worktreePath, '/worktree-d');
        expect(failures.last.error, contains('branch is checked out'));

        await subscription.cancel();
        bridge.disconnect();
        for (final activeSocket in sockets) {
          await activeSocket.close();
        }
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test('dispose cancels a legacy worktree removal timeout', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      server.transform(WebSocketTransformer()).listen(socketReady.complete);

      final bridge = BridgeService(
        legacyWorktreeRemoveRequestTimeout: const Duration(milliseconds: 20),
      );
      bridge.connect('ws://127.0.0.1:${server.port}');
      final connected = bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      final socket = await socketReady.future;
      await connected;
      socket.add(jsonEncode({'type': 'session_list', 'sessions': <Object>[]}));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bridge.removeWorktree('/project-a', '/worktree-a');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      bridge.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await socket.close();
      await server.close(force: true);
    });

    test(
      'capability learned after send lets the next removal use correlation',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();
        final requests = <Map<String, dynamic>>[];
        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'remove_worktree') requests.add(json);
          });
        });

        final bridge = BridgeService(
          legacyWorktreeRemoveRequestTimeout: const Duration(milliseconds: 30),
        );
        bridge.connect('ws://127.0.0.1:${server.port}');
        final connected = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        final socket = await socketReady.future;
        await connected;

        final updates = <WorktreeRemovedMessage>[];
        final subscription = bridge.messages
            .where((message) => message is WorktreeRemovedMessage)
            .cast<WorktreeRemovedMessage>()
            .listen(updates.add);
        bridge.removeWorktree('/project-a', '/worktree-a');
        bridge.removeWorktree('/project-b', '/worktree-b');
        while (requests.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(requests.single['requestId'], isNull);

        socket.add(
          jsonEncode({
            'type': 'session_list',
            'sessions': <Object>[],
            'protocolCapabilities': <String>['project_request_correlation_v1'],
          }),
        );
        while (requests.length < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(requests[1]['projectPath'], '/project-b');
        expect(requests[1]['requestId'], isNotNull);

        socket.add(
          jsonEncode({
            'type': 'worktree_removed',
            'projectPath': '/project-b',
            'requestId': requests[1]['requestId'],
            'worktreePath': '/worktree-b',
          }),
        );
        while (updates.length < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(updates.first.projectPath, '/project-a');
        expect(updates.first.error, contains('did not complete in time'));
        expect(updates.last.projectPath, '/project-b');
        expect(updates.last.error, isNull);

        await subscription.cancel();
        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'worktree requests can retry after their transport disconnects',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final sockets = <WebSocket>[];
        final firstSocketReady = Completer<WebSocket>();
        final secondSocketReady = Completer<WebSocket>();
        final firstRequestReady = Completer<Map<String, dynamic>>();
        final secondRequestReady = Completer<Map<String, dynamic>>();
        server.transform(WebSocketTransformer()).listen((socket) {
          sockets.add(socket);
          final socketIndex = sockets.length;
          if (socketIndex == 1) {
            firstSocketReady.complete(socket);
          } else if (socketIndex == 2) {
            secondSocketReady.complete(socket);
          }
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] != 'list_worktrees') return;
            if (socketIndex == 1 && !firstRequestReady.isCompleted) {
              firstRequestReady.complete(json);
            } else if (socketIndex == 2 && !secondRequestReady.isCompleted) {
              secondRequestReady.complete(json);
            }
          });
        });

        final bridge = BridgeService();
        addTearDown(() async {
          bridge.disconnect();
          for (final socket in sockets) {
            unawaited(socket.close());
          }
          try {
            await server.close(force: true);
          } finally {
            bridge.dispose();
          }
        });
        final connected = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        bridge.connect('ws://127.0.0.1:${server.port}');
        final firstSocket = await firstSocketReady.future.timeout(
          const Duration(seconds: 5),
        );
        await connected.timeout(const Duration(seconds: 5));
        bridge.requestWorktreeList('/project-a');
        await firstRequestReady.future.timeout(const Duration(seconds: 5));

        final reconnecting = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.reconnecting,
        );
        // A server-side WebSocket close waits for the peer's close frame on
        // Windows. Sending the close is enough to exercise reconnect behavior.
        unawaited(firstSocket.close());
        await reconnecting.timeout(const Duration(seconds: 5));
        bridge.requestWorktreeList('/project-a');

        // Automatic reconnect uses a two-second initial backoff, so leave
        // scheduling headroom for slower Windows GitHub runners.
        await secondSocketReady.future.timeout(const Duration(seconds: 5));
        final retriedRequest = await secondRequestReady.future.timeout(
          const Duration(seconds: 5),
        );
        expect(retriedRequest['projectPath'], '/project-a');
      },
    );

    test(
      'request IDs are omitted until the Bridge advertises support',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();
        server.transform(WebSocketTransformer()).listen(socketReady.complete);

        final bridge = BridgeService();
        expect(bridge.projectRequestIdForWire('offline-request'), isNull);
        bridge.connect('ws://127.0.0.1:${server.port}');
        final connected = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        final socket = await socketReady.future;
        await connected;

        socket.add(
          jsonEncode({'type': 'session_list', 'sessions': <Object>[]}),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(bridge.projectRequestIdForWire('request-1'), isNull);

        socket.add(
          jsonEncode({
            'type': 'session_list',
            'sessions': <Object>[],
            'protocolCapabilities': ['project_request_correlation_v1'],
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(bridge.projectRequestIdForWire('request-2'), 'request-2');

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'offline Git requests remain compatible with a legacy Bridge',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();
        final requestReady = Completer<Map<String, dynamic>>();
        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'git_branches' && !requestReady.isCompleted) {
              requestReady.complete(json);
            }
          });
        });

        final bridge = BridgeService();
        final requestId = bridge.createProjectRequestId('git-branches');
        bridge.send(
          ClientMessage.gitBranches(
            '/project-a',
            requestId: bridge.projectRequestIdForWire(requestId),
          ),
        );
        bridge.connect('ws://127.0.0.1:${server.port}');
        final socket = await socketReady.future;
        final request = await requestReady.future;

        expect(request['projectPath'], '/project-a');
        expect(request.containsKey('requestId'), isFalse);

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'correlated generic Git errors complete the operation stream',
      () async {
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
        final result = bridge.gitBranchesResults.first;

        socket.add(
          jsonEncode({
            'type': 'error',
            'message': 'Path not allowed',
            'errorCode': 'path_not_allowed',
            'path': '/project-a',
            'requestId': 'git-branches-42',
          }),
        );

        final typed = await result;
        expect(typed.projectPath, '/project-a');
        expect(typed.requestId, 'git-branches-42');
        expect(typed.error, 'Path not allowed');

        bridge.disconnect();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

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

    test('file transfer responses stay out of session streams', () async {
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
      Future<ServerMessage> nextGlobalResponse() => bridge.messages
          .where(
            (message) =>
                message is FileDownloadReadyMessage ||
                message is FileUploadReadyMessage ||
                message is FileUploadCompleteMessage ||
                message is ErrorMessage,
          )
          .first
          .timeout(const Duration(seconds: 2));
      final sessionResponses = <ServerMessage>[];
      final sessionSubscription = bridge
          .messagesForSession('s1')
          .where(
            (message) =>
                message is FileDownloadReadyMessage ||
                message is FileUploadReadyMessage ||
                message is FileUploadCompleteMessage ||
                message is ErrorMessage,
          )
          .listen(sessionResponses.add);

      bridge.send(
        ClientMessage.prepareFileDownload(
          projectPath: '/project',
          filePath: 'report.pdf',
          requestId: 'download-1',
        ),
      );
      final readyResponse = nextGlobalResponse();
      socket.add(
        jsonEncode({
          'type': 'file_download_ready',
          'requestId': 'download-1',
          'filePath': 'report.pdf',
          'fileName': 'report.pdf',
          'mimeType': 'application/pdf',
          'sizeBytes': 10,
          'downloadUrl':
              '/api/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        }),
      );
      expect(await readyResponse, isA<FileDownloadReadyMessage>());

      final errorResponse = nextGlobalResponse();
      socket.add(
        jsonEncode({
          'type': 'error',
          'errorCode': 'file_download_not_found',
          'message': 'File not found.',
          'requestId': 'download-2',
        }),
      );
      expect(
        (await errorResponse as ErrorMessage).errorCode,
        'file_download_not_found',
      );

      bridge.send(
        ClientMessage.prepareFileDownload(
          projectPath: '/project',
          filePath: 'legacy.pdf',
          requestId: 'download-3',
        ),
      );
      final legacyResponse = nextGlobalResponse();
      socket.add(
        jsonEncode({'type': 'error', 'message': 'Invalid message format'}),
      );
      expect(
        (await legacyResponse as ErrorMessage).message,
        'Invalid message format',
      );

      bridge.send(
        ClientMessage.prepareFileUpload(
          projectPath: '/project',
          directoryPath: '',
          fileName: 'upload.txt',
          sizeBytes: 3,
          conflictPolicy: 'rename',
          requestId: 'upload-1',
        ),
      );
      final uploadReadyResponse = nextGlobalResponse();
      socket.add(
        jsonEncode({
          'type': 'file_upload_ready',
          'requestId': 'upload-1',
          'fileName': 'upload.txt',
          'sizeBytes': 3,
          'uploadUrl':
              '/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'uploadToken': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        }),
      );
      expect(await uploadReadyResponse, isA<FileUploadReadyMessage>());

      final uploadCompleteResponse = nextGlobalResponse();
      socket.add(
        jsonEncode({
          'type': 'file_upload_complete',
          'requestId': 'upload-1',
          'filePath': 'upload.txt',
          'fileName': 'upload.txt',
          'sizeBytes': 3,
          'sha256': 'digest',
          'skipped': false,
        }),
      );
      expect(await uploadCompleteResponse, isA<FileUploadCompleteMessage>());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(sessionResponses, isEmpty);
      await sessionSubscription.cancel();

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
            final socket = await io.WebSocketTransformer.upgrade(request);
            socket.add(
              jsonEncode({'type': 'session_list', 'sessions': <Object>[]}),
            );
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

    test(
      'session context replaces stale list metadata before live patches',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();

        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
        });

        final bridge = BridgeService();
        bridge.setDeliveryPendingInput(
          's1',
          const QueuedInputItem(
            itemId: 'pending:local-1',
            text: 'Local pending input',
            createdAt: '2026-08-29T00:00:00.000Z',
          ),
        );
        final streamedContexts = <SessionContextMessage>[];
        final contextSubscription = bridge.messagesForSession('s1').listen((
          message,
        ) {
          if (message is SessionContextMessage) {
            streamedContexts.add(message);
          }
        });
        bridge.connect('ws://127.0.0.1:${server.port}');

        final socket = await socketReady.future;
        socket.add(
          jsonEncode({
            'type': 'session_list',
            'sessions': [
              {
                'id': 's1',
                'provider': 'claude',
                'projectPath': '/stale/project',
                'status': 'running',
                'permissionMode': 'default',
              },
            ],
            'protocolCapabilities': ['session_context_v1'],
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        socket.add(
          jsonEncode({
            'type': 'session_context',
            'sessionId': 's1',
            'context': {
              'id': 's1',
              'provider': 'claude',
              'projectPath': '/current/project',
              'worktreePath': '/current/worktree',
              'gitBranch': 'feature/current',
              'status': 'running',
              'permissionMode': 'plan',
              'planMode': true,
              'sandboxEnabled': true,
            },
          }),
        );
        socket.add(
          jsonEncode({'type': 'status', 'sessionId': 's1', 'status': 'idle'}),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final context = bridge.cachedSessionContext('s1');
        expect(bridge.sessions.single.projectPath, '/current/project');
        expect(context?.projectPath, '/current/project');
        expect(context?.worktreePath, '/current/worktree');
        expect(context?.gitBranch, 'feature/current');
        expect(context?.permissionMode, 'plan');
        expect(context?.status, 'idle');
        expect(context?.queuedInput?.itemId, 'pending:local-1');
        expect(
          streamedContexts.single.context.queuedInput?.itemId,
          'pending:local-1',
        );

        bridge.disconnect();
        await contextSubscription.cancel();
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
          socket.add(
            jsonEncode({'type': 'session_list', 'sessions': <Object>[]}),
          );
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

    test(
      'holds normal messages until Bridge protocol compatibility is known',
      () async {
        _automaticallyAnnounceLegacyProtocol = false;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();
        final sawCapabilities = Completer<void>();
        final sawInput = Completer<void>();
        final received = <Map<String, dynamic>>[];

        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            received.add(json);
            if (json['type'] == 'client_capabilities' &&
                !sawCapabilities.isCompleted) {
              sawCapabilities.complete();
            }
            if (json['type'] == 'input' && !sawInput.isCompleted) {
              sawInput.complete();
            }
          });
        });

        final bridge = BridgeService();
        bridge.send(
          ClientMessage.input(
            'wait for negotiation',
            sessionId: 's1',
            clientMessageId: 'cm-negotiation',
          ),
        );
        bridge.connect('ws://127.0.0.1:${server.port}');

        final socket = await socketReady.future;
        await sawCapabilities.future.timeout(const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          received.where((message) => message['type'] == 'input'),
          isEmpty,
        );

        socket.add(
          jsonEncode({'type': 'session_list', 'sessions': <Object>[]}),
        );
        await sawInput.future.timeout(const Duration(seconds: 1));

        expect(
          received.where((message) => message['type'] == 'input'),
          hasLength(1),
        );

        bridge.disconnect();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test('recent sessions ignores an older correlated response after the latest response', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      final requests = <Map<String, dynamic>>[];
      final twoRequestsReady = Completer<void>();

      server.transform(WebSocketTransformer()).listen((socket) {
        if (!socketReady.isCompleted) socketReady.complete(socket);
        socket.listen((data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] != 'list_recent_sessions') return;
          requests.add(json);
          if (requests.length == 2 && !twoRequestsReady.isCompleted) {
            twoRequestsReady.complete();
          }
        });
      });

      final bridge = BridgeService();
      final updates = <List<RecentSession>>[];
      final subscription = bridge.recentSessionsStream.listen(updates.add);
      bridge.connect('ws://127.0.0.1:${server.port}');
      await bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      final socket = await socketReady.future;

      bridge.switchFilter(searchQuery: 'first');
      bridge.switchFilter(searchQuery: 'second');
      await twoRequestsReady.future.timeout(const Duration(seconds: 1));

      socket.add(
        jsonEncode({
          'type': 'recent_sessions',
          'sessions': [
            {'sessionId': 'fresh', 'projectPath': '/tmp/project'},
          ],
          'hasMore': false,
          'offset': 0,
          'requestScope': 'list',
          'requestId': requests[1]['requestId'],
        }),
      );
      await bridge.recentSessionsStream.first;

      socket.add(
        jsonEncode({
          'type': 'recent_sessions',
          'sessions': [
            {'sessionId': 'stale', 'projectPath': '/tmp/project'},
          ],
          'hasMore': false,
          'offset': 0,
          'requestScope': 'list',
          'requestId': requests[0]['requestId'],
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(requests[0]['requestId'], isNotNull);
      expect(requests[1]['requestId'], isNot(requests[0]['requestId']));
      expect(bridge.recentSessions.single.sessionId, 'fresh');
      expect(updates, hasLength(1));

      bridge.disconnect();
      await subscription.cancel();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test('recent sessions timeout preserves rows and allows the same query to retry', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      final requests = <Map<String, dynamic>>[];
      final firstRequestReady = Completer<void>();
      final timedOutRequestReady = Completer<void>();
      final retryRequestReady = Completer<void>();

      server.transform(WebSocketTransformer()).listen((socket) {
        if (!socketReady.isCompleted) socketReady.complete(socket);
        socket.listen((data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] != 'list_recent_sessions') return;
          requests.add(json);
          switch (requests.length) {
            case 1:
              firstRequestReady.complete();
              socket.add(
                jsonEncode({
                  'type': 'recent_sessions',
                  'sessions': [
                    {'sessionId': 'existing', 'projectPath': '/tmp/project'},
                  ],
                  'hasMore': true,
                  'offset': 0,
                  'requestScope': 'list',
                  'requestId': json['requestId'],
                }),
              );
              break;
            case 2:
              timedOutRequestReady.complete();
              break;
            case 3:
              retryRequestReady.complete();
              socket.add(
                jsonEncode({
                  'type': 'recent_sessions',
                  'sessions': [
                    {'sessionId': 'recovered', 'projectPath': '/tmp/project'},
                  ],
                  'hasMore': false,
                  'offset': 0,
                  'requestScope': 'list',
                  'requestId': json['requestId'],
                }),
              );
              break;
          }
        });
      });

      final bridge = BridgeService(
        recentSessionsRequestTimeout: const Duration(milliseconds: 20),
      );
      final timeoutMessage = bridge.messages
          .where(
            (message) =>
                message is ErrorMessage &&
                message.errorCode == 'recent_sessions_failed',
          )
          .cast<ErrorMessage>()
          .first;
      bridge.connect('ws://127.0.0.1:${server.port}');
      await bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      final socket = await socketReady.future;

      bridge.requestRecentSessions();
      await firstRequestReady.future.timeout(const Duration(seconds: 1));
      await bridge.recentSessionsStream.first;
      expect(bridge.recentSessions.single.sessionId, 'existing');

      bridge.switchFilter(searchQuery: 'slow');
      await timedOutRequestReady.future.timeout(const Duration(seconds: 1));
      final error = await timeoutMessage.timeout(const Duration(seconds: 1));
      expect(error.requestId, requests[1]['requestId']);
      expect(bridge.recentSessions.single.sessionId, 'existing');

      bridge.switchFilter(searchQuery: 'slow');
      await retryRequestReady.future.timeout(const Duration(seconds: 1));
      await bridge.recentSessionsStream.firstWhere(
        (sessions) =>
            sessions.any((session) => session.sessionId == 'recovered'),
      );
      expect(requests[2]['requestId'], isNot(requests[1]['requestId']));
      expect(bridge.recentSessions.single.sessionId, 'recovered');

      bridge.disconnect();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test(
      'recent sessions can retry the same query after socket reconnect',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final sockets = <WebSocket>[];
        final firstSocketReady = Completer<WebSocket>();
        final secondSocketReady = Completer<WebSocket>();
        final firstRequestReady = Completer<Map<String, dynamic>>();
        final secondRequestReady = Completer<Map<String, dynamic>>();

        server.transform(WebSocketTransformer()).listen((socket) {
          sockets.add(socket);
          final socketIndex = sockets.length;
          if (socketIndex == 1) {
            firstSocketReady.complete(socket);
          } else if (socketIndex == 2) {
            secondSocketReady.complete(socket);
          }
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] != 'list_recent_sessions') return;
            if (socketIndex == 1 && !firstRequestReady.isCompleted) {
              firstRequestReady.complete(json);
            } else if (socketIndex == 2 && !secondRequestReady.isCompleted) {
              secondRequestReady.complete(json);
            }
          });
        });

        final bridge = BridgeService(
          recentSessionsRequestTimeout: const Duration(milliseconds: 80),
        );
        final errors = <ErrorMessage>[];
        final errorSub = bridge.messages
            .where((message) => message is ErrorMessage)
            .cast<ErrorMessage>()
            .listen(errors.add);
        final url = 'ws://127.0.0.1:${server.port}';
        final connected = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        bridge.connect(url);
        await connected.timeout(const Duration(seconds: 2));
        final firstSocket = await firstSocketReady.future.timeout(
          const Duration(seconds: 2),
        );

        bridge.switchFilter(searchQuery: 'same-query');
        final firstRequest = await firstRequestReady.future.timeout(
          const Duration(seconds: 1),
        );
        final reconnecting = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.reconnecting,
        );
        // A server-side WebSocket close waits for the peer's close frame on
        // Windows. The reconnect behavior only needs the close to be sent;
        // waiting for the full handshake can deadlock the test runner.
        unawaited(firstSocket.close());
        await reconnecting.timeout(const Duration(seconds: 1));

        final connectedAgain = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        bridge.connect(url);
        await secondSocketReady.future.timeout(const Duration(seconds: 1));
        await connectedAgain.timeout(const Duration(seconds: 2));
        bridge.switchFilter(searchQuery: 'same-query');
        final secondRequest = await secondRequestReady.future.timeout(
          const Duration(milliseconds: 200),
        );
        expect(secondRequest['requestId'], isNot(firstRequest['requestId']));

        final recoveredSessions = bridge.recentSessionsStream.firstWhere(
          (sessions) =>
              sessions.any((session) => session.sessionId == 'recovered'),
        );
        sockets[1].add(
          jsonEncode({
            'type': 'recent_sessions',
            'sessions': [
              {'sessionId': 'recovered', 'projectPath': '/tmp/project'},
            ],
            'hasMore': false,
            'offset': 0,
            'requestScope': 'list',
            'requestId': secondRequest['requestId'],
          }),
        );
        await recoveredSessions.timeout(const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(bridge.recentSessions.single.sessionId, 'recovered');
        expect(
          errors.where((error) => error.errorCode == 'recent_sessions_failed'),
          isEmpty,
        );

        bridge.disconnect();
        await errorSub.cancel();
        for (final socket in sockets) {
          unawaited(socket.close());
        }
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'scoped requests can retry after replacing a same-target socket',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final sockets = <WebSocket>[];
        final firstRequestReady = Completer<Map<String, dynamic>>();
        final secondRequestReady = Completer<Map<String, dynamic>>();
        final firstGalleryRequestReady = Completer<Map<String, dynamic>>();
        final secondGalleryRequestReady = Completer<Map<String, dynamic>>();
        final secondSocketReady = Completer<void>();

        server.transform(WebSocketTransformer()).listen((socket) {
          sockets.add(socket);
          final socketIndex = sockets.length;
          if (socketIndex == 2) secondSocketReady.complete();
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'list_recent_sessions') {
              if (socketIndex == 1 && !firstRequestReady.isCompleted) {
                firstRequestReady.complete(json);
              } else if (socketIndex == 2 && !secondRequestReady.isCompleted) {
                secondRequestReady.complete(json);
              }
            } else if (json['type'] == 'list_gallery') {
              if (socketIndex == 1 && !firstGalleryRequestReady.isCompleted) {
                firstGalleryRequestReady.complete(json);
              } else if (socketIndex == 2 &&
                  !secondGalleryRequestReady.isCompleted) {
                secondGalleryRequestReady.complete(json);
              }
            }
          });
        });

        final bridge = BridgeService(
          recentSessionsRequestTimeout: const Duration(milliseconds: 80),
        );
        final url = 'ws://127.0.0.1:${server.port}';
        final connected = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        bridge.connect(url);
        await connected.timeout(const Duration(seconds: 2));
        bridge.switchFilter(searchQuery: 'same-query');
        final firstRequest = await firstRequestReady.future.timeout(
          const Duration(seconds: 1),
        );
        bridge.requestGallery(sessionId: 'session-a');
        final firstGalleryRequest = await firstGalleryRequestReady.future
            .timeout(const Duration(seconds: 1));

        final connectedAgain = bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        bridge.connect(url);
        await secondSocketReady.future.timeout(const Duration(seconds: 1));
        await connectedAgain.timeout(const Duration(seconds: 2));
        bridge.switchFilter(searchQuery: 'same-query');
        bridge.requestGallery(sessionId: 'session-a');
        final secondRequest = await secondRequestReady.future.timeout(
          const Duration(milliseconds: 200),
        );
        final secondGalleryRequest = await secondGalleryRequestReady.future
            .timeout(const Duration(milliseconds: 200));

        expect(secondRequest['requestId'], isNot(firstRequest['requestId']));
        expect(
          secondGalleryRequest['requestId'],
          isNot(firstGalleryRequest['requestId']),
        );

        bridge.disconnect();
        for (final socket in sockets) {
          unawaited(socket.close());
        }
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test('queued gallery remains correlated through initial connect', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      server.transform(WebSocketTransformer()).listen((socket) {
        socketReady.complete(socket);
        socket.listen((data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] != 'list_gallery') return;
          socket.add(
            jsonEncode({
              'type': 'gallery_list',
              'images': [
                _galleryImageJson('offline-image', sessionId: 'session-a'),
              ],
              'sessionId': 'session-a',
              'requestId': json['requestId'],
            }),
          );
        });
      });

      final bridge = BridgeService(
        galleryRequestTimeout: const Duration(milliseconds: 500),
      );
      final update = bridge.galleryStreamFor(sessionId: 'session-a').first;
      bridge.requestGallery(sessionId: 'session-a');
      bridge.connect('ws://127.0.0.1:${server.port}');

      final images = await update.timeout(const Duration(milliseconds: 300));
      expect(images.single.id, 'offline-image');

      bridge.disconnect();
      final socket = await socketReady.future;
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test(
      'queued gallery survives a failed handshake and automatic reconnect',
      () async {
        final portProbe = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final port = portProbe.port;
        await portProbe.close(force: true);

        final bridge = BridgeService(
          galleryRequestTimeout: const Duration(milliseconds: 100),
        );
        final update = bridge.galleryStreamFor(sessionId: 'session-a').first;
        bridge.requestGallery(sessionId: 'session-a');
        bridge.connect('ws://127.0.0.1:$port');
        await bridge.connectionStatus
            .firstWhere((state) => state == BridgeConnectionState.reconnecting)
            .timeout(const Duration(seconds: 5));

        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        final socketReady = Completer<WebSocket>();
        server.transform(WebSocketTransformer()).listen((socket) {
          socketReady.complete(socket);
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] != 'list_gallery') return;
            socket.add(
              jsonEncode({
                'type': 'gallery_list',
                'images': [
                  _galleryImageJson('reconnected', sessionId: 'session-a'),
                ],
                'sessionId': 'session-a',
                'requestId': json['requestId'],
              }),
            );
          });
        });

        final images = await update.timeout(const Duration(seconds: 8));
        expect(images.single.id, 'reconnected');

        bridge.disconnect();
        final socket = await socketReady.future;
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test('queued gallery survives socket replacement during flush', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      server.transform(WebSocketTransformer()).listen((socket) {
        sockets.add(socket);
        socket.listen((data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] != 'list_gallery') return;
          final sessionId = json['sessionId'] as String?;
          socket.add(
            jsonEncode({
              'type': 'gallery_list',
              'images': [
                _galleryImageJson('image-$sessionId', sessionId: sessionId),
              ],
              'sessionId': sessionId,
              'requestId': json['requestId'],
            }),
          );
        });
      });

      final bridge = BridgeService(
        galleryRequestTimeout: const Duration(seconds: 2),
      );
      final url = 'ws://127.0.0.1:${server.port}';
      var replacedDuringFlush = false;
      bridge.onOutgoingMessage = (message) {
        if (message.type != 'list_gallery' || replacedDuringFlush) return;
        replacedDuringFlush = true;
        bridge.connect(url);
      };
      final sessionAUpdate = bridge
          .galleryStreamFor(sessionId: 'session-a')
          .first;
      final sessionBUpdate = bridge
          .galleryStreamFor(sessionId: 'session-b')
          .first;
      bridge.requestGallery(sessionId: 'session-a');
      bridge.requestGallery(sessionId: 'session-b');
      bridge.connect(url);

      final updates = await Future.wait([sessionAUpdate, sessionBUpdate])
          .timeout(const Duration(seconds: 3));
      expect(replacedDuringFlush, isTrue);
      expect(sockets, hasLength(2));
      expect(updates[0].single.id, 'image-session-a');
      expect(updates[1].single.id, 'image-session-b');

      bridge.disconnect();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
      bridge.dispose();
    });

    test('dispose invalidates an active scoped queue flush', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      server.transform(WebSocketTransformer()).listen((socket) {
        sockets.add(socket);
        socket.listen((_) {});
      });

      final bridge = BridgeService();
      final disposed = Completer<void>();
      bridge.requestGallery(sessionId: 'session-a');
      bridge.requestGallery(sessionId: 'session-b');
      bridge.onOutgoingMessage = (message) {
        if (message.type != 'list_gallery' || disposed.isCompleted) return;
        bridge.dispose();
        disposed.complete();
      };
      bridge.connect('ws://127.0.0.1:${server.port}');

      await disposed.future.timeout(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    });

    test(
      'legacy recent sessions response must match pending project and offset',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();
        final requests = <Map<String, dynamic>>[];
        final threeRequestsReady = Completer<void>();

        server.transform(WebSocketTransformer()).listen((socket) {
          if (!socketReady.isCompleted) socketReady.complete(socket);
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] != 'list_recent_sessions') return;
            requests.add(json);
            if (requests.length == 3 && !threeRequestsReady.isCompleted) {
              threeRequestsReady.complete();
            }
          });
        });

        final bridge = BridgeService();
        final updates = <List<RecentSession>>[];
        final subscription = bridge.recentSessionsStream.listen(updates.add);
        bridge.connect('ws://127.0.0.1:${server.port}');
        await bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        final socket = await socketReady.future;

        bridge.switchProjectFilter('/tmp/old');
        bridge.switchProjectFilter('/tmp/current');
        bridge.loadMoreRecentSessions(projectPath: '/tmp/current', offset: 20);
        await threeRequestsReady.future.timeout(const Duration(seconds: 1));

        void sendLegacyResponse({
          required String sessionId,
          required String projectPath,
          required int offset,
        }) {
          socket.add(
            jsonEncode({
              'type': 'recent_sessions',
              'sessions': [
                {'sessionId': sessionId, 'projectPath': projectPath},
              ],
              'hasMore': false,
              'projectPath': projectPath,
              'offset': offset,
              'requestScope': 'list',
            }),
          );
        }

        sendLegacyResponse(
          sessionId: 'wrong-project',
          projectPath: '/tmp/old',
          offset: 0,
        );
        sendLegacyResponse(
          sessionId: 'wrong-offset',
          projectPath: '/tmp/current',
          offset: 0,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(updates, isEmpty);

        sendLegacyResponse(
          sessionId: 'matching',
          projectPath: '/tmp/current',
          offset: 20,
        );
        await bridge.recentSessionsStream.first;

        expect(bridge.recentSessions.single.sessionId, 'matching');
        expect(updates, hasLength(1));

        bridge.disconnect();
        await subscription.cancel();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'gallery correlates global and session scopes across reversed responses',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();
        final requests = <Map<String, dynamic>>[];
        final requestsReady = Completer<void>();
        server.transform(WebSocketTransformer()).listen((socket) {
          if (!socketReady.isCompleted) socketReady.complete(socket);
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] != 'list_gallery') return;
            requests.add(json);
            if (requests.length == 4 && !requestsReady.isCompleted) {
              requestsReady.complete();
            }
          });
        });

        final bridge = BridgeService();
        final globalUpdates = <List<GalleryImage>>[];
        final sessionAUpdates = <List<GalleryImage>>[];
        final sessionBUpdates = <List<GalleryImage>>[];
        final projectUpdates = <List<GalleryImage>>[];
        final globalSub = bridge.galleryStream.listen(globalUpdates.add);
        final sessionASub = bridge
            .galleryStreamFor(sessionId: 'session-a')
            .listen(sessionAUpdates.add);
        final sessionBSub = bridge
            .galleryStreamFor(sessionId: 'session-b')
            .listen(sessionBUpdates.add);
        final projectSub = bridge
            .galleryStreamFor(projectPath: '/tmp/project-only')
            .listen(projectUpdates.add);
        bridge.connect('ws://127.0.0.1:${server.port}');
        await bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        final socket = await socketReady.future;

        bridge.requestGallery();
        bridge.requestGallery(sessionId: 'session-a');
        bridge.requestGallery(sessionId: 'session-b');
        bridge.requestGallery(projectPath: '/tmp/project-only');
        await requestsReady.future.timeout(const Duration(seconds: 1));

        Map<String, dynamic> requestFor({
          String? sessionId,
          String? projectPath,
        }) => requests.singleWhere(
          (request) =>
              request['sessionId'] == sessionId &&
              request['projectPath'] == projectPath,
        );

        void respond({
          required Map<String, dynamic> request,
          required String imageId,
          String? requestId,
          String? sessionId,
          String? projectPath,
        }) {
          socket.add(
            jsonEncode({
              'type': 'gallery_list',
              'images': [
                _galleryImageJson(
                  imageId,
                  sessionId: sessionId,
                  projectPath: projectPath ?? '/tmp/project',
                ),
              ],
              'requestId': requestId ?? request['requestId'],
              'sessionId': ?sessionId,
              'projectPath': ?projectPath,
            }),
          );
        }

        final globalRequest = requestFor();
        final sessionARequest = requestFor(sessionId: 'session-a');
        final sessionBRequest = requestFor(sessionId: 'session-b');
        final projectRequest = requestFor(projectPath: '/tmp/project-only');

        respond(
          request: sessionBRequest,
          requestId: 'unknown-request',
          sessionId: 'session-b',
          imageId: 'unknown',
        );
        respond(
          request: sessionBRequest,
          sessionId: 'session-a',
          imageId: 'wrong-session',
        );
        respond(
          request: sessionARequest,
          sessionId: 'session-a',
          projectPath: '/wrong-project',
          imageId: 'wrong-project',
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(globalUpdates, isEmpty);
        expect(sessionAUpdates, isEmpty);
        expect(sessionBUpdates, isEmpty);
        expect(projectUpdates, isEmpty);

        respond(
          request: projectRequest,
          projectPath: '/tmp/project-only',
          imageId: 'project-image',
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(globalUpdates, isEmpty);
        expect(sessionAUpdates, isEmpty);
        expect(sessionBUpdates, isEmpty);
        expect(projectUpdates.single.single.id, 'project-image');

        respond(
          request: sessionBRequest,
          sessionId: 'session-b',
          imageId: 'session-b-image',
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(globalUpdates, isEmpty);
        expect(sessionAUpdates, isEmpty);
        expect(sessionBUpdates.single.single.id, 'session-b-image');

        respond(
          request: sessionARequest,
          sessionId: 'session-a',
          imageId: 'session-a-image',
        );
        respond(request: globalRequest, imageId: 'global-image');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(bridge.galleryImages.single.id, 'global-image');
        expect(
          bridge.galleryImagesFor(sessionId: 'session-a').single.id,
          'session-a-image',
        );
        expect(
          bridge.galleryImagesFor(sessionId: 'session-b').single.id,
          'session-b-image',
        );
        expect(
          bridge.galleryImagesFor(projectPath: '/tmp/project-only').single.id,
          'project-image',
        );
        expect(globalUpdates, hasLength(1));
        expect(sessionAUpdates, hasLength(1));
        expect(sessionBUpdates, hasLength(1));
        expect(projectUpdates, hasLength(1));

        bridge.disconnect();
        await globalSub.cancel();
        await sessionASub.cancel();
        await sessionBSub.cancel();
        await projectSub.cancel();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test(
      'gallery legacy responses require one exactly matching pending scope',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();
        final requests = <Map<String, dynamic>>[];
        server.transform(WebSocketTransformer()).listen((socket) {
          if (!socketReady.isCompleted) socketReady.complete(socket);
          socket.listen((data) {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'list_gallery') requests.add(json);
          });
        });

        final bridge = BridgeService();
        final sessionAUpdates = <List<GalleryImage>>[];
        final sessionBUpdates = <List<GalleryImage>>[];
        final sessionASub = bridge
            .galleryStreamFor(sessionId: 'session-a')
            .listen(sessionAUpdates.add);
        final sessionBSub = bridge
            .galleryStreamFor(sessionId: 'session-b')
            .listen(sessionBUpdates.add);
        bridge.connect('ws://127.0.0.1:${server.port}');
        await bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        final socket = await socketReady.future;

        bridge.requestGallery(sessionId: 'session-a');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        socket.add(
          jsonEncode({
            'type': 'gallery_list',
            'images': [_galleryImageJson('legacy-a', sessionId: 'session-a')],
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(sessionAUpdates.single.single.id, 'legacy-a');

        bridge.requestGallery(sessionId: 'session-a');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        socket.add(
          jsonEncode({
            'type': 'gallery_list',
            'images': [
              _galleryImageJson('wrong-session', sessionId: 'session-b'),
            ],
            'sessionId': 'session-b',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(sessionAUpdates, hasLength(1));
        expect(sessionBUpdates, isEmpty);

        bridge.requestGallery(sessionId: 'session-b');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        socket.add(
          jsonEncode({
            'type': 'gallery_list',
            'images': [_galleryImageJson('ambiguous', sessionId: 'session-a')],
            'sessionId': 'session-a',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(sessionAUpdates, hasLength(1));
        expect(sessionBUpdates, isEmpty);

        final latestA = requests.lastWhere(
          (request) => request['sessionId'] == 'session-a',
        );
        final latestB = requests.lastWhere(
          (request) => request['sessionId'] == 'session-b',
        );
        for (final request in [latestA, latestB]) {
          socket.add(
            jsonEncode({
              'type': 'gallery_list',
              'images': [
                _galleryImageJson(
                  'resolved-${request['sessionId']}',
                  sessionId: request['sessionId'] as String,
                ),
              ],
              'requestId': request['requestId'],
              'sessionId': request['sessionId'],
            }),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(sessionAUpdates, hasLength(2));
        expect(sessionBUpdates, hasLength(1));

        bridge.disconnect();
        await sessionASub.cancel();
        await sessionBSub.cancel();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );

    test('gallery timeout preserves cache, retries, and disconnect cancels timeout', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      final requests = <Map<String, dynamic>>[];
      server.transform(WebSocketTransformer()).listen((socket) {
        if (!socketReady.isCompleted) socketReady.complete(socket);
        socket.listen((data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] == 'list_gallery') requests.add(json);
        });
      });

      final bridge = BridgeService(
        galleryRequestTimeout: const Duration(milliseconds: 25),
      );
      final errors = <ErrorMessage>[];
      final errorSub = bridge.messages
          .where((message) => message is ErrorMessage)
          .cast<ErrorMessage>()
          .listen(errors.add);
      bridge.connect('ws://127.0.0.1:${server.port}');
      await bridge.connectionStatus.firstWhere(
        (state) => state == BridgeConnectionState.connected,
      );
      final socket = await socketReady.future;

      bridge.requestGallery(sessionId: 'session-a');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final first = requests.single;
      socket.add(
        jsonEncode({
          'type': 'gallery_list',
          'images': [_galleryImageJson('existing', sessionId: 'session-a')],
          'requestId': first['requestId'],
          'sessionId': 'session-a',
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      bridge.requestGallery(sessionId: 'session-a');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(
        errors.where((error) => error.errorCode == 'gallery_failed'),
        hasLength(1),
      );
      expect(
        bridge.galleryImagesFor(sessionId: 'session-a').single.id,
        'existing',
      );

      bridge.requestGallery(sessionId: 'session-a');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final retry = requests.last;
      expect(retry['requestId'], isNot(first['requestId']));
      socket.add(
        jsonEncode({
          'type': 'gallery_list',
          'images': [_galleryImageJson('retried', sessionId: 'session-a')],
          'requestId': retry['requestId'],
          'sessionId': 'session-a',
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        bridge.galleryImagesFor(sessionId: 'session-a').single.id,
        'retried',
      );

      bridge.requestGallery(sessionId: 'session-b');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      bridge.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(
        errors.where((error) => error.errorCode == 'gallery_failed'),
        hasLength(1),
      );

      await errorSub.cancel();
      await socket.close();
      await server.close(force: true);
      bridge.dispose();
    });

    test(
      'gallery new images update only matching scopes and deduplicate',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final socketReady = Completer<WebSocket>();
        server.transform(WebSocketTransformer()).listen((socket) {
          if (!socketReady.isCompleted) socketReady.complete(socket);
        });

        final bridge = BridgeService();
        final sessionAUpdates = <List<GalleryImage>>[];
        final sessionBUpdates = <List<GalleryImage>>[];
        final projectUpdates = <List<GalleryImage>>[];
        final sessionASub = bridge
            .galleryStreamFor(sessionId: 'session-a')
            .listen(sessionAUpdates.add);
        final sessionBSub = bridge
            .galleryStreamFor(sessionId: 'session-b')
            .listen(sessionBUpdates.add);
        final projectSub = bridge
            .galleryStreamFor(projectPath: '/tmp/project-a')
            .listen(projectUpdates.add);
        bridge.connect('ws://127.0.0.1:${server.port}');
        await bridge.connectionStatus.firstWhere(
          (state) => state == BridgeConnectionState.connected,
        );
        final socket = await socketReady.future;

        final event = {
          'type': 'gallery_new_image',
          'image': _galleryImageJson(
            'new-image',
            sessionId: 'session-a',
            projectPath: '/tmp/project-a',
          ),
        };
        socket.add(jsonEncode(event));
        socket.add(jsonEncode(event));
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(bridge.galleryImages, hasLength(1));
        expect(sessionAUpdates.last, hasLength(1));
        expect(sessionBUpdates, isEmpty);
        expect(projectUpdates.last, hasLength(1));

        bridge.disconnect();
        await sessionASub.cancel();
        await sessionBSub.cancel();
        await projectSub.cancel();
        await socket.close();
        await server.close(force: true);
        bridge.dispose();
      },
    );
  });
}
