import 'package:ccpocket/features/chat_session/widgets/chat_input_with_overlays.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    patrolWidgetTest(
      'H6: Arrow keys navigate file completion and Tab selects',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await emitAndPump($.tester, bridge, [
          const StatusMessage(status: ProcessStatus.idle),
        ]);
        bridge.emitFileList(['a.dart', 'bb.dart', 'ccc.dart']);
        await pumpN($.tester);

        await $.tester.enterText(
          find.byKey(const ValueKey('message_input')),
          '@',
        );
        await pumpN($.tester);

        expect(find.text('a.dart'), findsOneWidget);
        expect(find.text('bb.dart'), findsOneWidget);

        await $.tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await $.tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
        await $.tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
        await $.tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
        await pumpN($.tester);

        final textField = $.tester.widget<TextField>(
          find.byKey(const ValueKey('message_input')),
        );
        expect(textField.controller?.text, '@bb.dart ');
      },
    );

    patrolWidgetTest('H7: Ctrl+N/P navigate file completion and Tab selects', (
      $,
    ) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      bridge.emitFileList(['a.dart', 'bb.dart', 'ccc.dart']);
      await pumpN($.tester);

      await $.tester.enterText(
        find.byKey(const ValueKey('message_input')),
        '@',
      );
      await pumpN($.tester);

      await $.tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyN,
        character: '\u000e',
      );
      await $.tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
      await $.tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyN,
        character: '\u000e',
      );
      await $.tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
      await $.tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyP,
        character: '\u0010',
      );
      await $.tester.sendKeyUpEvent(LogicalKeyboardKey.keyP);
      await $.tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await $.tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await pumpN($.tester);

      final textField = $.tester.widget<TextField>(
        find.byKey(const ValueKey('message_input')),
      );
      expect(textField.controller?.text, '@bb.dart ');
    });

    patrolWidgetTest('H8: Ctrl+A/E jump to first and last file completions', (
      $,
    ) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      bridge.emitFileList(['a.dart', 'bb.dart', 'ccc.dart']);
      await pumpN($.tester);

      await $.tester.enterText(
        find.byKey(const ValueKey('message_input')),
        '@',
      );
      await pumpN($.tester);

      await $.tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyE,
        character: '\u0005',
      );
      await $.tester.sendKeyUpEvent(LogicalKeyboardKey.keyE);
      await $.tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyA,
        character: '\u0001',
      );
      await $.tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await $.tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await $.tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await pumpN($.tester);

      var textField = $.tester.widget<TextField>(
        find.byKey(const ValueKey('message_input')),
      );
      expect(textField.controller?.text, '@a.dart ');

      await $.tester.enterText(
        find.byKey(const ValueKey('message_input')),
        '@',
      );
      await pumpN($.tester);

      await $.tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyE,
        character: '\u0005',
      );
      await $.tester.sendKeyUpEvent(LogicalKeyboardKey.keyE);
      await $.tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await $.tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await pumpN($.tester);

      textField = $.tester.widget<TextField>(
        find.byKey(const ValueKey('message_input')),
      );
      expect(textField.controller?.text, '@ccc.dart ');
    });
  });
}
