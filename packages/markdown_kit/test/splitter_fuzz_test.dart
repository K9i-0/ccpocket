// The splitter decides where a document may be cut into chunks that are
// parsed (and cached) on their own. Its one obligation is that this changes
// nothing: the blocks must be those of parsing the document in one piece.
//
// The CommonMark examples check that in corpus_invariants_test.dart. This
// file checks it on random stacks of lines chosen to be awkward for the
// splitter: list items with every marker and indentation, rules that look
// like list items, fences, quotes and raw HTML.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

const _lines = [
  '- a',
  '* b',
  '+ c',
  '1. d',
  '2. e',
  '1) f',
  '3) g',
  '- [ ] h',
  '- [x] i',
  '  - n',
  '   1. m',
  '  text',
  '    code',
  ' - one',
  '   * three',
  '',
  '',
  '',
  'para',
  'more text',
  '# head',
  '> quote',
  '> - q',
  '---',
  '* * *',
  '-',
  '1.',
  '10. ten',
  '  2) x',
  '```',
  '  ```',
  '<b>x</b>',
  '_ _ _',
  ' ---',
  '  > q',
  r'\[',
  r'\]',
  '<details>',
  '</details>',
  '- - -',
  '  - - -',
  '+',
  '   -',
  '  1)',
  'a | b',
  '| a | b |',
  '|---|---|',
  '<div>',
  'Setext',
  '===',
];

void main() {
  test('random documents parse the same chunk by chunk and in one piece', () {
    // A reference definition in front turns the splitter off for the whole
    // document, and makes no block of its own.
    const unsplit = '[zz-unsplit]: /unsplit\n\n';
    final random = Random(20261127);
    final different = <String>{};
    var split = 0;

    for (var n = 0; n < 12000; n++) {
      final count = 2 + random.nextInt(12);
      final source =
          '${[for (var i = 0; i < count; i++) _lines[random.nextInt(_lines.length)]].join('\n')}\n';
      final chunks = splitMarkdownBlocks(source);
      expect(chunks.join(), source);
      if (chunks.length < 2) continue;
      split++;

      final chunked = GfmMarkdownParser().parse(source).blocks;
      final whole = GfmMarkdownParser().parse('$unsplit$source').blocks;
      var same = chunked.length == whole.length;
      for (var i = 0; same && i < chunked.length; i++) {
        same = chunked[i] == whole[i];
      }
      if (!same) different.add(source);
    }

    expect(split, greaterThan(1000));
    // What is left are two readings of a fence indented under a list item
    // that the splitter gets wrong: a fence line outside the item is taken to
    // close the fence inside it, and a fence after an empty item is taken to
    // belong to that item. Anything new in this set is a regression worth a
    // look.
    expect(different, _known);
  });
}

const _known = <String>{
  '+ c\n* b\n===\n  ```\n```\n   -\n\n> - q\n',
  '2. e\n+\n\n  ```\n  - n\n* * *\n  text\n2. e\n\n</details>\n3) g\n  2) x\n',
};
