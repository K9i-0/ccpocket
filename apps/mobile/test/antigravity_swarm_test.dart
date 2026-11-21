import 'package:ccpocket/features/chat_session/lite_mode_projection.dart';
import 'package:ccpocket/features/chat_session/widgets/background_tasks_bar.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/utils/tool_categories.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';
import 'package:ccpocket/widgets/bubbles/swarm_post_card.dart';
import 'package:ccpocket/widgets/message_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// A board post as the Bridge sends it: a tool call named `SwarmPost` and a
/// result that repeats the text for clients that show it as a plain tool.
const _post = {
  'seq': 2,
  'agent': 'writer_a',
  'text': '@coordinator [done] wrote `a.txt`\n\n## Details\n- Line 1\n- Line 2',
  'time': '2026-11-21 20:51:41',
};

ServerChatEntry _postEntry() => ServerChatEntry(
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'swarm-post:s:2',
      role: 'assistant',
      content: const [
        ToolUseContent(id: 'swarm-post:s:2', name: 'SwarmPost', input: _post),
      ],
      model: 'antigravity',
    ),
  ),
);

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets(
    'a board post starts compact, expands inline on tap, and opens detail sheet',
    (tester) async {
      await pump(
        tester,
        const ToolUseTile(
          toolUseId: 'swarm-post:s:2',
          name: 'SwarmPost',
          input: _post,
        ),
      );

      expect(find.byType(SwarmPostCard), findsOneWidget);
      expect(find.text('writer_a'), findsOneWidget);
      expect(find.text('→ @coordinator'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('20:51'), findsOneWidget);
      expect(find.textContaining('[done] wrote a.txt'), findsOneWidget);
      // Full body details are hidden while collapsed.
      expect(find.textContaining('Line 2'), findsNothing);
      expect(
        find.byKey(const ValueKey('swarm_post_sheet_button_2')),
        findsNothing,
      );
      // Not the generic tool row, which would show the tool's name.
      expect(find.text('SwarmPost'), findsNothing);

      // Tap to expand inline.
      await tester.tap(find.byKey(const ValueKey('swarm_post_toggle_2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Line 2', findRichText: true), findsOneWidget);
      expect(
        find.byKey(const ValueKey('swarm_post_sheet_button_2')),
        findsOneWidget,
      );

      // Open the full-screen detail sheet.
      await tester.tap(find.byKey(const ValueKey('swarm_post_sheet_button_2')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('swarm_post_detail_sheet')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('swarm_post_detail_sheet')),
          matching: find.textContaining('Line 2', findRichText: true),
        ),
        findsOneWidget,
      );

      // Close sheet and collapse back to compact.
      Navigator.of(
        tester.element(find.byKey(const ValueKey('swarm_post_detail_sheet'))),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('swarm_post_toggle_2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Line 2'), findsNothing);
    },
  );

  testWidgets(
    'background tasks bar renders a compact Swarm summary and sheet',
    (tester) async {
      await pump(
        tester,
        const BackgroundTasksBar(
          tasks: [
            BackgroundTaskInfo(
              taskId: 'swarm:waterfall-pond',
              taskType: 'antigravity_agent',
              subagentType: 'swarm',
              description: 'Swarm: waterfall-pond',
              summary: 'File pond.dart',
            ),
            BackgroundTaskInfo(
              taskId: 'swarm:ocean-river',
              taskType: 'antigravity_agent',
              subagentType: 'swarm',
              description: 'Swarm: ocean-river',
              summary: 'Waiting',
            ),
          ],
        ),
      );

      expect(find.text('Swarm (2)'), findsOneWidget);
      expect(
        find.textContaining('waterfall-pond — File pond.dart'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('background_tasks_bar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const ValueKey('background_tasks_sheet')),
        findsOneWidget,
      );
      expect(find.text('waterfall-pond'), findsOneWidget);
      expect(find.text('ocean-river'), findsOneWidget);
      expect(find.text('Waiting'), findsOneWidget);
    },
  );

  test('the result of a board post is not shown a second time', () {
    expect(
      ServerMessageWidget.isVisible(
        const ToolResultMessage(
          toolUseId: 'swarm-post:s:2',
          content: '@coordinator [done] wrote `a.txt`',
          toolName: 'SwarmPost',
        ),
        hiddenToolUseIds: const {},
      ),
      isFalse,
    );
    expect(
      ServerMessageWidget.isVisible(
        const ToolResultMessage(
          toolUseId: 'call_1',
          content: 'Done',
          toolName: 'swarm',
        ),
        hiddenToolUseIds: const {},
      ),
      isTrue,
    );
  });

  test('lite mode keeps board posts, which are conversation, not tools', () {
    final entries = liteModeEntries([
      _postEntry(),
      ServerChatEntry(
        const ToolResultMessage(
          toolUseId: 'swarm-post:s:2',
          content: 'x',
          toolName: 'SwarmPost',
        ),
      ),
    ]);
    expect(entries, hasLength(1));
    expect(
      (entries.single as ServerChatEntry).message,
      isA<AssistantServerMessage>(),
    );
  });

  test('an approval says which swarm worker is asking', () {
    const command = PermissionRequestMessage(
      toolUseId: 'worker_call_1',
      toolName: 'Bash',
      input: {'command': 'echo a > a.txt', 'swarmWorker': 'writer_a'},
    );
    expect(command.presentation.secondaryDetails, ['Swarm worker: writer_a']);
    expect(command.presentation.primaryTarget, 'echo a > a.txt');

    const edit = PermissionRequestMessage(
      toolUseId: 'worker_call_2',
      toolName: 'FileChange',
      input: {'changes': <Object>[], 'swarmWorker': 'writer_b'},
    );
    expect(edit.presentation.secondaryDetails, ['Swarm worker: writer_b']);

    const own = PermissionRequestMessage(
      toolUseId: 'call_3',
      toolName: 'Bash',
      input: {'command': 'ls'},
    );
    expect(own.presentation.secondaryDetails, isEmpty);
  });

  test('tool rows name the worker and summarise swarm actions', () {
    expect(
      getToolSummary(ToolCategory.bash, const {
        'command': 'echo a > a.txt',
        'swarmWorker': 'writer_a',
      }),
      '[writer_a] echo a > a.txt',
    );
    expect(
      getToolSummary(ToolCategory.other, const {
        'action': 'add',
        'name': 'writer_a',
        'brief': 'Write a.txt',
      }),
      'add writer_a',
    );
    expect(
      getToolSummary(ToolCategory.other, const {'action': 'status'}),
      'status',
    );
    // Unrelated tools are summarised as before.
    expect(
      getToolSummary(ToolCategory.other, const {'description': 'Explore'}),
      'Explore',
    );
  });
}
