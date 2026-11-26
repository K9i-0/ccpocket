// Parse-level edge cases: line endings, code fences, links, line breaks,
// escapes, list and heading markers.
//
// Mined from flutter_md (regression_test, edge_cases_test, hostile_input_test
// › Links) and gpt_markdown (inline/, block/, regression/nested_code_blocks,
// paragraph_line_breaks, issue_104_crlf_table_rendering, link_with_title,
// inline/autolink), rewritten against markdown_kit's AST. Expected values
// follow CommonMark/GFM as implemented by markdown_kit, not the references.
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_kit/markdown_kit.dart';

List<MarkdownBlock> _parse(
  String source, {
  MarkdownParserOptions options = const MarkdownParserOptions(),
}) => GfmMarkdownParser(options: options).parse(source).blocks;

List<MarkdownInline> _inlines(String source) =>
    (_parse(source).single as ParagraphBlock).inlines;

String _visible(String source) => source
    .replaceAll('\r', r'\r')
    .replaceAll('\n', r'\n')
    .replaceAll('\t', r'\t');

String _upstream(String source) {
  try {
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ).parse(source);
    return '${_visible(source)} -> upstream: '
        '${_visible(md.renderToHtml(nodes))}';
  } catch (error) {
    return '${_visible(source)} -> upstream throws ${error.runtimeType}';
  }
}

String _text(List<MarkdownBlock> blocks) =>
    blocks.map(extractBlockRenderedText).join('\n\n');

List<Type> _kinds(List<MarkdownBlock> blocks) => [
  for (final block in blocks) block.runtimeType,
];

/// Every string the AST holds: text, code, destinations, titles, languages.
List<String> _strings(List<MarkdownBlock> blocks) {
  final out = <String>[];
  void inline(MarkdownInline node) {
    switch (node) {
      case TextInline(:final text):
        out.add(text);
      case InlineCodeInline(:final code):
        out.add(code);
      case LinkInline(:final destination, :final title, :final children):
        out.add(destination);
        if (title != null) out.add(title);
        children.forEach(inline);
      case ImageInline(:final source, :final alt, :final title):
        out
          ..add(source)
          ..add(alt);
        if (title != null) out.add(title);
      case EmphasisInline(:final children) ||
          StrongInline(:final children) ||
          StrikethroughInline(:final children) ||
          UnderlineInline(:final children) ||
          SubscriptInline(:final children) ||
          SuperscriptInline(:final children) ||
          KeyboardInline(:final children):
        children.forEach(inline);
      case InlineLatexInline(:final expression):
        out.add(expression);
      case FootnoteRefInline(:final label):
        out.add(label);
      case CustomInline(:final text):
        out.add(text);
      case LineBreakInline():
        break;
    }
  }

  void block(MarkdownBlock node) {
    switch (node) {
      case ParagraphBlock(:final inlines):
        inlines.forEach(inline);
      case HeadingBlock(:final inlines):
        inlines.forEach(inline);
      case CodeBlock(:final code, :final language, :final infoString):
        out.add(code);
        if (language != null) out.add(language);
        if (infoString != null) out.add(infoString);
      case BlockquoteBlock(:final children):
        children.forEach(block);
      case AlertBlock(:final children):
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
      case HtmlDetailsBlock(:final summary, :final children):
        summary.forEach(inline);
        children.forEach(block);
      case FootnoteDefinitionsBlock(:final definitions):
        for (final definition in definitions) {
          out.add(definition.label);
          definition.children.forEach(block);
        }
      case BlockLatexBlock(:final expression):
        out.add(expression);
      case ThematicBreakBlock():
        break;
    }
  }

  blocks.forEach(block);
  return out;
}

void _expectNoCarriageReturn(String source) {
  final leaked = _strings(_parse(source))
      .where((value) => value.contains('\r'))
      .map(_visible)
      .toList();
  expect(leaked, isEmpty, reason: _upstream(source));
}

void main() {
  // gpt_markdown regression/issue_104_crlf_table_rendering_test and the
  // "CRLF everywhere" priority: does a `\r` leak into the AST?
  group('CRLF and CR line endings', () {
    const table = TableBlock(
      alignments: [TableColumnAlign.left, TableColumnAlign.right],
      header: TableRowNode(
        cells: [
          [TextInline('Name')],
          [TextInline('Value')],
        ],
      ),
      rows: [
        TableRowNode(
          cells: [
            [TextInline('foo')],
            [TextInline('bar')],
          ],
        ),
        TableRowNode(
          cells: [
            [TextInline('baz')],
            [TextInline('qux')],
          ],
        ),
      ],
    );
    const lines = [
      '| Name | Value |',
      '|:-----|------:|',
      '| foo  | bar   |',
      '| baz  | qux   |',
    ];

    test('a CRLF table is a table with clean cells', () {
      expect(_parse(lines.join('\r\n')), const [table]);
      expect(_parse('${lines.join('\r\n')}\r\n'), const [table]);
    });

    test('a bare-CR table is a table with clean cells', () {
      expect(_parse(lines.join('\r')), const [table]);
      expect(_parse('${lines.join('\r')}\r'), const [table]);
    });

    test('a table with mixed CRLF and LF endings is a table', () {
      final source = '${lines[0]}\r\n${lines[1]}\n${lines[2]}\r\n${lines[3]}\n';
      expect(_parse(source), const [table]);
    });

    test('a CRLF table between paragraphs keeps its neighbours', () {
      final source = 'Before\r\n\r\n${lines.join('\r\n')}\r\n\r\nAfter\r\n';
      expect(_parse(source), const [
        ParagraphBlock(inlines: [TextInline('Before')]),
        table,
        ParagraphBlock(inlines: [TextInline('After')]),
      ]);
    });

    test('a CRLF fence keeps the CR out of language and code', () {
      final block =
          _parse(
                '```dart title="a"\r\nfinal a = 1;\r\n\r\nfinal b = 2;\r\n```\r\n',
              ).single
              as CodeBlock;
      expect(block.language, 'dart');
      expect(block.infoString, 'dart title="a"');
      expect(block.code, 'final a = 1;\n\nfinal b = 2;');
      expect(block.closed, isTrue);
    });

    test('a CRLF tilde fence and an unclosed CRLF fence are clean too', () {
      final tilde = _parse('~~~py\r\nx = 1\r\n~~~').single as CodeBlock;
      expect(tilde.language, 'py');
      expect(tilde.code, 'x = 1');
      expect(tilde.closed, isTrue);
      final open = _parse('```js\r\nlet a;\r\nlet b;\r\n').single as CodeBlock;
      expect(open.language, 'js');
      expect(open.code, 'let a;\nlet b;');
      expect(open.closed, isFalse);
    });

    test('CRLF indented code has LF between its lines', () {
      final block = _parse('    a\r\n    b\r\n').single as CodeBlock;
      expect(block.isFenced, isFalse);
      expect(block.code, 'a\nb');
    });

    test('CRLF headings, ATX and setext', () {
      expect(_parse('# Title\r\n\r\n## Sub ##\r\n'), const [
        HeadingBlock(level: 1, inlines: [TextInline('Title')]),
        HeadingBlock(level: 2, inlines: [TextInline('Sub')]),
      ]);
      expect(_parse('Title\r\n=====\r\n\r\nSub\r\n---\r\n'), const [
        HeadingBlock(level: 1, inlines: [TextInline('Title')]),
        HeadingBlock(level: 2, inlines: [TextInline('Sub')]),
      ]);
    });

    test('CRLF soft and hard breaks', () {
      expect(_inlines('one\r\ntwo'), const [
        TextInline('one'),
        LineBreakInline(isHard: false),
        TextInline('two'),
      ]);
      expect(_inlines('one  \r\ntwo'), const [
        TextInline('one'),
        LineBreakInline(),
        TextInline('two'),
      ]);
      expect(_inlines('one\\\r\ntwo'), const [
        TextInline('one'),
        LineBreakInline(),
        TextInline('two'),
      ]);
    });

    test('a code span across a CRLF joins its lines with one space', () {
      expect(_inlines('`a\r\nb`'), const [InlineCodeInline('a b')]);
      expect(_inlines('`a\nb`'), const [InlineCodeInline('a b')]);
    });

    test('CRLF lists, task lists and nested lists', () {
      final list =
          _parse('- [x] done\r\n- [ ] todo\r\n  - child\r\n- plain\r\n').single
              as ListBlock;
      expect(list.items.map((item) => item.checked), [true, false, null]);
      expect(extractListItemRenderedText(list.items[0]), 'done');
      expect(
        list.items[1].children.first,
        const ParagraphBlock(inlines: [TextInline('todo')]),
      );
      expect(list.items[1].children.last, isA<ListBlock>());
      expect(extractListItemRenderedText(list.items[2]), 'plain');
      expect(list.tight, isTrue);
    });

    test('CRLF quotes and alerts', () {
      expect(_parse('> one\r\n> two\r\n'), const [
        BlockquoteBlock(
          children: [
            ParagraphBlock(
              inlines: [
                TextInline('one'),
                LineBreakInline(isHard: false),
                TextInline('two'),
              ],
            ),
          ],
        ),
      ]);
      expect(_parse('> [!WARNING]\r\n> Careful.\r\n'), const [
        AlertBlock(
          kind: AlertKind.warning,
          children: [
            ParagraphBlock(inlines: [TextInline('Careful.')]),
          ],
        ),
      ]);
    });

    test('CRLF details, display math, footnotes and reference links', () {
      expect(
        _parse(
          '<details>\r\n<summary>Sum</summary>\r\n\r\nbody\r\n\r\n</details>\r\n',
        ),
        const [
          HtmlDetailsBlock(
            summary: [TextInline('Sum')],
            children: [
              ParagraphBlock(inlines: [TextInline('body')]),
            ],
          ),
        ],
      );
      expect(_parse('\\[\r\nx^2\r\n+ y\r\n\\]\r\n'), const [
        BlockLatexBlock(expression: 'x^2\n+ y'),
      ]);
      final footnotes = _parse('Claim[^1].\r\n\r\n[^1]: The note.\r\n');
      expect(_kinds(footnotes), [ParagraphBlock, FootnoteDefinitionsBlock]);
      final definition =
          (footnotes.last as FootnoteDefinitionsBlock).definitions.single;
      expect(definition.label, '1');
      expect(definition.children, const [
        ParagraphBlock(inlines: [TextInline('The note.')]),
      ]);
      expect(_parse('See [docs][d].\r\n\r\n[d]: /docs "Title"\r\n'), const [
        ParagraphBlock(
          inlines: [
            TextInline('See '),
            LinkInline(
              destination: '/docs',
              title: 'Title',
              children: [TextInline('docs')],
            ),
            TextInline('.'),
          ],
        ),
      ]);
    });

    test('no string in the AST of a CRLF document holds a CR', () {
      const document = '''
# Title

Para with `code`, [link](https://example.com "t"), ![img](a.png "t") and
a soft break.
Hard break.

```dart info
code();

more();
```

    indented

- item
  1. nested

     para
- [ ] task

> quote
> > deeper

> [!TIP]
> tip

| a | b |
| - | - |
| 1 | 2 |

<details open>
<summary>Sum</summary>

inner

</details>

<div>
raw html
</div>

\\[
x
\\]

Inline \\(y\\) and footnote[^n] and [ref].

[ref]: /ref 'title'

[^n]: note
    continued

---
''';
      _expectNoCarriageReturn(document.replaceAll('\n', '\r\n'));
      // Sanity: the document really exercises the walker.
      expect(_kinds(_parse(document)).toSet().length, greaterThan(9));
      // Deep equality: `toString` would hide code and table cells.
      expect(_parse(document.replaceAll('\n', '\r\n')), _parse(document));
    });

    test('no string in the AST of a bare-CR document holds a CR', () {
      for (final source in [
        'one\rtwo',
        '# Title\r\rtext',
        '```dart\rcode\r```',
        '- a\r- b',
        '> a\r> b',
        'a  \rb',
        '`a\rb`',
        '[a](/u "t\rt")',
        '<details>\r<summary>S</summary>\r\rbody\r\r</details>',
        '\\[\rx\r\\]',
        '<div>\rraw\r</div>',
        'text[^1]\r\r[^1]: note\r    more',
      ]) {
        _expectNoCarriageReturn(source);
      }
    });

    test('the raw-text fallback normalises line endings', () {
      // package:markdown refuses an alert marker followed by a delimiter row.
      for (final newline in ['\r\n', '\r']) {
        final source = '> [!NOTE]$newline| --- | :-: |';
        expect(_parse(source), const [
          ParagraphBlock(inlines: [TextInline('> [!NOTE]\n| --- | :-: |')]),
        ], reason: _visible(source));
      }
    });
  });

  // gpt_markdown block/code_block_test, regression/nested_code_blocks_test.
  group('code fences', () {
    test('an empty fenced block has empty code', () {
      for (final source in ['```\n```', '```dart\n```\n', '~~~\n~~~']) {
        final block = _parse(source).single as CodeBlock;
        expect(block.code, isEmpty, reason: _visible(source));
        expect(block.closed, isTrue);
      }
    });

    test('content, blank lines and trailing spaces are kept verbatim', () {
      final block =
          _parse('```\nline1\n\n  line3  \n\n\nline6\n```').single as CodeBlock;
      expect(block.code, 'line1\n\n  line3  \n\n\nline6');
    });

    test('Markdown, HTML and entities inside a fence stay literal', () {
      const body = '**x** [a](b) <b>t</b> &amp; \\( y \\) [^1] > q\n# h';
      final block = _parse('```\n$body\n```').single as CodeBlock;
      expect(block.code, body);
    });

    test('a longer fence holds a shorter one', () {
      final block = _parse('````md\n```dart\nx\n```\n````').single as CodeBlock;
      expect(block.language, 'md');
      expect(block.code, '```dart\nx\n```');
      expect(block.closed, isTrue);
    });

    test('tilde and backtick fences hold each other', () {
      final tilde = _parse('~~~\n```\nx\n```\n~~~').single as CodeBlock;
      expect(tilde.code, '```\nx\n```');
      final backtick = _parse('```\n~~~\nx\n~~~\n```').single as CodeBlock;
      expect(backtick.code, '~~~\nx\n~~~');
    });

    test('a shorter closing fence does not close', () {
      final block = _parse('````\nx\n```\n').single as CodeBlock;
      expect(block.code, 'x\n```');
      expect(block.closed, isFalse);
    });

    test('a longer closing fence closes', () {
      final block = _parse('```\nx\n``````\nafter').first as CodeBlock;
      expect(block.code, 'x');
      expect(block.closed, isTrue);
    });

    test('a closing fence may be indented three spaces but not four', () {
      final three = _parse('```\nx\n   ```\nafter');
      expect(_kinds(three), [CodeBlock, ParagraphBlock]);
      expect((three.first as CodeBlock).closed, isTrue);
      final four = _parse('```\nx\n    ```\nafter').single as CodeBlock;
      expect(four.code, 'x\n    ```\nafter');
      expect(four.closed, isFalse);
    });

    test('a closing fence with an info string does not close', () {
      final block = _parse('```\nx\n``` dart\ny\n```').single as CodeBlock;
      expect(block.code, 'x\n``` dart\ny');
      expect(block.closed, isTrue);
    });

    test('an indented fence removes that indent from its content', () {
      final block = _parse('  ```\n  x\n    y\n z\n  ```').single as CodeBlock;
      expect(block.code, 'x\n  y\nz');
    });

    test('the language is the first word of the info string', () {
      final cases = <String, (String?, String?)>{
        '```dart': ('dart', 'dart'),
        '```  dart  ': ('dart', 'dart'),
        '``` dart linenums title="x"': ('dart', 'dart linenums title="x"'),
        '~~~c++': ('c++', 'c++'),
        '```objective-c': ('objective-c', 'objective-c'),
        '```': (null, null),
        '```   ': (null, null),
      };
      cases.forEach((opener, expected) {
        final block = _parse('$opener\nx\n```').first as CodeBlock;
        expect(block.language, expected.$1, reason: opener);
        expect(
          block.infoString == null || block.infoString!.isEmpty
              ? null
              : block.infoString,
          expected.$2,
          reason: opener,
        );
      });
    });

    test('a backtick in a backtick-fence info string means no fence', () {
      const source = '```a`b\nx';
      expect(_parse(source).whereType<CodeBlock>(), isEmpty);
      // A tilde fence may have one.
      final tilde = _parse('~~~ a`b\nx\n~~~').single as CodeBlock;
      expect(tilde.code, 'x');
      expect(tilde.language, 'a`b');
    });

    test('a fence in a list item stays in the item, without its indent', () {
      const source = '1. Run\n\n   ```sh\n   a\n\n     b\n   ```\n2. Next';
      final list = _parse(source).single as ListBlock;
      expect(list.items, hasLength(2));
      final item = list.items.first;
      expect(
        item.children.first,
        const ParagraphBlock(inlines: [TextInline('Run')]),
      );
      final code = item.children.last as CodeBlock;
      expect(code.language, 'sh');
      expect(code.code, 'a\n\n  b');
      expect(code.closed, isTrue);
      expect(extractListItemRenderedText(list.items.last), 'Next');
    });

    test('a second paragraph stays in its list item', () {
      final list =
          _parse('1. First\n\n   More.\n2. Second').single as ListBlock;
      expect(list.items, hasLength(2));
      expect(list.items.first.children, const [
        ParagraphBlock(inlines: [TextInline('First')]),
        ParagraphBlock(inlines: [TextInline('More.')]),
      ]);
    });

    test('a fence in a quote is code without the quote markers', () {
      final quote =
          _parse('> ```bash\n> echo \$A/\$B\n>\n> ls\n> ```').single
              as BlockquoteBlock;
      final code = quote.children.single as CodeBlock;
      expect(code.language, 'bash');
      expect(code.code, 'echo \$A/\$B\n\nls');
      expect(code.closed, isTrue);
    });

    test('a fence left open in a quote ends where the quote ends', () {
      final blocks = _parse('> ```\n> a\n\nafter');
      expect(_kinds(blocks), [BlockquoteBlock, ParagraphBlock]);
      final code = (blocks.first as BlockquoteBlock).children.single;
      expect((code as CodeBlock).code, 'a');
      expect(blocks.last, const ParagraphBlock(inlines: [TextInline('after')]));
    });

    // flutter_md block_test › Blockquotes (quoted fences).
    test('quoted fences: no space after the marker, tildes, nesting', () {
      final tight = _parse('>```\n>  x\n>```').single as BlockquoteBlock;
      // The marker takes one optional space with it; the second is code.
      expect((tight.children.single as CodeBlock).code, ' x');
      final tilde = _parse('> ~~~\n> hi\n> ~~~').single as BlockquoteBlock;
      expect((tilde.children.single as CodeBlock).code, 'hi');
      final nested = _parse('> > ```\n> > a `b`\n> > ```').single;
      final inner = (nested as BlockquoteBlock).children.single;
      final code = (inner as BlockquoteBlock).children.single as CodeBlock;
      expect(code.code, 'a `b`');
      expect(code.closed, isTrue);
    });

    test('a quoted fence keeps code indentation and fence-like lines', () {
      final quote =
          _parse(
                '> text\n>\n> ````\n>     deep\n> ```\n> > not a quote\n> ````',
              ).single
              as BlockquoteBlock;
      expect(
        quote.children.first,
        const ParagraphBlock(inlines: [TextInline('text')]),
      );
      final code = quote.children.last as CodeBlock;
      expect(code.code, '    deep\n```\n> not a quote');
      expect(code.closed, isTrue);
    });

    test('an alert holds a fence with its indentation', () {
      final alert =
          _parse('> [!NOTE]\n> ```py\n> if x:\n>     y()\n> ```').single
              as AlertBlock;
      final code = alert.children.single as CodeBlock;
      expect(code.language, 'py');
      expect(code.code, 'if x:\n    y()');
    });

    test('a fence nested in a list in a quote keeps its content', () {
      final quote =
          _parse('> - step\n>\n>   ```\n>   x\n>   ```').single
              as BlockquoteBlock;
      final list = quote.children.single as ListBlock;
      final code = list.items.single.children.last as CodeBlock;
      expect(code.code, 'x');
    });

    test('a code block directly followed by a list', () {
      final blocks = _parse('```\nx\n```\n- a\n- b');
      expect(_kinds(blocks), [CodeBlock, ListBlock]);
      expect((blocks.last as ListBlock).items, hasLength(2));
    });

    test('a fence interrupts a paragraph; indented code does not', () {
      expect(_kinds(_parse('text\n```\nx\n```')), [ParagraphBlock, CodeBlock]);
      expect(_parse('text\n    not code'), const [
        ParagraphBlock(
          inlines: [
            TextInline('text'),
            LineBreakInline(isHard: false),
            TextInline('not code'),
          ],
        ),
      ]);
    });

    test('indented code keeps deeper indentation and inner blank lines', () {
      final block = _parse('    a\n\n      b\n    c\n').single as CodeBlock;
      expect(block.isFenced, isFalse);
      expect(block.code, 'a\n\n  b\nc');
    });
  });

  // gpt_markdown inline/highlight_test (inline code).
  group('code spans', () {
    test('double backticks hold a single backtick', () {
      expect(_inlines('`` a`b ``'), const [InlineCodeInline('a`b')]);
      expect(_inlines('` `` `'), const [InlineCodeInline('``')]);
    });

    test('one space is stripped from each side, but not from all-space', () {
      expect(_inlines('`  a  `'), const [InlineCodeInline(' a ')]);
      expect(_inlines('a ` ` b')[1], const InlineCodeInline(' '));
      expect(_inlines('`a `'), const [InlineCodeInline('a ')]);
    });

    test('backslashes and markup inside a code span are literal', () {
      expect(_inlines(r'`a\*b`'), const [InlineCodeInline(r'a\*b')]);
      expect(_inlines('`**x** <b> &amp; foo(bar)`'), const [
        InlineCodeInline('**x** <b> &amp; foo(bar)'),
      ]);
    });

    test('a code span wins over a link around it', () {
      expect(_inlines('`[a](b)` [c](d)'), const [
        InlineCodeInline('[a](b)'),
        TextInline(' '),
        LinkInline(destination: 'd', children: [TextInline('c')]),
      ]);
      expect(_inlines('[not a `link](/u)`'), const [
        TextInline('[not a '),
        InlineCodeInline('link](/u)'),
      ]);
    });

    test('backtick runs of different lengths do not pair', () {
      expect(_inlines('``a`'), const [TextInline('``a`')]);
      expect(_inlines('`a``b`'), const [InlineCodeInline('a``b')]);
    });

    test('several code spans in one sentence', () {
      expect(_inlines('Run `a` then `b`.'), const [
        TextInline('Run '),
        InlineCodeInline('a'),
        TextInline(' then '),
        InlineCodeInline('b'),
        TextInline('.'),
      ]);
    });
  });

  // flutter_md regression_test › Link-target parsing, Link & emphasis edge
  // cases; hostile_input_test › Links; gpt_markdown links_test,
  // regression/link_with_title_test.
  group('inline links', () {
    LinkInline link(String source) =>
        _inlines(source).whereType<LinkInline>().single;

    test('the three title forms', () {
      for (final source in [
        '[t](https://x.io "the title")',
        "[t](https://x.io 'the title')",
        '[t](https://x.io (the title))',
        '[t](<https://x.io> "the title")',
        '[t](  https://x.io   "the title"  )',
      ]) {
        expect(_inlines(source), const [
          LinkInline(
            destination: 'https://x.io',
            title: 'the title',
            children: [TextInline('t')],
          ),
        ], reason: _upstream(source));
      }
    });

    test('a link without a title has a null title', () {
      expect(link('[t](https://x.io)').title, isNull);
      expect(link('[t](https://x.io "")').destination, 'https://x.io');
    });

    test('a title keeps quotes, entities and markup characters as text', () {
      final parsed = link(r'[a](/u "T &amp; <b> \"q\" *s*")');
      expect(parsed.destination, '/u');
      expect(parsed.title, 'T & <b> "q" *s*');
    });

    test('links with titles in a sentence, several per line', () {
      expect(_inlines("See [A](/a 'Title A') and [B](/b (Title B))."), const [
        TextInline('See '),
        LinkInline(
          destination: '/a',
          title: 'Title A',
          children: [TextInline('A')],
        ),
        TextInline(' and '),
        LinkInline(
          destination: '/b',
          title: 'Title B',
          children: [TextInline('B')],
        ),
        TextInline('.'),
      ]);
    });

    test('an angle-bracketed destination may hold spaces', () {
      final parsed = link('[t](<https://x.io/a b>)');
      expect(Uri.decodeFull(parsed.destination), 'https://x.io/a b');
      expect(parsed.children, const [TextInline('t')]);
    });

    test('a bare destination with a space is not a link for its label', () {
      const source = '[t](/path/a b)';
      expect(_inlines(source), const [
        TextInline(source),
      ], reason: _upstream(source));
    });

    test('balanced parentheses belong to the destination', () {
      expect(
        link('[w](https://en.wikipedia.org/wiki/A_(b))').destination,
        'https://en.wikipedia.org/wiki/A_(b)',
      );
      expect(link('[w](/a(b(c))d)').destination, '/a(b(c))d');
    });

    test('escaped parentheses and brackets', () {
      expect(link(r'[t](a\)b)').destination, 'a)b');
      expect(link(r'[t](a\(b)').destination, 'a(b');
      expect(link(r'[a\]b](https://x.io)').children, const [TextInline('a]b')]);
      expect(link(r'[a\[b](https://x.io)').children, const [TextInline('a[b')]);
    });

    test('balanced brackets in the label', () {
      expect(link('[a [b] c](/u)').children, const [TextInline('a [b] c')]);
    });

    test('an unterminated angle destination is not a link', () {
      const source = '[t](<https://x.io)';
      expect(
        _inlines(source).whereType<LinkInline>().where(
          (candidate) => candidate.children.contains(const TextInline('t')),
        ),
        isEmpty,
        reason: _upstream(source),
      );
      expect(_text(_parse(source)), source);
    });

    test('empty label and empty destination', () {
      expect(_inlines('[](/u)'), const [
        LinkInline(destination: '/u', children: []),
      ]);
      expect(_inlines('[a]()'), const [
        LinkInline(destination: '', children: [TextInline('a')]),
      ]);
    });

    test('styled labels', () {
      expect(_inlines('[**bold** *it* `code` ~~s~~](/u)'), const [
        LinkInline(
          destination: '/u',
          children: [
            StrongInline(children: [TextInline('bold')]),
            TextInline(' '),
            EmphasisInline(children: [TextInline('it')]),
            TextInline(' '),
            InlineCodeInline('code'),
            TextInline(' '),
            StrikethroughInline(children: [TextInline('s')]),
          ],
        ),
      ]);
    });

    test('emphasis around and across a link', () {
      expect(_inlines('**[d](4)**'), const [
        StrongInline(
          children: [
            LinkInline(destination: '4', children: [TextInline('d')]),
          ],
        ),
      ]);
      // Emphasis cannot start outside a link and end inside it.
      expect(link('*a [b*](/u)').children, const [TextInline('b*')]);
    });

    test('a link cannot contain another link', () {
      expect(_inlines('[a [b](/inner) c](/outer)'), const [
        TextInline('[a '),
        LinkInline(destination: '/inner', children: [TextInline('b')]),
        TextInline(' c](/outer)'),
      ]);
    });

    test('a URL in a link label is not linked a second time', () {
      expect(
        _inlines('see [https://a.com](https://b.com)')[1],
        const LinkInline(
          destination: 'https://b.com',
          children: [TextInline('https://a.com')],
        ),
      );
    });

    test('a link wrapping an image', () {
      expect(_inlines('[![alt](i.png "it")](https://x.io "lt")'), const [
        LinkInline(
          destination: 'https://x.io',
          title: 'lt',
          children: [ImageInline(source: 'i.png', alt: 'alt', title: 'it')],
        ),
      ]);
    });

    test('an image alt text is the plain text of its label', () {
      expect(_inlines('![a *b* `c` [d](/x)](i.png)'), const [
        ImageInline(source: 'i.png', alt: 'a b c d'),
      ]);
      expect(_inlines('![](i.png)'), const [ImageInline(source: 'i.png')]);
    });

    test('an escaped bang leaves a link, not an image', () {
      expect(_inlines(r'\![a](b) [c](d)'), const [
        TextInline('!'),
        LinkInline(destination: 'b', children: [TextInline('a')]),
        TextInline(' '),
        LinkInline(destination: 'd', children: [TextInline('c')]),
      ]);
    });

    test('adjacent images and links keep their order', () {
      expect(_inlines('![a](1)![b](2)[c](3)**[d](4)**'), const [
        ImageInline(source: '1', alt: 'a'),
        ImageInline(source: '2', alt: 'b'),
        LinkInline(destination: '3', children: [TextInline('c')]),
        StrongInline(
          children: [
            LinkInline(destination: '4', children: [TextInline('d')]),
          ],
        ),
      ]);
    });

    test('consecutive links on single-newline lines', () {
      expect(_inlines('[a](/1)\n[b](/2)\n[c](/3)'), const [
        LinkInline(destination: '/1', children: [TextInline('a')]),
        LineBreakInline(isHard: false),
        LinkInline(destination: '/2', children: [TextInline('b')]),
        LineBreakInline(isHard: false),
        LinkInline(destination: '/3', children: [TextInline('c')]),
      ]);
    });

    test('more labels than links resolve the right one', () {
      expect(_inlines('[x] [y] [a](/u) [z]'), const [
        TextInline('[x] [y] '),
        LinkInline(destination: '/u', children: [TextInline('a')]),
        TextInline(' [z]'),
      ]);
    });

    test('whitespace between label and destination means no link', () {
      expect(_inlines('[a] (/u)'), const [TextInline('[a] (/u)')]);
    });

    test('entities and percent-escapes in a destination', () {
      expect(link('[a](/u?a=1&amp;b=2)').destination, '/u?a=1&b=2');
      expect(link('[a](/a%20b)').destination, '/a%20b');
    });

    test('links in headings, list items, quotes and table cells', () {
      const expected = LinkInline(
        destination: '/u',
        children: [TextInline('a')],
      );
      expect((_parse('# [a](/u)').single as HeadingBlock).inlines, const [
        expected,
      ]);
      final list = _parse('- [a](/u)').single as ListBlock;
      expect(list.items.single.children, const [
        ParagraphBlock(inlines: [expected]),
      ]);
      final quote = _parse('> [a](/u)').single as BlockquoteBlock;
      expect(quote.children, const [
        ParagraphBlock(inlines: [expected]),
      ]);
      final table = _parse('| [a](/u) |\n| --- |\n| [a](/u) |').single;
      expect((table as TableBlock).header.cells.single, const [expected]);
      expect(table.rows.single.cells.single, const [expected]);
    });
  });

  group('reference links', () {
    test('full, collapsed and shortcut forms', () {
      const definition = '\n\n[Foo]: /url "T"';
      const expected = LinkInline(
        destination: '/url',
        title: 'T',
        children: [TextInline('foo')],
      );
      expect(_inlines('[foo][Foo]$definition'), const [expected]);
      expect(_inlines('[foo][]$definition'), const [expected]);
      expect(_inlines('[foo]$definition'), const [expected]);
    });

    test('labels match case-insensitively and collapse whitespace', () {
      final inlines = _inlines('[a  B][]\n\n[A b]: /u');
      expect(inlines.single, isA<LinkInline>());
      expect((inlines.single as LinkInline).destination, '/u');
    });

    test('an undefined reference stays literal', () {
      expect(_inlines('[x][y] and [z]'), const [TextInline('[x][y] and [z]')]);
    });

    test('a definition renders nothing', () {
      expect(_parse('[a]: /u\n[b]: /v "t"\n'), isEmpty);
      expect(_parse('text\n\n[a]: /u'), const [
        ParagraphBlock(inlines: [TextInline('text')]),
      ]);
    });

    test('the first of two definitions wins', () {
      final inlines = _inlines('[a]\n\n[a]: /first\n[a]: /second');
      expect((inlines.single as LinkInline).destination, '/first');
    });

    test('a definition inside a code block defines nothing', () {
      final blocks = _parse('[a]\n\n```\n[a]: /u\n```');
      expect(blocks.first, const ParagraphBlock(inlines: [TextInline('[a]')]));
      expect((blocks.last as CodeBlock).code, '[a]: /u');
    });

    test('a definition cannot interrupt a paragraph', () {
      final blocks = _parse('text\n[a]: /u\n\n[a]');
      // Rendered text shows a soft break as a space.
      expect(_text(blocks), 'text [a]: /u\n\n[a]');
      expect(_kinds(blocks), [ParagraphBlock, ParagraphBlock]);
    });

    test('reference images', () {
      expect(_inlines('![alt][i]\n\n[i]: a.png "T"'), const [
        ImageInline(source: 'a.png', alt: 'alt', title: 'T'),
      ]);
    });

    test('a multi-line definition with the title on the next line', () {
      final inlines = _inlines('[a]\n\n[a]:\n  /u\n  "T"');
      expect(inlines, const [
        LinkInline(destination: '/u', title: 'T', children: [TextInline('a')]),
      ]);
    });

    test('references resolve in every block of a long document', () {
      // The definition keeps the document in one chunk for the splitter.
      const source =
          '# [h]\n\n- [h] item\n\n> [h] quote\n\n| [h] |\n| --- |\n\n[h]: /u\n';
      final blocks = _parse(source);
      expect(_kinds(blocks), [
        HeadingBlock,
        ListBlock,
        BlockquoteBlock,
        TableBlock,
      ]);
      const expected = LinkInline(
        destination: '/u',
        children: [TextInline('h')],
      );
      expect((blocks[0] as HeadingBlock).inlines, const [expected]);
      final item = (blocks[1] as ListBlock).items.single.children.single;
      expect((item as ParagraphBlock).inlines.first, expected);
      final quoted = (blocks[2] as BlockquoteBlock).children.single;
      expect((quoted as ParagraphBlock).inlines.first, expected);
      expect((blocks[3] as TableBlock).header.cells.single, const [expected]);
    });
  });

  // gpt_markdown inline/autolink_test (parse side).
  group('autolinks', () {
    LinkInline only(String source) =>
        _inlines(source).whereType<LinkInline>().single;

    test('a bare https URL is linked', () {
      expect(_inlines('go to https://example.com now'), const [
        TextInline('go to '),
        LinkInline(
          destination: 'https://example.com',
          isAutolink: true,
          children: [TextInline('https://example.com')],
        ),
        TextInline(' now'),
      ]);
    });

    test('trailing punctuation is left outside the link', () {
      expect(_inlines('see https://example.com/a.'), const [
        TextInline('see '),
        LinkInline(
          destination: 'https://example.com/a',
          isAutolink: true,
          children: [TextInline('https://example.com/a')],
        ),
        TextInline('.'),
      ]);
      expect(
        only('really https://example.com/a?!. yes').destination,
        'https://example.com/a',
      );
      expect(
        only('a https://example.com/a, b').destination,
        'https://example.com/a',
      );
    });

    test('an unbalanced closing parenthesis is left outside', () {
      expect(
        only('link (https://example.com/a) here').destination,
        'https://example.com/a',
      );
      expect(
        only('see https://en.wikipedia.org/wiki/A_(b) here').destination,
        'https://en.wikipedia.org/wiki/A_(b)',
      );
    });

    test('a trailing entity reference is left outside', () {
      const source = 'x https://example.com/a&hl; y';
      expect(
        only(source).destination,
        'https://example.com/a',
        reason: _upstream(source),
      );
    });

    test('underscores and tildes in a path are not emphasis', () {
      const url = 'https://example.com/a_b_c/~user/d__e__f';
      expect(_inlines('see $url ok'), const [
        TextInline('see '),
        LinkInline(
          destination: url,
          isAutolink: true,
          children: [TextInline(url)],
        ),
        TextInline(' ok'),
      ]);
    });

    test('a www host is linked over http', () {
      final parsed = only('visit www.example.com today');
      expect(parsed.destination, 'http://www.example.com');
      expect(parsed.children, const [TextInline('www.example.com')]);
    });

    test('a bare email becomes a mailto link', () {
      final parsed = only('write to ada@example.com please');
      expect(parsed.destination, 'mailto:ada@example.com');
      expect(parsed.children, const [TextInline('ada@example.com')]);
    });

    test('a URL glued to a word, or an unknown bare scheme, is not linked', () {
      for (final source in ['xhttps://example.com', 'open myapp://thing now']) {
        expect(
          _inlines(source).whereType<LinkInline>(),
          isEmpty,
          reason: _upstream(source),
        );
        expect(_text(_parse(source)), source);
      }
    });

    test('angle-bracket autolinks drop the brackets', () {
      expect(
        _inlines('see <https://example.com/a?b=c> now')[1],
        const LinkInline(
          destination: 'https://example.com/a?b=c',
          isAutolink: true,
          children: [TextInline('https://example.com/a?b=c')],
        ),
      );
      final mail = only('mail <ada@example.com> now');
      expect(mail.destination, 'mailto:ada@example.com');
      expect(mail.children, const [TextInline('ada@example.com')]);
      // Any scheme is accepted inside angle brackets.
      expect(only('open <myapp://thing> now').destination, 'myapp://thing');
    });

    test('emphasis around a URL does not leak into the destination', () {
      expect(_inlines('**https://example.com/a**'), const [
        StrongInline(
          children: [
            LinkInline(
              destination: 'https://example.com/a',
              isAutolink: true,
              children: [TextInline('https://example.com/a')],
            ),
          ],
        ),
      ]);
    });

    test('a URL in code stays code', () {
      expect(
        _inlines('run `https://example.com` now')[1],
        const InlineCodeInline('https://example.com'),
      );
      final block = _parse('```\nhttps://example.com\n```').single as CodeBlock;
      expect(block.code, 'https://example.com');
    });

    test('URLs are linked in headings, lists and table cells', () {
      const url = 'https://example.com';
      const expected = LinkInline(
        destination: url,
        isAutolink: true,
        children: [TextInline(url)],
      );
      expect((_parse('# $url').single as HeadingBlock).inlines, const [
        expected,
      ]);
      final list = _parse('- $url').single as ListBlock;
      expect(list.items.single.children, const [
        ParagraphBlock(inlines: [expected]),
      ]);
      final table = _parse('| $url |\n| --- |').single as TableBlock;
      expect(table.header.cells.single, const [expected]);
    });

    test('a bare www host is flagged as an autolink like a bare URL', () {
      // Bare URLs and bare emails are flagged; the www form is the third
      // GFM extended autolink.
      expect(only('go to https://example.com now').isAutolink, isTrue);
      expect(only('write to ada@example.com please').isAutolink, isTrue);
      expect(only('visit www.example.com today').isAutolink, isTrue);
    });
  });

  // gpt_markdown regression/paragraph_line_breaks_test.
  group('line breaks', () {
    const soft = LineBreakInline(isHard: false);
    const hard = LineBreakInline();

    test('a paragraph of short lines keeps a break between each', () {
      expect(_inlines('one\ntwo\nthree'), const [
        TextInline('one'),
        soft,
        TextInline('two'),
        soft,
        TextInline('three'),
      ]);
    });

    test('two or more trailing spaces, or a backslash, break hard', () {
      for (final source in ['a  \nb', 'a     \nb', 'a\\\nb']) {
        expect(_inlines(source), const [
          TextInline('a'),
          hard,
          TextInline('b'),
        ], reason: _visible(source));
      }
    });

    test('one trailing space is a soft break without the space', () {
      expect(_inlines('a \nb'), const [TextInline('a'), soft, TextInline('b')]);
    });

    test('leading spaces on the next line are dropped', () {
      expect(_inlines('a\n   b'), const [
        TextInline('a'),
        soft,
        TextInline('b'),
      ]);
      expect(_inlines('a  \n   b'), const [
        TextInline('a'),
        hard,
        TextInline('b'),
      ]);
    });

    test('a hard-break marker at the end of a block breaks nothing', () {
      expect(_inlines('a  '), const [TextInline('a')]);
      expect(_inlines(r'a\'), const [TextInline(r'a\')]);
      expect((_parse('# a  ').single as HeadingBlock).inlines, const [
        TextInline('a'),
      ]);
    });

    test('<br> in its three spellings breaks hard', () {
      for (final tag in ['<br>', '<br/>', '<br />', '<BR>']) {
        expect(_inlines('a${tag}b'), const [
          TextInline('a'),
          hard,
          TextInline('b'),
        ], reason: tag);
      }
    });

    test('breaks inside emphasis and links stay inside', () {
      expect(_inlines('*a  \nb*'), const [
        EmphasisInline(children: [TextInline('a'), hard, TextInline('b')]),
      ]);
      expect(_inlines('[a\nb](/u)'), const [
        LinkInline(
          destination: '/u',
          children: [TextInline('a'), soft, TextInline('b')],
        ),
      ]);
    });

    test('a hard break is not recognised inside a code span', () {
      expect(_inlines('`a  \nb`'), const [InlineCodeInline('a   b')]);
      expect(_inlines('`a\\\nb`'), const [InlineCodeInline(r'a\ b')]);
    });

    test('softBreakAsHardBreak turns every soft break hard', () {
      const options = MarkdownParserOptions(softBreakAsHardBreak: true);
      final blocks = _parse(
        'one\ntwo\n\n- a\n  b\n\n> c\n> d',
        options: options,
      );
      expect(
        blocks.first,
        const ParagraphBlock(
          inlines: [TextInline('one'), hard, TextInline('two')],
        ),
      );
      final item = (blocks[1] as ListBlock).items.single.children.single;
      expect((item as ParagraphBlock).inlines, const [
        TextInline('a'),
        hard,
        TextInline('b'),
      ]);
      final quoted = (blocks[2] as BlockquoteBlock).children.single;
      expect((quoted as ParagraphBlock).inlines, const [
        TextInline('c'),
        hard,
        TextInline('d'),
      ]);
      // Code is untouched by the option.
      expect(_parse('```\na\nb\n```', options: options), const [
        CodeBlock(code: 'a\nb', isFenced: true),
      ]);
    });

    test('blank lines, however many, separate paragraphs', () {
      for (final source in [
        'a\n\nb',
        'a\n\n\n\nb',
        'a\n \t \nb',
        '\n\na\n\nb\n\n',
      ]) {
        expect(_parse(source), const [
          ParagraphBlock(inlines: [TextInline('a')]),
          ParagraphBlock(inlines: [TextInline('b')]),
        ], reason: _visible(source));
      }
    });
  });

  // flutter_md regression_test › Escape rebuilding; edge_cases › Unicode.
  group('escapes and entities', () {
    test('escaped markers stay literal', () {
      final cases = <String, String>{
        r'\*not italic\*': '*not italic*',
        r'a\\b': r'a\b',
        r'\# \! \[ \] \(': '# ! [ ] (',
        r'\*abc': '*abc',
        r'\`not code\`': '`not code`',
        r'a\_b\_c': 'a_b_c',
        r'\~\~not strike\~\~': '~~not strike~~',
        r'\<b>not html\</b>': '<b>not html</b>',
        r'\[not a link](/u)': '[not a link](/u)',
        r'price \$5 today': r'price $5 today',
        r'a \| b': 'a | b',
      };
      cases.forEach((source, expected) {
        expect(_inlines(source), [TextInline(expected)], reason: source);
      });
    });

    test('an escaped ampersand does not start an entity', () {
      // CommonMark: `\&ouml;` is the six characters `&ouml;`.
      for (final source in [r'\&amp; x', r'\&lt;b\&gt;', r'\&#42;']) {
        expect(_inlines(source), [
          TextInline(source.replaceAll(r'\', '')),
        ], reason: _upstream(source));
      }
    });

    test('an entity is decoded exactly once', () {
      // `&amp;lt;` is how a reply spells the text "&lt;".
      final cases = <String, String>{
        '&amp;amp;': '&amp;',
        'write &amp;lt;b&amp;gt; for bold': 'write &lt;b&gt; for bold',
        '&amp;#42;': '&#42;',
      };
      cases.forEach((source, expected) {
        expect(_inlines(source), [
          TextInline(expected),
        ], reason: _upstream(source));
      });
      final table = _parse('| &amp;amp; |\n| --- |').single as TableBlock;
      expect(table.header.cells.single, const [TextInline('&amp;')]);
      expect(_inlines('<b>&amp;lt;</b>'), const [
        StrongInline(children: [TextInline('&lt;')]),
      ]);
    });

    test('a backslash before a letter, digit or space is kept', () {
      for (final source in [r'C:\Users\me', r'a\1', r'a\ b', r'\é']) {
        expect(_inlines(source), [TextInline(source)], reason: source);
      }
    });

    test('an escape followed by real emphasis', () {
      expect(_inlines(r'\* *italic*'), const [
        TextInline('* '),
        EmphasisInline(children: [TextInline('italic')]),
      ]);
    });

    test('escaped block markers start a paragraph, not a block', () {
      final cases = <String, String>{
        r'\# not a heading': '# not a heading',
        r'\> not a quote': '> not a quote',
        r'\- not a list': '- not a list',
        r'1\. not a list': '1. not a list',
        r'\```': '```',
        r'\---': '---',
        r'\| a | b |': '| a | b |',
      };
      cases.forEach((source, expected) {
        expect(_parse(source), [
          ParagraphBlock(inlines: [TextInline(expected)]),
        ], reason: source);
      });
    });

    test('entities decode to text and never start markup', () {
      final cases = <String, String>{
        '&lt;b&gt;x&lt;/b&gt;': '<b>x</b>',
        '&#42;not em&#42;': '*not em*',
        '&#x2A;not em&#x2a;': '*not em*',
        '&quot;q&quot; &apos;a&apos;': '"q" \'a\'',
        'a&nbsp;b': 'a\u00A0b',
        '&copy; 2026': '\u00A9 2026',
        '&#0;': '\uFFFD',
        'AT&T, a & b, &;, &x, &#;, &#x;': 'AT&T, a & b, &;, &x, &#;, &#x;',
      };
      cases.forEach((source, expected) {
        expect(_inlines(source), [TextInline(expected)], reason: source);
      });
    });
  });

  // flutter_md edge_cases_test › Unicode & emoji; gpt_markdown bold/italic/
  // strikethrough tests. `__x__` is strong and `~x~` is strikethrough here.
  group('emphasis', () {
    test('GFM semantics for underscores and tildes', () {
      expect(_inlines('__text__'), const [
        StrongInline(children: [TextInline('text')]),
      ]);
      expect(_inlines('_text_'), const [
        EmphasisInline(children: [TextInline('text')]),
      ]);
      expect(_inlines('~x~ and ~~y~~'), const [
        StrikethroughInline(children: [TextInline('x')]),
        TextInline(' and '),
        StrikethroughInline(children: [TextInline('y')]),
      ]);
    });

    test('three or more tildes do not strike', () {
      // GFM 6.5: "Three or more tildes do not create a strikethrough."
      const source = 'a ~~~x~~~ b';
      expect(_inlines(source), const [
        TextInline(source),
      ], reason: _upstream(source));
    }, skip: 'package:markdown 7.3.1 emits a nested strikethrough for ~~~x~~~');

    test('strong and emphasis together', () {
      expect(_inlines('***both***'), const [
        EmphasisInline(
          children: [
            StrongInline(children: [TextInline('both')]),
          ],
        ),
      ]);
      expect(_inlines('**bold *it* bold**'), const [
        StrongInline(
          children: [
            TextInline('bold '),
            EmphasisInline(children: [TextInline('it')]),
            TextInline(' bold'),
          ],
        ),
      ]);
      expect(_inlines('**first** and **second**'), const [
        StrongInline(children: [TextInline('first')]),
        TextInline(' and '),
        StrongInline(children: [TextInline('second')]),
      ]);
    });

    test('strong emphasis may span a soft line break', () {
      expect(_inlines('x **a\nb** y'), const [
        TextInline('x '),
        StrongInline(
          children: [
            TextInline('a'),
            LineBreakInline(isHard: false),
            TextInline('b'),
          ],
        ),
        TextInline(' y'),
      ]);
      // A closer at the start of the next line is not right-flanking.
      expect(_inlines('**a\n** b').whereType<StrongInline>(), isEmpty);
    });

    test('underscores inside words are not emphasis', () {
      for (final source in [
        'snake_case_name',
        'переменная_значение_тут',
        '日本_語_です',
        'a__b__c',
        '2 * 3 * 4',
        'a * b * c',
      ]) {
        expect(_inlines(source), [TextInline(source)], reason: source);
      }
    });

    test('stars inside words are emphasis', () {
      expect(_inlines('a*b*c'), const [
        TextInline('a'),
        EmphasisInline(children: [TextInline('b')]),
        TextInline('c'),
      ]);
    });

    test('emphasis around non-ASCII text', () {
      expect(_inlines('Привет **мир**'), const [
        TextInline('Привет '),
        StrongInline(children: [TextInline('мир')]),
      ]);
      expect(_inlines('**太字**です'), const [
        StrongInline(children: [TextInline('太字')]),
        TextInline('です'),
      ]);
      expect(_inlines('Hello 👋 *world* 🌍'), const [
        TextInline('Hello 👋 '),
        EmphasisInline(children: [TextInline('world')]),
        TextInline(' 🌍'),
      ]);
    });

    test(
      'an opener followed by a space, or a closer after one, is literal',
      () {
        for (final source in [
          'a ** b ** c',
          '**bold **',
          '** bold**',
          '_ a _',
        ]) {
          expect(_inlines(source), [TextInline(source)], reason: source);
        }
      },
    );

    test('markers other engines support stay literal here', () {
      // flutter_md highlight/spoiler, gpt_markdown radio buttons.
      for (final source in [
        '==highlight==',
        '||spoiler||',
        '( ) Unchecked option',
        '(x) Checked option',
        '[ ] bare checkbox',
        '[x] bare checkbox',
        '^sup^ and H2O',
      ]) {
        expect(_inlines(source), [TextInline(source)], reason: source);
      }
    });
  });

  // flutter_md regression_test › List-line parsing; gfm_test › Thematic
  // breaks; gpt_markdown block/ordered_list, unordered_list, headings,
  // horizontal_rule, blockquote, indent.
  group('block markers', () {
    test('ordered list markers and start numbers', () {
      final dot = _parse('1. one\n2. two').single as ListBlock;
      expect(dot.ordered, isTrue);
      expect(dot.start, 1);
      expect(dot.items, hasLength(2));
      final paren = _parse('1) one\n2) two').single as ListBlock;
      expect(paren.ordered, isTrue);
      expect(paren.items, hasLength(2));
      expect((_parse('100. Item 100').single as ListBlock).start, 100);
      expect((_parse('0. zero').single as ListBlock).start, 0);
      expect((_parse('123456789. item').single as ListBlock).start, 123456789);
      // Later numbers are ignored.
      final odd = _parse('3. a\n1. b\n7. c').single as ListBlock;
      expect(odd.start, 3);
      expect(odd.items, hasLength(3));
    });

    test('what is not a list', () {
      for (final source in [
        '1234567890. ten digits',
        '-no space',
        '1.no space',
        '-> arrow',
        '1st place and 2nd place',
        '+1 for this',
        '-1 is negative',
      ]) {
        expect(_parse(source), [
          ParagraphBlock(inlines: [TextInline(source)]),
        ], reason: source);
      }
      expect(_parse('*emphasis here*'), const [
        ParagraphBlock(
          inlines: [
            EmphasisInline(children: [TextInline('emphasis here')]),
          ],
        ),
      ]);
      expect(_parse('_italic_ at the start'), const [
        ParagraphBlock(
          inlines: [
            EmphasisInline(children: [TextInline('italic')]),
            TextInline(' at the start'),
          ],
        ),
      ]);
    });

    test('the three bullet characters', () {
      for (final marker in ['-', '*', '+']) {
        final list = _parse('$marker a\n$marker b').single as ListBlock;
        expect(list.ordered, isFalse, reason: marker);
        expect(list.items.map(extractListItemRenderedText), ['a', 'b']);
      }
    });

    test('a change of marker starts a new list', () {
      final bullets = _parse('- Dash item\n* Asterisk item');
      expect(_kinds(bullets), [ListBlock, ListBlock]);
      final ordered = _parse('1. a\n2) b');
      expect(_kinds(ordered), [ListBlock, ListBlock]);
      expect((ordered.last as ListBlock).start, 2);
    });

    test('tight and loose lists', () {
      expect((_parse('- a\n- b').single as ListBlock).tight, isTrue);
      expect((_parse('- a\n\n- b').single as ListBlock).tight, isFalse);
      expect((_parse('- a\n  - b\n- c').single as ListBlock).tight, isTrue);
    });

    test('nested items follow the indent of their parent content', () {
      final list = _parse('- a\n  - b\n    - c\n- d').single as ListBlock;
      expect(list.items, hasLength(2));
      final b = list.items.first.children.last as ListBlock;
      expect(extractBlockRenderedText(b.items.single.children.first), 'b');
      final c = b.items.single.children.last as ListBlock;
      expect(extractListItemRenderedText(c.items.single), 'c');
      // Under an ordered marker the content starts three columns in.
      final ordered = _parse('1. a\n   - b\n2. c').single as ListBlock;
      expect(ordered.items, hasLength(2));
      expect(ordered.items.first.children.last, isA<ListBlock>());
    });

    test('only a list starting at 1 interrupts a paragraph', () {
      expect(_kinds(_parse('text\n1. one')), [ParagraphBlock, ListBlock]);
      expect(_kinds(_parse('text\n- item')), [ParagraphBlock, ListBlock]);
      expect(_parse('text\n2. two'), const [
        ParagraphBlock(
          inlines: [
            TextInline('text'),
            LineBreakInline(isHard: false),
            TextInline('2. two'),
          ],
        ),
      ]);
    });

    test('list items hold inline markup', () {
      final list =
          _parse('1. **Bold** item\n2. Use `code` here\n3. *it*').single
              as ListBlock;
      expect(
        list.items[0].children.single,
        const ParagraphBlock(
          inlines: [
            StrongInline(children: [TextInline('Bold')]),
            TextInline(' item'),
          ],
        ),
      );
      expect(
        list.items[1].children.single,
        const ParagraphBlock(
          inlines: [
            TextInline('Use '),
            InlineCodeInline('code'),
            TextInline(' here'),
          ],
        ),
      );
    });

    test('headings: levels, spacing and closing hashes', () {
      for (var level = 1; level <= 6; level++) {
        expect(_parse('${'#' * level} Heading $level'), [
          HeadingBlock(level: level, inlines: [TextInline('Heading $level')]),
        ]);
      }
      expect(_parse('#Title'), const [
        ParagraphBlock(inlines: [TextInline('#Title')]),
      ]);
      expect(_parse('## Title ##'), const [
        HeadingBlock(level: 2, inlines: [TextInline('Title')]),
      ]);
      expect(_parse('# Title #not'), const [
        HeadingBlock(level: 1, inlines: [TextInline('Title #not')]),
      ]);
      expect(_parse(r'# C\#'), const [
        HeadingBlock(level: 1, inlines: [TextInline('C#')]),
      ]);
      expect(_parse('   ### Indented'), const [
        HeadingBlock(level: 3, inlines: [TextInline('Indented')]),
      ]);
      final empty = _parse('#').single as HeadingBlock;
      expect(empty.level, 1);
      expect(empty.inlines, isEmpty);
    });

    test('headings hold inline markup and need no blank line around', () {
      expect(_parse('# **Bold** `code` *it*'), const [
        HeadingBlock(
          level: 1,
          inlines: [
            StrongInline(children: [TextInline('Bold')]),
            TextInline(' '),
            InlineCodeInline('code'),
            TextInline(' '),
            EmphasisInline(children: [TextInline('it')]),
          ],
        ),
      ]);
      expect(_kinds(_parse('text\n# First\n## Second\nmore')), [
        ParagraphBlock,
        HeadingBlock,
        HeadingBlock,
        ParagraphBlock,
      ]);
    });

    test('setext headings', () {
      expect(_parse('Title\n=\n\nSub *it*\n---'), const [
        HeadingBlock(level: 1, inlines: [TextInline('Title')]),
        HeadingBlock(
          level: 2,
          inlines: [
            TextInline('Sub '),
            EmphasisInline(children: [TextInline('it')]),
          ],
        ),
      ]);
      // Without text above it, `===` is a paragraph and `---` a rule.
      expect(_parse('==='), const [
        ParagraphBlock(inlines: [TextInline('===')]),
      ]);
    });

    test('thematic breaks', () {
      for (final source in [
        '---',
        '***',
        '___',
        '- - -',
        '* * *',
        '_ _ _',
        '----------',
        '   ---',
        '--- ',
        ' *  *  * ',
      ]) {
        expect(_parse(source), const [ThematicBreakBlock()], reason: source);
      }
      expect(_parse('Above\n\n---\n\nBelow'), const [
        ParagraphBlock(inlines: [TextInline('Above')]),
        ThematicBreakBlock(),
        ParagraphBlock(inlines: [TextInline('Below')]),
      ]);
      expect(_parse('---\n\n---'), const [
        ThematicBreakBlock(),
        ThematicBreakBlock(),
      ]);
      // `***` interrupts a paragraph; `---` under text is a setext heading.
      expect(_kinds(_parse('Above\n***\nBelow')), [
        ParagraphBlock,
        ThematicBreakBlock,
        ParagraphBlock,
      ]);
    });

    test('what is not a thematic break', () {
      for (final source in ['--', '**', '__', '----text', '-*-', '⸻', '—--']) {
        expect(
          _parse(source).whereType<ThematicBreakBlock>(),
          isEmpty,
          reason: source,
        );
      }
      final code = _parse('    ---').single as CodeBlock;
      expect(code.code, '---');
    });

    test('blockquotes: lazy lines, separate quotes, inline markup', () {
      expect(_parse('> Line 1\nlazy line'), const [
        BlockquoteBlock(
          children: [
            ParagraphBlock(
              inlines: [
                TextInline('Line 1'),
                LineBreakInline(isHard: false),
                TextInline('lazy line'),
              ],
            ),
          ],
        ),
      ]);
      expect(_kinds(_parse('> Quote 1\n\n> Quote 2')), [
        BlockquoteBlock,
        BlockquoteBlock,
      ]);
      final styled = _parse('>**Bold** `code` *it*').single as BlockquoteBlock;
      expect(extractBlockRenderedText(styled.children.single), 'Bold code it');
      final blocks = _parse('> # H\n> - a\n> - b\n>\n> text').single;
      expect(_kinds((blocks as BlockquoteBlock).children), [
        HeadingBlock,
        ListBlock,
        ParagraphBlock,
      ]);
    });

    test('indentation: up to three spaces is prose, four is code', () {
      expect(_parse('  Indented **bold**\n  Line 2'), const [
        ParagraphBlock(
          inlines: [
            TextInline('Indented '),
            StrongInline(children: [TextInline('bold')]),
            LineBreakInline(isHard: false),
            TextInline('Line 2'),
          ],
        ),
      ]);
      final code = _parse('    More indented').single as CodeBlock;
      expect(code.isFenced, isFalse);
      expect(code.code, 'More indented');
    });

    test('the document keeps its source', () {
      const source = '# Title\r\n\r\nBody with **bold**.\n';
      expect(GfmMarkdownParser().parse(source).source, source);
    });
  });
}
