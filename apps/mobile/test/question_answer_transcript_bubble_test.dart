import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/question_answer_transcript_bubble.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows question options, descriptions and the selected choice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(
          body: QuestionAnswerTranscriptBubble(
            transcript: QuestionAnswerTranscript(
              plainText: 'Question: Which sound?\nAnswer: Forest birdsong',
              questions: [
                AnsweredQuestion(
                  header: 'Garden sound',
                  question: 'Which sound should the garden use?',
                  options: [
                    AnsweredQuestionOption(
                      label: 'Forest birdsong',
                      description: 'Morning birds',
                      selected: true,
                    ),
                    AnsweredQuestionOption(
                      label: 'Rainfall',
                      description: 'Soft rain',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Garden sound'), findsOneWidget);
    expect(find.text('Question'), findsOneWidget);
    expect(find.text('AskUserQuestion'), findsNothing);
    expect(find.text('Which sound should the garden use?'), findsOneWidget);
    expect(find.text('Forest birdsong'), findsOneWidget);
    expect(find.text('Morning birds'), findsOneWidget);
    expect(find.text('Rainfall'), findsOneWidget);
    expect(find.text('Soft rain'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('question_answer_option_Forest birdsong')),
      findsOneWidget,
    );
  });

  testWidgets('shows custom text as the Other answer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(
          body: QuestionAnswerTranscriptBubble(
            transcript: QuestionAnswerTranscript(
              plainText: 'Question: Which sound?\nAnswer: A hidden cave',
              questions: [
                AnsweredQuestion(
                  question: 'Which sound?',
                  options: [AnsweredQuestionOption(label: 'Forest birdsong')],
                  freeTextAnswer: 'A hidden cave',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Other answer...'), findsOneWidget);
    expect(find.text('A hidden cave'), findsOneWidget);
  });

  testWidgets('labels secret answers as hidden without showing their value', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(
          body: QuestionAnswerTranscriptBubble(
            transcript: QuestionAnswerTranscript(
              plainText: 'Question: Access token?\nAnswer: [hidden]',
              questions: [
                AnsweredQuestion(question: 'Access token?', answerHidden: true),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Question'), findsOneWidget);
    expect(find.text('Hidden for privacy'), findsOneWidget);
    expect(find.text('••••'), findsOneWidget);
    expect(find.text('top-secret-value'), findsNothing);
  });
}
