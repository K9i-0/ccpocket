import 'package:ccpocket/utils/ordered_list_editing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('renumberOrderedListsInRange', () {
    TextEditingValue renumber(
      String text, {
      int startOffset = 0,
      int? endOffset,
      TextSelection? selection,
    }) => renumberOrderedListsInRange(
      TextEditingValue(
        text: text,
        selection: selection ?? TextSelection.collapsed(offset: text.length),
      ),
      startOffset: startOffset,
      endOffset: endOffset ?? text.length,
    );

    test('restarts an indented sequence and continues the parent sequence', () {
      const input = '1. A\n2. B\n  3. B-1\n  4. B-2\n5. C';

      final result = renumber(input);

      expect(result.text, '1. A\n2. B\n  1. B-1\n  2. B-2\n3. C');
    });

    test('counts each nested sibling sequence independently', () {
      const input =
          '7. A\n'
          '  8. A-1\n'
          '    9. A-1-a\n'
          '    10. A-1-b\n'
          '  11. A-2\n'
          '12. B\n'
          '  13. B-1';

      final result = renumber(input);

      expect(
        result.text,
        '1. A\n'
        '  1. A-1\n'
        '    1. A-1-a\n'
        '    2. A-1-b\n'
        '  2. A-2\n'
        '2. B\n'
        '  1. B-1',
      );
    });

    test('nested bullets do not advance the parent ordered sequence', () {
      const input = '4. A\n  - note\n  - note\n9. B';

      final result = renumber(input);

      expect(result.text, '1. A\n  - note\n  - note\n2. B');
    });

    test('a same-level bullet starts a new ordered sequence', () {
      const input = '4. A\n- separate\n9. B';

      final result = renumber(input);

      expect(result.text, '1. A\n- separate\n1. B');
    });

    test('normal text separates list blocks', () {
      const input = '8. untouched\n\nplain text\n\n4. changed\n8. changed';
      final changedStart = input.indexOf('4. changed');

      final result = renumber(
        input,
        startOffset: changedStart,
        endOffset: input.length,
      );

      expect(
        result.text,
        '8. untouched\n\nplain text\n\n1. changed\n2. changed',
      );
    });

    test('indented continuation text stays inside its parent list', () {
      const input = '4. A\n   continuation\n9. B';

      final result = renumber(input);

      expect(result.text, '1. A\n   continuation\n2. B');
    });

    test('does not renumber list-looking lines inside fenced code', () {
      const input = '```text\n9. example\n10. example\n```';

      final result = renumber(input);

      expect(result.text, input);
    });

    test('four-space fence-like content does not close a code fence', () {
      const input = '```text\n    ```\n9. example\n```';

      final result = renumber(input);

      expect(result.text, input);
    });

    test(
      'uses the pre-indent fence positions when indentation reaches four',
      () {
        const original = '```text\n9. example\n```';
        const indented = '    ```text\n    9. example\n    ```';
        final value = TextEditingValue(
          text: indented,
          selection: const TextSelection.collapsed(offset: indented.length),
        );

        final result = renumberOrderedListsInRange(
          value,
          startOffset: 0,
          endOffset: indented.length,
          fenceReferenceText: original,
        );

        expect(result.text, indented);
      },
    );

    test('also protects a fence that becomes valid after dedenting', () {
      const original = '    ```text\n    9. example\n    ```';
      const dedented = '  ```text\n  9. example\n  ```';
      final value = TextEditingValue(
        text: dedented,
        selection: const TextSelection.collapsed(offset: dedented.length),
      );

      final result = renumberOrderedListsInRange(
        value,
        startOffset: 0,
        endOffset: dedented.length,
        fenceReferenceText: original,
      );

      expect(result.text, dedented);
    });

    test('preserves cursor position when marker digit counts shrink', () {
      const input = '9. A\n10. B\n11. C';
      final selection = TextSelection.collapsed(offset: input.length);

      final result = renumber(input, selection: selection);

      expect(result.text, '1. A\n2. B\n3. C');
      expect(
        result.selection,
        TextSelection.collapsed(offset: result.text.length),
      );
    });

    test('preserves the ordered-list delimiter', () {
      const input = '8) A\n9) B';

      final result = renumber(input);

      expect(result.text, '1) A\n2) B');
    });
  });

  group('completeListAfterNewline', () {
    TextEditingValue complete(String text) {
      final value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      return completeListAfterNewline(value)!;
    }

    test('continues a non-empty ordered item at the same indentation', () {
      final result = complete('1. A\n  3. child\n');

      expect(result.text, '1. A\n  3. child\n  4. ');
    });

    test('outdents an empty nested item and continues its parent', () {
      final result = complete('1. A\n  1. child\n  2. \n');

      expect(result.text, '1. A\n  1. child\n2. ');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('finds a parent across indented continuation text', () {
      final result = complete('1. parent\n   continuation\n  1. \n');

      expect(result.text, '1. parent\n   continuation\n2. ');
    });

    test('rejects a parent deeper than intervening continuation text', () {
      final result = complete(
        '1. top\n  1. nested parent\n continuation\n    1. \n',
      );

      expect(result.text, '1. top\n  1. nested parent\n continuation\n2. ');
    });

    test('outdents one level at a time in a deeply nested list', () {
      final result = complete('1. A\n  1. child\n    1. grandchild\n    2. \n');

      expect(result.text, '1. A\n  1. child\n    1. grandchild\n  2. ');
    });

    test('exits an empty top-level ordered list', () {
      final result = complete('1. A\n2. \n');

      expect(result.text, '1. A\n');
    });

    test('continues the parent bullet when outdenting', () {
      final result = complete('- parent\n  1. child\n  2. \n');

      expect(result.text, '- parent\n  1. child\n- ');
    });

    test('does not complete list-looking lines inside fenced code', () {
      const text = '```text\n1. example\n';
      final value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );

      expect(completeListAfterNewline(value), isNull);
    });
  });
}
