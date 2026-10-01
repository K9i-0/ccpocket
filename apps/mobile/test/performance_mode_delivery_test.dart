import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> until(bool Function() condition) async {
  final caller = StackTrace.current;
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for delivery: $caller');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'waits for the latest mode ACK before replacing cached and past history',
    () async {
      SharedPreferences.setMockInitialValues({});
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Map<String, dynamic>>[];
      late WebSocket socket;
      server.transform(WebSocketTransformer()).listen((connected) {
        socket = connected;
        connected.listen(
          (data) =>
              requests.add(jsonDecode(data as String) as Map<String, dynamic>),
        );
        connected.add(
          jsonEncode({
            'type': 'session_list',
            'sessions': [],
            'protocolCapabilities': ['performance_mode_v1'],
          }),
        );
      });
      final bridge = BridgeService();
      final streaming = StreamingStateCubit();
      ChatSessionCubit? chat;
      void send(Map<String, dynamic> msg) =>
          socket.add(jsonEncode({'sessionId': 's1', ...msg}));
      final toolMessage = {
        'type': 'assistant',
        'message': {
          'id': 'a1',
          'role': 'assistant',
          'model': 'test',
          'content': [
            {
              'type': 'tool_use',
              'id': 't1',
              'name': 'Read',
              'input': {'file_path': '/large'},
            },
          ],
        },
      };
      try {
        bridge.connect('ws://127.0.0.1:${server.port}');
        await until(
          () => requests.any((r) => r['type'] == 'client_capabilities'),
        );
        expect(requests.first['type'], 'client_capabilities');
        final initial = requests.lastWhere(
          (r) => r['type'] == 'client_capabilities',
        );
        send({
          'type': 'performance_mode_state',
          'deliveryRevision': initial['deliveryRevision'],
        });
        chat = ChatSessionCubit(
          bridge: bridge,
          sessionId: 's1',
          streamingCubit: streaming,
        );
        send({
          'type': 'history',
          'messages': [toolMessage],
        });
        await until(() => chat!.state.entries.isNotEmpty);
        requests.clear();
        bridge.configurePerformanceMode(true, {});
        await until(
          () => requests.any((r) => r['type'] == 'client_capabilities'),
        );
        final revision = requests.last['deliveryRevision'];
        expect(chat.state.entries, isNotEmpty);
        expect(requests.where((r) => r['type'] == 'get_history'), isEmpty);
        // An old frame already on the wire must be cleared at the ACK boundary.
        send({
          'type': 'past_history',
          'claudeSessionId': 'claude-1',
          'messages': [
            {
              'role': 'assistant',
              'content': [
                {'type': 'text', 'text': 'old past'},
              ],
            },
          ],
        });
        send({'type': 'performance_mode_state', 'deliveryRevision': revision});
        send({
          'type': 'past_history',
          'claudeSessionId': 'claude-1',
          'messages': [
            {
              'role': 'assistant',
              'content': [
                {'type': 'text', 'text': 'new past'},
              ],
            },
          ],
        });
        await until(
          () => chat!.state.entries.any(
            (entry) =>
                entry is ServerChatEntry &&
                entry.message is AssistantServerMessage &&
                (entry.message as AssistantServerMessage).message.content
                    .whereType<TextContent>()
                    .any((part) => part.text == 'new past'),
          ),
        );
        expect(chat.state.entries, hasLength(1));
        final past =
            (chat.state.entries.single as ServerChatEntry).message
                as AssistantServerMessage;
        expect((past.message.content.single as TextContent).text, 'new past');
        await until(() => requests.any((r) => r['type'] == 'get_history'));
        send({'type': 'session_activity'});
        await until(() => chat!.lastAgentActivityAt != null);
        expect(chat.state.entries, hasLength(1));
        expect(bridge.cachedSessionMessages('s1'), isEmpty);
        // Rapid toggles: an outdated ACK cannot invalidate the current transcript.
        requests.clear();
        bridge.configurePerformanceMode(false, {});
        bridge.configurePerformanceMode(true, {});
        await until(
          () =>
              requests
                  .where((r) => r['type'] == 'client_capabilities')
                  .length ==
              2,
        );
        final caps = requests
            .where((r) => r['type'] == 'client_capabilities')
            .toList();
        send({
          'type': 'performance_mode_state',
          'deliveryRevision': caps.first['deliveryRevision'],
        });
        send({
          'type': 'performance_mode_state',
          'deliveryRevision': caps.last['deliveryRevision'],
        });
        await until(() => requests.any((r) => r['type'] == 'get_history'));
        requests.removeWhere((r) => r['type'] == 'get_history');
        bridge.configurePerformanceMode(false, {});
        await until(
          () =>
              requests
                  .where((r) => r['type'] == 'client_capabilities')
                  .length ==
              3,
        );
        send({
          'type': 'performance_mode_state',
          'deliveryRevision': requests.last['deliveryRevision'],
        });
        await until(() => requests.any((r) => r['type'] == 'get_history'));
        send({
          'type': 'history',
          'messages': [toolMessage],
        });
        await until(() => chat!.state.entries.isNotEmpty);
        final restored = chat.state.entries.single as ServerChatEntry;
        expect(
          (restored.message as AssistantServerMessage).message.content.single,
          isA<ToolUseContent>(),
        );
      } finally {
        await chat?.close();
        await streaming.close();
        bridge.dispose();
        await socket.close();
        await server.close(force: true);
      }
    },
  );
}
