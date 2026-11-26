import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:markdown_kit/src/selection/selection_autoscroll.dart';
import 'package:markdown_kit/src/selection/selection_controller.dart';
import 'package:markdown_kit/src/selection/selection_handles.dart';
import 'package:markdown_kit/src/selection/selection_scope.dart';

/// Minimal `RenderParagraph`-backed [MarkdownSelectionSurface] widget used to
/// exercise real layout, hit-testing, `LeaderLayer` handle tracking, and
/// `ListView` scrolling in widget tests without depending on Step 3 renderers.
class _TestSelectableParagraph extends LeafRenderObjectWidget {
  const _TestSelectableParagraph({
    required this.documentId,
    required this.blockIndex,
    required this.text,
    required this.controller,
  });

  final String documentId;
  final int blockIndex;
  final String text;
  final MarkdownSelectionController controller;

  static const TextStyle _defaultStyle = TextStyle(fontSize: 16, height: 1.5);

  @override
  _RenderTestSelectableParagraph createRenderObject(BuildContext context) {
    return _RenderTestSelectableParagraph(
      documentId: documentId,
      blockIndex: blockIndex,
      textOffsetInBlock: 0,
      rawText: text,
      controller: controller,
      text: TextSpan(text: text, style: _defaultStyle),
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTestSelectableParagraph renderObject,
  ) {
    renderObject
      ..documentId = documentId
      ..blockIndex = blockIndex
      ..textOffsetInBlock = 0
      ..rawText = text
      ..controller = controller
      ..text = TextSpan(text: text, style: _defaultStyle)
      ..textDirection = Directionality.of(context);
  }
}

class _RenderTestSelectableParagraph extends RenderParagraph
    implements MarkdownSelectionSurface {
  _RenderTestSelectableParagraph({
    required this.documentId,
    required this.blockIndex,
    required this.textOffsetInBlock,
    required this.rawText,
    required MarkdownSelectionController controller,
    required InlineSpan text,
    required super.textDirection,
  }) : _controller = controller,
       super(text);

  @override
  String documentId;

  @override
  int blockIndex;

  @override
  int textOffsetInBlock;

  String rawText;

  MarkdownSelectionController _controller;
  set controller(MarkdownSelectionController value) {
    if (_controller == value) return;
    if (attached) {
      _controller.unregisterSurface(this);
    }
    _controller = value;
    if (attached) {
      _controller.registerSurface(this);
    }
  }

  TextRange? _highlightRange;
  LayerLink? _startHandleLayerLink;
  int? _startHandleLocalOffset;
  LayerLink? _endHandleLayerLink;
  int? _endHandleLocalOffset;

  @override
  int get textLength => rawText.length;

  @override
  Rect? get globalBounds {
    if (!attached || !hasSize) return null;
    final origin = localToGlobal(Offset.zero);
    return origin & size;
  }

  @override
  bool get hasSelectionHandleLeaders =>
      _startHandleLayerLink != null || _endHandleLayerLink != null;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.registerSurface(this);
  }

  @override
  void detach() {
    _controller.unregisterSurface(this);
    super.detach();
  }

  @override
  bool hitsTextAtGlobal(Offset globalOffset) {
    final bounds = globalBounds;
    if (bounds == null || !bounds.contains(globalOffset)) return false;
    final local = globalToLocal(globalOffset);
    final boxes = getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: rawText.length),
    );
    for (final box in boxes) {
      if (box.toRect().inflate(2.0).contains(local)) return true;
    }
    return false;
  }

  @override
  MarkdownPosition positionForGlobalOffset(Offset globalOffset) {
    final local = globalToLocal(globalOffset);
    final pos = getPositionForOffset(local);
    final clamped = pos.offset.clamp(0, rawText.length);
    return MarkdownPosition(
      documentId: documentId,
      blockIndex: blockIndex,
      offset: textOffsetInBlock + clamped,
    );
  }

  @override
  TextRange wordRangeAtLocal(int localOffset) {
    final clamped = localOffset.clamp(0, rawText.length);
    return getWordBoundary(TextPosition(offset: clamped));
  }

  @override
  TextRange lineRangeAtLocal(int localOffset) {
    final clamped = localOffset.clamp(0, rawText.length);
    final prevNl = clamped > 0 ? rawText.lastIndexOf('\n', clamped - 1) : -1;
    final nextNl = rawText.indexOf('\n', clamped);
    return TextRange(
      start: prevNl >= 0 ? prevNl + 1 : 0,
      end: nextNl >= 0 ? nextNl : rawText.length,
    );
  }

  @override
  List<TextBox> boxesForLocalRange(int start, int end) {
    final s = start.clamp(0, rawText.length);
    final e = end.clamp(s, rawText.length);
    if (e <= s) return const [];
    return getBoxesForSelection(TextSelection(baseOffset: s, extentOffset: e));
  }

  @override
  Rect caretRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) {
    final clamped = offset.clamp(0, rawText.length);
    final pos = TextPosition(offset: clamped, affinity: affinity);
    final caretOffset = getOffsetForCaret(pos, Rect.zero);
    final height = getFullHeightForCaret(pos);
    return Rect.fromLTWH(caretOffset.dx, caretOffset.dy, 2.0, height);
  }

  @override
  Rect? globalRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) {
    if (!attached || !hasSize) return null;
    final localRect = caretRectForLocalOffset(offset, affinity: affinity);
    final topLeft = localToGlobal(localRect.topLeft);
    return topLeft & localRect.size;
  }

  @override
  void setSelectionHighlightRange(TextRange? range) {
    if (_highlightRange == range) return;
    _highlightRange = range;
    if (attached) markNeedsPaint();
  }

  @override
  void setSelectionHandleLayers({
    LayerLink? startHandleLayerLink,
    int? startHandleLocalOffset,
    LayerLink? endHandleLayerLink,
    int? endHandleLocalOffset,
  }) {
    if (startHandleLayerLink != null) {
      _startHandleLayerLink = startHandleLayerLink;
      _startHandleLocalOffset = startHandleLocalOffset;
    }
    if (endHandleLayerLink != null) {
      _endHandleLayerLink = endHandleLayerLink;
      _endHandleLocalOffset = endHandleLocalOffset;
    }
    if (attached) markNeedsPaint();
  }

  @override
  void clearSelectionHandleLayersIfLinked({
    LayerLink? startHandleLayerLink,
    LayerLink? endHandleLayerLink,
  }) {
    var changed = false;
    if (startHandleLayerLink != null &&
        _startHandleLayerLink == startHandleLayerLink) {
      _startHandleLayerLink = null;
      _startHandleLocalOffset = null;
      changed = true;
    }
    if (endHandleLayerLink != null &&
        _endHandleLayerLink == endHandleLayerLink) {
      _endHandleLayerLink = null;
      _endHandleLocalOffset = null;
      changed = true;
    }
    if (changed && attached) {
      markNeedsPaint();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final range = _highlightRange;
    if (range != null && range.isValid && !range.isCollapsed) {
      final paint = Paint()..color = const Color(0x55007AFF);
      for (final box in boxesForLocalRange(range.start, range.end)) {
        context.canvas.drawRect(box.toRect().shift(offset), paint);
      }
    }

    super.paint(context, offset);

    if (_startHandleLayerLink != null && _startHandleLocalOffset != null) {
      final caretRect = caretRectForLocalOffset(
        _startHandleLocalOffset!,
        affinity: TextAffinity.downstream,
      );
      context.pushLayer(
        LeaderLayer(
          link: _startHandleLayerLink!,
          offset: offset + caretRect.bottomLeft,
        ),
        (PaintingContext _, Offset _) {},
        Offset.zero,
      );
    }
    if (_endHandleLayerLink != null && _endHandleLocalOffset != null) {
      final caretRect = caretRectForLocalOffset(
        _endHandleLocalOffset!,
        affinity: TextAffinity.upstream,
      );
      context.pushLayer(
        LeaderLayer(
          link: _endHandleLayerLink!,
          offset: offset + caretRect.bottomLeft,
        ),
        (PaintingContext _, Offset _) {},
        Offset.zero,
      );
    }
  }
}

/// Minimal `widgets.dart`-only app shell providing [Directionality],
/// [MediaQuery], [Overlay], and [FocusScope] without `material.dart`.
Widget _testApp({required Widget child}) {
  return Directionality(
    textDirection: ui.TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(400, 600)),
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

Widget _buildToolbar(BuildContext context, MarkdownSelectionScopeState state) {
  return Stack(
    children: [
      Positioned(
        left: 20,
        top: 20,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              key: const ValueKey<String>('toolbar_copy'),
              onTap: state.copySelection,
              child: const SizedBox(width: 60, height: 32, child: Text('Copy')),
            ),
            GestureDetector(
              key: const ValueKey<String>('toolbar_copy_md'),
              onTap: state.copySelectionAsMarkdown,
              child: const SizedBox(
                width: 80,
                height: 32,
                child: Text('Copy MD'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

void main() {
  group('Autoscroll session & AxisDirection.up unit tests', () {
    test(
      'disarms per direction at scroll boundary until pointer exits edge band',
      () {
        var pixels = 0.0;
        const maxExtent = 50.0;
        final target = MarkdownCallbackAutoscrollTarget(
          viewportProvider: () => const MarkdownAutoscrollViewport(
            rect: Rect.fromLTWH(0, 0, 400, 600),
          ),
          canScrollUpCallback: () => pixels > 0,
          canScrollDownCallback: () => pixels < maxExtent,
          onScrollVisualDelta: (dy) {
            final before = pixels;
            pixels = (pixels + dy).clamp(0.0, maxExtent);
            return pixels - before;
          },
        );
        final session = MarkdownAutoscrollSession();

        // Pointer in top band when already at pixels == 0 -> disarms up immediately.
        expect(
          applyMarkdownSelectionAutoscroll(
            target: target,
            session: session,
            globalPointer: const Offset(100, 10),
            dt: const Duration(milliseconds: 50),
          ),
          0.0,
        );
        expect(session.isUpDisarmed, isTrue);

        // Drag down into bottom band -> scrolls down to maxExtent and disarms down.
        final d1 = applyMarkdownSelectionAutoscroll(
          target: target,
          session: session,
          globalPointer: const Offset(100, 595),
          dt: const Duration(milliseconds: 100),
        );
        expect(d1, greaterThan(0));
        expect(pixels, maxExtent);
        expect(session.isDownDisarmed, isTrue);
        // Up was re-armed because pointer left the top band.
        expect(session.isUpDisarmed, isFalse);

        // Even if maxExtent grew or content shifted, down remains disarmed while
        // still inside the bottom band.
        pixels = 20.0;
        expect(
          applyMarkdownSelectionAutoscroll(
            target: target,
            session: session,
            globalPointer: const Offset(100, 595),
            dt: const Duration(milliseconds: 50),
          ),
          0.0,
        );

        // Move pointer out of bottom band -> re-arms down.
        expect(
          applyMarkdownSelectionAutoscroll(
            target: target,
            session: session,
            globalPointer: const Offset(100, 300),
            dt: const Duration(milliseconds: 50),
          ),
          0.0,
        );
        expect(session.isDownDisarmed, isFalse);

        // Re-entering bottom band now scrolls again.
        final d2 = applyMarkdownSelectionAutoscroll(
          target: target,
          session: session,
          globalPointer: const Offset(100, 590),
          dt: const Duration(milliseconds: 50),
        );
        expect(d2, greaterThan(0));
      },
    );
  });

  group('Opaque low-slop handles & ListView gesture isolation', () {
    for (final platform in const [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets(
        'handle drag after 150ms pause moves selection without scrolling ListView ($platform)',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() {
            debugDefaultTargetPlatformOverride = null;
          });

          final scrollController = ScrollController();
          addTearDown(scrollController.dispose);

          final controller = MarkdownSelectionController();
          addTearDown(controller.dispose);

          final paragraphs = List<String>.generate(
            20,
            (i) => 'Line $i alpha beta gamma delta epsilon',
          );
          controller.putDocument(
            MarkdownDocumentRef(
              id: 'doc',
              document: MarkdownDocument(
                blocks: [
                  for (final p in paragraphs)
                    ParagraphBlock(inlines: [TextInline(p)]),
                ],
              ),
            ),
          );

          await tester.pumpWidget(
            _testApp(
              child: MarkdownSelectionScope(
                controller: controller,
                contextMenuBuilder: _buildToolbar,
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: paragraphs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: _TestSelectableParagraph(
                      documentId: 'doc',
                      blockIndex: index,
                      text: paragraphs[index],
                      controller: controller,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Long-press on Line 1 to start selection and show handles + toolbar.
          final line1Finder = find.byWidgetPredicate(
            (w) => w is _TestSelectableParagraph && w.blockIndex == 1,
          );
          final line1Rect = tester.getRect(line1Finder);
          final longPressTarget = Offset(
            line1Rect.left + 80,
            line1Rect.center.dy,
          );

          final lpGesture = await tester.startGesture(longPressTarget);
          await tester.pump(
            kLongPressTimeout + const Duration(milliseconds: 50),
          );
          expect(controller.hasSelection, isTrue);
          expect(
            find.byKey(MarkdownSelectionHandleOverlay.magnifierKey),
            findsOneWidget,
          );
          await lpGesture.up();
          await tester.pumpAndSettle();

          final initialText = controller.getText();
          expect(initialText, isNotEmpty);
          expect(
            find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
            findsOneWidget,
          );
          expect(
            find.byKey(MarkdownSelectionHandleOverlay.endHandleKey),
            findsOneWidget,
          );
          expect(
            find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
            findsOneWidget,
          );

          // Verify hit box meets minimum 44x44 logical pixel size.
          final endHandleRect = tester.getRect(
            find.byKey(MarkdownSelectionHandleOverlay.endHandleKey),
          );
          expect(endHandleRect.width, greaterThanOrEqualTo(44.0));
          expect(endHandleRect.height, greaterThanOrEqualTo(44.0));

          // CRITICAL REGRESSION: touch end handle, pause 150ms (past kPressTimeout),
          // drag vertically 60px downward. Handle MUST capture drag, extend selection,
          // NOT scroll ListView, and keep selection active!
          final scrollBefore = scrollController.offset;
          final handleGesture = await tester.startGesture(endHandleRect.center);
          await tester.pump(const Duration(milliseconds: 150));
          await handleGesture.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 16));
          await handleGesture.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 16));
          await handleGesture.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 16));
          await handleGesture.up();
          await tester.pumpAndSettle();

          expect(scrollController.offset, scrollBefore);
          expect(controller.hasSelection, isTrue);
          expect(controller.getText().length, greaterThan(initialText.length));
          expect(
            find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets(
      'dragging outside handle after 150ms pause scrolls ListView AND keeps selection active',
      (tester) async {
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);

        final paragraphs = List<String>.generate(
          30,
          (i) => 'Paragraph $i with enough text to scroll freely',
        );
        controller.putDocument(
          MarkdownDocumentRef(
            id: 'doc',
            document: MarkdownDocument(
              blocks: [
                for (final p in paragraphs)
                  ParagraphBlock(inlines: [TextInline(p)]),
              ],
            ),
          ),
        );

        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              contextMenuBuilder: _buildToolbar,
              child: ListView.builder(
                controller: scrollController,
                itemCount: paragraphs.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: _TestSelectableParagraph(
                    documentId: 'doc',
                    blockIndex: index,
                    text: paragraphs[index],
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Long-press on Paragraph 0 to create an active selection.
        final p0Rect = tester.getRect(
          find.byWidgetPredicate(
            (w) => w is _TestSelectableParagraph && w.blockIndex == 0,
          ),
        );
        final lp = await tester.startGesture(
          Offset(p0Rect.left + 40, p0Rect.center.dy),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await lp.up();
        await tester.pumpAndSettle();

        final selectedBeforeScroll = controller.getText();
        expect(selectedBeforeScroll, 'Paragraph');

        // Touch well outside handles (lower area of viewport), pause 150ms,
        // and drag upward by 120px to scroll ListView down.
        final drag = await tester.startGesture(const Offset(320, 420));
        await tester.pump(const Duration(milliseconds: 150));
        await drag.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 16));
        await drag.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 16));
        await drag.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 16));
        await drag.up();
        await tester.pumpAndSettle();

        expect(scrollController.offset, greaterThan(50.0));
        expect(controller.hasSelection, isTrue);
        expect(controller.getText(), selectedBeforeScroll);

        // Tap outside selection clears it cleanly.
        await tester.tapAt(const Offset(350, 450));
        await tester.pumpAndSettle();
        expect(controller.hasSelection, isFalse);
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
          findsNothing,
        );
      },
    );

    testWidgets(
      'ListView(reverse: true) edge autoscroll during handle drag scrolls list and extends selection',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });

        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        final controller = MarkdownSelectionController(
          allowCrossDocumentSelection: true,
        );
        addTearDown(controller.dispose);

        // Chat-style reverse list: index 0 is newest at bottom, index 24 is oldest at top.
        const count = 25;
        final texts = List<String>.generate(
          count,
          (i) => 'Message $i selectable line content',
        );
        for (var i = 0; i < count; i++) {
          controller.putDocument(
            MarkdownDocumentRef(
              id: 'msg-$i',
              // Older messages have smaller reading order (top -> bottom).
              order: count - 1 - i,
              document: MarkdownDocument(
                blocks: [
                  ParagraphBlock(inlines: [TextInline(texts[i])]),
                ],
              ),
            ),
          );
        }

        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              autoscroll: const MarkdownSelectionAutoscrollConfig(
                edgeZone: 60.0,
                maxVelocity: 800.0,
                useMediaQueryPadding: false,
              ),
              contextMenuBuilder: _buildToolbar,
              child: ListView.builder(
                controller: scrollController,
                reverse: true,
                itemCount: count,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: _TestSelectableParagraph(
                    documentId: 'msg-$index',
                    blockIndex: 0,
                    text: texts[index],
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(scrollController.offset, 0.0);

        // Long-press on msg-2 near the bottom of the reverse list.
        final msg2Rect = tester.getRect(
          find.byWidgetPredicate(
            (w) => w is _TestSelectableParagraph && w.documentId == 'msg-2',
          ),
        );
        final lp = await tester.startGesture(
          Offset(msg2Rect.left + 40, msg2Rect.center.dy),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await lp.up();
        await tester.pumpAndSettle();

        expect(controller.hasSelection, isTrue);
        final initialSelected = controller.getText();
        final startHandleRect = tester.getRect(
          find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
        );

        // Drag start handle into the TOP edge autoscroll band (y = 10) and hold
        // across multiple ticks so AxisDirection.up autoscroll increases pixels!
        final handleDrag = await tester.startGesture(startHandleRect.center);
        await tester.pump(const Duration(milliseconds: 50));
        await handleDrag.moveTo(const Offset(100, 10));
        for (var tick = 0; tick < 12; tick++) {
          await tester.pump(const Duration(milliseconds: 32));
        }
        await handleDrag.up();
        await tester.pumpAndSettle();

        expect(scrollController.offset, greaterThan(50.0));
        expect(controller.hasSelection, isTrue);
        expect(
          controller.getText().length,
          greaterThan(initialSelected.length),
        );
      },
    );

    testWidgets(
      'iOS tapping inside active selection toggles toolbar visibility',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });

        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);
        controller.putDocument(
          const MarkdownDocumentRef(
            id: 'd1',
            document: MarkdownDocument(
              blocks: [
                ParagraphBlock(inlines: [TextInline('Toggle toolbar text')]),
              ],
            ),
          ),
        );

        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              contextMenuBuilder: _buildToolbar,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 100, left: 20),
                  child: _TestSelectableParagraph(
                    documentId: 'd1',
                    blockIndex: 0,
                    text: 'Toggle toolbar text',
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pRect = tester.getRect(find.byType(_TestSelectableParagraph));
        final lp = await tester.startGesture(
          Offset(pRect.left + 80, pRect.center.dy),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await lp.up();
        await tester.pumpAndSettle();

        expect(
          find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
          findsOneWidget,
        );

        // Tap inside active selection -> hides toolbar while keeping selection.
        final selectionRect = controller.globalSelectionRects().first;
        await tester.tapAt(selectionRect.center);
        await tester.pumpAndSettle();
        expect(controller.hasSelection, isTrue);
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
          findsNothing,
        );

        // Tap inside again -> restores toolbar.
        await tester.tapAt(selectionRect.center);
        await tester.pumpAndSettle();
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
          findsOneWidget,
        );
      },
    );
  });

  group('Desktop mouse & keyboard selection', () {
    testWidgets(
      'supports mouse drag, double-click, triple-click, right-click menu, Cmd/Ctrl+C, and Esc',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });

        String? copiedClipboardText;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                final args = call.arguments as Map<Object?, Object?>;
                copiedClipboardText = args['text'] as String?;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);
        controller.putDocument(
          const MarkdownDocumentRef(
            id: 'd1',
            document: MarkdownDocument(
              blocks: [
                HeadingBlock(
                  level: 2,
                  inlines: [TextInline('Alpha Beta Gamma')],
                ),
                ParagraphBlock(inlines: [TextInline('Second line words')]),
              ],
            ),
          ),
        );

        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              contextMenuBuilder: _buildToolbar,
              child: Padding(
                padding: const EdgeInsets.only(top: 80, left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TestSelectableParagraph(
                      documentId: 'd1',
                      blockIndex: 0,
                      text: 'Alpha Beta Gamma',
                      controller: controller,
                    ),
                    const SizedBox(height: 12),
                    _TestSelectableParagraph(
                      documentId: 'd1',
                      blockIndex: 1,
                      text: 'Second line words',
                      controller: controller,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final b0Rect = tester.getRect(
          find.byWidgetPredicate(
            (w) => w is _TestSelectableParagraph && w.blockIndex == 0,
          ),
        );

        // 1. Mouse click-drag character selection.
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: Offset(b0Rect.left + 2, b0Rect.center.dy),
        );
        await tester.pump();
        await mouse.down(Offset(b0Rect.left + 2, b0Rect.center.dy));
        await tester.pump();
        await mouse.moveTo(Offset(b0Rect.left + 85, b0Rect.center.dy));
        await tester.pump();
        await mouse.up();
        await tester.pumpAndSettle();

        expect(controller.hasSelection, isTrue);
        final draggedText = controller.getText();
        expect(draggedText, isNotEmpty);
        // Desktop mouse selection does not show mobile touch handles.
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
          findsNothing,
        );

        // 2. Cmd+C copies plain text to clipboard.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();
        expect(copiedClipboardText, draggedText);

        // 3. Escape clears selection.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(controller.hasSelection, isFalse);

        // 4. Double-click selects word ("Alpha").
        final clickPoint = Offset(b0Rect.left + 18, b0Rect.center.dy);
        await mouse.down(clickPoint);
        await mouse.up();
        await tester.pump(const Duration(milliseconds: 50));
        await mouse.down(clickPoint);
        await mouse.up();
        await tester.pumpAndSettle();
        expect(controller.getText(), 'Alpha');

        // Wait past double-tap timeout before triple-click sequence.
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));

        // 5. Triple-click selects entire block ("Alpha Beta Gamma").
        for (var i = 0; i < 3; i++) {
          await mouse.down(clickPoint);
          await mouse.up();
          await tester.pump(const Duration(milliseconds: 40));
        }
        await tester.pumpAndSettle();
        expect(controller.getText(), 'Alpha Beta Gamma');

        // 6. Right-click shows context menu & "Copy MD" copies reconstructed Markdown.
        final rightMouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await rightMouse.down(clickPoint);
        await rightMouse.up();
        await tester.pumpAndSettle();
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey<String>('toolbar_copy_md')));
        await tester.pumpAndSettle();
        expect(copiedClipboardText, '## Alpha Beta Gamma');

        // 7. Cmd+A selects all blocks.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();
        expect(controller.getText(), 'Alpha Beta Gamma\n\nSecond line words');

        // 8. Shift+Click extends from a single-click anchor.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(controller.hasSelection, isFalse);

        final anchorPoint = Offset(b0Rect.left + 2, b0Rect.center.dy);
        await mouse.down(anchorPoint);
        await mouse.up();
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await mouse.down(Offset(b0Rect.left + 85, b0Rect.center.dy));
        await mouse.up();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(controller.hasSelection, isTrue);
        expect(controller.getText(), startsWith('Alpha'));
      },
    );

    testWidgets(
      'long-press drag extends by word, scroll off-screen hides/restores toolbar, and canStartSelectionAt blocks',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });

        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);

        final paragraphs = List<String>.generate(
          30,
          (i) => 'Word$i Alpha Beta Gamma Delta',
        );
        controller.putDocument(
          MarkdownDocumentRef(
            id: 'doc',
            document: MarkdownDocument(
              blocks: [
                for (final p in paragraphs)
                  ParagraphBlock(inlines: [TextInline(p)]),
              ],
            ),
          ),
        );

        var allowStart = false;
        MarkdownSelection? latestSelection;
        var parentDismissed = false;
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _testApp(
            child: Actions(
              actions: <Type, Action<Intent>>{
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) {
                    parentDismissed = true;
                    return null;
                  },
                ),
              },
              child: MarkdownSelectionScope(
                controller: controller,
                focusNode: focusNode,
                contextMenuBuilder: _buildToolbar,
                canStartSelectionAt: (_) => allowStart,
                onSelectionChanged: (sel) => latestSelection = sel,
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: paragraphs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: _TestSelectableParagraph(
                      documentId: 'doc',
                      blockIndex: index,
                      text: paragraphs[index],
                      controller: controller,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final p0Rect = tester.getRect(
          find.byWidgetPredicate(
            (w) => w is _TestSelectableParagraph && w.blockIndex == 0,
          ),
        );

        // When canStartSelectionAt returns false, long-press does not select.
        final blockedLp = await tester.startGesture(
          Offset(p0Rect.left + 20, p0Rect.center.dy),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await blockedLp.up();
        await tester.pumpAndSettle();
        expect(controller.hasSelection, isFalse);

        // Escape bubbles to parent DismissIntent when no selection is active.
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(parentDismissed, isTrue);

        // Allow selection: long-press and drag horizontally while holding to
        // extend by word boundaries.
        allowStart = true;
        final lp = await tester.startGesture(
          Offset(p0Rect.left + 20, p0Rect.center.dy),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        expect(controller.getText(), 'Word0');
        expect(latestSelection, isNotNull);

        await lp.moveTo(Offset(p0Rect.left + 180, p0Rect.center.dy));
        await tester.pump();
        expect(controller.getText(), contains('Alpha'));
        await lp.up();
        await tester.pumpAndSettle();

        expect(
          find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
          findsOneWidget,
        );
        final savedText = controller.getText();

        // Scroll selection completely off-screen -> selection preserved, toolbar hidden.
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(controller.hasSelection, isTrue);
        expect(controller.getText(), savedText);
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
          findsNothing,
        );
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
          findsNothing,
        );

        // Scroll back to top -> handles and toolbar automatically restore.
        scrollController.jumpTo(0.0);
        await tester.pumpAndSettle();
        expect(controller.hasSelection, isTrue);
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
          findsOneWidget,
        );
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ListView(reverse: true) downward edge autoscroll with bottomPad decreases pixels',
      (tester) async {
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final controller = MarkdownSelectionController(
          allowCrossDocumentSelection: true,
        );
        addTearDown(controller.dispose);

        const count = 25;
        final texts = List<String>.generate(
          count,
          (i) => 'Reverse item $i text',
        );
        for (var i = 0; i < count; i++) {
          controller.putDocument(
            MarkdownDocumentRef(
              id: 'r-$i',
              order: count - 1 - i,
              document: MarkdownDocument(
                blocks: [
                  ParagraphBlock(inlines: [TextInline(texts[i])]),
                ],
              ),
            ),
          );
        }

        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              autoscroll: const MarkdownSelectionAutoscrollConfig(
                edgeZone: 50.0,
                maxVelocity: 700.0,
                bottomPad: 40.0,
                useMediaQueryPadding: false,
              ),
              child: ListView.builder(
                controller: scrollController,
                reverse: true,
                itemCount: count,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: _TestSelectableParagraph(
                    documentId: 'r-$index',
                    blockIndex: 0,
                    text: texts[index],
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start scrolled up into older messages.
        scrollController.jumpTo(300.0);
        await tester.pumpAndSettle();
        final startPixels = scrollController.offset;

        // Long-press a visible item and drag into the padded bottom band
        // (viewport bottom 600 - bottomPad 40 = 560, trigger starts at 510).
        final visibleParagraph = find.byType(_TestSelectableParagraph).first;
        final rect = tester.getRect(visibleParagraph);
        final lp = await tester.startGesture(
          Offset(rect.left + 30, rect.center.dy),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        expect(controller.hasSelection, isTrue);

        await lp.moveTo(const Offset(100, 545));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 32));
        }
        await lp.up();
        await tester.pumpAndSettle();

        expect(scrollController.offset, lessThan(startPixels - 40.0));
      },
    );

    testWidgets(
      'non-Apple Shift+Arrow steps by character/line while Shift+End and Ctrl+Shift+End jump to line/doc end',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });

        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        controller.putDocument(
          const MarkdownDocumentRef(
            id: 'd1',
            document: MarkdownDocument(
              blocks: [
                ParagraphBlock(inlines: [TextInline('Alpha Beta')]),
                ParagraphBlock(inlines: [TextInline('Gamma Delta')]),
                ParagraphBlock(inlines: [TextInline('Epsilon Zeta')]),
              ],
            ),
          ),
        );

        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              focusNode: focusNode,
              child: Padding(
                padding: const EdgeInsets.only(top: 40, left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TestSelectableParagraph(
                      documentId: 'd1',
                      blockIndex: 0,
                      text: 'Alpha Beta',
                      controller: controller,
                    ),
                    const SizedBox(height: 8),
                    _TestSelectableParagraph(
                      documentId: 'd1',
                      blockIndex: 1,
                      text: 'Gamma Delta',
                      controller: controller,
                    ),
                    const SizedBox(height: 8),
                    _TestSelectableParagraph(
                      documentId: 'd1',
                      blockIndex: 2,
                      text: 'Epsilon Zeta',
                      controller: controller,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        controller.setSelection(
          const MarkdownSelection.collapsed(
            MarkdownPosition(documentId: 'd1', blockIndex: 0, offset: 0),
          ),
        );
        focusNode.requestFocus();
        await tester.pumpAndSettle();

        // Shift+ArrowRight must extend by 1 char, NOT jump to line break.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(controller.getText(), 'A');

        // Shift+End jumps to end of current line.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(controller.getText(), 'Alpha Beta');

        // Shift+ArrowDown moves to block 1 (adjacent line), NOT doc boundary block 2.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(controller.selection!.extent.blockIndex, 1);

        // Ctrl+Shift+End jumps to document boundary (end of block 2).
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(
          controller.getText(),
          'Alpha Beta\n\nGamma Delta\n\nEpsilon Zeta',
        );
      },
    );

    testWidgets(
      'flipped handle drag survives when fixed anchor scrolls completely off-screen during autoscroll',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });

        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);

        final paragraphs = List<String>.generate(
          30,
          (i) => 'Row $i alpha beta gamma delta',
        );
        controller.putDocument(
          MarkdownDocumentRef(
            id: 'doc',
            document: MarkdownDocument(
              blocks: [
                for (final p in paragraphs)
                  ParagraphBlock(inlines: [TextInline(p)]),
              ],
            ),
          ),
        );

        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              autoscroll: const MarkdownSelectionAutoscrollConfig(
                edgeZone: 60.0,
                maxVelocity: 1200.0,
                useMediaQueryPadding: false,
              ),
              contextMenuBuilder: _buildToolbar,
              child: ListView.builder(
                controller: scrollController,
                scrollCacheExtent: const ScrollCacheExtent.pixels(0.0),
                itemCount: paragraphs.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: _TestSelectableParagraph(
                    documentId: 'doc',
                    blockIndex: index,
                    text: paragraphs[index],
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to the bottom so Row 25 is near the bottom of viewport.
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pumpAndSettle();

        final row25Finder = find.byWidgetPredicate(
          (w) => w is _TestSelectableParagraph && w.blockIndex == 25,
        );
        final row25Rect = tester.getRect(row25Finder);
        final lp = await tester.startGesture(
          Offset(row25Rect.left + 80, row25Rect.center.dy),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await lp.up();
        await tester.pumpAndSettle();

        final endHandleRect = tester.getRect(
          find.byKey(MarkdownSelectionHandleOverlay.endHandleKey),
        );

        // Grab the END handle and drag UP past the start handle into the top
        // autoscroll band until Row 25 (now the logical END anchor) unmounts!
        final handleDrag = await tester.startGesture(endHandleRect.center);
        await tester.pump(const Duration(milliseconds: 30));
        await handleDrag.moveTo(const Offset(120, 8));

        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 32));
          final endpoints = controller.selectionHandleEndpoints();
          if (endpoints != null && !endpoints.hasEnd) {
            break;
          }
        }

        // Fixed anchor (Row 25, logical END) is now off-screen & unmounted!
        final midEndpoints = controller.selectionHandleEndpoints();
        expect(midEndpoints, isNotNull);
        expect(midEndpoints!.hasEnd, isFalse);
        expect(midEndpoints.hasStart, isTrue);

        // Move the still-held finger further right/down-from-top — the active
        // drag recognizer must STILL be alive and updating the start edge!
        final selectionBeforeMove = controller.selection;
        await handleDrag.moveTo(const Offset(40, 120));
        await tester.pump();
        expect(controller.selection, isNot(selectionBeforeMove));

        // Release finger: off-screen end handle entry is now cleanly removed.
        await handleDrag.up();
        await tester.pumpAndSettle();
        expect(controller.hasSelection, isTrue);
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.endHandleKey),
          findsNothing,
        );
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ancestor SingleChildScrollView hides toolbar while scrolling, re-anchors on end, and hides when off-screen',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });

        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);

        controller.putDocument(
          const MarkdownDocumentRef(
            id: 'd1',
            document: MarkdownDocument(
              blocks: [
                ParagraphBlock(inlines: [TextInline('Ancestor scroll target')]),
              ],
            ),
          ),
        );

        Offset? lastToolbarAnchor;
        await tester.pumpWidget(
          _testApp(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 120),
                  MarkdownSelectionScope(
                    controller: controller,
                    contextMenuBuilder: (ctx, state) {
                      final anchor = state.contextMenuAnchors.primaryAnchor;
                      lastToolbarAnchor = anchor;
                      return Stack(
                        children: [
                          Positioned(
                            left: anchor.dx,
                            top: anchor.dy,
                            child: const SizedBox(
                              key: ValueKey<String>('anchored_toolbar'),
                              width: 60,
                              height: 24,
                              child: Text('Menu'),
                            ),
                          ),
                        ],
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _TestSelectableParagraph(
                        documentId: 'd1',
                        blockIndex: 0,
                        text: 'Ancestor scroll target',
                        controller: controller,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1200),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pRect = tester.getRect(find.byType(_TestSelectableParagraph));
        final lp = await tester.startGesture(
          Offset(pRect.left + 40, pRect.center.dy),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await lp.up();
        await tester.pumpAndSettle();

        expect(
          find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
          findsOneWidget,
        );
        final initialAnchorY = lastToolbarAnchor!.dy;

        // Drag-scroll the ancestor SingleChildScrollView by 60px: toolbar hides
        // while scrolling and reappears at the updated (higher) Y coordinate.
        final drag = await tester.startGesture(const Offset(300, 400));
        await drag.moveBy(const Offset(0, -60));
        await tester.pump();
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
          findsNothing,
        );
        await drag.up();
        await tester.pumpAndSettle();

        expect(
          find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
          findsOneWidget,
        );
        expect(lastToolbarAnchor!.dy, lessThan(initialAnchorY - 20.0));

        // Scroll selection completely off-screen above viewport -> toolbar hides.
        scrollController.jumpTo(400.0);
        await tester.pumpAndSettle();
        expect(controller.hasSelection, isTrue);
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.toolbarKey),
          findsNothing,
        );
      },
    );

    testWidgets(
      'autoscroll host bounds scope per boundary doc and ignore empty thematic breaks, and canStartSelectionAt blocks double/triple click',
      (tester) async {
        final controller = MarkdownSelectionController(
          allowCrossDocumentSelection: true,
        );
        addTearDown(controller.dispose);
        final scopeKey = GlobalKey<MarkdownSelectionScopeState>();

        // doc0 has 3 blocks (block 0 will remain unmounted); doc1 has 2 blocks
        // (both mounted, including block 0 which previously poisoned minMountedBlock).
        controller.putDocument(
          const MarkdownDocumentRef(
            id: 'doc0',
            order: 0,
            document: MarkdownDocument(
              blocks: [
                ParagraphBlock(inlines: [TextInline('Doc0 Block0 unmounted')]),
                ParagraphBlock(inlines: [TextInline('Doc0 Block1 mounted')]),
                ParagraphBlock(inlines: [TextInline('Doc0 Block2 mounted')]),
              ],
            ),
          ),
        );
        controller.putDocument(
          const MarkdownDocumentRef(
            id: 'doc1',
            order: 1,
            document: MarkdownDocument(
              blocks: [
                ParagraphBlock(inlines: [TextInline('Doc1 Block0 mounted')]),
                ParagraphBlock(inlines: [TextInline('Doc1 Block1 mounted')]),
                ThematicBreakBlock(),
              ],
            ),
          ),
        );

        var allowStart = false;
        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              key: scopeKey,
              controller: controller,
              canStartSelectionAt: (_) => allowStart,
              child: Padding(
                padding: const EdgeInsets.only(top: 100, left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TestSelectableParagraph(
                      documentId: 'doc0',
                      blockIndex: 1,
                      text: 'Doc0 Block1 mounted',
                      controller: controller,
                    ),
                    _TestSelectableParagraph(
                      documentId: 'doc0',
                      blockIndex: 2,
                      text: 'Doc0 Block2 mounted',
                      controller: controller,
                    ),
                    _TestSelectableParagraph(
                      documentId: 'doc1',
                      blockIndex: 0,
                      text: 'Doc1 Block0 mounted',
                      controller: controller,
                    ),
                    _TestSelectableParagraph(
                      documentId: 'doc1',
                      blockIndex: 1,
                      text: 'Doc1 Block1 mounted',
                      controller: controller,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bounds = scopeKey.currentState!.debugAutoscrollHostBounds()!;
        // doc0 block 0 is unmounted -> top MUST be -infinity even though doc1 mounts block 0!
        expect(bounds.top, double.negativeInfinity);
        // doc1's last selectable block (block 1) IS mounted (trailing ThematicBreakBlock ignored) -> bottom MUST be finite!
        expect(bounds.bottom.isFinite, isTrue);

        // canStartSelectionAt == false must also block desktop double-click and triple-click.
        final pRect = tester.getRect(
          find.byType(_TestSelectableParagraph).first,
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        final pt = Offset(pRect.left + 20, pRect.center.dy);
        for (var i = 0; i < 3; i++) {
          await mouse.down(pt);
          await mouse.up();
          await tester.pump(const Duration(milliseconds: 40));
        }
        await tester.pumpAndSettle();
        expect(controller.hasSelection, isFalse);
      },
    );
  });
}
