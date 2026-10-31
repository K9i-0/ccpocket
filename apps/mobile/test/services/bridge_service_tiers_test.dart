import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final supportsExtended in [false, true]) {
    test(
      'extended speed dispatch follows Bridge capability $supportsExtended',
      () async {
        SharedPreferences.setMockInitialValues({});
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final sockets = <WebSocket>[];
        final received = <Map<String, dynamic>>[];
        final dispatched = Completer<void>();
        server.transform(WebSocketTransformer()).listen((socket) {
          sockets.add(socket);
          socket.listen((raw) {
            final message = jsonDecode(raw as String) as Map<String, dynamic>;
            received.add(message);
            if (message['type'] == 'resume_session' &&
                !dispatched.isCompleted) {
              dispatched.complete();
            }
          });
          socket.add(
            jsonEncode({
              'type': 'session_list',
              'sessions': <dynamic>[],
              'protocolCapabilities': supportsExtended
                  ? ['codex_service_tiers_v1']
                  : <String>[],
              'codexModelServiceTiers': {
                'gpt-6-astra': ['fast', 'ultrafast'],
              },
              'codexModelServiceTierMetadata': {
                'gpt-6-astra': [
                  {'id': 'ultrafast', 'name': 'Ultrafast'},
                ],
              },
            }),
          );
        });
        final bridge = BridgeService();
        try {
          final connected = bridge.sessionList.first;
          bridge.connect('ws://127.0.0.1:${server.port}');
          await connected.timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('initial session_list'),
          );
          final errors = <ErrorMessage>[];
          final failures = <SystemMessage>[];
          final rejected = Completer<void>();
          final subscription = bridge.messages.listen((message) {
            if (message is SystemMessage &&
                message.subtype == 'session_resume_failed') {
              failures.add(message);
            }
            if (message is ErrorMessage) {
              errors.add(message);
              if (!rejected.isCompleted) rejected.complete();
            }
          });
          try {
            bridge.send(
              ClientMessage.resumeSession(
                'old-thread',
                '/project',
                provider: 'codex',
                model: 'gpt-6-astra',
                serviceTier: 'ultrafast',
                resumeRequestId: 'request-1',
              ),
            );
            if (supportsExtended) {
              await dispatched.future.timeout(
                const Duration(seconds: 5),
                onTimeout: () => throw TimeoutException('resume dispatch'),
              );
              expect(
                received.singleWhere(
                  (message) => message['type'] == 'resume_session',
                )['serviceTier'],
                'ultrafast',
              );
              expect(errors, isEmpty);
              final refreshed = bridge.sessionList.first;
              sockets.single.add(
                jsonEncode({'type': 'session_list', 'sessions': <dynamic>[]}),
              );
              await refreshed.timeout(const Duration(seconds: 5));
              expect(bridge.supportsCodexServiceTiers, isFalse);
              expect(bridge.codexModelServiceTierMetadata, isEmpty);
            } else {
              await rejected.future.timeout(
                const Duration(seconds: 5),
                onTimeout: () => throw TimeoutException('local rejection'),
              );
              expect(
                received.where(
                  (message) => message['type'] == 'resume_session',
                ),
                isEmpty,
              );
              expect(errors.single.errorCode, 'codex_service_tier_unavailable');
              expect(failures.single.sourceSessionId, 'old-thread');
              expect(failures.single.resumeRequestId, 'request-1');
            }
          } finally {
            await subscription.cancel();
          }
        } finally {
          bridge.dispose();
          for (final socket in sockets) {
            await socket.close();
          }
          await server.close(force: true);
        }
      },
    );
  }

  for (final action in ['start', 'resume_session']) {
    for (final scenario in [
      (
        name: 'unresolved profile model',
        model: null,
        supportsExtended: true,
        allowed: true,
      ),
      (
        name: 'unresolved profile model on an old Bridge',
        model: null,
        supportsExtended: false,
        allowed: false,
      ),
      (
        name: 'resolved model without the selected tier',
        model: 'gpt-6-luna',
        supportsExtended: true,
        allowed: false,
      ),
    ]) {
      test('$action with ${scenario.name}', () async {
        SharedPreferences.setMockInitialValues({});
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final sockets = <WebSocket>[];
        final received = <Map<String, dynamic>>[];
        final dispatched = Completer<Map<String, dynamic>>();
        server.transform(WebSocketTransformer()).listen((socket) {
          sockets.add(socket);
          socket.listen((raw) {
            final message = jsonDecode(raw as String) as Map<String, dynamic>;
            received.add(message);
            if (message['type'] == action && !dispatched.isCompleted) {
              dispatched.complete(message);
            }
          });
          socket.add(
            jsonEncode({
              'type': 'session_list',
              // A profile may resolve differently from this cached model.
              'sessions': [
                {
                  'id': 'profile-thread',
                  'provider': 'codex',
                  'projectPath': '/project',
                  'status': 'idle',
                  'createdAt': '2026-10-31T00:00:00Z',
                  'lastActivityAt': '2026-10-31T00:00:00Z',
                  'codexModel': 'gpt-6-luna',
                },
              ],
              'protocolCapabilities': [
                if (scenario.supportsExtended) 'codex_service_tiers_v1',
              ],
              'codexModelServiceTierMetadata': {
                'gpt-6-astra': [
                  {'id': 'ultrafast', 'name': 'Ultrafast'},
                ],
                'gpt-6-luna': <dynamic>[],
              },
            }),
          );
        });
        final bridge = BridgeService();
        final errors = <ErrorMessage>[];
        final rejected = Completer<ErrorMessage>();
        final subscription = bridge.messages.listen((message) {
          if (message is ErrorMessage) {
            errors.add(message);
            if (!rejected.isCompleted) rejected.complete(message);
          }
        });
        try {
          final connected = bridge.sessionList.first;
          bridge.connect('ws://127.0.0.1:${server.port}');
          await connected.timeout(const Duration(seconds: 5));
          bridge.send(
            action == 'start'
                ? ClientMessage.start(
                    '/project',
                    sessionId: 'profile-thread',
                    provider: 'codex',
                    profile: 'latency',
                    model: scenario.model,
                    serviceTier: 'ultrafast',
                  )
                : ClientMessage.resumeSession(
                    'profile-thread',
                    '/project',
                    provider: 'codex',
                    profile: 'latency',
                    model: scenario.model,
                    serviceTier: 'ultrafast',
                    resumeRequestId: 'profile-request',
                  ),
          );
          if (scenario.allowed) {
            final request = await dispatched.future.timeout(
              const Duration(seconds: 5),
            );
            expect(request['profile'], 'latency');
            expect(request.containsKey('model'), isFalse);
            expect(request['serviceTier'], 'ultrafast');
            expect(errors, isEmpty);
            bridge.send(
              ClientMessage.setCodexSpeed(
                'ultrafast',
                sessionId: 'unknown-thread',
              ),
            );
            final error = await rejected.future.timeout(
              const Duration(seconds: 5),
            );
            expect(error.errorCode, 'codex_service_tier_unavailable');
            expect(
              received.where((message) => message['type'] == 'set_codex_speed'),
              isEmpty,
            );
          } else {
            final error = await rejected.future.timeout(
              const Duration(seconds: 5),
            );
            expect(error.errorCode, 'codex_service_tier_unavailable');
            expect(
              received.where((message) => message['type'] == action),
              isEmpty,
            );
          }
        } finally {
          await subscription.cancel();
          bridge.dispose();
          for (final socket in sockets) {
            await socket.close();
          }
          await server.close(force: true);
        }
      });
    }
  }
}
