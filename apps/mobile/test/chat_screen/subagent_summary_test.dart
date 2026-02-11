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

  group('Subagent summary', () {
    patrolWidgetTest('F1: ToolUseSummaryMessage displays summary text', (
      $,
    ) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        makeAssistantMessage('a1', 'Working on it.'),
        const ToolUseSummaryMessage(
          summary: 'Read 3 files and analyzed code',
          precedingToolUseIds: ['sub-1'],
        ),
      ]);
      await pumpN($.tester);

      expect($(ToolUseSummaryBubble), findsOneWidget);
      expect($('Read 3 files and analyzed code'), findsOneWidget);
    });

    patrolWidgetTest('F2: Preceding tool results are hidden', ($) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        makeAssistantMessage('a1', 'Processing.'),
        const ToolResultMessage(toolUseId: 'sub-1', content: 'Result 1'),
        const ToolResultMessage(toolUseId: 'sub-2', content: 'Result 2'),
        const ToolUseSummaryMessage(
          summary: 'Read 2 files',
          precedingToolUseIds: ['sub-1', 'sub-2'],
        ),
      ]);
      await pumpN($.tester);

      expect($('Read 2 files'), findsOneWidget);
    });

    patrolWidgetTest('F3: Non-hidden tool results display normally', ($) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        makeAssistantMessage('a1', 'Checking.'),
        const ToolResultMessage(
          toolUseId: 'normal-1',
          content: 'Normal result',
        ),
      ]);
      await pumpN($.tester);

      expect($('Normal result'), findsOneWidget);
    });
  });
}
