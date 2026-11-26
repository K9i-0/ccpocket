// Extra coverage for the copy formatters (plain text and Markdown).
//
// Gap inventory against the reference suite (flutter_md, MIT), by test name:
//
// selection/markup_formatter_test.dart
//   (a) already covered by selection_formatter_test.dart: nested unordered /
//       ordered / task lists, headings, blockquote, alert, fenced code with
//       and without a language, pipe table, documents join with
//       documentSeparator, a partially selected list falls back to sliced
//       text, an empty selection formats to an empty string.
//   (b) ported: custom listIndent controls nesting width [medium];
//       separators are configurable [medium]; a fully selected boundary
//       block still reconstructs [high]; can be installed as the controller
//       default formatter [medium]; differs from the default plain formatter
//       [low]; implements the MarkdownSelectionFormatter interface [low];
//       TextRange is exposed on selected blocks [medium] (here:
//       MarkdownSelectedBlock.startOffset / endOffset).
//   (c) ported with a different expectation: the reference renders
//       `__text__` as underline; markdown_kit follows GFM and copies it back
//       as bold. Ordered lists ignore listIndent and indent by marker width
//       (MarkdownMarkupFormatter.listIndent doc comment).
//
// Known limits that are NOT asserted here (docs/markdown-kit-architecture.md
// section 5): literal markdown characters are not escaped, math is always
// written with `$` / `$$`, adjacent lists with different markers may merge.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

MarkdownPosition _pos(String doc, int block, int offset) =>
    MarkdownPosition(documentId: doc, blockIndex: block, offset: offset);

MarkdownSelection _sel(MarkdownPosition base, MarkdownPosition extent) =>
    MarkdownSelection(base: base, extent: extent);

MarkdownDocument _parse(
  String markdown, {
  MarkdownParserOptions options = const MarkdownParserOptions(),
}) => GfmMarkdownParser(options: options).parse(markdown);

/// Controller holding [documents] (ids `d0`, `d1`, ... in reading order).
MarkdownSelectionController _controller(
  List<MarkdownDocument> documents, {
  MarkdownSelectionFormatter? plain,
  MarkdownSelectionFormatter? markup,
}) {
  final controller = MarkdownSelectionController(
    plainTextFormatter: plain,
    markupFormatter: markup,
  );
  addTearDown(controller.dispose);
  for (var i = 0; i < documents.length; i++) {
    controller.putDocument(
      MarkdownDocumentRef(id: 'd$i', order: i, document: documents[i]),
    );
  }
  return controller;
}

/// Markdown copy of everything in [markdown].
String _copyAll(
  String markdown, {
  MarkdownSelectionFormatter? markup,
  MarkdownParserOptions options = const MarkdownParserOptions(),
}) {
  final controller = _controller([
    _parse(markdown, options: options),
  ], markup: markup);
  expect(controller.selectAll(), isTrue);
  return controller.getMarkdown();
}

String _rendered(MarkdownDocument document) =>
    extractDocumentRenderedText(document);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('listIndent', () {
    test('controls the nesting width of bullet lists', () {
      const source = '- one\n  - nested\n    - deeper\n- two';
      expect(_copyAll(source), '- one\n  - nested\n    - deeper\n- two');
      expect(
        _copyAll(
          source,
          markup: const MarkdownMarkupFormatter(listIndent: '    '),
        ),
        '- one\n    - nested\n        - deeper\n- two',
      );
    });

    test('a wider bullet indent still parses back to the same structure', () {
      const source = '- one\n  - nested\n\n    para in nested\n- two\n';
      final copied = _copyAll(
        source,
        markup: const MarkdownMarkupFormatter(listIndent: '    '),
      );
      expect(_rendered(_parse(copied)), _rendered(_parse(source)));
    });

    test('ordered lists ignore it and indent by their marker width', () {
      const source = '1. first\n   - child\n2. second';
      for (final indent in ['', '  ', '      ']) {
        expect(
          _copyAll(source, markup: MarkdownMarkupFormatter(listIndent: indent)),
          '1. first\n   - child\n2. second',
          reason: 'listIndent "${indent.length} spaces"',
        );
      }
    });
  });

  group('Separators', () {
    test('markup blockSeparator and documentSeparator are configurable', () {
      final controller = _controller(
        [_parse('# Title\n\nbody'), _parse('other')],
        markup: const MarkdownMarkupFormatter(
          blockSeparator: '\n',
          documentSeparator: '\n\n***\n\n',
        ),
      );
      expect(controller.selectAll(), isTrue);
      expect(controller.getMarkdown(), '# Title\nbody\n\n***\n\nother');
      // The plain formatter keeps its own defaults.
      expect(controller.getText(), 'Title\n\nbody\n\nother');
    });

    test('plain blockSeparator and documentSeparator are configurable', () {
      final controller = _controller(
        [_parse('# Title\n\nbody'), _parse('other')],
        plain: const MarkdownPlainTextFormatter(
          blockSeparator: ' | ',
          documentSeparator: ' || ',
        ),
      );
      expect(controller.selectAll(), isTrue);
      expect(controller.getText(), 'Title | body || other');
      expect(controller.getMarkdown(), '# Title\n\nbody\n\nother');
    });

    test('a document that contributes no text adds no separator', () {
      final controller = _controller([
        _parse('alpha'),
        _parse('---'),
        const MarkdownDocument(blocks: []),
        _parse('omega'),
      ]);
      // From the very end of d0 to the middle of d3.
      controller.setSelection(_sel(_pos('d0', 0, 5), _pos('d3', 0, 3)));
      expect(controller.getText(), 'ome');

      controller.setSelection(_sel(_pos('d0', 0, 2), _pos('d3', 0, 0)));
      expect(controller.getText(), 'pha');
    });

    test('a thematic break between two selected blocks is kept in Markdown '
        'and dropped from plain text', () {
      final controller = _controller([_parse('above\n\n---\n\nbelow')]);
      controller.setSelection(_sel(_pos('d0', 0, 2), _pos('d0', 2, 3)));
      expect(controller.getText(), 'ove\n\nbel');
      expect(controller.getMarkdown(), 'ove\n\n---\n\nbel');
    });
  });

  group('Boundary blocks', () {
    const source = '# Title\n\n- alpha\n- beta\n\n> quoted **bold**';

    test('a selection ending exactly at a block end reconstructs that '
        'block', () {
      final document = _parse(source);
      final controller = _controller([document]);
      final listLength = extractBlockRenderedText(document.blocks[1]).length;
      controller.setSelection(
        _sel(_pos('d0', 0, 0), _pos('d0', 1, listLength)),
      );
      expect(controller.getMarkdown(), '# Title\n\n- alpha\n- beta');
    });

    test('a partial first block is sliced while the rest reconstructs', () {
      final document = _parse(source);
      final controller = _controller([document]);
      final quoteLength = extractBlockRenderedText(document.blocks[2]).length;
      controller.setSelection(
        _sel(_pos('d0', 0, 2), _pos('d0', 2, quoteLength)),
      );
      expect(
        controller.getMarkdown(),
        'tle\n\n- alpha\n- beta\n\n> quoted **bold**',
      );
    });

    test('a partial last block is sliced while the rest reconstructs', () {
      final controller = _controller([_parse(source)]);
      controller.setSelection(_sel(_pos('d0', 0, 0), _pos('d0', 2, 6)));
      expect(controller.getMarkdown(), '# Title\n\n- alpha\n- beta\n\nquoted');
    });

    test('one character short of a block end is still partial', () {
      final controller = _controller([_parse(source)]);
      controller.setSelection(_sel(_pos('d0', 0, 0), _pos('d0', 0, 4)));
      expect(controller.getMarkdown(), 'Titl');
      controller.setSelection(_sel(_pos('d0', 0, 0), _pos('d0', 0, 5)));
      expect(controller.getMarkdown(), '# Title');
    });

    test('a reversed selection formats exactly like the forward one', () {
      final controller = _controller([_parse(source)]);
      controller.setSelection(_sel(_pos('d0', 0, 2), _pos('d0', 2, 6)));
      final forward = controller.getMarkdown();
      controller.setSelection(_sel(_pos('d0', 2, 6), _pos('d0', 0, 2)));
      expect(controller.getMarkdown(), forward);
    });

    test('selected blocks expose their offsets and partial state', () {
      final document = _parse(source);
      final controller = _controller([document]);
      controller.setSelection(_sel(_pos('d0', 0, 2), _pos('d0', 2, 6)));

      final content = controller.selectedContent();
      expect(content.documents, hasLength(1));
      final blocks = content.documents.single.blocks;
      expect(blocks, hasLength(3));

      expect((blocks[0].startOffset, blocks[0].endOffset), (2, 5));
      expect(blocks[0].isPartial, isTrue);
      expect(blocks[0].selectedText, 'tle');

      expect(blocks[1].isFullBlock, isTrue);
      expect(blocks[1].selectedText, 'alpha\nbeta');
      expect(blocks[1].block, same(document.blocks[1]));

      expect((blocks[2].startOffset, blocks[2].endOffset), (0, 6));
      expect(blocks[2].isPartial, isTrue);
      expect(blocks[2].fullText, 'quoted bold');
    });

    test('a collapsed selection has empty content in both formats', () {
      final controller = _controller([_parse(source)]);
      controller.setSelection(MarkdownSelection.collapsed(_pos('d0', 1, 3)));
      expect(controller.selectedContent().isEmpty, isTrue);
      expect(controller.getText(), '');
      expect(controller.getMarkdown(), '');
    });
  });

  group('Wiring', () {
    test('a custom markup formatter is used by getMarkdown only', () {
      final controller = _controller([
        _parse('**bold**'),
      ], markup: const _Shout());
      expect(controller.selectAll(), isTrue);
      expect(controller.getMarkdown(), 'SHOUT:bold');
      expect(controller.getText(), 'bold');
    });

    test('a custom plain formatter is used by getText only', () {
      final controller = _controller([
        _parse('**bold**'),
      ], plain: const _Shout());
      expect(controller.selectAll(), isTrue);
      expect(controller.getText(), 'SHOUT:bold');
      expect(controller.getMarkdown(), '**bold**');
    });

    test('the default formatters are the documented ones', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      expect(controller.plainTextFormatter, isA<MarkdownPlainTextFormatter>());
      expect(controller.markupFormatter, isA<MarkdownMarkupFormatter>());
      expect(
        const MarkdownMarkupFormatter(),
        isA<MarkdownSelectionFormatter>(),
      );
    });

    test('Markdown copy differs from plain copy for formatted content', () {
      final controller = _controller([_parse('# Head\n\n- [x] done')]);
      expect(controller.selectAll(), isTrue);
      expect(controller.getText(), 'Head\n\ndone');
      expect(controller.getMarkdown(), '# Head\n\n- [x] done');
    });
  });

  group('GFM semantics in copied Markdown', () {
    test('double underscores are bold and copy back as bold', () {
      final document = _parse('__strong__ and _soft_');
      expect(_rendered(document), 'strong and soft');
      final copied = _copyAll('__strong__ and _soft_');
      expect(copied, contains('**strong**'));
      expect(_parse(copied).blocks.single, isA<ParagraphBlock>());
      final first =
          (_parse(copied).blocks.single as ParagraphBlock).inlines.first;
      expect(first, isA<StrongInline>());
    });

    test('dollar signs stay literal text unless dollar LaTeX is enabled', () {
      const source = r'costs $5 and $7 total';
      final document = _parse(source);
      expect(_rendered(document), source);
      expect(_copyAll(source), source);
    });

    test('dollar LaTeX, when enabled, copies back with dollar delimiters', () {
      const options = MarkdownParserOptions(enableDollarLatex: true);
      final copied = _copyAll(r'inline $x^2$ here', options: options);
      expect(copied, r'inline $x^2$ here');
    });

    test('an unsupported raw HTML block is copied as its literal text', () {
      const source = '<marquee>hello there</marquee>';
      final document = _parse(source);
      expect(_rendered(document), contains('<marquee>'));
      expect(_copyAll(source), contains('<marquee>hello there</marquee>'));
    });

    test('an HTML comment block is neither shown nor copied', () {
      final controller = _controller([
        _parse('before\n\n<!-- secret note -->\n\nafter'),
      ]);
      expect(controller.selectAll(), isTrue);
      expect(controller.getText(), 'before\n\nafter');
      expect(controller.getMarkdown(), isNot(contains('secret')));
    });

    test('inline code that contains a backtick keeps its content', () {
      const source = 'run `` a`b `` now';
      final copied = _copyAll(source);
      expect(_rendered(_parse(copied)), _rendered(_parse(source)));
      expect(_rendered(_parse(source)), contains('a`b'));
    });

    test('a hard line break survives the round trip', () {
      const source = 'line one  \nline two';
      final copied = _copyAll(source);
      expect(_rendered(_parse(copied)), 'line one\nline two');
    });

    test('links, images and strikethrough keep their targets', () {
      const source =
          'see [docs](https://example.com/a "Title") ~~old~~ '
          '![alt text](https://example.com/i.png)';
      final copied = _copyAll(source);
      expect(copied, contains('[docs](https://example.com/a'));
      expect(copied, contains('~~old~~'));
      expect(copied, contains('![alt text](https://example.com/i.png)'));
    });

    test('a fence longer than any backtick run inside the code is chosen', () {
      const source = '````\nuse ``` inside\n````';
      final copied = _copyAll(source);
      final reparsed = _parse(copied);
      expect(reparsed.blocks.single, isA<CodeBlock>());
      expect(
        (reparsed.blocks.single as CodeBlock).code,
        contains('``` inside'),
      );
    });

    test('table column alignment survives the round trip', () {
      const source = '| l | c | r |\n|:--|:-:|--:|\n| 1 | 2 | 3 |';
      final reparsed = _parse(_copyAll(source));
      expect((reparsed.blocks.single as TableBlock).alignments, [
        TableColumnAlign.left,
        TableColumnAlign.center,
        TableColumnAlign.right,
      ]);
    });

    test('an ordered list keeps its start number', () {
      expect(_copyAll('7. seven\n8. eight'), '7. seven\n8. eight');
    });

    test('a loose list stays loose', () {
      const source = '- one\n\n- two\n';
      final reparsed = _parse(_copyAll(source));
      expect((reparsed.blocks.single as ListBlock).tight, isFalse);
    });
  });

  group('Random selections over a rich document (seed 7)', () {
    const source = '''
# Heading one

Paragraph with **bold**, _emphasis_, `code` and a [link](https://x.example).

- item one
- item two
  - nested item
- [x] task item

> quote line
>
> second quote paragraph

| A | B |
|---|---|
| 1 | 2 |

---

```dart
final answer = 42;
```

1. ordered one
2. ordered two

Last paragraph.
''';

    test('plain copy always equals the model slice and Markdown copy never '
        'throws or leaks separators', () {
      final document = _parse(source);
      final controller = _controller([document]);
      final texts = [
        for (final block in document.blocks) extractBlockRenderedText(block),
      ];
      final random = math.Random(7);

      MarkdownPosition randomPosition() {
        final block = random.nextInt(texts.length);
        return _pos('d0', block, random.nextInt(texts[block].length + 1));
      }

      for (var i = 0; i < 300; i++) {
        final a = randomPosition();
        final b = randomPosition();
        controller.setSelection(_sel(a, b));
        final (:start, :end) = controller.normalizedSelection!;

        final parts = <String>[];
        for (var block = start.blockIndex; block <= end.blockIndex; block++) {
          final from = block == start.blockIndex ? start.offset : 0;
          final to = block == end.blockIndex ? end.offset : texts[block].length;
          final slice = texts[block].substring(from, to);
          if (slice.isNotEmpty) parts.add(slice);
        }
        final expected = parts.join('\n\n');
        expect(controller.getText(), expected, reason: 'iteration $i: $a..$b');

        final markdown = controller.getMarkdown();
        if (expected.isEmpty) {
          // Only thematic breaks may remain.
          expect(markdown.replaceAll('---', '').trim(), isEmpty);
        } else {
          expect(markdown, isNotEmpty, reason: 'iteration $i');
        }
        // A partly selected edge block is copied as its plain slice, which
        // may itself begin or end on a line break inside that block.
        expect(
          markdown.startsWith('\n'),
          expected.startsWith('\n'),
          reason: 'iteration $i',
        );
        if (!expected.endsWith('\n')) {
          expect(markdown.endsWith('\n\n'), isFalse, reason: 'iteration $i');
        }

        controller.setSelection(_sel(b, a));
        expect(controller.getText(), expected, reason: 'reversed $i');
        expect(controller.getMarkdown(), markdown, reason: 'reversed $i');
      }
    });

    test('whole-block selections reparse to the same rendered text', () {
      final document = _parse(source);
      final controller = _controller([document]);
      final texts = [
        for (final block in document.blocks) extractBlockRenderedText(block),
      ];
      final selectable = [
        for (var i = 0; i < texts.length; i++)
          if (texts[i].isNotEmpty) i,
      ];
      final random = math.Random(7);

      for (var i = 0; i < 100; i++) {
        final x = selectable[random.nextInt(selectable.length)];
        final y = selectable[random.nextInt(selectable.length)];
        final first = math.min(x, y);
        final last = math.max(x, y);
        controller.setSelection(
          _sel(_pos('d0', first, 0), _pos('d0', last, texts[last].length)),
        );
        final reparsed = _parse(controller.getMarkdown());
        expect(
          _rendered(reparsed),
          controller.getText(),
          reason: 'blocks $first..$last:\n${controller.getMarkdown()}',
        );
      }
    });
  });
}

class _Shout implements MarkdownSelectionFormatter {
  const _Shout();

  @override
  String format(MarkdownSelectedContent content) {
    final text = [
      for (final document in content.documents)
        for (final block in document.blocks) block.selectedText,
    ].join('+');
    return 'SHOUT:$text';
  }
}
