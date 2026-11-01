import 'package:ccpocket/utils/markdown_block_splitter.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _split(String text) {
  final blocks = splitMarkdownBlocks(text);
  expect(blocks.join(), text, reason: 'blocks must reproduce the input');
  return blocks;
}

void main() {
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
    const text = 'intro\n\n```dart\nfinal a = 1;\n\nfinal b = 2;\n```\n\nafter';
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

  test('keeps loose list items in one block', () {
    const text = 'Intro:\n\n- one\n\n- two\n\n* three\n\nOutro';
    expect(_split(text), [
      'Intro:\n\n',
      '- one\n\n- two\n\n* three\n\n',
      'Outro',
    ]);
  });

  test('keeps loose ordered list items in one block', () {
    const text = '1. one\n\n2) two\n\n10. ten\n\nOutro';
    expect(_split(text), ['1. one\n\n2) two\n\n10. ten\n\n', 'Outro']);
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

  test('splits blockquotes and rules', () {
    expect(_split('> quote\n\n---\n\ntext'), [
      '> quote\n\n',
      '---\n\n',
      'text',
    ]);
  });

  test('falls back to a single block with reference definitions', () {
    const text = 'See [docs][d].\n\nMore text.\n\n[d]: https://example.com';
    expect(_split(text), [text]);
    const footnote = 'Claim[^1].\n\nMore.\n\n[^1]: Source';
    expect(_split(footnote), [footnote]);
  });

  test('falls back to a single block with multi-paragraph HTML blocks', () {
    const text = 'intro\n\n<!--\ncomment\n\nstill comment\n-->\n\nafter';
    expect(_split(text), [text]);
    const pre = 'intro\n\n<pre>\na\n\nb\n</pre>';
    expect(_split(pre), [pre]);
  });

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
        '# Plan\n\nSome **bold** text.\n\n- a\n\n- b\n\n```js\nx();\n\ny();\n```'
        '\n\n| h |\n|---|\n| v |\n\n> quote\n\nDone.\n';
    for (var i = 0; i <= full.length; i++) {
      final prefix = full.substring(0, i);
      expect(splitMarkdownBlocks(prefix).join(), prefix);
    }
    expect(_split(full), [
      '# Plan\n\n',
      'Some **bold** text.\n\n',
      '- a\n\n- b\n\n',
      '```js\nx();\n\ny();\n```\n\n',
      '| h |\n|---|\n| v |\n\n',
      '> quote\n\n',
      'Done.\n',
    ]);
  });
}
