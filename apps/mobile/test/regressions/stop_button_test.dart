import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/approval_bar.dart';
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

  group('Stop button', () {
    patrolWidgetTest(
      'Stop during running state resets approval and plan mode',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        // Setup: running state with pending approval
        await ChatTestScenario($, bridge)
            .emit([
              msg.assistant(
                'a1',
                'Running command',
                toolUses: [
                  const ToolUseContent(
                    id: 'tool-1',
                    name: 'Bash',
                    input: {'command': 'ls'},
                  ),
                ],
              ),
              msg.bashPermission('tool-1'),
              msg.waitingApproval,
            ])
            .expectWidget(ApprovalBar)
            .run();

        // Emit stopped result (simulating Bridge response to stop)
        await ChatTestScenario($, bridge)
            .emit([const ResultMessage(subtype: 'stopped')])
            .expectNoWidget(ApprovalBar)
            .run();
      },
    );

    patrolWidgetTest('Stop during streaming clears streaming state', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      // Emit streaming deltas
      await ChatTestScenario($, bridge).emit([
        msg.running,
        msg.streamDelta('Hello '),
        msg.streamDelta('world'),
      ]).run();

      // Emit stopped result
      await ChatTestScenario(
        $,
        bridge,
      ).emit([const ResultMessage(subtype: 'stopped')]).run();

      // No crash - streaming state was cleaned up
    });

    patrolWidgetTest('Stop during plan mode resets inPlanMode', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      // Enter plan mode
      await ChatTestScenario($, bridge).emit([
        msg.enterPlan('enter-1', 'tool-enter-1'),
        msg.exitPlan('exit-1', 'tool-exit-1', '# Plan'),
        const PermissionRequestMessage(
          toolUseId: 'tool-exit-1',
          toolName: 'ExitPlanMode',
          input: {'plan': 'Implementation Plan'},
        ),
        msg.waitingApproval,
      ]).run();

      // Verify plan approval UI is visible
      expect(find.text('Accept Plan'), findsOneWidget);

      // Emit stopped result
      await ChatTestScenario(
        $,
        bridge,
      ).emit([const ResultMessage(subtype: 'stopped')]).run();

      // Plan approval UI should be gone
      expect(find.text('Accept Plan'), findsNothing);
    });

    patrolWidgetTest('Messages arriving after stop are still displayed', (
      $,
    ) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      // Running → stopped
      await ChatTestScenario($, bridge).emit([
        msg.running,
        msg.assistant('a1', 'Working...'),
        const ResultMessage(subtype: 'stopped'),
      ]).run();

      // Send new message (new session starts)
      await ChatTestScenario($, bridge)
          .emit([
            msg.running,
            msg.assistant('a2', 'New response after stop'),
            msg.result(),
            msg.idle,
          ])
          .expectText('New response after stop')
          .run();
    });
  });
}
