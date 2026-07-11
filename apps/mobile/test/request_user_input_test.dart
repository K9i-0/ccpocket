import 'package:ccpocket/utils/request_user_input.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('requestUserInputQuestions', () {
    test('normalizes valid questions and options', () {
      final questions = requestUserInputQuestions({
        'questions': [
          {
            'question': 'Pick one',
            'header': 'Choice',
            'options': [
              {'label': 'A', 'description': 'First'},
            ],
            'multiSelect': false,
          },
        ],
      });

      expect(questions.single['question'], 'Pick one');
      expect(questions.single['options'], isA<List<Map<String, dynamic>>>());
    });

    test('rejects missing, empty, and non-list questions', () {
      expect(requestUserInputQuestions(const {}), isEmpty);
      expect(requestUserInputQuestions(const {'questions': []}), isEmpty);
      expect(requestUserInputQuestions(const {'questions': 'bad'}), isEmpty);
    });

    test('rejects an entire mixed list when one question is malformed', () {
      expect(
        requestUserInputQuestions({
          'questions': [
            {'question': 'Valid'},
            {'question': 123},
          ],
        }),
        isEmpty,
      );
    });

    test('rejects malformed question fields', () {
      for (final question in [
        <Object?, Object?>{1: 'non-string-key'},
        <String, Object?>{'question': ''},
        <String, Object?>{'question': 'Q', 'header': 1},
        <String, Object?>{'question': 'Q', 'multiSelect': 'false'},
        <String, Object?>{'question': 'Q', 'options': 'bad'},
        <String, Object?>{'question': 'Q', 'options': null},
      ]) {
        expect(
          requestUserInputQuestions({
            'questions': [question],
          }),
          isEmpty,
        );
      }
    });

    test('rejects malformed option fields', () {
      for (final options in [
        <Object?>['not-a-map'],
        <Object?>[
          {1: 'non-string-key'},
        ],
        <Object?>[
          {'label': 1},
        ],
        <Object?>[
          {'label': ''},
        ],
        <Object?>[
          {'label': 'A', 'description': 1},
        ],
      ]) {
        expect(
          requestUserInputQuestions({
            'questions': [
              {'question': 'Q', 'options': options},
            ],
          }),
          isEmpty,
        );
      }
    });
  });

  test('malformed AskUserQuestion permissions are always decline-only', () {
    const request = PermissionRequestMessage(
      toolUseId: 'bad-ask',
      toolName: 'AskUserQuestion',
      input: {
        'questions': ['bad'],
        'availableDecisions': ['accept', 'acceptForSession', 'decline'],
      },
    );

    expect(request.isMalformedAskUserQuestion, isTrue);
    expect(request.canApprove, isFalse);
    expect(request.canApproveForSession, isFalse);
    expect(request.canDecline, isTrue);
  });
}
