import 'package:ccpocket/features/chat/widgets/chat_input_with_overlays.dart';
import 'package:ccpocket/features/chat/widgets/plan_mode_chip.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/approval_bar.dart';
import 'package:ccpocket/widgets/bubbles/ask_user_question_widget.dart';
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

  group('Plan + Approve flow', () {
    patrolWidgetTest('J1: Plan accept followed by tool approval', ($) async {
      await setupPlanApproval($, bridge);

      // Verify plan approval bar is showing
      expect(find.text('Accept Plan'), findsOneWidget);
      expect($(PlanModeChip), findsOneWidget);

      // Accept plan
      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      final approveMsg = findSentMessage(bridge, 'approve');
      expect(approveMsg, isNotNull);
      expect(approveMsg!['id'], 'tool-exit-1');

      // Bridge sends tool result for plan, then new Bash tool + permission
      await emitAndPump($.tester, bridge, [
        const ToolResultMessage(
          toolUseId: 'tool-exit-1',
          content: 'Plan approved',
        ),
        makeAssistantMessage(
          'a-post-plan',
          'Running command.',
          toolUses: [
            const ToolUseContent(
              id: 'tool-bash-1',
              name: 'Bash',
              input: {'command': 'npm install'},
            ),
          ],
        ),
        makeBashPermission('tool-bash-1'),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      // Now approval bar should show normal tool approval (not plan)
      expect($(ApprovalBar), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('approve_always_button')),
        findsOneWidget,
      );

      // PlanModeChip still visible (inPlanMode not reset by approve)
      expect($(PlanModeChip), findsOneWidget);
    });

    patrolWidgetTest('J2: Plan reject with feedback triggers re-plan cycle', (
      $,
    ) async {
      await setupPlanApproval($, bridge);

      // Enter feedback
      await $.tester.enterText(
        find.byKey(const ValueKey('plan_feedback_input')),
        'Add error handling',
      );
      await pumpN($.tester);

      // Reject (Keep Planning)
      await $.tester.tap(find.byKey(const ValueKey('reject_button')));
      await pumpN($.tester);

      final rejectMsg = findSentMessage(bridge, 'reject');
      expect(rejectMsg, isNotNull);
      expect(rejectMsg!['message'], 'Add error handling');

      // ApprovalBar should be gone after reject
      expect($(ApprovalBar), findsNothing);

      // Bridge re-enters plan mode with revised plan
      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        makeEnterPlanMessage('enter-2', 'tool-enter-2'),
        makePlanExitMessage(
          'exit-2',
          'tool-exit-2',
          '# Revised Plan\n\n- Step 1 with error handling',
        ),
        const PermissionRequestMessage(
          toolUseId: 'tool-exit-2',
          toolName: 'ExitPlanMode',
          input: {'plan': 'Revised Plan'},
        ),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      // Plan approval bar reappears
      expect(find.text('Accept Plan'), findsOneWidget);
      expect(find.text('Keep Planning'), findsOneWidget);
    });

    patrolWidgetTest(
      'J3: Plan accept with clearContext sends clearContext and transitions',
      ($) async {
        await setupPlanApproval($, bridge);

        // Toggle Clear Context chip
        await $.tester.tap(find.byKey(const ValueKey('clear_context_chip')));
        await pumpN($.tester);

        // Accept Plan
        await $.tester.tap(find.byKey(const ValueKey('approve_button')));
        await pumpN($.tester);

        final msg = findSentMessage(bridge, 'approve');
        expect(msg, isNotNull);
        expect(msg!['clearContext'], true);

        // Bridge sends tool result, then clearing status, then idle
        await emitAndPump($.tester, bridge, [
          const ToolResultMessage(
            toolUseId: 'tool-exit-1',
            content: 'Plan approved',
          ),
          const StatusMessage(status: ProcessStatus.clearing),
        ]);
        await pumpN($.tester);

        // During clearing: approval bar should be gone
        expect($(ApprovalBar), findsNothing);

        // Transition to idle
        await emitAndPump($.tester, bridge, [
          const StatusMessage(status: ProcessStatus.idle),
        ]);
        await pumpN($.tester);

        // Input should be restored
        expect($(ChatInputWithOverlays), findsOneWidget);
      },
    );

    patrolWidgetTest('J4: Plan accept then AskUserQuestion', ($) async {
      await setupPlanApproval($, bridge);

      // Accept Plan
      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      // Bridge sends tool result, then AskUserQuestion
      final question = [
        {
          'question': 'Which database should we use?',
          'header': 'Database',
          'options': [
            {'label': 'SQLite', 'description': 'Embedded DB'},
            {'label': 'PostgreSQL', 'description': 'Server DB'},
          ],
          'multiSelect': false,
        },
      ];
      await emitAndPump($.tester, bridge, [
        const ToolResultMessage(
          toolUseId: 'tool-exit-1',
          content: 'Plan approved',
        ),
        makeAskQuestionMessage('ask-q1', question),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      // AskUserQuestionWidget should be shown, not ApprovalBar
      expect($(AskUserQuestionWidget), findsOneWidget);
      expect($(ApprovalBar), findsNothing);
      expect(find.text('Which database should we use?'), findsOneWidget);
    });

    patrolWidgetTest('J5: Multiple plan rejection cycles then accept', (
      $,
    ) async {
      await setupPlanApproval($, bridge);

      // --- Rejection cycle 1 ---
      await $.tester.enterText(
        find.byKey(const ValueKey('plan_feedback_input')),
        'Add tests',
      );
      await pumpN($.tester);
      await $.tester.tap(find.byKey(const ValueKey('reject_button')));
      await pumpN($.tester);

      // Re-plan cycle 1
      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        makeEnterPlanMessage('enter-2', 'tool-enter-2'),
        makePlanExitMessage('exit-2', 'tool-exit-2', '# Plan v2'),
        const PermissionRequestMessage(
          toolUseId: 'tool-exit-2',
          toolName: 'ExitPlanMode',
          input: {'plan': 'Plan v2'},
        ),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);
      expect(find.text('Accept Plan'), findsOneWidget);

      // --- Rejection cycle 2 ---
      await $.tester.enterText(
        find.byKey(const ValueKey('plan_feedback_input')),
        'More detail on step 3',
      );
      await pumpN($.tester);
      await $.tester.tap(find.byKey(const ValueKey('reject_button')));
      await pumpN($.tester);

      // Re-plan cycle 2
      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        makeEnterPlanMessage('enter-3', 'tool-enter-3'),
        makePlanExitMessage('exit-3', 'tool-exit-3', '# Plan v3'),
        const PermissionRequestMessage(
          toolUseId: 'tool-exit-3',
          toolName: 'ExitPlanMode',
          input: {'plan': 'Plan v3'},
        ),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);
      expect(find.text('Accept Plan'), findsOneWidget);

      // --- Rejection cycle 3 ---
      await $.tester.enterText(
        find.byKey(const ValueKey('plan_feedback_input')),
        'Simplify step 1',
      );
      await pumpN($.tester);
      await $.tester.tap(find.byKey(const ValueKey('reject_button')));
      await pumpN($.tester);

      // Re-plan cycle 3 (final)
      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        makeEnterPlanMessage('enter-4', 'tool-enter-4'),
        makePlanExitMessage('exit-4', 'tool-exit-4', '# Plan v4 (final)'),
        const PermissionRequestMessage(
          toolUseId: 'tool-exit-4',
          toolName: 'ExitPlanMode',
          input: {'plan': 'Plan v4'},
        ),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      // --- Accept final plan ---
      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      // Verify all reject messages have correct feedback
      final rejects = findAllSentMessages(bridge, 'reject');
      expect(rejects, hasLength(3));
      expect(rejects[0]['message'], 'Add tests');
      expect(rejects[1]['message'], 'More detail on step 3');
      expect(rejects[2]['message'], 'Simplify step 1');

      // Verify final approve (only one — initial plan was rejected, not approved)
      final approves = findAllSentMessages(bridge, 'approve');
      expect(approves, hasLength(1));
      expect(approves[0]['id'], 'tool-exit-4');

      // After approve + running: approval bar gone
      await emitAndPump($.tester, bridge, [
        const ToolResultMessage(
          toolUseId: 'tool-exit-4',
          content: 'Plan approved',
        ),
        const StatusMessage(status: ProcessStatus.running),
      ]);
      await pumpN($.tester);
      expect($(ApprovalBar), findsNothing);
    });
  });
}
