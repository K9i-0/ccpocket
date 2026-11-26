import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:markdown_kit/src/selection/selection_handles.dart';

/// Pure `widgets.dart`-only test app providing [Directionality], [MediaQuery],
/// [FocusScope], and a reactive [Overlay] (updating its root [OverlayEntry] on
/// widget rebuilds) without importing `material.dart`.
Widget _testApp({
  required Widget child,
  Size size = const Size(420, 680),
  MarkdownThemeData? theme,
}) {
  Widget body = ColoredBox(color: const Color(0xFFFFFFFF), child: child);
  if (theme != null) {
    body = MarkdownTheme(data: theme, child: body);
  }
  return Directionality(
    textDirection: ui.TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: FocusScope(
        autofocus: true,
        child: _ReactiveOverlayShell(child: body),
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
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_rootEntry]);
  }
}

/// Finds the first attached [RenderSelectableParagraph] whose plain text
/// contains [substring] (optionally scoped to [documentId]).
RenderSelectableParagraph _findParagraphContaining(
  WidgetTester tester,
  String substring, {
  String? documentId,
}) {
  for (final element in find.bySubtype<RichText>().evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is RenderSelectableParagraph &&
        renderObject.attached &&
        renderObject.hasSize) {
      if (documentId != null && renderObject.documentId != documentId) {
        continue;
      }
      final plain = renderObject.baseText.toPlainText(
        includeSemanticsLabels: false,
      );
      if (plain.contains(substring)) {
        return renderObject;
      }
    }
  }
  throw StateError(
    'No mounted RenderSelectableParagraph containing "$substring"'
    '${documentId == null ? '' : ' in document "$documentId"'}.',
  );
}

/// Computes the global center of the first rendered glyph box of [paragraph].
Offset _firstGlyphGlobalCenter(RenderSelectableParagraph paragraph) {
  final boxes = paragraph.getBoxesForSelection(
    const TextSelection(baseOffset: 0, extentOffset: 1),
  );
  expect(boxes, isNotEmpty);
  return paragraph.localToGlobal(boxes.first.toRect().center);
}

/// Computes the global center of the glyph range `[start, end)` in [paragraph].
Offset _rangeGlobalCenter(
  RenderSelectableParagraph paragraph,
  int start,
  int end,
) {
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  );
  expect(boxes, isNotEmpty);
  return paragraph.localToGlobal(boxes.first.toRect().center);
}

/// Starts a touch long-press at [globalPoint] and releases cleanly so handles
/// and toolbar appear.
Future<void> _longPressTouchAt(WidgetTester tester, Offset globalPoint) async {
  final gesture = await tester.startGesture(
    globalPoint,
    kind: PointerDeviceKind.touch,
  );
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('MarkdownView + SelectablePlainText end-to-end integration', () {
    const richMarkdown = '''
# Report Title

Intro alpha beta paragraph.

- First bullet item
- Second bullet item

```dart
final count = 42;
print(count);
```

| ColA | ColB |
| --- | --- |
| Val1 | Val2 |
''';

    for (final platform in const [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets(
        'long-press + 150ms paused opaque handle drag across blocks in '
        'reverse ListView never steals scroll and formats plain text & '
        'Markdown cleanly ($platform)',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() {
            debugDefaultTargetPlatformOverride = null;
          });

          final controller = MarkdownSelectionController();
          addTearDown(controller.dispose);
          final scrollController = ScrollController();
          addTearDown(scrollController.dispose);

          // Reverse ListView: index 0 sits at the bottom, higher indices stack
          // above it, creating genuine scrollable overflow.
          await tester.pumpWidget(
            _testApp(
              size: const Size(420, 720),
              child: MarkdownSelectionScope(
                controller: controller,
                child: ListView(
                  reverse: true,
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: SelectablePlainText(
                        'Latest user reply below assistant message',
                        documentId: 'user-bottom',
                        documentOrder: 20,
                        style: TextStyle(fontSize: 15, height: 1.4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: MarkdownView(
                        documentId: 'assistant-rich',
                        documentOrder: 10,
                        data: richMarkdown,
                        theme: MarkdownThemeData.fallback().copyWith(
                          blockSpacing: 8.0,
                        ),
                      ),
                    ),
                    for (var i = 0; i < 8; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: SelectablePlainText(
                          'Older history message number $i with extra text '
                          'to guarantee scrollable list overflow.',
                          documentId: 'older-$i',
                          documentOrder: 9 - i,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(scrollController.position.maxScrollExtent, greaterThan(0));
          final initialScrollOffset = scrollController.offset;

          final headingPara = _findParagraphContaining(
            tester,
            'Report Title',
            documentId: 'assistant-rich',
          );
          final lastTableCellPara = _findParagraphContaining(
            tester,
            'Val2',
            documentId: 'assistant-rich',
          );

          // 1. Long-press on the heading to start word selection.
          await _longPressTouchAt(tester, _firstGlyphGlobalCenter(headingPara));

          expect(controller.hasSelection, isTrue);
          expect(controller.getText(), 'Report');
          expect(
            find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
            findsOneWidget,
          );
          expect(
            find.byKey(MarkdownSelectionHandleOverlay.endHandleKey),
            findsOneWidget,
          );

          // 2. Touch down on end handle, pause 150ms (regression check: list
          // must NOT claim the gesture), then drag down through paragraph,
          // list, code block, and table to the last table cell.
          final endHandleCenter = tester.getCenter(
            find.byKey(MarkdownSelectionHandleOverlay.endHandleKey),
          );
          final targetCellEnd = lastTableCellPara.localToGlobal(
            Offset(
              lastTableCellPara.size.width - 1,
              lastTableCellPara.size.height / 2,
            ),
          );
          final endCaretCenter = Offset(
            controller.selectionHandleEndpoints()!.endGlobal!.dx,
            controller.selectionHandleEndpoints()!.endGlobal!.dy -
                (controller.selectionHandleEndpoints()!.endLineHeight ?? 20) /
                    2,
          );
          final anchorCompensation = endCaretCenter - endHandleCenter;
          final dragDestination = targetCellEnd - anchorCompensation;

          final handleGesture = await tester.startGesture(
            endHandleCenter,
            kind: PointerDeviceKind.touch,
          );
          await tester.pump(const Duration(milliseconds: 150));

          const steps = 16;
          for (var s = 1; s <= steps; s++) {
            final t = s / steps;
            final nextPoint = Offset.lerp(endHandleCenter, dragDestination, t)!;
            await handleGesture.moveTo(nextPoint);
            await tester.pump(const Duration(milliseconds: 16));
          }
          await handleGesture.up();
          await tester.pumpAndSettle();

          // ListView must NOT have stolen the scroll gesture during handle drag.
          expect(scrollController.offset, closeTo(initialScrollOffset, 0.5));
          expect(controller.hasSelection, isTrue);

          final plain = controller.getText();
          // Paragraphs / blocks separated by \n\n.
          expect(
            plain,
            contains('Report Title\n\nIntro alpha beta paragraph.'),
          );
          // List items separated by \n without bullet glyphs or "- ".
          expect(plain, contains('First bullet item\nSecond bullet item'));
          expect(plain, isNot(contains('•')));
          expect(plain, isNot(contains('- First bullet item')));
          // Code block raw text without language header "dart".
          expect(plain, contains('final count = 42;\nprint(count);'));
          expect(plain, isNot(contains('dart\nfinal count')));
          // Table cells separated by \t and rows by \n.
          expect(plain, contains('ColA\tColB\nVal1\tVal2'));

          // Markdown reconstruction restores #, -, ```, and | table pipes.
          final reconstructed = controller.getMarkdown();
          expect(reconstructed, contains('# Report Title'));
          expect(reconstructed, contains('- First bullet item'));
          expect(reconstructed, contains('- Second bullet item'));
          expect(reconstructed, contains('```dart'));
          expect(reconstructed, contains('| ColA | ColB |'));
          expect(reconstructed, contains('| Val1 | Val2 |'));
        },
      );
    }

    testWidgets(
      'allowCrossDocumentSelection: false clamps drags to bubble, switches '
      'on long-press of another bubble, and survives off-screen scroll-off',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });

        final controller = MarkdownSelectionController(
          allowCrossDocumentSelection: false,
        );
        addTearDown(controller.dispose);
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        final items = <({String id, bool isMarkdown, String content})>[
          (
            id: 'msg-0',
            isMarkdown: false,
            content: 'User prompt message alpha bravo charlie',
          ),
          (
            id: 'msg-1',
            isMarkdown: true,
            content:
                'Assistant bubble first line.\n\nAssistant bubble second line.',
          ),
          for (var i = 2; i < 18; i++)
            (
              id: 'msg-$i',
              isMarkdown: i.isOdd,
              content: 'History item $i with enough vertical height to scroll.',
            ),
        ];

        await tester.pumpWidget(
          _testApp(
            size: const Size(400, 560),
            child: MarkdownSelectionScope(
              controller: controller,
              child: ListView.builder(
                reverse: true,
                scrollCacheExtent: const ScrollCacheExtent.pixels(0.0),
                controller: scrollController,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  // In reverse ListView, index 0 is newest (bottom, highest order).
                  final order = items.length - index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: item.isMarkdown
                        ? MarkdownView(
                            key: ValueKey<String>(item.id),
                            documentId: item.id,
                            documentOrder: order,
                            data: item.content,
                          )
                        : SelectablePlainText(
                            item.content,
                            key: ValueKey<String>(item.id),
                            documentId: item.id,
                            documentOrder: order,
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Select inside MarkdownView 'msg-1'.
        final assistantPara1 = _findParagraphContaining(
          tester,
          'Assistant bubble first',
          documentId: 'msg-1',
        );
        final userPara = _findParagraphContaining(
          tester,
          'User prompt message',
          documentId: 'msg-0',
        );

        await _longPressTouchAt(
          tester,
          _firstGlyphGlobalCenter(assistantPara1),
        );
        expect(controller.hasSelection, isTrue);
        expect(controller.selection!.base.documentId, 'msg-1');

        // 2. Drag end handle well past msg-1 into user bubble msg-0 below it.
        final endHandleCenter = tester.getCenter(
          find.byKey(MarkdownSelectionHandleOverlay.endHandleKey),
        );
        final userCenter = _firstGlyphGlobalCenter(userPara);

        final drag = await tester.startGesture(
          endHandleCenter,
          kind: PointerDeviceKind.touch,
        );
        await tester.pump(const Duration(milliseconds: 150));
        await drag.moveTo(Offset(userCenter.dx, userCenter.dy + 40));
        await tester.pump(const Duration(milliseconds: 32));
        await drag.up();
        await tester.pumpAndSettle();

        // Clamped strictly within 'msg-1'; no text leaked from 'msg-0'.
        expect(controller.selection!.base.documentId, 'msg-1');
        expect(controller.selection!.extent.documentId, 'msg-1');
        expect(controller.getText(), contains('Assistant bubble second line.'));
        expect(controller.getText(), isNot(contains('User prompt')));

        // 3. Long-press inside the second bubble (SelectablePlainText 'msg-0')
        // -> cleanly switches selection to 'msg-0'.
        await _longPressTouchAt(tester, _firstGlyphGlobalCenter(userPara));
        expect(controller.hasSelection, isTrue);
        expect(controller.selection!.base.documentId, 'msg-0');
        expect(controller.selection!.extent.documentId, 'msg-0');
        expect(controller.getText(), 'User');

        // Select full 'msg-0' via selectAll (respects allowCrossDocumentSelection: false).
        expect(controller.selectAll(), isTrue);
        await tester.pumpAndSettle();
        expect(controller.getText(), 'User prompt message alpha bravo charlie');

        // 4. Scroll 'msg-0' completely off-screen (cacheExtent: 0) -> unmounts
        // its RenderSelectableParagraph while keeping document registered.
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pumpAndSettle();

        final mountedMsg0Surfaces = controller.mountedSurfaces.where(
          (s) => s.documentId == 'msg-0',
        );
        expect(mountedMsg0Surfaces, isEmpty);
        expect(controller.hasSelection, isTrue);
        expect(controller.getText(), 'User prompt message alpha bravo charlie');

        // 5. Scroll back to 0 -> 'msg-0' remounts with selection highlight and
        // handle overlays restored.
        scrollController.jumpTo(0.0);
        await tester.pumpAndSettle();

        final remountedUserPara = _findParagraphContaining(
          tester,
          'User prompt message',
          documentId: 'msg-0',
        );
        expect(
          remountedUserPara.selectionHighlightRange,
          const TextRange(start: 0, end: 39),
        );
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
          findsOneWidget,
        );
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.endHandleKey),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'streaming reuses settled leading blocks (onBlockReused) and keeps '
      'selection anchored across streaming updates and true -> false handoff',
      (tester) async {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);

        final builtIndices = <int>[];
        final reusedIndices = <int>[];

        Widget buildStreamingTree({
          required String data,
          required bool isStreaming,
          Key? viewKey,
        }) {
          return _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              child: MarkdownView(
                key: viewKey,
                documentId: 'stream-doc',
                data: data,
                isStreaming: isStreaming,
                onBlockBuilt: (index, _) => builtIndices.add(index),
                onBlockReused: (index, _) => reusedIndices.add(index),
              ),
            ),
          );
        }

        // Initial streaming frame with 3 blocks.
        await tester.pumpWidget(
          buildStreamingTree(
            viewKey: const ValueKey<String>('streaming-bubble'),
            isStreaming: true,
            data:
                '# Stream Heading\n\nSettled middle paragraph text.\n\nTail start',
          ),
        );
        await tester.pumpAndSettle();

        expect(builtIndices, [0, 1, 2]);
        expect(reusedIndices, isEmpty);

        // Anchor a selection inside the settled middle paragraph (block 1).
        controller.setSelection(
          const MarkdownSelection(
            base: MarkdownPosition(
              documentId: 'stream-doc',
              blockIndex: 1,
              offset: 8,
            ),
            extent: MarkdownPosition(
              documentId: 'stream-doc',
              blockIndex: 1,
              offset: 24,
            ),
          ),
        );
        await tester.pump();
        expect(controller.getText(), 'middle paragraph');

        // Stream update #1: append text to tail block 2.
        builtIndices.clear();
        reusedIndices.clear();
        await tester.pumpWidget(
          buildStreamingTree(
            viewKey: const ValueKey<String>('streaming-bubble'),
            isStreaming: true,
            data:
                '# Stream Heading\n\nSettled middle paragraph text.\n\nTail start with more tokens',
          ),
        );
        await tester.pump();

        expect(reusedIndices, [0, 1]);
        expect(builtIndices, [2]);
        expect(controller.hasSelection, isTrue);
        expect(controller.getText(), 'middle paragraph');

        // Stream update #2: append an unclosed fenced code block as block 3.
        builtIndices.clear();
        reusedIndices.clear();
        await tester.pumpWidget(
          buildStreamingTree(
            viewKey: const ValueKey<String>('streaming-bubble'),
            isStreaming: true,
            data:
                '# Stream Heading\n\nSettled middle paragraph text.\n\n'
                'Tail start with more tokens\n\n```dart\nfinal v = 1;',
          ),
        );
        await tester.pump();

        expect(reusedIndices, [0, 1, 2]);
        expect(builtIndices, [3]);
        expect(controller.hasSelection, isTrue);
        expect(controller.getText(), 'middle paragraph');

        // Handoff from streaming bubble (isStreaming: true) to finalized
        // assistant bubble (isStreaming: false) with a DIFFERENT widget key
        // sharing the same documentId (simulates StreamingBubble -> AssistantBubble).
        builtIndices.clear();
        reusedIndices.clear();
        await tester.pumpWidget(
          buildStreamingTree(
            viewKey: const ValueKey<String>('final-assistant-bubble'),
            isStreaming: false,
            data:
                '# Stream Heading\n\nSettled middle paragraph text.\n\n'
                'Tail start with more tokens\n\n```dart\nfinal v = 1;\n```',
          ),
        );
        await tester.pumpAndSettle();

        // Selection stays anchored across the widget swap because default
        // keepDocumentOnDispose == true prevents the outgoing streaming widget
        // from removing 'stream-doc'.
        expect(controller.hasSelection, isTrue);
        expect(controller.getText(), 'middle paragraph');

        final middlePara = _findParagraphContaining(
          tester,
          'Settled middle paragraph',
          documentId: 'stream-doc',
        );
        expect(
          middlePara.selectionHighlightRange,
          const TextRange(start: 8, end: 24),
        );
      },
    );

    testWidgets(
      'standalone MarkdownView and SelectablePlainText work without ancestor '
      'MarkdownSelectionScope and dispose cleanly',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });

        MarkdownSelection? latestMarkdownSelection;
        String? toolbarCopiedText;

        await tester.pumpWidget(
          _testApp(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownView(
                  data: 'Standalone **markdown** content',
                  selectable: true,
                  onSelectionChanged: (sel) => latestMarkdownSelection = sel,
                  contextMenuBuilder: (context, state) {
                    toolbarCopiedText = state.selectedPlainText;
                    return const SizedBox(
                      key: ValueKey<String>('standalone_toolbar'),
                      width: 80,
                      height: 32,
                    );
                  },
                ),
                const SizedBox(height: 16),
                const SelectablePlainText(
                  'Standalone plain text bubble',
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final mdPara = _findParagraphContaining(tester, 'Standalone markdown');
        await _longPressTouchAt(tester, _firstGlyphGlobalCenter(mdPara));

        expect(latestMarkdownSelection, isNotNull);
        expect(latestMarkdownSelection!.isCollapsed, isFalse);
        expect(toolbarCopiedText, 'Standalone');
        expect(
          find.byKey(const ValueKey<String>('standalone_toolbar')),
          findsOneWidget,
        );
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
          findsOneWidget,
        );

        // Long-press standalone SelectablePlainText as well.
        final plainPara = _findParagraphContaining(
          tester,
          'Standalone plain text',
        );
        await _longPressTouchAt(tester, _firstGlyphGlobalCenter(plainPara));
        expect(plainPara.selectionHighlightRange, isNotNull);
        expect(plainPara.selectionHighlightRange!.isCollapsed, isFalse);

        // Unmounting must cleanly dispose internal scopes/controllers without
        // throwing ChangeNotifier debugAssertNotDisposed.
        await tester.pumpWidget(_testApp(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'selectable: false disables surface registration and text cursor; '
      'keepDocumentOnDispose: false unregisters document on dispose',
      (tester) async {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownView(
                    documentId: 'non-selectable',
                    data: 'Non-selectable paragraph',
                    selectable: false,
                  ),
                  MarkdownView(
                    documentId: 'ephemeral-doc',
                    data: 'Ephemeral selectable paragraph',
                    keepDocumentOnDispose: false,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.documentForId('non-selectable'), isNull);
        expect(controller.documentForId('ephemeral-doc'), isNotNull);
        expect(
          controller.mountedSurfaces.where(
            (s) => s.documentId == 'non-selectable',
          ),
          isEmpty,
        );

        // Verify non-selectable MarkdownView uses MouseCursor.defer rather than
        // SystemMouseCursors.text.
        final nonSelectableRegion = tester.widget<MouseRegion>(
          find
              .descendant(
                of: find.byWidgetPredicate(
                  (w) => w is MarkdownView && w.documentId == 'non-selectable',
                ),
                matching: find.byType(MouseRegion),
              )
              .first,
        );
        expect(nonSelectableRegion.cursor, MouseCursor.defer);

        // Remove ephemeral-doc -> keepDocumentOnDispose: false removes it from
        // the ancestor controller.
        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              child: const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.documentForId('ephemeral-doc'), isNull);
      },
    );

    testWidgets(
      'TappableTextSpan link tap and hover underline work inside MarkdownView '
      'alongside MarkdownSelectionScope',
      (tester) async {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);

        final tappedLinks = <(String, String)>[];

        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              child: MarkdownView(
                documentId: 'link-doc',
                data: 'Visit [DocsLink](https://example.com "Docs") today',
                builders: MarkdownBuilders(
                  onLinkTap: (url, title) => tappedLinks.add((url, title)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final para = _findParagraphContaining(
          tester,
          'Visit DocsLink today',
          documentId: 'link-doc',
        );
        // 'Visit ' is indices 0..6, 'DocsLink' is indices 6..14.
        final linkCenter = _rangeGlobalCenter(para, 6, 14);
        final outsideLink = _rangeGlobalCenter(para, 0, 5);

        // 1. Desktop hover activates hoverStyle (underline) and click cursor.
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await tester.pump();

        await mouse.moveTo(linkCenter);
        await tester.pump();

        expect(para.hoveredSpanIndex, isNotNull);
        final hoveredMouseRegion = tester.widget<MouseRegion>(
          find.descendant(
            of: find.byType(SelectableParagraph),
            matching: find.byType(MouseRegion),
          ),
        );
        expect(hoveredMouseRegion.cursor, SystemMouseCursors.click);

        // Confirm rendered TextSpan under hover contains underline decoration.
        var foundUnderline = false;
        para.text.visitChildren((span) {
          if (span is TextSpan &&
              span.style?.decoration == TextDecoration.underline) {
            foundUnderline = true;
          }
          return true;
        });
        expect(foundUnderline, isTrue);

        // Moving pointer off link clears hover styling and restores text cursor.
        await mouse.moveTo(outsideLink);
        await tester.pump();
        expect(para.hoveredSpanIndex, isNull);

        // 2. Touch tap activates the link callback without starting selection.
        await tester.tapAt(linkCenter);
        await tester.pumpAndSettle();
        expect(tappedLinks, [('https://example.com', 'Docs')]);
        expect(controller.hasSelection, isFalse);

        // 3. Mouse primary click also activates the link callback.
        await mouse.down(linkCenter);
        await tester.pump(const Duration(milliseconds: 20));
        await mouse.up();
        await tester.pumpAndSettle();
        expect(tappedLinks.length, 2);

        // 4. Touch long-press on the link starts selection WITHOUT firing onLinkTap.
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });
        await _longPressTouchAt(tester, linkCenter);
        expect(tappedLinks.length, 2);
        expect(controller.hasSelection, isTrue);
        expect(controller.getText(), 'DocsLink');
      },
    );
  });
}
