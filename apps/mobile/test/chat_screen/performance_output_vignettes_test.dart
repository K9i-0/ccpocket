import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/features/response_artifacts/workspace_output_links.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/services/session_runtime_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/chat_test_helpers.dart';

const projectedToolResult = {
  'type': 'tool_result',
  'toolUseId': 'review',
  'content': '',
  'images': [
    {
      'id': 'review-screen',
      'url': '/images/review-screen',
      'mimeType': 'image/png',
    },
  ],
  'outputLinkCandidates': [
    {
      'href': '/workspace/project/reports/review.pdf',
      'label': 'Release review',
      'syntax': 'markdown',
    },
    {
      'href': 'reports/summary.md',
      'label': 'reports/summary.md',
      'syntax': 'inline',
    },
    {'href': 'unrelated.md', 'label': 'unrelated.md', 'syntax': 'bare'},
  ],
};

void main() {
  for (final envelope in ['history_snapshot', 'history_delta']) {
    test('$envelope metadata survives the Bridge runtime history cache', () {
      final store = SessionRuntimeStore();
      store.applyServerMessage(
        testSessionId,
        ServerMessage.fromJson({
          'type': envelope,
          'fromSeq': 1,
          'toSeq': 1,
          'filtered': true,
          'messages': [
            {'seq': 1, 'message': projectedToolResult},
          ],
        }),
      );
      final restored =
          store.messages(testSessionId).single as ToolResultMessage;
      expect(restored.images.single.url, '/images/review-screen');
      expect(
        workspaceOutputLinksForMessage(
          restored,
          knownPathSuffixes: const {'reports/review.pdf'},
          projectPath: '/workspace/project',
        ).map((link) => link.path),
        ['reports/review.pdf'],
      );
    });
  }
  for (final provider in ['claude', 'codex']) {
    for (final envelope in ['live', 'history', 'past_history']) {
      testWidgets(
        '$provider renders projected output attachments from $envelope',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(650, 1100));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final bridge = _ArtifactBridge();
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
          final settings = tester
              .element(find.byKey(const ValueKey('message_input')))
              .read<SettingsCubit>();
          settings.setSessionLiteMode(testSessionId, true);
          tester
              .element(find.byKey(const ValueKey('message_input')))
              .read<FileListCubit>();
          bridge.emitMessage(
            const FileListMessage(
              projectPath: '/workspace/project',
              files: ['reports/review.pdf'],
            ),
          );
          await pumpN(tester);
          final wireMessage = switch (envelope) {
            'live' => projectedToolResult,
            'history' => {
              'type': 'history',
              'messages': [projectedToolResult],
            },
            'past_history' => {
              'type': 'past_history',
              'claudeSessionId': 'saved-review',
              'messages': [
                {...projectedToolResult, 'type': null, 'role': 'tool_result'},
              ],
            },
            _ => {
              'type': envelope,
              'fromSeq': 1,
              'toSeq': 1,
              'filtered': true,
              'messages': [
                {'seq': 1, 'message': projectedToolResult},
              ],
            },
          };
          bridge.emitMessage(ServerMessage.fromJson(wireMessage));
          await pumpN(tester);
          expect(
            find.byKey(const ValueKey('generated_image_chat_thumbnail_0')),
            findsOneWidget,
          );
          expect(
            find.byKey(
              const ValueKey('response_file_vignette_reports/review.pdf'),
            ),
            findsOneWidget,
          );
          expect(find.text('Release review'), findsOneWidget);
          final relative = find.byKey(
            const ValueKey('response_file_vignette_reports/summary.md'),
          );
          expect(relative, findsNothing);
          expect(
            find.byKey(const ValueKey('response_file_vignette_unrelated.md')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final liteMode in [false, true]) {
    testWidgets(
      'a labeled absolute output link keeps its full button in ${liteMode ? 'performance' : 'standard'} mode',
      (tester) async {
        final bridge = _ArtifactBridge();
        addTearDown(bridge.dispose);
        await tester.pumpWidget(
          await buildTestClaudeSessionScreen(
            bridge: bridge,
            projectPath: '/workspace/project',
          ),
        );
        await pumpN(tester);
        bridge.emitFileList([
          'reports/review.pdf',
        ], projectPath: '/workspace/project');
        await pumpN(tester);
        tester
            .element(find.byKey(const ValueKey('message_input')))
            .read<SettingsCubit>()
            .setSessionLiteMode(testSessionId, liteMode);
        bridge.emitMessage(
          ServerMessage.fromJson({
            'type': 'tool_result',
            'toolUseId': 'report',
            'content': liteMode
                ? ''
                : '[Review](/workspace/project/reports/review.pdf)',
            if (liteMode)
              'outputLinkCandidates': [
                {
                  'href': '/workspace/project/reports/review.pdf',
                  'label': 'Review',
                  'syntax': 'markdown',
                },
              ],
          }),
        );
        await pumpN(tester);
        final card = find.byKey(
          const ValueKey('response_file_vignette_reports/review.pdf'),
        );
        expect(card, findsOneWidget);
        expect(find.text('Review'), findsOneWidget);
        await tester.tap(card);
        await pumpN(tester);
        expect(
          bridge.sentMessages
              .map((message) => jsonDecode(message.toJson()))
              .any(
                (message) =>
                    message['type'] == 'read_file' &&
                    message['filePath'] == 'reports/review.pdf',
              ),
          isTrue,
        );
      },
    );
  }

  testWidgets(
    'unknown metadata does not leave a blank row in performance mode',
    (tester) async {
      final bridge = _ArtifactBridge();
      addTearDown(bridge.dispose);
      await tester.pumpWidget(
        await buildTestClaudeSessionScreen(bridge: bridge),
      );
      await pumpN(tester);
      tester
          .element(find.byKey(const ValueKey('message_input')))
          .read<SettingsCubit>()
          .setSessionLiteMode(testSessionId, true);
      bridge.emitMessage(
        ServerMessage.fromJson({
          'type': 'tool_result',
          'toolUseId': 'log',
          'content': '',
          'outputLinkCandidates': [
            {'href': 'unrelated.md', 'label': 'unrelated.md', 'syntax': 'bare'},
          ],
        }),
      );
      await pumpN(tester);
      expect(find.byKey(const ValueKey('tool_result:log:0')), findsNothing);
    },
  );
}

class _ArtifactBridge extends MockBridgeService {
  @override
  Stream<FileListMessage> fileListMessagesForProject(String projectPath) =>
      messages
          .where(
            (message) =>
                message is FileListMessage &&
                message.projectPath == projectPath,
          )
          .cast<FileListMessage>();
}
