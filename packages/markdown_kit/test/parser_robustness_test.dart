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
      final complete = GfmMarkdownParser().parse(source);
      expect(last!.blocks, complete.blocks, reason: _visible(source));
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

  test('pathological inputs parse within a bounded time', () {
    final inputs = <String, String>{
      'open brackets': '[' * 20000,
      'backticks': '`' * 20000,
      'stars': '*a ' * 10000,
      'underscores': '_' * 20000,
      'nested quotes': '${'> ' * 500}deep',
      'nested lists': [
        for (var i = 0; i < 200; i++) '${'  ' * i}- item',
      ].join('\n'),
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
