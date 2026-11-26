// Controller and scope edge cases: empty documents, thematic breaks,
// reversed selections, out-of-range positions, document registry, handle
// endpoints with an unmounted end, and allowCrossDocumentSelection on / off.
//
// Gap inventory against the reference suite (flutter_md, MIT), by test name:
//
// selection/selection_controller_edge_test.dart
//   (b) ported: reconcile / removeDocument dropping the range clears
//       toolbarWanted [high]; an unrelated document update keeps the toolbar
//       [medium]; selectAll skips a trailing empty document [high]; selectAll
//       over only empty documents is a no-op [high]; an identical commit does
//       not notify [high].
//   (c) ported with a different expectation: "reversed / forward selection
//       proxies an unmounted base / extent onto the visible end" -
//       markdown_kit reports a null endpoint for the unmounted side
//       (MarkdownHandleEndpoints doc comment in selection_controller.dart).
//   Missing, not ported: "a repeated selectAll notifies again" (no stated
//       contract either way); "content anchor prefers the nearest duplicate
//       block" (touches the documented contentAnchored limit).
//   (d) not applicable: "an affinity-only commit notifies" (MarkdownPosition
//       has no affinity).
//
// selection/selection_registry_test.dart, selection_test.dart,
// selection_coverage_test.dart
//   (b) ported: sparse explicit orders keep their reading order [medium];
//       colliding orders keep a stable order [medium]; removeDocument drops
//       a touching selection [high]; moveSelectionEdgeToGlobal with no
//       mounted surface is a no-op [high]; selectAll over an empty leading
//       document does not throw [high]; collapsed or empty selection has no
//       endpoint rect [high]; global rect and unmounted edges [high];
//       setDocuments without the selected document drops it [medium];
//       localBoxesForRange group (valid range, soft wrap, empty / inverted,
//       out-of-bounds) [medium]; word boundaries: apostrophe, underscore and
//       digits [low].
//   (d) not applicable: controller groups ("a group keeps one selection
//       across controllers"), deferred removeDocument while a surface is
//       mounted, isLinkAtGlobal, order-less putDocument auto-ordering,
//       "an unregistered endpoint does not paint every registered body"
//       (markdown_kit orders unregistered ids by id on purpose).
//
// selection/selection_handles_test.dart, selection_chrome_test.dart,
// selection_handle_endpoints_test.dart, selection_host_gates_test.dart,
// selection_scope_regressions_test.dart, selection_widget_test.dart
//   (a) already covered: handle drags, opaque hit area, desktop shows no
//       handles, canStartSelectionAt, toolbar toggling, route changes.
//   (c) ported with a different expectation: "disabling hides chrome and
//       enabling restores it" - markdown_kit clears the selection when the
//       scope is disabled (selection_scope.dart didUpdateWidget).
//   (b) ported: moveSelectionEdgeToGlobal(isStart) moves only that edge
//       [high]; a handle drag onto the other edge never collapses [high];
//       directed edges may cross [high]; handles stay when one selection-end
//       surface unmounts [high]; both endpoints unmounted still keeps the
//       range [high]; a disabled scope does not select on drag [medium];
//       right-click does not mutate the selection [medium]; drag with only
//       an empty document does not crash [medium]; a mouse click that misses
//       clears an active range [medium].
//   Missing, not ported: long-press haptics (markdown_kit does call
//       HapticFeedback.selectionClick), toolbar anchoring / re-anchoring,
//       selection_scope_coverage_test.dart as a whole (toolbar anchors,
//       secondary-tap matrix per platform, didUpdateWidget) - low priority
//       and partly covered by selection_handles_gesture_test.
//   (d) not applicable: enableTouchGestures, enableTouchConsecutiveTaps,
//       ownsSelectionChrome, cursorResolver, isLinkAtGlobal, focus-loss
//       clearing, touch double-tap selection - not present in lib/src
//       (touch selection starts only on long-press).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

MarkdownDocument _doc(List<String> paragraphs) => MarkdownDocument(
  blocks: [
    for (final p in paragraphs) ParagraphBlock(inlines: [TextInline(p)]),
  ],
);

MarkdownPosition _pos(String doc, int block, int offset) =>
    MarkdownPosition(documentId: doc, blockIndex: block, offset: offset);

MarkdownSelection _sel(MarkdownPosition base, MarkdownPosition extent) =>
    MarkdownSelection(base: base, extent: extent);

/// One-line LTR mock surface: 10px per character, 20px tall.
class _Surface implements MarkdownSelectionSurface {
  _Surface(
    this.documentId,
    this.blockIndex,
    this.text, {
    required this.top,
    this.textOffsetInBlock = 0,
  });

  static const double advance = 10;
  static const double lineHeight = 20;

  @override
  final String documentId;
  @override
  final int blockIndex;
  final String text;
  final double top;
  static const double left = 0;
  @override
  final int textOffsetInBlock;

  TextRange? highlight;

  Offset get origin => Offset(left, top);

  /// Global point in the middle of character [index].
  Offset at(int index) =>
      origin + Offset(index * advance + advance / 2, lineHeight / 2);

  /// Global point on the caret before character [index].
  Offset caret(int index) => origin + Offset(index * advance, lineHeight / 2);

  @override
  int get textLength => text.length;

  @override
  ui.TextDirection get textDirection => ui.TextDirection.ltr;

  @override
  Rect? get globalBounds =>
      origin & Size(math.max(1, text.length * advance), lineHeight);

  @override
  bool get hasSelectionHandleLeaders => false;

  @override
  bool hitsTextAtGlobal(Offset globalOffset) =>
      text.isNotEmpty && globalBounds!.contains(globalOffset);

  @override
  MarkdownPosition positionForGlobalOffset(Offset globalOffset) {
    final local = ((globalOffset.dx - left) / advance).round().clamp(
      0,
      text.length,
    );
    return MarkdownPosition(
      documentId: documentId,
      blockIndex: blockIndex,
      offset: textOffsetInBlock + local,
    );
  }

  @override
  TextRange wordRangeAtLocal(int localOffset) {
    if (text.isEmpty) return const TextRange.collapsed(0);
    final at = localOffset.clamp(0, text.length - 1);
    final isSpace = text[at] == ' ';
    var start = at;
    var end = at + 1;
    while (start > 0 && (text[start - 1] == ' ') == isSpace) {
      start--;
    }
    while (end < text.length && (text[end] == ' ') == isSpace) {
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
        s * advance,
        0,
        e * advance,
        lineHeight,
        ui.TextDirection.ltr,
      ),
    ];
  }

  @override
  Rect caretRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) => Rect.fromLTWH(offset.clamp(0, text.length) * advance, 0, 1, lineHeight);

  @override
  Rect? globalRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) => caretRectForLocalOffset(offset, affinity: affinity).shift(origin);

  @override
  void setSelectionHighlightRange(TextRange? range) => highlight = range;

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

/// Documents `a` = ["alpha beta", "gamma"], `b` = ["delta"], `c` = ["omega"],
/// each block backed by a mounted mock surface, stacked 40px apart.
class _Fixture {
  _Fixture({bool allowCrossDocumentSelection = true})
    : controller = MarkdownSelectionController(
        allowCrossDocumentSelection: allowCrossDocumentSelection,
      ) {
    controller
      ..putDocument(
        MarkdownDocumentRef(
          id: 'a',
          order: 0,
          document: _doc(['alpha beta', 'gamma']),
        ),
      )
      ..putDocument(
        MarkdownDocumentRef(id: 'b', order: 1, document: _doc(['delta'])),
      )
      ..putDocument(
        MarkdownDocumentRef(id: 'c', order: 2, document: _doc(['omega'])),
      );
    for (final s in [a0, a1, b0, c0]) {
      controller.registerSurface(s);
    }
    controller.addListener(() => notifications++);
  }

  final MarkdownSelectionController controller;
  final a0 = _Surface('a', 0, 'alpha beta', top: 0);
  final a1 = _Surface('a', 1, 'gamma', top: 40);
  final b0 = _Surface('b', 0, 'delta', top: 80);
  final c0 = _Surface('c', 0, 'omega', top: 120);
  int notifications = 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Fixture f;
  setUp(() {
    f = _Fixture();
    addTearDown(f.controller.dispose);
  });

  group('setSelection with out-of-range positions', () {
    test('an offset past the block end clamps to the block length', () {
      f.controller.setSelection(_sel(_pos('a', 0, 6), _pos('a', 0, 999)));
      expect(f.controller.selection, _sel(_pos('a', 0, 6), _pos('a', 0, 10)));
      expect(f.controller.getText(), 'beta');
    });

    test('a block index past the end clamps to the last block', () {
      f.controller.setSelection(_sel(_pos('a', 0, 6), _pos('a', 7, 999)));
      expect(f.controller.selection!.extent, _pos('a', 1, 5));
      expect(f.controller.getText(), 'beta\n\ngamma');
    });

    test('a selection inside an unknown document copies nothing and does '
        'not throw', () {
      f.controller.setSelection(_sel(_pos('ghost', 0, 0), _pos('ghost', 0, 5)));
      expect(f.controller.getText(), '');
      expect(f.controller.getMarkdown(), '');
      expect(f.controller.selectionHandleEndpoints(), isNull);
      expect(f.controller.globalSelectionRects(), isEmpty);
      for (final s in [f.a0, f.a1, f.b0, f.c0]) {
        expect(s.highlight, isNull);
      }
    });

    test('an identical commit does not notify', () {
      final selection = _sel(_pos('a', 0, 0), _pos('a', 0, 5));
      f.controller.setSelection(selection);
      expect(f.notifications, 1);
      f.controller.setSelection(selection);
      f.controller.setSelection(_sel(_pos('a', 0, 0), _pos('a', 0, 5)));
      expect(f.notifications, 1);
    });

    test('a commit that only clamps to the same range does not notify', () {
      f.controller.setSelection(_sel(_pos('a', 0, 0), _pos('a', 0, 10)));
      expect(f.notifications, 1);
      f.controller.setSelection(_sel(_pos('a', 0, 0), _pos('a', 0, 500)));
      expect(f.notifications, 1);
    });

    test('setSelection(null) clears highlights and notifies once', () {
      f.controller.setSelection(_sel(_pos('a', 0, 0), _pos('a', 0, 5)));
      expect(f.a0.highlight, const TextRange(start: 0, end: 5));
      f.controller.setSelection(null);
      expect(f.controller.selection, isNull);
      expect(f.a0.highlight, isNull);
      expect(f.notifications, 2);
    });

    test('cross-document setSelection is pulled back into the base document '
        'when cross-document selection is off', () {
      final single = _Fixture(allowCrossDocumentSelection: false);
      addTearDown(single.controller.dispose);

      single.controller.setSelection(_sel(_pos('a', 0, 6), _pos('c', 0, 3)));
      expect(
        single.controller.selection,
        _sel(_pos('a', 0, 6), _pos('a', 1, 5)),
      );

      single.controller.setSelection(_sel(_pos('b', 0, 3), _pos('a', 0, 2)));
      expect(
        single.controller.selection,
        _sel(_pos('b', 0, 3), _pos('b', 0, 0)),
      );
      expect(single.controller.getText(), 'del');
    });
  });

  group('Reversed selections', () {
    test('copy the same text as the forward selection', () {
      f.controller.setSelection(_sel(_pos('a', 0, 6), _pos('b', 0, 3)));
      final forward = (f.controller.getText(), f.controller.getMarkdown());
      f.controller.setSelection(_sel(_pos('b', 0, 3), _pos('a', 0, 6)));
      expect(f.controller.isSelectionReversed, isTrue);
      expect((f.controller.getText(), f.controller.getMarkdown()), forward);
      expect(forward.$1, 'beta\n\ngamma\n\ndel');
    });

    test('highlight the same ranges as the forward selection', () {
      f.controller.setSelection(_sel(_pos('b', 0, 3), _pos('a', 0, 6)));
      expect(f.a0.highlight, const TextRange(start: 6, end: 10));
      expect(f.a1.highlight, const TextRange(start: 0, end: 5));
      expect(f.b0.highlight, const TextRange(start: 0, end: 3));
      expect(f.c0.highlight, isNull);
    });

    test('normalizedSelection is in reading order', () {
      f.controller.setSelection(_sel(_pos('c', 0, 1), _pos('a', 1, 2)));
      final normalized = f.controller.normalizedSelection!;
      expect(normalized.start, _pos('a', 1, 2));
      expect(normalized.end, _pos('c', 0, 1));
    });

    test('a reversed selection inside one block is reversed by offset', () {
      f.controller.setSelection(_sel(_pos('a', 0, 8), _pos('a', 0, 2)));
      expect(f.controller.isSelectionReversed, isTrue);
      expect(f.controller.getText(), 'pha be');
    });

    test('isSelectionReversed is false with no or a collapsed selection', () {
      expect(f.controller.isSelectionReversed, isFalse);
      f.controller.setSelection(MarkdownSelection.collapsed(_pos('a', 0, 3)));
      expect(f.controller.isSelectionReversed, isFalse);
      expect(f.controller.hasSelection, isFalse);
    });
  });

  group('selectAll', () {
    MarkdownSelectionController withDocs(
      List<MarkdownDocument> documents, {
      bool allowCrossDocumentSelection = true,
    }) {
      final controller = MarkdownSelectionController(
        allowCrossDocumentSelection: allowCrossDocumentSelection,
      );
      addTearDown(controller.dispose);
      for (var i = 0; i < documents.length; i++) {
        controller.putDocument(
          MarkdownDocumentRef(id: 'd$i', order: i, document: documents[i]),
        );
      }
      return controller;
    }

    const empty = MarkdownDocument(blocks: []);
    const onlyBreak = MarkdownDocument(blocks: [ThematicBreakBlock()]);

    test('with no documents and no surfaces returns false', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      expect(controller.selectAll(), isFalse);
      expect(controller.selection, isNull);
    });

    test('over only empty documents is a no-op that does not notify', () {
      final controller = withDocs([empty, onlyBreak, empty]);
      var notified = 0;
      controller.addListener(() => notified++);
      expect(controller.selectAll(), isFalse);
      expect(controller.selection, isNull);
      expect(notified, 0);
    });

    test('skips a leading empty document', () {
      final controller = withDocs([
        empty,
        _doc(['one']),
        _doc(['two']),
      ]);
      expect(controller.selectAll(), isTrue);
      expect(controller.selection, _sel(_pos('d1', 0, 0), _pos('d2', 0, 3)));
      expect(controller.getText(), 'one\n\ntwo');
    });

    test('skips a trailing empty document', () {
      final controller = withDocs([
        _doc(['one']),
        _doc(['two']),
        empty,
      ]);
      expect(controller.selectAll(), isTrue);
      expect(controller.selection!.extent, _pos('d1', 0, 3));
    });

    test('skips an empty document in the middle', () {
      final controller = withDocs([
        _doc(['one']),
        onlyBreak,
        _doc(['two']),
      ]);
      expect(controller.selectAll(), isTrue);
      expect(controller.getText(), 'one\n\ntwo');
    });

    test('starts after a leading thematic break and ends before a trailing '
        'one', () {
      const document = MarkdownDocument(
        blocks: [
          ThematicBreakBlock(),
          ParagraphBlock(inlines: [TextInline('first')]),
          ThematicBreakBlock(),
          ParagraphBlock(inlines: [TextInline('last')]),
          ThematicBreakBlock(),
        ],
      );
      final controller = withDocs([document]);
      expect(controller.selectAll(), isTrue);
      expect(controller.selection, _sel(_pos('d0', 1, 0), _pos('d0', 3, 4)));
      expect(controller.getText(), 'first\n\nlast');
      expect(controller.getMarkdown(), 'first\n\n---\n\nlast');
    });

    test('a named document that is empty or unknown returns false', () {
      final controller = withDocs([
        _doc(['one']),
        empty,
        onlyBreak,
      ]);
      expect(controller.selectAll(documentId: 'd1'), isFalse);
      expect(controller.selectAll(documentId: 'd2'), isFalse);
      expect(controller.selectAll(documentId: 'missing'), isFalse);
      expect(controller.selection, isNull);
    });

    test('a named document selects only that document even when '
        'cross-document selection is allowed', () {
      expect(f.controller.selectAll(documentId: 'b'), isTrue);
      expect(f.controller.getText(), 'delta');
      expect(f.a0.highlight, isNull);
      expect(f.c0.highlight, isNull);
    });

    test('without a selection and cross-document off, a lone registered '
        'document is the target', () {
      final controller = withDocs([
        _doc(['only', 'doc']),
      ], allowCrossDocumentSelection: false);
      expect(controller.selectAll(), isTrue);
      expect(controller.getText(), 'only\n\ndoc');
    });

    test('with cross-document off the anchor document wins over reading '
        'order', () {
      final single = _Fixture(allowCrossDocumentSelection: false);
      addTearDown(single.controller.dispose);
      single.controller.setSelection(_sel(_pos('c', 0, 1), _pos('c', 0, 2)));
      expect(single.controller.selectAll(), isTrue);
      expect(single.controller.getText(), 'omega');
    });

    test('falls back to mounted surfaces when no document is registered', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      controller
        ..registerSurface(_Surface('x', 0, 'first', top: 0))
        ..registerSurface(_Surface('x', 1, 'second', top: 40));
      expect(controller.selectAll(), isTrue);
      expect(controller.selection, _sel(_pos('x', 0, 0), _pos('x', 1, 6)));
    });
  });

  group('Document registry', () {
    test('documents are returned in reading order for sparse orders', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      controller
        ..putDocument(
          MarkdownDocumentRef(id: 'z', order: 100, document: _doc(['3'])),
        )
        ..putDocument(
          MarkdownDocumentRef(id: 'y', order: -7, document: _doc(['1'])),
        )
        ..putDocument(
          MarkdownDocumentRef(id: 'x', order: 12, document: _doc(['2'])),
        );
      expect(controller.documents.map((d) => d.id), ['y', 'x', 'z']);
      expect(controller.selectAll(), isTrue);
      expect(controller.getText(), '1\n\n2\n\n3');
    });

    test('colliding orders fall back to a stable id order', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      for (final id in ['m', 'k', 'l']) {
        controller.putDocument(
          MarkdownDocumentRef(id: id, order: 5, document: _doc([id])),
        );
      }
      expect(controller.documents.map((d) => d.id), ['k', 'l', 'm']);
      controller.setSelection(_sel(_pos('m', 0, 1), _pos('k', 0, 0)));
      expect(controller.isSelectionReversed, isTrue);
      expect(controller.getText(), 'k\n\nl\n\nm');
    });

    test('changing a document order re-sorts the selection', () {
      f.controller.setSelection(_sel(_pos('a', 1, 0), _pos('b', 0, 5)));
      expect(f.controller.isSelectionReversed, isFalse);
      f.controller.putDocument(
        MarkdownDocumentRef(id: 'b', order: -1, document: _doc(['delta'])),
      );
      expect(f.controller.documents.first.id, 'b');
      expect(f.controller.isSelectionReversed, isTrue);
    });

    test('documentForId and hasDocuments reflect registration', () {
      expect(f.controller.hasDocuments, isTrue);
      expect(f.controller.documentForId('b')!.id, 'b');
      expect(f.controller.documentForId('nope'), isNull);
      for (final id in ['a', 'b', 'c']) {
        f.controller.removeDocument(id);
      }
      expect(f.controller.hasDocuments, isFalse);
    });

    test('putDocument with an equal ref does not notify', () {
      f.controller.setSelection(_sel(_pos('a', 0, 0), _pos('a', 0, 5)));
      final before = f.notifications;
      f.controller.putDocument(
        MarkdownDocumentRef(
          id: 'a',
          order: 0,
          document: f.controller.documentForId('a')!.document,
        ),
      );
      expect(f.notifications, before);
    });

    test('removing an unknown document does not notify', () {
      f.controller.setSelection(_sel(_pos('a', 0, 0), _pos('a', 0, 5)));
      final before = f.notifications;
      f.controller.removeDocument('nope');
      expect(f.notifications, before);
      expect(f.controller.hasSelection, isTrue);
    });

    test('removing the document of either endpoint drops the selection, '
        'its highlights and toolbarWanted', () {
      for (final removed in ['a', 'c']) {
        final fixture = _Fixture();
        addTearDown(fixture.controller.dispose);
        fixture.controller.setSelection(
          _sel(_pos('a', 0, 6), _pos('c', 0, 3)),
          toolbarWanted: true,
        );
        expect(fixture.controller.toolbarWanted, isTrue);
        final before = fixture.notifications;

        fixture.controller.removeDocument(removed);
        expect(fixture.controller.selection, isNull, reason: removed);
        expect(fixture.controller.toolbarWanted, isFalse);
        expect(fixture.notifications, before + 1);
        for (final s in [fixture.a0, fixture.a1, fixture.b0, fixture.c0]) {
          expect(s.highlight, isNull);
        }
      }
    });

    test('removing a document in the middle of the range keeps the '
        'selection and drops only its text', () {
      f.controller.setSelection(_sel(_pos('a', 1, 0), _pos('c', 0, 5)));
      expect(f.controller.getText(), 'gamma\n\ndelta\n\nomega');

      f.controller.removeDocument('b');
      expect(f.controller.selection, _sel(_pos('a', 1, 0), _pos('c', 0, 5)));
      expect(f.controller.getText(), 'gamma\n\nomega');
    });

    test('an update to an unrelated document keeps selection and toolbar', () {
      f.controller.setSelection(
        _sel(_pos('a', 0, 0), _pos('a', 0, 5)),
        toolbarWanted: true,
      );
      final before = f.notifications;
      f.controller.putDocument(
        MarkdownDocumentRef(id: 'c', order: 2, document: _doc(['omega more'])),
      );
      expect(f.controller.selection, _sel(_pos('a', 0, 0), _pos('a', 0, 5)));
      expect(f.controller.toolbarWanted, isTrue);
      expect(f.notifications, before);
    });

    test('a reconcile that drops the range clears toolbarWanted', () {
      final controller = MarkdownSelectionController(
        reconciliationPolicy:
            const MarkdownReconciliationPolicy.clearOnChange(),
      );
      addTearDown(controller.dispose);
      controller.putDocument(
        MarkdownDocumentRef(id: 'a', document: _doc(['alpha beta'])),
      );
      controller.setSelection(
        _sel(_pos('a', 0, 0), _pos('a', 0, 5)),
        toolbarWanted: true,
      );
      expect(controller.toolbarWanted, isTrue);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.putDocument(
        MarkdownDocumentRef(id: 'a', document: _doc(['rewritten'])),
      );
      expect(controller.selection, isNull);
      expect(controller.toolbarWanted, isFalse);
      expect(notified, 1);
    });

    test('an append-only update keeps the selection without notifying', () {
      f.controller.setSelection(_sel(_pos('a', 0, 6), _pos('a', 1, 5)));
      final before = f.notifications;
      f.controller.putDocument(
        MarkdownDocumentRef(
          id: 'a',
          order: 0,
          document: _doc(['alpha beta', 'gamma and more', 'new block']),
        ),
      );
      expect(f.controller.selection, _sel(_pos('a', 0, 6), _pos('a', 1, 5)));
      expect(f.controller.getText(), 'beta\n\ngamma');
      expect(f.notifications, before);
    });

    test('registering a document after a selection points into it clamps '
        'the selection to the real content', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      controller.setSelection(_sel(_pos('late', 0, 2), _pos('late', 4, 50)));
      controller.putDocument(
        MarkdownDocumentRef(id: 'late', document: _doc(['short', 'text'])),
      );
      expect(
        controller.selection,
        _sel(_pos('late', 0, 2), _pos('late', 1, 4)),
      );
      expect(controller.getText(), 'ort\n\ntext');
    });
  });

  group('toolbarWanted', () {
    test('cannot be set without a non-collapsed selection', () {
      f.controller.toolbarWanted = true;
      expect(f.controller.toolbarWanted, isFalse);
      f.controller.setSelection(
        MarkdownSelection.collapsed(_pos('a', 0, 2)),
        toolbarWanted: true,
      );
      expect(f.controller.toolbarWanted, isFalse);
      expect(f.notifications, 1);
    });

    test('notifies only when the value changes', () {
      f.controller.setSelection(_sel(_pos('a', 0, 0), _pos('a', 0, 5)));
      final before = f.notifications;
      f.controller.toolbarWanted = true;
      f.controller.toolbarWanted = true;
      expect(f.notifications, before + 1);
      f.controller.toolbarWanted = false;
      expect(f.notifications, before + 2);
    });

    test('clear() resets it and a later selection starts without it', () {
      f.controller.setSelection(
        _sel(_pos('a', 0, 0), _pos('a', 0, 5)),
        toolbarWanted: true,
      );
      f.controller.clear();
      f.controller.setSelection(_sel(_pos('a', 0, 0), _pos('a', 0, 5)));
      expect(f.controller.toolbarWanted, isFalse);
    });

    test('a new gesture selection drops the toolbar request', () {
      f.controller.setSelection(
        _sel(_pos('a', 0, 0), _pos('a', 0, 5)),
        toolbarWanted: true,
      );
      expect(f.controller.selectWordAtGlobal(f.b0.at(2)), isTrue);
      expect(f.controller.toolbarWanted, isFalse);
    });

    test('clear() with nothing selected does not notify', () {
      f.controller.clear();
      expect(f.notifications, 0);
    });
  });

  _gestureEntryPointTests();
  _endpointTests();
  _lifecycleTests();
  _widgetTests();
}

void _gestureEntryPointTests() {
  group('Pointer entry points', () {
    late _Fixture f;
    setUp(() {
      f = _Fixture();
      addTearDown(f.controller.dispose);
    });

    test('every entry point returns false with no mounted surface', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      controller.putDocument(
        MarkdownDocumentRef(id: 'a', document: _doc(['alpha'])),
      );
      var notified = 0;
      controller.addListener(() => notified++);
      const point = Offset(10, 10);

      expect(controller.startAtGlobal(point), isFalse);
      expect(controller.selectWordAtGlobal(point), isFalse);
      expect(controller.selectBlockAtGlobal(point), isFalse);
      expect(controller.hitsSelectableContent(point), isFalse);
      expect(controller.extendToGlobal(point), isFalse);
      expect(notified, 0);

      controller.setSelection(_sel(_pos('a', 0, 0), _pos('a', 0, 3)));
      expect(controller.extendToGlobal(point), isFalse);
      expect(
        controller.moveSelectionEdgeToGlobal(point, isStart: true),
        isFalse,
      );
      expect(
        controller.moveSelectionEdgeToGlobal(point, isStart: false),
        isFalse,
      );
      expect(
        controller.extendGranular(controller.selection!, point, word: true),
        isFalse,
      );
      expect(controller.selection, _sel(_pos('a', 0, 0), _pos('a', 0, 3)));
      expect(controller.mountedHostBounds(), isNull);
    });

    test('extendToGlobal and moveSelectionEdgeToGlobal need a selection', () {
      expect(f.controller.extendToGlobal(f.a0.at(3)), isFalse);
      expect(
        f.controller.moveSelectionEdgeToGlobal(f.a0.at(3), isStart: true),
        isFalse,
      );
      expect(f.notifications, 0);
    });

    test('extendToGlobal to the current extent reports no change', () {
      f.controller.startAtGlobal(f.a0.caret(2));
      expect(f.controller.extendToGlobal(f.a0.caret(6)), isTrue);
      final before = f.notifications;
      expect(f.controller.extendToGlobal(f.a0.caret(6)), isFalse);
      expect(f.notifications, before);
    });

    test('a drag above all content extends to the very start', () {
      f.controller.startAtGlobal(f.b0.caret(3));
      expect(f.controller.extendToGlobal(const Offset(500, -200)), isTrue);
      expect(f.controller.selection!.extent, _pos('a', 0, 0));
      expect(f.controller.getText(), 'alpha beta\n\ngamma\n\ndel');
    });

    test('a drag below all content extends to the very end', () {
      f.controller.startAtGlobal(f.b0.caret(3));
      expect(f.controller.extendToGlobal(const Offset(-50, 900)), isTrue);
      expect(f.controller.selection!.extent, _pos('c', 0, 5));
      expect(f.controller.getText(), 'ta\n\nomega');
    });

    test('a drag in the gap between two blocks snaps to the nearer one', () {
      f.controller.startAtGlobal(f.a0.caret(0));
      // a0 spans y 0..20 and a1 spans 40..60.
      expect(f.controller.extendToGlobal(const Offset(20, 24)), isTrue);
      expect(f.controller.selection!.extent, _pos('a', 0, 2));
      expect(f.controller.extendToGlobal(const Offset(20, 37)), isTrue);
      expect(f.controller.selection!.extent, _pos('a', 1, 2));
    });

    test('selectBlockAtGlobal selects the whole block of a multi-surface '
        'block', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      const document = MarkdownDocument(
        blocks: [
          ParagraphBlock(inlines: [TextInline('head\ntail')]),
        ],
      );
      controller.putDocument(
        const MarkdownDocumentRef(id: 'a', document: document),
      );
      final head = _Surface('a', 0, 'head', top: 0);
      final tail = _Surface('a', 0, 'tail', top: 30, textOffsetInBlock: 5);
      controller
        ..registerSurface(head)
        ..registerSurface(tail);

      expect(controller.selectBlockAtGlobal(tail.at(1)), isTrue);
      expect(controller.selection, _sel(_pos('a', 0, 0), _pos('a', 0, 9)));
      expect(head.highlight, const TextRange(start: 0, end: 4));
      expect(tail.highlight, const TextRange(start: 0, end: 4));
    });

    test('selectWordAtGlobal on a later surface of a block uses block '
        'offsets', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      controller.putDocument(
        const MarkdownDocumentRef(
          id: 'a',
          document: MarkdownDocument(
            blocks: [
              ParagraphBlock(inlines: [TextInline('head\ntail end')]),
            ],
          ),
        ),
      );
      final tail = _Surface('a', 0, 'tail end', top: 30, textOffsetInBlock: 5);
      controller.registerSurface(tail);

      expect(controller.selectWordAtGlobal(tail.at(6)), isTrue);
      expect(controller.selection, _sel(_pos('a', 0, 10), _pos('a', 0, 13)));
      expect(controller.getText(), 'end');
    });

    test('selectWordAtGlobal near an empty surface yields a collapsed '
        'selection, not a throw', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      final blank = _Surface('x', 0, '', top: 0);
      controller.registerSurface(blank);

      expect(controller.selectWordAtGlobal(const Offset(3, 10)), isTrue);
      expect(controller.selection!.isCollapsed, isTrue);
      expect(controller.hasSelection, isFalse);
      expect(controller.getText(), '');
    });

    test('hitsSelectableContent is true only over text', () {
      expect(f.controller.hitsSelectableContent(f.a1.at(2)), isTrue);
      // Right of the 5-character line.
      expect(
        f.controller.hitsSelectableContent(const Offset(200, 50)),
        isFalse,
      );
      // Between two blocks.
      expect(f.controller.hitsSelectableContent(const Offset(10, 30)), isFalse);
    });
  });

  group('moveSelectionEdgeToGlobal', () {
    late _Fixture f;
    setUp(() {
      f = _Fixture();
      addTearDown(f.controller.dispose);
      f.controller.setSelection(_sel(_pos('a', 0, 2), _pos('a', 0, 8)));
    });

    test('isStart: true moves only the start', () {
      expect(
        f.controller.moveSelectionEdgeToGlobal(f.a0.caret(0), isStart: true),
        isTrue,
      );
      final normalized = f.controller.normalizedSelection!;
      expect((normalized.start.offset, normalized.end.offset), (0, 8));
    });

    test('isStart: false moves only the end', () {
      expect(
        f.controller.moveSelectionEdgeToGlobal(f.a1.caret(3), isStart: false),
        isTrue,
      );
      final normalized = f.controller.normalizedSelection!;
      expect(normalized.start, _pos('a', 0, 2));
      expect(normalized.end, _pos('a', 1, 3));
    });

    test('on a reversed selection isStart still means the reading-order '
        'start', () {
      f.controller.setSelection(_sel(_pos('a', 0, 8), _pos('a', 0, 2)));
      expect(
        f.controller.moveSelectionEdgeToGlobal(f.a0.caret(4), isStart: true),
        isTrue,
      );
      final normalized = f.controller.normalizedSelection!;
      expect((normalized.start.offset, normalized.end.offset), (4, 8));

      expect(
        f.controller.moveSelectionEdgeToGlobal(f.a0.caret(10), isStart: false),
        isTrue,
      );
      final after = f.controller.normalizedSelection!;
      expect((after.start.offset, after.end.offset), (4, 10));
    });

    test('dragging an edge exactly onto the other edge never collapses', () {
      final before = f.notifications;
      expect(
        f.controller.moveSelectionEdgeToGlobal(f.a0.caret(8), isStart: true),
        isFalse,
      );
      expect(
        f.controller.moveSelectionEdgeToGlobal(f.a0.caret(2), isStart: false),
        isFalse,
      );
      expect(f.controller.selection, _sel(_pos('a', 0, 2), _pos('a', 0, 8)));
      expect(f.notifications, before);
    });

    test('dragging the start past the end flips the selection around the '
        'fixed end', () {
      expect(
        f.controller.moveSelectionEdgeToGlobal(f.a1.caret(3), isStart: true),
        isTrue,
      );
      final normalized = f.controller.normalizedSelection!;
      expect(normalized.start, _pos('a', 0, 8));
      expect(normalized.end, _pos('a', 1, 3));
      expect(f.controller.getText(), 'ta\n\ngam');
    });

    test('dragging the end before the start flips the selection around the '
        'fixed start', () {
      expect(
        f.controller.moveSelectionEdgeToGlobal(f.a0.caret(0), isStart: false),
        isTrue,
      );
      final normalized = f.controller.normalizedSelection!;
      expect((normalized.start.offset, normalized.end.offset), (0, 2));
      expect(f.controller.getText(), 'al');
    });

    test('an edge may cross into another document when allowed', () {
      expect(
        f.controller.moveSelectionEdgeToGlobal(f.c0.caret(2), isStart: false),
        isTrue,
      );
      expect(f.controller.normalizedSelection!.end, _pos('c', 0, 2));
    });

    test('an edge is clamped to the fixed edge document when cross-document '
        'selection is off', () {
      final single = _Fixture(allowCrossDocumentSelection: false);
      addTearDown(single.controller.dispose);
      single.controller.setSelection(_sel(_pos('b', 0, 1), _pos('b', 0, 3)));

      single.controller.moveSelectionEdgeToGlobal(
        single.c0.caret(4),
        isStart: false,
      );
      expect(single.controller.normalizedSelection!.end, _pos('b', 0, 5));

      single.controller.moveSelectionEdgeToGlobal(
        single.a0.caret(4),
        isStart: true,
      );
      expect(single.controller.normalizedSelection!.start, _pos('b', 0, 0));
      expect(single.controller.getText(), 'delta');
      expect(single.a0.highlight, isNull);
      expect(single.c0.highlight, isNull);
    });
  });

  group('mountedHostBounds', () {
    test('is the union of every mounted surface', () {
      final f = _Fixture();
      addTearDown(f.controller.dispose);
      expect(
        f.controller.mountedHostBounds(),
        const Rect.fromLTRB(0, 0, 100, 140),
      );
    });

    test('is limited to the anchor document when cross-document selection '
        'is off', () {
      final f = _Fixture(allowCrossDocumentSelection: false);
      addTearDown(f.controller.dispose);
      expect(
        f.controller.mountedHostBounds(),
        const Rect.fromLTRB(0, 0, 100, 140),
        reason: 'no selection yet: nothing to scope to',
      );

      f.controller.setSelection(_sel(_pos('b', 0, 0), _pos('b', 0, 2)));
      expect(
        f.controller.mountedHostBounds(),
        const Rect.fromLTRB(0, 80, 50, 100),
      );
      expect(
        f.controller.mountedHostBounds(respectCrossDocumentLimit: false),
        const Rect.fromLTRB(0, 0, 100, 140),
      );
    });
  });
}

void _endpointTests() {
  group('Handle endpoints with unmounted ends', () {
    late _Fixture f;
    setUp(() {
      f = _Fixture();
      addTearDown(f.controller.dispose);
    });

    test('no selection or a collapsed selection has no endpoints', () {
      expect(f.controller.selectionHandleEndpoints(), isNull);
      expect(f.controller.selectionEndpointGlobalRect(base: true), isNull);
      expect(f.controller.selectionEndpointGlobalRect(base: false), isNull);
      expect(f.controller.globalSelectionRects(), isEmpty);

      f.controller.setSelection(MarkdownSelection.collapsed(_pos('a', 0, 3)));
      expect(f.controller.selectionHandleEndpoints(), isNull);
      expect(f.controller.globalSelectionRects(), isEmpty);
    });

    test('both ends mounted: endpoints sit on the caret bottoms', () {
      f.controller.setSelection(_sel(_pos('a', 0, 6), _pos('b', 0, 3)));
      final endpoints = f.controller.selectionHandleEndpoints()!;
      expect(endpoints.hasStart && endpoints.hasEnd, isTrue);
      expect(endpoints.startSurface, same(f.a0));
      expect(endpoints.endSurface, same(f.b0));
      expect(endpoints.startLocalOffset, 6);
      expect(endpoints.endLocalOffset, 3);
      expect(endpoints.startGlobal, const Offset(60, 20));
      expect(endpoints.endGlobal, const Offset(30, 100));
      expect(endpoints.startLineHeight, _Surface.lineHeight);
      expect(endpoints.endLineHeight, _Surface.lineHeight);
    });

    test('an unmounted start leaves only the end endpoint', () {
      f.controller.setSelection(_sel(_pos('a', 0, 6), _pos('c', 0, 3)));
      f.controller.unregisterSurface(f.a0);

      final endpoints = f.controller.selectionHandleEndpoints()!;
      expect(endpoints.hasStart, isFalse);
      expect(endpoints.startSurface, isNull);
      expect(endpoints.startGlobal, isNull);
      expect(endpoints.hasEnd, isTrue);
      expect(endpoints.endSurface, same(f.c0));
      expect(endpoints.hasAny, isTrue);
      expect(f.controller.selection, _sel(_pos('a', 0, 6), _pos('c', 0, 3)));
    });

    test('an unmounted end leaves only the start endpoint', () {
      f.controller.setSelection(_sel(_pos('a', 0, 6), _pos('c', 0, 3)));
      f.controller.unregisterSurface(f.c0);

      final endpoints = f.controller.selectionHandleEndpoints()!;
      expect(endpoints.hasStart, isTrue);
      expect(endpoints.startSurface, same(f.a0));
      expect(endpoints.hasEnd, isFalse);
      expect(endpoints.endGlobal, isNull);
    });

    test('a reversed selection with an unmounted base loses the END '
        'endpoint (reading order)', () {
      // base c:3 is the reading-order end.
      f.controller.setSelection(_sel(_pos('c', 0, 3), _pos('a', 0, 6)));
      f.controller.unregisterSurface(f.c0);

      final endpoints = f.controller.selectionHandleEndpoints()!;
      expect(endpoints.hasStart, isTrue);
      expect(endpoints.hasEnd, isFalse);
      expect(f.controller.selectionEndpointGlobalRect(base: true), isNull);
      expect(
        f.controller.selectionEndpointGlobalRect(base: false),
        const Rect.fromLTWH(60, 0, 1, 20),
      );
    });

    test('both ends unmounted: no endpoints, but the range and its copy '
        'survive', () {
      f.controller.setSelection(_sel(_pos('a', 0, 6), _pos('c', 0, 3)));
      f.controller
        ..unregisterSurface(f.a0)
        ..unregisterSurface(f.c0);

      expect(f.controller.selectionHandleEndpoints(), isNull);
      expect(f.controller.hasSelection, isTrue);
      expect(f.controller.getText(), 'beta\n\ngamma\n\ndelta\n\nome');
      // The blocks in between are still mounted and still highlighted.
      expect(f.a1.highlight, const TextRange(start: 0, end: 5));
      expect(f.b0.highlight, const TextRange(start: 0, end: 5));
      expect(f.controller.globalSelectionRects(), hasLength(2));
    });

    test('remounting an end restores its endpoint and highlight', () {
      f.controller.setSelection(_sel(_pos('a', 0, 6), _pos('c', 0, 3)));
      f.controller.unregisterSurface(f.a0);
      final remounted = _Surface('a', 0, 'alpha beta', top: -300);
      f.controller.registerSurface(remounted);

      expect(remounted.highlight, const TextRange(start: 6, end: 10));
      final endpoints = f.controller.selectionHandleEndpoints()!;
      expect(endpoints.startSurface, same(remounted));
      expect(endpoints.startGlobal, const Offset(60, -280));
    });

    test('globalSelectionRects lists one rect per mounted surface in '
        'reading order', () {
      f.controller.setSelection(_sel(_pos('c', 0, 3), _pos('a', 0, 6)));
      expect(f.controller.globalSelectionRects(), const [
        Rect.fromLTRB(60, 0, 100, 20),
        Rect.fromLTRB(0, 40, 50, 60),
        Rect.fromLTRB(0, 80, 50, 100),
        Rect.fromLTRB(0, 120, 30, 140),
      ]);
    });

    test('MarkdownHandleEndpoints equality covers every field', () {
      const base = MarkdownHandleEndpoints(
        startLocalOffset: 1,
        endLocalOffset: 2,
        startGlobal: Offset(1, 2),
        endGlobal: Offset(3, 4),
        startLineHeight: 10,
        endLineHeight: 12,
      );
      const same = MarkdownHandleEndpoints(
        startLocalOffset: 1,
        endLocalOffset: 2,
        startGlobal: Offset(1, 2),
        endGlobal: Offset(3, 4),
        startLineHeight: 10,
        endLineHeight: 12,
      );
      expect(base, same);
      expect(base.hashCode, same.hashCode);
      // No surface: positions alone do not make an endpoint.
      expect(base.hasAny, isFalse);
      expect(
        base,
        isNot(
          const MarkdownHandleEndpoints(
            startLocalOffset: 1,
            endLocalOffset: 2,
            startGlobal: Offset(1, 2),
            endGlobal: Offset(3, 5),
            startLineHeight: 10,
            endLineHeight: 12,
          ),
        ),
      );
    });
  });
}

void _lifecycleTests() {
  group('Controller lifecycle', () {
    test('surfaces are deduplicated and exposed read-only', () {
      final f = _Fixture();
      addTearDown(f.controller.dispose);
      f.controller.registerSurface(f.a0);
      expect(f.controller.mountedSurfaces, hasLength(4));
      expect(
        () => f.controller.mountedSurfaces.add(_Surface('q', 0, 'q', top: 0)),
        throwsUnsupportedError,
      );
    });

    test('unregistering an unknown surface is ignored', () {
      final f = _Fixture();
      addTearDown(f.controller.dispose);
      f.controller.setSelection(_sel(_pos('a', 0, 0), _pos('a', 0, 3)));
      final before = f.notifications;
      f.controller.unregisterSurface(_Surface('q', 0, 'q', top: 0));
      expect(f.notifications, before);
    });

    test('a surface registered while a selection is active receives its '
        'highlight immediately', () {
      final f = _Fixture();
      addTearDown(f.controller.dispose);
      f.controller.setSelection(_sel(_pos('a', 0, 0), _pos('c', 0, 5)));
      final late = _Surface('b', 0, 'delta', top: 300);
      f.controller.registerSurface(late);
      expect(late.highlight, const TextRange(start: 0, end: 5));
    });

    test('dispose is idempotent and later calls are inert', () {
      final controller = MarkdownSelectionController();
      controller.putDocument(
        MarkdownDocumentRef(id: 'a', document: _doc(['alpha'])),
      );
      controller.dispose();
      controller.dispose();

      final surface = _Surface('a', 0, 'alpha', top: 0);
      controller
        ..putDocument(MarkdownDocumentRef(id: 'b', document: _doc(['beta'])))
        ..removeDocument('a')
        ..registerSurface(surface)
        ..unregisterSurface(surface);
      expect(controller.hasDocuments, isFalse);
      expect(controller.mountedSurfaces, isEmpty);
    });
  });
}

Widget _testApp({required Widget child}) {
  return Directionality(
    key: UniqueKey(),
    textDirection: ui.TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: FocusScope(
        autofocus: true,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) =>
                  ColoredBox(color: const Color(0xFFFFFFFF), child: child),
            ),
          ],
        ),
      ),
    ),
  );
}

RenderSelectableParagraph _paragraph(WidgetTester tester, String substring) {
  for (final element in find.bySubtype<RichText>().evaluate()) {
    final ro = element.renderObject;
    if (ro is RenderSelectableParagraph &&
        ro.attached &&
        ro.baseText.toPlainText().contains(substring)) {
      return ro;
    }
  }
  throw StateError('no paragraph containing "$substring"');
}

Offset _glyphCenter(RenderSelectableParagraph p, int index) {
  final box = p.boxesForLocalRange(index, index + 1).first.toRect();
  return p.localToGlobal(box.center);
}

Future<void> _longPress(WidgetTester tester, Offset at) async {
  final g = await tester.startGesture(at, kind: PointerDeviceKind.touch);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await g.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

String _id(int i) => 'm${i.toString().padLeft(2, '0')}';
String _body(int i) => 'message ${i.toString().padLeft(2, '0')} body text';

void _widgetTests() {
  final startHandle = find.byKey(MarkdownSelectionHandleOverlay.startHandleKey);
  final endHandle = find.byKey(MarkdownSelectionHandleOverlay.endHandleKey);

  Future<(MarkdownSelectionController, ScrollController)> pumpChat(
    WidgetTester tester, {
    bool enabled = true,
    MarkdownSelectionController? controller,
  }) async {
    final selection = controller ?? MarkdownSelectionController();
    if (controller == null) addTearDown(selection.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _testApp(
        child: MarkdownSelectionScope(
          controller: selection,
          enabled: enabled,
          child: ListView.builder(
            controller: scroll,
            itemCount: 40,
            itemBuilder: (context, index) => SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: MarkdownView(
                  document: _doc([_body(index)]),
                  documentId: _id(index),
                  documentOrder: index,
                  theme: MarkdownThemeData.fallback(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (selection, scroll);
  }

  /// A lazily built list only registers the documents it has built. Walk the
  /// list once so every message is known to the controller, then return to
  /// the top (documents are kept after their widgets are disposed).
  Future<void> buildEveryMessage(
    WidgetTester tester,
    MarkdownSelectionController controller,
    ScrollController scroll,
  ) async {
    final max = scroll.position.maxScrollExtent;
    for (var offset = 0.0; offset < max; offset += 400) {
      scroll.jumpTo(offset);
      await tester.pump();
    }
    scroll.jumpTo(max);
    await tester.pump();
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(controller.documents, hasLength(40));
  }

  void onPlatform(
    TargetPlatform platform,
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  group('Touch handles when a selection end is virtualized away', () {
    onPlatform(
      TargetPlatform.iOS,
      'control: both handles show for a '
      'long-pressed word',
      (tester) async {
        final (controller, _) = await pumpChat(tester);
        await _longPress(tester, _glyphCenter(_paragraph(tester, _body(2)), 1));
        expect(controller.getText(), 'message');
        expect(startHandle, findsOneWidget);
        expect(endHandle, findsOneWidget);
      },
    );

    onPlatform(
      TargetPlatform.iOS,
      'only the start handle shows while the '
      'end message is not built',
      (tester) async {
        final (controller, scroll) = await pumpChat(tester);
        await buildEveryMessage(tester, controller, scroll);
        await _longPress(tester, _glyphCenter(_paragraph(tester, _body(2)), 1));
        controller.setSelection(_sel(_pos(_id(2), 0, 0), _pos(_id(35), 0, 7)));
        await tester.pump();
        await tester.pump();

        expect(controller.selectionHandleEndpoints()!.hasEnd, isFalse);
        expect(startHandle, findsOneWidget);
        expect(endHandle, findsNothing);
      },
    );

    onPlatform(
      TargetPlatform.iOS,
      'scrolling to the end message swaps '
      'which handle shows and keeps the range',
      (tester) async {
        final (controller, scroll) = await pumpChat(tester);
        await buildEveryMessage(tester, controller, scroll);
        await _longPress(tester, _glyphCenter(_paragraph(tester, _body(2)), 1));
        final range = _sel(_pos(_id(2), 0, 0), _pos(_id(35), 0, 7));
        controller.setSelection(range);
        await tester.pump();

        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.selection, range);
        final endpoints = controller.selectionHandleEndpoints()!;
        expect(endpoints.hasStart, isFalse);
        expect(endpoints.hasEnd, isTrue);
        expect(startHandle, findsNothing);
        expect(endHandle, findsOneWidget);
      },
    );

    onPlatform(
      TargetPlatform.iOS,
      'with both ends scrolled away no handle '
      'shows, the middle stays highlighted and copy is complete',
      (tester) async {
        final (controller, scroll) = await pumpChat(tester);
        await buildEveryMessage(tester, controller, scroll);
        await _longPress(tester, _glyphCenter(_paragraph(tester, _body(2)), 1));
        controller.setSelection(_sel(_pos(_id(0), 0, 0), _pos(_id(39), 0, 7)));
        await tester.pump();

        scroll.jumpTo(48.0 * 18);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.selectionHandleEndpoints(), isNull);
        expect(startHandle, findsNothing);
        expect(endHandle, findsNothing);
        expect(controller.globalSelectionRects(), isNotEmpty);
        final lines = controller.getText().split('\n\n');
        expect(lines, hasLength(40));
        expect(lines.first, _body(0));
        expect(lines.last, 'message');
      },
    );
  });

  group('Scope enabled flag', () {
    onPlatform(
      TargetPlatform.iOS,
      'a disabled scope does not select on '
      'long-press',
      (tester) async {
        final (controller, _) = await pumpChat(tester, enabled: false);
        await _longPress(tester, _glyphCenter(_paragraph(tester, _body(2)), 1));
        expect(controller.selection, isNull);
        expect(startHandle, findsNothing);
      },
    );

    onPlatform(
      TargetPlatform.macOS,
      'a disabled scope does not select on a '
      'mouse drag',
      (tester) async {
        final (controller, _) = await pumpChat(tester, enabled: false);
        final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: from);
        await mouse.down(from);
        await tester.pump();
        await mouse.moveTo(from + const Offset(80, 0));
        await tester.pump();
        await mouse.up();
        await tester.pump();
        expect(controller.selection, isNull);
      },
    );

    onPlatform(
      TargetPlatform.iOS,
      'disabling clears the selection and its handles; a re-enabled scope '
      'selects again',
      (tester) async {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);

        Widget build({required bool enabled}) => Directionality(
          textDirection: ui.TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: FocusScope(
              autofocus: true,
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => _EnabledHost(
                      controller: controller,
                      initiallyEnabled: enabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpWidget(build(enabled: true));
        await tester.pump();
        await _longPress(tester, _glyphCenter(_paragraph(tester, 'alpha'), 1));
        expect(controller.getText(), 'alpha');
        expect(startHandle, findsOneWidget);

        // Spec difference from the reference ("disabling hides chrome and
        // enabling restores it"): markdown_kit clears the selection when the
        // scope is disabled (MarkdownSelectionScopeState.didUpdateWidget:
        // `if (!widget.enabled && oldWidget.enabled) clearSelection();`).
        tester.state<_EnabledHostState>(find.byType(_EnabledHost)).set(false);
        await tester.pump();
        await tester.pump();
        expect(startHandle, findsNothing);
        expect(endHandle, findsNothing);
        expect(controller.selection, isNull);

        tester.state<_EnabledHostState>(find.byType(_EnabledHost)).set(true);
        await tester.pump();
        await tester.pump();
        expect(startHandle, findsNothing);
        expect(controller.selection, isNull);

        // The re-enabled scope selects again.
        await _longPress(tester, _glyphCenter(_paragraph(tester, 'alpha'), 1));
        expect(controller.getText(), 'alpha');
        expect(startHandle, findsOneWidget);
      },
    );
  });

  group('Desktop pointer edge cases', () {
    onPlatform(
      TargetPlatform.macOS,
      'a right-click inside the selection '
      'does not change it',
      (tester) async {
        final (controller, _) = await pumpChat(tester);
        final range = _sel(_pos(_id(2), 0, 0), _pos(_id(2), 0, 15));
        controller.setSelection(range);
        await tester.pump();

        final right = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        final at = _glyphCenter(_paragraph(tester, _body(2)), 4);
        await right.addPointer(location: at);
        await right.down(at);
        await right.up();
        await tester.pump();
        expect(controller.selection, range);
      },
    );

    onPlatform(
      TargetPlatform.macOS,
      'a click on empty space clears the '
      'selection',
      (tester) async {
        final (controller, _) = await pumpChat(tester);
        controller.setSelection(_sel(_pos(_id(2), 0, 0), _pos(_id(2), 0, 7)));
        await tester.pump();

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        const empty = Offset(700, 110);
        expect(controller.hitsSelectableContent(empty), isFalse);
        await mouse.addPointer(location: empty);
        await mouse.down(empty);
        await mouse.up();
        await tester.pump(const Duration(milliseconds: 400));
        expect(controller.hasSelection, isFalse);
      },
    );

    onPlatform(
      TargetPlatform.macOS,
      'a drag over a scope that holds only '
      'an empty document does nothing and does not throw',
      (tester) async {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              child: const Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  child: MarkdownView(data: '', documentId: 'empty'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(20, 20));
        await mouse.down(const Offset(20, 20));
        await tester.pump();
        await mouse.moveTo(const Offset(200, 200));
        await tester.pump();
        await mouse.up();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(controller.hasSelection, isFalse);
        expect(controller.getText(), '');
      },
    );

    onPlatform(
      TargetPlatform.macOS,
      'a drag that starts past an empty '
      'document still selects the real one',
      (tester) async {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MarkdownView(
                        data: '',
                        documentId: 'empty',
                        documentOrder: 0,
                      ),
                      MarkdownView(
                        document: _doc(['real words here']),
                        documentId: 'real',
                        documentOrder: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final p = _paragraph(tester, 'real words');
        final from = _glyphCenter(p, 0) - const Offset(6, 0);
        final to = _glyphCenter(p, 3) + const Offset(7, 0);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: from);
        await mouse.down(from);
        await tester.pump();
        await mouse.moveTo(Offset.lerp(from, to, 0.5)!);
        await tester.pump();
        await mouse.moveTo(to);
        await tester.pump();
        await mouse.up();
        await tester.pump();

        expect(controller.getText(), 'real');
      },
    );
  });

  group('RenderSelectableParagraph geometry queries', () {
    Future<RenderSelectableParagraph> pumpParagraph(
      WidgetTester tester,
      String text, {
      double width = 300,
    }) async {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _testApp(
          child: MarkdownSelectionScope(
            controller: controller,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: MarkdownView(document: _doc([text]), documentId: 'doc'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return _paragraph(tester, text.substring(0, 4));
    }

    testWidgets('a valid range has boxes inside the paragraph', (tester) async {
      final p = await pumpParagraph(tester, 'hello world');
      final boxes = p.boxesForLocalRange(0, 5);
      expect(boxes, isNotEmpty);
      for (final box in boxes) {
        expect(
          (Offset.zero & p.size).inflate(0.5).contains(box.toRect().center),
          isTrue,
        );
      }
    });

    testWidgets('a soft-wrapped range has one box per visual line', (
      tester,
    ) async {
      const text = 'a long line of text that wraps onto several visual lines';
      final p = await pumpParagraph(tester, text, width: 120);
      final tops = p
          .boxesForLocalRange(0, text.length)
          .map((b) => b.top)
          .toSet();
      expect(tops.length, greaterThan(2));
    });

    testWidgets('an empty or inverted range has no boxes', (tester) async {
      final p = await pumpParagraph(tester, 'hello world');
      expect(p.boxesForLocalRange(3, 3), isEmpty);
      expect(p.boxesForLocalRange(7, 2), isEmpty);
    });

    testWidgets('out-of-bounds offsets are clamped', (tester) async {
      final p = await pumpParagraph(tester, 'hello world');
      final whole = p.boxesForLocalRange(0, 11);
      final clamped = p.boxesForLocalRange(-10, 9999);
      expect(clamped.map((b) => b.toRect()), whole.map((b) => b.toRect()));
      expect(p.boxesForLocalRange(50, 60), isEmpty);
      expect(p.caretRectForLocalOffset(9999).left, greaterThan(0));
      expect(p.wordRangeAtLocal(9999).isValid, isTrue);
    });

    testWidgets('the gutter right of a short line is not text', (tester) async {
      final p = await pumpParagraph(tester, 'short');
      final last = p.boxesForLocalRange(4, 5).first.toRect();
      expect(p.hitsTextAtGlobal(p.localToGlobal(last.center)), isTrue);
      expect(
        p.hitsTextAtGlobal(
          p.localToGlobal(Offset(last.right + 40, last.center.dy)),
        ),
        isFalse,
      );
    });

    testWidgets('a word keeps its apostrophe', (tester) async {
      final p = await pumpParagraph(tester, "we don't stop");
      final range = p.wordRangeAtLocal(5);
      expect("we don't stop".substring(range.start, range.end), "don't");
    });

    testWidgets('underscores and digits stay inside a word', (tester) async {
      final p = await pumpParagraph(tester, 'call snake_case2 now');
      final range = p.wordRangeAtLocal(8);
      expect(
        'call snake_case2 now'.substring(range.start, range.end),
        'snake_case2',
      );
    });
  });
}

class _EnabledHost extends StatefulWidget {
  const _EnabledHost({
    required this.controller,
    required this.initiallyEnabled,
  });
  final MarkdownSelectionController controller;
  final bool initiallyEnabled;

  @override
  State<_EnabledHost> createState() => _EnabledHostState();
}

class _EnabledHostState extends State<_EnabledHost> {
  late bool _enabled = widget.initiallyEnabled;

  void set(bool value) => setState(() => _enabled = value);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: MarkdownSelectionScope(
        controller: widget.controller,
        enabled: _enabled,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(60),
            child: MarkdownView(
              document: _doc(const ['alpha beta gamma']),
              documentId: 'doc',
            ),
          ),
        ),
      ),
    );
  }
}
