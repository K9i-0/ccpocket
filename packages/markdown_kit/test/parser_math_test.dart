// LaTeX at parse level: `\(..\)` and `\[..\]` (on by default), `$..$` and
// `$$..$$` (opt-in through MarkdownParserOptions.enableDollarLatex).
//
// Mined from flutter_md math_test / regression_test (inline math off by
// default, currency) and gpt_markdown latex/, streaming/math_streaming_test.
// markdown_kit hands the expression to a builder verbatim, so there is no
// symbol conversion to test; what matters is where math starts and ends.
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

const _dollar = MarkdownParserOptions(enableDollarLatex: true);

List<MarkdownBlock> _parse(
  String source, {
  MarkdownParserOptions options = const MarkdownParserOptions(),
}) => GfmMarkdownParser(options: options).parse(source).blocks;

List<MarkdownInline> _inlines(
  String source, {
  MarkdownParserOptions options = const MarkdownParserOptions(),
}) => (_parse(source, options: options).single as ParagraphBlock).inlines;

List<String> _math(
  String source, {
  MarkdownParserOptions options = const MarkdownParserOptions(),
}) => [
  for (final inline in _inlines(source, options: options))
    if (inline is InlineLatexInline) inline.expression,
];

void main() {
  group(r'inline \( \)', () {
    test('expressions are passed through verbatim', () {
      final cases = <String, String>{
        r'\(x^2\)': 'x^2',
        r'\(\frac{a}{b}\)': r'\frac{a}{b}',
        r'\(x_1\)': 'x_1',
        r'\(\alpha + \beta\)': r'\alpha + \beta',
        r'\(\sqrt{x}\)': r'\sqrt{x}',
        r'\( x \)': 'x',
        r'\(f(x) = (a+b)\)': 'f(x) = (a+b)',
        r'\(a \\ b\)': r'a \\ b',
        r'\(a < b > c\)': 'a < b > c',
        r'\(a & b\)': 'a & b',
        r'\(\text{if } x\)': r'\text{if } x',
        r'\(x\_y\)': r'x\_y',
        r'\([a, b]\)': '[a, b]',
        r'\(\$5\)': r'\$5',
      };
      cases.forEach((source, expected) {
        expect(_inlines(source), [InlineLatexInline(expected)], reason: source);
      });
    });

    test('math in a sentence keeps the text around it', () {
      expect(_inlines(r'The equation \(E = mc^2\) is famous'), const [
        TextInline('The equation '),
        InlineLatexInline('E = mc^2'),
        TextInline(' is famous'),
      ]);
      expect(_inlines(r'\(a\) and \(b\), then \(c\).'), const [
        InlineLatexInline('a'),
        TextInline(' and '),
        InlineLatexInline('b'),
        TextInline(', then '),
        InlineLatexInline('c'),
        TextInline('.'),
      ]);
    });

    test('underscores and stars inside math are not emphasis', () {
      expect(_math(r'\(a_i + b_i\) and \(c_j * d_j\)'), [
        'a_i + b_i',
        'c_j * d_j',
      ]);
      expect(_inlines(r'*\(a*b\)* and **\(x_1\)**'), const [
        EmphasisInline(children: [InlineLatexInline('a*b')]),
        TextInline(' and '),
        StrongInline(children: [InlineLatexInline('x_1')]),
      ]);
      // Emphasis opened before math does not close inside it.
      expect(_inlines(r'_a \(b_c\) d_'), const [
        EmphasisInline(
          children: [
            TextInline('a '),
            InlineLatexInline('b_c'),
            TextInline(' d'),
          ],
        ),
      ]);
    });

    test('markup inside math is not parsed', () {
      expect(_inlines(r'\(<b>x</b> [a](b) &amp; **c**\)'), const [
        InlineLatexInline('<b>x</b> [a](b) &amp; **c**'),
      ]);
    });

    test('math sits inside headings, lists, quotes, links and cells', () {
      const math = InlineLatexInline('x^2');
      expect((_parse(r'# \(x^2\)').single as HeadingBlock).inlines, const [
        math,
      ]);
      final list = _parse(r'- \(x^2\)').single as ListBlock;
      expect(list.items.single.children, const [
        ParagraphBlock(inlines: [math]),
      ]);
      final quote = _parse(r'> \(x^2\)').single as BlockquoteBlock;
      expect(quote.children, const [
        ParagraphBlock(inlines: [math]),
      ]);
      expect(_inlines(r'[\(x^2\)](/u)'), const [
        LinkInline(destination: '/u', children: [math]),
      ]);
      final table = _parse('| \\(x^2\\) |\n| --- |').single as TableBlock;
      expect(table.header.cells.single, const [math]);
    });

    test('code protects its content', () {
      expect(_inlines(r'`\(x\)` and \(y\)'), const [
        InlineCodeInline(r'\(x\)'),
        TextInline(' and '),
        InlineLatexInline('y'),
      ]);
      final block =
          _parse('```\n\\(x\\)\n\\[\ny\n\\]\n```').single as CodeBlock;
      expect(block.code, '\\(x\\)\n\\[\ny\n\\]');
      final indented = _parse('    \\[\n    y\n    \\]').single as CodeBlock;
      expect(indented.code, '\\[\ny\n\\]');
    });

    test('an opener without a closer, or empty math, is not math', () {
      // What is left are ordinary backslash escapes of the parentheses.
      expect(_inlines(r'so \(x^2 is open'), const [
        TextInline('so (x^2 is open'),
      ]);
      expect(_inlines(r'only a closer x\)'), const [
        TextInline('only a closer x)'),
      ]);
      expect(_inlines(r'empty \(\) here'), const [TextInline('empty () here')]);
      expect(_inlines(r'blank \(  \) here'), const [
        TextInline('blank (  ) here'),
      ]);
    });

    test('an escaped backslash before the parenthesis is not an opener', () {
      expect(_inlines(r'\\(x\\)'), const [TextInline(r'\(x\)')]);
    });

    test('math does not span a blank line', () {
      final blocks = _parse('a \\(x\n\ny\\) b');
      expect(blocks, hasLength(2));
      for (final block in blocks) {
        expect(
          (block as ParagraphBlock).inlines.whereType<InlineLatexInline>(),
          isEmpty,
        );
      }
    });

    test('enableLatex: false leaves plain escapes', () {
      const off = MarkdownParserOptions(enableLatex: false);
      expect(_inlines(r'a \(x\) b', options: off), const [
        TextInline('a (x) b'),
      ]);
      final blocks = _parse('\\[\nx\n\\]', options: off);
      expect(blocks.whereType<BlockLatexBlock>(), isEmpty);
      expect(extractBlockRenderedText(blocks.single), '[ x ]');
    });
  });

  group(r'display \[ \]', () {
    test('a single-line block', () {
      expect(_parse(r'\[x^2 + y^2 = z^2\]'), const [
        BlockLatexBlock(expression: 'x^2 + y^2 = z^2'),
      ]);
      expect(_parse(r'  \[ \frac{a}{b} \]  '), const [
        BlockLatexBlock(expression: r'\frac{a}{b}'),
      ]);
    });

    test('a multi-line block keeps its lines and inner blank lines', () {
      expect(_parse('\\[\n\\int_{0}^{1} x^2 \\, dx\n\\]'), const [
        BlockLatexBlock(expression: r'\int_{0}^{1} x^2 \, dx'),
      ]);
      expect(_parse('\\[\na\n\n  b\n\\]'), const [
        BlockLatexBlock(expression: 'a\n\n  b'),
      ]);
    });

    test('a matrix keeps its row separators and ampersands', () {
      const body = '\\begin{pmatrix}\na & b \\\\\nc & d\n\\end{pmatrix}';
      expect(_parse('\\[\n$body\n\\]'), const [
        BlockLatexBlock(expression: body),
      ]);
    });

    test('markup, entities and dollars inside are verbatim', () {
      const body = r'a_i * b_i < c &amp; **d** `e` $f$ # g';
      expect(_parse('\\[\n$body\n\\]'), const [
        BlockLatexBlock(expression: body),
      ]);
    });

    test('text before and after is kept in its own paragraphs', () {
      expect(_parse('Before:\n\n\\[\nx\n\\]\n\nAfter.'), const [
        ParagraphBlock(inlines: [TextInline('Before:')]),
        BlockLatexBlock(expression: 'x'),
        ParagraphBlock(inlines: [TextInline('After.')]),
      ]);
    });

    test('display math interrupts a paragraph', () {
      expect(_parse('Before:\n\\[\nx\n\\]\nAfter.'), const [
        ParagraphBlock(inlines: [TextInline('Before:')]),
        BlockLatexBlock(expression: 'x'),
        ParagraphBlock(inlines: [TextInline('After.')]),
      ]);
    });

    test('several display blocks in a row', () {
      expect(_parse('\\[a\\]\n\n\\[\nb\n\\]\n\\[c\\]'), const [
        BlockLatexBlock(expression: 'a'),
        BlockLatexBlock(expression: 'b'),
        BlockLatexBlock(expression: 'c'),
      ]);
    });

    test('the closer may share the last line of content', () {
      expect(_parse('\\[\na + b\n= c \\]\n\nafter'), const [
        BlockLatexBlock(expression: 'a + b\n= c'),
        ParagraphBlock(inlines: [TextInline('after')]),
      ]);
    });

    test('an unclosed block runs to the end and says so', () {
      final block = _parse('\\[\nx^2\n\nmore').single as BlockLatexBlock;
      expect(block.closed, isFalse);
      expect(block.expression, 'x^2\n\nmore');
    });

    test('display math inside a list item and a quote', () {
      final list = _parse('- item\n\n  \\[\n  x\n  \\]\n- next').single;
      expect((list as ListBlock).items, hasLength(2));
      expect(
        list.items.first.children.last,
        const BlockLatexBlock(expression: 'x'),
      );
      final quote = _parse('> \\[\n> x\n> \\]').single as BlockquoteBlock;
      expect(quote.children, const [BlockLatexBlock(expression: 'x')]);
    });

    test('brackets in prose are not math', () {
      for (final source in [
        r'\[optional] note here',
        r'see \[1\] and \[2\] below',
        r'text \[x\] more',
        r'a \] b',
      ]) {
        final blocks = _parse(source);
        expect(blocks.single, isA<ParagraphBlock>(), reason: source);
        expect(
          extractBlockRenderedText(blocks.single),
          source.replaceAll(r'\', ''),
          reason: source,
        );
      }
    });
  });

  group(r'opt-in $ and $$', () {
    test('off by default: dollars are text', () {
      for (final source in [
        r'angle $\alpha$ small',
        r'$x$',
        r'It costs $5 and $10 today.',
        r'$$x^2$$',
      ]) {
        expect(_inlines(source), [TextInline(source)], reason: source);
      }
      expect(_inlines(r'price \$5 today'), const [
        TextInline(r'price $5 today'),
      ]);
      final blocks = _parse('\$\$\nx\n\$\$');
      expect(blocks.whereType<BlockLatexBlock>(), isEmpty);
      expect(extractBlockRenderedText(blocks.single), r'$$ x $$');
    });

    test('inline spans', () {
      final cases = <String, List<String>>{
        r'$\alpha$': [r'\alpha'],
        r'$x$': ['x'],
        r'A $\rightarrow$ B': [r'\rightarrow'],
        r'$\alpha$ and $\beta$': [r'\alpha', r'\beta'],
        r'$x^{10}$, $a_{12}$ and $H_2O$': ['x^{10}', 'a_{12}', 'H_2O'],
        r'$a_i * b_i \\ c$': [r'a_i * b_i \\ c'],
        r'$x^{2$': ['x^{2'],
        r'($x$)': ['x'],
        r'$x$y': ['x'],
        r'$a \$ b$': [r'a \$ b'],
        r'$$x^2$$ inline': ['x^2'],
      };
      cases.forEach((source, expected) {
        expect(_math(source, options: _dollar), expected, reason: source);
      });
    });

    test('currency is never math', () {
      for (final source in [
        r'I have $5 and $10 left',
        r'costs $5 total',
        r'from $5-$10 per seat',
        r'($5, $10 or $15)',
        r'$5.00 → $7.50',
        r'US$5 and A$6',
        r'a$b$c',
        r'pay $ 5 $ now',
        r'$ x $',
        r'just one $ sign',
        r'ends with $',
        r'$',
      ]) {
        expect(_inlines(source, options: _dollar), [
          TextInline(source),
        ], reason: source);
      }
    });

    test('an escaped dollar is a literal dollar and opens nothing', () {
      expect(_inlines(r'price \$5 and \$x\$', options: _dollar), const [
        TextInline(r'price $5 and $x$'),
      ]);
    });

    test('a dollar span does not cross a line or a code span', () {
      expect(_math('cost \$x\nand y\$ here', options: _dollar), isEmpty);
      expect(_inlines(r'$a$ `$b$` $c$', options: _dollar), const [
        InlineLatexInline('a'),
        TextInline(' '),
        InlineCodeInline(r'$b$'),
        TextInline(' '),
        InlineLatexInline('c'),
      ]);
      expect(_math(r'$a `code` b$', options: _dollar), isEmpty);
      final fenced = _parse('```\n\$x\$\n\$\$\ny\n\$\$\n```', options: _dollar);
      expect((fenced.single as CodeBlock).code, '\$x\$\n\$\$\ny\n\$\$');
    });

    test('display blocks', () {
      expect(_parse('\$\$\na^2 + b^2\n\n= c^2\n\$\$', options: _dollar), const [
        BlockLatexBlock(expression: 'a^2 + b^2\n\n= c^2'),
      ]);
      expect(_parse(r'$$a^2 + b^2 = c^2$$', options: _dollar), const [
        BlockLatexBlock(expression: 'a^2 + b^2 = c^2'),
      ]);
      expect(_parse('Before\n\$\$\nx\n\$\$\nAfter', options: _dollar), const [
        ParagraphBlock(inlines: [TextInline('Before')]),
        BlockLatexBlock(expression: 'x'),
        ParagraphBlock(inlines: [TextInline('After')]),
      ]);
      final open = _parse('\$\$\nx\n', options: _dollar).single;
      expect((open as BlockLatexBlock).closed, isFalse);
      expect(open.expression, 'x');
    });

    test(r'both delimiters work together, and \( \) still works', () {
      expect(_inlines(r'$a$ and \(b\)', options: _dollar), const [
        InlineLatexInline('a'),
        TextInline(' and '),
        InlineLatexInline('b'),
      ]);
      expect(_parse('\\[\nx\n\\]\n\n\$\$\ny\n\$\$', options: _dollar), const [
        BlockLatexBlock(expression: 'x'),
        BlockLatexBlock(expression: 'y'),
      ]);
      // A `$$` line does not close a `\[` block and vice versa.
      expect(_parse('\\[\nx\n\$\$\ny\n\\]', options: _dollar), const [
        BlockLatexBlock(expression: 'x\n\$\$\ny'),
      ]);
    });

    test('parsers with different options do not share results', () {
      const source = r'$x$';
      expect(_math(source), isEmpty);
      expect(_math(source, options: _dollar), ['x']);
      expect(_math(source), isEmpty);
    });
  });

  // gpt_markdown streaming/math_streaming_test (parse side).
  group('math while streaming', () {
    test('a display block stays one growing block until it closes', () {
      const source = 'Then:\n\n\\[\na^2\n\n+ b^2\n= c^2\n\\]\n\nDone.\n';
      final parser = GfmMarkdownParser();
      var previous = '';
      final start = source.indexOf('\\[\n') + 3;
      final close = source.indexOf('\\]\n') + 2;
      for (var end = start; end <= source.length; end++) {
        final blocks = parser
            .parse(source.substring(0, end), isStreaming: true)
            .blocks;
        final math = blocks[1] as BlockLatexBlock;
        expect(math.closed, end >= close, reason: 'at $end');
        expect(math.expression, startsWith(previous.trimRight()));
        expect(math.expression, isNot(contains(r'\]')));
        previous = math.expression;
        expect(blocks.length, end > close + 2 ? 3 : 2, reason: 'at $end');
      }
      expect(previous, 'a^2\n\n+ b^2\n= c^2');
    });

    test('a reply that opens with a dollar block keeps it as it closes', () {
      const source = '\$\$\nx = 1\n\$\$\n\nAfter.\n';
      final parser = GfmMarkdownParser(options: _dollar);
      for (var end = 3; end <= source.length; end++) {
        final blocks = parser
            .parse(source.substring(0, end), isStreaming: true)
            .blocks;
        expect(blocks.first, isA<BlockLatexBlock>(), reason: 'at $end');
        final math = blocks.first as BlockLatexBlock;
        expect(math.expression, isNot(contains(r'$')), reason: 'at $end');
        expect('x = 1', startsWith(math.expression.trimRight()));
      }
      expect(
        parser.parse(source, isStreaming: true).blocks,
        _parse(source, options: _dollar),
      );
    });

    test('inline math appears when its closer arrives, text before stays', () {
      const source = r'Then \(x = \frac{1}{2}\) holds.';
      final parser = GfmMarkdownParser();
      final close = source.indexOf(r'\)') + 2;
      for (var end = 1; end <= source.length; end++) {
        final blocks = parser
            .parse(source.substring(0, end), isStreaming: true)
            .blocks;
        final math = (blocks.single as ParagraphBlock).inlines
            .whereType<InlineLatexInline>();
        expect(math.length, end >= close ? 1 : 0, reason: 'at $end');
        expect(
          extractBlockRenderedText(blocks.single),
          startsWith(end >= 5 ? 'Then' : source.substring(0, end).trimRight()),
        );
      }
    });

    test('a closed formula is not disturbed by markup typed after it', () {
      const head = r'Given \(a_1 * b_1\) we';
      for (final tail in ['', ' get *', ' get **x', ' get `c', r' get \(d']) {
        final inlines =
            (GfmMarkdownParser()
                        .parse('$head$tail', isStreaming: true)
                        .blocks
                        .single
                    as ParagraphBlock)
                .inlines;
        expect(inlines[1], const InlineLatexInline('a_1 * b_1'), reason: tail);
      }
    });
  });
}
