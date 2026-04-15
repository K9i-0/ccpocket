import 'package:ccpocket/features/chat_session/widgets/chat_input_with_overlays.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';
import 'package:ccpocket/widgets/bubbles/error_bubble.dart';
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

  group('Error display', () {
    patrolWidgetTest('I1: ErrorMessage displays in chat', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        const ErrorMessage(message: 'Something went wrong'),
      ]);
      await pumpN($.tester);

      expect($('Something went wrong'), findsOneWidget);
    });

    patrolWidgetTest('I2: After error, idle restores input', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        const ErrorMessage(message: 'An error occurred'),
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      await pumpN($.tester);

      expect($(ChatInputWithOverlays), findsOneWidget);
    });
  });

  group('Structured error display with errorCode', () {
    patrolWidgetTest('I3: auth error shows title and hint', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        const ErrorMessage(
          message:
              '⚠ Claude Code authentication required\n\nClaude is not logged in.',
          errorCode: 'auth_login_required',
        ),
      ]);
      await pumpN($.tester);

      expect($('Claude login required'), findsOneWidget);
      expect(
        $('Claude needs to sign in again on the Bridge machine.'),
        findsOneWidget,
      );
      expect($('claude'), findsOneWidget);
      expect($('/login'), findsOneWidget);
    });

    patrolWidgetTest('I4: token expired error shows expired hint', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        const ErrorMessage(
          message:
              '⚠ Claude Code session expired\n\nYour login session has expired.',
          errorCode: 'auth_token_expired',
        ),
      ]);
      await pumpN($.tester);

      expect($('Claude login required'), findsOneWidget);
      expect(
        $('Claude needs to sign in again on the Bridge machine.'),
        findsOneWidget,
      );
    });

    patrolWidgetTest(
      'I4b: assistant auth text is promoted to structured auth error',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await emitAndPump($.tester, bridge, [
          const StatusMessage(status: ProcessStatus.running),
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'auth-assistant',
              role: 'assistant',
              model: 'claude-opus-4-6',
              content: [
                TextContent(
                  text:
                      'Failed to authenticate. API Error: 401\n'
                      '{"type":"error","error":{"type":"authentication_error","message":"OAuth token has expired. Please obtain a new token or refresh your existing token."}}',
                ),
              ],
            ),
          ),
        ]);
        await pumpN($.tester);

        expect($('Claude login required'), findsOneWidget);
        expect(
          $('Claude needs to sign in again on the Bridge machine.'),
          findsOneWidget,
        );
      },
    );

    patrolWidgetTest(
      'I4c: assistant guidance mentioning auth login is not promoted to auth error',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await emitAndPump($.tester, bridge, [
          const StatusMessage(status: ProcessStatus.running),
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'guidance-only',
              role: 'assistant',
              model: 'claude-opus-4-6',
              content: [
                TextContent(
                  text:
                      '方向性は正しいです。必要なら `claude auth login` も使えますが、'
                      '`claude` を開いて `/login` を使う方が分かりやすいです。',
                ),
              ],
            ),
          ),
        ]);
        await pumpN($.tester);

        expect($('Claude login required'), findsNothing);
        expect($('Authentication Error'), findsNothing);
        expect(find.byType(ErrorBubble), findsNothing);
        expect(find.byType(AssistantBubble), findsOneWidget);
      },
    );

    patrolWidgetTest('I5: path_not_allowed error shows path hint', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        const ErrorMessage(
          message:
              '⚠ Project path not allowed\n\n"/foo/bar" is not in the allowed directories.',
          errorCode: 'path_not_allowed',
        ),
      ]);
      await pumpN($.tester);

      expect($('Path Not Allowed'), findsOneWidget);
      expect(
        $('Update BRIDGE_ALLOWED_DIRS on the Bridge server'),
        findsOneWidget,
      );
    });

    patrolWidgetTest(
      'I6: error without errorCode shows plain message (backward compat)',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await emitAndPump($.tester, bridge, [
          const StatusMessage(status: ProcessStatus.running),
          const ErrorMessage(message: 'Generic error from old bridge'),
        ]);
        await pumpN($.tester);

        // Message should be shown
        expect($('Generic error from old bridge'), findsOneWidget);
        // No structured title should appear
        expect($('Authentication Error'), findsNothing);
        expect($('Path Not Allowed'), findsNothing);
      },
    );
  });
}
