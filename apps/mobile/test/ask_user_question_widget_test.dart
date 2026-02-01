import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/widgets/bubbles/ask_user_question_widget.dart';
import 'package:ccpocket/theme/app_theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('AskUserQuestionWidget - single question', () {
    testWidgets('shows question text and options', (tester) async {
      await tester.pumpWidget(_wrap(AskUserQuestionWidget(
        toolUseId: 'test-1',
        input: {
          'questions': [
            {
              'question': 'Which framework?',
              'header': 'Framework',
              'options': [
                {'label': 'Flutter', 'description': 'Cross-platform'},
                {'label': 'React Native', 'description': 'JavaScript based'},
              ],
              'multiSelect': false,
            }
          ]
        },
        onAnswer: (_, __) {},
      )));

      expect(find.text('Claude is asking'), findsOneWidget);
      expect(find.text('Which framework?'), findsOneWidget);
      expect(find.text('Framework'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Cross-platform'), findsOneWidget);
      expect(find.text('React Native'), findsOneWidget);
      expect(find.text('JavaScript based'), findsOneWidget);
    });

    testWidgets('tapping option sends answer immediately for single question',
        (tester) async {
      String? answeredId;
      String? answeredResult;

      await tester.pumpWidget(_wrap(AskUserQuestionWidget(
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
            }
          ]
        },
        onAnswer: (id, result) {
          answeredId = id;
          answeredResult = result;
        },
      )));

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

      await tester.pumpWidget(_wrap(AskUserQuestionWidget(
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
            }
          ]
        },
        onAnswer: (_, result) {
          answeredResult = result;
        },
      )));

      // Type custom text and tap Send
      await tester.enterText(
          find.byType(TextField), 'Charlie');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(answeredResult, 'Charlie');
      expect(find.text('Answered'), findsOneWidget);
    });
  });

  group('AskUserQuestionWidget - multiple questions', () {
    testWidgets('shows all questions and submit button', (tester) async {
      await tester.pumpWidget(_wrap(AskUserQuestionWidget(
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
          ]
        },
        onAnswer: (_, __) {},
      )));

      expect(find.text('Color?'), findsOneWidget);
      expect(find.text('Size?'), findsOneWidget);
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
      // Submit button should be present but disabled
      expect(find.text('Answer all questions to submit'), findsOneWidget);
    });

    testWidgets('tapping option does not send immediately for multi-question',
        (tester) async {
      bool answered = false;

      await tester.pumpWidget(_wrap(AskUserQuestionWidget(
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
          ]
        },
        onAnswer: (_, __) => answered = true,
      )));

      // Tap one option — should NOT send
      await tester.tap(find.text('Red'));
      await tester.pumpAndSettle();

      expect(answered, false);
      // Still shows the submit prompt
      expect(find.text('Answer all questions to submit'), findsOneWidget);
    });

    testWidgets('answering all questions enables submit and sends JSON',
        (tester) async {
      String? answeredResult;

      await tester.pumpWidget(_wrap(AskUserQuestionWidget(
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
          ]
        },
        onAnswer: (_, result) => answeredResult = result,
      )));

      // Answer both questions
      await tester.tap(find.text('Red'));
      await tester.pumpAndSettle();

      // Scroll to make "Large" visible, then tap
      await tester.ensureVisible(find.text('Large'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();

      // Submit button should now say "Submit All Answers"
      await tester.ensureVisible(find.text('Submit All Answers'));
      await tester.pumpAndSettle();
      expect(find.text('Submit All Answers'), findsOneWidget);

      // Tap submit
      await tester.tap(find.text('Submit All Answers'));
      await tester.pumpAndSettle();

      // Verify JSON answer
      expect(answeredResult, isNotNull);
      final decoded = jsonDecode(answeredResult!) as Map<String, dynamic>;
      expect(decoded['answers'], isA<Map>());
      final answers = decoded['answers'] as Map<String, dynamic>;
      expect(answers['Color?'], 'Red');
      expect(answers['Size?'], 'Large');

      // Should show answered state
      expect(find.text('Answered'), findsOneWidget);
    });
  });

  group('AskUserQuestionWidget - multiSelect', () {
    testWidgets('multi-select allows toggling multiple options', (tester) async {
      String? answeredResult;

      await tester.pumpWidget(_wrap(AskUserQuestionWidget(
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
          ]
        },
        onAnswer: (_, result) => answeredResult = result,
      )));

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
      expect(find.byIcon(Icons.check_box), findsNWidgets(2)); // Auth + API selected
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget); // DB unselected
    });
  });

  group('AskUserQuestionWidget - answered state', () {
    testWidgets('shows answered state after answering', (tester) async {
      await tester.pumpWidget(_wrap(AskUserQuestionWidget(
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
            }
          ]
        },
        onAnswer: (_, __) {},
      )));

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
