import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/utils/command_completion_matcher.dart';

void main() {
  group('commandCompletionScore', () {
    test('keeps matching scoped by trigger', () {
      expect(commandCompletionScore(r'$skills', r'$skills'), 0);
      expect(commandCompletionScore('@skills', r'$skills'), -1);
      expect(commandCompletionScore('/skills', r'$skills'), -1);
    });

    test('preserves original order for trigger-only query', () {
      final ranked = rankCommandCompletions(
        ['/review', '/compact', '/context'],
        '/',
        (command) => command,
      );

      expect(ranked, ['/review', '/compact', '/context']);
    });

    test('matches namespaced command segments', () {
      expect(
        commandCompletionScore(r'$superpowers:writing-skills', r'$skills'),
        isNonNegative,
      );
      expect(
        commandCompletionScore(r'$superpowers:writing-plans', r'$plans'),
        isNonNegative,
      );
    });

    test('matches compact subsequences for fuzzy discovery', () {
      expect(
        commandCompletionScore(r'$superpowers:writing-skills', r'$suwr'),
        isNonNegative,
      );
    });

    test('ranks prefix and segment matches before fuzzy matches', () {
      final ranked = rankCommandCompletions(
        [
          r'$superpowers:writing-skills',
          r'$skills',
          r'$superpowers',
          r'@superpowers:writing-skills',
        ],
        r'$skills',
        (command) => command,
      );

      expect(ranked, [r'$skills', r'$superpowers:writing-skills']);
    });

    test('ranks tighter fuzzy matches ahead of looser fuzzy matches', () {
      final ranked = rankCommandCompletions(
        [r'$sample:utility-workflows', r'$superpowers:writing-skills'],
        r'$suwr',
        (command) => command,
      );

      expect(ranked.first, r'$superpowers:writing-skills');
    });
  });
}
