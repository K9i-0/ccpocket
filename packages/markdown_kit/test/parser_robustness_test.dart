import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_kit/markdown_kit.dart';

/// Line fragments that exercise every block construct the splitter has to
/// reason about. Random documents are assembled from these.
const _lines = <String>[
  '',
  '',
  '',
  'plain paragraph text',
  'second line with **bold** and `code`',
  '日本語の段落です。絵文字👨‍👩‍👧も含む',
  '# Heading',
  '## Heading two',
  'Setext heading',
  '===',
  '---',
  '***',
  '- item one',
  '- item two',
  '* star item',
  '+ plus item',
  '1. ordered one',
  '2. ordered two',
  '1) paren ordered',
  '- [ ] todo',
  '- [x] done',
  '  continuation indented two',
  '    indented four',
  '\tindented tab',
  '  - nested item',
  '    - deeper item',
  '> quote line',
  '> - quoted list',
  '>',
  '> [!NOTE]',
  'lazy continuation',
  '```',
  '```dart',
  '````',
  '~~~',
  '  ```',
  'final x = 1;',
  '| a | b |',
  '| --- | :-: |',
  '| 1 | 2 |',
  '<details>',
  '<summary>Sum</summary>',
  '</details>',
  '<div>',
  '</div>',
  '<br>',
  'text with <b>bold</b> html',
  r'\[',
  r'\]',
  r'\[ x^2 \]',
  r'$$',
  r'inline \(a+b\) math',
  'a [link](https://example.com) here',
  '![img](https://example.com/a.png)',
  'footnote ref[^1]',
  'trailing spaces  ',
  r'backslash\',
];

final _rawHtmlLine = RegExp(r'^<', multiLine: true);

String _randomDocument(Random random) {
  final count = 1 + random.nextInt(12);
  final buffer = StringBuffer();
  for (var i = 0; i < count; i++) {
    buffer.write(_lines[random.nextInt(_lines.length)]);
    if (i < count - 1 || random.nextBool()) buffer.write('\n');
  }
  return buffer.toString();
}

String _renderStandard(String source) {
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ).parse(source);
  return md.renderToHtml(nodes);
}

String _visible(String source) => source.replaceAll('\n', r'\n');

void main() {
  const iterations = 4000;

  test('splitMarkdownBlocks chunks always join back to the source', () {
    final random = Random(20261126);
    for (var i = 0; i < iterations; i++) {
      final source = _randomDocument(random);
      expect(
        splitMarkdownBlocks(source).join(),
        source,
        reason: _visible(source),
      );
    }
  });

  test('parsing chunk by chunk matches parsing the whole document', () {
    final random = Random(42);
    final failures = <String>[];
    for (var i = 0; i < iterations; i++) {
      final source = _randomDocument(random);
      // package:markdown renders raw HTML blocks differently depending on what
      // precedes them, so they cannot be compared through its own renderer.
      if (_rawHtmlLine.hasMatch(source)) continue;
      final chunks = splitMarkdownBlocks(source);
      if (chunks.length < 2) continue;
      final String whole;
      try {
        whole = _renderStandard(source);
      } on AssertionError {
        // package:markdown rejects a few inputs outright; see the fallback
        // test below.
        continue;
      }
      final pieces = chunks
          .map(_renderStandard)
          .where((html) => html.isNotEmpty)
          .join('\n');
      if (pieces != whole) failures.add(source);
    }
    failures.sort((a, b) => a.length.compareTo(b.length));
    expect(failures.take(5).map(_visible).toList(), isEmpty);
  });

  test('streaming every prefix never throws and converges', () {
    final random = Random(7);
    for (var i = 0; i < 600; i++) {
      final source = '${_randomDocument(random)}\n';
      final streaming = GfmMarkdownParser();
      MarkdownDocument? last;
      for (var end = 1; end <= source.length; end++) {
        final prefix = source.substring(0, end);
        last = streaming.parse(prefix, isStreaming: true);
        final fresh = GfmMarkdownParser().parse(prefix, isStreaming: true);
        expect(last.blocks, fresh.blocks, reason: _visible(prefix));
      }
      // While streaming, unfinished syntax at the end may still be held. The
      // finished reply is parsed without the flag, on the same parser.
      last = streaming.parse(source);
      final complete = GfmMarkdownParser().parse(source);
      expect(last.blocks, complete.blocks, reason: _visible(source));
    }
  });

  test('falls back to raw text when package:markdown refuses the input', () {
    // An alert marker directly followed by a table delimiter row trips the
    // "BlockParser.parseLines is not advancing" guard inside package:markdown.
    const source = '> [!NOTE]\n| --- | :-: |';
    for (final isStreaming in [false, true]) {
      final document = GfmMarkdownParser().parse(
        source,
        isStreaming: isStreaming,
      );
      expect(document.blocks, const [
        ParagraphBlock(inlines: [TextInline(source)]),
      ]);
    }

    final mixed = GfmMarkdownParser().parse('Before\n\n$source\n\nAfter');
    expect(mixed.blocks, const [
      ParagraphBlock(inlines: [TextInline('Before')]),
      ParagraphBlock(inlines: [TextInline(source)]),
      ParagraphBlock(inlines: [TextInline('After')]),
    ]);
  });

  test('only the rejected part falls back when splitting is disabled', () {
    // The footnote definition keeps the document in a single chunk, so the
    // whole message used to degrade to raw text.
    const rejected = '> [!NOTE]\n| --- | :-: |';
    final document = GfmMarkdownParser().parse(
      '# Title\n\n$rejected\n\nSome **bold** text[^1].\n\n[^1]: note\n',
    );
    expect(document.blocks.take(3), const [
      HeadingBlock(level: 1, inlines: [TextInline('Title')]),
      ParagraphBlock(inlines: [TextInline(rejected)]),
      ParagraphBlock(
        inlines: [
          TextInline('Some '),
          StrongInline(children: [TextInline('bold')]),
          TextInline(' text'),
          // Footnotes are not numbered across the isolated pieces.
          FootnoteRefInline(label: '1'),
          TextInline('.'),
        ],
      ),
    ]);
  });

  test('raw HTML blocks keep no stray blank lines and hide comments', () {
    final parser = GfmMarkdownParser();
    expect(
      parser.parse('<div align="center">\n\n# Title\n</div>\n\nafter').blocks,
      const [
        ParagraphBlock(inlines: [TextInline('<div align="center">')]),
        HeadingBlock(level: 1, inlines: [TextInline('Title')]),
        ParagraphBlock(inlines: [TextInline('</div>')]),
        ParagraphBlock(inlines: [TextInline('after')]),
      ],
    );
    expect(
      parser
          .parse('<!-- hidden note -->\ntext\n\n<!--\nmulti\nline\n-->')
          .blocks,
      const [
        ParagraphBlock(inlines: [TextInline('text')]),
      ],
    );
  });

  group('whitespace package:markdown leaves at line edges', () {
    List<MarkdownInline> firstItem(String source) {
      final list = GfmMarkdownParser().parse(source).blocks.single as ListBlock;
      return (list.items.first.children.first as ParagraphBlock).inlines;
    }

    test('extra spaces after a list marker do not indent the text', () {
      expect(firstItem('-   item'), const [TextInline('item')]);
      expect(firstItem('1.  item'), const [TextInline('item')]);
    });

    test('an indented continuation line joins with a single break', () {
      final document = GfmMarkdownParser().parse(
        'first line \n    second line',
      );
      expect(document.blocks, const [
        ParagraphBlock(
          inlines: [
            TextInline('first line'),
            LineBreakInline(isHard: false),
            TextInline('second line'),
          ],
        ),
      ]);
      expect(extractDocumentRenderedText(document), 'first line second line');
    });

    test('indentation before inline markup at a line start is dropped', () {
      expect(GfmMarkdownParser().parse('  *a*\n  **b** c').blocks, const [
        ParagraphBlock(
          inlines: [
            EmphasisInline(children: [TextInline('a')]),
            LineBreakInline(isHard: false),
            StrongInline(children: [TextInline('b')]),
            TextInline(' c'),
          ],
        ),
      ]);
    });

    test('spaces inside a line and inside inline HTML are kept', () {
      expect(GfmMarkdownParser().parse('a  b<b> c</b>').blocks, const [
        ParagraphBlock(
          inlines: [
            TextInline('a  b'),
            StrongInline(children: [TextInline(' c')]),
          ],
        ),
      ]);
    });

    test('a paragraph holding only <br> stays a spacer', () {
      expect(GfmMarkdownParser().parse('<br>').blocks, const [
        ParagraphBlock(inlines: [LineBreakInline(isHard: true)]),
      ]);
    });
  });

  group('reference definitions keep the document in one chunk', () {
    test('with an escaped bracket in the label', () {
      const source = '[a\\]]: /url\n\n[a\\]]\n';
      expect(splitMarkdownBlocks(source), [source]);
      final paragraph =
          GfmMarkdownParser().parse(source).blocks.single as ParagraphBlock;
      expect(paragraph.inlines.single, isA<LinkInline>());
    });

    test('inside a block quote', () {
      const source = '[foo]\n\n> [foo]: /url\n';
      expect(splitMarkdownBlocks(source), [source]);
      final paragraph =
          GfmMarkdownParser().parse(source).blocks.first as ParagraphBlock;
      expect(paragraph.inlines.single, isA<LinkInline>());
    });
  });

  group('a fence beside a list', () {
    String standardHtml(String source) => md.renderToHtml(
      md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      ).parse(source),
    );

    void expectChunksMatchWhole(String source) {
      final pieces = splitMarkdownBlocks(source)
          .map(standardHtml)
          .where((html) => html.isNotEmpty)
          .join('\n');
      expect(pieces, standardHtml(source), reason: _visible(source));
    }

    test('shallower than the item content column is not inside the item', () {
      // The fence ends the list, so unindented code with a blank line in it
      // must stay one block.
      expectChunksMatchWhole(
        '1. item\n  ```\ncode at zero\n\nmore code\n  ```\n\nafter\n',
      );
      expectChunksMatchWhole(
        '- item\n\n ```\ncode at zero\n\nmore code\n ```\n\nafter\n',
      );
    });

    test('at the item content column belongs to the item', () {
      expectChunksMatchWhole(
        '- item\n  ```\n  code\n\n  more\n  ```\n\nafter\n',
      );
      expectChunksMatchWhole(
        '10. item\n    ```\n    code\n\n    more\n    ```\n\nafter\n',
      );
    });

    test('left open by the end of its item does not swallow what follows', () {
      expectChunksMatchWhole(
        '- item\n  ```\n  code\nparagraph\n\n```\nreal\n\ncode\n```\n',
      );
    });
  });

  group('a trailing backslash while streaming', () {
    test('is held until the next character arrives', () {
      expect(sanitizeStreamingTail('[1] the formula \\'), '[1] the formula ');
      expect(sanitizeStreamingTail('a \\\\'), 'a \\\\');
      expect(sanitizeStreamingTail('line\\\n'), 'line\\\n');
    });

    test('is shown inside an open code fence', () {
      expect(sanitizeStreamingTail('```\npath\\'), '```\npath\\');
    });

    test('does not degrade a paragraph that starts with a bracket', () {
      final parser = GfmMarkdownParser();
      const source = '[1] the formula \\(x\\) holds';
      for (var end = 1; end <= source.length; end++) {
        parser.parse(source.substring(0, end), isStreaming: true);
      }
      expect(parser.rawTextFallbackCount, 0);
    });
  });

  test('pathological inputs parse within a bounded time', () {
    final inputs = <String, String>{
      'open brackets': '[' * 20000,
      'backticks': '`' * 20000,
      'stars': '*a ' * 10000,
      'underscores': '_' * 20000,
      'nested quotes': '${'> ' * 500}deep',
      'nested lists': [for (var i = 0; i < 200; i++) '${'  ' * i}- item']
          .join('\n'),
      'html opens': '<b>' * 5000,
      'html mixed': '<b><i><u>' * 2000 + '</u></i></b>' * 2000,
      'long line': 'word ' * 60000,
      'latex opens': r'\(' * 2000,
      'footnote refs': '[^a]' * 5000,
      'pipes': '${'|' * 5000}\n${'|-' * 2500}|\n${'|' * 5000}',
      'details opens': '<details>\n' * 300,
      'entities': '&amp;' * 20000,
      'comments': '${'<!-- a -->' * 5000}x',
      'comment opens': '<!-- a ' * 5000,
      'many paragraphs': 'para\n\n' * 20000,
    };
    inputs.forEach((name, input) {
      final watch = Stopwatch()..start();
      GfmMarkdownParser().parse(input);
      GfmMarkdownParser().parse(input, isStreaming: true);
      watch.stop();
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)), reason: name);
    });
  });
}
