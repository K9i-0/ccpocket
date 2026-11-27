/// Invariants of markdown_kit's own layers, checked over the CommonMark
/// specification's examples. The examples are small but cover every construct
/// and many awkward combinations, which makes them a good corpus for code the
/// specification says nothing about: the splitter, streaming, offsets, copy.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

List<String> _corpus() {
  final examples = (jsonDecode(
    File('test/commonmark_spec/spec.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  return [
    for (final example in examples) example['markdown'] as String,
    // A few documents joining several examples, so blocks follow one another.
    for (var i = 0; i + 5 < examples.length; i += 40)
      [for (var j = i; j < i + 5; j++) examples[j]['markdown']].join('\n'),
  ];
}

String _visible(String source) => jsonEncode(source);

bool _sameBlocks(List<MarkdownBlock> a, List<MarkdownBlock> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  final corpus = _corpus();

  test('splitMarkdownBlocks chunks join back to every source', () {
    for (final source in corpus) {
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
    }
  });

  test('parsing chunk by chunk gives the blocks of parsing in one piece', () {
    // A reference definition in front turns the splitter off for the whole
    // document, and makes no block of its own.
    const unsplit = '[zz-unsplit]: /unsplit\n\n';
    var split = 0;
    final different = <String>{};
    for (final source in corpus) {
      if (splitMarkdownBlocks(source).length < 2) continue;
      split++;
      expect(splitMarkdownBlocks('$unsplit$source'), hasLength(1));
      final chunked = GfmMarkdownParser().parse(source).blocks;
      final whole = GfmMarkdownParser().parse('$unsplit$source').blocks;
      if (!_sameBlocks(chunked, whole)) different.add(source);
    }
    expect(split, greaterThan(50));
    expect(different, isEmpty);
  });

  test('source ranges are in order and inside the source for every '
      'document', () {
    for (final source in corpus) {
      final document = GfmMarkdownParser().parse(source);
      final ranges = document.blockSourceRanges;
      if (document.isEmpty) {
        expect(ranges, anyOf(isNull, isEmpty), reason: _visible(source));
        continue;
      }
      expect(ranges, hasLength(document.blocks.length));
      var previous = const MarkdownSourceRange(0, 0);
      for (final range in ranges!) {
        expect(range.end, lessThanOrEqualTo(source.length));
        expect(
          range == previous || range.start >= previous.end,
          isTrue,
          reason: _visible(source),
        );
        previous = range;
      }
    }
  });

  test('streaming every prefix converges on the complete parse', () {
    final degraded = <String>{};
    for (final source in corpus) {
      final complete = source.endsWith('\n') ? source : '$source\n';
      final streaming = GfmMarkdownParser();
      MarkdownDocument? last;
      for (var end = 1; end <= complete.length; end++) {
        final prefix = complete.substring(0, end);
        final before = streaming.rawTextFallbackCount;
        last = streaming.parse(prefix, isStreaming: true);
        if (streaming.rawTextFallbackCount > before) degraded.add(prefix);
      }
      // While streaming, unfinished syntax at the end may still be held. The
      // finished text is parsed without the flag, on the same parser.
      last = streaming.parse(complete);
      expect(
        last.blocks,
        GfmMarkdownParser().parse(complete).blocks,
        reason: _visible(complete),
      );
    }
    // package:markdown throws a RangeError while a reference definition's
    // destination is a lone `<`. markdown_kit shows that frame as raw text.
    // Anything new in this set is a regression worth a look.
    expect(degraded, {'[Foo bar]:\n<', '[foo]: <'});
  });

  test('copying a whole document as plain text gives its rendered text', () {
    for (final source in corpus) {
      final document = GfmMarkdownParser().parse(source);
      if (document.blocks.isEmpty) continue;
      final controller = MarkdownSelectionController()
        ..putDocument(MarkdownDocumentRef(id: 'doc', document: document));
      controller.selectAll(documentId: 'doc');
      expect(
        controller.getText(),
        extractDocumentRenderedText(document),
        reason: _visible(source),
      );
      // Reconstructing Markdown must work for any tree the parser produces.
      expect(controller.getMarkdown, returnsNormally, reason: _visible(source));
      controller.dispose();
    }
  });

  testWidgets('every rendered surface covers exactly its canonical text', (
    tester,
  ) async {
    final failures = <String>[];
    for (var i = 0; i < corpus.length; i++) {
      final source = corpus[i];
      final document = GfmMarkdownParser().parse(source);
      final controller = MarkdownSelectionController();
      await tester.pumpWidget(
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => MarkdownSelectionScope(
                    controller: controller,
                    child: SingleChildScrollView(
                      child: MarkdownView(
                        key: ValueKey(i),
                        document: document,
                        documentId: 'doc-$i',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final exception = tester.takeException();
      if (exception != null) {
        failures.add('threw $exception for ${_visible(source)}');
      }

      final byBlock = <int, List<MarkdownSelectionSurface>>{};
      for (final surface in controller.mountedSurfaces) {
        byBlock.putIfAbsent(surface.blockIndex, () => []).add(surface);
        final blockText = extractBlockRenderedText(
          document.blocks[surface.blockIndex],
        );
        final start = surface.textOffsetInBlock;
        final end = start + surface.textLength;
        if (end > blockText.length) {
          failures.add(
            'range $start..$end past ${blockText.length}: '
            '${_visible(source)}',
          );
          continue;
        }
        final painted = (surface as RenderSelectableParagraph).baseText
            .toPlainText();
        final canonical = blockText.substring(start, end);
        // Inline widgets and the math fallback paint text of another length.
        final comparable =
            painted.length == canonical.length && !painted.contains('￼');
        if (comparable && painted != canonical) {
          failures.add(
            'painted ${_visible(painted)} for '
            '${_visible(canonical)}: ${_visible(source)}',
          );
        }
        for (var offset = 0; offset <= surface.textLength; offset++) {
          final word = surface.wordRangeAtLocal(offset);
          if (word.start < 0 ||
              word.end > surface.textLength ||
              word.start > word.end) {
            failures.add('word $word at $offset: ${_visible(source)}');
          }
          surface.caretRectForLocalOffset(offset);
          surface.lineRangeAtLocal(offset);
        }
      }
      byBlock.forEach((blockIndex, surfaces) {
        surfaces.sort(
          (a, b) => a.textOffsetInBlock.compareTo(b.textOffsetInBlock),
        );
        for (var k = 1; k < surfaces.length; k++) {
          if (surfaces[k].textOffsetInBlock < surfaces[k - 1].blockEndOffset) {
            failures.add('overlap in block $blockIndex: ${_visible(source)}');
          }
        }
      });

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }
    expect(failures.take(10).toList(), isEmpty);
  });
}
