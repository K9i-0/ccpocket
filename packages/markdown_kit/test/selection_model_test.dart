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

class _FakeSurface implements MarkdownSelectionSurface {
  _FakeSurface({
    required this.documentId,
    required this.blockIndex,
    required this.textOffsetInBlock,
    required this.textLength,
  });

  @override
  final String documentId;

  @override
  final int blockIndex;

  @override
  final int textOffsetInBlock;

  @override
  final int textLength;

  @override
  TextDirection get textDirection => TextDirection.ltr;

  @override
  Rect? get globalBounds => const Rect.fromLTWH(0, 0, 100, 20);

  @override
  bool get hasSelectionHandleLeaders => false;

  @override
  List<TextBox> boxesForLocalRange(int start, int end) => const [];

  @override
  Rect caretRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) => affinity == TextAffinity.upstream
      ? const Rect.fromLTWH(50, 0, 2, 20)
      : Rect.zero;

  @override
  void clearSelectionHandleLayersIfLinked({
    LayerLink? startHandleLayerLink,
    LayerLink? endHandleLayerLink,
  }) {}

  @override
  Rect? globalRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) => caretRectForLocalOffset(offset, affinity: affinity);

  @override
  bool hitsTextAtGlobal(Offset globalOffset) => true;

  @override
  TextRange lineRangeAtLocal(int localOffset) =>
      TextRange(start: 0, end: textLength);

  @override
  MarkdownPosition positionForGlobalOffset(Offset globalOffset) =>
      MarkdownPosition(
        documentId: documentId,
        blockIndex: blockIndex,
        offset: textOffsetInBlock,
      );

  @override
  void setSelectionHandleLayers({
    LayerLink? startHandleLayerLink,
    int? startHandleLocalOffset,
    LayerLink? endHandleLayerLink,
    int? endHandleLocalOffset,
  }) {}

  @override
  void setSelectionHighlightRange(TextRange? range) {}

  @override
  TextRange wordRangeAtLocal(int localOffset) =>
      TextRange(start: 0, end: textLength);
}

void main() {
  group('MarkdownPosition and MarkdownSelection', () {
    test('compares positions using documentOrder and normalizes reversed selections', () {
      const p1 = MarkdownPosition(documentId: 'b', blockIndex: 0, offset: 5);
      const p2 = MarkdownPosition(documentId: 'a', blockIndex: 1, offset: 2);
      const order = {'b': 0, 'a': 1};

      expect(p1.compareTo(p2, documentOrder: order), lessThan(0));

      const reversed = MarkdownSelection(base: p2, extent: p1);
      expect(reversed.isCollapsed, isFalse);
      expect(reversed.isSingleDocument, isFalse);
      expect(reversed.isReversed(documentOrder: order), isTrue);

      final (:start, :end) = reversed.normalized(documentOrder: order);
      expect(start, p1);
      expect(end, p2);

      const collapsed = MarkdownSelection.collapsed(p1);
      expect(collapsed.isCollapsed, isTrue);
      expect(collapsed.isSingleDocument, isTrue);
    });
  });

  group('MarkdownSelectedContent.extract', () {
    test(
      'extracts partial, multi-block, and cross-document selections accurately',
      () {
        final doc1 = _doc(['Hello world', 'Second paragraph']);
        final doc2 = _doc(['Another message']);
        final refs = [
          MarkdownDocumentRef(id: 'm2', document: doc2, order: 2),
          MarkdownDocumentRef(id: 'm1', document: doc1, order: 1),
        ];

        // Reversed cross-document selection from doc2[0]@7 back to doc1[0]@6.
        const selection = MarkdownSelection(
          base: MarkdownPosition(documentId: 'm2', blockIndex: 0, offset: 7),
          extent: MarkdownPosition(documentId: 'm1', blockIndex: 0, offset: 6),
        );

        final content = MarkdownSelectedContent.extract(
          selection: selection,
          documents: refs,
        );
        expect(content.isNotEmpty, isTrue);
        expect(content.documents.length, 2);

        expect(content.documents[0].documentId, 'm1');
        expect(content.documents[0].blocks.length, 2);
        expect(content.documents[0].blocks[0].selectedText, 'world');
        expect(content.documents[0].blocks[0].isPartial, isTrue);
        expect(content.documents[0].blocks[1].selectedText, 'Second paragraph');
        expect(content.documents[0].blocks[1].isFullBlock, isTrue);

        expect(content.documents[1].documentId, 'm2');
        expect(content.documents[1].blocks.single.selectedText, 'Another');
      },
    );

    test('returns empty content for collapsed selection', () {
      final doc = _doc(['Hello']);
      const selection = MarkdownSelection.collapsed(
        MarkdownPosition(documentId: 'm1', blockIndex: 0, offset: 2),
      );
      final content = MarkdownSelectedContent.extract(
        selection: selection,
        documents: [MarkdownDocumentRef(id: 'm1', document: doc)],
      );
      expect(content.isEmpty, isTrue);
    });
  });

  group('MarkdownReconciliationPolicy', () {
    test(
      'clearOnChange clears only when the targeted document actually changes',
      () {
        const policy = MarkdownReconciliationPolicy.clearOnChange();
        final prev = _doc(['Hello']);
        final next = _doc(['Hello world']);
        const sel = MarkdownSelection(
          base: MarkdownPosition(documentId: 'm1', blockIndex: 0, offset: 0),
          extent: MarkdownPosition(documentId: 'm1', blockIndex: 0, offset: 5),
        );

        expect(
          policy.reconcile(
            documentId: 'm1',
            previousDocument: prev,
            nextDocument: prev,
            currentSelection: sel,
          ),
          sel,
        );
        expect(
          policy.reconcile(
            documentId: 'other',
            previousDocument: prev,
            nextDocument: next,
            currentSelection: sel,
          ),
          sel,
        );
        expect(
          policy.reconcile(
            documentId: 'm1',
            previousDocument: prev,
            nextDocument: next,
            currentSelection: sel,
          ),
          isNull,
        );
      },
    );

    test('appendFastPath preserves append-only streaming growth and clears on prefix edits', () {
      const policy = MarkdownReconciliationPolicy.appendFastPath();
      final prev = _doc(['First paragraph', 'Hello wor']);
      final appendedSameBlock = _doc(['First paragraph', 'Hello world!']);
      final appendedNewBlock = _doc([
        'First paragraph',
        'Hello wor',
        'Third paragraph',
      ]);
      final mutatedPrefix = _doc(['First paragraph', 'hello world']);

      const sel = MarkdownSelection(
        base: MarkdownPosition(documentId: 'm1', blockIndex: 1, offset: 0),
        extent: MarkdownPosition(documentId: 'm1', blockIndex: 1, offset: 5),
      );

      expect(
        policy.reconcile(
          documentId: 'm1',
          previousDocument: prev,
          nextDocument: appendedSameBlock,
          currentSelection: sel,
        ),
        sel,
      );
      expect(
        policy.reconcile(
          documentId: 'm1',
          previousDocument: prev,
          nextDocument: appendedNewBlock,
          currentSelection: sel,
        ),
        sel,
      );
      expect(
        policy.reconcile(
          documentId: 'm1',
          previousDocument: prev,
          nextDocument: mutatedPrefix,
          currentSelection: sel,
        ),
        isNull,
      );
    });

    test('contentAnchored relocates selection after formatting changes and disambiguates duplicates', () {
      const policy = MarkdownReconciliationPolicy.contentAnchored();

      // Simulates `**hello` finalizing into `**hello**` (rendered text drops `**`).
      final prevStreaming = _doc(['Say **hello']);
      final nextFinalized = _doc(['Say hello world']);
      const sel = MarkdownSelection(
        base: MarkdownPosition(documentId: 'm1', blockIndex: 0, offset: 6),
        extent: MarkdownPosition(documentId: 'm1', blockIndex: 0, offset: 11),
      );
      final reconciled = policy.reconcile(
        documentId: 'm1',
        previousDocument: prevStreaming,
        nextDocument: nextFinalized,
        currentSelection: sel,
      );
      expect(
        reconciled,
        const MarkdownSelection(
          base: MarkdownPosition(documentId: 'm1', blockIndex: 0, offset: 4),
          extent: MarkdownPosition(documentId: 'm1', blockIndex: 0, offset: 9),
        ),
      );

      // Duplicate substring disambiguation via surrounding context.
      final dupPrev = _doc(['alpha foo beta foo gamma']);
      final dupNext = _doc(['PREFIX alpha foo beta foo gamma']);
      // Select the second "foo" (reversed direction!).
      const secondFooStart = 15;
      const secondFooEnd = 18;
      const dupSel = MarkdownSelection(
        base: MarkdownPosition(
          documentId: 'm1',
          blockIndex: 0,
          offset: secondFooEnd,
        ),
        extent: MarkdownPosition(
          documentId: 'm1',
          blockIndex: 0,
          offset: secondFooStart,
        ),
      );
      final dupReconciled = policy.reconcile(
        documentId: 'm1',
        previousDocument: dupPrev,
        nextDocument: dupNext,
        currentSelection: dupSel,
      );
      expect(
        dupReconciled,
        const MarkdownSelection(
          base: MarkdownPosition(
            documentId: 'm1',
            blockIndex: 0,
            offset: secondFooEnd + 7,
          ),
          extent: MarkdownPosition(
            documentId: 'm1',
            blockIndex: 0,
            offset: secondFooStart + 7,
          ),
        ),
      );

      // Completely replaced content clears selection.
      final unrelated = _doc(['Something completely different']);
      expect(
        policy.reconcile(
          documentId: 'm1',
          previousDocument: prevStreaming,
          nextDocument: unrelated,
          currentSelection: sel,
        ),
        isNull,
      );
    });
  });

  group('MarkdownSelectionSurfaceExtensions', () {
    test('maps block ranges into local surface ranges safely', () {
      final surface = _FakeSurface(
        documentId: 'm1',
        blockIndex: 0,
        textOffsetInBlock: 10,
        textLength: 8,
      );
      expect(surface.blockEndOffset, 18);
      expect(surface.localRangeForBlockRange(0, 10), isNull);
      expect(surface.localRangeForBlockRange(18, 25), isNull);
      expect(
        surface.localRangeForBlockRange(5, 14),
        const TextRange(start: 0, end: 4),
      );
      expect(
        surface.localRangeForBlockRange(12, 16),
        const TextRange(start: 2, end: 6),
      );
      expect(
        surface.localRangeForBlockRange(15, 25),
        const TextRange(start: 5, end: 8),
      );
    });
  });
}
