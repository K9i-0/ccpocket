import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/utils/request_user_input.dart';

void main() {
  group('requestUserInputQuestions', () {
    test('returns an empty list when questions is missing or not a list', () {
      expect(requestUserInputQuestions(const {}), isEmpty);
      expect(
        requestUserInputQuestions(const {'questions': 'not-a-list'}),
        isEmpty,
      );
    });

    test('keeps only map questions with string keys', () {
      final questions = requestUserInputQuestions({
        'questions': [
          'bad',
          {1: 'bad-key'},
          {'question': 'Pick one'},
        ],
      });

      expect(questions, [
        {'question': 'Pick one'},
      ]);
      expect(
        firstRequestUserInputQuestion({
          'questions': ['bad'],
        }),
        isNull,
      );
      expect(
        hasRequestUserInputQuestions({
          'questions': ['bad'],
        }),
        isFalse,
      );
    });
  });
}
