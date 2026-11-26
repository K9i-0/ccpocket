// Right-to-left selection and selection-relevant RTL geometry.
//
// Gap inventory against the reference suite (flutter_md, MIT), by test name:
//
// selection/selection_rtl_test.dart
//   (b) ported: mouse drag from the right edge selects the reading start
//       [high]; copied text does not depend on the direction [high]; a
//       reversed RTL / LTR selection keeps reading-order endpoints [high];
//       each end of a mixed selection follows its own document [medium];
//       narrow widths paint without throwing [low]; an empty RTL document
//       lays out to nothing [low].
//   (c) ported with a different expectation: "handle types follow the text,
//       not the ambient Directionality" - markdown_kit handles are logical
//       start/end (MarkdownSelectionHandleType), there are no left/right
//       handle types, so the tests assert that the START endpoint sits on the
//       visual right of RTL text. "a scrolled-off RTL base proxies onto the
//       reading start" - markdown_kit reports a null endpoint instead of a
//       proxy (MarkdownHandleEndpoints doc comment).
//   Missing, not ported: "Right-to-left link taps" (link hit-testing, not a
//       selection behaviour).
//   (d) not applicable: "Right-to-left constraints" minWidth /
//       loose-constraint hugging (flutter_md's single-render-object layout).

// The reference header and quote/alert indent tests (rtl_test.dart "heading
// aligns", "quote text sits left of the right-hand indent", nested children)
// are missing and not ported: block chrome geometry, not selection.
//
// widget/rtl_test.dart, widget/rtl_geometry_test.dart
//   (b) ported: maps the right edge to the start of RTL text [high]; aligns
//       RTL text to the right edge / keeps LTR on the left [medium]; RTL list
//       item content sits left of the bullet [medium]; RTL table maps taps
//       back to mirrored cells [medium]; code blocks stay left-to-right
//       [medium]; selection geometry matches the highlighted glyphs [high].
//   (d) not applicable: "is the mirror of LTR" pixel comparisons, explicit
//       column alignment, degenerate / infinite widths - those pin
//       flutter_md's own painter and have no selection behaviour.
//
// New here (no reference counterpart): the RTL branch of
// MarkdownSelectionController.selectWordAtGlobal that steps back onto the
// pressed glyph.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:markdown_kit/src/selection/selection_handles.dart';

Widget _testApp({
  required Widget child,
  ui.TextDirection direction = ui.TextDirection.ltr,
  Size size = const Size(420, 680),
}) {
  // A fresh key per call: Overlay only reads initialEntries once, so pumping
  // a second tree in the same test must remount it.
  return Directionality(
    key: UniqueKey(),
    textDirection: direction,
    child: MediaQuery(
      data: MediaQueryData(size: size),
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

MarkdownDocument _doc(List<String> paragraphs) => MarkdownDocument(
  blocks: [
    for (final p in paragraphs) ParagraphBlock(inlines: [TextInline(p)]),
  ],
);

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

/// Global rect of the glyph at canonical offset [index] of [p].
Rect _glyph(RenderSelectableParagraph p, int index) {
  final boxes = p.boxesForLocalRange(index, index + 1);
  expect(boxes, isNotEmpty, reason: 'glyph $index has no box');
  final local = boxes.first.toRect();
  return p.localToGlobal(local.topLeft) & local.size;
}

/// A point inside glyph [index], [fraction] of the way from its visual left.
Offset _inGlyph(RenderSelectableParagraph p, int index, double fraction) {
  final rect = _glyph(p, index);
  return Offset(rect.left + rect.width * fraction, rect.center.dy);
}

MarkdownPosition _pos(String doc, int block, int offset) =>
    MarkdownPosition(documentId: doc, blockIndex: block, offset: offset);

/// One-line mock surface with a fixed advance per character. In RTL the first
/// character sits at the right edge and offsets grow leftwards.
class _LineSurface implements MarkdownSelectionSurface {
  _LineSurface({
    required this.documentId,
    required this.text,
    required this.textDirection,
    this.origin = Offset.zero,
  });

  static const double advance = 10;
  static const double lineHeight = 20;

  @override
  final String documentId;
  final String text;
  final Offset origin;

  @override
  final ui.TextDirection textDirection;

  @override
  int get blockIndex => 0;

  @override
  int get textOffsetInBlock => 0;

  @override
  int get textLength => text.length;

  double get _width => text.length * advance;

  bool get _rtl => textDirection == ui.TextDirection.rtl;

  /// Local x of the caret before character [offset].
  double _caretX(int offset) =>
      _rtl ? _width - offset * advance : offset * advance;

  /// A global point inside character [index], [fraction] of the way from its
  /// LEADING edge (the right edge in RTL).
  Offset inChar(int index, double fraction) {
    final leading = _caretX(index);
    final x = _rtl
        ? leading - advance * fraction
        : leading + advance * fraction;
    return origin + Offset(x, lineHeight / 2);
  }

  @override
  Rect? get globalBounds => origin & Size(_width, lineHeight);

  @override
  bool get hasSelectionHandleLeaders => false;

  @override
  bool hitsTextAtGlobal(Offset globalOffset) =>
      globalBounds!.contains(globalOffset);

  @override
  MarkdownPosition positionForGlobalOffset(Offset globalOffset) {
    final localX = globalOffset.dx - origin.dx;
    final fromLeading = _rtl ? _width - localX : localX;
    final offset = (fromLeading / advance).round().clamp(0, text.length);
    return MarkdownPosition(
      documentId: documentId,
      blockIndex: 0,
      offset: offset,
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
    final a = _caretX(s);
    final b = _caretX(e);
    return [
      TextBox.fromLTRBD(
        a < b ? a : b,
        0,
        a < b ? b : a,
        lineHeight,
        textDirection,
      ),
    ];
  }

  @override
  Rect caretRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) {
    // Same shape as RenderSelectableParagraph: a 1px caret starting at the
    // caret x.
    return Rect.fromLTWH(
      _caretX(offset.clamp(0, text.length)),
      0,
      1,
      lineHeight,
    );
  }

  @override
  Rect? globalRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) => caretRectForLocalOffset(offset, affinity: affinity).shift(origin);

  @override
  void setSelectionHighlightRange(TextRange? range) {}

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

const _hebrew = 'שלום עולם טוב'; // words at 0..4, 5..9, 10..13
const _rtlWithLatin = 'שלום hello עולם'; // Latin word at 5..10
const _ltrWithHebrew = 'alpha שלום gamma'; // Hebrew word at 6..10

Widget _view({
  required MarkdownSelectionController controller,
  required MarkdownDocument document,
  ui.TextDirection? textDirection,
  String documentId = 'doc',
  double width = 320,
}) {
  return MarkdownSelectionScope(
    controller: controller,
    child: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: SizedBox(
          width: width,
          child: MarkdownView(
            document: document,
            documentId: documentId,
            textDirection: textDirection,
            theme: MarkdownThemeData.fallback(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _geometryTests();
  _endpointTests();
  _structureTests();
  _codeBlockTests();

  group('selectWordAtGlobal steps back onto the pressed glyph (mock)', () {
    const text = 'abcd efgh ijkl'; // words at 0..4, 5..9, 10..14

    for (final direction in ui.TextDirection.values) {
      for (final fraction in <double>[0.1, 0.3, 0.5, 0.7, 0.9]) {
        test('${direction.name}: ${(fraction * 100).round()}% into the last '
            'letter of a word selects that word', () {
          final controller = MarkdownSelectionController();
          addTearDown(controller.dispose);
          controller.putDocument(
            MarkdownDocumentRef(id: 'doc', document: _doc([text])),
          );
          final surface = _LineSurface(
            documentId: 'doc',
            text: text,
            textDirection: direction,
          );
          controller.registerSurface(surface);

          // Index 8 is the "h" that ends "efgh"; index 9 is a space.
          expect(
            controller.selectWordAtGlobal(surface.inChar(8, fraction)),
            isTrue,
          );
          final sel = controller.normalizedSelection!;
          expect(
            (sel.start.offset, sel.end.offset),
            (5, 9),
            reason: 'pressed the last letter of "efgh"',
          );
        });

        test('${direction.name}: ${(fraction * 100).round()}% into the first '
            'letter of a word selects that word', () {
          final controller = MarkdownSelectionController();
          addTearDown(controller.dispose);
          controller.putDocument(
            MarkdownDocumentRef(id: 'doc', document: _doc([text])),
          );
          final surface = _LineSurface(
            documentId: 'doc',
            text: text,
            textDirection: direction,
          );
          controller.registerSurface(surface);

          expect(
            controller.selectWordAtGlobal(surface.inChar(5, fraction)),
            isTrue,
          );
          final sel = controller.normalizedSelection!;
          expect((sel.start.offset, sel.end.offset), (5, 9));
        });
      }

      test('${direction.name}: half a pixel inside the trailing edge of a '
          'word still selects that word', () {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);
        controller.putDocument(
          MarkdownDocumentRef(id: 'doc', document: _doc([text])),
        );
        final surface = _LineSurface(
          documentId: 'doc',
          text: text,
          textDirection: direction,
        );
        controller.registerSurface(surface);

        // 0.5px before the caret that follows "h" (advance is 10).
        expect(controller.selectWordAtGlobal(surface.inChar(8, 0.95)), isTrue);
        final sel = controller.normalizedSelection!;
        expect((sel.start.offset, sel.end.offset), (5, 9));
      });
    }
  });

  group('selectWordAtGlobal on rendered RTL text', () {
    Future<MarkdownSelectionController> pump(
      WidgetTester tester,
      String text,
      ui.TextDirection direction,
    ) async {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _testApp(
          child: _view(
            controller: controller,
            document: _doc([text]),
            textDirection: direction,
          ),
        ),
      );
      await tester.pump();
      return controller;
    }

    testWidgets('control: LTR text selects the pressed word at every '
        'fraction of a glyph', (tester) async {
      const text = 'alpha beta gamma';
      final controller = await pump(tester, text, ui.TextDirection.ltr);
      final p = _paragraph(tester, 'alpha');
      for (final fraction in <double>[0.1, 0.3, 0.5, 0.7, 0.9]) {
        for (final index in <int>[6, 9]) {
          controller.selectWordAtGlobal(_inGlyph(p, index, fraction));
          final sel = controller.normalizedSelection!;
          expect(
            (sel.start.offset, sel.end.offset),
            (6, 10),
            reason: 'glyph $index at $fraction',
          );
        }
      }
    });

    testWidgets('Hebrew text selects the pressed word at every fraction of '
        'a glyph', (tester) async {
      final controller = await pump(tester, _hebrew, ui.TextDirection.rtl);
      final p = _paragraph(tester, 'שלום');
      expect(p.textDirection, ui.TextDirection.rtl);
      // First and last letters of the middle word (5..9).
      for (final fraction in <double>[0.1, 0.3, 0.5, 0.7, 0.9]) {
        for (final index in <int>[5, 6, 8]) {
          controller.selectWordAtGlobal(_inGlyph(p, index, fraction));
          final sel = controller.normalizedSelection!;
          expect(
            (sel.start.offset, sel.end.offset),
            (5, 9),
            reason: 'glyph $index at $fraction from its left',
          );
        }
      }
    });

    testWidgets('a Latin word inside an RTL paragraph selects the pressed '
        'word', (tester) async {
      final controller = await pump(
        tester,
        _rtlWithLatin,
        ui.TextDirection.rtl,
      );
      final p = _paragraph(tester, 'hello');
      final failures = <String>[];
      for (final fraction in <double>[0.25, 0.75]) {
        for (final index in <int>[5, 7, 9]) {
          controller.selectWordAtGlobal(_inGlyph(p, index, fraction));
          final sel = controller.normalizedSelection!;
          if (sel.start.offset != 5 || sel.end.offset != 10) {
            failures.add(
              'glyph $index at $fraction -> '
              '${sel.start.offset}..${sel.end.offset}',
            );
          }
        }
      }
      expect(failures, isEmpty, reason: 'expected 5..10 ("hello")');
    });

    testWidgets('a Hebrew word inside an LTR paragraph selects the pressed '
        'word', (tester) async {
      final controller = await pump(
        tester,
        _ltrWithHebrew,
        ui.TextDirection.ltr,
      );
      final p = _paragraph(tester, 'alpha');
      final failures = <String>[];
      for (final fraction in <double>[0.25, 0.75]) {
        for (final index in <int>[6, 7, 9]) {
          controller.selectWordAtGlobal(_inGlyph(p, index, fraction));
          final sel = controller.normalizedSelection!;
          if (sel.start.offset != 6 || sel.end.offset != 10) {
            failures.add(
              'glyph $index at $fraction -> '
              '${sel.start.offset}..${sel.end.offset}',
            );
          }
        }
      }
      expect(failures, isEmpty, reason: 'expected 6..10 (the Hebrew word)');
    });

    testWidgets('a touch long-press on the trailing half of an RTL glyph '
        'selects the pressed word', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final controller = await pump(tester, _hebrew, ui.TextDirection.rtl);
        final p = _paragraph(tester, 'שלום');
        // Trailing half of an RTL glyph is its visual LEFT half. Index 8 is
        // the last letter of the middle word.
        final gesture = await tester.startGesture(
          _inGlyph(p, 8, 0.25),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(controller.getText(), 'עולם');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

Future<MarkdownSelectionController> _pumpParagraph(
  WidgetTester tester,
  String text,
  ui.TextDirection direction, {
  double width = 320,
}) async {
  final controller = MarkdownSelectionController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    _testApp(
      child: _view(
        controller: controller,
        document: _doc([text]),
        textDirection: direction,
        width: width,
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void _geometryTests() {
  group('RTL paragraph geometry', () {
    // The view is 320 wide with a 40px padding: it spans x = 40..360.
    testWidgets('RTL text starts at the right edge', (tester) async {
      await _pumpParagraph(tester, _hebrew, ui.TextDirection.rtl);
      final first = _glyph(_paragraph(tester, 'שלום'), 0);
      expect(first.right, moreOrLessEquals(360, epsilon: 0.5));
    });

    testWidgets('LTR text starts at the left edge', (tester) async {
      await _pumpParagraph(tester, 'alpha beta', ui.TextDirection.ltr);
      final first = _glyph(_paragraph(tester, 'alpha'), 0);
      expect(first.left, moreOrLessEquals(40, epsilon: 0.5));
    });

    testWidgets('offsets grow leftwards in RTL text', (tester) async {
      await _pumpParagraph(tester, _hebrew, ui.TextDirection.rtl);
      final p = _paragraph(tester, 'שלום');
      for (var i = 0; i + 1 < _hebrew.length; i++) {
        expect(
          _glyph(p, i + 1).center.dx,
          lessThan(_glyph(p, i).center.dx),
          reason: 'glyph ${i + 1} must sit left of glyph $i',
        );
      }
    });

    testWidgets('the right edge maps to the start of RTL text and the left '
        'edge to its end', (tester) async {
      final controller = await _pumpParagraph(
        tester,
        _hebrew,
        ui.TextDirection.rtl,
      );
      final p = _paragraph(tester, 'שלום');
      final y = _glyph(p, 0).center.dy;

      expect(
        controller.startAtGlobal(Offset(_glyph(p, 0).right - 0.5, y)),
        isTrue,
      );
      expect(controller.selection!.base, _pos('doc', 0, 0));

      final last = _glyph(p, _hebrew.length - 1);
      expect(controller.startAtGlobal(Offset(last.left + 0.5, y)), isTrue);
      expect(controller.selection!.base, _pos('doc', 0, _hebrew.length));
    });

    testWidgets('the highlight covers exactly the selected RTL glyphs', (
      tester,
    ) async {
      final controller = await _pumpParagraph(
        tester,
        _hebrew,
        ui.TextDirection.rtl,
      );
      final p = _paragraph(tester, 'שלום');
      controller.setSelection(
        MarkdownSelection(base: _pos('doc', 0, 5), extent: _pos('doc', 0, 9)),
      );
      await tester.pump();

      final rects = controller.globalSelectionRects();
      expect(rects, isNotEmpty);
      final union = rects.reduce((a, b) => a.expandToInclude(b));
      final expected = _glyph(p, 5).expandToInclude(_glyph(p, 8));
      expect(union.left, moreOrLessEquals(expected.left, epsilon: 0.5));
      expect(union.right, moreOrLessEquals(expected.right, epsilon: 0.5));
    });

    testWidgets('a mouse drag from the right edge leftwards selects the '
        'reading start', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final controller = await _pumpParagraph(
          tester,
          _hebrew,
          ui.TextDirection.rtl,
        );
        final p = _paragraph(tester, 'שלום');
        final from = _inGlyph(p, 0, 0.9);
        // Left quarter of glyph 3 = past its trailing edge side, so the
        // nearest caret is 4.
        final to = _inGlyph(p, 3, 0.25);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: from);
        await tester.pump();
        await mouse.down(from);
        await tester.pump();
        await mouse.moveTo(Offset.lerp(from, to, 0.5)!);
        await tester.pump();
        await mouse.moveTo(to);
        await tester.pump();
        await mouse.up();
        await tester.pump();

        expect(controller.getText(), 'שלום');
        final sel = controller.normalizedSelection!;
        expect((sel.start.offset, sel.end.offset), (0, 4));
        expect(controller.isSelectionReversed, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('extendToLineBreak stays on the visual line of wrapped RTL '
        'text', (tester) async {
      const long = 'אחת שתיים שלוש ארבע חמש שש שבע שמונה תשע עשר';
      final controller = await _pumpParagraph(
        tester,
        long,
        ui.TextDirection.rtl,
        width: 140,
      );
      final p = _paragraph(tester, 'אחת');
      final lineTops = <double>{
        for (var i = 0; i < long.length; i++)
          if (long[i] != ' ') _glyph(p, i).top,
      }.toList()..sort();
      expect(lineTops.length, greaterThan(2), reason: 'text must wrap');

      // Non-space offsets on the second visual line.
      final onSecond = <int>[
        for (var i = 0; i < long.length; i++)
          if (long[i] != ' ' && _glyph(p, i).top == lineTops[1]) i,
      ];
      final lineStart = onSecond.first;
      final lineEnd = onSecond.last + 1;
      final middle = onSecond[onSecond.length ~/ 2];

      controller.setSelection(
        MarkdownSelection.collapsed(_pos('doc', 0, middle)),
      );
      expect(controller.extendToLineBreak(forward: true), isTrue);
      expect(
        controller.selection!.extent.offset,
        anyOf(lineEnd, lineEnd + 1),
        reason: 'end of the second line (before or after the wrap space)',
      );
      expect(controller.selection!.base.offset, middle);

      controller.setSelection(
        MarkdownSelection.collapsed(_pos('doc', 0, middle)),
      );
      expect(controller.extendToLineBreak(forward: false), isTrue);
      expect(controller.selection!.extent.offset, lineStart);
    });

    testWidgets('half a pixel inside the trailing edge of the last letter '
        'of an RTL word still selects that word', (tester) async {
      final controller = await _pumpParagraph(
        tester,
        _hebrew,
        ui.TextDirection.rtl,
      );
      final p = _paragraph(tester, 'שלום');
      // Glyph 8 ends the middle word; its trailing edge is its visual left.
      final rect = _glyph(p, 8);
      controller.selectWordAtGlobal(Offset(rect.left + 0.5, rect.center.dy));
      final sel = controller.normalizedSelection!;
      expect((sel.start.offset, sel.end.offset), (5, 9));
    });

    testWidgets('control: half a pixel inside the trailing edge of the last '
        'letter of an LTR word selects that word', (tester) async {
      final controller = await _pumpParagraph(
        tester,
        'alpha beta gamma',
        ui.TextDirection.ltr,
      );
      final p = _paragraph(tester, 'alpha');
      final rect = _glyph(p, 9);
      controller.selectWordAtGlobal(Offset(rect.right - 0.5, rect.center.dy));
      final sel = controller.normalizedSelection!;
      expect((sel.start.offset, sel.end.offset), (6, 10));
    });
  });
}

void _endpointTests() {
  group('Handle endpoints follow reading order, not the screen side', () {
    testWidgets('the start endpoint of an RTL selection is on the right', (
      tester,
    ) async {
      final controller = await _pumpParagraph(
        tester,
        _hebrew,
        ui.TextDirection.rtl,
      );
      controller.setSelection(
        MarkdownSelection(base: _pos('doc', 0, 5), extent: _pos('doc', 0, 9)),
      );
      await tester.pump();

      final endpoints = controller.selectionHandleEndpoints()!;
      expect(endpoints.startLocalOffset, 5);
      expect(endpoints.endLocalOffset, 9);
      expect(endpoints.startGlobal!.dx, greaterThan(endpoints.endGlobal!.dx));
    });

    testWidgets('the start endpoint of an LTR selection is on the left', (
      tester,
    ) async {
      final controller = await _pumpParagraph(
        tester,
        'alpha beta gamma',
        ui.TextDirection.ltr,
      );
      controller.setSelection(
        MarkdownSelection(base: _pos('doc', 0, 6), extent: _pos('doc', 0, 10)),
      );
      await tester.pump();

      final endpoints = controller.selectionHandleEndpoints()!;
      expect(endpoints.startGlobal!.dx, lessThan(endpoints.endGlobal!.dx));
    });

    for (final direction in ui.TextDirection.values) {
      testWidgets('a reversed ${direction.name} selection reports the same '
          'endpoints as the forward one', (tester) async {
        final text = direction == ui.TextDirection.rtl
            ? _hebrew
            : 'alpha beta gamma';
        final controller = await _pumpParagraph(tester, text, direction);
        controller.setSelection(
          MarkdownSelection(base: _pos('doc', 0, 5), extent: _pos('doc', 0, 9)),
        );
        final forward = controller.selectionHandleEndpoints();
        expect(controller.isSelectionReversed, isFalse);

        controller.setSelection(
          MarkdownSelection(base: _pos('doc', 0, 9), extent: _pos('doc', 0, 5)),
        );
        expect(controller.isSelectionReversed, isTrue);
        expect(controller.selectionHandleEndpoints(), forward);
      });
    }

    testWidgets('touch handles of an RTL selection: start handle sits right '
        'of the end handle', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final controller = await _pumpParagraph(
          tester,
          _hebrew,
          ui.TextDirection.rtl,
        );
        final p = _paragraph(tester, 'שלום');
        final gesture = await tester.startGesture(
          _inGlyph(p, 6, 0.5),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.getText(), 'עולם');

        final start = find.byKey(MarkdownSelectionHandleOverlay.startHandleKey);
        final end = find.byKey(MarkdownSelectionHandleOverlay.endHandleKey);
        expect(start, findsOneWidget);
        expect(end, findsOneWidget);
        expect(
          tester.getCenter(start).dx,
          greaterThan(tester.getCenter(end).dx),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('each end of a mixed selection follows its own document', (
      tester,
    ) async {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _testApp(
          child: MarkdownSelectionScope(
            controller: controller,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MarkdownView(
                        document: _doc([_hebrew]),
                        documentId: 'a',
                        documentOrder: 0,
                        textDirection: ui.TextDirection.rtl,
                        theme: MarkdownThemeData.fallback(),
                      ),
                      MarkdownView(
                        document: _doc(['alpha beta gamma']),
                        documentId: 'b',
                        documentOrder: 1,
                        textDirection: ui.TextDirection.ltr,
                        theme: MarkdownThemeData.fallback(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.setSelection(
        MarkdownSelection(base: _pos('a', 0, 2), extent: _pos('b', 0, 3)),
      );
      await tester.pump();

      final endpoints = controller.selectionHandleEndpoints()!;
      final rtl = _paragraph(tester, 'שלום');
      final ltr = _paragraph(tester, 'alpha');
      // Caret 2 of the RTL document is the LEFT edge of its glyph 1.
      expect(
        endpoints.startGlobal!.dx,
        moreOrLessEquals(_glyph(rtl, 1).left, epsilon: 1.5),
      );
      // Caret 3 of the LTR document is the RIGHT edge of its glyph 2.
      expect(
        endpoints.endGlobal!.dx,
        moreOrLessEquals(_glyph(ltr, 2).right, epsilon: 1.5),
      );
      expect(controller.getText(), 'ום עולם טוב\n\nalp');
    });

    test('an RTL selection whose start surface is unmounted reports only '
        'the end endpoint', () {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      controller
        ..putDocument(
          MarkdownDocumentRef(id: 'a', order: 0, document: _doc([_hebrew])),
        )
        ..putDocument(
          MarkdownDocumentRef(id: 'b', order: 1, document: _doc([_hebrew])),
        );
      final visible = _LineSurface(
        documentId: 'b',
        text: _hebrew,
        textDirection: ui.TextDirection.rtl,
        origin: const Offset(0, 100),
      );
      controller.registerSurface(visible);
      controller.setSelection(
        MarkdownSelection(base: _pos('a', 0, 2), extent: _pos('b', 0, 4)),
      );

      final endpoints = controller.selectionHandleEndpoints()!;
      expect(endpoints.hasStart, isFalse);
      expect(endpoints.hasEnd, isTrue);
      expect(endpoints.endSurface, same(visible));
      expect(endpoints.endLocalOffset, 4);
      // Caret 4 of a 13-character RTL line: 9 advances from the left.
      expect(
        endpoints.endGlobal,
        const Offset(9 * _LineSurface.advance, 100 + _LineSurface.lineHeight),
      );
    });
  });
}

void _structureTests() {
  group('RTL structure', () {
    Future<MarkdownSelectionController> pumpMarkdown(
      WidgetTester tester,
      String markdown,
      ui.TextDirection direction, {
      double width = 320,
      String documentId = 'doc',
    }) async {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _testApp(
          child: MarkdownSelectionScope(
            controller: controller,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Align(
                  alignment: Alignment.topLeft,
                  widthFactor: 1,
                  child: SizedBox(
                    width: width,
                    child: MarkdownView(
                      data: markdown,
                      documentId: documentId,
                      textDirection: direction,
                      theme: MarkdownThemeData.fallback(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return controller;
    }

    testWidgets('copied text does not depend on the direction', (tester) async {
      const markdown =
          'פסקה עם [קישור](https://x.example) and **bold**\n\n'
          '- אחד\n- two\n\n'
          '| א | b |\n|---|---|\n| 1 | 2 |\n';
      final ltr = await pumpMarkdown(tester, markdown, ui.TextDirection.ltr);
      expect(ltr.selectAll(), isTrue);
      final ltrText = ltr.getText();
      final ltrMarkdown = ltr.getMarkdown();

      final rtl = await pumpMarkdown(tester, markdown, ui.TextDirection.rtl);
      expect(rtl.selectAll(), isTrue);

      expect(ltrText, contains('קישור'));
      expect(ltrText, contains('א\tb'));
      expect(rtl.getText(), ltrText);
      expect(rtl.getMarkdown(), ltrMarkdown);
    });

    testWidgets('RTL list item text sits left of a right-hand marker', (
      tester,
    ) async {
      await pumpMarkdown(tester, '- אחד\n- שתיים', ui.TextDirection.rtl);
      final item = _paragraph(tester, 'אחד');
      final bounds = item.globalBounds!;
      // View spans 40..360. The marker gutter is on the right.
      expect(bounds.left, moreOrLessEquals(40, epsilon: 0.5));
      expect(bounds.right, lessThan(360 - 4));
      expect(
        _glyph(item, 0).right,
        moreOrLessEquals(bounds.right, epsilon: 0.5),
      );
    });

    testWidgets('LTR list item text sits right of a left-hand marker', (
      tester,
    ) async {
      await pumpMarkdown(tester, '- one\n- two', ui.TextDirection.ltr);
      final bounds = _paragraph(tester, 'one').globalBounds!;
      expect(bounds.left, greaterThan(40 + 4));
    });

    testWidgets('an RTL table puts the first column on the right and maps '
        'presses to the mirrored cells', (tester) async {
      final controller = await pumpMarkdown(
        tester,
        '| ראשון | שני |\n|---|---|\n| 1 | 2 |',
        ui.TextDirection.rtl,
      );
      final first = _paragraph(tester, 'ראשון');
      final second = _paragraph(tester, 'שני');
      expect(
        first.globalBounds!.center.dx,
        greaterThan(second.globalBounds!.center.dx),
      );

      controller.selectWordAtGlobal(_inGlyph(second, 1, 0.5));
      expect(controller.getText(), 'שני');
      controller.selectWordAtGlobal(_inGlyph(first, 1, 0.5));
      expect(controller.getText(), 'ראשון');
    });

    for (final direction in ui.TextDirection.values) {
      for (final width in <double>[1, 24, 80]) {
        testWidgets('width $width ${direction.name} lays out, paints and '
            'selects without throwing', (tester) async {
          const markdown =
              '# כותרת\n\nפסקה with mixed text\n\n- אחד\n  - two\n\n'
              '> ציטוט\n\n| א | ב |\n|---|---|\n| 1 | 2 |\n\n'
              '```\ncode\n```\n';
          final controller = await pumpMarkdown(
            tester,
            markdown,
            direction,
            width: width,
          );
          controller.selectAll();
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(controller.getText(), contains('כותרת'));
        });
      }
    }

    testWidgets('an empty RTL document lays out to nothing and has nothing '
        'to select', (tester) async {
      final controller = await pumpMarkdown(tester, '', ui.TextDirection.rtl);
      expect(tester.takeException(), isNull);
      expect(controller.selectAll(), isFalse);
      expect(controller.hasSelection, isFalse);
      expect(tester.getSize(find.byType(MarkdownView)).height, 0);
    });
  });
}

void _codeBlockTests() {
  group('Code inside an RTL document', () {
    testWidgets('a fenced code block stays left-to-right', (tester) async {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _testApp(
          child: MarkdownSelectionScope(
            controller: controller,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: SizedBox(
                  width: 320,
                  child: MarkdownView(
                    data: 'פסקה\n\n```\nabc def;\n```\n',
                    documentId: 'doc',
                    textDirection: ui.TextDirection.rtl,
                    theme: MarkdownThemeData.fallback(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final prose = _paragraph(tester, 'פסקה');
      final code = _paragraph(tester, 'abc def');
      expect(prose.textDirection, ui.TextDirection.rtl);
      expect(code.textDirection, ui.TextDirection.ltr);
      // The trailing ";" must stay at the visual end of the line.
      expect(_glyph(code, 7).left, greaterThan(_glyph(code, 0).left));
    });
  });
}
