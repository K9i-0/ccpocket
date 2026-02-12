import 'package:ccpocket/features/chat/widgets/chat_input_with_overlays.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/approval_bar.dart';
import 'package:flutter/material.dart';
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

  group('Consecutive approvals', () {
    patrolWidgetTest(
      'K1: Approve then immediate new permission without tool_result',
      ($) async {
        await $.pumpWidget(buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        // Setup single approval
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
          const StatusMessage(status: ProcessStatus.waitingApproval),
        ]);
        await pumpN($.tester);
        expect($(ApprovalBar), findsOneWidget);

        // Approve tool-1
        await $.tester.tap(find.byKey(const ValueKey('approve_button')));
        await pumpN($.tester);

        // Approval bar should be gone (only one pending)
        expect($(ApprovalBar), findsNothing);

        // Before tool-1 result arrives, new permission arrives
        await emitAndPump($.tester, bridge, [
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
          const StatusMessage(status: ProcessStatus.waitingApproval),
        ]);
        await pumpN($.tester);

        // Approval bar reappears with tool-2
        expect($(ApprovalBar), findsOneWidget);

        // Can approve tool-2
        await $.tester.tap(find.byKey(const ValueKey('approve_button')));
        await pumpN($.tester);

        final approves = findAllSentMessages(bridge, 'approve');
        expect(approves, hasLength(2));
        expect(approves[0]['id'], 'tool-1');
        expect(approves[1]['id'], 'tool-2');
      },
    );

    patrolWidgetTest('K2: Mixed approve and reject in sequence', ($) async {
      await setupMultiApproval($, bridge);

      // Approve tool-2 (currently shown) and emit result
      await approveAndEmitResult($, bridge, 'tool-2', 'On branch main');

      // tool-1 now shown — reject it
      expect($(ApprovalBar), findsOneWidget);
      await $.tester.tap(find.byKey(const ValueKey('reject_button')));
      await pumpN($.tester);

      // Verify one approve (tool-2) and one reject (tool-1)
      final approves = findAllSentMessages(bridge, 'approve');
      final rejects = findAllSentMessages(bridge, 'reject');
      expect(approves, hasLength(1));
      expect(approves[0]['id'], 'tool-2');
      expect(rejects, hasLength(1));
      expect(rejects[0]['id'], 'tool-1');

      // ApprovalBar should be gone after reject
      expect($(ApprovalBar), findsNothing);
    });

    patrolWidgetTest('K3: Approve Always then normal approve', ($) async {
      await setupMultiApproval($, bridge);

      // "Always" approve tool-2
      await $.tester.tap(find.byKey(const ValueKey('approve_always_button')));
      await pumpN($.tester);

      // Emit result for tool-2 so next pending shows
      await emitAndPump($.tester, bridge, [
        const ToolResultMessage(toolUseId: 'tool-2', content: 'On branch main'),
      ]);
      await pumpN($.tester);

      // tool-1 now shown — normal approve
      expect($(ApprovalBar), findsOneWidget);
      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      // Verify approve_always for tool-2, approve for tool-1
      final always = findAllSentMessages(bridge, 'approve_always');
      final approves = findAllSentMessages(bridge, 'approve');
      expect(always, hasLength(1));
      expect(always[0]['id'], 'tool-2');
      expect(approves, hasLength(1));
      expect(approves[0]['id'], 'tool-1');
    });

    patrolWidgetTest('K4: Five rapid approvals in sequence', ($) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      // Emit 5 tool uses with permissions
      final messages = <ServerMessage>[];
      for (var i = 1; i <= 5; i++) {
        messages.add(
          makeAssistantMessage(
            'a$i',
            'Command $i.',
            toolUses: [
              ToolUseContent(
                id: 'tool-$i',
                name: 'Bash',
                input: {'command': 'cmd$i'},
              ),
            ],
          ),
        );
        messages.add(
          PermissionRequestMessage(
            toolUseId: 'tool-$i',
            toolName: 'Bash',
            input: {'command': 'cmd$i'},
          ),
        );
      }
      messages.add(const StatusMessage(status: ProcessStatus.waitingApproval));

      await emitAndPump($.tester, bridge, messages);
      await pumpN($.tester);

      // The last PermissionRequestMessage processed (tool-5) is displayed first.
      // After approving it, _emitNextApprovalOrNone picks the earliest
      // unresolved permission from entries, so the order is: 5, 1, 2, 3, 4.
      final approvalOrder = [5, 1, 2, 3, 4];
      for (final i in approvalOrder) {
        expect($(ApprovalBar), findsOneWidget);
        await approveAndEmitResult($, bridge, 'tool-$i', 'result $i');
      }

      // All 5 approved, bar gone
      expect($(ApprovalBar), findsNothing);
      final approves = findAllSentMessages(bridge, 'approve');
      expect(approves, hasLength(5));
    });

    patrolWidgetTest('K5: Button approve first, button approve second', (
      $,
    ) async {
      await setupMultiApproval($, bridge);

      // Button approve tool-2
      await approveAndEmitResult($, bridge, 'tool-2', 'On branch main');

      // tool-1 now shown — button approve
      expect($(ApprovalBar), findsOneWidget);
      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      // Both approved
      final approves = findAllSentMessages(bridge, 'approve');
      expect(approves, hasLength(2));
    });

    patrolWidgetTest('K6: After all approvals resolved input is restored', (
      $,
    ) async {
      await setupMultiApproval($, bridge);

      // During approval: input hidden
      expect($(ChatInputWithOverlays), findsNothing);

      // Approve both
      await approveAndEmitResult($, bridge, 'tool-2', 'result');
      await approveAndEmitResult($, bridge, 'tool-1', 'result');

      // Emit running then idle
      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
      ]);
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      await pumpN($.tester);

      // Input restored
      expect($(ApprovalBar), findsNothing);
      expect($(ChatInputWithOverlays), findsOneWidget);
    });
  });
}
