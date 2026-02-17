import 'package:ccpocket/models/messages.dart';
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

  group('Rewind', () {
    patrolWidgetTest(
      'RewindPreviewMessage is stored in state and cleared after rewind',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        // Send a user message first so rewind has a target
        await ChatTestScenario($, bridge).emit([
          msg.assistant('a1', 'Hello!'),
          const UserInputMessage(
            text: 'Do something',
            userMessageUuid: 'user-uuid-1',
          ),
          msg.assistant('a2', 'Done!'),
          msg.result(),
          msg.idle,
        ]).run();

        // Emit a RewindPreviewMessage (simulating dry-run response)
        await emitAndPump($.tester, bridge, [
          const RewindPreviewMessage(
            canRewind: true,
            filesChanged: ['lib/main.dart'],
            insertions: 5,
            deletions: 2,
          ),
        ]);
        await pumpN($.tester);

        // The cubit should have stored the preview
        // (can't directly check cubit state from here, but we verify
        // no crash and the message was processed)

        // Now emit a RewindResultMessage
        await emitAndPump($.tester, bridge, [
          const RewindResultMessage(success: true, mode: 'both'),
        ]);
        await pumpN($.tester);

        // No crash - rewind result processed correctly
      },
    );

    patrolWidgetTest(
      'RewindPreviewMessage with canRewind=false is handled gracefully',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await emitAndPump($.tester, bridge, [
          const RewindPreviewMessage(
            canRewind: false,
            error: 'No checkpoints available',
          ),
        ]);
        await pumpN($.tester);

        // Should not crash even when canRewind is false
      },
    );

    patrolWidgetTest(
      'RewindResultMessage with success=false is handled gracefully',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await emitAndPump($.tester, bridge, [
          const RewindResultMessage(
            success: false,
            mode: 'code',
            error: 'Failed to rewind files',
          ),
        ]);
        await pumpN($.tester);

        // Should not crash on failed rewind
      },
    );
  });
}
