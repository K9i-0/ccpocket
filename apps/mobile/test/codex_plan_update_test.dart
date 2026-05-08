import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/utils/codex_plan_update.dart';

void main() {
  group('codexPlanUpdateInputFromText', () {
    test('parses legacy Plan update text', () {
      final input = codexPlanUpdateInputFromText(
        'Plan update: Initial draft\n'
        '1. [completed] Gather requirements\n'
        '2. [in progress] Write tests\n'
        '3. [pending] Implement fix',
      );

      expect(input, {
        'title': 'Plan update',
        'explanation': 'Initial draft',
        'todos': [
          {
            'content': 'Gather requirements',
            'status': 'completed',
            'activeForm': '',
          },
          {'content': 'Write tests', 'status': 'in_progress', 'activeForm': ''},
          {'content': 'Implement fix', 'status': 'pending', 'activeForm': ''},
        ],
      });
    });
  });

  group('codexPlanUpdateTextFromInput', () {
    test('formats structured UpdatePlan input', () {
      final text = codexPlanUpdateTextFromInput({
        'explanation': 'Initial draft',
        'todos': [
          {'content': 'Gather requirements', 'status': 'completed'},
          {'content': 'Write tests', 'status': 'in_progress'},
        ],
      });

      expect(
        text,
        'Plan update: Initial draft\n'
        '1. [completed] Gather requirements\n'
        '2. [in progress] Write tests',
      );
    });
  });
}
