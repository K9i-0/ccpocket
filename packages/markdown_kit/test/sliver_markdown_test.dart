import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

Widget _testApp({required Widget child, Size size = const Size(420, 480)}) {
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
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_rootEntry]);
  }
}

/// Builds a 40-block Markdown document containing headings, paragraphs, lists,
/// fenced code blocks, and GFM tables.
String _buildFortyBlockMarkdown() {
  final blocks = <String>[];
  for (var i = 0; i < 40; i++) {
    final tag = i.toString().padLeft(2, '0');
    if (i == 0) {
      blocks.add('# Chapter $tag Opening Heading');
    } else if (i == 10) {
      blocks.add('- List $tag item one\n- List $tag item two');
    } else if (i == 20) {
      blocks.add('```dart\nfinal block$tag = $i;\n```');
    } else if (i == 30) {
      blocks.add(
        '| Key$tag | Value$tag |\n| --- | --- |\n| Left$tag | Right$tag |',
      );
    } else {
      blocks.add(
        'Paragraph block $tag with enough words to take space inside the '
        'sliver viewport and exercise lazy virtualization cleanly.',
      );
    }
  }
  return blocks.join('\n\n');
}

RenderSelectableParagraph _findParagraphContaining(
  WidgetTester tester,
  String substring,
) {
  for (final element in find.bySubtype<RichText>().evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is RenderSelectableParagraph &&
        renderObject.attached &&
        renderObject.hasSize) {
      final plain = renderObject.baseText.toPlainText(
        includeSemanticsLabels: false,
      );
      if (plain.contains(substring)) {
        return renderObject;
      }
    }
  }
  throw StateError(
    'No mounted RenderSelectableParagraph containing "$substring".',
  );
}

Offset _firstGlyphGlobalCenter(RenderSelectableParagraph paragraph) {
  final boxes = paragraph.getBoxesForSelection(
    const TextSelection(baseOffset: 0, extentOffset: 1),
  );
  expect(boxes, isNotEmpty);
  return paragraph.localToGlobal(boxes.first.toRect().center);
}

void main() {
  group('SliverMarkdownView viewport virtualization & selection', () {
    testWidgets('builds blocks lazily inside viewport + cacheExtent, preserves '
        'selection across scroll-off, and copies full range across mounted & '
        'unmounted blocks', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });

      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      final builtBlocks = <int>{};
      final markdown = _buildFortyBlockMarkdown();

      await tester.pumpWidget(
        _testApp(
          size: const Size(420, 420),
          child: MarkdownSelectionScope(
            controller: controller,
            child: CustomScrollView(
              controller: scrollController,
              scrollCacheExtent: const ScrollCacheExtent.pixels(0.0),
              slivers: [
                SliverMarkdownView(
                  documentId: 'long-doc',
                  data: markdown,
                  onBlockBuilt: (index, _) => builtBlocks.add(index),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Full 40-block AST is registered immediately while only visible
      // blocks near the top of the viewport were built lazily.
      final docRef = controller.documentForId('long-doc');
      expect(docRef, isNotNull);
      expect(docRef!.document.blocks.length, 40);
      expect(builtBlocks, contains(0));
      expect(builtBlocks, isNot(contains(39)));
      expect(builtBlocks.length, lessThan(20));

      // 2. Start a touch long-press selection on block 0 ('Chapter').
      final block0Para = _findParagraphContaining(tester, 'Chapter 00');
      final gesture = await tester.startGesture(
        _firstGlyphGlobalCenter(block0Para),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.hasSelection, isTrue);
      expect(controller.getText(), 'Chapter');
      expect(
        find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
        findsOneWidget,
      );

      // 3. Scroll down to the true bottom of the variable-height sliver list
      // so block 0 unmounts and block 39 builds lazily.
      for (var step = 0; step < 6; step++) {
        final maxExtent = scrollController.position.maxScrollExtent;
        if ((scrollController.offset - maxExtent).abs() < 1.0 &&
            builtBlocks.contains(39)) {
          break;
        }
        scrollController.jumpTo(maxExtent);
        await tester.pumpAndSettle();
      }

      expect(builtBlocks, contains(39));
      expect(
        controller.mountedSurfaces.where((s) => s.blockIndex == 0),
        isEmpty,
      );
      expect(
        controller.mountedSurfaces.where((s) => s.blockIndex == 39),
        isNotEmpty,
      );
      // Selection anchored on unmounted block 0 is preserved!
      expect(controller.hasSelection, isTrue);
      expect(controller.getText(), 'Chapter');

      // 4. Extend selection across unmounted block 0 through mounted block 39.
      final block39Text = extractBlockRenderedText(docRef.document.blocks[39]);
      controller.setSelection(
        MarkdownSelection(
          base: const MarkdownPosition(
            documentId: 'long-doc',
            blockIndex: 0,
            offset: 0,
          ),
          extent: MarkdownPosition(
            documentId: 'long-doc',
            blockIndex: 39,
            offset: block39Text.length,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mounted tail block 39 reflects the highlight even while start block 0
      // is scrolled off-screen.
      final block39Para = _findParagraphContaining(
        tester,
        'Paragraph block 39',
      );
      expect(
        block39Para.selectionHighlightRange,
        TextRange(start: 0, end: block39Text.length),
      );

      // Plain-text copy covers ALL 40 blocks (unmounted + mounted).
      final copiedPlain = controller.getText();
      expect(copiedPlain, startsWith('Chapter 00 Opening Heading\n\n'));
      expect(copiedPlain, contains('List 10 item one\nList 10 item two'));
      expect(copiedPlain, isNot(contains('- List 10 item one')));
      expect(copiedPlain, contains('final block20 = 20;'));
      expect(copiedPlain, isNot(contains('dart\nfinal block20')));
      expect(copiedPlain, contains('Key30\tValue30\nLeft30\tRight30'));
      expect(copiedPlain, endsWith(block39Text));

      // Markdown copy reconstructs syntax across unmounted & mounted blocks.
      final copiedMd = controller.getMarkdown();
      expect(copiedMd, startsWith('# Chapter 00 Opening Heading'));
      expect(copiedMd, contains('- List 10 item one\n- List 10 item two'));
      expect(copiedMd, contains('```dart\nfinal block20 = 20;\n```'));
      expect(copiedMd, contains('| Key30 | Value30 |'));
      expect(copiedMd, endsWith(block39Text));

      // 5. Scroll back to the top -> block 0 remounts with its selection
      // highlight and start handle restored!
      scrollController.jumpTo(0.0);
      await tester.pumpAndSettle();

      final remountedBlock0 = _findParagraphContaining(tester, 'Chapter 00');
      expect(
        remountedBlock0.selectionHighlightRange,
        TextRange(
          start: 0,
          end: extractBlockRenderedText(docRef.document.blocks[0]).length,
        ),
      );
      expect(
        find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
        findsOneWidget,
      );
    });

    testWidgets(
      'supports pre-parsed document, blockSpacing padding, selectable: false, '
      'and keepDocumentOnDispose: false',
      (tester) async {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);

        final preParsed = GfmMarkdownParser().parse(
          'First sliver block\n\nSecond sliver block',
        );

        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              child: CustomScrollView(
                slivers: [
                  SliverMarkdownView(
                    documentId: 'preparsed-doc',
                    document: preParsed,
                    theme: MarkdownThemeData.fallback().copyWith(
                      blockSpacing: 18.0,
                    ),
                    keepDocumentOnDispose: false,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.documentForId('preparsed-doc')?.document, preParsed);

        // Verify index > 0 gets top padding equal to theme.blockSpacing.
        final paddings = tester
            .widgetList<Padding>(find.byType(Padding))
            .where((p) => p.padding == const EdgeInsets.only(top: 18.0))
            .toList();
        expect(paddings, hasLength(1));

        // Verify keepDocumentOnDispose: false removes document on dispose.
        await tester.pumpWidget(
          _testApp(
            child: MarkdownSelectionScope(
              controller: controller,
              child: const CustomScrollView(
                slivers: [
                  SliverMarkdownView(
                    documentId: 'disabled-doc',
                    data: 'Read-only block',
                    selectable: false,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.documentForId('preparsed-doc'), isNull);
        expect(controller.documentForId('disabled-doc'), isNull);
        expect(controller.mountedSurfaces, isEmpty);
      },
    );
  });
}
