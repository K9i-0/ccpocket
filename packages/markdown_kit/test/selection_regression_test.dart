// Review tests for the selection engine. Each test asserts the CORRECT
// behaviour and is expected to FAIL until the referenced defect is fixed.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

Widget _testApp({required Widget child, Size size = const Size(420, 680)}) {
  return Directionality(
    textDirection: ui.TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: FocusScope(
        autofocus: true,
        child: _ReactiveOverlayShell(
          child: ColoredBox(color: const Color(0xFFFFFFFF), child: child),
        ),
      ),
    ),
  );
}

class _ReactiveOverlayShell extends StatefulWidget {
  const _ReactiveOverlayShell({required this.child});
  final Widget child;
  @override
  State<_ReactiveOverlayShell> createState() => _ReactiveOverlayShellState();
}

class _ReactiveOverlayShellState extends State<_ReactiveOverlayShell> {
  late final ValueNotifier<Widget> _childNotifier = ValueNotifier<Widget>(
    widget.child,
  );
  late final OverlayEntry _rootEntry = OverlayEntry(
    builder: (_) => ValueListenableBuilder<Widget>(
      valueListenable: _childNotifier,
      builder: (_, child, _) => child,
    ),
  );

  @override
  void didUpdateWidget(covariant _ReactiveOverlayShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _childNotifier.value = widget.child;
  }

  @override
  void dispose() {
    _childNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_rootEntry]);
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

Offset _rangeCenter(RenderSelectableParagraph p, int start, int end) {
  final boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  );
  expect(boxes, isNotEmpty);
  return p.localToGlobal(boxes.first.toRect().center);
}

Future<void> _longPress(WidgetTester tester, Offset at) async {
  final g = await tester.startGesture(at, kind: PointerDeviceKind.touch);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await g.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Widget _toolbar(BuildContext context, MarkdownSelectionScopeState state) {
  return const Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: 10, height: 10),
  );
}

const _style = TextStyle(fontSize: 16, height: 1.5);

void main() {
  // ---------------------------------------------------------------------------
  // BUG 1: selection_scope.dart:512-518 (_syncOverlay -> hideAll) +
  // selection_handles.dart:268-275 (hideAll removes the handle entry that owns
  // the active PanGestureRecognizer). When the selection is cleared by the
  // controller while a handle is being dragged, the recognizer is disposed
  // without onEnd/onCancel, so the scope never runs _onHandleDragEnd:
  // _isDraggingHandle stays true (toolbar suppressed for every later
  // selection) and the autoscroll Ticker keeps running forever.
  // ---------------------------------------------------------------------------
  testWidgets(
    'controller-side clear during a handle drag leaves no stuck drag state',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _testApp(
          child: MarkdownSelectionScope(
            controller: controller,
            contextMenuBuilder: _toolbar,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: MarkdownView(
                data: '',
                document: _doc(['alpha beta gamma delta', 'second paragraph']),
                documentId: 'doc',
                theme: MarkdownThemeData.fallback(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final para = _paragraph(tester, 'alpha');
      await _longPress(tester, _rangeCenter(para, 6, 10));
      // Control: harness works, toolbar and handles are shown.
      expect(controller.hasSelection, isTrue);
      expect(
        find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
        findsOneWidget,
      );
      expect(
        find.byKey(MarkdownSelectionHandleOverlay.endHandleKey),
        findsOneWidget,
      );

      expect(tester.binding.transientCallbackCount, 0); // control: idle

      // Start dragging the end handle.
      final handleCenter = tester.getCenter(
        find.byKey(MarkdownSelectionHandleOverlay.endHandleKey),
      );
      final drag = await tester.startGesture(
        handleCenter,
        kind: PointerDeviceKind.touch,
      );
      await drag.moveBy(const Offset(12, 0));
      await tester.pump();
      await drag.moveBy(const Offset(12, 0));
      await tester.pump();

      // Selection is cleared from the model side mid-drag (e.g. streaming
      // reconciliation returning null, or the host calling clear()).
      controller.clear();
      await tester.pump();
      await drag.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The autoscroll ticker must not keep running after the drag is gone.
      final transientAfter = tester.binding.transientCallbackCount;

      // A fresh long-press selection must show the toolbar again.
      await _longPress(
        tester,
        _rangeCenter(_paragraph(tester, 'alpha'), 6, 10),
      );
      expect(controller.hasSelection, isTrue);
      final toolbarShown = find
          .byKey(MarkdownSelectionHandleOverlay.toolbarKey)
          .evaluate()
          .isNotEmpty;

      debugDefaultTargetPlatformOverride = null;
      expect(
        transientAfter,
        0,
        reason: 'autoscroll ticker still active after orphaned handle drag',
      );
      expect(
        toolbarShown,
        isTrue,
        reason: '_isDraggingHandle stuck true suppresses the toolbar',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // BUG 2: selection_controller.dart:241-260. registerSurface /
  // unregisterSurface call notifyListeners() synchronously whenever a
  // selection is active. Surfaces attach/detach during build/layout/finalize,
  // so any listener that rebuilds (ListenableBuilder, setState) throws
  // "setState() or markNeedsBuild() called during build".
  // ---------------------------------------------------------------------------
  testWidgets(
    'mounting a surface while a selection is active does not notify during build',
    (tester) async {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);

      Widget build({required bool showSecond}) {
        return _testApp(
          child: Column(
            children: [
              // Typical host UI: e.g. a "copy" button enabled by selection.
              ListenableBuilder(
                listenable: controller,
                builder: (_, _) => SizedBox(
                  height: 10,
                  width: controller.hasSelection ? 20 : 10,
                ),
              ),
              Expanded(
                child: MarkdownSelectionScope(
                  controller: controller,
                  child: Column(
                    children: [
                      MarkdownView(
                        data: '',
                        document: _doc(['first document text']),
                        documentId: 'a',
                        theme: MarkdownThemeData.fallback(),
                        shrinkWrap: true,
                      ),
                      if (showSecond)
                        MarkdownView(
                          data: '',
                          document: _doc(['second document text']),
                          documentId: 'b',
                          documentOrder: 1,
                          theme: MarkdownThemeData.fallback(),
                          shrinkWrap: true,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }

      await tester.pumpWidget(build(showSecond: false));
      await tester.pump();
      controller.setSelection(
        const MarkdownSelection(
          base: MarkdownPosition(documentId: 'a', blockIndex: 0, offset: 0),
          extent: MarkdownPosition(documentId: 'a', blockIndex: 0, offset: 5),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull); // control
      expect(controller.hasSelection, isTrue);

      // A new bubble scrolls in / is appended while the selection is active.
      await tester.pumpWidget(build(showSecond: true));
      expect(tester.takeException(), isNull);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // BUG 4: selection_scope.dart:321-335 (didUpdateWidget). When the controller
  // is swapped, _lastNotifiedSelection is resynced but _hadSelection is not.
  // If the old controller had a selection and the new one has none, the next
  // selection on the new controller does not trigger setState, so the
  // tap-outside recognizer (only registered when hasSelection at build time,
  // :1509) and DismissIntent action (:1418) are never installed.
  // ---------------------------------------------------------------------------
  testWidgets(
    'tap outside clears selection after the scope controller was swapped',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final a = MarkdownSelectionController();
      final b = MarkdownSelectionController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      Widget build(MarkdownSelectionController c) => _testApp(
        child: MarkdownSelectionScope(
          controller: c,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: MarkdownView(
                data: '',
                document: _doc(['alpha beta gamma delta']),
                documentId: 'doc',
                theme: MarkdownThemeData.fallback(),
                shrinkWrap: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(a));
      await tester.pump();
      await _longPress(
        tester,
        _rangeCenter(_paragraph(tester, 'alpha'), 6, 10),
      );
      expect(a.hasSelection, isTrue);

      // Control: tap outside clears on the original controller.
      await tester.tapAt(const Offset(300, 500));
      await tester.pump(const Duration(milliseconds: 400));
      expect(a.hasSelection, isFalse);

      await _longPress(
        tester,
        _rangeCenter(_paragraph(tester, 'alpha'), 6, 10),
      );
      expect(a.hasSelection, isTrue);

      await tester.pumpWidget(build(b));
      await tester.pump();
      await tester.pump();
      expect(b.hasSelection, isFalse);

      await _longPress(
        tester,
        _rangeCenter(_paragraph(tester, 'alpha'), 6, 10),
      );
      expect(b.hasSelection, isTrue);

      await tester.tapAt(const Offset(300, 500));
      await tester.pump(const Duration(milliseconds: 400));
      final cleared = !b.hasSelection;
      debugDefaultTargetPlatformOverride = null;
      expect(cleared, isTrue);
    },
  );

  // ---------------------------------------------------------------------------
  // BUG 7: selection_controller.dart:313-318 (selectWordAtGlobal) uses the
  // caret position nearest to the touch (positionForGlobalOffset ->
  // getPositionForOffset, selectable_paragraph.dart:1536) and feeds it as a
  // downstream TextPosition to getWordBoundary. A press on the RIGHT half of a
  // glyph resolves to the caret after it, so the word AFTER the pressed glyph
  // is selected (next kanji on Japanese text; the space after a Latin word's
  // last letter).
  // ---------------------------------------------------------------------------
  // 0.25 (left half) passes today; only the right half is broken.
  for (final fraction in <double>[0.75]) {
    testWidgets(
      'long-press at ${(fraction * 100).round()}% of a glyph selects the pressed word',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);
        const jp = '今日は天気がいいので散歩に行きましょう';
        const en = 'alpha beta gamma';

        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: MarkdownView(
                    data: '',
                    document: _doc([jp, en]),
                    documentId: 'doc',
                    theme: MarkdownThemeData.fallback(),
                    shrinkWrap: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        Offset at(RenderSelectableParagraph p, int index) {
          final box = p
              .getBoxesForSelection(
                TextSelection(baseOffset: index, extentOffset: index + 1),
              )
              .first
              .toRect();
          return p.localToGlobal(
            Offset(box.left + box.width * fraction, box.center.dy),
          );
        }

        // English: press the final "a" of "beta" (index 9) -> "beta" = 6..10.
        await _longPress(tester, at(_paragraph(tester, 'alpha'), 9));
        final enSel = controller.normalizedSelection!;
        controller.clear();
        await tester.pump();

        // Japanese: press glyph 3 ("天"); the selection must contain it.
        await _longPress(tester, at(_paragraph(tester, '今日'), 3));
        final jpSel = controller.normalizedSelection!;

        final jpOk = jpSel.start.offset <= 3 && jpSel.end.offset >= 4;
        final enOk = enSel.start.offset == 6 && enSel.end.offset == 10;
        expect(
          (japaneseContainsPressedGlyph: jpOk, englishSelectsBeta: enOk),
          (japaneseContainsPressedGlyph: true, englishSelectsBeta: true),
          reason:
              'jp pressed glyph 3, selected '
              '${jpSel.start.offset}..${jpSel.end.offset}; en pressed index 9, '
              'selected ${enSel.start.offset}..${enSel.end.offset}',
        );
      },
    );
  }

  testWidgets(
    'long-press on the trailing half of the last glyph of a wrapped line stays on that glyph',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      const jp = '今日は天気がいいので散歩に行きましょうそして買い物もします';

      await tester.pumpWidget(
        _testApp(
          child: MarkdownSelectionScope(
            controller: controller,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                child: MarkdownView(
                  data: '',
                  document: _doc([jp]),
                  documentId: 'doc',
                  theme: MarkdownThemeData.fallback(),
                  shrinkWrap: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final paragraph = _paragraph(tester, '今日');
      Rect boxAt(int index) => paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: index, extentOffset: index + 1),
          )
          .first
          .toRect();
      final firstLineTop = boxAt(0).top;
      var lastOnFirstLine = 0;
      while (boxAt(lastOnFirstLine + 1).top == firstLineTop) {
        lastOnFirstLine++;
      }
      expect(lastOnFirstLine, lessThan(jp.length - 2), reason: 'must wrap');

      final box = boxAt(lastOnFirstLine);
      await _longPress(
        tester,
        paragraph.localToGlobal(
          Offset(box.left + box.width * 0.75, box.center.dy),
        ),
      );
      final selection = controller.normalizedSelection!;
      expect(
        selection.start.offset <= lastOnFirstLine &&
            selection.end.offset >= lastOnFirstLine + 1,
        isTrue,
        reason:
            'pressed glyph $lastOnFirstLine, selected '
            '${selection.start.offset}..${selection.end.offset}',
      );
    },
  );

  testWidgets(
    'long-press on the trailing half of an emoji selects the whole emoji',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      const family = '👨‍👩‍👧';
      const text = 'ab $family cd 😀 ef';

      await tester.pumpWidget(
        _testApp(
          child: MarkdownSelectionScope(
            controller: controller,
            child: Align(
              alignment: Alignment.topLeft,
              child: MarkdownView(
                data: '',
                document: _doc([text]),
                documentId: 'doc',
                theme: MarkdownThemeData.fallback(),
                shrinkWrap: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final paragraph = _paragraph(tester, 'ab');
      for (final emoji in [family, '😀']) {
        final start = text.indexOf(emoji);
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + emoji.length),
        );
        final box = boxes.last.toRect();
        await _longPress(
          tester,
          paragraph.localToGlobal(
            Offset(box.left + box.width * 0.75, box.center.dy),
          ),
        );
        expect(controller.getText(), emoji);
        controller.clear();
        await tester.pump();
      }
    },
  );

  // ---------------------------------------------------------------------------
  // BUG 5 (low, desktop keyboard only): selection_controller.dart:1449-1457.
  // _isWordCodeUnit treats every code unit >= 0x80 as a word character, so
  // CJK punctuation (、。「」 etc.) never terminates a word and
  // Shift+Alt/Ctrl+Arrow jumps across whole Japanese sentences.
  // ---------------------------------------------------------------------------
  test('extendByWord stops at Japanese punctuation', () {
    final controller = MarkdownSelectionController();
    addTearDown(controller.dispose);
    const text = '日本語、テスト。 next';
    controller.putDocument(
      MarkdownDocumentRef(id: 'd', document: _doc([text])),
    );
    controller.setSelection(
      const MarkdownSelection.collapsed(
        MarkdownPosition(documentId: 'd', blockIndex: 0, offset: 0),
      ),
    );
    controller.extendByWord(forward: true);
    expect(controller.selection!.extent.offset, lessThanOrEqualTo(3));
  });

  // ---------------------------------------------------------------------------
  // BUG 6 (low): selection_scope.dart:231-237. copySelection awaits the
  // clipboard and then calls hideToolbar(), which writes
  // controller.toolbarWanted on a controller that may have been disposed while
  // the platform call was in flight (scope unmounted) -> ChangeNotifier
  // used-after-dispose assertion.
  // ---------------------------------------------------------------------------
  testWidgets('copySelection completing after unmount does not throw', (
    tester,
  ) async {
    final clipboardGate = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          await clipboardGate.future;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    late MarkdownSelectionScopeState state;
    await tester.pumpWidget(
      _testApp(
        child: MarkdownSelectionScope(
          contextMenuBuilder: _toolbar,
          child: Builder(
            builder: (context) {
              state = MarkdownSelectionScope.stateOf(context);
              return const SelectablePlainText(
                'hello world',
                style: _style,
                documentId: 'doc',
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final controller = state.controller;
    expect(controller.selectAll(), isTrue);
    state.showToolbar();
    await tester.pump();
    expect(state.toolbarIsVisible, isTrue); // control

    Object? error;
    final future = state.copySelection().catchError((Object e) {
      error = e;
    });
    await tester.pumpWidget(const SizedBox());
    clipboardGate.complete();
    await future;
    await tester.pump();
    expect(error, isNull);
    expect(tester.takeException(), isNull);
  });
}
