import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/widgets/bubbles/ask_user_question_widget.dart';
import 'package:ccpocket/theme/app_theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

void main() {
  group('AskUserQuestionWidget - single question', () {
    testWidgets('shows question text and options', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AskUserQuestionWidget(
            toolUseId: 'test-1',
            input: {
              'questions': [
                {
                  'question': 'Which framework?',
                  'header': 'Framework',
                  'options': [
                    {'label': 'Flutter', 'description': 'Cross-platform'},
                    {
                      'label': 'React Native',
                      'description': 'JavaScript based',
                    },
                  ],
                  'multiSelect': false,
                },
              ],
            },
            onAnswer: (_, _) {},
          ),
        ),
      );

      expect(find.text('Claude is asking'), findsOneWidget);
      expect(find.text('Which framework?'), findsOneWidget);
      expect(find.text('Framework'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Cross-platform'), findsOneWidget);
      expect(find.text('React Native'), findsOneWidget);
      expect(find.text('JavaScript based'), findsOneWidget);
    });

    testWidgets('tapping option sends answer immediately for single question', (
      tester,
    ) async {
      String? answeredId;
      String? answeredResult;

      await tester.pumpWidget(
        _wrap(
          AskUserQuestionWidget(
            toolUseId: 'test-2',
            input: {
              'questions': [
                {
                  'question': 'Pick one',
                  'header': 'Choice',
                  'options': [
                    {'label': 'A', 'description': 'Option A'},
                    {'label': 'B', 'description': 'Option B'},
                  ],
                  'multiSelect': false,
                },
              ],
            },
            onAnswer: (id, result) {
              answeredId = id;
              answeredResult = result;
            },
          ),
        ),
      );

      // Tap option A
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      expect(answeredId, 'test-2');
      expect(answeredResult, 'A');
      // Should show "Answered" state
      expect(find.text('Answered'), findsOneWidget);
    });

    testWidgets('free text input sends answer', (tester) async {
      String? answeredResult;

      await tester.pumpWidget(
        _wrap(
          AskUserQuestionWidget(
            toolUseId: 'test-3',
            input: {
              'questions': [
                {
                  'question': 'What is your name?',
                  'header': 'Name',
                  'options': [
                    {'label': 'Alice', 'description': ''},
                    {'label': 'Bob', 'description': ''},
                  ],
                  'multiSelect': false,
                },
              ],
            },
            onAnswer: (_, result) {
              answeredResult = result;
            },
          ),
        ),
      );

      // Type custom text and tap Send
      await tester.enterText(find.byType(TextField), 'Charlie');
      await tester.pumpAndSettle();
      final sendButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send'),
      );
      expect(sendButton.onPressed, isNotNull);
      sendButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(answeredResult, 'Charlie');
      expect(find.text('Answered'), findsOneWidget);
    });

    testWidgets('keyboard done closes keyboard without sending', (
      tester,
    ) async {
      String? answeredResult;

      await tester.pumpWidget(
        _wrap(
          AskUserQuestionWidget(
            toolUseId: 'test-3b',
            input: {
              'questions': [
                {
                  'question': 'What is your name?',
                  'header': 'Name',
                  'options': [
                    {'label': 'Alice', 'description': ''},
                    {'label': 'Bob', 'description': ''},
                  ],
                  'multiSelect': false,
                },
              ],
            },
            onAnswer: (_, result) {
              answeredResult = result;
            },
          ),
        ),
      );

      final input = find.byType(TextField);
      await tester.tap(input);
      await tester.enterText(input, 'Charlie');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(answeredResult, isNull);
      expect(find.text('Answered'), findsNothing);
    });

    testWidgets('send button is disabled until text is entered', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AskUserQuestionWidget(
            toolUseId: 'test-3c',
            input: {
              'questions': [
                {
                  'question': 'What is your name?',
                  'header': 'Name',
                  'options': [
                    {'label': 'Alice', 'description': ''},
                    {'label': 'Bob', 'description': ''},
                  ],
                  'multiSelect': false,
                },
              ],
            },
            onAnswer: (toolUseId, result) {},
          ),
        ),
      );

      FilledButton sendButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send'),
      );

      expect(sendButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'x');
      await tester.pumpAndSettle();
      expect(sendButton().onPressed, isNotNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      expect(sendButton().onPressed, isNull);
    });
  });

  group('AskUserQuestionWidget - multiple questions', () {
    testWidgets('uses page view and shows submit button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AskUserQuestionWidget(
            toolUseId: 'test-4',
            input: {
              'questions': [
                {
                  'question': 'Color?',
                  'header': 'Color',
                  'options': [
                    {'label': 'Red', 'description': ''},
                    {'label': 'Blue', 'description': ''},
                  ],
                  'multiSelect': false,
                },
                {
                  'question': 'Size?',
                  'header': 'Size',
                  'options': [
                    {'label': 'Small', 'description': ''},
                    {'label': 'Large', 'description': ''},
                  ],
                  'multiSelect': false,
                },
              ],
            },
            onAnswer: (_, _) {},
          ),
        ),
      );

      expect(find.text('Color?'), findsOneWidget);
      expect(find.text('Size?'), findsNothing);
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('Small'), findsNothing);
      expect(find.text('Large'), findsNothing);
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('initial multi-question state does not send immediately', (
      tester,
    ) async {
      bool answered = false;

      await tester.pumpWidget(
        _wrap(
          AskUserQuestionWidget(
            toolUseId: 'test-5',
            input: {
              'questions': [
                {
                  'question': 'Color?',
                  'header': 'Color',
                  'options': [
                    {'label': 'Red', 'description': ''},
                    {'label': 'Blue', 'description': ''},
                  ],
                  'multiSelect': false,
                },
                {
                  'question': 'Size?',
                  'header': 'Size',
                  'options': [
                    {'label': 'Small', 'description': ''},
                    {'label': 'Large', 'description': ''},
                  ],
                  'multiSelect': false,
                },
              ],
            },
            onAnswer: (_, _) => answered = true,
          ),
        ),
      );

      expect(answered, false);
    });

    testWidgets('custom answer in multi-question uses Next button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AskUserQuestionWidget(
            toolUseId: 'test-6',
            input: {
              'questions': [
                {
                  'question': 'Color?',
                  'header': 'Color',
                  'options': [
                    {'label': 'Red', 'description': ''},
                    {'label': 'Blue', 'description': ''},
                  ],
                  'multiSelect': false,
                },
                {
                  'question': 'Size?',
                  'header': 'Size',
                  'options': [
                    {'label': 'Small', 'description': ''},
                    {'label': 'Large', 'description': ''},
                  ],
                  'multiSelect': false,
                },
              ],
            },
            onAnswer: (toolUseId, result) {},
          ),
        ),
      );

      final otherAnswerButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Other answer...'),
      );
      otherAnswerButton.onPressed!.call();
      await tester.pumpAndSettle();

      FilledButton nextButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );

      expect(nextButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Green');
      await tester.pumpAndSettle();
      expect(nextButton().onPressed, isNotNull);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Size?'), findsOneWidget);
      expect(find.text('Color?'), findsNothing);
    });
  });

  group('AskUserQuestionWidget - multiSelect', () {
    testWidgets('multi-select allows toggling multiple options', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AskUserQuestionWidget(
            toolUseId: 'test-7',
            input: {
              'questions': [
                {
                  'question': 'Pick features',
                  'header': 'Features',
                  'options': [
                    {'label': 'Auth', 'description': 'Authentication'},
                    {'label': 'DB', 'description': 'Database'},
                    {'label': 'API', 'description': 'REST API'},
                  ],
                  'multiSelect': true,
                },
              ],
            },
            onAnswer: (_, _) {},
          ),
        ),
      );

      // Select Auth and API
      await tester.tap(find.text('Auth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('API'));
      await tester.pumpAndSettle();

      // Since it's single question, but multiSelect means we need to check
      // that it doesn't auto-send (multiSelect options stay selected)
      // For single question with multiSelect, we still use free text send
      // Actually looking at the code: _isSingleQuestion is true but multiSelect
      // doesn't auto-send for single question either - it stores in _multiAnswers
      // The user must use the free text or Submit All Answers
      // Wait - actually checking the code again: _selectOption for single question
      // only auto-sends for non-multi. Multi stores in _multiAnswers.
      // And _isSingleQuestion hides the Submit button.
      // So user has to type in text field to send. Let's verify checkbox state.
      expect(
        find.byIcon(Icons.check_box),
        findsNWidgets(2),
      ); // Auth + API selected
      expect(
        find.byIcon(Icons.check_box_outline_blank),
        findsOneWidget,
      ); // DB unselected
    });
  });

  group('AskUserQuestionWidget - answered state', () {
    testWidgets('shows answered state after answering', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AskUserQuestionWidget(
            toolUseId: 'test-8',
            input: {
              'questions': [
                {
                  'question': 'Yes or No?',
                  'header': 'Confirm',
                  'options': [
                    {'label': 'Yes', 'description': ''},
                    {'label': 'No', 'description': ''},
                  ],
                  'multiSelect': false,
                },
              ],
            },
            onAnswer: (_, _) {},
          ),
        ),
      );

      // Before answering
      expect(find.text('Claude is asking'), findsOneWidget);
      expect(find.text('Answered'), findsNothing);

      // Tap Yes
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      // After answering
      expect(find.text('Answered'), findsOneWidget);
      expect(find.text('Claude is asking'), findsNothing);
    });
  });
}
