import 'package:ccpocket/features/chat_session/widgets/chat_input_with_overlays.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/approval_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'helpers/chat_test_helpers.dart';

void main() {
  group('Multiple approval queue', () {
    late MockBridgeService bridge;

    setUp(() {
      bridge = MockBridgeService();
    });

    tearDown(() {
      bridge.dispose();
    });

    patrolWidgetTest('B1: Oldest approval shows next', ($) async {
      await setupMultiApproval($, bridge);

      // The oldest request (tool-1) is shown first.
      expect(find.byType(ApprovalBar), findsOneWidget);
      expect(find.byKey(const ValueKey('approve_button')), findsOneWidget);

      // Resolve tool-1 and advance to tool-2.
      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      expect(find.byKey(const ValueKey('approve_button')), findsOneWidget);
      expect(find.byType(ApprovalBar), findsOneWidget);

      expect(find.text('git status'), findsWidgets);
    });

    patrolWidgetTest('B2: Approve both in arrival order and clear bar', (
      $,
    ) async {
      await setupMultiApproval($, bridge);

      await approveAndEmitResult($, bridge, 'tool-1', 'file1.txt');

      await approveAndEmitResult($, bridge, 'tool-2', 'On branch main');

      // Simulate bridge sending running status after all approvals resolved
      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
      ]);
      await pumpN($.tester);

      // ApprovalBar should be gone
      expect(find.byType(ApprovalBar), findsNothing);

      // ChatInputWithOverlays should be restored
      expect(find.byType(ChatInputWithOverlays), findsOneWidget);
    });

    patrolWidgetTest('B3: Three consecutive approvals', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      // Emit 3 tool uses with permission requests
      await emitAndPump($.tester, bridge, [
        makeAssistantMessage(
          'a1',
          'Command 1.',
          toolUses: [
            const ToolUseContent(
              id: 'tool-1',
              name: 'Bash',
              input: {'command': 'ls -la'},
            ),
          ],
        ),
        makeBashPermission('tool-1'),
        makeAssistantMessage(
          'a2',
          'Command 2.',
          toolUses: [
            const ToolUseContent(
              id: 'tool-2',
              name: 'Bash',
              input: {'command': 'git status'},
            ),
          ],
        ),
        const PermissionRequestMessage(
          toolUseId: 'tool-2',
          toolName: 'Bash',
          input: {'command': 'git status'},
        ),
        makeAssistantMessage(
          'a3',
          'Command 3.',
          toolUses: [
            const ToolUseContent(
              id: 'tool-3',
              name: 'Bash',
              input: {'command': 'cat README.md'},
            ),
          ],
        ),
        const PermissionRequestMessage(
          toolUseId: 'tool-3',
          toolName: 'Bash',
          input: {'command': 'cat README.md'},
        ),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      // Resolve requests in arrival order.
      expect(find.byType(ApprovalBar), findsOneWidget);
      await approveAndEmitResult($, bridge, 'tool-1', 'file1.txt');

      expect(find.byType(ApprovalBar), findsOneWidget);
      await approveAndEmitResult($, bridge, 'tool-2', 'On branch main');

      expect(find.byType(ApprovalBar), findsOneWidget);
      await approveAndEmitResult($, bridge, 'tool-3', '# README');

      // Simulate bridge sending running status
      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
      ]);
      await pumpN($.tester);

      // ApprovalBar should be gone after all 3 approvals
      expect(find.byType(ApprovalBar), findsNothing);

      // Verify 3 'approve' messages were sent
      final approveMessages = findAllSentMessages(bridge, 'approve');
      expect(approveMessages, hasLength(3));
    });

    patrolWidgetTest('B4: Reject advances to the next pending prompt', (
      $,
    ) async {
      await setupMultiApproval($, bridge);

      expect(find.byKey(const ValueKey('reject_button')), findsOneWidget);

      // Reject the oldest prompt and advance to tool-2.
      await $.tester.tap(find.byKey(const ValueKey('reject_button')));
      await pumpN($.tester);
      expect(find.byType(ApprovalBar), findsOneWidget);

      await $.tester.tap(find.byKey(const ValueKey('reject_button')));
      await pumpN($.tester);

      expect(find.byType(ApprovalBar), findsNothing);

      expect(findAllSentMessages(bridge, 'reject'), hasLength(2));
    });
  });
}
