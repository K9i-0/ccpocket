import 'package:ccpocket/features/chat/widgets/chat_input_with_overlays.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/approval_bar.dart';
import 'package:flutter/material.dart';
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

    patrolWidgetTest('B1: Approve first shows second', ($) async {
      await setupMultiApproval($, bridge);

      // Approval bar should be visible (tool-2 is the current shown approval)
      expect(find.byType(ApprovalBar), findsOneWidget);
      expect(find.byKey(const ValueKey('approve_button')), findsOneWidget);

      // Tap approve for the currently shown permission (tool-2)
      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      // After approving tool-2, _emitNextApprovalOrNone finds tool-1 still
      // pending and shows it. The approval bar should still be visible.
      expect(find.byKey(const ValueKey('approve_button')), findsOneWidget);
      expect(find.byType(ApprovalBar), findsOneWidget);

      // The 'ls -la' text should appear (in approval bar and/or tool use tile)
      expect(find.text('ls -la'), findsWidgets);
    });

    patrolWidgetTest('B2: Approve second clears bar', ($) async {
      await setupMultiApproval($, bridge);

      // Approve tool-2 (currently shown) and simulate bridge result
      await approveAndEmitResult($, bridge, 'tool-2', 'On branch main');

      // Approve tool-1 (now shown) and simulate bridge result
      await approveAndEmitResult($, bridge, 'tool-1', 'file1.txt\nfile2.txt');

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

      // Approve tool-3 (last received, currently shown)
      expect(find.byType(ApprovalBar), findsOneWidget);
      await approveAndEmitResult($, bridge, 'tool-3', '# README');

      // Approve tool-1 (next in queue)
      expect(find.byType(ApprovalBar), findsOneWidget);
      await approveAndEmitResult($, bridge, 'tool-1', 'file1.txt');

      // Approve tool-2 (last remaining)
      expect(find.byType(ApprovalBar), findsOneWidget);
      await approveAndEmitResult($, bridge, 'tool-2', 'On branch main');

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

    patrolWidgetTest('B4: Reject clears all pending', ($) async {
      await setupMultiApproval($, bridge);

      // Verify approval bar is showing
      expect(find.byKey(const ValueKey('reject_button')), findsOneWidget);

      // Tap reject
      await $.tester.tap(find.byKey(const ValueKey('reject_button')));
      await pumpN($.tester);

      // ApprovalBar should be completely gone (all pending cleared, not next)
      expect(find.byType(ApprovalBar), findsNothing);

      // Verify a 'reject' message was sent
      final rejectMessage = findSentMessage(bridge, 'reject');
      expect(rejectMessage, isNotNull);
    });
  });
}
