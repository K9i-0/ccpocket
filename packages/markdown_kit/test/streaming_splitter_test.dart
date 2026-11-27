import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

List<String> _split(String text) {
  final blocks = splitMarkdownBlocks(text);
  expect(blocks.join(), text, reason: 'blocks must reproduce the input');
  return blocks;
}

void main() {
  group('sanitizeStreamingTail holds unfinished inline syntax', () {
    test('bold and strikethrough appear once closed', () {
      expect(sanitizeStreamingTail('This is **impor'), 'This is ');
      expect(
        sanitizeStreamingTail('This is **important**'),
        'This is **important**',
      );
      expect(sanitizeStreamingTail('This is ~~wro'), 'This is ');
      // The first half of a pair is not shown alone.
      expect(sanitizeStreamingTail('This is *'), 'This is ');
      expect(sanitizeStreamingTail(r'An escaped \*'), r'An escaped \*');
    });

    test('a link appears once its destination is closed', () {
      expect(sanitizeStreamingTail('See [the do'), 'See ');
      expect(sanitizeStreamingTail('See [the docs]'), 'See ');
      expect(sanitizeStreamingTail('See [the docs](https://exa'), 'See ');
      expect(
        sanitizeStreamingTail('See [the docs](https://example.com)'),
        'See [the docs](https://example.com)',
      );
      expect(sanitizeStreamingTail('An image ![alt](https://e'), 'An image ');
      // Brackets that turn out not to be a link are released.
      expect(sanitizeStreamingTail('Item [1] is'), 'Item [1] is');
      expect(sanitizeStreamingTail('- [ ] todo'), '- [ ] todo');
      expect(sanitizeStreamingTail('> [!NOTE]'), '> [!NOTE]');
    });

    test('ordinary punctuation is not held', () {
      for (final source in [
        'Compute 2 * 3 * 4 and then carry on',
        'call snake_case_name now',
        'a `closed` span and **closed** bold',
        r'pay $5 now',
      ]) {
        expect(sanitizeStreamingTail(source), source);
      }
    });

    test('only the last line is held, and a new line releases it', () {
      expect(sanitizeStreamingTail('a **b\nnext'), 'a **b\nnext');
      expect(sanitizeStreamingTail('a **b\n'), 'a **b\n');
    });

    test('an opener far behind is taken as literal text', () {
      final long = 'a **b ${'word ' * 80}';
      expect(sanitizeStreamingTail(long), long);
    });

    test('nothing is held inside a code block', () {
      const source = '```\nprint("**not bold") # [not a link](';
      expect(sanitizeStreamingTail(source), source);
    });
  });

  test('sanitizeStreamingTail holds an alert marker until it is complete', () {
    expect(sanitizeStreamingTail('Intro\n\n> ['), 'Intro\n\n');
    expect(sanitizeStreamingTail('Intro\n\n> [!TI'), 'Intro\n\n');
    expect(sanitizeStreamingTail('Intro\n\n> [!TIP]'), 'Intro\n\n> [!TIP]');
    expect(sanitizeStreamingTail('> quoted [text'), '> quoted ');
  });

  group('sanitizeStreamingTail holds a table until it is one', () {
    test('header and delimiter rows appear together', () {
      expect(sanitizeStreamingTail('Intro\n\n| a | b'), 'Intro\n\n');
      expect(sanitizeStreamingTail('Intro\n\n| a | b |\n'), 'Intro\n\n');
      expect(
        sanitizeStreamingTail('Intro\n\n| a | b |\n| --- | -'),
        'Intro\n\n',
      );
      expect(
        sanitizeStreamingTail('Intro\n\n| a | b |\n| --- | --- |\n'),
        'Intro\n\n| a | b |\n| --- | --- |\n',
      );
      expect(
        sanitizeStreamingTail('Intro\n\n| a | b |\n| --- | --- |\n| 1 | 2'),
        'Intro\n\n| a | b |\n| --- | --- |\n| 1 | 2',
      );
    });

    test('a pipe line that is not a table is released', () {
      expect(sanitizeStreamingTail('| just text\nmore'), '| just text\nmore');
    });

    test('a streamed table never shows as raw pipes', () {
      const source = 'Intro\n\n| a | b |\n| --- | --- |\n| 1 | 2 |\n\nAfter\n';
      final parser = GfmMarkdownParser();
      for (var end = 1; end <= source.length; end++) {
        final document = parser.parse(
          source.substring(0, end),
          isStreaming: true,
        );
        for (final block in document.blocks) {
          if (block is ParagraphBlock) {
            expect(
              extractBlockRenderedText(block).contains('|'),
              isFalse,
              reason: source.substring(0, end),
            );
          }
        }
      }
    });
  });

  group('splitMarkdownBlocks', () {
    test('returns no blocks for empty text', () {
      expect(splitMarkdownBlocks(''), isEmpty);
    });

    test('splits paragraphs and headings at blank lines', () {
      expect(_split('# Title\n\nfirst para\nsame para\n\nsecond'), [
        '# Title\n\n',
        'first para\nsame para\n\n',
        'second',
      ]);
    });

    test('keeps multiple blank lines and CRLF with the preceding block', () {
      expect(_split('one\r\n\r\n\r\ntwo\r\n'), ['one\r\n\r\n\r\n', 'two\r\n']);
    });

    test('does not split without a blank line', () {
      expect(_split('# Title\npara\n- item'), ['# Title\npara\n- item']);
    });

    test('keeps leading blank lines in the first block', () {
      expect(_split('\n\npara\n\nnext'), ['\n\npara\n\n', 'next']);
    });

    test('keeps blank lines inside a closed fence', () {
      const text =
          'intro\n\n```dart\nfinal a = 1;\n\nfinal b = 2;\n```\n\nafter';
      expect(_split(text), [
        'intro\n\n',
        '```dart\nfinal a = 1;\n\nfinal b = 2;\n```\n\n',
        'after',
      ]);
    });

    test('keeps the rest of the text with an unterminated fence', () {
      const text = 'intro\n\n~~~\ncode\n\nmore code\n\n# not a heading';
      expect(_split(text), [
        'intro\n\n',
        '~~~\ncode\n\nmore code\n\n# not a heading',
      ]);
    });

    test('requires a matching fence marker to close', () {
      const text = '````\n```\n\nstill code\n````\n\nafter';
      expect(_split(text), ['````\n```\n\nstill code\n````\n\n', 'after']);
      const tilde = '~~~\n```\n\nstill code\n~~~\n\nafter';
      expect(_split(tilde), ['~~~\n```\n\nstill code\n~~~\n\n', 'after']);
    });

    test('keeps a fence inside a list item with the list', () {
      const text = '- item\n  ```\n  code\n\n  more\n  ```\n\nafter';
      expect(_split(text), [
        '- item\n  ```\n  code\n\n  more\n  ```\n\n',
        'after',
      ]);
    });

    test('keeps tables whole and splits after them', () {
      const text = '| a | b |\n|---|---|\n| 1 | 2 |\n\nnext';
      expect(_split(text), ['| a | b |\n|---|---|\n| 1 | 2 |\n\n', 'next']);
    });

    test('keeps a loose list in one block and splits where its marker '
        'changes', () {
      const unordered = 'Intro:\n\n- one\n\n- two\n\n* three\n\nOutro';
      expect(_split(unordered), [
        'Intro:\n\n',
        '- one\n\n- two\n\n',
        // Another bullet character starts another list.
        '* three\n\n',
        'Outro',
      ]);
      const ordered = '1. one\n\n2. two\n\n10) ten\n\nOutro';
      expect(_split(ordered), ['1. one\n\n2. two\n\n', '10) ten\n\n', 'Outro']);
    });

    test('keeps indented continuation lines with the preceding block', () {
      const text = '- item\n\n  continued paragraph\n\n    nested code\n\nend';
      expect(_split(text), [
        '- item\n\n  continued paragraph\n\n    nested code\n\n',
        'end',
      ]);
      expect(_split('para\n\n\tindented'), ['para\n\n\tindented']);
    });

    test('splits a list from a following paragraph', () {
      expect(_split('- a\n\npara\n\n- b'), ['- a\n\n', 'para\n\n', '- b']);
    });

    test('splits blockquotes, alerts, and rules', () {
      expect(_split('> [!NOTE]\n> alert\n\n---\n\ntext'), [
        '> [!NOTE]\n> alert\n\n',
        '---\n\n',
        'text',
      ]);
    });

    test('keeps <details> blocks with internal blank lines together', () {
      const text =
          'before\n\n<details>\n<summary>More</summary>\n\npara 1\n\npara 2\n</details>\n\nafter';
      expect(_split(text), [
        'before\n\n',
        '<details>\n<summary>More</summary>\n\npara 1\n\npara 2\n</details>\n\n',
        'after',
      ]);
    });

    test(
      'does not let inline `<details>` in prose disable subsequent splits',
      () {
        const text =
            'Use `<details>` for toggles.\n\nNext paragraph.\n\nThird.';
        expect(_split(text), [
          'Use `<details>` for toggles.\n\n',
          'Next paragraph.\n\n',
          'Third.',
        ]);
      },
    );

    test(r'keeps $$ and \[ block math with internal blank lines together', () {
      const dollar = 'before\n\n\$\$\na = 1\n\nb = 2\n\$\$\n\nafter';
      expect(_split(dollar), [
        'before\n\n',
        '\$\$\na = 1\n\nb = 2\n\$\$\n\n',
        'after',
      ]);

      const bracket =
          r'before'
          '\n\n'
          r'\['
          '\n'
          'x = 1\n\ny = 2\n'
          r'\]'
          '\n\nafter';
      expect(_split(bracket), [
        'before\n\n',
        '\\[\nx = 1\n\ny = 2\n\\]\n\n',
        'after',
      ]);
    });

    test(
      'falls back to a single block with reference and footnote definitions',
      () {
        const text = 'See [docs][d].\n\nMore text.\n\n[d]: https://example.com';
        expect(_split(text), [text]);
        const footnote = 'Claim[^1].\n\nMore.\n\n[^1]: Source';
        expect(_split(footnote), [footnote]);
      },
    );

    test(
      'falls back to a single block with multi-paragraph raw HTML blocks',
      () {
        const text = 'intro\n\n<!--\ncomment\n\nstill comment\n-->\n\nafter';
        expect(_split(text), [text]);
        const pre = 'intro\n\n<pre>\na\n\nb\n</pre>';
        expect(_split(pre), [pre]);
      },
    );

    test('ignores definition-like and HTML lines inside fences', () {
      const text =
          '```ts\ntype M = {\n  [key: string]: string;\n\n};\n'
          '<!-- note\n\n[x]: y\n```\n\nafter';
      expect(_split(text), [
        '```ts\ntype M = {\n  [key: string]: string;\n\n};\n'
            '<!-- note\n\n[x]: y\n```\n\n',
        'after',
      ]);
      const outside = 'para\n\n  [key: string]: x\n\nafter';
      expect(_split(outside), [outside]);
    });

    test('reproduces a streamed prefix at every length', () {
      const full =
          '# Plan\n\nSome **bold** text.\n\n- a\n\n- b\n\n'
          '```js\nx();\n\ny();\n```\n\n'
          '<details>\n<summary>Info</summary>\n\nInner\n</details>\n\n'
          '| h |\n|---|\n| v |\n\n> quote\n\nDone.\n';
      for (var i = 0; i <= full.length; i++) {
        final prefix = full.substring(0, i);
        expect(splitMarkdownBlocks(prefix).join(), prefix);
      }
    });
  });

  group('sanitizeStreamingTail', () {
    test('holds partial opening fence and info-string lines until newline', () {
      expect(sanitizeStreamingTail('Hello\n\n`'), 'Hello\n\n');
      expect(sanitizeStreamingTail('Hello\n\n``'), 'Hello\n\n');
      expect(sanitizeStreamingTail('Hello\n\n```'), 'Hello\n\n');
      expect(sanitizeStreamingTail('Hello\n\n```da'), 'Hello\n\n');
      expect(sanitizeStreamingTail('Hello\n\n```dart'), 'Hello\n\n');
      expect(sanitizeStreamingTail('Hello\n\n~~~python'), 'Hello\n\n');
      expect(sanitizeStreamingTail('```dart'), '');

      // Once newline arrives, the fence line is complete and no longer held.
      expect(sanitizeStreamingTail('Hello\n\n```dart\n'), 'Hello\n\n```dart\n');
      expect(
        sanitizeStreamingTail('Hello\n\n```dart\nfinal x = 1;'),
        'Hello\n\n```dart\nfinal x = 1;',
      );
    });

    test('shows a closed code span and holds an unclosed one', () {
      expect(sanitizeStreamingTail('Hello\n\n`code`'), 'Hello\n\n`code`');
      expect(sanitizeStreamingTail('Hello\n\n`in'), 'Hello\n\n');
      // Three backticks with a backtick in the "info string" are not a fence
      // but the start of a code span, which is still open here.
      expect(sanitizeStreamingTail('Hello\n\n```inline`'), 'Hello\n\n');
      expect(
        sanitizeStreamingTail('Hello\n\n```inline` then ```'),
        'Hello\n\n```inline` then ```',
      );
    });

    test('holds partial closing fence runs inside an open fence', () {
      expect(
        sanitizeStreamingTail('```dart\nfinal x = 1;\n`'),
        '```dart\nfinal x = 1;\n',
      );
      expect(
        sanitizeStreamingTail('```dart\nfinal x = 1;\n``'),
        '```dart\nfinal x = 1;\n',
      );
      expect(
        sanitizeStreamingTail('```dart\nfinal x = 1;\n  ``'),
        '```dart\nfinal x = 1;\n',
      );
      // 4-backtick fence holds up to 3 closing backticks.
      expect(sanitizeStreamingTail('````dart\ncode\n```'), '````dart\ncode\n');
      // Complete closing fence is kept intact.
      expect(
        sanitizeStreamingTail('```dart\nfinal x = 1;\n```'),
        '```dart\nfinal x = 1;\n```',
      );
      // Real code starting with a backtick (JS template literal) is kept.
      expect(sanitizeStreamingTail('```js\n`hello`'), '```js\n`hello`');
    });

    test('holds partial display math openers and closers', () {
      expect(
        sanitizeStreamingTail(
          r'Hello'
          '\n\n'
          r'\[',
        ),
        'Hello\n\n',
      );
      expect(sanitizeStreamingTail('Hello\n\n\$\$'), 'Hello\n\n');
      expect(sanitizeStreamingTail('\$\$\nx + y\n\$'), '\$\$\nx + y\n');
      expect(sanitizeStreamingTail('\\[\nx + y\n\\'), '\\[\nx + y\n');
    });

    test('prevents fence flicker when streaming token-by-token through GfmMarkdownParser', () {
      final parser = GfmMarkdownParser();
      const full = 'Intro\n\n```dart\nfinal x = 1;\n```\n\nDone';

      for (var i = 0; i <= full.length; i++) {
        final prefix = full.substring(0, i);
        final doc = parser.parse(prefix, isStreaming: true);
        for (final block in doc.blocks.whereType<CodeBlock>()) {
          // Never see a partial language string like 'd', 'da', 'dar'.
          expect(block.language, 'dart');
          // Never see stray closing backticks inside code content.
          expect(block.code.contains('`'), isFalse);
        }
      }
    });
  });

  group('lists with different markers', () {
    List<String> kinds(String source) => [
      for (final block in GfmMarkdownParser().parse(source).blocks)
        block is ListBlock
            ? 'list(${block.items.length})'
            : block.runtimeType.toString(),
    ];

    test('a list with another marker after a blank line is its own chunk', () {
      expect(splitMarkdownBlocks('- a\n\n1. b\n'), ['- a\n\n', '1. b\n']);
      expect(splitMarkdownBlocks('- a\n\n* b\n'), ['- a\n\n', '* b\n']);
      expect(splitMarkdownBlocks('1. a\n\n2) b\n'), ['1. a\n\n', '2) b\n']);
      expect(splitMarkdownBlocks('- a\n- b\n\n1. c\n\n- [ ] d\n'), [
        '- a\n- b\n\n',
        '1. c\n\n',
        '- [ ] d\n',
      ]);
    });

    test('a loose list with one marker stays one chunk', () {
      expect(splitMarkdownBlocks('- a\n\n- b\n\n- c\n'), hasLength(1));
      expect(splitMarkdownBlocks('1. a\n\n2. b\n'), hasLength(1));
    });

    test('a nested list with another marker does not end the outer one', () {
      const source = '- a\n  1. nested\n\n- b\n';
      expect(splitMarkdownBlocks(source), hasLength(1));
      expect(kinds(source), ['list(2)']);
    });

    test('a marker change right below other text does not split', () {
      // Whether `2.` here is a new list or more of the first item depends on
      // rules the splitter does not model, so it leaves the block whole.
      expect(splitMarkdownBlocks('- a\n2. b\n\n- c\n'), hasLength(1));
      expect(splitMarkdownBlocks('- a\n2. b\n\n3. c\n'), hasLength(1));
    });

    test('the lists are the same split or not', () {
      const unsplit = '[zz-unsplit]: /unsplit\n\n';
      for (final source in [
        '- a\n\n1. b\n',
        '- a\n\n* b\n\n+ c\n',
        '1. a\n\n2) b\n',
        '3. a\n\n- b\n\n- [ ] c\n',
        '- a\n\n  more\n\n1. b\n   - nested\n\n* c\n',
        '- a\n1. b\n\n- c\n',
        '- a\n2. b\n\n1. c\n',
        'text\n- a\n\n1. b\n',
        '- a\n\n* * *\n\n- b\n',
        '- a\n\n -  b\n\n1. c\n',
        '10. a\n   - b\n\n- c\n',
      ]) {
        expect(
          GfmMarkdownParser().parse(source).blocks,
          GfmMarkdownParser().parse('$unsplit$source').blocks,
          reason: source,
        );
      }
    });

    test('each list gets a source range of its own', () {
      const source = '- a\n- b\n\n1. c\n\n- [ ] d\n';
      final document = GfmMarkdownParser().parse(source);
      expect(document.blocks, hasLength(3));
      expect(document.blockSourceRanges, const [
        MarkdownSourceRange(0, 9),
        MarkdownSourceRange(9, 15),
        MarkdownSourceRange(15, 23),
      ]);
    });
  });

  group('definitions and fences the splitter used to misread', () {
    const unsplit = '[zz-unsplit]: /unsplit\n\n';

    void expectSameSplitOrNot(String source) {
      expect(
        GfmMarkdownParser().parse(source).blocks,
        GfmMarkdownParser().parse('$unsplit$source').blocks,
        reason: source,
      );
    }

    test('a reference label that runs on to the next line keeps its link', () {
      const source = 'See [Baz][Foo bar].\n\nMore.\n\n[Foo\n  bar]: /url\n';
      expect(splitMarkdownBlocks(source), hasLength(1));
      final first = GfmMarkdownParser().parse(source).blocks.first;
      expect(
        (first as ParagraphBlock).inlines
            .whereType<LinkInline>()
            .single
            .destination,
        '/url',
      );
    });

    test('a line that only opens a bracket does not stop the splitting', () {
      expect(
        splitMarkdownBlocks('[not a label\n\nnext\n\nlast\n'),
        hasLength(3),
      );
      expect(
        splitMarkdownBlocks('[open\nclosed] here\n\nnext\n'),
        hasLength(2),
      );
    });

    test('a fence line outside the item opens a new fence', () {
      // The first fence ends with its item; the second runs to the end and
      // holds the blank line.
      const source = '- item\n  ```\n  inside\n```\nouter\n\nstill code\n';
      expect(splitMarkdownBlocks(source), hasLength(1));
      expectSameSplitOrNot(source);
    });

    test('a fence after an empty item and a blank line is not in the item', () {
      const source = '-\n\n  ```\n  code\nmore\n\nstill code\n  ```\n\nafter\n';
      expectSameSplitOrNot(source);
      expect(splitMarkdownBlocks(source).last, 'after\n');
    });

    test('a fence at the margin ends the list item above it', () {
      const source =
          '- a\n```\none\n```\n  ```\n  two\n\n  still two\n  ```\n\nafter\n';
      expectSameSplitOrNot(source);
      expect(splitMarkdownBlocks(source).last, 'after\n');
    });

    test('a fence inside an item still ends where the item does', () {
      const source = '- item\n  ```\n  code\n\n  more\n  ```\n\nafter\n';
      expect(splitMarkdownBlocks(source), [
        '- item\n  ```\n  code\n\n  more\n  ```\n\n',
        'after\n',
      ]);
      expectSameSplitOrNot(source);
    });
  });
}
