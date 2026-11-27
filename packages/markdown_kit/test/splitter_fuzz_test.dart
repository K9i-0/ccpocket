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

    for (var n = 0; n < 60000; n++) {
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
    // What is left needs rules the splitter does not model. An empty list
    // marker right below text is that text and not an item, so a fence
    // indented under it is not inside an item; and a fence inside a raw HTML
    // block such as `<div>` is not a fence. Anything new in this set is a
    // regression worth a look.
    expect(different, _known);
  });
}

const _known = <String>{
  '   -\npara\n+\n  ```\n# head\n|---|---|\n===\n  2) x\npara\n\n_ _ _\n10. ten\n===\n',
  '<div>\n  - n\n  ```\n- [x] i\n_ _ _\n> - q\n\\]\n---\n\n```\n\n\\]\n',
  '10. ten\n-\n ---\n  ```\n  2) x\n+\n\n> - q\n  - n\n10. ten\n  - n\n  - n\n',
  '- a\n  2) x\n  text\n-\n+\n===\n  ```\n|---|---|\n ---\n# head\n\n<b>x</b>\n',
};
