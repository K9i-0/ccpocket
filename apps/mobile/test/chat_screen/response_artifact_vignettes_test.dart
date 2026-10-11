import 'dart:convert';

import 'package:ccpocket/features/generated_image_preview/generated_image_preview_screen.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/bubbles/tool_result_bubble.dart';
import 'package:ccpocket/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/chat_test_helpers.dart';

void main() {
  for (final provider in ['claude', 'codex']) {
    for (final liteMode in [false, true]) {
      testWidgets(
        '$provider output attachments are immediately accessible in ${liteMode ? 'performance' : 'standard'} mode',
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
          await tester.pump();

          bridge.emitFileList([
            'reports/Release review.pdf',
          ], projectPath: '/workspace/project');
          await pumpN(tester);

          // Both providers deliver assets as enriched tool_result messages.
          bridge.emitMessage(
            ServerMessage.fromJson({
              'type': 'assistant',
              'message': {
                'id': 'report-prepared',
                'role': 'assistant',
                'model': provider == 'claude'
                    ? 'claude-sonnet-4-20250514'
                    : 'gpt-5.6',
                'content': [
                  {
                    'type': 'text',
                    'text': 'The review is ready: [Release review](</workspace/project/reports/Release review.pdf>).',
                  },
                ],
              },
            }),
          );
          await pumpN(tester);
          final fileCard = find.byKey(
            const ValueKey('response_file_vignette_reports/Release review.pdf'),
          );
          expect(fileCard, findsOneWidget);
          await tester.tap(fileCard);
          await tester.pump();
          final directoryRequest = bridge.sentMessages
              .map(
                (message) =>
                    jsonDecode(message.toJson()) as Map<String, dynamic>,
              )
              .lastWhere((message) => message['type'] == 'list_directory');
          expect(directoryRequest['path'], '/workspace/project/reports');
          bridge.emitMessage(
            ErrorMessage(
              message: 'Path is not a directory',
              errorCode: 'not_a_directory',
              requestId: directoryRequest['requestId'] as String,
            ),
            sessionId: 'file-browser',
          );
          await pumpN(tester);
          expect(
            bridge.sentMessages.any(
              (message) =>
                  jsonDecode(message.toJson())['type'] == 'read_file' &&
                  jsonDecode(message.toJson())['filePath'] ==
                      'reports/Release review.pdf',
            ),
            isTrue,
          );
          Navigator.of(tester.element(fileCard)).pop();
          await pumpN(tester);

          bridge.emitMessage(
            ServerMessage.fromJson({
              'type': 'tool_result',
              'toolUseId': 'capture-review',
              'toolName': provider == 'claude'
                  ? 'mcp__browser__screenshot'
                  : 'mcp:browser/screenshot',
              'content': 'Captured the release review screen.',
              'images': [
                {
                  'id': 'review-screen',
                  'url': '/images/review-screen',
                  'mimeType': 'image/png',
                },
              ],
            }),
          );
          await pumpN(tester);
          final image = find.byKey(
            const ValueKey('generated_image_chat_thumbnail_0'),
          );
          expect(image, findsOneWidget);
          expect(tester.getSize(image), const Size(112, 112));
          await tester.tap(image);
          await pumpN(tester);
          expect(find.byType(GeneratedImagePreviewScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'each generated image stays at its source while the turn continues',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(650, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bridge = MockBridgeService();
      addTearDown(bridge.dispose);
      await tester.pumpWidget(
        await buildTestCodexSessionScreen(bridge: bridge),
      );
      await pumpN(tester);
      for (final id in ['first-capture', 'second-capture']) {
        bridge.emitMessage(
          ServerMessage.fromJson({
            'type': 'tool_result',
            'toolUseId': id,
            'toolName': 'ImageGeneration',
            'content': 'status: completed',
            'images': [
              {'id': id, 'url': '/images/$id', 'mimeType': 'image/png'},
            ],
          }),
        );
        await pumpN(tester);
        final source = find.byWidgetPredicate(
          (widget) =>
              widget is ChatEntryWidget &&
              widget.entry is ServerChatEntry &&
              (widget.entry as ServerChatEntry).message is ToolResultMessage &&
              ((widget.entry as ServerChatEntry).message as ToolResultMessage)
                      .toolUseId ==
                  id,
        );
        expect(
          find.descendant(
            of: source,
            matching: find.byKey(
              const ValueKey('generated_image_chat_thumbnail_0'),
            ),
          ),
          findsOneWidget,
        );
        bridge.emitMessage(
          makeAssistantMessage(
            'after-$id',
            'The capture is ready. I am continuing the review.',
          ),
        );
        await pumpN(tester);
      }
      expect(
        find.byKey(const ValueKey('generated_image_chat_thumbnail_0')),
        findsNWidgets(2),
      );
    },
  );

  testWidgets(
    'a streamed workspace link becomes available before the response completes',
    (tester) async {
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
        'reports/review.md',
      ], projectPath: '/workspace/project');
      await pumpN(tester);
      bridge.emitMessage(
        const StreamDeltaMessage(text: 'Read the [release review]('),
      );
      await pumpN(tester);
      expect(
        find.byKey(const ValueKey('response_file_vignette_reports/review.md')),
        findsNothing,
      );
      bridge.emitMessage(
        const StreamDeltaMessage(text: './reports/review.md).'),
      );
      await pumpN(tester);
      expect(
        find.byKey(const ValueKey('response_file_vignette_reports/review.md')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a collapsed tool still shows workspace output documents', (
    tester,
  ) async {
    final bridge = MockBridgeService();
    addTearDown(bridge.dispose);
    await tester.pumpWidget(
      await buildTestClaudeSessionScreen(
        bridge: bridge,
        projectPath: '/workspace/project',
      ),
    );
    await pumpN(tester);
    bridge.emitFileList([
      'reports/summary.docx',
    ], projectPath: '/workspace/project');
    await pumpN(tester);
    bridge.emitMessage(
      ServerMessage.fromJson({
        'type': 'tool_result',
        'toolUseId': 'write-report',
        'toolName': 'Bash',
        'content': 'Export complete. [Summary](./reports/summary.docx)',
      }),
    );
    await pumpN(tester);
    bridge.emitMessage(
      makeAssistantMessage('export-ready', 'The summary is ready to read.'),
    );
    await pumpN(tester);
    expect(find.byType(ToolResultBubble), findsOneWidget);
    expect(
      find.text('Export complete. [Summary](./reports/summary.docx)'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('response_file_vignette_reports/summary.docx')),
      findsOneWidget,
    );
  });
}
