import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/utils/structured_error_inference.dart';

void main() {
  group('inferStructuredErrorCode', () {
    test('does not classify guidance text as auth error', () {
      final code = inferStructuredErrorCode(
        message:
            '提案:\n'
            '1. `claude` を起動\n'
            '2. 必要なら `claude auth login` を実行\n'
            '3. `/login` の遠隔ログインを主役にする',
      );

      expect(code, isNull);
    });

    test('does not classify normal markdown mentioning BRIDGE_ALLOWED_DIRS', () {
      final code = inferStructuredErrorCode(
        message:
            '[packages/bridge/README.md](/Users/kotahayashi/Workspace/ccpocket/packages/bridge/README.md:30) の Configuration を更新しました。\n\n'
            '追加・補完した内容:\n'
            '- `BRIDGE_ALLOWED_DIRS`\n'
            '- Diff 画像系 `DIFF_IMAGE_AUTO_DISPLAY_KB` / `DIFF_IMAGE_MAX_SIZE_MB`\n'
            '- `BRIDGE_PROMPT_HISTORY_FILE`\n'
            '- `HTTP_PROXY` / `ALL_PROXY` と小文字 proxy variant',
      );

      expect(code, isNull);
    });

    test('classifies legacy path_not_allowed error text', () {
      final code = inferStructuredErrorCode(
        message:
            '⚠ Project path not allowed\n\n'
            '"/foo/bar" is not in the allowed directories.\n\n'
            'Fix: Update BRIDGE_ALLOWED_DIRS on the Bridge server.',
      );

      expect(code, 'path_not_allowed');
    });
  });
}
