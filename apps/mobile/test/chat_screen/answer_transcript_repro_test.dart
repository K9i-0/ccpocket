import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/widgets/chat_message_list.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/widgets/bubbles/question_answer_transcript_bubble.dart';
import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'helpers/chat_test_helpers.dart';

const _questionInput = {
  'questions': [
    {
      'id': 'garden_sound',
      'question': 'Which sound should the garden use?',
      'header': 'Garden sound',
      'options': [
        {'label': 'Forest birdsong', 'description': 'Morning birds'},
        {'label': 'Rainfall', 'description': 'Soft rain'},
      ],
      'multiSelect': false,
    },
  ],
};

void _expectQuestionAnswerDetails(WidgetTester tester) {
  final bubble = find.byType(QuestionAnswerTranscriptBubble);
  expect(bubble, findsOneWidget);
  expect(
    find.descendant(
      of: bubble,
      matching: find.text('Which sound should the garden use?'),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(of: bubble, matching: find.text('Garden sound')),
    findsOneWidget,
  );
  for (final label in [
    'Forest birdsong',
    'Morning birds',
    'Rainfall',
    'Soft rain',
  ]) {
    expect(
      find.descendant(of: bubble, matching: find.text(label)),
      findsOneWidget,
    );
  }
  expect(
    find.descendant(
      of: bubble,
      matching: find.byKey(
        const ValueKey('question_answer_option_Forest birdsong'),
      ),
    ),
    findsOneWidget,
  );
}

void main() {
  patrolWidgetTest('Claude chat retains the selected question answer', (
    $,
  ) async {
    final bridge = MockBridgeService();
    addTearDown(bridge.dispose);
    await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
    await pumpN($.tester);

    await emitAndPump($.tester, bridge, [
      makeAssistantMessage(
        'before-question',
        'I need one detail before I continue.',
        toolUses: const [
          ToolUseContent(
            id: 'ask-1',
            name: 'AskUserQuestion',
            input: _questionInput,
          ),
        ],
      ),
      const PermissionRequestMessage(
        toolUseId: 'ask-1',
        toolName: 'AskUserQuestion',
        input: _questionInput,
      ),
      const StatusMessage(status: ProcessStatus.waitingApproval),
    ]);

    expect(find.text('Which sound should the garden use?'), findsOneWidget);
    await $.tester.tap(find.text('Forest birdsong'));
    await pumpN($.tester);
    expect(
      bridge.sentMessages.any((message) {
        final json = decodeClientMessage(message);
        return json['type'] == 'answer' && json['toolUseId'] == 'ask-1';
      }),
      isTrue,
    );
    _expectQuestionAnswerDetails($.tester);
    expect(find.byType(QuestionAnswerTranscriptBubble), findsOneWidget);

    await emitAndPump($.tester, bridge, [
      const ToolResultMessage(
        toolUseId: 'ask-1',
        content: 'Forest birdsong',
        permissionOutcome: PermissionOutcome.answered,
      ),
      const AssistantServerMessage(
        message: AssistantMessage(
          id: 'after-answer',
          role: 'assistant',
          model: 'claude-sonnet',
          content: [TextContent(text: 'I will add birdsong to the garden.')],
        ),
      ),
    ]);

    _expectQuestionAnswerDetails($.tester);
    expect(
      find.text('I will add birdsong to the garden.', findRichText: true),
      findsOneWidget,
    );

    final settings = BlocProvider.of<SettingsCubit>(
      $.tester.element(find.byType(ChatMessageList).first),
    );
    settings.setLiteMode(true);
    await pumpN($.tester);
    expect(find.text('AskUserQuestion'), findsNothing);
    _expectQuestionAnswerDetails($.tester);

    await emitAndPump($.tester, bridge, [
      HistoryMessage(
        messages: [
          makeAssistantMessage(
            'before-question',
            'I need one detail before I continue.',
            toolUses: const [
              ToolUseContent(
                id: 'ask-1',
                name: 'AskUserQuestion',
                input: _questionInput,
              ),
            ],
          ),
          const PermissionRequestMessage(
            toolUseId: 'ask-1',
            toolName: 'AskUserQuestion',
            input: _questionInput,
          ),
          const ToolResultMessage(
            toolUseId: 'ask-1',
            content: 'Forest birdsong',
            permissionOutcome: PermissionOutcome.answered,
          ),
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'after-answer',
              role: 'assistant',
              model: 'claude-sonnet',
              content: [
                TextContent(text: 'I will add birdsong to the garden.'),
              ],
            ),
          ),
          const StatusMessage(status: ProcessStatus.idle),
        ],
      ),
    ]);
    final chatCubit = BlocProvider.of<ChatSessionCubit>(
      $.tester.element(find.byType(ChatMessageList).first),
    );
    expect(
      chatCubit.state.entries.whereType<QuestionAnswerChatEntry>(),
      hasLength(1),
    );
    _expectQuestionAnswerDetails($.tester);
  });

  patrolWidgetTest('Codex chat retains the selected question answer', (
    $,
  ) async {
    final bridge = MockBridgeService();
    addTearDown(bridge.dispose);
    await $.pumpWidget(await buildTestCodexSessionScreen(bridge: bridge));
    await pumpN($.tester);

    await emitAndPump($.tester, bridge, [
      makeAssistantMessage('before-question', 'I need one detail first.'),
      const PermissionRequestMessage(
        toolUseId: 'ask-1',
        toolName: 'AskUserQuestion',
        input: _questionInput,
      ),
      const StatusMessage(status: ProcessStatus.waitingApproval),
    ]);
    await $.tester.tap(find.text('Forest birdsong'));
    await pumpN($.tester);
    _expectQuestionAnswerDetails($.tester);
    expect(find.byType(QuestionAnswerTranscriptBubble), findsOneWidget);
    await emitAndPump($.tester, bridge, [
      const ToolResultMessage(
        toolUseId: 'ask-1',
        content: 'Forest birdsong',
        permissionOutcome: PermissionOutcome.answered,
      ),
      const AssistantServerMessage(
        message: AssistantMessage(
          id: 'after-answer',
          role: 'assistant',
          model: 'codex',
          content: [TextContent(text: 'I will add birdsong to the garden.')],
        ),
      ),
    ]);

    _expectQuestionAnswerDetails($.tester);
    expect(find.byType(QuestionAnswerTranscriptBubble), findsOneWidget);
    expect(
      find.text('I will add birdsong to the garden.', findRichText: true),
      findsOneWidget,
    );

    final settings = BlocProvider.of<SettingsCubit>(
      $.tester.element(find.byType(ChatMessageList).first),
    );
    settings.setLiteMode(true);
    await pumpN($.tester);
    expect(find.text('AskUserQuestion'), findsNothing);
    _expectQuestionAnswerDetails($.tester);
  });

  patrolWidgetTest('restores question answers from Codex history', ($) async {
    final bridge = MockBridgeService();
    addTearDown(bridge.dispose);
    await $.pumpWidget(await buildTestCodexSessionScreen(bridge: bridge));
    await pumpN($.tester);

    await emitAndPump($.tester, bridge, [
      HistoryMessage(
        messages: [
          makeAssistantMessage('before-question', 'I need one detail first.'),
          const PermissionRequestMessage(
            toolUseId: 'ask-1',
            toolName: 'AskUserQuestion',
            input: _questionInput,
          ),
          const ToolResultMessage(
            toolUseId: 'ask-1',
            content: 'Forest birdsong',
            permissionOutcome: PermissionOutcome.answered,
          ),
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'after-answer',
              role: 'assistant',
              model: 'codex',
              content: [
                TextContent(text: 'I will add birdsong to the garden.'),
              ],
            ),
          ),
          const StatusMessage(status: ProcessStatus.idle),
        ],
      ),
    ]);

    _expectQuestionAnswerDetails($.tester);
    expect(
      find.text('I will add birdsong to the garden.', findRichText: true),
      findsOneWidget,
    );
  });
}
