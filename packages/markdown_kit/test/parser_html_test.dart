// HTML at parse level: the supported inline tags (br, b/strong, i/em, u,
// s/del, sub, sup, kbd, a, img), the details/summary block, and what happens
// to everything else (shown as written; comment-only blocks are dropped).
//
// Mined from gpt_markdown inline/underline_test and
// integration/html_tags_widget_test (AST side); rewritten against
// markdown_kit's AST.
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

List<MarkdownBlock> _parse(
  String source, {
  MarkdownParserOptions options = const MarkdownParserOptions(),
}) => GfmMarkdownParser(options: options).parse(source).blocks;

List<MarkdownInline> _inlines(String source) =>
    (_parse(source).single as ParagraphBlock).inlines;

String _text(List<MarkdownBlock> blocks) =>
    blocks.map(extractBlockRenderedText).join('\n\n');

List<Type> _kinds(List<MarkdownBlock> blocks) => [
  for (final block in blocks) block.runtimeType,
];

ParagraphBlock _p(String text) => ParagraphBlock(inlines: [TextInline(text)]);

void main() {
  group('supported inline tags', () {
    const x = [TextInline('x')];

    test('each tag maps to its inline node', () {
      final cases = <String, MarkdownInline>{
        '<b>x</b>': const StrongInline(children: x),
        '<strong>x</strong>': const StrongInline(children: x),
        '<i>x</i>': const EmphasisInline(children: x),
        '<em>x</em>': const EmphasisInline(children: x),
        '<u>x</u>': const UnderlineInline(children: x),
        '<s>x</s>': const StrikethroughInline(children: x),
        '<del>x</del>': const StrikethroughInline(children: x),
        '<sub>x</sub>': const SubscriptInline(children: x),
        '<sup>x</sup>': const SuperscriptInline(children: x),
        '<kbd>x</kbd>': const KeyboardInline(children: x),
      };
      cases.forEach((source, expected) {
        expect(_inlines(source), [expected], reason: source);
        // In a sentence, with text on both sides.
        expect(_inlines('a $source b'), [
          const TextInline('a '),
          expected,
          const TextInline(' b'),
        ], reason: source);
      });
    });

    test('tag names are case-insensitive and may carry attributes', () {
      const expected = [StrongInline(children: x)];
      for (final source in [
        '<B>x</B>',
        '<b>x</B>',
        '<b class="k" data-a=\'1\'>x</b>',
        '<b >x</b >',
      ]) {
        expect(_inlines(source), expected, reason: source);
      }
    });

    test('underline: word, phrase, mid-sentence and several', () {
      expect(_inlines('<u>underlined phrase here</u>'), const [
        UnderlineInline(children: [TextInline('underlined phrase here')]),
      ]);
      expect(_inlines('<u>first</u> and <u>second</u>'), const [
        UnderlineInline(children: [TextInline('first')]),
        TextInline(' and '),
        UnderlineInline(children: [TextInline('second')]),
      ]);
    });

    test('Markdown inside a tag and a tag inside Markdown', () {
      expect(_inlines('<u>*a* **b** `c` [d](/u)</u>'), const [
        UnderlineInline(
          children: [
            EmphasisInline(children: [TextInline('a')]),
            TextInline(' '),
            StrongInline(children: [TextInline('b')]),
            TextInline(' '),
            InlineCodeInline('c'),
            TextInline(' '),
            LinkInline(destination: '/u', children: [TextInline('d')]),
          ],
        ),
      ]);
      expect(_inlines('**<u>x</u>** and [<kbd>x</kbd>](/u)'), const [
        StrongInline(children: [UnderlineInline(children: x)]),
        TextInline(' and '),
        LinkInline(
          destination: '/u',
          children: [KeyboardInline(children: x)],
        ),
      ]);
    });

    test('tags nest', () {
      expect(_inlines('<b><i><u>x</u></i></b>'), const [
        StrongInline(
          children: [
            EmphasisInline(children: [UnderlineInline(children: x)]),
          ],
        ),
      ]);
      expect(_inlines('H<sub>2</sub>O and x<sup>2</sup>'), const [
        TextInline('H'),
        SubscriptInline(children: [TextInline('2')]),
        TextInline('O and x'),
        SuperscriptInline(children: [TextInline('2')]),
      ]);
      expect(_inlines('<kbd>Ctrl</kbd>+<kbd>C</kbd>'), const [
        KeyboardInline(children: [TextInline('Ctrl')]),
        TextInline('+'),
        KeyboardInline(children: [TextInline('C')]),
      ]);
    });

    test('a tag pair may span a soft line break', () {
      expect(_inlines('<b>one\ntwo</b>'), const [
        StrongInline(
          children: [
            TextInline('one'),
            LineBreakInline(isHard: false),
            TextInline('two'),
          ],
        ),
      ]);
    });

    test('unbalanced tags keep every visible character', () {
      final cases = <String, List<String>>{
        '<u>unclosed': ['unclosed'],
        'closed only</u>': ['closed only'],
        '<b><i>word</b></i>': ['word'],
        '<b>one<i>two</b>three': ['one', 'two', 'three'],
        '</b></b><b>': [],
        '<b><b><b>word</b>': ['word'],
      };
      cases.forEach((source, words) {
        final blocks = _parse(source);
        expect(_kinds(blocks), [ParagraphBlock], reason: source);
        final text = _text(blocks);
        for (final word in words) {
          expect(text, contains(word), reason: source);
        }
      });
      expect(_inlines('<u>unclosed'), const [TextInline('<u>unclosed')]);
      // By design a stray closing tag is dropped, like a browser does, while
      // a stray opener is shown as written (gfm_parser: "Unmatched stray
      // closing tags are silently dropped").
      expect(_inlines('closed only</u>'), const [TextInline('closed only')]);
    });

    test('tags inside code are code', () {
      expect(_inlines('`<b>x</b>` and `<br>`'), const [
        InlineCodeInline('<b>x</b>'),
        TextInline(' and '),
        InlineCodeInline('<br>'),
      ]);
      final block = _parse('```html\n<b>x</b><br>\n<details>\n```').single;
      expect((block as CodeBlock).code, '<b>x</b><br>\n<details>');
    });

    test('an escaped angle bracket is text', () {
      expect(_inlines(r'\<b>x\</b>'), const [TextInline('<b>x</b>')]);
      expect(_inlines('&lt;b&gt;x&lt;/b&gt;'), const [TextInline('<b>x</b>')]);
    });

    test('inline tags stay inside their list item, cell and heading', () {
      final list = _parse('- a <b>b</b> c\n- d').single as ListBlock;
      expect(list.items, hasLength(2));
      expect(list.items.first.children, const [
        ParagraphBlock(
          inlines: [
            TextInline('a '),
            StrongInline(children: [TextInline('b')]),
            TextInline(' c'),
          ],
        ),
      ]);
      final table = _parse('| <u>x</u> | a<br>b |\n| --- | --- |').single;
      expect((table as TableBlock).header.cells, const [
        [UnderlineInline(children: x)],
        [TextInline('a'), LineBreakInline(), TextInline('b')],
      ]);
      expect(
        (_parse('# T <sup>x</sup>').single as HeadingBlock).inlines,
        const [TextInline('T '), SuperscriptInline(children: x)],
      );
    });
  });

  group('<a> and <img>', () {
    test('an anchor becomes a link with destination and title', () {
      expect(
        _inlines('see <a href="https://x.io" title="T">the *docs*</a>.'),
        const [
          TextInline('see '),
          LinkInline(
            destination: 'https://x.io',
            title: 'T',
            children: [
              TextInline('the '),
              EmphasisInline(children: [TextInline('docs')]),
            ],
          ),
          TextInline('.'),
        ],
      );
    });

    test('attribute quoting styles and entity decoding', () {
      for (final source in [
        '<a href="/u?a=1&amp;b=2">x</a>',
        "<a href='/u?a=1&amp;b=2'>x</a>",
        '<a target="_blank" href="/u?a=1&amp;b=2" rel="x">x</a>',
        '<A HREF="/u?a=1&amp;b=2">x</A>',
      ]) {
        expect(_inlines(source), const [
          LinkInline(destination: '/u?a=1&b=2', children: [TextInline('x')]),
        ], reason: source);
      }
    });

    test('an anchor keeps its text even without an href', () {
      final blocks = _parse('<a name="top">label</a> and <a>bare</a>');
      expect(_text(blocks), contains('label'));
      expect(_text(blocks), contains('bare'));
    });

    test('an image tag becomes an image', () {
      for (final source in [
        '<img src="a.png" alt="A" title="T">',
        '<img src="a.png" alt="A" title="T"/>',
        '<img alt="A" width="40" height=20 src="a.png" title="T" />',
        '<IMG SRC="a.png" ALT="A" TITLE="T">',
      ]) {
        expect(_parse(source), const [
          ParagraphBlock(
            inlines: [ImageInline(source: 'a.png', alt: 'A', title: 'T')],
          ),
        ], reason: source);
      }
      expect(_inlines('logo <img src="a.png"> here'), const [
        TextInline('logo '),
        ImageInline(source: 'a.png'),
        TextInline(' here'),
      ]);
    });

    test('an image inside an anchor', () {
      expect(_inlines('<a href="/u"><img src="a.png" alt="A"></a>'), const [
        LinkInline(
          destination: '/u',
          children: [ImageInline(source: 'a.png', alt: 'A')],
        ),
      ]);
    });
  });

  group('unsupported HTML', () {
    test('an unsupported inline tag is shown as written', () {
      for (final source in [
        'a <mark>x</mark> b',
        'a <span style="color:red">x</span> b',
        'a <font color="red">x</font> b',
        'a <custom-tag>x</custom-tag> b',
        'a <input type="checkbox"> b',
      ]) {
        final blocks = _parse(source);
        expect(_kinds(blocks), [ParagraphBlock], reason: source);
        expect(_text(blocks), source, reason: source);
      }
    });

    test('Markdown around an unsupported inline tag still parses', () {
      final inlines = _inlines('**bold** <mark>x</mark> `code`');
      expect(inlines.first, const StrongInline(children: [TextInline('bold')]));
      expect(inlines.last, const InlineCodeInline('code'));
    });

    test('an unsupported block is a paragraph of literal text', () {
      expect(_parse('<table><tr><td>x</td></tr></table>'), [
        _p('<table><tr><td>x</td></tr></table>'),
      ]);
      expect(_parse('<ul>\n<li>one</li>\n</ul>\n\nafter'), [
        _p('<ul>\n<li>one</li>\n</ul>'),
        _p('after'),
      ]);
      expect(_parse('<script>\nalert("x")\n</script>'), [
        _p('<script>\nalert("x")\n</script>'),
      ]);
      expect(_parse('<hr>\n\ntext'), [_p('<hr>'), _p('text')]);
    });

    test('comment-only blocks are dropped, text around them is kept', () {
      expect(_parse('<!-- note -->'), isEmpty);
      expect(_parse('before\n\n<!-- a -->\n<!-- b -->\n\nafter'), [
        _p('before'),
        _p('after'),
      ]);
      expect(_parse('<!--\n- not a list\n# not a heading\n-->\n\nafter'), [
        _p('after'),
      ]);
    });

    test('an unterminated comment does not swallow the text before it', () {
      final blocks = _parse('before\n\n<!-- never closed\n\nstill here');
      expect(blocks.first, _p('before'));
    });

    test('enableHtml: false shows every tag as written', () {
      const off = MarkdownParserOptions(enableHtml: false);
      for (final source in [
        'a <b>x</b> b',
        'a <u>x</u> b',
        'one<br>two',
        'k <kbd>x</kbd> <a href="/u">y</a> <img src="a.png">',
      ]) {
        expect(_parse(source, options: off), [_p(source)], reason: source);
      }
      final details = _parse(
        '<details>\n<summary>S</summary>\n\nbody\n\n</details>',
        options: off,
      );
      expect(details.whereType<HtmlDetailsBlock>(), isEmpty);
      expect(_text(details), contains('<summary>S</summary>'));
      expect(_text(details), contains('body'));
    });
  });

  group('<details>', () {
    HtmlDetailsBlock details(String source) =>
        _parse(source).single as HtmlDetailsBlock;

    test('summary, body and the open attribute', () {
      final closed = details(
        '<details>\n<summary>Sum</summary>\n\nbody\n\n</details>',
      );
      expect(closed.initiallyOpen, isFalse);
      expect(closed.summary, const [TextInline('Sum')]);
      expect(closed.children, [_p('body')]);
      for (final opener in [
        '<details open>',
        '<details open="">',
        '<details class="x" open>',
        '<DETAILS OPEN>',
      ]) {
        expect(
          details(
            '$opener\n<summary>S</summary>\n\nbody\n\n</details>',
          ).initiallyOpen,
          isTrue,
          reason: opener,
        );
      }
      expect(
        details('<details data-open="no">\n\nbody\n\n</details>').initiallyOpen,
        isFalse,
      );
    });

    test('the summary holds inline Markdown and inline HTML', () {
      final block = details(
        '<details>\n<summary><b>Bold</b> *it* `code`</summary>\n\nbody\n</details>',
      );
      expect(block.summary, const [
        StrongInline(children: [TextInline('Bold')]),
        TextInline(' '),
        EmphasisInline(children: [TextInline('it')]),
        TextInline(' '),
        InlineCodeInline('code'),
      ]);
    });

    test('a block without a summary has an empty summary', () {
      final block = details('<details>\n\nbody\n\n</details>');
      expect(block.summary, isEmpty);
      expect(block.children, [_p('body')]);
    });

    test('the body is full Markdown', () {
      final block = details(
        '<details>\n<summary>S</summary>\n\n# Heading\n\n- a\n- b\n\n'
        '| x |\n| - |\n\n> quote\n\n```dart\ncode();\n\nmore();\n```\n\n</details>',
      );
      expect(_kinds(block.children), [
        HeadingBlock,
        ListBlock,
        TableBlock,
        BlockquoteBlock,
        CodeBlock,
      ]);
      expect((block.children.last as CodeBlock).code, 'code();\n\nmore();');
    });

    test('body text right after the summary, without a blank line', () {
      final block = details(
        '<details>\n<summary>S</summary>\nbody **bold**\n</details>',
      );
      expect(block.summary, const [TextInline('S')]);
      expect(block.children, const [
        ParagraphBlock(
          inlines: [
            TextInline('body '),
            StrongInline(children: [TextInline('bold')]),
          ],
        ),
      ]);
    });

    test('everything on one line', () {
      final block = details('<details><summary>S</summary>body</details>');
      expect(block.summary, const [TextInline('S')]);
      expect(block.children, [_p('body')]);
    });

    test('a closing tag inside a code fence does not close the block', () {
      final blocks = _parse(
        '<details>\n<summary>S</summary>\n\n```html\n</details>\n```\n\n'
        'tail\n\n</details>\n\nafter',
      );
      expect(_kinds(blocks), [HtmlDetailsBlock, ParagraphBlock]);
      final block = blocks.first as HtmlDetailsBlock;
      expect(_kinds(block.children), [CodeBlock, ParagraphBlock]);
      expect((block.children.first as CodeBlock).code, '</details>');
      expect(blocks.last, _p('after'));
    });

    test('details nest', () {
      final outer = details(
        '<details>\n<summary>Outer</summary>\n\nbefore\n\n'
        '<details>\n<summary>Inner</summary>\n\ninside\n\n</details>\n\n'
        'between\n\n</details>',
      );
      expect(outer.summary, const [TextInline('Outer')]);
      expect(_kinds(outer.children), [
        ParagraphBlock,
        HtmlDetailsBlock,
        ParagraphBlock,
      ]);
      final inner = outer.children[1] as HtmlDetailsBlock;
      expect(inner.summary, const [TextInline('Inner')]);
      expect(inner.children, [_p('inside')]);
    });

    test('text after the block is not part of it', () {
      final blocks = _parse(
        'before\n\n<details>\n<summary>S</summary>\n\nbody\n\n</details>\n\nafter',
      );
      expect(_kinds(blocks), [
        ParagraphBlock,
        HtmlDetailsBlock,
        ParagraphBlock,
      ]);
      expect(blocks.last, _p('after'));
      final tight = _parse(
        '<details>\n<summary>S</summary>\nbody\n</details>\nafter',
      );
      expect(_kinds(tight), [HtmlDetailsBlock, ParagraphBlock]);
      expect(tight.last, _p('after'));
    });

    test('an unclosed block holds the rest of the document', () {
      final block = details('<details>\n<summary>S</summary>\n\nbody\n\nmore');
      expect(block.summary, const [TextInline('S')]);
      expect(block.children, [_p('body'), _p('more')]);
    });

    test('a block element shows before its closing tag streams in', () {
      const source =
          'Intro.\n\n<details>\n<summary>Sum</summary>\n\nbody one\n\n'
          '```\ncode\n\nmore\n```\n\n</details>\n\nAfter.\n';
      final parser = GfmMarkdownParser();
      final summaryEnd = source.indexOf('</summary>') + '</summary>'.length;
      MarkdownDocument? last;
      for (var end = 1; end <= source.length; end++) {
        last = parser.parse(source.substring(0, end), isStreaming: true);
        if (end > summaryEnd) {
          expect(
            last.blocks.length,
            greaterThanOrEqualTo(2),
            reason: 'at $end',
          );
          final block = last.blocks[1] as HtmlDetailsBlock;
          expect(block.summary, const [TextInline('Sum')], reason: 'at $end');
        }
      }
      expect(last!.blocks, _parse(source));
      expect(_kinds(last.blocks), [
        ParagraphBlock,
        HtmlDetailsBlock,
        ParagraphBlock,
      ]);
      final block = last.blocks[1] as HtmlDetailsBlock;
      expect(_kinds(block.children), [ParagraphBlock, CodeBlock]);
      expect((block.children.last as CodeBlock).code, 'code\n\nmore');
    });

    test('details inside a list item and a quote', () {
      final list =
          _parse(
                '- item\n\n  <details>\n  <summary>S</summary>\n\n  body\n\n  </details>\n- next',
              ).single
              as ListBlock;
      expect(list.items, hasLength(2));
      final nested = list.items.first.children.last as HtmlDetailsBlock;
      expect(nested.summary, const [TextInline('S')]);
      expect(nested.children, [_p('body')]);
      final quote =
          _parse(
                '> <details>\n> <summary>S</summary>\n>\n> body\n>\n> </details>',
              ).single
              as BlockquoteBlock;
      final quoted = quote.children.single as HtmlDetailsBlock;
      expect(quoted.children, [_p('body')]);
    });
  });
}
