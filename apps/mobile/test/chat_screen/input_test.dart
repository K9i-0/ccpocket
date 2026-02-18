import 'package:ccpocket/features/chat_session/widgets/chat_input_with_overlays.dart';
import 'package:ccpocket/models/messages.dart';
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

  group('Chat input', () {
    patrolWidgetTest('H1: Idle shows input field', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      await pumpN($.tester);

      expect($(#message_input), findsOneWidget);
      expect($(#send_button), findsOneWidget);
    });

    patrolWidgetTest('H2: Send message sends to bridge', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      await pumpN($.tester);

      await $.tester.enterText(
        find.byKey(const ValueKey('message_input')),
        'Hello Claude',
      );
      await pumpN($.tester);

      await $(#send_button).tap();
      await pumpN($.tester);

      final msg = findSentMessage(bridge, 'input');
      expect(msg, isNotNull);
      expect(msg!['text'], 'Hello Claude');

      // Verify the TextField is cleared
      final textField = $.tester.widget<TextField>(
        find.byKey(const ValueKey('message_input')),
      );
      expect(textField.controller?.text, isEmpty);
    });

    patrolWidgetTest('H3: Running shows stop button', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
      ]);
      await pumpN($.tester);

      expect($(#stop_button), findsOneWidget);
    });

    patrolWidgetTest('H4: Empty text does not send', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      await pumpN($.tester);

      await $(#send_button).tap();
      await pumpN($.tester);

      final msg = findSentMessage(bridge, 'input');
      expect(msg, isNull);
    });

    patrolWidgetTest('H5: WaitingApproval hides input area', ($) async {
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
        const PermissionRequestMessage(
          toolUseId: 'tool-1',
          toolName: 'Bash',
          input: {'command': 'ls'},
        ),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      expect($(ChatInputWithOverlays), findsNothing);
    });
  });
}
