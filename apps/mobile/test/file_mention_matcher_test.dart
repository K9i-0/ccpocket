import 'package:ccpocket/utils/file_mention_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scoreFileMentionPath', () {
    test('matches exact basename before broader matches', () {
      expect(scoreFileMentionPath('apps/mobile/lib/main.dart', 'main'), 0);
      expect(
        scoreFileMentionPath('apps/mobile/lib/main.dart', 'mai'),
        lessThan(scoreFileMentionPath('apps/mobile/lib/domain.dart', 'mai')),
      );
    });

    test('matches compact fuzzy queries across path segments', () {
      expect(
        scoreFileMentionPath('docs/design/', 'dode'),
        greaterThanOrEqualTo(5),
      );
      expect(scoreFileMentionPath('docs/design/', 'dode'), isNot(-1));
      expect(scoreFileMentionPath('docs/design/api.md', 'dode'), isNot(-1));
    });

    test('keeps direct path contains ahead of fuzzy matches', () {
      final direct = scoreFileMentionPath('docs/design/', 'docs/des');
      final fuzzy = scoreFileMentionPath('docs/design/', 'dode');

      expect(direct, lessThan(fuzzy));
    });

    test('does not fuzzy match single-character queries', () {
      expect(scoreFileMentionPath('docs/design/', 'x'), -1);
    });
  });
}
