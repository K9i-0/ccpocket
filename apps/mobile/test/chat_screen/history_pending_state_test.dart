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

  group('History pending state restoration', () {
    patrolWidgetTest(
      'L1: History with plan approval pending shows plan approval bar',
      ($) async {
        await $.pumpWidget(buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await emitAndPump($.tester, bridge, [
          makeHistoryWithPlanApproval('tool-plan-hist'),
        ]);
        await pumpN($.tester);

        // Plan approval bar should show
        expect($(ApprovalBar), findsOneWidget);
        expect(find.text('Accept Plan'), findsOneWidget);
        expect(find.text('Keep Planning'), findsOneWidget);

        // Always button should NOT be shown (plan mode)
        expect(
          find.byKey(const ValueKey('approve_always_button')),
          findsNothing,
        );

        // Note: _handleHistory does NOT restore inPlanMode, so
        // PlanModeChip will not be visible from history alone
        expect($(PlanModeChip), findsNothing);

        // Input should be hidden during approval
        expect($(ChatInputWithOverlays), findsNothing);
      },
    );

    patrolWidgetTest(
      'L2: History with AskUserQuestion pending shows question widget',
      ($) async {
        await $.pumpWidget(buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        final question = [
          {
            'question': 'Which approach should we take?',
            'header': 'Approach',
            'options': [
              {'label': 'Option A', 'description': 'Simple approach'},
              {'label': 'Option B', 'description': 'Complex approach'},
            ],
            'multiSelect': false,
          },
        ];

        await emitAndPump($.tester, bridge, [
          makeHistoryWithAskUser('ask-hist-1', question),
        ]);
        await pumpN($.tester);

        // AskUserQuestionWidget should be shown
        expect($(AskUserQuestionWidget), findsOneWidget);
        expect(find.text('Which approach should we take?'), findsOneWidget);

        // ApprovalBar should NOT be shown
        expect($(ApprovalBar), findsNothing);

        // Input hidden
        expect($(ChatInputWithOverlays), findsNothing);
      },
    );

    patrolWidgetTest('L3: History with mixed resolved/unresolved permissions', (
      $,
    ) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      // 3 permissions: tool-2 resolved by ToolResult, tool-1 and tool-3 pending
      final history = HistoryMessage(
        messages: [
          const StatusMessage(status: ProcessStatus.waitingApproval),
          makeAssistantMessage(
            'h1',
            'Cmd 1',
            toolUses: [
              const ToolUseContent(
                id: 'tool-1',
                name: 'Bash',
                input: {'command': 'ls'},
              ),
            ],
          ),
          const PermissionRequestMessage(
            toolUseId: 'tool-1',
            toolName: 'Bash',
            input: {'command': 'ls'},
          ),
          makeAssistantMessage(
            'h2',
            'Cmd 2',
            toolUses: [
              const ToolUseContent(
                id: 'tool-2',
                name: 'Bash',
                input: {'command': 'pwd'},
              ),
            ],
          ),
          const PermissionRequestMessage(
            toolUseId: 'tool-2',
            toolName: 'Bash',
            input: {'command': 'pwd'},
          ),
          // tool-2 was resolved
          const ToolResultMessage(toolUseId: 'tool-2', content: '/home/user'),
          makeAssistantMessage(
            'h3',
            'Cmd 3',
            toolUses: [
              const ToolUseContent(
                id: 'tool-3',
                name: 'Bash',
                input: {'command': 'cat file.txt'},
              ),
            ],
          ),
          const PermissionRequestMessage(
            toolUseId: 'tool-3',
            toolName: 'Bash',
            input: {'command': 'cat file.txt'},
          ),
        ],
      );

      await emitAndPump($.tester, bridge, [history]);
      await pumpN($.tester);

      // ApprovalBar shows first pending (tool-1, FIFO order)
      expect($(ApprovalBar), findsOneWidget);

      // Approve tool-1 and emit result
      await approveAndEmitResult($, bridge, 'tool-1', 'file1.txt');

      // tool-3 should now show (tool-2 already resolved)
      expect($(ApprovalBar), findsOneWidget);

      // Approve tool-3
      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      // Verify both approvals sent
      final approves = findAllSentMessages(bridge, 'approve');
      expect(approves, hasLength(2));
      expect(approves[0]['id'], 'tool-1');
      expect(approves[1]['id'], 'tool-3');
    });

    patrolWidgetTest(
      'L4: History with ResultMessage clears all pending state',
      ($) async {
        await $.pumpWidget(buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        // History with permissions but ending with ResultMessage
        final history = HistoryMessage(
          messages: [
            const StatusMessage(status: ProcessStatus.idle),
            makeAssistantMessage(
              'h1',
              'Cmd 1',
              toolUses: [
                const ToolUseContent(
                  id: 'tool-1',
                  name: 'Bash',
                  input: {'command': 'ls'},
                ),
              ],
            ),
            const PermissionRequestMessage(
              toolUseId: 'tool-1',
              toolName: 'Bash',
              input: {'command': 'ls'},
            ),
            const ResultMessage(subtype: 'success', cost: 0.01),
          ],
        );

        await emitAndPump($.tester, bridge, [history]);
        await pumpN($.tester);

        // No approval bar (ResultMessage clears all pending)
        expect($(ApprovalBar), findsNothing);
        // Input visible (idle status)
        expect($(ChatInputWithOverlays), findsOneWidget);
      },
    );

    patrolWidgetTest('L5: History plan approval can be accepted', ($) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        makeHistoryWithPlanApproval('tool-plan-hist'),
      ]);
      await pumpN($.tester);

      expect(find.text('Accept Plan'), findsOneWidget);

      // Accept plan
      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      final msg = findSentMessage(bridge, 'approve');
      expect(msg, isNotNull);
      expect(msg!['id'], 'tool-plan-hist');

      // ApprovalBar should be gone
      expect($(ApprovalBar), findsNothing);
    });

    patrolWidgetTest(
      'L6: History plan approval can be rejected with feedback',
      ($) async {
        await $.pumpWidget(buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await emitAndPump($.tester, bridge, [
          makeHistoryWithPlanApproval('tool-plan-hist'),
        ]);
        await pumpN($.tester);

        expect(find.text('Keep Planning'), findsOneWidget);

        // Enter feedback
        await $.tester.enterText(
          find.byKey(const ValueKey('plan_feedback_input')),
          'Need more detail on step 3',
        );
        await pumpN($.tester);

        // Reject
        await $.tester.tap(find.byKey(const ValueKey('reject_button')));
        await pumpN($.tester);

        final msg = findSentMessage(bridge, 'reject');
        expect(msg, isNotNull);
        expect(msg!['message'], 'Need more detail on step 3');

        // ApprovalBar should be gone
        expect($(ApprovalBar), findsNothing);
      },
    );
  });
}
