import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/bubbles/tool_use_summary_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'helpers/chat_test_helpers.dart';

void main() {
  late MockBridgeService bridge;

  setUp(() {
    bridge = MockBridgeService();
  });

  tearDown(() {
    bridge.dispose();
  });

  group('Subagent summary advanced', () {
    patrolWidgetTest(
      'M1: Two consecutive summaries hide their respective tool results',
      ($) async {
        await $.pumpWidget(buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await emitAndPump($.tester, bridge, [
          const StatusMessage(status: ProcessStatus.running),
          makeAssistantMessage('a1', 'Processing phase 1.'),
          makeToolResult('sub-1', 'File content 1'),
          makeToolResult('sub-2', 'File content 2'),
          makeToolUseSummary('Read 2 files', ['sub-1', 'sub-2']),
          makeAssistantMessage('a2', 'Processing phase 2.'),
          makeToolResult('sub-3', 'Write output 1'),
          makeToolResult('sub-4', 'Write output 2'),
          makeToolUseSummary('Wrote 2 files', ['sub-3', 'sub-4']),
        ]);
        await pumpN($.tester);

        // Both summary bubbles visible
        expect($(ToolUseSummaryBubble), findsNWidgets(2));
        expect($('Read 2 files'), findsOneWidget);
        expect($('Wrote 2 files'), findsOneWidget);
      },
    );

    patrolWidgetTest('M2: Summary interleaved with regular tool results', (
      $,
    ) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        makeAssistantMessage('a1', 'Checking.'),
        // Normal tool result before summary
        makeToolResult('normal-1', 'Normal result before'),
        // Subagent tool results + summary
        makeToolResult('sub-1', 'Hidden result'),
        makeToolUseSummary('Subagent work done', ['sub-1']),
        // Normal tool result after summary
        makeToolResult('normal-2', 'Normal result after'),
      ]);
      await pumpN($.tester);

      // Normal results visible
      expect($('Normal result before'), findsOneWidget);
      expect($('Normal result after'), findsOneWidget);

      // Summary visible
      expect($('Subagent work done'), findsOneWidget);
      expect($(ToolUseSummaryBubble), findsOneWidget);
    });

    patrolWidgetTest('M3: Summary with 10 tool IDs compressed', ($) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      // Generate 10 tool results
      final messages = <ServerMessage>[
        const StatusMessage(status: ProcessStatus.running),
        makeAssistantMessage('a1', 'Analyzing codebase.'),
      ];
      final ids = <String>[];
      for (var i = 1; i <= 10; i++) {
        final id = 'sub-$i';
        ids.add(id);
        messages.add(makeToolResult(id, 'Result $i'));
      }
      messages.add(makeToolUseSummary('Analyzed entire codebase', ids));

      await emitAndPump($.tester, bridge, messages);
      await pumpN($.tester);

      // One summary bubble
      expect($(ToolUseSummaryBubble), findsOneWidget);
      expect($('Analyzed entire codebase'), findsOneWidget);
    });

    patrolWidgetTest(
      'M4: Summary in history — tool results not hidden (current behavior)',
      ($) async {
        // _handleHistory does NOT extract toolUseIdsToHide from
        // ToolUseSummaryMessage, so hidden IDs are empty and all tool
        // results render normally alongside the summary bubble.
        await $.pumpWidget(buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        final history = HistoryMessage(
          messages: [
            const StatusMessage(status: ProcessStatus.idle),
            makeAssistantMessage('h1', 'Work done.'),
            const ToolResultMessage(
              toolUseId: 'sub-hist-1',
              content: 'History result 1',
            ),
            const ToolResultMessage(
              toolUseId: 'sub-hist-2',
              content: 'History result 2',
            ),
            const ToolUseSummaryMessage(
              summary: 'Read 2 files from history',
              precedingToolUseIds: ['sub-hist-1', 'sub-hist-2'],
            ),
            const ToolResultMessage(
              toolUseId: 'normal-hist',
              content: 'Normal history result',
            ),
          ],
        );

        await emitAndPump($.tester, bridge, [history]);
        await pumpN($.tester);

        // Summary bubble is rendered
        expect($(ToolUseSummaryBubble), findsOneWidget);
        expect($('Read 2 files from history'), findsOneWidget);

        // History tool results are NOT hidden (hiddenToolUseIds empty)
        // so they render alongside the summary
        expect($('History result 1'), findsOneWidget);
        expect($('History result 2'), findsOneWidget);
        expect($('Normal history result'), findsOneWidget);
      },
    );

    patrolWidgetTest('M5: Summary followed by new live tool results', (
      $,
    ) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      // Phase 1: summary hides some results
      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        makeAssistantMessage('a1', 'Phase 1.'),
        makeToolResult('sub-1', 'Hidden result'),
        makeToolUseSummary('Read file', ['sub-1']),
      ]);
      await pumpN($.tester);

      expect($('Read file'), findsOneWidget);

      // Phase 2: new tool result arrives — should not be hidden
      await emitAndPump($.tester, bridge, [
        makeAssistantMessage('a2', 'Phase 2.'),
        makeToolResult('new-1', 'New live result'),
      ]);
      await pumpN($.tester);

      expect($('New live result'), findsOneWidget);
      expect($(ToolUseSummaryBubble), findsOneWidget);
    });

    patrolWidgetTest('M6: Three summaries accumulate hiddenToolUseIds', (
      $,
    ) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        // Phase 1
        makeAssistantMessage('a1', 'Phase 1.'),
        makeToolResult('s1-1', 'P1 result'),
        makeToolUseSummary('Phase 1 done', ['s1-1']),
        // Phase 2
        makeAssistantMessage('a2', 'Phase 2.'),
        makeToolResult('s2-1', 'P2 result 1'),
        makeToolResult('s2-2', 'P2 result 2'),
        makeToolUseSummary('Phase 2 done', ['s2-1', 's2-2']),
        // Phase 3
        makeAssistantMessage('a3', 'Phase 3.'),
        makeToolResult('s3-1', 'P3 result'),
        makeToolUseSummary('Phase 3 done', ['s3-1']),
      ]);
      await pumpN($.tester);

      // Three summary bubbles
      expect($(ToolUseSummaryBubble), findsNWidgets(3));
      expect($('Phase 1 done'), findsOneWidget);
      expect($('Phase 2 done'), findsOneWidget);
      expect($('Phase 3 done'), findsOneWidget);
    });
  });
}
