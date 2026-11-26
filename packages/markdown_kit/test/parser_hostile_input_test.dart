// Adversarial input for the parser: unterminated constructs, deep nesting,
// large inputs, control characters, NUL, lone surrogates, tabs.
//
// The behaviours were mined from the flutter_md (edge_cases_test,
// hostile_input_test) and gpt_markdown (fuzz_findings_test) suites and
// rewritten against the markdown_kit AST. `GfmMarkdownParser.parse` never
// throws by contract, so "does not throw" alone proves little: every case
// also pins the structure the input must keep.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_kit/markdown_kit.dart';

List<MarkdownBlock> _parse(String source, {bool isStreaming = false}) =>
    GfmMarkdownParser().parse(source, isStreaming: isStreaming).blocks;

/// What plain `package:markdown` makes of [source], shown next to a failure
/// so an upstream result can be told apart from a markdown_kit one.
String _upstream(String source) {
  try {
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ).parse(source);
    return 'upstream: ${_visible(md.renderToHtml(nodes))}';
  } catch (error) {
    return 'upstream throws ${error.runtimeType}';
  }
}

String _visible(String source) => source
    .replaceAll('\r', r'\r')
    .replaceAll('\n', r'\n')
    .replaceAll('\t', r'\t')
    .replaceAll('\u0000', r'\0');

String _text(List<MarkdownBlock> blocks) =>
    blocks.map(extractBlockRenderedText).join('\n\n');

List<Type> _kinds(List<MarkdownBlock> blocks) => [
  for (final block in blocks) block.runtimeType,
];

/// Walks every part of the AST a renderer or the selection engine touches.
/// A stack overflow here counts even when `parse` returned.
void _exercise(List<MarkdownBlock> blocks) {
  for (final block in blocks) {
    block.toString();
    block.hashCode;
    expect(block == block, isTrue);
    extractBlockRenderedText(block);
  }
}

/// Whether [blocks] is the raw-text fallback for [source]: one paragraph
/// holding the whole trimmed source as literal text.
bool _isRawFallback(List<MarkdownBlock> blocks, String source) {
  if (blocks.length != 1) return false;
  final block = blocks.single;
  if (block is! ParagraphBlock || block.inlines.length != 1) return false;
  final inline = block.inlines.single;
  return inline is TextInline &&
      inline.text == source.replaceAll('\r\n', '\n').trim();
}

void main() {
  // flutter_md edge_cases_test › Does not crash on pathological input
  group('unterminated and degenerate constructs', () {
    test('whitespace-only and newline-only input has no blocks', () {
      for (final source in ['   \t  ', '\n\n\n', ' \n \n', '\r\n\r\n', '\t']) {
        for (final isStreaming in [false, true]) {
          expect(
            _parse(source, isStreaming: isStreaming),
            isEmpty,
            reason: _visible(source),
          );
        }
      }
    });

    test('an unterminated backtick fence is an open code block', () {
      final block = _parse('```dart\nvoid main() {}').single as CodeBlock;
      expect(block.isFenced, isTrue);
      expect(block.closed, isFalse);
      expect(block.language, 'dart');
      expect(block.code, 'void main() {}');
    });

    test('an unterminated tilde fence is an open code block', () {
      final block = _parse('~~~\ncode').single as CodeBlock;
      expect(block.isFenced, isTrue);
      expect(block.closed, isFalse);
      expect(block.language, isNull);
      expect(block.code, 'code');
    });

    test('a fence opener alone is an empty open code block', () {
      for (final source in ['```', '```\n', '~~~~', '```dart\n']) {
        final block = _parse(source).single as CodeBlock;
        expect(block.code, isEmpty, reason: _visible(source));
        expect(block.closed, isFalse, reason: _visible(source));
      }
    });

    test('an unterminated inline link keeps every character', () {
      const source = '[label](http://x.com';
      final blocks = _parse(source);
      expect(_kinds(blocks), [ParagraphBlock]);
      expect(_text(blocks), source, reason: _upstream(source));
    });

    test('an unterminated image keeps every character', () {
      const source = '![alt](';
      final blocks = _parse(source);
      expect(blocks, const [
        ParagraphBlock(inlines: [TextInline(source)]),
      ], reason: _upstream(source));
    });

    test('an unclosed bracket before a real link stays literal', () {
      const source = '[unclosed and [real](http://x.com)';
      final paragraph = _parse(source).single as ParagraphBlock;
      expect(paragraph.inlines, const [
        TextInline('[unclosed and '),
        LinkInline(destination: 'http://x.com', children: [TextInline('real')]),
      ], reason: _upstream(source));
    });

    test('unclosed emphasis, strong, strike and code stay literal', () {
      for (final source in [
        '**unclosed bold',
        '*unclosed italic',
        '~~unclosed strike',
        '`unclosed code',
        '__unclosed',
        '_unclosed',
        'a ** b',
        'trailing **',
      ]) {
        expect(_parse(source), [
          ParagraphBlock(inlines: [TextInline(source)]),
        ], reason: '${_visible(source)} ${_upstream(source)}');
      }
    });

    test('a long run of one delimiter stays literal', () {
      for (final char in ['_', '~', '=', '|', '^', '\$', '[', ']', '(']) {
        final source = 'a${char * 200}b';
        expect(_parse(source), [
          ParagraphBlock(inlines: [TextInline(source)]),
        ], reason: char);
      }
      // A run of `*` or `-` alone on a line is a thematic break, so it is
      // wrapped in letters here to stay inline.
      expect(_text(_parse('a${'*' * 200}b')), 'a${'*' * 200}b');
      expect(_text(_parse('a${'`' * 200}b')), 'a${'`' * 200}b');
    });

    test('more than six hashes is a paragraph, not a heading', () {
      expect(_parse('#############'), const [
        ParagraphBlock(inlines: [TextInline('#############')]),
      ]);
      expect(_parse('####### seven'), const [
        ParagraphBlock(inlines: [TextInline('####### seven')]),
      ]);
    });

    test('every ASCII punctuation character at once keeps its text', () {
      // `\{` is a backslash escape, so the backslash is consumed. `()[]` is
      // written in that order because `![]()` is a valid (empty) image.
      const source = r'x *_~=|`#>-+.!()[]\{}';
      final blocks = _parse(source);
      expect(_kinds(blocks), [ParagraphBlock]);
      expect(_text(blocks), 'x *_~=|`#>-+.!()[]{}', reason: _upstream(source));
    });

    test('a backslash at the end of the input is literal', () {
      expect(_text(_parse(r'text\')), r'text\');
      expect(_text(_parse(r'\')), r'\');
      expect(_text(_parse('text\\\n')), r'text\');
    });

    test('nested quotes without spaces nest three deep', () {
      const source = '> outer\n>> inner\n>>> deepest';
      final outer = _parse(source).single as BlockquoteBlock;
      expect(
        outer.children.first,
        const ParagraphBlock(inlines: [TextInline('outer')]),
      );
      final inner = outer.children.last as BlockquoteBlock;
      expect(
        inner.children.first,
        const ParagraphBlock(inlines: [TextInline('inner')]),
      );
      final deepest = inner.children.last as BlockquoteBlock;
      expect(deepest.children, const [
        ParagraphBlock(inlines: [TextInline('deepest')]),
      ]);
    });

    test('a non-monotonic list indent keeps all three items', () {
      // `b` is indented four columns: deeper than the content of `a`, so it
      // nests; `c` at two columns is a sibling of `b`.
      const source = '- a\n    - b\n  - c';
      final blocks = _parse(source);
      expect(_kinds(blocks), [ListBlock], reason: _upstream(source));
      final text = _text(blocks);
      for (final item in ['a', 'b', 'c']) {
        expect(text, contains(item));
      }
      final list = blocks.single as ListBlock;
      expect(list.items, hasLength(1));
      final nested = list.items.single.children.last as ListBlock;
      expect(nested.items, hasLength(2));
    });

    test('a six-level nested list nests six deep', () {
      final source = [
        for (var depth = 0; depth < 6; depth++) '${'  ' * depth}- l$depth',
      ].join('\n');
      var list = _parse(source).single as ListBlock;
      for (var depth = 0; depth < 6; depth++) {
        expect(list.items, hasLength(1));
        final item = list.items.single;
        expect(extractBlockRenderedText(item.children.first), 'l$depth');
        if (depth < 5) list = item.children.last as ListBlock;
      }
    });
  });

  // Priorities: control characters, NUL, lone surrogates.
  group('control characters', () {
    test('NUL is kept or replaced by U+FFFD, never dropped silently', () {
      const source = 'a\u0000b';
      for (final isStreaming in [false, true]) {
        final text = _text(_parse(source, isStreaming: isStreaming));
        expect(text, anyOf('a\u0000b', 'a�b'));
      }
    });

    test('NUL inside code, links, headings and tables does not throw', () {
      for (final source in [
        '`a\u0000b`',
        '```\na\u0000b\n```',
        '[a\u0000b](http://x.io/\u0000)',
        '# a\u0000b',
        '| a\u0000 | b |\n| --- | --- |\n| \u0000 | 2 |',
        '\u0000',
        '\u0000\n\u0000',
        '> \u0000',
        '- \u0000',
        r'\('
            '\u0000'
            r'\)',
        '<b>\u0000</b>',
        '[^\u0000]: x',
      ]) {
        for (final isStreaming in [false, true]) {
          _exercise(_parse(source, isStreaming: isStreaming));
        }
      }
      final code = _parse('```\na\u0000b\n```').single as CodeBlock;
      expect(code.code, anyOf('a\u0000b', 'a�b'));
      final table =
          _parse('| a\u0000 | b |\n| --- | --- |\n| \u0000 | 2 |').single
              as TableBlock;
      expect(table.columnCount, 2);
      expect(table.rows, hasLength(1));
    });

    void expectKeptInsideWords(int code) {
      final char = String.fromCharCode(code);
      // The character sits inside words: several of these count as
      // whitespace for the emphasis flanking rules (form feed, NBSP).
      final source = 'a${char}b **bo${char}ld** `c${char}d`';
      final blocks = _parse(source);
      final reason = 'U+${code.toRadixString(16)} ${_upstream(source)}';
      expect(_kinds(blocks), [ParagraphBlock], reason: reason);
      expect((blocks.single as ParagraphBlock).inlines, [
        TextInline('a${char}b '),
        StrongInline(children: [TextInline('bo${char}ld')]),
        const TextInline(' '),
        InlineCodeInline('c${char}d'),
      ], reason: reason);
      _exercise(blocks);
    }

    test('C0 controls, DEL and invisible characters stay in the text', () {
      for (final code in [
        0x01, 0x02, 0x07, 0x08, 0x0B, 0x0C, 0x0E, 0x1B, 0x1F, 0x7F, //
        0x85, 0xA0, 0x200B, 0x200D, 0xFEFF, 0xFFFD,
      ]) {
        expectKeptInsideWords(code);
      }
    });

    test(
      'U+2028 and U+2029 are ordinary characters, not line endings',
      () {
        // CommonMark knows only LF, CR and CRLF as line endings, so these two
        // may sit inside a code span or strong emphasis like any other
        // character.
        expectKeptInsideWords(0x2028);
        expectKeptInsideWords(0x2029);
      },
      skip: 'package:markdown 7.3.1: the code span pattern uses `.`, which excludes U+2028/U+2029',
    );

    test('a leading byte-order mark does not hide the first block', () {
      const source = '﻿# Title\n\ntext';
      final blocks = _parse(source);
      expect(blocks, hasLength(2), reason: _upstream(source));
      expect(blocks.last, const ParagraphBlock(inlines: [TextInline('text')]));
      expect(_text(blocks), contains('Title'));
    });

    test('every C0 control at a line start keeps the following blocks', () {
      for (var code = 0; code < 0x20; code++) {
        if (code == 0x09 || code == 0x0A || code == 0x0D) continue;
        final char = String.fromCharCode(code);
        final source = '${char}first\n\n- item\n\n```\ncode\n```\n';
        final blocks = _parse(source);
        expect(_kinds(blocks), [
          ParagraphBlock,
          ListBlock,
          CodeBlock,
        ], reason: 'U+${code.toRadixString(16)} ${_upstream(source)}');
        expect((blocks.last as CodeBlock).code, 'code');
      }
    });
  });

  // gpt_markdown fuzz_findings_test › lone surrogate
  group('lone surrogates', () {
    final high = String.fromCharCode(0xD83D);
    final low = String.fromCharCode(0xDE00);

    test('a lone surrogate anywhere parses and can be walked', () {
      for (final lone in [high, low]) {
        for (final source in [
          lone,
          'a${lone}b',
          '**$lone**',
          '`$lone`',
          '# $lone',
          '[$lone]($lone)',
          '![$lone]($lone)',
          '| $lone |\n| --- |\n| $lone |',
          '```$lone\n$lone\n```',
          '- $lone\n  - $lone',
          '> $lone',
          '<b>$lone</b>',
          '<details><summary>$lone</summary>\n\n$lone\n\n</details>',
          '&$lone;',
          'text[^$lone]\n\n[^$lone]: $lone',
          r'\('
              '$lone'
              r'\)',
          'https://example.com/$lone',
        ]) {
          for (final isStreaming in [false, true]) {
            final blocks = _parse(source, isStreaming: isStreaming);
            expect(blocks, isNotEmpty, reason: _visible(source));
            _exercise(blocks);
          }
        }
      }
    });

    test('a lone surrogate stays in the text as written or as U+FFFD', () {
      for (final lone in [high, low]) {
        final text = _text(_parse('a${lone}b'));
        expect(text, anyOf('a${lone}b', 'a�b'));
      }
    });

    test('a stream cut in the middle of an emoji never throws', () {
      const reply =
          'Ship it 😀🚀 now 👍🏽 — 家族 👨‍👩‍👧 done.\n\n- 😀\n- `🚀`\n';
      final parser = GfmMarkdownParser();
      MarkdownDocument? last;
      for (var end = 1; end <= reply.length; end++) {
        last = parser.parse(reply.substring(0, end), isStreaming: true);
        _exercise(last.blocks);
      }
      expect(last!.blocks, _parse(reply));
      expect(_text(last.blocks), contains('👨‍👩‍👧'));
    });

    test('an emoji survives every inline construct intact', () {
      const source =
          '**😀** *🚀* ~~👍🏽~~ `👨‍👩‍👧` [🌍](https://example.com/🌍) 日本語';
      final blocks = _parse(source);
      expect(_text(blocks), '😀 🚀 👍🏽 👨‍👩‍👧 🌍 日本語');
      final link = (blocks.single as ParagraphBlock).inlines
          .whereType<LinkInline>()
          .single;
      expect(Uri.decodeFull(link.destination), 'https://example.com/🌍');
    });
  });

  // flutter_md hostile_input_test › Quote depth; edge_cases › deeply nested.
  group('deep nesting', () {
    test('a fence at the bottom of 40 nested quotes is still code', () {
      final source = '${'> ' * 40}```\n${'> ' * 40}code\n${'> ' * 40}```';
      MarkdownBlock block = _parse(source).single;
      for (var depth = 0; depth < 40; depth++) {
        expect(block, isA<BlockquoteBlock>(), reason: 'depth $depth');
        block = (block as BlockquoteBlock).children.single;
      }
      expect(block, isA<CodeBlock>());
      expect((block as CodeBlock).code, 'code');
      expect(block.closed, isTrue);
    });

    test('an alert inside nested quotes is found at its own level', () {
      const source = '> > [!WARNING]\n> > careful';
      final outer = _parse(source).single as BlockquoteBlock;
      final alert = outer.children.single as AlertBlock;
      expect(alert.kind, AlertKind.warning);
      expect(alert.children, const [
        ParagraphBlock(inlines: [TextInline('careful')]),
      ]);
    });

    test('deeply nested quotes parse and can be walked', () {
      for (final depth in [100, 300]) {
        final source = '${'> ' * depth}deep';
        final blocks = _parse(source);
        expect(_isRawFallback(blocks, source), isFalse, reason: '$depth');
        var levels = 0;
        MarkdownBlock block = blocks.single;
        while (block is BlockquoteBlock) {
          levels++;
          block = block.children.single;
        }
        expect(levels, depth);
        expect(block, const ParagraphBlock(inlines: [TextInline('deep')]));
        _exercise(blocks);
        _exercise(_parse(source, isStreaming: true));
      }
    });

    test('deeply nested lists parse and can be walked', () {
      const depth = 100;
      final source = [for (var i = 0; i < depth; i++) '${'  ' * i}- item $i']
          .join('\n');
      final blocks = _parse(source);
      expect(_isRawFallback(blocks, source), isFalse);
      var levels = 0;
      MarkdownBlock? block = blocks.single;
      while (block is ListBlock) {
        levels++;
        final children = block.items.single.children;
        block = children.length > 1 ? children.last : null;
      }
      expect(levels, depth);
      _exercise(blocks);
    });

    test('deeply nested emphasis keeps its text', () {
      // Each opener is left-flanking only and each closer right-flanking
      // only, so the pairs nest 200 deep.
      const pairs = 100;
      final source = '${'*a _b ' * pairs}x${' b_ a*' * pairs}';
      final blocks = _parse(source);
      expect(_text(blocks), '${'a b ' * pairs}x${' b a' * pairs}');
      var depth = 0;
      var inlines = (blocks.single as ParagraphBlock).inlines;
      while (inlines.whereType<EmphasisInline>().isNotEmpty) {
        depth++;
        inlines = inlines.whereType<EmphasisInline>().single.children;
      }
      expect(depth, pairs * 2);
      _exercise(blocks);
    });

    test('deeply nested inline HTML keeps its text', () {
      final source = '${'<b><i>' * 300}x${'</i></b>' * 300}';
      final blocks = _parse(source);
      expect(_text(blocks), 'x');
      _exercise(blocks);
    });

    test('deeply nested brackets resolve only the innermost link', () {
      // Links may not contain other links, so only the innermost pair links.
      final source = '${'[' * 300}a${'](u)' * 300}';
      final blocks = _parse(source);
      final links = <LinkInline>[];
      void collect(List<MarkdownInline> inlines) {
        for (final inline in inlines) {
          if (inline is LinkInline) {
            links.add(inline);
            collect(inline.children);
          }
        }
      }

      collect((blocks.single as ParagraphBlock).inlines);
      expect(links, hasLength(1));
      expect(links.single.destination, 'u');
      expect(links.single.children, const [TextInline('a')]);
      _exercise(blocks);
    });

    test('nested details blocks nest and can be walked', () {
      const depth = 30;
      final source =
          '${'<details>\n<summary>s</summary>\n\n' * depth}core\n\n'
          '${'</details>\n' * depth}';
      final blocks = _parse(source);
      var levels = 0;
      MarkdownBlock block = blocks.single;
      while (block is HtmlDetailsBlock) {
        levels++;
        expect(block.summary, const [TextInline('s')]);
        block = block.children.single;
      }
      expect(levels, depth);
      expect(block, const ParagraphBlock(inlines: [TextInline('core')]));
      _exercise(blocks);
    });
  });

  // flutter_md edge_cases_test › Boundary conditions, "linear time" inputs
  // (structure only: the timing lives in parser_robustness_test), and
  // hostile_input_test › Links past the 16-bit boundary.
  group('large inputs', () {
    test('a very long single line is one paragraph', () {
      final source = 'word ' * 50000;
      final blocks = _parse(source);
      expect(blocks, hasLength(1));
      expect(_text(blocks), source.trimRight());
    });

    test('thousands of paragraphs stay separate blocks', () {
      const count = 5000;
      final source = [for (var i = 0; i < count; i++) 'para $i'].join('\n\n');
      for (final isStreaming in [false, true]) {
        final blocks = _parse(source, isStreaming: isStreaming);
        expect(blocks, hasLength(count));
        expect(
          blocks.first,
          const ParagraphBlock(inlines: [TextInline('para 0')]),
        );
        expect(
          blocks.last,
          const ParagraphBlock(inlines: [TextInline('para ${count - 1}')]),
        );
      }
    });

    test('a table keeps thousands of rows', () {
      const count = 3000;
      final source =
          '| h | i |\n|---|---|\n'
          '${[for (var i = 0; i < count; i++) '| a$i | b$i |'].join('\n')}\n';
      final table = _parse(source).single as TableBlock;
      expect(table.columnCount, 2);
      expect(table.rows, hasLength(count));
      expect(table.rows.last.cells, const [
        [TextInline('a${count - 1}')],
        [TextInline('b${count - 1}')],
      ]);
    });

    test('table-looking rows without a delimiter row are a paragraph', () {
      final source = '| a | b |\n' * 3000;
      final blocks = _parse(source);
      expect(_kinds(blocks), [ParagraphBlock]);
    });

    test('every one of 70,000 links is kept', () {
      const count = 70000;
      final source = '[a](b) ' * count;
      final paragraph = _parse(source).single as ParagraphBlock;
      final links = paragraph.inlines.whereType<LinkInline>().toList();
      expect(links, hasLength(count));
      expect(
        links.last,
        const LinkInline(destination: 'b', children: [TextInline('a')]),
      );
    });

    test('a long code block with blank lines is one block', () {
      const lines = 4001;
      final body = [for (var i = 0; i < lines; i++) i.isEven ? 'line $i' : '']
          .join('\n');
      final source = 'Before\n\n```dart\n$body\n```\n\nAfter';
      for (final isStreaming in [false, true]) {
        final blocks = _parse(source, isStreaming: isStreaming);
        expect(_kinds(blocks), [ParagraphBlock, CodeBlock, ParagraphBlock]);
        expect((blocks[1] as CodeBlock).code == body, isTrue);
        expect((blocks[1] as CodeBlock).closed, isTrue);
      }
    });

    test('long runs of openers without a closer stay literal', () {
      final sources = <String, String>{
        'stars': 'a${'*' * 100000}b',
        'underscores': 'a${'_' * 100000}b',
        'tildes': 'a${'~' * 100000}b',
        'bold openers': '${'**a ' * 20000}end',
        'brackets, one closer': '${'[' * 50000}]',
        'image openers, one closer': '${'![' * 25000}]',
        'less-than': 'a${'<' * 50000}',
        'ampersands': 'a${'&' * 50000}',
      };
      sources.forEach((name, source) {
        final blocks = _parse(source);
        expect(_kinds(blocks), [ParagraphBlock], reason: name);
        expect(_text(blocks) == source, isTrue, reason: name);
      });
    });

    test('backticks after escaped backslashes pair up into code spans', () {
      // Outside a code span `\\` is an escaped backslash, so the backtick
      // after it is a real delimiter; the backticks then pair up two by two.
      final source = 'a${r'\\`' * 20000}b';
      final blocks = _parse(source);
      expect(_kinds(blocks), [ParagraphBlock]);
      final paragraph = blocks.single as ParagraphBlock;
      expect(paragraph.inlines.whereType<InlineCodeInline>(), hasLength(10000));
      expect(paragraph.inlines.first, const TextInline(r'a\'));
      expect(paragraph.inlines.last, const TextInline('b'));
    });

    test('20,000 nested quotes can still be walked', () {
      final source = '${'>' * 20000}x';
      final blocks = _parse(source);
      expect(blocks, hasLength(1));
      // What the selection engine and the widget layer do with a block.
      expect(() => extractBlockRenderedText(blocks.single), returnsNormally);
      expect(() => blocks.single.hashCode, returnsNormally);
      expect(() => blocks.single == _parse(source).single, returnsNormally);
      expect(() => blocks.single.toString(), returnsNormally);
    });
  });

  // Priority: tabs.
  group('tabs', () {
    test('a tab after a block marker works like a space', () {
      expect(_parse('#\tTitle'), const [
        HeadingBlock(level: 1, inlines: [TextInline('Title')]),
      ]);
      expect(_parse('>\tquote'), const [
        BlockquoteBlock(
          children: [
            ParagraphBlock(inlines: [TextInline('quote')]),
          ],
        ),
      ]);
      final list = _parse('-\tone\n-\ttwo').single as ListBlock;
      expect(list.items.map(extractListItemRenderedText), ['one', 'two']);
      final ordered = _parse('1.\tone\n2.\ttwo').single as ListBlock;
      expect(ordered.ordered, isTrue);
      expect(ordered.items.map(extractListItemRenderedText), ['one', 'two']);
    });

    test('a tab-indented line is an indented code block', () {
      final block = _parse('\tcode\n\tmore').single as CodeBlock;
      expect(block.isFenced, isFalse);
      expect(block.code, 'code\nmore');
    });

    test('tabs inside code are kept as tabs', () {
      final fenced = _parse('```\n\tif (x) {\n\t\ty();\n\t}\n```').single;
      expect((fenced as CodeBlock).code, '\tif (x) {\n\t\ty();\n\t}');
      final paragraph = _parse('a `x\ty` b').single as ParagraphBlock;
      expect(paragraph.inlines[1], const InlineCodeInline('x\ty'));
    });

    test('a tab nests a list item', () {
      const source = '- a\n\t- b';
      final list = _parse(source).single as ListBlock;
      expect(list.items, hasLength(1), reason: _upstream(source));
      final nested = list.items.single.children.last as ListBlock;
      expect(nested.items.map(extractListItemRenderedText), ['b']);
    });

    test('tabs around table cells are trimmed', () {
      const source = '|\ta\t|\tb\t|\n|\t---\t|\t---\t|\n|\t1\t|\t2\t|';
      final blocks = _parse(source);
      expect(_kinds(blocks), [TableBlock], reason: _upstream(source));
      final table = blocks.single as TableBlock;
      expect(table.header.cells, const [
        [TextInline('a')],
        [TextInline('b')],
      ]);
      expect(table.rows.single.cells, const [
        [TextInline('1')],
        [TextInline('2')],
      ]);
    });

    test('a tab inside a paragraph is kept', () {
      expect(_parse('a\tb'), const [
        ParagraphBlock(inlines: [TextInline('a\tb')]),
      ]);
    });

    test('a tab-indented fence in a list item belongs to the item', () {
      const source = '1. step\n\n\t```sh\n\tls\n\t```\n\n2. next';
      for (final isStreaming in [false, true]) {
        final blocks = _parse(source, isStreaming: isStreaming);
        expect(_kinds(blocks), [ListBlock], reason: _upstream(source));
        final list = blocks.single as ListBlock;
        expect(list.items, hasLength(2));
        final code = list.items.first.children.last as CodeBlock;
        expect(code.language, 'sh');
        expect(code.code, 'ls');
      }
    });
  });

  // flutter_md hostile_input_test › random documents keep the parser
  // invariants. Seeded; complements parser_robustness_test with hostile
  // fragments (control characters, lone surrogates, CR, tabs).
  group('random hostile documents', () {
    final pieces = <String>[
      '\n',
      '\n',
      '\n\n',
      '\r\n',
      '\r',
      '\t',
      ' ',
      '  ',
      '    ',
      '\u0000',
      '\u0001',
      '\u001B',
      '\u007F',
      ' ',
      '﻿',
      String.fromCharCode(0xD83D),
      String.fromCharCode(0xDE00),
      '😀',
      '`',
      '``',
      '```',
      '~~~',
      '````',
      '*',
      '**',
      '_',
      '__',
      '~',
      '~~',
      '[',
      ']',
      '(',
      ')',
      '![',
      '](',
      '<',
      '>',
      '</',
      '/>',
      '&',
      ';',
      '#',
      '# ',
      '- ',
      '1. ',
      '> ',
      '| ',
      ' |',
      '|',
      '---',
      ':-:',
      '===',
      r'\',
      r'\(',
      r'\)',
      r'\[',
      r'\]',
      r'$',
      r'$$',
      '[^',
      ']:',
      '[!NOTE]',
      '<details>',
      '</details>',
      '<summary>',
      '</summary>',
      '<b>',
      '</b>',
      '<br>',
      '<a href="',
      '">',
      '<img src="',
      '<!--',
      '-->',
      '<div>',
      '&amp;',
      '&#0;',
      '&#x110000;',
      '&#xD800;',
      '&#99999999999;',
      'word',
      'text ',
      'https://a.b/c',
      'www.a.b',
      'a@b.co',
      '- [ ] ',
      '- [x] ',
      'x^2',
      '{',
      '}',
    ];

    String randomDocument(Random random) {
      final buffer = StringBuffer();
      for (var n = 1 + random.nextInt(24); n > 0; n--) {
        buffer.write(pieces[random.nextInt(pieces.length)]);
      }
      return buffer.toString();
    }

    test('parse never throws and the result can be walked', () {
      final random = Random(20261127);
      for (var i = 0; i < 6000; i++) {
        final source = randomDocument(random);
        for (final options in const [
          MarkdownParserOptions(),
          MarkdownParserOptions(enableDollarLatex: true),
          MarkdownParserOptions(
            enableHtml: false,
            enableLatex: false,
            enableFootnotes: false,
            enableAlerts: false,
          ),
        ]) {
          for (final isStreaming in [false, true]) {
            final MarkdownDocument document;
            try {
              document = GfmMarkdownParser(options: options)
                  .parse(source, isStreaming: isStreaming);
              _exercise(document.blocks);
            } catch (error) {
              fail('${error.runtimeType} on ${_visible(source)}');
            }
            expect(
              document.source,
              isStreaming
                  ? sanitizeStreamingTail(
                      source,
                      bracketMath: options.enableLatex,
                      dollarMath:
                          options.enableLatex && options.enableDollarLatex,
                    )
                  : source,
            );
          }
        }
      }
    });

    test('the split always joins back, whatever the characters', () {
      final random = Random(99);
      for (var i = 0; i < 6000; i++) {
        final source = randomDocument(random);
        expect(
          splitMarkdownBlocks(source).join(),
          source,
          reason: _visible(source),
        );
        expect(
          splitMarkdownBlocks(source, ignoreCrossBlockConstructs: true).join(),
          source,
          reason: _visible(source),
        );
        expect(source, startsWith(sanitizeStreamingTail(source)));
      }
    });

    test('parsing the same hostile text twice gives equal documents', () {
      final random = Random(5);
      for (var i = 0; i < 2000; i++) {
        final source = randomDocument(random);
        final parser = GfmMarkdownParser();
        final first = parser.parse(source);
        expect(identical(parser.parse(source), first), isTrue);
        expect(
          GfmMarkdownParser().parse(source),
          first,
          reason: _visible(source),
        );
      }
    });
  });
}
