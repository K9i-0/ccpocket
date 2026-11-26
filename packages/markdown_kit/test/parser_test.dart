import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

class _CountingLocalhostRule extends MarkdownInlineRule {
  int matchAtCalls = 0;

  @override
  Set<int> get triggerCodeUnits => const {0x68, 0x48}; // 'h', 'H'

  static final _pattern = RegExp(
    r'https?://localhost(?::\d+)?(?:/[^\s<>()!.,;:]*)?',
    caseSensitive: false,
  );

  @override
  MarkdownInlineMatch? matchAt(String text, int index) {
    matchAtCalls++;
    final match = _pattern.matchAsPrefix(text, index);
    if (match == null) return null;
    final url = match.group(0)!;
    return MarkdownInlineMatch(
      end: match.end,
      inline: LinkInline(
        destination: url,
        children: [TextInline(url)],
        isAutolink: true,
      ),
    );
  }
}

class _CountingFilePathRule extends MarkdownInlineRule {
  int matchAtCalls = 0;

  static final _pattern = RegExp(
    r'[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)+(?::\d+)?',
  );

  @override
  bool mayMatch(String text) => text.contains('/');

  @override
  MarkdownInlineMatch? matchAt(String text, int index) {
    matchAtCalls++;
    if (index > 0 && !RegExp(r'[\s(\[]').hasMatch(text[index - 1])) {
      return null;
    }
    final match = _pattern.matchAsPrefix(text, index);
    if (match == null) return null;
    final path = match.group(0)!;
    return MarkdownInlineMatch(
      end: match.end,
      inline: CustomInline(kind: 'file_path', text: path, data: {'path': path}),
    );
  }
}

void main() {
  group('GfmMarkdownParser core GFM blocks and inlines', () {
    late GfmMarkdownParser parser;

    setUp(() {
      parser = GfmMarkdownParser();
    });

    test('parses empty input to empty document', () {
      expect(parser.parse(''), MarkdownDocument.empty);
      expect(parser.parse('   \n\n  ').blocks, isEmpty);
    });

    test(
      'parses headings h1-h6 and paragraphs with rich inline formatting',
      () {
        const md = '''
# Title

### Sub **Heading**

Hello *world*, **bold**, ~~strike~~, and `code`.
''';
        final doc = parser.parse(md);
        expect(doc.blocks.length, 3);

        final h1 = doc.blocks[0] as HeadingBlock;
        expect(h1.level, 1);
        expect(h1.inlines, [const TextInline('Title')]);

        final h3 = doc.blocks[1] as HeadingBlock;
        expect(h3.level, 3);
        expect(h3.inlines, [
          const TextInline('Sub '),
          const StrongInline(children: [TextInline('Heading')]),
        ]);

        final p = doc.blocks[2] as ParagraphBlock;
        expect(p.inlines, [
          const TextInline('Hello '),
          const EmphasisInline(children: [TextInline('world')]),
          const TextInline(', '),
          const StrongInline(children: [TextInline('bold')]),
          const TextInline(', '),
          const StrikethroughInline(children: [TextInline('strike')]),
          const TextInline(', and '),
          const InlineCodeInline('code'),
          const TextInline('.'),
        ]);
      },
    );

    test(
      'parses fenced and indented code blocks with metadata and closed flag',
      () {
        const md = '''
```dart title="main.dart"
void main() {
  print('<hello & world>');
}
```

    indented code
    line 2

~~~python
x = 1
''';
        final doc = parser.parse(md);
        expect(doc.blocks.length, 3);

        final fenced = doc.blocks[0] as CodeBlock;
        expect(fenced.isFenced, isTrue);
        expect(fenced.closed, isTrue);
        expect(fenced.language, 'dart');
        expect(fenced.infoString, 'dart title="main.dart"');
        expect(fenced.code, "void main() {\n  print('<hello & world>');\n}");

        final indented = doc.blocks[1] as CodeBlock;
        expect(indented.isFenced, isFalse);
        expect(indented.language, isNull);
        expect(indented.code, 'indented code\nline 2');

        final unclosed = doc.blocks[2] as CodeBlock;
        expect(unclosed.isFenced, isTrue);
        expect(unclosed.closed, isFalse);
        expect(unclosed.language, 'python');
        expect(unclosed.code, 'x = 1');
      },
    );

    test('parses ordered, unordered, nested, and task lists', () {
      const md = '''
- [x] Done task
- [ ] Pending task
- Regular item
  - Nested child

3. Third
4. Fourth
''';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 2);

      final ul = doc.blocks[0] as ListBlock;
      expect(ul.ordered, isFalse);
      expect(ul.items.length, 3);
      expect(ul.items[0].checked, isTrue);
      expect(extractListItemRenderedText(ul.items[0]), 'Done task');
      expect(ul.items[1].checked, isFalse);
      expect(extractListItemRenderedText(ul.items[1]), 'Pending task');
      expect(ul.items[2].checked, isNull);
      expect(ul.items[2].children.length, 2);
      expect(ul.items[2].children[1], isA<ListBlock>());

      final ol = doc.blocks[1] as ListBlock;
      expect(ol.ordered, isTrue);
      expect(ol.start, 3);
      expect(ol.items.length, 2);
    });

    test('parses GFM tables with column alignments and empty cells', () {
      const md = '''
| Left | Center | Right | Default |
| :--- | :----: | ----: | ------- |
| a | **b** | | d |
| 1 | 2 | 3 | 4 |
''';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);

      final table = doc.blocks.first as TableBlock;
      expect(table.alignments, [
        TableColumnAlign.left,
        TableColumnAlign.center,
        TableColumnAlign.right,
        TableColumnAlign.none,
      ]);
      expect(table.columnCount, 4);
      expect(table.rows.length, 2);
      expect(
        extractBlockRenderedText(table),
        'Left\tCenter\tRight\tDefault\na\tb\t\td\n1\t2\t3\t4',
      );
    });

    test(
      'parses links, autolinks, reference links, images, breaks, and hr',
      () {
        const md = '''
Visit [Dart](https://dart.dev "Dart Lang") or https://flutter.dev and [Ref][r].

![Logo](https://example.com/logo.png "Logo Title")

Line one  
Line two\\
Line three

---

[r]: https://example.org
''';
        final doc = parser.parse(md);
        expect(doc.blocks.length, 4);

        final p1 = doc.blocks[0] as ParagraphBlock;
        final links = p1.inlines.whereType<LinkInline>().toList();
        expect(links.length, 3);
        expect(links[0].destination, 'https://dart.dev');
        expect(links[0].title, 'Dart Lang');
        expect(links[0].isAutolink, isFalse);
        expect(links[1].destination, 'https://flutter.dev');
        expect(links[1].isAutolink, isTrue);
        expect(links[2].destination, 'https://example.org');

        final p2 = doc.blocks[1] as ParagraphBlock;
        expect(p2.inlines, [
          const ImageInline(
            source: 'https://example.com/logo.png',
            alt: 'Logo',
            title: 'Logo Title',
          ),
        ]);

        final p3 = doc.blocks[2] as ParagraphBlock;
        expect(extractBlockRenderedText(p3), 'Line one\nLine two\nLine three');

        expect(doc.blocks[3], const ThematicBreakBlock());
      },
    );

    test('decodes HTML entities in prose but leaves code untouched', () {
      const md = 'Tom &amp; Jerry &mdash; `a &amp; b` &#65; &#x42;';
      final doc = parser.parse(md);
      final p = doc.blocks.first as ParagraphBlock;
      expect(p.inlines, [
        const TextInline('Tom & Jerry \u2014 '),
        const InlineCodeInline('a &amp; b'),
        const TextInline(' A B'),
      ]);
    });
  });

  group('GFM alerts', () {
    test('parses all five GFM alert kinds (case-insensitive)', () {
      final parser = GfmMarkdownParser();
      const kinds = [
        ('NOTE', AlertKind.note),
        ('tip', AlertKind.tip),
        ('IMPORTANT', AlertKind.important),
        ('Warning', AlertKind.warning),
        ('CAUTION', AlertKind.caution),
      ];

      for (final (marker, expectedKind) in kinds) {
        final doc = parser.parse('> [!$marker]\n> Body line');
        expect(doc.blocks.length, 1);
        final alert = doc.blocks.first as AlertBlock;
        expect(alert.kind, expectedKind);
        expect(extractBlockRenderedText(alert), 'Body line');
      }
    });

    test('parses multi-paragraph alerts and keeps regular quotes as BlockquoteBlock', () {
      final parser = GfmMarkdownParser();
      final multi = parser.parse('> [!WARNING]\n>\n> First\n>\n> Second');
      final alert = multi.blocks.first as AlertBlock;
      expect(alert.kind, AlertKind.warning);
      expect(alert.children.length, 2);
      expect(extractBlockRenderedText(alert), 'First\nSecond');

      final inlineText = parser.parse('> [!NOTE] inline text on same line');
      expect(inlineText.blocks.first, isA<BlockquoteBlock>());

      final disabled = GfmMarkdownParser(
        options: const MarkdownParserOptions(enableAlerts: false),
      ).parse('> [!NOTE]\n> Body');
      expect(disabled.blocks.first, isA<BlockquoteBlock>());
    });
  });

  group('Common HTML support', () {
    late GfmMarkdownParser parser;

    setUp(() {
      parser = GfmMarkdownParser();
    });

    test('parses inline HTML tags and nested Markdown cleanly', () {
      const md =
          '<b>bold</b> <strong>strong</strong> <i>italic</i> <em>em</em> '
          '<u>under</u> <s>strike</s> <del>del</del> '
          'H<sub>2</sub>O x<sup>2</sup> <kbd>Ctrl</kbd> '
          '<a href="https://example.com" title="Ex"><b>Link</b></a> '
          '<img src="a.png" alt="Pic" title="T" />'
          'a<br>b<br/>c';
      final doc = parser.parse(md);
      final p = doc.blocks.first as ParagraphBlock;

      expect(p.inlines.whereType<StrongInline>().length, 2);
      expect(p.inlines.whereType<EmphasisInline>().length, 2);
      expect(p.inlines.whereType<UnderlineInline>().length, 1);
      expect(p.inlines.whereType<StrikethroughInline>().length, 2);
      expect(p.inlines.whereType<SubscriptInline>().length, 1);
      expect(p.inlines.whereType<SuperscriptInline>().length, 1);
      expect(p.inlines.whereType<KeyboardInline>().length, 1);

      final link = p.inlines.whereType<LinkInline>().single;
      expect(link.destination, 'https://example.com');
      expect(link.title, 'Ex');
      expect(link.children, [
        const StrongInline(children: [TextInline('Link')]),
      ]);

      final img = p.inlines.whereType<ImageInline>().single;
      expect(img.source, 'a.png');
      expect(img.alt, 'Pic');
      expect(img.title, 'T');

      final breaks = p.inlines.whereType<LineBreakInline>().toList();
      expect(breaks.length, 2);
      expect(breaks.every((b) => b.isHard), isTrue);
    });

    test('parses <details> and <summary> with nested Markdown blocks', () {
      const md = '''
<details open>
<summary>Show **more**</summary>

Paragraph inside details.

```dart
final x = 1;
```

- item 1
- item 2
</details>
''';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      final details = doc.blocks.first as HtmlDetailsBlock;
      expect(details.initiallyOpen, isTrue);
      expect(details.summary, [
        const TextInline('Show '),
        const StrongInline(children: [TextInline('more')]),
      ]);
      expect(details.children.length, 3);
      expect(details.children[0], isA<ParagraphBlock>());
      expect(details.children[1], isA<CodeBlock>());
      expect(details.children[2], isA<ListBlock>());
      expect(
        extractBlockRenderedText(details),
        'Show more\nParagraph inside details.\nfinal x = 1;\nitem 1\nitem 2',
      );
    });

    test('handles unclosed HTML tags gracefully and ignores HTML inside code spans', () {
      final unclosed = parser.parse('Start <u>unclosed text');
      expect(extractDocumentRenderedText(unclosed), 'Start <u>unclosed text');

      final inCode = parser.parse('Code `<u>raw</u>` and `<br>`');
      final p = inCode.blocks.first as ParagraphBlock;
      expect(p.inlines.whereType<UnderlineInline>(), isEmpty);
      expect(p.inlines.whereType<LineBreakInline>(), isEmpty);
      expect(p.inlines.whereType<InlineCodeInline>().map((c) => c.code), [
        '<u>raw</u>',
        '<br>',
      ]);
    });

    test(
      'keeps <details> summary anchored to start and preserves indented code',
      () {
        const md = '''
<details>

    indented code inside details

```html
<summary>Not the outer summary</summary>
```
</details>
''';
        final doc = parser.parse(md);
        final details = doc.blocks.single as HtmlDetailsBlock;
        expect(details.summary, isEmpty);
        expect(details.children.length, 2);

        final indented = details.children[0] as CodeBlock;
        expect(indented.isFenced, isFalse);
        expect(indented.code, 'indented code inside details');

        final fenced = details.children[1] as CodeBlock;
        expect(fenced.language, 'html');
        expect(fenced.code, '<summary>Not the outer summary</summary>');
      },
    );

    test('parses standalone <img>, <br>, and inline HTML lines instead of raw text', () {
      const md = '''
<img src="a.png" alt="Demo" title="Preview" />

<br />

<a href="https://example.com"><b>Standalone link</b></a>
''';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 3);

      final p1 = doc.blocks[0] as ParagraphBlock;
      expect(p1.inlines, [
        const ImageInline(source: 'a.png', alt: 'Demo', title: 'Preview'),
      ]);

      final p2 = doc.blocks[1] as ParagraphBlock;
      expect(p2.inlines, [const LineBreakInline(isHard: true)]);

      final p3 = doc.blocks[2] as ParagraphBlock;
      expect(p3.inlines, [
        const LinkInline(
          destination: 'https://example.com',
          children: [
            StrongInline(children: [TextInline('Standalone link')]),
          ],
        ),
      ]);
    });
  });

  group('Footnotes', () {
    test(
      'parses and resolves footnote references and multi-paragraph definitions',
      () {
        final parser = GfmMarkdownParser();
        const md = '''
First claim[^b] and second claim[^a]. Also code `[^a]`.

[^a]: Alpha note.
[^b]: Beta line one.

    Beta second paragraph.
''';
        final doc = parser.parse(md);
        expect(doc.blocks.length, 2);

        final p = doc.blocks[0] as ParagraphBlock;
        final refs = p.inlines.whereType<FootnoteRefInline>().toList();
        expect(refs.length, 2);
        expect(refs[0], const FootnoteRefInline(label: 'b', index: 1));
        expect(refs[1], const FootnoteRefInline(label: 'a', index: 2));
        expect(refs[0].displayLabel, '[1]');

        final defsBlock = doc.blocks[1] as FootnoteDefinitionsBlock;
        expect(defsBlock.definitions.length, 2);
        expect(defsBlock.definitions[0].label, 'b');
        expect(defsBlock.definitions[0].index, 1);
        expect(defsBlock.definitions[0].children.length, 2);
        expect(defsBlock.definitions[1].label, 'a');
        expect(defsBlock.definitions[1].index, 2);

        expect(
          extractBlockRenderedText(defsBlock),
          'Beta line one.\nBeta second paragraph.\nAlpha note.',
        );
      },
    );
  });

  group('LaTeX math', () {
    test(
      r'parses \(...\) and \[...\] by default and leaves $...$ as currency',
      () {
        final parser = GfmMarkdownParser();
        const md = r'''
Inline \(E = mc^2\) and price $5 and $10 plus `\(not_math\)`.

\[
\int_0^1 x^2 \, dx = \frac{1}{3}
\]
''';
        final doc = parser.parse(md);
        expect(doc.blocks.length, 2);

        final p = doc.blocks[0] as ParagraphBlock;
        expect(
          p.inlines.whereType<InlineLatexInline>().single.expression,
          'E = mc^2',
        );
        expect(
          extractBlockRenderedText(p),
          r'Inline E = mc^2 and price $5 and $10 plus \(not_math\).',
        );

        final mathBlock = doc.blocks[1] as BlockLatexBlock;
        expect(mathBlock.closed, isTrue);
        expect(mathBlock.expression, r'\int_0^1 x^2 \, dx = \frac{1}{3}');
      },
    );

    test(
      r'supports opt-in $...$ and $$...$$ while guarding currency expressions',
      () {
        final parser = GfmMarkdownParser(
          options: const MarkdownParserOptions(enableDollarLatex: true),
        );
        const md = r'''
Area $A = \pi r^2$, cost $5 and $10, escaped \$x\$, code `$y$`.

$$
a^2 + b^2 = c^2
$$
''';
        final doc = parser.parse(md);
        expect(doc.blocks.length, 2);

        final p = doc.blocks[0] as ParagraphBlock;
        final inlineMath = p.inlines.whereType<InlineLatexInline>().toList();
        expect(inlineMath.length, 1);
        expect(inlineMath.first.expression, r'A = \pi r^2');
        expect(extractBlockRenderedText(p), contains(r'$5 and $10'));

        final blockMath = doc.blocks[1] as BlockLatexBlock;
        expect(blockMath.closed, isTrue);
        expect(blockMath.expression, 'a^2 + b^2 = c^2');
      },
    );

    test(r'does not misparse \[optional] prose as unclosed display math', () {
      final parser = GfmMarkdownParser();
      final doc = parser.parse(r'\[optional] note here');
      expect(doc.blocks.single, isA<ParagraphBlock>());
    });

    test(r'refuses to cross backtick code spans in \(...\) and $$...$$ inline math', () {
      final parser = GfmMarkdownParser(
        options: const MarkdownParserOptions(enableDollarLatex: true),
      );
      final parenDoc = parser.parse(r'Use \( and `code` and \)');
      final parenP = parenDoc.blocks.single as ParagraphBlock;
      expect(parenP.inlines.whereType<InlineLatexInline>(), isEmpty);
      expect(parenP.inlines.whereType<InlineCodeInline>().single.code, 'code');

      final dollarDoc = parser.parse(r'Use $$ and `code` and $$');
      final dollarP = dollarDoc.blocks.single as ParagraphBlock;
      expect(dollarP.inlines.whereType<InlineLatexInline>(), isEmpty);
      expect(dollarP.inlines.whereType<InlineCodeInline>().single.code, 'code');
    });
  });

  group('MarkdownInlineScanner', () {
    test('skips matchAt on ordinary prose and never touches code spans or link labels', () {
      final localhostRule = _CountingLocalhostRule();
      final filePathRule = _CountingFilePathRule();
      final parser = GfmMarkdownParser(
        options: MarkdownParserOptions(
          inlineRules: [localhostRule, filePathRule],
        ),
      );

      // Plain prose with neither 'h'/'H' nor '/' skips both rules completely.
      final plainDoc = parser.parse('Simple plain text 123.');
      expect(plainDoc.blocks.single, isA<ParagraphBlock>());
      expect(localhostRule.matchAtCalls, 0);
      expect(filePathRule.matchAtCalls, 0);

      // Code spans, fenced code blocks, and existing link labels are untouched.
      const mixed = '''
Check lib/main.dart:42 and http://localhost:8080/api!

Inline `lib/ignored.dart` and [lib/in_link.dart](https://example.com).

```dart
// lib/in_code_block.dart http://localhost:3000
```
''';
      final doc = parser.parse(mixed);
      final p1 = doc.blocks[0] as ParagraphBlock;
      expect(
        p1.inlines.whereType<CustomInline>().single,
        const CustomInline(
          kind: 'file_path',
          text: 'lib/main.dart:42',
          data: {'path': 'lib/main.dart:42'},
        ),
      );
      expect(
        p1.inlines.whereType<LinkInline>().single.destination,
        'http://localhost:8080/api',
      );

      final p2 = doc.blocks[1] as ParagraphBlock;
      expect(p2.inlines.whereType<CustomInline>(), isEmpty);
      expect(
        p2.inlines.whereType<InlineCodeInline>().single.code,
        'lib/ignored.dart',
      );
      final existingLink = p2.inlines.whereType<LinkInline>().single;
      expect(existingLink.children, [const TextInline('lib/in_link.dart')]);

      final code = doc.blocks[2] as CodeBlock;
      expect(code.code, '// lib/in_code_block.dart http://localhost:3000');
    });
  });

  group('Caching and incremental block parsing', () {
    test('uses bounded LRU cache for documents and reuses prefix blocks when streaming', () {
      final parser = GfmMarkdownParser(
        maxCacheEntries: 2,
        maxBlockCacheEntries: 4,
      );

      final d1 = parser.parse('# One\n\nBody one');
      final d1Again = parser.parse('# One\n\nBody one');
      expect(identical(d1, d1Again), isTrue);
      expect(parser.documentCacheLength, 1);

      parser.parse('# Two');
      parser.parse('# Three');
      // LRU limit is 2, so '# One\n\nBody one' was evicted.
      expect(parser.documentCacheLength, 2);
      final d1Reparsed = parser.parse('# One\n\nBody one');
      expect(identical(d1, d1Reparsed), isFalse);
      expect(d1Reparsed, d1);

      // Streaming frames do not evict completed documents from _documentCache.
      for (var i = 1; i <= 10; i++) {
        parser.parse('# Stream\n\nChunk ${'x' * i}', isStreaming: true);
      }
      expect(parser.documentCacheLength, 2);
      expect(identical(parser.parse('# One\n\nBody one'), d1Reparsed), isTrue);
    });
  });

  group('Canonical rendered text extraction', () {
    test(
      'joins document blocks with blank lines and skips thematic breaks',
      () {
        final doc = MarkdownDocument(
          blocks: const [
            HeadingBlock(level: 1, inlines: [TextInline('Title')]),
            ParagraphBlock(inlines: [TextInline('Body')]),
            ThematicBreakBlock(),
            CodeBlock(code: 'const a = 1;'),
            BlockLatexBlock(expression: 'x + y'),
          ],
        );
        expect(
          extractDocumentRenderedText(doc),
          'Title\n\nBody\n\nconst a = 1;\n\nx + y',
        );
      },
    );
  });
}
