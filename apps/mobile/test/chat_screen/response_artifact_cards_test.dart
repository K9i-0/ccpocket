import 'dart:convert';

import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/bubbles/tool_result_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/chat_test_helpers.dart';

void main() {
  for (final provider in ['claude', 'codex']) {
    for (final liteMode in [false, true]) {
      testWidgets(
        '$provider renders MCP resource cards in ${liteMode ? 'performance' : 'standard'} mode',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(650, 1100));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final bridge = MockBridgeService();
          addTearDown(bridge.dispose);
          final screen = provider == 'claude'
              ? await buildTestClaudeSessionScreen(
                  bridge: bridge,
                  projectPath: '/workspace/project',
                )
              : await buildTestCodexSessionScreen(
                  bridge: bridge,
                  projectPath: '/workspace/project',
                );
          await tester.pumpWidget(screen);
          await pumpN(tester);
          final settings = BlocProvider.of<SettingsCubit>(
            tester.element(find.byKey(const ValueKey('message_input'))),
          );
          settings.setSessionLiteMode(testSessionId, liteMode);
          bridge.emitFileList([
            'reports/Release review.pdf',
          ], projectPath: '/workspace/project');
          await pumpN(tester);

          bridge.emitMessage(
            ServerMessage.fromJson({
              'type': 'tool_result',
              'toolUseId': 'report-export',
              'toolName': provider == 'claude'
                  ? 'mcp__reports__export'
                  : 'mcp:reports/export',
              'content': '',
              'mcpResourceLinks': [
                {
                  'uri':
                      'file:///workspace/project/reports/Release%20review.pdf',
                  'name': 'Release review',
                  'mimeType': 'application/pdf',
                },
              ],
            }),
          );
          await pumpN(tester);

          final card = find.byKey(
            const ValueKey('response_file_card_reports/Release review.pdf'),
          );
          expect(card, findsOneWidget);
          await tester.tap(card);
          await pumpN(tester);
          expect(
            bridge.sentMessages
                .map((message) => jsonDecode(message.toJson()))
                .any(
                  (message) =>
                      message['type'] == 'read_file' &&
                      message['filePath'] == 'reports/Release review.pdf',
                ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('ordinary tool text and assistant links do not create cards', (
    tester,
  ) async {
    final bridge = MockBridgeService();
    addTearDown(bridge.dispose);
    await tester.pumpWidget(
      await buildTestCodexSessionScreen(
        bridge: bridge,
        projectPath: '/workspace/project',
      ),
    );
    await pumpN(tester);
    bridge.emitFileList([
      'reports/review.pdf',
    ], projectPath: '/workspace/project');
    await pumpN(tester);

    bridge.emitMessage(
      ServerMessage.fromJson({
        'type': 'tool_result',
        'toolUseId': 'command',
        'toolName': 'Bash',
        'content': '[Review](./reports/review.pdf)',
      }),
    );
    bridge.emitMessage(
      makeAssistantMessage(
        'answer',
        'The output is [here](./reports/review.pdf).',
      ),
    );
    await pumpN(tester);

    expect(
      find.byKey(const ValueKey('response_file_card_reports/review.pdf')),
      findsNothing,
    );
  });

  testWidgets('an image generation result keeps its existing inline preview', (
    tester,
  ) async {
    final bridge = MockBridgeService();
    addTearDown(bridge.dispose);
    await tester.pumpWidget(await buildTestCodexSessionScreen(bridge: bridge));
    await pumpN(tester);
    bridge.emitMessage(
      ServerMessage.fromJson({
        'type': 'tool_result',
        'toolUseId': 'generated-image',
        'toolName': 'ImageGeneration',
        'content': 'status: completed',
        'images': [
          {
            'id': 'generated-image',
            'url': '/images/generated-image',
            'mimeType': 'image/png',
          },
        ],
      }),
    );
    await pumpN(tester);

    expect(
      find.byKey(const ValueKey('generated_image_chat_thumbnail_0')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('response_artifact_cards')), findsNothing);
    expect(find.byType(ToolResultBubble), findsOneWidget);
  });
}
