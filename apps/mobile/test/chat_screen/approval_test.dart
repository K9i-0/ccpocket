import 'package:ccpocket/features/claude_code_session/widgets/chat_input_with_overlays.dart';
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

  /// Emit an assistant message with a Bash tool use, a permission request,
  /// and a waitingApproval status so the ApprovalBar becomes visible.
  Future<void> setupApproval(PatrolTester $) async {
    await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
    await pumpN($.tester);
    await emitAndPump($.tester, bridge, [
      makeAssistantMessage(
        'a1',
        'Running command.',
        toolUses: [
          const ToolUseContent(
            id: 'tool-1',
            name: 'Bash',
            input: {'command': 'ls'},
          ),
        ],
      ),
      makeBashPermission('tool-1'),
      const StatusMessage(status: ProcessStatus.waitingApproval),
    ]);
    await pumpN($.tester);
  }

  group('Single tool approval', () {
    patrolWidgetTest(
      'A1: Approval bar displays when permission request + waitingApproval',
      ($) async {
        await setupApproval($);

        expect($(ApprovalBar), findsOneWidget);
        expect($(#approve_button), findsOneWidget);
        expect($(#reject_button), findsOneWidget);
        expect($(#approve_always_button), findsOneWidget);
      },
    );

    patrolWidgetTest('A2: Approve sends approve message', ($) async {
      await setupApproval($);

      await $(#approve_button).tap();
      await pumpN($.tester);

      final msg = findSentMessage(bridge, 'approve');
      expect(msg, isNotNull);
      expect(msg!['id'], 'tool-1');
    });

    patrolWidgetTest('A3: Reject sends reject message', ($) async {
      await setupApproval($);

      await $(#reject_button).tap();
      await pumpN($.tester);

      final msg = findSentMessage(bridge, 'reject');
      expect(msg, isNotNull);
    });

    patrolWidgetTest('A4: Always sends approve_always message', ($) async {
      await setupApproval($);

      await $(#approve_always_button).tap();
      await pumpN($.tester);

      final msg = findSentMessage(bridge, 'approve_always');
      expect(msg, isNotNull);
    });

    patrolWidgetTest('A5: Input area hidden during waitingApproval', ($) async {
      await setupApproval($);

      expect($(ChatInputWithOverlays), findsNothing);
    });

    patrolWidgetTest('A6: No Dismissible — swipe does not approve', ($) async {
      await setupApproval($);

      // Verify there is no Dismissible widget wrapping the approval bar
      expect(find.byType(Dismissible), findsNothing);

      // Approval bar is shown and only responds to button taps
      expect($(ApprovalBar), findsOneWidget);
      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      final msg = findSentMessage(bridge, 'approve');
      expect(msg, isNotNull);
    });

    patrolWidgetTest('A7: No Dismissible — swipe does not reject', ($) async {
      await setupApproval($);

      // Verify there is no Dismissible widget wrapping the approval bar
      expect(find.byType(Dismissible), findsNothing);

      // Rejection only works via button
      expect($(ApprovalBar), findsOneWidget);
      await $.tester.tap(find.byKey(const ValueKey('reject_button')));
      await pumpN($.tester);

      final msg = findSentMessage(bridge, 'reject');
      expect(msg, isNotNull);
    });
  });
}
