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
}
