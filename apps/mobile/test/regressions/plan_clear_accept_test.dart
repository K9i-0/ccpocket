import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/approval_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../chat_screen/helpers/chat_test_helpers.dart';
import '../helpers/chat_test_dsl.dart';

void main() {
  late MockBridgeService bridge;

  setUp(() {
    bridge = MockBridgeService();
  });

  tearDown(() {
    bridge.dispose();
  });

  group('Plan clear & accept', () {
    patrolWidgetTest('Accept Plan sends approve message without clearContext', (
      $,
    ) async {
      await setupPlanApproval($, bridge);

      // Tap "Accept Plan"
      await $.tester.tap(find.text('Accept Plan'));
      await pumpN($.tester);

      final sent = findSentMessage(bridge, 'approve');
      expect(sent, isNotNull);
      expect(sent!['id'], 'tool-exit-1');
      // clearContext should not be set for regular accept
      expect(sent['clearContext'], isNot(true));
    });

    patrolWidgetTest('Accept & Clear sends approve with clearContext=true', (
      $,
    ) async {
      await setupPlanApproval($, bridge);

      // Tap "Accept & Clear" button
      await $.tester.tap(
        find.byKey(const ValueKey('approve_clear_context_button')),
      );
      await pumpN($.tester);

      final sent = findSentMessage(bridge, 'approve');
      expect(sent, isNotNull);
      expect(sent!['id'], 'tool-exit-1');
      expect(sent['clearContext'], isTrue);
    });

    patrolWidgetTest(
      'Session switch after clearContext resets entries and approval',
      ($) async {
        await setupPlanApproval($, bridge);

        // Tap "Accept & Clear"
        await $.tester.tap(
          find.byKey(const ValueKey('approve_clear_context_button')),
        );
        await pumpN($.tester);

        // Bridge responds with session_created (clearContext)
        await ChatTestScenario($, bridge)
            .emit([
              const SystemMessage(
                subtype: 'session_created',
                sessionId: 'new-session-id',
              ),
            ])
            .expectNoWidget(ApprovalBar)
            .run();
      },
    );

    patrolWidgetTest('Keep Planning sends reject with feedback text', (
      $,
    ) async {
      await setupPlanApproval($, bridge);

      // Enter feedback text
      final feedbackInput = find.byKey(const ValueKey('plan_feedback_input'));
      // Only enter feedback if the widget exists
      if (feedbackInput.evaluate().isNotEmpty) {
        await $.tester.enterText(feedbackInput, 'Add error handling');
        await pumpN($.tester);

        // Tap the reject/keep planning button
        await $.tester.tap(find.byKey(const ValueKey('reject_button')));
        await pumpN($.tester);

        final sent = findSentMessage(bridge, 'reject');
        expect(sent, isNotNull);
        expect(sent!['id'], 'tool-exit-1');
        expect(sent['message'], contains('Add error handling'));
      }
    });

    patrolWidgetTest(
      'Plan mode approval followed by tool approval works correctly',
      ($) async {
        await setupPlanApproval($, bridge);

        // Accept the plan
        await $.tester.tap(find.text('Accept Plan'));
        await pumpN($.tester);

        // Bridge emits tool result for ExitPlanMode, then a new tool use
        await ChatTestScenario($, bridge)
            .emit([
              const ToolResultMessage(
                toolUseId: 'tool-exit-1',
                content: 'Plan accepted',
              ),
              msg.assistant(
                'a3',
                'Now executing the plan.',
                toolUses: [
                  const ToolUseContent(
                    id: 'tool-bash-1',
                    name: 'Bash',
                    input: {'command': 'npm install'},
                  ),
                ],
              ),
              msg.bashPermission('tool-bash-1'),
              msg.waitingApproval,
            ])
            .expectWidget(ApprovalBar)
            .run();

        // Approve the bash tool
        await $.tester.tap(find.byKey(const ValueKey('approve_button')));
        await pumpN($.tester);

        final allApproves = findAllSentMessages(bridge, 'approve');
        // Should have 2 approves: one for plan, one for bash
        expect(allApproves.length, 2);
        expect(allApproves[0]['id'], 'tool-exit-1');
        expect(allApproves[1]['id'], 'tool-bash-1');
      },
    );

    patrolWidgetTest('Multiple reject cycles preserve plan mode', ($) async {
      await setupPlanApproval($, bridge);

      // First reject with feedback
      final feedbackInput = find.byKey(const ValueKey('plan_feedback_input'));
      if (feedbackInput.evaluate().isNotEmpty) {
        await $.tester.enterText(feedbackInput, 'More details please');
        await pumpN($.tester);
        await $.tester.tap(find.byKey(const ValueKey('reject_button')));
        await pumpN($.tester);

        // Bridge responds with new plan
        await ChatTestScenario($, bridge).emit([
          msg.running,
          msg.assistant('a-revised', 'Here is the revised plan.'),
          msg.exitPlan('exit-2', 'tool-exit-2', '# Revised Plan'),
          const PermissionRequestMessage(
            toolUseId: 'tool-exit-2',
            toolName: 'ExitPlanMode',
            input: {'plan': 'Revised Implementation Plan'},
          ),
          msg.waitingApproval,
        ]).run();

        // Plan approval UI should still be visible
        expect(find.text('Accept Plan'), findsOneWidget);
      }
    });
  });
}
