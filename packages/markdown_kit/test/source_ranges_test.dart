// MarkdownDocument.blockSourceRanges: where each top-level block came from in
// the source, and that recording it leaves block caching and equality alone.
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

String _slice(MarkdownDocument doc, int block) {
  final range = doc.blockSourceRanges![block];
  return doc.source.substring(range.start, range.end);
}

void main() {
  group('blockSourceRanges', () {
    test('one range per block, each covering the text of its block', () {
      const source =
          '# Title\n\nFirst paragraph.\n\n- a\n- b\n\n```\ncode\n```\n';
      final doc = GfmMarkdownParser().parse(source);

      expect(doc.blocks, hasLength(4));
      expect(doc.blockSourceRanges, hasLength(4));
      expect(_slice(doc, 0), '# Title\n\n');
      expect(_slice(doc, 1), 'First paragraph.\n\n');
      expect(_slice(doc, 2), '- a\n- b\n\n');
      expect(_slice(doc, 3), '```\ncode\n```\n');
    });

    test('ranges tile the source in order when every chunk has a block', () {
      const source = 'one\n\n\n\ntwo\n\n> three\n\n1. four\n';
      final doc = GfmMarkdownParser().parse(source);
      final ranges = doc.blockSourceRanges!;

      expect(ranges.first.start, 0);
      expect(ranges.last.end, source.length);
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].start, ranges[i - 1].end);
      }
    });

    test('blocks with no blank line between them share one range', () {
      const source = '# Title\nBody right below.\n\nNext.\n';
      final doc = GfmMarkdownParser().parse(source);
      final ranges = doc.blockSourceRanges!;

      expect(doc.blocks[0], isA<HeadingBlock>());
      expect(doc.blocks[1], isA<ParagraphBlock>());
      expect(ranges, hasLength(3));
      expect(identical(ranges[0], ranges[1]), isTrue);
      expect(_slice(doc, 0), '# Title\nBody right below.\n\n');
      expect(_slice(doc, 2), 'Next.\n');
    });

    test('a document with a reference definition still has a range per '
        'block', () {
      const source =
          'See [the docs][d].\n\n[d]: https://example.com\n\nMore.\n\n- end\n';
      final doc = GfmMarkdownParser().parse(source);

      expect(doc.blocks, hasLength(3));
      // The link was resolved, so the document was parsed in one piece.
      expect(
        (doc.blocks[0] as ParagraphBlock).inlines.whereType<LinkInline>(),
        hasLength(1),
      );
      expect(_slice(doc, 0), 'See [the docs][d].\n\n');
      // The definition makes no block and is in no range.
      expect(_slice(doc, 1), 'More.\n\n');
      expect(_slice(doc, 2), '- end\n');
      expect(doc.blockIndexAtSourceOffset(source.indexOf('[d]:')), 1);
    });

    test('the footnotes block shares the range of the last block', () {
      const source = 'Text[^1].\n\nMore.\n\n[^1]: The note.\n';
      final doc = GfmMarkdownParser().parse(source);
      final ranges = doc.blockSourceRanges!;

      expect(doc.blocks.last, isA<FootnoteDefinitionsBlock>());
      expect(ranges, hasLength(doc.blocks.length));
      expect(_slice(doc, 0), 'Text[^1].\n\n');
      expect(_slice(doc, 1), 'More.\n\n');
      expect(ranges.last, ranges[ranges.length - 2]);
    });

    test('raw HTML across blank lines leaves one range for everything', () {
      const source = 'Before.\n\n<pre>\na\n\nb\n</pre>\n\nAfter.\n';
      final doc = GfmMarkdownParser().parse(source);

      expect(doc.blocks.length, greaterThan(1));
      for (final range in doc.blockSourceRanges!) {
        expect(range, const MarkdownSourceRange(0, source.length));
      }
    });

    test('the ranges of an unsplit document are only worked out when read', () {
      final parser = GfmMarkdownParser();
      final doc = parser.parse('One [a][d].\n\nTwo.\n\n[d]: /u\n');

      // Parsed in one piece: nothing went through the cache of chunks.
      expect(parser.blockCacheLength, 0);
      expect(doc.blockSourceRanges, hasLength(2));
      expect(parser.blockCacheLength, 0);
      expect(doc.blockSourceRanges![1], const MarkdownSourceRange(13, 19));
      expect(parser.blockCacheLength, greaterThan(0));
    });

    test('the ranges cannot be changed', () {
      for (final source in ['a\n\nb\n', 'a [x][d]\n\nb\n\n[d]: /u\n']) {
        final ranges = GfmMarkdownParser().parse(source).blockSourceRanges!;
        expect(
          () => ranges[0] = const MarkdownSourceRange(0, 0),
          throwsUnsupportedError,
        );
        expect(ranges.clear, throwsUnsupportedError);
      }
    });

    test('a single block covers the whole source', () {
      const source = 'Just one paragraph.';
      final doc = GfmMarkdownParser().parse(source);

      expect(doc.blockSourceRanges, const [
        MarkdownSourceRange(0, source.length),
      ]);
    });

    test('a fence with blank lines inside stays one range', () {
      const source = 'Intro.\n\n```dart\na();\n\nb();\n```\n\nOutro.\n';
      final doc = GfmMarkdownParser().parse(source);

      expect(doc.blocks, hasLength(3));
      expect(_slice(doc, 1), '```dart\na();\n\nb();\n```\n\n');
    });

    test('CRLF line endings count toward the offsets', () {
      const source = 'one\r\n\r\ntwo\r\n';
      final doc = GfmMarkdownParser().parse(source);

      expect(_slice(doc, 0), 'one\r\n\r\n');
      expect(_slice(doc, 1), 'two\r\n');
    });

    test('while streaming, ranges refer to the held-back source', () {
      const source = 'Done.\n\nStill **typ';
      final doc = GfmMarkdownParser().parse(source, isStreaming: true);

      expect(doc.source, 'Done.\n\nStill ');
      expect(doc.blockSourceRanges, hasLength(doc.blocks.length));
      expect(doc.blockSourceRanges!.last.end, doc.source.length);
    });

    test(
      'an empty document and a hand-built one have none or what was given',
      () {
        expect(GfmMarkdownParser().parse('').blockSourceRanges, isNull);
        expect(
          const MarkdownDocument(blocks: [ThematicBreakBlock()])
              .blockSourceRanges,
          isNull,
        );
      },
    );

    test('with the document cache off the ranges are still recorded', () {
      final parser = GfmMarkdownParser(maxCacheEntries: 0);
      final doc = parser.parse('a\n\nb\n');

      expect(parser.documentCacheLength, 0);
      expect(doc.blockSourceRanges, hasLength(2));
    });
  });

  group('blockIndexAtSourceOffset', () {
    const source = 'one\n\ntwo\nmore\n\nthree\n';
    final doc = GfmMarkdownParser().parse(source);

    test('maps an offset to the block made from it', () {
      expect(doc.blockIndexAtSourceOffset(0), 0);
      expect(doc.blockIndexAtSourceOffset(source.indexOf('two')), 1);
      expect(doc.blockIndexAtSourceOffset(source.indexOf('more')), 1);
      expect(doc.blockIndexAtSourceOffset(source.indexOf('three')), 2);
    });

    test('the blank lines after a block belong to it', () {
      expect(doc.blockIndexAtSourceOffset(source.indexOf('\n\ntwo') + 1), 0);
    });

    test('an offset at or past the end maps to the last block', () {
      expect(doc.blockIndexAtSourceOffset(source.length), 2);
      expect(doc.blockIndexAtSourceOffset(source.length + 100), 2);
    });

    test('blocks sharing a range resolve to the first of them', () {
      final shared = GfmMarkdownParser().parse('# T\nbody\n\nnext\n');
      expect(shared.blockIndexAtSourceOffset(5), 0);
      expect(shared.blockIndexAtSourceOffset(11), 2);
    });

    test('is null without ranges', () {
      expect(MarkdownDocument.empty.blockIndexAtSourceOffset(0), isNull);
      expect(
        const MarkdownDocument(blocks: [ThematicBreakBlock()])
            .blockIndexAtSourceOffset(0),
        isNull,
      );
    });
  });

  group('recording ranges leaves caching and equality alone', () {
    test('the same chunk at another position reuses the cached blocks', () {
      final parser = GfmMarkdownParser();
      final first = parser.parse('Shared paragraph.\n\nTail one.\n');
      final second = parser.parse(
        'A new block in front.\n\nShared paragraph.\n\nTail two.\n',
      );

      expect(identical(first.blocks[0], second.blocks[1]), isTrue);
      expect(first.blockSourceRanges![0], isNot(second.blockSourceRanges![1]));
    });

    test('blocks compare equal whatever their position in the source', () {
      final a = GfmMarkdownParser().parse('x\n\nSame.\n').blocks[1];
      final b = GfmMarkdownParser().parse('longer start\n\nSame.\n').blocks[1];

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('documents compare by source and blocks, not by ranges', () {
      final parsed = GfmMarkdownParser().parse('a\n\nb\n');
      final rebuilt = MarkdownDocument(
        blocks: parsed.blocks,
        source: parsed.source,
      );

      expect(rebuilt, parsed);
      expect(rebuilt.hashCode, parsed.hashCode);
    });

    test('a streamed reply keeps settled blocks identical as it grows', () {
      const reply = 'First.\n\nSecond.\n\nThird is still being writ';
      final parser = GfmMarkdownParser();
      final early = parser.parse(reply.substring(0, 20), isStreaming: true);
      final late = parser.parse(reply, isStreaming: true);

      expect(identical(early.blocks[0], late.blocks[0]), isTrue);
      expect(early.blockSourceRanges![0], late.blockSourceRanges![0]);
    });
  });
}
