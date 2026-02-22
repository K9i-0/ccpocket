import 'package:ccpocket/features/chat_session/widgets/chat_input_with_overlays.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/bubbles/ask_user_question_widget.dart';
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

  // ---- Question data ----

  final singleQuestion = [
    {
      'question': 'Which framework should we use?',
      'header': 'Framework',
      'options': [
        {'label': 'React', 'description': 'Popular UI library'},
        {'label': 'Vue', 'description': 'Progressive framework'},
        {'label': 'Angular', 'description': 'Full-featured framework'},
      ],
      'multiSelect': false,
    },
  ];

  final multiQuestions = [
    {
      'question': 'Which database?',
      'header': 'Database',
      'options': [
        {'label': 'SQLite', 'description': 'Embedded DB'},
        {'label': 'PostgreSQL', 'description': 'Server DB'},
      ],
      'multiSelect': false,
    },
    {
      'question': 'Which features?',
      'header': 'Features',
      'options': [
        {'label': 'Auth', 'description': 'User authentication'},
        {'label': 'Push', 'description': 'Push notifications'},
      ],
      'multiSelect': true,
    },
  ];

  group('AskUserQuestion', () {
    patrolWidgetTest('E1: Single question displays question text and options', (
      $,
    ) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        makeAskQuestionMessage('ask-1', singleQuestion),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      // Question text is visible
      expect(find.text('Which framework should we use?'), findsOneWidget);

      // All 3 option labels are visible
      expect(find.text('React'), findsOneWidget);
      expect(find.text('Vue'), findsOneWidget);
      expect(find.text('Angular'), findsOneWidget);

      // ChatInputWithOverlays is NOT shown
      expect($(ChatInputWithOverlays), findsNothing);
    });

    patrolWidgetTest(
      'E2: Single question - tapping option sends answer immediately',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await emitAndPump($.tester, bridge, [
          makeAskQuestionMessage('ask-2', singleQuestion),
          const StatusMessage(status: ProcessStatus.waitingApproval),
        ]);
        await pumpN($.tester);

        // Tap the first option
        await $.tester.tap(find.text('React'));
        await pumpN($.tester);

        // Verify an 'answer' message was sent with the selected label
        final msg = findSentMessage(bridge, 'answer');
        expect(msg, isNotNull);
        expect(msg!['toolUseId'], 'ask-2');
        expect(msg['result'], 'React');
      },
    );

    patrolWidgetTest('E3: Multiple questions use paged UI with Submit button', (
      $,
    ) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        makeAskQuestionMessage('ask-3', multiQuestions),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      // First question is visible in page 1.
      expect(find.text('Which database?'), findsOneWidget);
      expect(find.text('Which features?'), findsNothing);
      expect(find.text('1/3'), findsOneWidget);

      // Submit button exists but is disabled (shows hint text)
      expect(find.text('Answer all questions to submit'), findsOneWidget);
    });

    patrolWidgetTest('E4: Multi-question first answer advances without sending', (
      $,
    ) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        makeAskQuestionMessage('ask-4', multiQuestions),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      // Answer first question (single select) -> auto advances to question 2.
      await $.tester.tap(find.text('SQLite'));
      await pumpN($.tester);

      // Second question is shown, but answer is not sent yet.
      expect(find.text('Which features?'), findsOneWidget);
      expect(find.text('Answer all questions to submit'), findsOneWidget);
      expect(findSentMessage(bridge, 'answer'), isNull);
    });

    patrolWidgetTest('E5: After answering shows "Answered" text', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        makeAskQuestionMessage('ask-5', singleQuestion),
        const StatusMessage(status: ProcessStatus.waitingApproval),
      ]);
      await pumpN($.tester);

      // Tap option to answer
      await $.tester.tap(find.text('React'));
      await pumpN($.tester);

      // After answering a single question the cubit resets approval state,
      // removing AskUserQuestionWidget from the tree. Verify the answer was
      // sent and the widget is no longer displayed.
      final msg = findSentMessage(bridge, 'answer');
      expect(msg, isNotNull);
      expect(msg!['result'], 'React');
      expect($(AskUserQuestionWidget), findsNothing);
    });

    patrolWidgetTest(
      'E6: permission_request for AskUserQuestion does not show ApprovalBar',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        // Simulate the real message sequence from the bridge:
        // 1. assistant message with AskUserQuestion tool_use
        // 2. permission_request for the same AskUserQuestion
        // 3. status: waitingApproval
        //
        // Bug: the permission_request overwrites ApprovalState.askUser
        // with ApprovalState.permission, showing the wrong dialog.
        await emitAndPump($.tester, bridge, [
          makeAskQuestionMessage('ask-race', singleQuestion),
          const PermissionRequestMessage(
            toolUseId: 'ask-race',
            toolName: 'AskUserQuestion',
            input: {
              'questions': [
                {
                  'question': 'Which framework should we use?',
                  'header': 'Framework',
                  'options': [
                    {'label': 'React', 'description': 'Popular UI library'},
                    {'label': 'Vue', 'description': 'Progressive framework'},
                    {
                      'label': 'Angular',
                      'description': 'Full-featured framework',
                    },
                  ],
                  'multiSelect': false,
                },
              ],
            },
          ),
          const StatusMessage(status: ProcessStatus.waitingApproval),
        ]);
        await pumpN($.tester);

        // AskUserQuestionWidget should be shown, NOT the approval bar
        expect($(AskUserQuestionWidget), findsOneWidget);
        expect(find.text('Which framework should we use?'), findsOneWidget);

        // ChatInputWithOverlays (approval bar container) should NOT be shown
        expect($(ChatInputWithOverlays), findsNothing);
      },
    );
  });
}
