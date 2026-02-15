import 'package:ccpocket/features/claude_code_session/widgets/chat_input_with_overlays.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/approval_bar.dart';
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

  group('History approval restoration', () {
    patrolWidgetTest('D1: History with waitingApproval shows ApprovalBar', (
      $,
    ) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        makeHistoryWithPendingApproval('tool-hist-1'),
      ]);
      await pumpN($.tester);

      expect($(ApprovalBar), findsOneWidget);
      expect($(#approve_button), findsOneWidget);
    });

    patrolWidgetTest('D2: History with idle does NOT show ApprovalBar', (
      $,
    ) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        makeHistoryWithPendingApproval(
          'tool-hist-1',
          status: ProcessStatus.idle,
        ),
      ]);
      await pumpN($.tester);

      expect($(ApprovalBar), findsNothing);
      expect($(ChatInputWithOverlays), findsOneWidget);
    });

    patrolWidgetTest('D3: History with 2 unresolved permissions shows first', (
      $,
    ) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      final historyWith2 = HistoryMessage(
        messages: [
          const StatusMessage(status: ProcessStatus.waitingApproval),
          makeAssistantMessage(
            'h1',
            'Command 1',
            toolUses: [
              const ToolUseContent(
                id: 'tool-hist-1',
                name: 'Bash',
                input: {'command': 'ls -la'},
              ),
            ],
          ),
          const PermissionRequestMessage(
            toolUseId: 'tool-hist-1',
            toolName: 'Bash',
            input: {'command': 'ls -la'},
          ),
          makeAssistantMessage(
            'h2',
            'Command 2',
            toolUses: [
              const ToolUseContent(
                id: 'tool-hist-2',
                name: 'Bash',
                input: {'command': 'cat file.txt'},
              ),
            ],
          ),
          const PermissionRequestMessage(
            toolUseId: 'tool-hist-2',
            toolName: 'Bash',
            input: {'command': 'cat file.txt'},
          ),
        ],
      );

      await emitAndPump($.tester, bridge, [historyWith2]);
      await pumpN($.tester);

      expect($(ApprovalBar), findsOneWidget);
      expect(find.text('ls -la'), findsWidgets);
    });

    patrolWidgetTest('D4: History restored permission can be approved', (
      $,
    ) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        makeHistoryWithPendingApproval('tool-hist-1'),
      ]);
      await pumpN($.tester);

      expect($(ApprovalBar), findsOneWidget);

      await $(#approve_button).tap();
      await pumpN($.tester);

      final msg = findSentMessage(bridge, 'approve');
      expect(msg, isNotNull);
      expect(msg!['id'], 'tool-hist-1');
    });
  });
}
