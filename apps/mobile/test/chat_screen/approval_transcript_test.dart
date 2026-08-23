import 'package:ccpocket/features/chat_session/permission_transcript.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/approval_bar.dart';
import 'package:ccpocket/widgets/bubbles/permission_request_bubble.dart';
import 'package:ccpocket/widgets/bubbles/tool_result_bubble.dart';
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

  patrolWidgetTest(
    'pending approval is compact and the bottom bar owns the full action UI',
    ($) async {
      await $.pumpWidget(await buildTestCodexSessionScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        makeAssistantMessage(
          'assistant-1',
          'Running command.',
          toolUses: [
            const ToolUseContent(
              id: 'command-1',
              name: 'Bash',
              input: {'command': 'git status --short'},
            ),
          ],
        ),
        const PermissionRequestMessage(
          toolUseId: 'command-1',
          toolName: 'Bash',
          input: {
            'command': 'git status --short',
            'reason': 'Inspect the working tree',
          },
        ),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      expect($(ApprovalBar), findsOneWidget);
      expect($(PermissionRequestBubble), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);

      final transcriptBubble = $.tester.widget<PermissionRequestBubble>(
        find.byType(PermissionRequestBubble),
      );
      expect(transcriptBubble.status, PermissionTranscriptStatus.pending);
    },
  );

  patrolWidgetTest(
    'resolved approval becomes one history event and keeps real command output',
    ($) async {
      await $.pumpWidget(await buildTestCodexSessionScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const PermissionRequestMessage(
          toolUseId: 'command-1',
          toolName: 'Bash',
          input: {'command': 'pwd'},
        ),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      await $(#approve_button).tap();
      await emitAndPump($.tester, bridge, [
        const ToolResultMessage(
          toolUseId: 'command-1',
          content: 'Approved',
          permissionOutcome: PermissionOutcome.approved,
        ),
        const StatusMessage(status: ProcessStatus.running),
        const ToolResultMessage(
          toolUseId: 'command-1',
          content: '/home/user/project',
          toolName: 'Bash',
        ),
      ]);
      await pumpN($.tester);

      expect($(ApprovalBar), findsNothing);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Tool Result'), findsNothing);
      expect(find.text('/home/user/project'), findsOneWidget);
      expect($(ToolResultBubble), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'standalone legacy output matching an outcome label stays visible',
    ($) async {
      await $.pumpWidget(await buildTestCodexSessionScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const ToolResultMessage(toolUseId: 'command-1', content: 'Approved'),
      ]);
      await pumpN($.tester);

      expect(find.text('Approved'), findsOneWidget);
      expect($(ToolResultBubble), findsOneWidget);
      expect($(PermissionRequestBubble), findsNothing);
    },
  );

  patrolWidgetTest(
    'ambiguous legacy output stays visible beside a matching request',
    ($) async {
      await $.pumpWidget(await buildTestCodexSessionScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const PermissionRequestMessage(
          toolUseId: 'command-1',
          toolName: 'Bash',
          input: {'command': 'printf Approved'},
        ),
        const ToolResultMessage(toolUseId: 'command-1', content: 'Approved'),
        const StatusMessage(status: ProcessStatus.running),
      ]);
      await pumpN($.tester);

      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect($(ToolResultBubble), findsOneWidget);
      expect($(PermissionRequestBubble), findsOneWidget);
    },
  );
}
