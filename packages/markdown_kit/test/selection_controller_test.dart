import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

MarkdownDocument _doc(List<String> paragraphs) {
  return MarkdownDocument(
    blocks: [
      for (final p in paragraphs) ParagraphBlock(inlines: [TextInline(p)]),
    ],
  );
}

/// Deterministic mock surface where each character occupies `charWidth` x `lineHeight`.
class _TestSurface implements MarkdownSelectionSurface {
  _TestSurface({
    required this.documentId,
    required this.blockIndex,
    required this.text,
    required this.origin,
    this.textOffsetInBlock = 0,
  });

  @override
  final String documentId;

  @override
  final int blockIndex;

  final String text;
  final Offset origin;

  @override
  final int textOffsetInBlock;

  static const double charWidth = 10.0;
  static const double lineHeight = 20.0;

  TextRange? lastHighlightRange;
  int highlightSyncCount = 0;

  @override
  int get textLength => text.length;

  @override
  TextDirection get textDirection => TextDirection.ltr;

  @override
  Rect? get globalBounds => Rect.fromLTWH(
    origin.dx,
    origin.dy,
    math.max(1.0, text.length * charWidth),
    lineHeight,
  );

  @override
  bool get hasSelectionHandleLeaders => false;

  @override
  bool hitsTextAtGlobal(Offset globalOffset) {
    final bounds = globalBounds;
    return bounds != null && bounds.contains(globalOffset);
  }

  @override
  MarkdownPosition positionForGlobalOffset(Offset globalOffset) {
    final localX = globalOffset.dx - origin.dx;
    final localIdx = (localX / charWidth).round().clamp(0, text.length);
    return MarkdownPosition(
      documentId: documentId,
      blockIndex: blockIndex,
      offset: textOffsetInBlock + localIdx,
    );
  }

  @override
  TextRange wordRangeAtLocal(int localOffset) {
    if (text.isEmpty) return const TextRange.collapsed(0);
    final clamped = localOffset.clamp(0, text.length - 1);
    var start = clamped;
    var end = clamped;
    if (text[clamped] == ' ') {
      return TextRange(start: clamped, end: math.min(clamped + 1, text.length));
    }
    while (start > 0 && text[start - 1] != ' ') {
      start--;
    }
    while (end < text.length && text[end] != ' ') {
      end++;
    }
    return TextRange(start: start, end: end);
  }

  @override
  TextRange lineRangeAtLocal(int localOffset) =>
      TextRange(start: 0, end: text.length);

  @override
  List<TextBox> boxesForLocalRange(int start, int end) {
    final s = start.clamp(0, text.length);
    final e = end.clamp(s, text.length);
    if (e <= s) return const [];
    return [
      TextBox.fromLTRBD(
        s * charWidth,
        0,
        e * charWidth,
        lineHeight,
        TextDirection.ltr,
      ),
    ];
  }

  @override
  Rect caretRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) {
    final clamped = offset.clamp(0, text.length);
    return Rect.fromLTWH(clamped * charWidth, 0, 2, lineHeight);
  }

  @override
  Rect? globalRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) {
    return caretRectForLocalOffset(offset, affinity: affinity).shift(origin);
  }

  @override
  void setSelectionHighlightRange(TextRange? range) {
    lastHighlightRange = range;
    highlightSyncCount++;
  }

  @override
  void setSelectionHandleLayers({
    LayerLink? startHandleLayerLink,
    int? startHandleLocalOffset,
    LayerLink? endHandleLayerLink,
    int? endHandleLocalOffset,
  }) {}

  @override
  void clearSelectionHandleLayersIfLinked({
    LayerLink? startHandleLayerLink,
    LayerLink? endHandleLayerLink,
  }) {}
}

void main() {
  group('MarkdownSelectionController single-document clamping', () {
    late MarkdownSelectionController controller;
    late _TestSurface doc0Block0;
    late _TestSurface doc0Block1;
    late _TestSurface doc1Block0;

    setUp(() {
      controller = MarkdownSelectionController(
        allowCrossDocumentSelection: false,
      );
      controller.putDocument(
        MarkdownDocumentRef(
          id: 'msg-1',
          order: 0,
          document: _doc(['Hello world', 'Second line']),
        ),
      );
      controller.putDocument(
        MarkdownDocumentRef(
          id: 'msg-2',
          order: 1,
          document: _doc(['Another bubble']),
        ),
      );

      doc0Block0 = _TestSurface(
        documentId: 'msg-1',
        blockIndex: 0,
        text: 'Hello world',
        origin: const Offset(0, 0),
      );
      doc0Block1 = _TestSurface(
        documentId: 'msg-1',
        blockIndex: 1,
        text: 'Second line',
        origin: const Offset(0, 30),
      );
      doc1Block0 = _TestSurface(
        documentId: 'msg-2',
        blockIndex: 0,
        text: 'Another bubble',
        origin: const Offset(0, 80),
      );

      controller.registerSurface(doc0Block0);
      controller.registerSurface(doc0Block1);
      controller.registerSurface(doc1Block0);
    });

    tearDown(() {
      controller.dispose();
    });

    test('clamps extendToGlobal strictly inside anchor document', () {
      expect(controller.startAtGlobal(const Offset(60, 10)), isTrue);
      // Drag downward into msg-2: must clamp to end of msg-1.
      controller.extendToGlobal(const Offset(50, 90));

      expect(
        controller.selection,
        const MarkdownSelection(
          base: MarkdownPosition(documentId: 'msg-1', blockIndex: 0, offset: 6),
          extent: MarkdownPosition(
            documentId: 'msg-1',
            blockIndex: 1,
            offset: 11,
          ),
        ),
      );
      expect(controller.getText(), 'world\n\nSecond line');
      expect(doc1Block0.lastHighlightRange, isNull);

      // Start in msg-2, drag upward into msg-1: must clamp to start of msg-2.
      expect(controller.startAtGlobal(const Offset(80, 90)), isTrue);
      controller.extendToGlobal(const Offset(20, 10));

      expect(
        controller.selection,
        const MarkdownSelection(
          base: MarkdownPosition(documentId: 'msg-2', blockIndex: 0, offset: 8),
          extent: MarkdownPosition(
            documentId: 'msg-2',
            blockIndex: 0,
            offset: 0,
          ),
        ),
      );
      expect(controller.getText(), 'Another ');
      expect(doc0Block0.lastHighlightRange, isNull);
      expect(doc0Block1.lastHighlightRange, isNull);
    });

    test(
      'clamps extendGranular and moveSelectionEdgeToGlobal inside anchor doc',
      () {
        expect(controller.selectWordAtGlobal(const Offset(15, 10)), isTrue);
        expect(controller.getText(), 'Hello');

        final anchor = controller.selection!;
        // Drag word-granular into msg-2 -> clamps at end of msg-1.
        controller.extendGranular(anchor, const Offset(40, 90), word: true);
        expect(controller.selection!.extent.documentId, 'msg-1');
        expect(controller.getText(), 'Hello world\n\nSecond line');

        // Drag end handle into msg-2 -> still clamped to msg-1.
        controller.moveSelectionEdgeToGlobal(
          const Offset(100, 90),
          isStart: false,
        );
        expect(controller.selection!.extent.documentId, 'msg-1');
        expect(doc1Block0.lastHighlightRange, isNull);

        // Drag start handle above msg-1 -> clamped to start of msg-1.
        controller.moveSelectionEdgeToGlobal(
          const Offset(0, -30),
          isStart: true,
        );
        expect(
          controller.normalizedSelection!.start,
          const MarkdownPosition(documentId: 'msg-1', blockIndex: 0, offset: 0),
        );
      },
    );

    test(
      'selectAll selects only the anchor document when cross-doc is false',
      () {
        controller.selectWordAtGlobal(const Offset(20, 90));
        expect(controller.selectAll(), isTrue);
        expect(controller.getText(), 'Another bubble');
        expect(doc0Block0.lastHighlightRange, isNull);
        expect(
          doc1Block0.lastHighlightRange,
          const TextRange(start: 0, end: 14),
        );
      },
    );

    test(
      'starting a new selection in another document replaces prior selection cleanly',
      () {
        controller.selectWordAtGlobal(const Offset(15, 10));
        expect(controller.getText(), 'Hello');
        expect(
          doc0Block0.lastHighlightRange,
          const TextRange(start: 0, end: 5),
        );

        controller.selectWordAtGlobal(const Offset(15, 90));
        expect(controller.getText(), 'Another');
        expect(doc0Block0.lastHighlightRange, isNull);
        expect(
          doc1Block0.lastHighlightRange,
          const TextRange(start: 0, end: 7),
        );
      },
    );

    test('keyboard extensions respect single-document boundary', () {
      controller.selectWordAtGlobal(const Offset(15, 10));
      controller.extendToDocumentBoundary(forward: true);
      expect(controller.getText(), 'Hello world\n\nSecond line');
      expect(controller.extendByCharacter(forward: true), isFalse);
      expect(controller.extendByWord(forward: true), isFalse);
    });
  });

  group('MarkdownSelectionController cross-document selection', () {
    test(
      'spans multiple documents in reading order and handles reversed selections',
      () {
        final controller = MarkdownSelectionController(
          allowCrossDocumentSelection: true,
        );
        addTearDown(controller.dispose);

        controller.putDocument(
          MarkdownDocumentRef(
            id: 'doc-b',
            order: 2,
            document: _doc(['Bravo delta']),
          ),
        );
        controller.putDocument(
          MarkdownDocumentRef(
            id: 'doc-a',
            order: 1,
            document: _doc(['Alpha charlie']),
          ),
        );

        final surfaceA = _TestSurface(
          documentId: 'doc-a',
          blockIndex: 0,
          text: 'Alpha charlie',
          origin: const Offset(0, 0),
        );
        final surfaceB = _TestSurface(
          documentId: 'doc-b',
          blockIndex: 0,
          text: 'Bravo delta',
          origin: const Offset(0, 40),
        );
        controller.registerSurface(surfaceA);
        controller.registerSurface(surfaceB);

        // Reversed selection starting in doc-b and dragging up into doc-a.
        controller.startAtGlobal(const Offset(50, 50));
        controller.extendToGlobal(const Offset(60, 10));

        expect(controller.isSelectionReversed, isTrue);
        expect(controller.getText(), 'charlie\n\nBravo');
        expect(surfaceA.lastHighlightRange, const TextRange(start: 6, end: 13));
        expect(surfaceB.lastHighlightRange, const TextRange(start: 0, end: 5));

        // selectAll selects across all documents.
        expect(controller.selectAll(), isTrue);
        expect(controller.getText(), 'Alpha charlie\n\nBravo delta');
      },
    );
  });

  group('Off-screen disposal preservation & streaming reconciliation', () {
    test(
      'preserves selection and copy output when surfaces unmount and restores highlights on remount',
      () {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);

        controller.putDocument(
          MarkdownDocumentRef(
            id: 'd1',
            document: _doc(['First paragraph', 'Second paragraph']),
          ),
        );

        final s0 = _TestSurface(
          documentId: 'd1',
          blockIndex: 0,
          text: 'First paragraph',
          origin: const Offset(0, 0),
        );
        final s1 = _TestSurface(
          documentId: 'd1',
          blockIndex: 1,
          text: 'Second paragraph',
          origin: const Offset(0, 30),
        );
        controller.registerSurface(s0);
        controller.registerSurface(s1);

        controller.startAtGlobal(const Offset(60, 10));
        controller.extendToGlobal(const Offset(60, 40));
        expect(controller.getText(), 'paragraph\n\nSecond');

        // Simulate block 0 scrolling off-screen and disposing.
        controller.unregisterSurface(s0);

        expect(controller.hasSelection, isTrue);
        expect(controller.getText(), 'paragraph\n\nSecond');

        final partialEndpoints = controller.selectionHandleEndpoints();
        expect(partialEndpoints, isNotNull);
        expect(partialEndpoints!.hasStart, isFalse);
        expect(partialEndpoints.hasEnd, isTrue);

        // Simulate block 1 also scrolling off-screen.
        controller.unregisterSurface(s1);
        expect(controller.hasSelection, isTrue);
        expect(controller.getText(), 'paragraph\n\nSecond');
        expect(controller.selectionHandleEndpoints(), isNull);

        // Simulate block 0 scrolling back into view with a fresh surface instance.
        final s0Remounted = _TestSurface(
          documentId: 'd1',
          blockIndex: 0,
          text: 'First paragraph',
          origin: const Offset(0, 0),
        );
        controller.registerSurface(s0Remounted);
        expect(
          s0Remounted.lastHighlightRange,
          const TextRange(start: 6, end: 15),
        );
        final restoredEndpoints = controller.selectionHandleEndpoints();
        expect(restoredEndpoints, isNotNull);
        expect(restoredEndpoints!.hasStart, isTrue);
        expect(restoredEndpoints.startLocalOffset, 6);
      },
    );

    test(
      'reconciles streaming updates via contentAnchored and syncs highlights',
      () {
        final controller = MarkdownSelectionController(
          reconciliationPolicy:
              const MarkdownReconciliationPolicy.contentAnchored(),
        );
        addTearDown(controller.dispose);

        controller.putDocument(
          MarkdownDocumentRef(id: 'stream', document: _doc(['Say **hello'])),
        );
        final surfaceBefore = _TestSurface(
          documentId: 'stream',
          blockIndex: 0,
          text: 'Say **hello',
          origin: Offset.zero,
        );
        controller.registerSurface(surfaceBefore);

        controller.setSelection(
          const MarkdownSelection(
            base: MarkdownPosition(
              documentId: 'stream',
              blockIndex: 0,
              offset: 6,
            ),
            extent: MarkdownPosition(
              documentId: 'stream',
              blockIndex: 0,
              offset: 11,
            ),
          ),
        );
        expect(controller.getText(), 'hello');
        expect(
          surfaceBefore.lastHighlightRange,
          const TextRange(start: 6, end: 11),
        );

        // Markdown finalizes `**hello**` -> rendered text shifts from 6..11 to 4..9.
        controller.unregisterSurface(surfaceBefore);
        final surfaceAfter = _TestSurface(
          documentId: 'stream',
          blockIndex: 0,
          text: 'Say hello world',
          origin: Offset.zero,
        );
        controller.registerSurface(surfaceAfter);
        controller.putDocument(
          MarkdownDocumentRef(
            id: 'stream',
            document: _doc(['Say hello world']),
          ),
        );

        expect(controller.getText(), 'hello');
        expect(
          surfaceAfter.lastHighlightRange,
          const TextRange(start: 4, end: 9),
        );

        // Unrelated document replacement clears selection and highlights.
        controller.putDocument(
          MarkdownDocumentRef(
            id: 'stream',
            document: _doc(['Completely unrelated']),
          ),
        );
        expect(controller.selection, isNull);
        expect(surfaceAfter.lastHighlightRange, isNull);
      },
    );
  });

  group('Multi-surface blocks, geometry helpers, and keyboard extensions', () {
    test('maps highlights and handle endpoints across sub-block surfaces', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);

      // A list block whose canonical text is "One\nTwo" (lengths 3, separator 1, 3).
      const listDoc = MarkdownDocument(
        blocks: [
          ListBlock(
            ordered: false,
            items: [
              ListItemNode(
                children: [
                  ParagraphBlock(inlines: [TextInline('One')]),
                ],
              ),
              ListItemNode(
                children: [
                  ParagraphBlock(inlines: [TextInline('Two')]),
                ],
              ),
            ],
          ),
        ],
      );
      controller.putDocument(
        const MarkdownDocumentRef(id: 'd1', document: listDoc),
      );

      final item0 = _TestSurface(
        documentId: 'd1',
        blockIndex: 0,
        textOffsetInBlock: 0,
        text: 'One',
        origin: const Offset(20, 10),
      );
      final item1 = _TestSurface(
        documentId: 'd1',
        blockIndex: 0,
        textOffsetInBlock: 4,
        text: 'Two',
        origin: const Offset(20, 40),
      );
      controller.registerSurface(item0);
      controller.registerSurface(item1);

      controller.setSelection(
        const MarkdownSelection(
          base: MarkdownPosition(documentId: 'd1', blockIndex: 0, offset: 1),
          extent: MarkdownPosition(documentId: 'd1', blockIndex: 0, offset: 6),
        ),
      );

      expect(controller.getText(), 'ne\nTw');
      expect(item0.lastHighlightRange, const TextRange(start: 1, end: 3));
      expect(item1.lastHighlightRange, const TextRange(start: 0, end: 2));

      final endpoints = controller.selectionHandleEndpoints()!;
      expect(endpoints.startSurface, item0);
      expect(endpoints.startLocalOffset, 1);
      expect(endpoints.startGlobal, const Offset(30, 30));
      expect(endpoints.startLineHeight, 20.0);
      expect(endpoints.endSurface, item1);
      expect(endpoints.endLocalOffset, 2);
      expect(endpoints.endGlobal, const Offset(40, 60));
      expect(endpoints.endLineHeight, 20.0);

      final rects = controller.globalSelectionRects();
      expect(rects.length, 2);
      expect(rects[0], const Rect.fromLTWH(30, 10, 20, 20));
      expect(rects[1], const Rect.fromLTWH(20, 40, 20, 20));

      expect(
        controller.selectionEndpointGlobalRect(base: true),
        const Rect.fromLTWH(30, 10, 2, 20),
      );
      expect(
        controller.selectionEndpointGlobalRect(base: false),
        const Rect.fromLTWH(40, 40, 2, 20),
      );

      controller.clear();
      expect(controller.selection, isNull);
      expect(item0.lastHighlightRange, isNull);
      expect(item1.lastHighlightRange, isNull);
    });

    test(
      'supports character, word, line-break, and adjacent-line keyboard extensions',
      () {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);

        controller.putDocument(
          MarkdownDocumentRef(
            id: 'd1',
            document: _doc(['Hello world', 'Second line with more text']),
          ),
        );
        final s0 = _TestSurface(
          documentId: 'd1',
          blockIndex: 0,
          text: 'Hello world',
          origin: const Offset(0, 0),
        );
        final s1 = _TestSurface(
          documentId: 'd1',
          blockIndex: 1,
          text: 'Second line with more text',
          origin: const Offset(0, 25),
        );
        controller.registerSurface(s0);
        controller.registerSurface(s1);

        controller.setSelection(
          const MarkdownSelection.collapsed(
            MarkdownPosition(documentId: 'd1', blockIndex: 0, offset: 0),
          ),
        );

        expect(controller.extendByCharacter(forward: true), isTrue);
        expect(controller.getText(), 'H');

        expect(controller.extendByWord(forward: true), isTrue);
        expect(controller.getText(), 'Hello');

        expect(controller.extendToLineBreak(forward: true), isTrue);
        expect(controller.getText(), 'Hello world');

        expect(controller.extendToAdjacentLine(forward: true), isTrue);
        expect(controller.selection!.extent.blockIndex, 1);

        expect(controller.extendToDocumentBoundary(forward: true), isTrue);
        expect(
          controller.getText(),
          'Hello world\n\nSecond line with more text',
        );
      },
    );
  });
}
