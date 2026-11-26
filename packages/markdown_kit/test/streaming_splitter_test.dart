import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

List<String> _split(String text) {
  final blocks = splitMarkdownBlocks(text);
  expect(blocks.join(), text, reason: 'blocks must reproduce the input');
  return blocks;
}

void main() {
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

    test('keeps loose unordered and ordered list items in one block', () {
      const unordered = 'Intro:\n\n- one\n\n- two\n\n* three\n\nOutro';
      expect(_split(unordered), [
        'Intro:\n\n',
        '- one\n\n- two\n\n* three\n\n',
        'Outro',
      ]);
      const ordered = '1. one\n\n2) two\n\n10. ten\n\nOutro';
      expect(_split(ordered), ['1. one\n\n2) two\n\n10. ten\n\n', 'Outro']);
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

    test('does not hold inline backtick code spans on a line', () {
      expect(sanitizeStreamingTail('Hello\n\n`code`'), 'Hello\n\n`code`');
      expect(sanitizeStreamingTail('Hello\n\n`in'), 'Hello\n\n`in');
      expect(
        sanitizeStreamingTail('Hello\n\n```inline`'),
        'Hello\n\n```inline`',
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
}
