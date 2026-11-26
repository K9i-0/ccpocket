// Streaming behaviour of the parser and the block splitter on realistic
// replies: every prefix parses, the stream converges on the non-streaming
// result, half-typed fences and display math never flash, and the caches
// behave.
//
// Mined from flutter_md streaming_test and gpt_markdown streaming/
// (stream_split, commonmark_streaming, inline_hold, math_streaming) and
// regression/nested_code_blocks, rewritten against markdown_kit's API.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_kit/markdown_kit.dart';

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
    return 'upstream: ${_visible(md.renderToHtml(nodes))}';
  } catch (error) {
    return 'upstream throws ${error.runtimeType}';
  }
}

List<Type> _kinds(List<MarkdownBlock> blocks) => [
  for (final block in blocks) block.runtimeType,
];

const _dollar = MarkdownParserOptions(enableDollarLatex: true);

/// A reply the way a coding assistant writes one: prose, a fenced block with
/// a blank line inside, a list holding a fence, a table, an alert.
const _codeReply = '''
Here is the fix for `parse()`:

```dart
void main() {

  print('hello');
}
```

1. Run the tests:

   ```sh
   flutter test

   dart analyze
   ```
2. Commit the change.

| File | Lines |
| :--- | ----: |
| a.dart | 12 |
| b.dart | 3 |

> [!NOTE]
> Restart the app **after** the change.

Done.
''';

/// Display and inline math, a collapsed section, a footnote-free tail.
const _mathReply = r'''
The energy is \(E = mc^2\), and the series is:

\[
\sum_{i=1}^{n} i

= \frac{n(n+1)}{2}
\]

<details>
<summary>Derivation</summary>

Pair the terms: \(1 + n\), \(2 + (n-1)\).

```
no math here \(x\)
```

</details>

So the total for `n = 10` is 55.
''';

/// Reference links and footnotes keep the document in a single chunk.
const _referenceReply = '''
# Sources

See the [guide][g] and the [spec] for details[^1].

- [guide][g] covers setup
- <https://example.com/direct> is the mirror

[g]: https://example.com/guide "The Guide"
[spec]: https://example.com/spec

[^1]: Checked last week.
''';

const _dollarReply = r'''
Inline $a^2 + b^2$ costs $5 or $10.

$$
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}

y = 0
$$

After.
''';

final _replies = <String, (String, MarkdownParserOptions)>{
  'code reply': (_codeReply, const MarkdownParserOptions()),
  'math reply': (_mathReply, const MarkdownParserOptions()),
  'reference reply': (_referenceReply, const MarkdownParserOptions()),
  'dollar reply': (_dollarReply, _dollar),
  'code reply, CRLF': (
    _codeReply.replaceAll('\n', '\r\n'),
    const MarkdownParserOptions(),
  ),
  'math reply, CRLF': (
    _mathReply.replaceAll('\n', '\r\n'),
    const MarkdownParserOptions(),
  ),
};

final _onlyFenceChars = RegExp(r'^[ \t]*(`+|~+)[ \t]*$');
final _partialCloser = RegExp(r'(^|\n)[ \t]*(`{1,2}|~{1,2})$');

/// Collects everything a half-typed fence or display-math delimiter would
/// look like if it leaked into a frame.
List<String> _flicker(List<MarkdownBlock> blocks) {
  final problems = <String>[];
  void visit(MarkdownBlock block) {
    switch (block) {
      case ParagraphBlock():
        final text = extractBlockRenderedText(block);
        final lastLine = text.split('\n').last;
        if (_onlyFenceChars.hasMatch(lastLine)) {
          problems.add('paragraph ends in a fence run: "$text"');
        }
        if (lastLine.trim() == r'$$' || lastLine.trim() == r'\[') {
          problems.add('paragraph ends in a math opener: "$text"');
        }
      case CodeBlock(:final code, :final isFenced):
        if (isFenced && _partialCloser.hasMatch(code)) {
          problems.add('code ends in a partial closing fence: "$code"');
        }
      case BlockLatexBlock(:final expression):
        final lastLine = expression.split('\n').last.trim();
        if (lastLine == r'$' || lastLine == r'\') {
          problems.add('math ends in a partial closer: "$expression"');
        }
      case BlockquoteBlock(:final children):
        children.forEach(visit);
      case AlertBlock(:final children):
        children.forEach(visit);
      case HtmlDetailsBlock(:final children):
        children.forEach(visit);
      case ListBlock(:final items):
        for (final item in items) {
          item.children.forEach(visit);
        }
      default:
        break;
    }
  }

  blocks.forEach(visit);
  return problems;
}

void main() {
  // flutter_md streaming_test › char-by-char; gpt_markdown streaming_markdown.
  group('every prefix of a realistic reply', () {
    _replies.forEach((name, entry) {
      final (source, options) = entry;

      test('$name: parses at every length and converges', () {
        final streaming = GfmMarkdownParser(options: options);
        MarkdownDocument? last;
        for (var end = 1; end <= source.length; end++) {
          final prefix = source.substring(0, end);
          last = streaming.parse(prefix, isStreaming: true);
          // A parser that saw the earlier frames must agree with one that
          // sees this frame cold: caches may never change the result.
          final cold = GfmMarkdownParser(options: options)
              .parse(prefix, isStreaming: true);
          expect(last.blocks, cold.blocks, reason: _visible(prefix));
        }
        final complete = GfmMarkdownParser(options: options).parse(source);
        expect(last!.blocks, complete.blocks);
        // The same parser, asked for the finished text, agrees too.
        expect(streaming.parse(source).blocks, complete.blocks);
      });

      test('$name: no half-typed fence or display math is shown', () {
        final streaming = GfmMarkdownParser(options: options);
        for (var end = 1; end <= source.length; end++) {
          final prefix = source.substring(0, end);
          final blocks = streaming.parse(prefix, isStreaming: true).blocks;
          expect(_flicker(blocks), isEmpty, reason: _visible(prefix));
        }
      });
    });

    test('the finished replies keep their structure', () {
      List<Type> kindsOf(String name) {
        final (source, options) = _replies[name]!;
        return _kinds(GfmMarkdownParser(options: options).parse(source).blocks);
      }

      const codeKinds = [
        ParagraphBlock,
        CodeBlock,
        ListBlock,
        TableBlock,
        AlertBlock,
        ParagraphBlock,
      ];
      expect(kindsOf('code reply'), codeKinds);
      expect(kindsOf('code reply, CRLF'), codeKinds);
      const mathKinds = [
        ParagraphBlock,
        BlockLatexBlock,
        HtmlDetailsBlock,
        ParagraphBlock,
      ];
      expect(kindsOf('math reply'), mathKinds);
      expect(kindsOf('math reply, CRLF'), mathKinds);
      expect(kindsOf('reference reply'), [
        HeadingBlock,
        ParagraphBlock,
        ListBlock,
        FootnoteDefinitionsBlock,
      ]);
      expect(kindsOf('dollar reply'), [
        ParagraphBlock,
        BlockLatexBlock,
        ParagraphBlock,
      ]);
    });

    test('CRLF and LF replies parse to the same blocks', () {
      for (final name in ['code reply', 'math reply']) {
        final (lf, options) = _replies[name]!;
        final (crlf, _) = _replies['$name, CRLF']!;
        expect(
          GfmMarkdownParser(options: options).parse(crlf).blocks,
          GfmMarkdownParser(options: options).parse(lf).blocks,
          reason: name,
        );
      }
    });
  });

  // flutter_md streaming_test › by-line / by-word / by-size / random.
  group('chunked delivery', () {
    Iterable<int> boundaries(String source, String strategy) sync* {
      switch (strategy) {
        case 'by-line':
          for (var i = 0; i < source.length; i++) {
            if (source.codeUnitAt(i) == 0x0A) yield i + 1;
          }
        case 'by-word':
          for (var i = 0; i < source.length; i++) {
            if (source.codeUnitAt(i) == 0x20) yield i + 1;
          }
        case 'by-3':
          for (var i = 3; i < source.length; i += 3) {
            yield i;
          }
        case 'by-17':
          for (var i = 17; i < source.length; i += 17) {
            yield i;
          }
        default:
          final random = Random(int.parse(strategy.split('-').last));
          var i = 0;
          while (true) {
            i += 1 + random.nextInt(24);
            if (i >= source.length) break;
            yield i;
          }
      }
      yield source.length;
    }

    for (final strategy in [
      'by-line',
      'by-word',
      'by-3',
      'by-17',
      'random-1',
      'random-2',
      'random-3',
    ]) {
      test('$strategy delivery matches a cold parse of each frame', () {
        _replies.forEach((name, entry) {
          final (source, options) = entry;
          final streaming = GfmMarkdownParser(options: options);
          MarkdownDocument? last;
          for (final end in boundaries(source, strategy)) {
            final prefix = source.substring(0, end);
            last = streaming.parse(prefix, isStreaming: true);
            final cold = GfmMarkdownParser(options: options)
                .parse(prefix, isStreaming: true);
            expect(
              last.blocks,
              cold.blocks,
              reason: '$name ${_visible(prefix)}',
            );
            expect(_flicker(last.blocks), isEmpty, reason: _visible(prefix));
          }
          expect(
            last!.blocks,
            GfmMarkdownParser(options: options).parse(source).blocks,
            reason: name,
          );
        });
      });
    }

    test('two replies streamed through one parser do not mix', () {
      // A chat list shares one parser between bubbles; the streaming slot
      // holds a single tail, so interleaved streams must not read each
      // other's blocks.
      final shared = GfmMarkdownParser();
      const first = _codeReply;
      const second = _mathReply;
      final longest = max(first.length, second.length);
      for (var end = 5; end <= longest; end += 5) {
        for (final source in [first, second]) {
          final prefix = source.substring(0, min(end, source.length));
          expect(
            shared.parse(prefix, isStreaming: true).blocks,
            GfmMarkdownParser().parse(prefix, isStreaming: true).blocks,
            reason: _visible(prefix),
          );
        }
      }
    });
  });

  // gpt_markdown math_streaming › "text that is not being streamed is left as
  // it was"; replies commonly end without a final newline.
  group('the last frame of a reply without a trailing newline', () {
    test('a closing fence without a newline closes the block', () {
      const source = 'Run:\n\n```sh\nls\n```';
      for (final isStreaming in [false, true]) {
        final blocks = GfmMarkdownParser()
            .parse(source, isStreaming: isStreaming)
            .blocks;
        final code = blocks.last as CodeBlock;
        expect(code.code, 'ls');
        expect(code.closed, isTrue, reason: 'isStreaming: $isStreaming');
      }
    });

    test('closing display math without a newline closes the block', () {
      for (final source in ['\\[\nx^2\n\\]', '\$\$\nx^2\n\$\$']) {
        for (final isStreaming in [false, true]) {
          final blocks = GfmMarkdownParser(options: _dollar)
              .parse(source, isStreaming: isStreaming)
              .blocks;
          expect(blocks, const [
            BlockLatexBlock(expression: 'x^2'),
          ], reason: '${_visible(source)} isStreaming: $isStreaming');
        }
      }
    });

    test('unfinished inline constructs agree in both modes', () {
      // Only fences and display math are held back while streaming; inline
      // constructs are shown as typed, exactly as a finished reply would.
      for (final source in [
        'say _hello',
        'Run `npm inst',
        'a **bold',
        'see [docs](https://exam',
        'see [docs][re',
        'see <b',
        'a <b>bold',
        'a <!-- b',
        r'so \(x^2',
        'Title\n-',
        'Title\n=',
        '1. one\n2',
        '1. one\n2.',
        'text\n\n[1]',
        'text\n\n[1]: https://ex',
        'text\n\n[foo]:\n',
        'Intro.\n| a | b |\n',
        '| a | b |\n|--',
        '| a | b |\n| --- | --- |\n| 1',
        '\n|',
        '\n|---|:-:|\n',
        '\n| a |\n',
        '- [',
        '- [x',
        '> [!NO',
        '<details',
        '<details>\n<summ',
        'footnote[^',
        '![alt](https://example.com/a.p',
      ]) {
        final streamed = GfmMarkdownParser().parse(source, isStreaming: true);
        final whole = GfmMarkdownParser().parse(source);
        expect(streamed.blocks, whole.blocks, reason: _visible(source));
      }
    });

    test('an unclosed inline math opener in a finished reply is not math', () {
      // No closer, so no math; `\(` is then an ordinary CommonMark backslash
      // escape of `(` and the backslash is consumed.
      const source = r'so \(x^2 is open';
      final blocks = GfmMarkdownParser().parse(source).blocks;
      final paragraph = blocks.single as ParagraphBlock;
      expect(paragraph.inlines.whereType<InlineLatexInline>(), isEmpty);
      expect(extractBlockRenderedText(paragraph), 'so (x^2 is open');

      const dollar = r'an unpaired $x stays';
      final dollarBlocks = GfmMarkdownParser(options: _dollar).parse(dollar);
      expect(extractBlockRenderedText(dollarBlocks.blocks.single), dollar);
    });
  });

  // gpt_markdown stream_split_test; regression/nested_code_blocks_test ›
  // splitting at blank lines; commonmark_streaming › settledSplitOffset.
  group('splitMarkdownBlocks settles blocks for good', () {
    test('a block, once split off, never changes as the reply grows', () {
      for (final name in ['code reply', 'math reply', 'dollar reply']) {
        final (source, _) = _replies[name]!;
        var settled = const <String>[];
        for (var end = 1; end <= source.length; end++) {
          final chunks = splitMarkdownBlocks(source.substring(0, end));
          expect(chunks.join(), source.substring(0, end));
          expect(
            chunks.length,
            greaterThanOrEqualTo(settled.length),
            reason: 'the split moved backward at $end',
          );
          expect(
            chunks.take(settled.length).toList(),
            settled,
            reason: 'a settled chunk changed at $end',
          );
          settled = chunks.sublist(0, chunks.length - 1);
        }
      }
    });

    test('a trailing newline or blank line does not settle the last block', () {
      expect(splitMarkdownBlocks('One.\n\nTwo.'), ['One.\n\n', 'Two.']);
      expect(splitMarkdownBlocks('One.\n\nTwo.\n'), ['One.\n\n', 'Two.\n']);
      expect(splitMarkdownBlocks('One.\n\nTwo.\n\n'), ['One.\n\n', 'Two.\n\n']);
      expect(splitMarkdownBlocks('Just one paragraph.'), [
        'Just one paragraph.',
      ]);
    });

    test('a tilde fence with blank lines is one chunk', () {
      expect(splitMarkdownBlocks('Intro.\n\n~~~\na\n\nb\n~~~\n\nAfter.'), [
        'Intro.\n\n',
        '~~~\na\n\nb\n~~~\n\n',
        'After.',
      ]);
    });

    test('a long fence is not closed by a shorter one', () {
      expect(
        splitMarkdownBlocks('Intro.\n\n````\n```\n\nx\n```\n\ny\n````\n\nEnd'),
        ['Intro.\n\n', '````\n```\n\nx\n```\n\ny\n````\n\n', 'End'],
      );
    });

    test('a backtick fence is not closed by a tilde fence', () {
      expect(splitMarkdownBlocks('```\n~~~\n\nx\n~~~\n\ny\n```\n\nEnd'), [
        '```\n~~~\n\nx\n~~~\n\ny\n```\n\n',
        'End',
      ]);
    });

    test('a closing fence with an info string does not close', () {
      expect(splitMarkdownBlocks('```\na\n```dart\n\nb\n```\n\nEnd'), [
        '```\na\n```dart\n\nb\n```\n\n',
        'End',
      ]);
    });

    test('display math with blank lines is one chunk', () {
      expect(splitMarkdownBlocks('Intro.\n\n\\[\na^2\n\n b^2\n\\]\n\nAfter.'), [
        'Intro.\n\n',
        '\\[\na^2\n\n b^2\n\\]\n\n',
        'After.',
      ]);
    });

    test('a list item and its fenced code stay together', () {
      const source = '1. Run\n\n   ```\n   x\n\n   y\n   ```\n\n2. Next\n\nEnd';
      expect(splitMarkdownBlocks(source), [
        '1. Run\n\n   ```\n   x\n\n   y\n   ```\n\n2. Next\n\n',
        'End',
      ]);
      expect(splitMarkdownBlocks('Intro.\n\n$source').first, 'Intro.\n\n');
    });

    test('an HTML comment with blank lines keeps the document whole', () {
      const source = 'Intro.\n\n<!--\na\n\nb\n-->\n\nAfter.';
      expect(splitMarkdownBlocks(source), [source]);
      expect(GfmMarkdownParser().parse(source).blocks, const [
        ParagraphBlock(inlines: [TextInline('Intro.')]),
        ParagraphBlock(inlines: [TextInline('After.')]),
      ]);
    });
  });

  // Where the splitter's own view of fences, math and definitions can drift
  // from the parser's. The expected values are what CommonMark says about the
  // whole document; the splitter must not change them.
  group('splitting never changes what the document means', () {
    test('a fence marker indented four spaces is code, not a fence', () {
      // The first ``` is an indented code block. The real fence below holds
      // a blank line and must stay one block.
      const source = '    ```\n\ntext\n\n```\na\n\nb\n```\n';
      final blocks = GfmMarkdownParser().parse(source).blocks;
      final reason =
          '${_upstream(source)}\nchunks: ${splitMarkdownBlocks(source)}';
      expect(_kinds(blocks), [
        CodeBlock,
        ParagraphBlock,
        CodeBlock,
      ], reason: reason);
      expect((blocks[0] as CodeBlock).isFenced, isFalse);
      expect((blocks[0] as CodeBlock).code, '```');
      expect((blocks[2] as CodeBlock).code, 'a\n\nb');
      expect((blocks[2] as CodeBlock).closed, isTrue);
    });

    test('a tab-indented fence marker is code, not a fence', () {
      const source = '\t```\n\ntext\n\n```\na\n\nb\n```\n';
      final blocks = GfmMarkdownParser().parse(source).blocks;
      final reason =
          '${_upstream(source)}\nchunks: ${splitMarkdownBlocks(source)}';
      expect(_kinds(blocks), [
        CodeBlock,
        ParagraphBlock,
        CodeBlock,
      ], reason: reason);
      expect((blocks[2] as CodeBlock).code, 'a\n\nb');
    });

    test('a fence left open in a list item ends with the item', () {
      // The item's fence is closed by the end of the list, so the ``` after
      // the paragraph opens a new block that holds a blank line.
      const source = '- item\n  ```\n  in\n\npara\n\n```\na\n\nb\n```\n';
      final blocks = GfmMarkdownParser().parse(source).blocks;
      final reason =
          '${_upstream(source)}\nchunks: ${splitMarkdownBlocks(source)}';
      expect(_kinds(blocks), [
        ListBlock,
        ParagraphBlock,
        CodeBlock,
      ], reason: reason);
      expect((blocks[2] as CodeBlock).code, 'a\n\nb');
      expect((blocks[2] as CodeBlock).closed, isTrue);
    });

    test('a fence left open in a quote ends with the quote', () {
      const source = '> ```\n> a\n\nb\n\n```\nc\n\nd\n```\n';
      final blocks = GfmMarkdownParser().parse(source).blocks;
      expect(_kinds(blocks), [
        BlockquoteBlock,
        ParagraphBlock,
        CodeBlock,
      ], reason: _upstream(source));
      expect((blocks[2] as CodeBlock).code, 'c\n\nd');
    });

    test('a reference defined inside a quote resolves outside it', () {
      const source = '> [ref]: /url\n\nSee [ref].';
      final blocks = GfmMarkdownParser().parse(source).blocks;
      final paragraph = blocks.last as ParagraphBlock;
      expect(paragraph.inlines, const [
        TextInline('See '),
        LinkInline(destination: '/url', children: [TextInline('ref')]),
        TextInline('.'),
      ], reason: _upstream(source));
    });

    test('a reference defined inside a list item resolves outside it', () {
      const source = '- [ref]: /url\n\nSee [ref].';
      final blocks = GfmMarkdownParser().parse(source).blocks;
      final paragraph = blocks.last as ParagraphBlock;
      expect(
        paragraph.inlines,
        const [
          TextInline('See '),
          LinkInline(destination: '/url', children: [TextInline('ref')]),
          TextInline('.'),
        ],
        reason: '${_upstream(source)}\nchunks: ${splitMarkdownBlocks(source)}',
      );
    });

    test('a reference defined inside <details> resolves outside it', () {
      // The definition follows a blank line, so it is ordinary Markdown
      // inside the block; without the blank line before the last paragraph
      // (one chunk) the same link does resolve.
      const source =
          '<details>\n<summary>S</summary>\n\n[ref]: /url\n\n</details>\n\n'
          'See [ref].';
      final blocks = GfmMarkdownParser().parse(source).blocks;
      final paragraph = blocks.last as ParagraphBlock;
      expect(
        paragraph.inlines,
        const [
          TextInline('See '),
          LinkInline(destination: '/url', children: [TextInline('ref')]),
          TextInline('.'),
        ],
        reason: '${_upstream(source)}\nchunks: ${splitMarkdownBlocks(source)}',
      );
    });

    test('a reference used before its definition resolves in every chunk', () {
      const source =
          'First [one].\n\nSecond [two][2].\n\n```\n[one]: /not-a-def\n```\n\n'
          '[one]: /first\n[2]: /second "Two"\n';
      final blocks = GfmMarkdownParser().parse(source).blocks;
      expect(_kinds(blocks), [ParagraphBlock, ParagraphBlock, CodeBlock]);
      final first = (blocks[0] as ParagraphBlock).inlines
          .whereType<LinkInline>()
          .single;
      expect(first.destination, '/first');
      final second = (blocks[1] as ParagraphBlock).inlines
          .whereType<LinkInline>()
          .single;
      expect(second.destination, '/second');
      expect(second.title, 'Two');
    });

    test('a reference link resolves once its definition streams in', () {
      const source = 'See [the docs][d] now.\n\nMore text.\n\n[d]: /docs\n';
      final parser = GfmMarkdownParser();
      MarkdownDocument? last;
      var sawResolved = false;
      for (var end = 1; end <= source.length; end++) {
        last = parser.parse(source.substring(0, end), isStreaming: true);
        final links = [
          for (final block in last.blocks.whereType<ParagraphBlock>())
            ...block.inlines.whereType<LinkInline>(),
        ];
        // The first paragraph was cached unresolved; the cache must not keep
        // it that way once the definition is there.
        if (links.isNotEmpty) {
          sawResolved = true;
          // The destination is still being typed in the first frames.
          expect('/docs', startsWith(links.single.destination));
        } else {
          expect(sawResolved, isFalse, reason: 'the link went away at $end');
        }
      }
      expect(sawResolved, isTrue);
      expect(last!.blocks, GfmMarkdownParser().parse(source).blocks);
    });

    test('a footnote resolves once its definition streams in', () {
      const source = 'Claim[^a] one.\n\nClaim[^b] two.\n\n[^a]: A.\n[^b]: B.\n';
      final parser = GfmMarkdownParser();
      MarkdownDocument? last;
      for (var end = 1; end <= source.length; end++) {
        last = parser.parse(source.substring(0, end), isStreaming: true);
      }
      final whole = GfmMarkdownParser().parse(source).blocks;
      expect(last!.blocks, whole);
      expect(_kinds(whole), [
        ParagraphBlock,
        ParagraphBlock,
        FootnoteDefinitionsBlock,
      ]);
      final refs = [
        for (final block in whole.whereType<ParagraphBlock>())
          ...block.inlines.whereType<FootnoteRefInline>(),
      ];
      expect(refs.map((ref) => ref.index), [1, 2]);
      final definitions = (whole.last as FootnoteDefinitionsBlock).definitions;
      expect(definitions.map((d) => d.label), ['a', 'b']);
      expect(definitions.map((d) => d.index), [1, 2]);
    });

    test('a bare CR line ending does not hide a fence from the splitter', () {
      // "para", a blank line and a fence opener, separated by lone CRs.
      const source = 'para\r\r```\ncode\n\nmore\n```\n';
      final blocks = GfmMarkdownParser().parse(source).blocks;
      final reason =
          '${_upstream(source)}\nchunks: '
          '${splitMarkdownBlocks(source).map(_visible).toList()}';
      expect(_kinds(blocks), [ParagraphBlock, CodeBlock], reason: reason);
      expect((blocks.last as CodeBlock).code, 'code\n\nmore');
      expect((blocks.last as CodeBlock).closed, isTrue);
    });

    // Random documents from line fragments, joined with LF, then the same
    // lines with other line endings.
    const fragments = [
      '',
      '',
      'plain text',
      'more *text* here',
      '# Heading',
      '- item',
      '  - nested',
      '1. one',
      '> quote',
      '```',
      '```dart',
      '~~~',
      'code line',
      '| a | b |',
      '| --- | --- |',
      '| 1 | 2 |',
      '---',
      r'\[',
      r'\]',
      '<details>',
      '</details>',
      '    indented',
      'trailing two  ',
    ];

    List<String> lineEndingFailures(
      int seed,
      Map<String, String> Function(List<String> lines, Random random) variants,
    ) {
      final random = Random(seed);
      final failures = <String>[];
      for (var i = 0; i < 1500; i++) {
        final lines = [
          for (var n = 1 + random.nextInt(10); n > 0; n--)
            fragments[random.nextInt(fragments.length)],
        ];
        final lf = '${lines.join('\n')}\n';
        final expected = GfmMarkdownParser().parse(lf).blocks;
        variants(lines, random).forEach((kind, source) {
          final actual = GfmMarkdownParser().parse(source).blocks;
          if (!_sameBlocks(actual, expected)) {
            failures.add(
              '$kind: ${_visible(source)}\n  got  $actual\n  want $expected',
            );
          }
        });
      }
      failures.sort((a, b) => a.length.compareTo(b.length));
      return failures;
    }

    test('CRLF and mixed CRLF/LF endings never change the parsed blocks', () {
      final failures = lineEndingFailures(
        104,
        (lines, random) => {
          'CRLF': '${lines.join('\r\n')}\r\n',
          'mixed': [
            for (final line in lines)
              '$line${random.nextBool() ? '\n' : '\r\n'}',
          ].join(),
        },
      );
      expect(failures.take(3).toList(), isEmpty);
    });

    test('bare CR line endings never change the parsed blocks', () {
      final failures = lineEndingFailures(
        105,
        (lines, random) => {
          'CR': '${lines.join('\r')}\r',
          'mixed': [
            for (var i = 0; i < lines.length; i++)
              // A CR before an empty LF-terminated line would read as one
              // CRLF, so such a line gets a CRLF of its own.
              '${lines[i]}${i + 1 < lines.length && lines[i + 1].isEmpty ? '\r\n' : const ['\n', '\r\n', '\r'][random.nextInt(3)]}',
          ].join(),
        },
      );
      expect(failures.take(3).toList(), isEmpty);
    });
  });

  group('holding back half-typed block markers', () {
    test('a fence in a list item is held like a top-level one', () {
      const head = '- step\n\n  ```sh\n  ls\n';
      expect(sanitizeStreamingTail('- step\n\n  ``'), '- step\n\n');
      expect(sanitizeStreamingTail('- step\n\n  ```s'), '- step\n\n');
      expect(sanitizeStreamingTail('$head  `'), head);
      expect(sanitizeStreamingTail('$head  ``'), head);
      expect(sanitizeStreamingTail('$head  ```'), '$head  ```');
    });

    test('tilde fences are held like backtick fences', () {
      expect(sanitizeStreamingTail('a\n\n~'), 'a\n\n');
      expect(sanitizeStreamingTail('a\n\n~~'), 'a\n\n');
      expect(sanitizeStreamingTail('a\n\n~~~py'), 'a\n\n');
      expect(sanitizeStreamingTail('~~~\nx\n~~'), '~~~\nx\n');
      // Backticks inside a tilde fence are content.
      expect(sanitizeStreamingTail('~~~\nx\n``'), '~~~\nx\n``');
    });

    test('a longer fence holds every shorter closing run', () {
      const head = '`````\n```\ninner\n```\n';
      for (var length = 1; length < 5; length++) {
        expect(sanitizeStreamingTail('$head${'`' * length}'), head);
      }
      expect(sanitizeStreamingTail('$head`````'), '$head`````');
    });

    test('CRLF input is held the same way', () {
      expect(sanitizeStreamingTail('a\r\n\r\n``'), 'a\r\n\r\n');
      expect(sanitizeStreamingTail('```\r\nx\r\n``'), '```\r\nx\r\n');
      expect(sanitizeStreamingTail('\\[\r\nx\r\n\\'), '\\[\r\nx\r\n');
      // A fence line that has only its CR so far is complete enough.
      expect(sanitizeStreamingTail('```dart\r'), '```dart\r');
      final blocks = GfmMarkdownParser()
          .parse('```dart\r', isStreaming: true)
          .blocks;
      expect((blocks.single as CodeBlock).language, 'dart');
    });

    test('ordinary prose is never held', () {
      for (final source in [
        'Just ordinary prose with nothing special in it',
        'Compute 2 * 3 * 4 and then carry on',
        'call snake_case_name now',
        'a `closed` span',
        r'pay $5 now',
        r'so $x',
        'inline ``` not a fence',
      ]) {
        expect(sanitizeStreamingTail(source), source);
      }
    });

    test('a half-typed closing fence is hidden when dollar math is off', () {
      // With the default options a lone `$$` line is ordinary text, so it
      // must not make the sanitizer think it is inside display math.
      const source = 'Costs:\n\$\$\n\n```dart\ncode\n``';
      final blocks = GfmMarkdownParser().parse(source, isStreaming: true);
      final code = blocks.blocks.whereType<CodeBlock>().single;
      expect(
        code.code,
        'code',
        reason: _visible(sanitizeStreamingTail(source)),
      );
    });
  });

  // gpt_markdown streaming_markdown_test › performance; flutter_md
  // streaming_test › freezing. markdown_kit: block cache + streaming slot.
  group('caches while streaming', () {
    test('settled blocks are the same objects in every later frame', () {
      const source = _codeReply;
      final parser = GfmMarkdownParser();
      final seen = <String, MarkdownBlock>{};
      for (var end = 1; end <= source.length; end++) {
        final prefix = source.substring(0, end);
        final chunks = splitMarkdownBlocks(sanitizeStreamingTail(prefix));
        final blocks = parser.parse(prefix, isStreaming: true).blocks;
        if (chunks.length < 2) continue;
        // The first chunk is settled: one paragraph, parsed exactly once.
        final first = seen.putIfAbsent(chunks.first, () => blocks.first);
        expect(identical(blocks.first, first), isTrue, reason: 'at $end');
      }
      expect(seen, hasLength(1));
    });

    test('tail frames do not grow the block or document caches', () {
      final parser = GfmMarkdownParser();
      const head = '# Title\n\nSettled paragraph.\n\n';
      var blockCacheAfterHead = -1;
      for (var i = 1; i <= 200; i++) {
        parser.parse('$head${'word ' * i}', isStreaming: true);
        if (i == 1) blockCacheAfterHead = parser.blockCacheLength;
      }
      expect(blockCacheAfterHead, 2);
      expect(parser.blockCacheLength, 2);
      expect(parser.documentCacheLength, 0);
    });

    test('a single-chunk stream stores nothing in the shared caches', () {
      final parser = GfmMarkdownParser();
      for (var i = 1; i <= 50; i++) {
        parser.parse('```\n${'line\n\n' * i}', isStreaming: true);
      }
      expect(parser.blockCacheLength, 0);
      expect(parser.documentCacheLength, 0);
    });

    test('streaming does not evict finished documents', () {
      final parser = GfmMarkdownParser(maxCacheEntries: 3);
      final finished = [
        for (final text in ['# A\n\na', '# B\n\nb', '# C\n\nc'])
          parser.parse(text),
      ];
      for (var end = 1; end <= _codeReply.length; end++) {
        parser.parse(_codeReply.substring(0, end), isStreaming: true);
      }
      expect(parser.documentCacheLength, 3);
      expect(identical(parser.parse('# A\n\na'), finished[0]), isTrue);
      expect(identical(parser.parse('# B\n\nb'), finished[1]), isTrue);
      expect(identical(parser.parse('# C\n\nc'), finished[2]), isTrue);
    });

    test('the finished parse reuses the blocks settled while streaming', () {
      final parser = GfmMarkdownParser();
      MarkdownDocument? streamed;
      for (var end = 1; end <= _codeReply.length; end++) {
        streamed = parser.parse(
          _codeReply.substring(0, end),
          isStreaming: true,
        );
      }
      final finished = parser.parse(_codeReply);
      expect(finished.blocks, streamed!.blocks);
      // Everything but the tail was settled, so it is not parsed again.
      for (var i = 0; i < finished.blocks.length - 1; i++) {
        expect(
          identical(finished.blocks[i], streamed.blocks[i]),
          isTrue,
          reason: 'block $i',
        );
      }
      expect(identical(parser.parse(_codeReply), finished), isTrue);
    });

    test('the same frame twice returns the same document', () {
      final parser = GfmMarkdownParser();
      final first = parser.parse('a\n\nb', isStreaming: true);
      expect(
        identical(parser.parse('a\n\nb', isStreaming: true), first),
        isTrue,
      );
      // A held-back tail maps onto the frame before it.
      final held = parser.parse('a\n\nb\n``', isStreaming: true);
      expect(
        identical(parser.parse('a\n\nb\n`', isStreaming: true), held),
        isTrue,
      );
    });

    test('a parser with caching disabled still parses correctly', () {
      final parser = GfmMarkdownParser(
        maxCacheEntries: 0,
        maxBlockCacheEntries: 0,
      );
      MarkdownDocument? last;
      for (var end = 1; end <= _codeReply.length; end++) {
        last = parser.parse(_codeReply.substring(0, end), isStreaming: true);
      }
      expect(parser.documentCacheLength, 0);
      expect(parser.blockCacheLength, 0);
      expect(last!.blocks, GfmMarkdownParser().parse(_codeReply).blocks);
      expect(parser.parse(_codeReply).blocks, last.blocks);
    });

    test('a tiny block cache evicts without changing the result', () {
      final parser = GfmMarkdownParser(maxBlockCacheEntries: 1);
      MarkdownDocument? last;
      for (var end = 1; end <= _codeReply.length; end++) {
        last = parser.parse(_codeReply.substring(0, end), isStreaming: true);
        expect(parser.blockCacheLength, lessThanOrEqualTo(1));
      }
      expect(last!.blocks, GfmMarkdownParser().parse(_codeReply).blocks);
    });

    test('clearCache forgets the streaming slot too', () {
      final parser = GfmMarkdownParser();
      final before = parser.parse('a\n\nb', isStreaming: true);
      parser.parse('# Done');
      parser.clearCache();
      expect(parser.documentCacheLength, 0);
      expect(parser.blockCacheLength, 0);
      final after = parser.parse('a\n\nb', isStreaming: true);
      expect(identical(after, before), isFalse);
      expect(after, before);
    });

    test('the source of a streamed document is what was parsed', () {
      final parser = GfmMarkdownParser();
      expect(parser.parse('a\n\n``', isStreaming: true).source, 'a\n\n');
      expect(parser.parse('a\n\n```', isStreaming: true).source, 'a\n\n');
      expect(
        parser.parse('a\n\n```\n', isStreaming: true).source,
        'a\n\n```\n',
      );
      expect(parser.parse('``', isStreaming: true), MarkdownDocument.empty);
    });
  });
}

/// Deep equality; `toString` would hide code and table cells.
bool _sameBlocks(List<MarkdownBlock> a, List<MarkdownBlock> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
