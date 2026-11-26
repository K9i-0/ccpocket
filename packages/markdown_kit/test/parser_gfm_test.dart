// GFM extensions at parse level: alerts, task lists, tables, footnotes.
//
// Mined from flutter_md gfm_test (Alerts, Task lists, Table alignment),
// edge_cases_test (ragged tables, pipes) and gpt_markdown block/alert_test
// (parsing group), block/checkbox_test, block/table_test,
// integration/complex_markdown_test; rewritten against markdown_kit's AST.
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_kit/markdown_kit.dart';

List<MarkdownBlock> _parse(
  String source, {
  MarkdownParserOptions options = const MarkdownParserOptions(),
}) => GfmMarkdownParser(options: options).parse(source).blocks;

String _upstream(String source) {
  String visible(String text) => text.replaceAll('\n', r'\n');
  try {
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ).parse(source);
    return '${visible(source)} -> upstream: ${visible(md.renderToHtml(nodes))}';
  } catch (error) {
    return '${visible(source)} -> upstream throws ${error.runtimeType}';
  }
}

List<Type> _kinds(List<MarkdownBlock> blocks) => [
  for (final block in blocks) block.runtimeType,
];

List<String> _cells(TableRowNode row) => [
  for (final cell in row.cells) extractInlinesRenderedText(cell),
];

ParagraphBlock _p(String text) => ParagraphBlock(inlines: [TextInline(text)]);

void main() {
  group('alerts', () {
    test('a marker alone is an alert with an empty body', () {
      for (final source in [
        '> [!WARNING]',
        '> [!WARNING]\n',
        '>[!WARNING]  ',
      ]) {
        expect(_parse(source), const [
          AlertBlock(kind: AlertKind.warning, children: []),
        ], reason: source);
      }
    });

    test('the marker is stripped and the body keeps its inline markup', () {
      const source =
          '> [!TIP]\n> Use **bold**, `code` and a [link](/u)\n> on two lines.';
      expect(_parse(source), const [
        AlertBlock(
          kind: AlertKind.tip,
          children: [
            ParagraphBlock(
              inlines: [
                TextInline('Use '),
                StrongInline(children: [TextInline('bold')]),
                TextInline(', '),
                InlineCodeInline('code'),
                TextInline(' and a '),
                LinkInline(destination: '/u', children: [TextInline('link')]),
                LineBreakInline(isHard: false),
                TextInline('on two lines.'),
              ],
            ),
          ],
        ),
      ]);
    });

    test('the body is what the quote held before alerts', () {
      const body = '> para\n>\n> - a\n> - b\n>\n> ```dart\n> x();\n> ```\n';
      final quote = _parse(body).single as BlockquoteBlock;
      final alert = _parse('> [!NOTE]\n$body').single as AlertBlock;
      expect(alert.kind, AlertKind.note);
      expect(alert.children, quote.children);
      expect(_kinds(alert.children), [ParagraphBlock, ListBlock, CodeBlock]);
      expect((alert.children.last as CodeBlock).code, 'x();');
    });

    test('a blank quote line after the marker still gives an alert', () {
      expect(_parse('> [!IMPORTANT]\n>\n> Body.'), [
        AlertBlock(kind: AlertKind.important, children: [_p('Body.')]),
      ]);
    });

    test('a lazy continuation line joins the alert body', () {
      expect(_parse('> [!CAUTION]\n> first\nlazy'), const [
        AlertBlock(
          kind: AlertKind.caution,
          children: [
            ParagraphBlock(
              inlines: [
                TextInline('first'),
                LineBreakInline(isHard: false),
                TextInline('lazy'),
              ],
            ),
          ],
        ),
      ]);
    });

    test('an unknown marker is an ordinary quote that keeps its text', () {
      for (final marker in [
        '[!FOOBAR]',
        '[!]',
        '[!NOTE',
        '[NOTE]',
        '[! NOTE]',
      ]) {
        final blocks = _parse('> $marker\n> body');
        expect(_kinds(blocks), [BlockquoteBlock], reason: marker);
        expect(
          extractBlockRenderedText(blocks.single),
          contains(marker),
          reason: marker,
        );
      }
    });

    test('text after the marker on its line means no alert', () {
      // GitHub only treats a marker that stands alone on the first line.
      final blocks = _parse('> [!NOTE] inline text\n> more');
      expect(_kinds(blocks), [BlockquoteBlock]);
      expect(extractBlockRenderedText(blocks.single), contains('[!NOTE]'));
    });

    test('a marker that is not on the first line means no alert', () {
      final blocks = _parse('> text\n> [!NOTE]\n> more');
      expect(_kinds(blocks), [BlockquoteBlock]);
      final later = _parse('> text\n>\n> [!NOTE]\n> more');
      expect(_kinds(later), [BlockquoteBlock]);
    });

    test('an ordinary quote is not an alert', () {
      expect(_parse('> just a normal quote'), [
        BlockquoteBlock(children: [_p('just a normal quote')]),
      ]);
    });

    test('alerts nest inside list items and quotes', () {
      final list =
          _parse('- item\n\n  > [!TIP]\n  > inside').single as ListBlock;
      expect(
        list.items.single.children.last,
        AlertBlock(kind: AlertKind.tip, children: [_p('inside')]),
      );
      final quote = _parse('> > [!NOTE]\n> > deep').single as BlockquoteBlock;
      expect(
        quote.children.single,
        AlertBlock(kind: AlertKind.note, children: [_p('deep')]),
      );
    });

    test('two alerts separated by a blank line are two blocks', () {
      final blocks = _parse('> [!NOTE]\n> one\n\n> [!WARNING]\n> two');
      expect(blocks, [
        AlertBlock(kind: AlertKind.note, children: [_p('one')]),
        AlertBlock(kind: AlertKind.warning, children: [_p('two')]),
      ]);
    });

    test('enableAlerts: false leaves the marker in an ordinary quote', () {
      final blocks = _parse(
        '> [!NOTE]\n> body',
        options: const MarkdownParserOptions(enableAlerts: false),
      );
      expect(_kinds(blocks), [BlockquoteBlock]);
      expect(extractBlockRenderedText(blocks.single), contains('[!NOTE]'));
    });

    test('a streamed alert becomes one when its marker completes', () {
      const source = '> [!WARNING]\n> Careful **now**.\n';
      final parser = GfmMarkdownParser();
      final kinds = <Type>{};
      MarkdownDocument? last;
      for (var end = 1; end <= source.length; end++) {
        last = parser.parse(source.substring(0, end), isStreaming: true);
        expect(last.blocks, hasLength(1));
        kinds.add(last.blocks.single.runtimeType);
        if (end >= '> [!WARNING]'.length) {
          expect(last.blocks.single, isA<AlertBlock>(), reason: 'at $end');
        }
      }
      expect(kinds, {BlockquoteBlock, AlertBlock});
      expect(last!.blocks, _parse(source));
    });
  });

  group('task lists', () {
    ListBlock list(String source) => _parse(source).single as ListBlock;

    test('unchecked, checked and upper-case checked items', () {
      final parsed = list('- [ ] todo\n- [x] done\n- [X] also\n- plain');
      expect(parsed.items.map((item) => item.checked), [
        false,
        true,
        true,
        null,
      ]);
      expect(parsed.items.map(extractListItemRenderedText), [
        'todo',
        'done',
        'also',
        'plain',
      ]);
    });

    test('what is not a checkbox stays text', () {
      for (final label in [
        '[] todo',
        '[  ] two spaces',
        '[y] other letter',
        '[x]glued',
        '[ x] padded',
        'text [x] later',
        r'\[x] escaped',
      ]) {
        final item = list('- $label').items.single;
        expect(item.checked, isNull, reason: _upstream('- $label'));
        expect(
          extractListItemRenderedText(item),
          label.replaceAll(r'\', ''),
          reason: label,
        );
      }
    });

    test('ordered and other-bullet task items', () {
      final ordered = list('1. [x] done\n2. [ ] todo');
      expect(ordered.ordered, isTrue);
      expect(ordered.items.map((item) => item.checked), [true, false]);
      for (final marker in ['*', '+']) {
        expect(list('$marker [x] done').items.single.checked, isTrue);
      }
    });

    test('nested task items keep their own state', () {
      final parsed = list('- [x] parent\n  - [ ] child\n    - [x] leaf');
      final parent = parsed.items.single;
      expect(parent.checked, isTrue);
      final child = (parent.children.last as ListBlock).items.single;
      expect(child.checked, isFalse);
      expect(extractBlockRenderedText(child.children.first), 'child');
      final leaf = (child.children.last as ListBlock).items.single;
      expect(leaf.checked, isTrue);
      expect(extractListItemRenderedText(leaf), 'leaf');
    });

    test('task items in a loose list', () {
      final parsed = list('- [x] done\n\n- [ ] todo\n\n  more');
      expect(parsed.tight, isFalse);
      expect(parsed.items.map((item) => item.checked), [true, false]);
      expect(parsed.items.last.children, [_p('todo'), _p('more')]);
    });

    test('task items hold inline markup', () {
      final parsed = list('- [x] **Bold** task\n- [ ] Run `npm install`');
      expect(
        parsed.items.first.children.single,
        const ParagraphBlock(
          inlines: [
            StrongInline(children: [TextInline('Bold')]),
            TextInline(' task'),
          ],
        ),
      );
      expect(
        parsed.items.last.children.single,
        const ParagraphBlock(
          inlines: [TextInline('Run '), InlineCodeInline('npm install')],
        ),
      );
    });

    test('a task list inside a quote', () {
      final quote = _parse('> - [x] a\n> - [ ] b').single as BlockquoteBlock;
      final inner = quote.children.single as ListBlock;
      expect(inner.items.map((item) => item.checked), [true, false]);
    });
  });

  group('tables', () {
    TableBlock table(String source) {
      final blocks = _parse(source);
      expect(_kinds(blocks), [TableBlock], reason: _upstream(source));
      return blocks.single as TableBlock;
    }

    test('alignment comes from the colons of the delimiter row', () {
      final parsed = table(
        '| a | b | c | d |\n|:--|:-:|--:|---|\n| 1 | 2 | 3 | 4 |',
      );
      expect(parsed.alignments, [
        TableColumnAlign.left,
        TableColumnAlign.center,
        TableColumnAlign.right,
        TableColumnAlign.none,
      ]);
      expect(table('|a|\n|:-:|\n|1|').alignments, [TableColumnAlign.center]);
      expect(table('| a | b |\n| - | - |').alignments, [
        TableColumnAlign.none,
        TableColumnAlign.none,
      ]);
    });

    test('a short row is padded and a long row is cut', () {
      final parsed = table('| a | b |\n|---|---|\n| 1 |\n| x | y | z |\n||');
      expect(parsed.columnCount, 2);
      expect(parsed.alignments, hasLength(2));
      expect(parsed.rows.map(_cells), [
        ['1', ''],
        ['x', 'y'],
        ['', ''],
      ]);
      for (final row in parsed.rows) {
        expect(row.cells, hasLength(2));
      }
    });

    test('the header must have as many cells as the delimiter row', () {
      for (final source in [
        '| a | b |\n| --- |\n| 1 | 2 |',
        '| a |\n| --- | --- |\n| 1 | 2 |',
      ]) {
        expect(
          _parse(source).whereType<TableBlock>(),
          isEmpty,
          reason: _upstream(source),
        );
      }
    });

    test('a delimiter row needs dashes', () {
      for (final source in [
        '|a|b|\n|xx|yy|\n|1|2|',
        '| a | b |\n| :: | :: |',
        '| a | b |\n| | |',
        '| a | b |',
        '|||',
        'a | b | c',
      ]) {
        expect(
          _parse(source).whereType<TableBlock>(),
          isEmpty,
          reason: _upstream(source),
        );
      }
    });

    test('outer pipes are optional', () {
      final bare = table('a | b\n--- | ---\n1 | 2');
      expect(_cells(bare.header), ['a', 'b']);
      expect(bare.rows.map(_cells), [
        ['1', '2'],
      ]);
      final half = table('| a | b\n| --- | ---\n| 1 | 2');
      expect(_cells(half.header), ['a', 'b']);
      expect(half.rows.map(_cells), [
        ['1', '2'],
      ]);
    });

    test('an escaped pipe is cell text, also inside a code span', () {
      final parsed = table(
        '| a \\| b | c |\n| --- | --- |\n| `x \\| y` | **p \\| q** |',
      );
      expect(parsed.columnCount, 2);
      expect(parsed.header.cells.first, const [TextInline('a | b')]);
      expect(parsed.rows.single.cells.first, const [InlineCodeInline('x | y')]);
      expect(parsed.rows.single.cells.last, const [
        StrongInline(children: [TextInline('p | q')]),
      ]);
    });

    test('cells hold inline markup, links, images and breaks', () {
      final parsed = table(
        '| **b** *i* | ~~s~~ `c` |\n| --- | --- |\n'
        '| [l](/u) ![i](a.png) | one<br>two |',
      );
      expect(parsed.header.cells, const [
        [
          StrongInline(children: [TextInline('b')]),
          TextInline(' '),
          EmphasisInline(children: [TextInline('i')]),
        ],
        [
          StrikethroughInline(children: [TextInline('s')]),
          TextInline(' '),
          InlineCodeInline('c'),
        ],
      ]);
      expect(parsed.rows.single.cells, const [
        [
          LinkInline(destination: '/u', children: [TextInline('l')]),
          TextInline(' '),
          ImageInline(source: 'a.png', alt: 'i'),
        ],
        [TextInline('one'), LineBreakInline(), TextInline('two')],
      ]);
    });

    test('cell text is trimmed and empty cells are empty', () {
      final parsed = table('|   a   |  |\n|---|---|\n|     |   b|');
      expect(parsed.header.cells, const [
        [TextInline('a')],
        <MarkdownInline>[],
      ]);
      expect(parsed.rows.single.cells, const [
        <MarkdownInline>[],
        [TextInline('b')],
      ]);
    });

    test('a header-only table has no rows', () {
      final parsed = table('| a | b |\n| --- | --- |');
      expect(parsed.rows, isEmpty);
      expect(_cells(parsed.header), ['a', 'b']);
    });

    test('a table ends at a blank line or at another block', () {
      expect(_kinds(_parse('| a |\n| - |\n| 1 |\n\nafter')), [
        TableBlock,
        ParagraphBlock,
      ]);
      expect(_kinds(_parse('| a |\n| - |\n| 1 |\n> quote')), [
        TableBlock,
        BlockquoteBlock,
      ]);
      expect(_kinds(_parse('| a |\n| - |\n| 1 |\n# Heading')), [
        TableBlock,
        HeadingBlock,
      ]);
      expect(_kinds(_parse('| a |\n| - |\n| 1 |\n```\ncode\n```')), [
        TableBlock,
        CodeBlock,
      ]);
    });

    test('a plain line right under a table is one more row', () {
      // GFM example 202: the table is only broken by a blank line or the
      // start of another block.
      const source = '| a | b |\n| - | - |\n| 1 | 2 |\nbar\n\nbaz';
      final blocks = _parse(source);
      expect(_kinds(blocks), [
        TableBlock,
        ParagraphBlock,
      ], reason: _upstream(source));
      expect((blocks.first as TableBlock).rows.map(_cells), [
        ['1', '2'],
        ['bar', ''],
      ]);
    });

    test('tables inside quotes and list items', () {
      final quote =
          _parse('> | a | b |\n> | - | - |\n> | 1 | 2 |').single
              as BlockquoteBlock;
      expect(quote.children.single, isA<TableBlock>());
      const source = '- item\n\n  | a | b |\n  | - | - |\n  | 1 | 2 |';
      final list = _parse(source).single as ListBlock;
      expect(
        list.items.single.children.last,
        isA<TableBlock>(),
        reason: _upstream(source),
      );
    });

    test('a wide table keeps every column', () {
      const columns = 40;
      String row(String Function(int) cell) =>
          '| ${[for (var i = 0; i < columns; i++) cell(i)].join(' | ')} |';
      final parsed = table(
        '${row((i) => 'h$i')}\n${row((_) => '---')}\n${row((i) => 'c$i')}',
      );
      expect(parsed.columnCount, columns);
      expect(_cells(parsed.rows.single).last, 'c${columns - 1}');
    });

    test('non-ASCII and emoji cells', () {
      final parsed = table('| 名前 | 値 |\n| --- | --- |\n| りんご 🍎 | ١٢٣ |');
      expect(_cells(parsed.header), ['名前', '値']);
      expect(_cells(parsed.rows.single), ['りんご 🍎', '١٢٣']);
    });

    test('the rendered text separates cells with tabs and rows with LF', () {
      final parsed = table('| a | b |\n| - | - |\n| 1 |  |\n| 3 | 4 |');
      expect(extractBlockRenderedText(parsed), 'a\tb\n1\t\n3\t4');
    });
  });

  group('footnotes', () {
    List<FootnoteRefInline> refs(List<MarkdownBlock> blocks) {
      final out = <FootnoteRefInline>[];
      void inline(MarkdownInline node) {
        switch (node) {
          case FootnoteRefInline():
            out.add(node);
          case EmphasisInline(:final children) ||
              StrongInline(:final children) ||
              StrikethroughInline(:final children) ||
              LinkInline(:final children):
            children.forEach(inline);
          default:
            break;
        }
      }

      void block(MarkdownBlock node) {
        switch (node) {
          case ParagraphBlock(:final inlines):
            inlines.forEach(inline);
          case HeadingBlock(:final inlines):
            inlines.forEach(inline);
          case BlockquoteBlock(:final children):
            children.forEach(block);
          case ListBlock(:final items):
            for (final item in items) {
              item.children.forEach(block);
            }
          case TableBlock(:final header, :final rows):
            for (final row in [header, ...rows]) {
              for (final cell in row.cells) {
                cell.forEach(inline);
              }
            }
          default:
            break;
        }
      }

      blocks.forEach(block);
      return out;
    }

    test('references are numbered in the order they first appear', () {
      final blocks = _parse(
        'Second[^b], first[^a], second again[^b].\n\n'
        '[^a]: Note A.\n[^b]: Note B.\n',
      );
      expect(refs(blocks), const [
        FootnoteRefInline(label: 'b', index: 1),
        FootnoteRefInline(label: 'a', index: 2),
        FootnoteRefInline(label: 'b', index: 1),
      ]);
      final definitions = (blocks.last as FootnoteDefinitionsBlock).definitions;
      expect(definitions.map((d) => (d.label, d.index)), [('b', 1), ('a', 2)]);
      expect(definitions.first.children, [_p('Note B.')]);
    });

    test('a definition may come before its reference', () {
      final blocks = _parse('[^n]: Early note.\n\nText[^n].');
      expect(refs(blocks), const [FootnoteRefInline(label: 'n', index: 1)]);
      expect(blocks.whereType<FootnoteDefinitionsBlock>(), hasLength(1));
      expect(blocks.last, isA<FootnoteDefinitionsBlock>());
    });

    test('references resolve inside emphasis, lists, quotes and tables', () {
      final blocks = _parse(
        '# Title[^1]\n\n**bold[^2]**\n\n- item[^3]\n\n> quote[^4]\n\n'
        '| cell[^5] |\n| --- |\n\n'
        '[^1]: a\n[^2]: b\n[^3]: c\n[^4]: d\n[^5]: e\n',
      );
      expect(refs(blocks).map((ref) => ref.index), [1, 2, 3, 4, 5]);
      expect(
        (blocks.last as FootnoteDefinitionsBlock).definitions,
        hasLength(5),
      );
    });

    test('word labels are kept as written', () {
      final blocks = _parse('Text[^my-note_1].\n\n[^my-note_1]: The note.');
      expect(refs(blocks).single.label, 'my-note_1');
      expect(
        (blocks.last as FootnoteDefinitionsBlock).definitions.single.label,
        'my-note_1',
      );
    });

    test('a definition holds lists and code as its children', () {
      final blocks = _parse(
        'Text[^1].\n\n[^1]: First paragraph.\n\n    - a\n    - b\n\n'
        '    ```dart\n    x();\n    ```\n',
      );
      final definition =
          (blocks.last as FootnoteDefinitionsBlock).definitions.single;
      expect(_kinds(definition.children), [
        ParagraphBlock,
        ListBlock,
        CodeBlock,
      ]);
      expect((definition.children.last as CodeBlock).code, 'x();');
    });

    test('a reference inside code is code', () {
      final blocks = _parse('`a[^1]`\n\n```\nb[^1]\n```\n\n[^1]: note');
      expect(refs(blocks), isEmpty);
      expect((blocks.first as ParagraphBlock).inlines, const [
        InlineCodeInline('a[^1]'),
      ]);
      expect((blocks[1] as CodeBlock).code, 'b[^1]');
    });

    test('a definition renders no paragraph of its own', () {
      final blocks = _parse('Text[^1].\n\n[^1]: The note.\n\nAfter.');
      expect(_kinds(blocks), [
        ParagraphBlock,
        ParagraphBlock,
        FootnoteDefinitionsBlock,
      ]);
      expect(blocks[1], _p('After.'));
    });

    test('a reference without a definition has no number', () {
      final blocks = _parse('Text[^missing] here.');
      expect(_kinds(blocks), [ParagraphBlock]);
      final reference = refs(blocks);
      // Either the literal text or an unnumbered reference, never a number.
      if (reference.isEmpty) {
        expect(extractBlockRenderedText(blocks.single), 'Text[^missing] here.');
      } else {
        expect(reference.single, const FootnoteRefInline(label: 'missing'));
      }
    });

    test('enableFootnotes: false leaves a lone reference as text', () {
      final blocks = _parse(
        'Text[^1] here.',
        options: const MarkdownParserOptions(enableFootnotes: false),
      );
      expect(blocks, [_p('Text[^1] here.')]);
    });
  });

  // gpt_markdown integration/complex_markdown_test (AST side).
  group('a complex document', () {
    const document = '''
# Project

Intro with **bold**, *italic*, `code` and a [link](https://example.com).

## Features

- First
- Second
  - Nested with `code`
* Other marker

1. One
2. Two

- [x] Done
- [ ] Todo

| Name | Status |
| ---- | :----: |
| **A** | `ok` |

> Quote with *emphasis*.

---

```dart
void main() {}
```
- after code
''';

    test('parses into the expected sequence of blocks', () {
      final blocks = _parse(document);
      expect(_kinds(blocks), [
        HeadingBlock,
        ParagraphBlock,
        HeadingBlock,
        ListBlock,
        ListBlock,
        ListBlock,
        ListBlock,
        TableBlock,
        BlockquoteBlock,
        ThematicBreakBlock,
        CodeBlock,
        ListBlock,
      ]);
      expect((blocks[0] as HeadingBlock).level, 1);
      expect((blocks[2] as HeadingBlock).level, 2);
      expect((blocks[3] as ListBlock).items, hasLength(2));
      expect((blocks[5] as ListBlock).ordered, isTrue);
      expect((blocks[6] as ListBlock).items.map((item) => item.checked), [
        true,
        false,
      ]);
      final table = blocks[7] as TableBlock;
      expect(table.alignments, [
        TableColumnAlign.none,
        TableColumnAlign.center,
      ]);
      expect(table.rows.single.cells, const [
        [
          StrongInline(children: [TextInline('A')]),
        ],
        [InlineCodeInline('ok')],
      ]);
      expect((blocks[10] as CodeBlock).code, 'void main() {}');
    });

    test('streams to the same blocks', () {
      final parser = GfmMarkdownParser();
      MarkdownDocument? last;
      for (var end = 1; end <= document.length; end++) {
        last = parser.parse(document.substring(0, end), isStreaming: true);
      }
      expect(last!.blocks, _parse(document));
    });
  });
}
