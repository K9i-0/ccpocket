import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:markdown_kit/src/rendering/block_renderer.dart';
import 'package:markdown_kit/src/rendering/details_widget.dart';
import 'package:markdown_kit/src/rendering/list_item_widget.dart';
import 'package:markdown_kit/src/rendering/table_widget.dart';

Widget _wrapApp(
  Widget child, {
  double width = 400.0,
  MarkdownThemeData? theme,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: MarkdownTheme(
        data: theme ?? MarkdownThemeData.fallback(),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('MarkdownThemeData & MarkdownBuilders value equality', () {
    test('fallback, dark, copyWith, equality, and InheritedWidget lookup', () {
      final a = MarkdownThemeData.fallback();
      final b = MarkdownThemeData.fallback();
      final dark = MarkdownThemeData.dark();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(dark)));

      final modified = a.copyWith(
        blockSpacing: 20.0,
        selectionColor: const Color(0x55FF0000),
      );
      expect(modified, isNot(equals(a)));
      expect(modified.blockSpacing, 20.0);
      expect(modified.selectionColor, const Color(0x55FF0000));
      expect(
        modified.copyWith(
          blockSpacing: a.blockSpacing,
          selectionColor: a.selectionColor,
        ),
        equals(a),
      );

      expect(a.headingStyleForLevel(1), a.h1Style);
      expect(a.headingStyleForLevel(6), a.h6Style);
      for (final kind in AlertKind.values) {
        expect(a.alertStyleFor(kind), isNotNull);
        expect(dark.alertStyleFor(kind), isNotNull);
      }

      const b1 = MarkdownBuilders();
      const b2 = MarkdownBuilders();
      expect(b1, equals(b2));
      expect(b1.hashCode, equals(b2.hashCode));
      void onTap(String u, String t) {}
      final b3 = b1.copyWith(onLinkTap: onTap);
      expect(b3, isNot(equals(b1)));
      expect(b3.onLinkTap, same(onTap));
    });

    testWidgets('MarkdownTheme.of and maybeOf resolve inherited theme', (
      tester,
    ) async {
      MarkdownThemeData? resolvedMaybe;
      MarkdownThemeData? resolvedOf;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              resolvedMaybe = MarkdownTheme.maybeOf(context);
              resolvedOf = MarkdownTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolvedMaybe, isNull);
      expect(resolvedOf, equals(MarkdownThemeData.fallback()));

      final custom = MarkdownThemeData.dark();
      await tester.pumpWidget(
        MarkdownTheme(
          data: custom,
          child: Builder(
            builder: (context) {
              resolvedMaybe = MarkdownTheme.maybeOf(context);
              resolvedOf = MarkdownTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolvedMaybe, equals(custom));
      expect(resolvedOf, equals(custom));
    });
  });

  group('TextOffsetMapping & WidgetSpan canonical offset accuracy', () {
    test('maps WidgetSpan with alt text without drift', () {
      // Canonical: "Hello Logo world" (len 16)
      // Painter:   "Hello \uFFFC world" (len 13)
      final builder = TextOffsetMappingBuilder()
        ..addOneToOne(6) // "Hello "
        ..addAtomic(canonicalLength: 4, painterLength: 1) // "Logo" <-> \uFFFC
        ..addOneToOne(6); // " world"
      final mapping = builder.build();

      expect(mapping.isIdentity, isFalse);
      expect(mapping.canonicalLength, 16);
      expect(mapping.painterLength, 13);

      // Canonical -> Painter ranges
      expect(mapping.canonicalRangeToPainterRange(0, 6), (start: 0, end: 6));
      expect(mapping.canonicalRangeToPainterRange(6, 10), (start: 6, end: 7));
      expect(mapping.canonicalRangeToPainterRange(11, 16), (start: 8, end: 13));
      expect(mapping.canonicalRangeToPainterRange(0, 16), (start: 0, end: 13));

      // Painter -> Canonical points & ranges
      expect(mapping.painterToCanonical(5), 5);
      expect(mapping.painterToCanonical(6), 6);
      expect(mapping.painterToCanonical(7), 10);
      expect(mapping.painterToCanonical(8), 11);
      expect(mapping.painterToCanonical(13), 16);
      expect(
        mapping.painterRangeToCanonicalRange(6, 7),
        const TextRange(start: 6, end: 10),
      );
      expect(
        mapping.painterRangeToCanonicalRange(8, 13),
        const TextRange(start: 11, end: 16),
      );
    });

    test(
      'maps WidgetSpan with empty alt text and color-swatch inline code',
      () {
        // Color swatch WidgetSpan + "#FF5733":
        // Canonical: "Color #FF5733 end" (len 17)
        // Painter:   "Color \uFFFC#FF5733 end" (len 18)
        final swatchSpan = TextSpan(
          children: [
            const WidgetSpan(child: SizedBox(width: 10, height: 10)),
            const TextSpan(text: '#FF5733'),
          ],
        );
        final builder = TextOffsetMappingBuilder()
          ..addOneToOne(6)
          ..addBuiltSpan(canonicalText: '#FF5733', span: swatchSpan)
          ..addOneToOne(4);
        final mapping = builder.build();

        expect(mapping.canonicalLength, 17);
        expect(mapping.painterLength, 18);
        // "#FF5733" is canonical [6, 13) -> painter [7, 14)
        expect(mapping.canonicalRangeToPainterRange(6, 13), (
          start: 7,
          end: 14,
        ));
        // "end" is canonical [14, 17) -> painter [15, 18)
        expect(mapping.canonicalRangeToPainterRange(14, 17), (
          start: 15,
          end: 18,
        ));
        expect(mapping.painterToCanonical(7), 6);
        expect(mapping.painterToCanonical(15), 14);
      },
    );

    testWidgets(
      'RenderSelectableParagraph preserves geometry and hit-testing around inline image WidgetSpan',
      (tester) async {
        final attached = <MarkdownSelectionSurface>[];
        const block = ParagraphBlock(
          inlines: [
            TextInline('Hello '),
            ImageInline(source: 'logo.png', alt: 'Logo'),
            TextInline(' world'),
          ],
        );

        await tester.pumpWidget(
          _wrapApp(
            MarkdownBlockRenderer(
              documentId: 'doc1',
              blockIndex: 0,
              block: block,
              builders: MarkdownBuilders(
                imageBuilder: (context, image, theme) =>
                    const SizedBox(width: 24, height: 16),
              ),
              onSurfaceAttach: attached.add,
            ),
          ),
        );

        expect(attached, hasLength(1));
        final surface = attached.single as RenderSelectableParagraph;
        expect(surface.textLength, 'Hello Logo world'.length);
        expect(
          surface.offsetMapping.painterLength,
          'Hello \uFFFC world'.length,
        );

        final helloBoxes = surface.boxesForLocalRange(0, 5);
        final imageBoxes = surface.boxesForLocalRange(6, 10);
        final worldBoxes = surface.boxesForLocalRange(11, 16);

        expect(helloBoxes, isNotEmpty);
        expect(imageBoxes, isNotEmpty);
        expect(worldBoxes, isNotEmpty);

        // Verify strict left-to-right non-drifting geometry.
        expect(
          imageBoxes.first.left,
          greaterThanOrEqualTo(helloBoxes.first.right),
        );
        expect(
          worldBoxes.first.left,
          greaterThanOrEqualTo(imageBoxes.first.right - 1.0),
        );

        // Hit-testing center of "world" must map inside canonical [11, 16].
        final worldLocalCenter = worldBoxes.first.toRect().center;
        final worldGlobalCenter = surface.localToGlobal(worldLocalCenter);
        final hitPos = surface.positionForGlobalOffset(worldGlobalCenter);
        expect(hitPos.documentId, 'doc1');
        expect(hitPos.blockIndex, 0);
        expect(hitPos.offset, inInclusiveRange(11, 16));

        // Word boundary at canonical offset inside "Logo" maps to [6, 10).
        expect(surface.wordRangeAtLocal(7), const TextRange(start: 6, end: 10));
        // Word boundary inside "world" maps to [11, 16).
        expect(
          surface.wordRangeAtLocal(13),
          const TextRange(start: 11, end: 16),
        );

        // Caret rect at start of "world" aligns with world's left edge.
        final caret = surface.caretRectForLocalOffset(11);
        expect(caret.left, closeTo(worldBoxes.first.left, 2.0));
      },
    );

    testWidgets(
      'empty-alt WidgetSpan and color-swatch inlineCodeBuilder keep offsets accurate',
      (tester) async {
        final attached = <MarkdownSelectionSurface>[];
        const block = ParagraphBlock(
          inlines: [
            TextInline('Hi '),
            ImageInline(source: 'empty.png', alt: ''),
            TextInline(' '),
            InlineCodeInline('#FF5733'),
            TextInline(' end'),
          ],
        );

        await tester.pumpWidget(
          _wrapApp(
            MarkdownBlockRenderer(
              documentId: 'doc1',
              blockIndex: 0,
              block: block,
              builders: MarkdownBuilders(
                imageBuilder: (_, _, _) =>
                    const SizedBox(width: 16, height: 16),
                inlineCodeBuilder: (_, code, style, _) => TextSpan(
                  children: [
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: SizedBox(width: 10, height: 10),
                    ),
                    TextSpan(text: code, style: style),
                  ],
                ),
              ),
              onSurfaceAttach: attached.add,
            ),
          ),
        );

        final expectedText = extractBlockRenderedText(block);
        expect(expectedText, 'Hi  #FF5733 end');
        final surface = attached.single as RenderSelectableParagraph;
        expect(surface.textLength, expectedText.length);

        final endStart = expectedText.indexOf('end');
        final endBoxes = surface.boxesForLocalRange(
          endStart,
          expectedText.length,
        );
        expect(endBoxes, isNotEmpty);
        final endCenter = surface.localToGlobal(endBoxes.first.toRect().center);
        final pos = surface.positionForGlobalOffset(endCenter);
        expect(pos.offset, inInclusiveRange(endStart, expectedText.length));
      },
    );
  });

  group('SelectableParagraph: CodeTextSpan, TappableTextSpan, hover & selection', () {
    testWidgets('RichText compatibility and multi-line inline code pills', (
      tester,
    ) async {
      final attached = <MarkdownSelectionSurface>[];
      const block = ParagraphBlock(
        inlines: [
          TextInline('Run '),
          InlineCodeInline(
            'very_long_inline_code_identifier_that_wraps_across_lines',
          ),
          TextInline(' now'),
        ],
      );

      await tester.pumpWidget(
        _wrapApp(
          width: 180.0,
          MarkdownBlockRenderer(
            documentId: 'doc1',
            blockIndex: 0,
            block: block,
            onSurfaceAttach: attached.add,
          ),
        ),
      );

      // find.text(..., findRichText: true) and find.bySubtype<RichText>() work!
      expect(
        find.text(
          'Run very_long_inline_code_identifier_that_wraps_across_lines now',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.bySubtype<RichText>(), findsOneWidget);

      final surface = attached.single as RenderSelectableParagraph;
      expect(surface.codeRangeCount, 1);

      // Verify the inline code span wrapped into at least 2 line fragments.
      final codeBoxes = surface.boxesForLocalRange(
        4,
        4 + 'very_long_inline_code_identifier_that_wraps_across_lines'.length,
      );
      expect(codeBoxes.length, greaterThanOrEqualTo(2));

      // Verify painting rounded rects succeeds without error.
      expect(find.bySubtype<RichText>(), paints..rrect());
    });

    testWidgets(
      'TappableTextSpan handles nested spans, tap, hover style without parent rebuild, cursor, exit, scroll, and layout invalidation',
      (tester) async {
        final tapped = <(String, String)>[];
        var parentBuilds = 0;
        final attached = <MarkdownSelectionSurface>[];
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        const block = ParagraphBlock(
          inlines: [
            TextInline('Visit '),
            LinkInline(
              destination: 'https://dart.dev',
              title: 'Dart',
              children: [
                TextInline('the '),
                StrongInline(children: [TextInline('Dart')]),
                TextInline(' '),
                InlineCodeInline('SDK'),
              ],
            ),
            TextInline(' page'),
          ],
        );

        Widget buildTree({double width = 400.0}) {
          return _wrapApp(
            width: width,
            SingleChildScrollView(
              controller: scrollController,
              child: SizedBox(
                height: 1200,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Builder(
                    builder: (context) {
                      parentBuilds++;
                      return MarkdownBlockRenderer(
                        documentId: 'doc1',
                        blockIndex: 0,
                        block: block,
                        builders: MarkdownBuilders(
                          onLinkTap: (url, title) => tapped.add((url, title)),
                        ),
                        onSurfaceAttach: attached.add,
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildTree());
        expect(parentBuilds, 1);
        final surface = attached.single as RenderSelectableParagraph;
        expect(surface.tappableRangeCount, 1);

        // Compute coordinates of the bold "Dart" inside the nested LinkInline
        // and the plain "Visit" outside the link.
        const fullText = 'Visit the Dart SDK page';
        final linkStart = fullText.indexOf('the Dart SDK');
        final linkBoxes = surface.boxesForLocalRange(
          linkStart,
          linkStart + 'the Dart SDK'.length,
        );
        expect(linkBoxes, isNotEmpty);
        final linkCenter = surface.localToGlobal(
          linkBoxes.first.toRect().center,
        );

        final plainBoxes = surface.boxesForLocalRange(0, 5);
        final plainCenter = surface.localToGlobal(
          plainBoxes.first.toRect().center,
        );

        // 1. Primary tap on nested link text triggers onLinkTap.
        await tester.tapAt(linkCenter);
        await tester.pump();
        expect(tapped, [('https://dart.dev', 'Dart')]);

        // 2. Tap outside link (on "Visit" and in trailing empty whitespace)
        //    does NOT trigger onLinkTap.
        await tester.tapAt(plainCenter);
        await tester.pump();
        final trailingWhitespace = surface.localToGlobal(
          Offset(surface.size.width - 4.0, plainBoxes.first.toRect().center.dy),
        );
        await tester.tapAt(trailingWhitespace);
        await tester.pump();
        expect(tapped, hasLength(1));

        // 3. Secondary (right-click) on link does NOT trigger onLinkTap.
        await tester.tapAt(linkCenter, buttons: kSecondaryMouseButton);
        await tester.pump();
        expect(tapped, hasLength(1));

        // 4. Desktop mouse hover applies hoverStyle underline & click cursor
        //    WITHOUT rebuilding parent MarkdownBlockRenderer!
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: plainCenter);
        await tester.pump();

        expect(surface.hoveredSpanIndex, isNull);
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.text,
        );

        await mouse.moveTo(linkCenter);
        await tester.pump();
        expect(parentBuilds, 1, reason: 'hover must not rebuild Markdown');
        expect(surface.hoveredSpanIndex, 0);
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.click,
        );

        // Verify the active rendered TextSpan contains underline decoration!
        var foundHoveredUnderline = false;
        surface.text.visitChildren((span) {
          if (span is TextSpan &&
              span.text == 'Dart' &&
              span.style?.decoration == TextDecoration.underline) {
            foundHoveredUnderline = true;
          }
          return true;
        });
        expect(foundHoveredUnderline, isTrue);

        // 5. Scrolling clears hover immediately.
        scrollController.jumpTo(50.0);
        await tester.pump();
        expect(surface.hoveredSpanIndex, isNull);

        // Scroll back, hover again, then test pointer exit clears hover.
        scrollController.jumpTo(0.0);
        await tester.pump();
        await mouse.moveTo(linkCenter);
        await tester.pump();
        expect(surface.hoveredSpanIndex, 0);

        await mouse.moveTo(const Offset(750, 550));
        await tester.pump();
        expect(surface.hoveredSpanIndex, isNull);

        // 6. Layout constraint change clears hover cleanly.
        await mouse.moveTo(linkCenter);
        await tester.pump();
        expect(surface.hoveredSpanIndex, 0);

        await tester.pumpWidget(buildTree(width: 220.0));
        await tester.pump();
        expect(surface.hoveredSpanIndex, isNull);
      },
    );

    testWidgets(
      'selection highlights, LeaderLayer handles, wrapped-line TextAffinity, hitsTextAtGlobal, and attach/detach',
      (tester) async {
        final attached = <MarkdownSelectionSurface>[];
        final detached = <MarkdownSelectionSurface>[];

        const text = 'Alpha Beta Gamma Delta Epsilon Zeta';
        final startLink = LayerLink();
        final endLink = LayerLink();

        await tester.pumpWidget(
          _wrapApp(
            width: 140.0,
            SelectableParagraph(
              documentId: 'docA',
              blockIndex: 2,
              textOffsetInBlock: 10,
              text: const TextSpan(
                text: text,
                style: TextStyle(fontSize: 14.0, height: 1.4),
              ),
              selectionColor: const Color(0x550088FF),
              onSurfaceAttach: attached.add,
              onSurfaceDetach: detached.add,
            ),
          ),
        );

        expect(attached, hasLength(1));
        expect(detached, isEmpty);
        final surface = attached.single as RenderSelectableParagraph;

        expect(surface.documentId, 'docA');
        expect(surface.blockIndex, 2);
        expect(surface.textOffsetInBlock, 10);
        expect(surface.textLength, text.length);
        expect(surface.globalBounds, isNotNull);

        // hitsTextAtGlobal is true on glyphs, false outside paragraph.
        final firstWordBox = surface.boxesForLocalRange(0, 5).first;
        expect(
          surface.hitsTextAtGlobal(
            surface.localToGlobal(firstWordBox.toRect().center),
          ),
          isTrue,
        );
        expect(surface.hitsTextAtGlobal(const Offset(790, 590)), isFalse);

        // Verify wrapped-line TextAffinity differs at the line wrap boundary.
        final firstLine = surface.lineRangeAtLocal(0);
        expect(firstLine.start, 0);
        expect(firstLine.end, lessThan(text.length));
        final secondLine = surface.lineRangeAtLocal(text.indexOf('Gamma'));
        expect(secondLine.start, greaterThan(0));
        final wrapBoundary = secondLine.start;
        final upstreamCaret = surface.caretRectForLocalOffset(
          wrapBoundary,
          affinity: TextAffinity.upstream,
        );
        final downstreamCaret = surface.caretRectForLocalOffset(
          wrapBoundary,
          affinity: TextAffinity.downstream,
        );
        expect(downstreamCaret.top, greaterThan(upstreamCaret.top));
        expect(
          surface.globalRectForLocalOffset(
            wrapBoundary,
            affinity: TextAffinity.downstream,
          ),
          isNotNull,
        );

        // Highlight & handle LeaderLayers.
        surface.setSelectionHighlightRange(const TextRange(start: 0, end: 10));
        surface.setSelectionHandleLayers(
          startHandleLayerLink: startLink,
          startHandleLocalOffset: 0,
          endHandleLayerLink: endLink,
          endHandleLocalOffset: firstLine.end,
        );
        expect(surface.hasSelectionHandleLeaders, isTrue);
        await tester.pump();

        expect(
          find.bySubtype<RichText>(),
          paints..rect(color: const Color(0x550088FF)),
        );

        // Clearing only startLink keeps endLink active.
        surface.clearSelectionHandleLayersIfLinked(
          startHandleLayerLink: startLink,
        );
        expect(surface.hasSelectionHandleLeaders, isTrue);
        surface.clearSelectionHandleLayersIfLinked(endHandleLayerLink: endLink);
        expect(surface.hasSelectionHandleLeaders, isFalse);
        await tester.pump();

        // Unmounting invokes onSurfaceDetach.
        await tester.pumpWidget(const SizedBox.shrink());
        expect(detached, [surface]);
      },
    );
  });

  group('Block renderers: lists, tables, details, alerts, code, footnotes, LaTeX', () {
    testWidgets(
      'Canvas list markers are excluded from selectable text and find.text',
      (tester) async {
        final attached = <MarkdownSelectionSurface>[];
        const block = ListBlock(
          ordered: true,
          start: 3,
          items: [
            ListItemNode(
              children: [
                ParagraphBlock(inlines: [TextInline('Third')]),
              ],
            ),
            ListItemNode(
              checked: true,
              children: [
                ParagraphBlock(inlines: [TextInline('Checked task')]),
              ],
            ),
            ListItemNode(
              checked: false,
              children: [
                ParagraphBlock(inlines: [TextInline('Parent')]),
                ListBlock(
                  ordered: false,
                  items: [
                    ListItemNode(
                      children: [
                        ParagraphBlock(inlines: [TextInline('Nested')]),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          _wrapApp(
            MarkdownBlockRenderer(
              documentId: 'doc1',
              blockIndex: 0,
              block: block,
              onSurfaceAttach: attached.add,
            ),
          ),
        );

        // Ordinal "3." is painted on Canvas, NEVER a Text/RichText widget!
        expect(find.text('3.', findRichText: true), findsNothing);
        expect(find.byType(MarkdownListItemWidget), findsNWidgets(4));

        final fullText = extractBlockRenderedText(block);
        expect(fullText, 'Third\nChecked task\nParent\nNested');
        expect(attached, hasLength(4));

        for (final surface in attached) {
          final render = surface as RenderSelectableParagraph;
          final slice = fullText.substring(
            surface.textOffsetInBlock,
            surface.textOffsetInBlock + surface.textLength,
          );
          expect(slice, render.baseText.toPlainText());
        }
      },
    );

    testWidgets(
      'MarkdownTableWidget fits narrow tables and horizontally scrolls wide tables without overflow',
      (tester) async {
        final narrowTable = const TableBlock(
          alignments: [TableColumnAlign.left, TableColumnAlign.right],
          header: TableRowNode(
            cells: [
              [TextInline('A')],
              [TextInline('B')],
            ],
          ),
          rows: [
            TableRowNode(
              cells: [
                [TextInline('1')],
                [TextInline('2')],
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          _wrapApp(
            width: 400.0,
            MarkdownBlockRenderer(
              documentId: 'doc1',
              blockIndex: 0,
              block: narrowTable,
            ),
          ),
        );
        expect(find.byType(MarkdownTableWidget), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsNothing);

        // Wide 6-column table inside a narrow 220px viewport must scroll
        // horizontally with zero overflow exceptions.
        final wideTable = TableBlock(
          alignments: List.filled(6, TableColumnAlign.left),
          header: TableRowNode(
            cells: [
              for (var i = 1; i <= 6; i++) [TextInline('Column Header $i')],
            ],
          ),
          rows: [
            TableRowNode(
              cells: [
                for (var i = 1; i <= 6; i++) [TextInline('Cell Value $i')],
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          _wrapApp(
            width: 220.0,
            MarkdownBlockRenderer(
              documentId: 'doc1',
              blockIndex: 0,
              block: wideTable,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final scrollViewFinder = find.byType(SingleChildScrollView);
        expect(scrollViewFinder, findsOneWidget);
        final scrollView = tester.widget<SingleChildScrollView>(
          scrollViewFinder,
        );
        expect(scrollView.scrollDirection, Axis.horizontal);

        // Dragging horizontally scrolls cleanly.
        await tester.drag(scrollViewFinder, const Offset(-120, 0));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'MarkdownDetailsWidget expands and collapses and preserves offsets',
      (tester) async {
        final attached = <MarkdownSelectionSurface>[];
        final detached = <MarkdownSelectionSurface>[];

        const block = HtmlDetailsBlock(
          initiallyOpen: false,
          summary: [TextInline('More info')],
          children: [
            ParagraphBlock(inlines: [TextInline('Hidden paragraph')]),
            CodeBlock(code: 'final x = 1;', language: 'dart'),
          ],
        );

        await tester.pumpWidget(
          _wrapApp(
            MarkdownBlockRenderer(
              documentId: 'doc1',
              blockIndex: 0,
              block: block,
              onSurfaceAttach: attached.add,
              onSurfaceDetach: detached.add,
            ),
          ),
        );

        // Initially collapsed: only summary surface attached.
        expect(find.byType(MarkdownDetailsWidget), findsOneWidget);
        expect(attached, hasLength(1));
        expect(find.text('Hidden paragraph', findRichText: true), findsNothing);

        // Tap summary to expand.
        await tester.tap(find.text('More info', findRichText: true));
        await tester.pumpAndSettle();

        expect(
          find.text('Hidden paragraph', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('final x = 1;', findRichText: true), findsOneWidget);
        expect(attached, hasLength(3));

        final fullText = extractBlockRenderedText(block);
        expect(fullText, 'More info\nHidden paragraph\nfinal x = 1;');
        for (final surface in attached) {
          final render = surface as RenderSelectableParagraph;
          expect(
            fullText.substring(
              surface.textOffsetInBlock,
              surface.textOffsetInBlock + surface.textLength,
            ),
            render.baseText.toPlainText(),
          );
        }

        // Tap again to collapse: body surfaces detach.
        await tester.tap(find.text('More info', findRichText: true));
        await tester.pumpAndSettle();
        expect(find.text('Hidden paragraph', findRichText: true), findsNothing);
        expect(detached, hasLength(2));
      },
    );

    testWidgets(
      'renders all AlertKinds, codeBlockBuilder, footnotes, and LaTeX fallback',
      (tester) async {
        // 1. All 5 AlertKinds render without non-uniform border errors.
        for (final kind in AlertKind.values) {
          final attached = <MarkdownSelectionSurface>[];
          final alert = AlertBlock(
            kind: kind,
            children: const [
              ParagraphBlock(inlines: [TextInline('Alert body')]),
            ],
          );
          await tester.pumpWidget(
            _wrapApp(
              MarkdownBlockRenderer(
                key: ValueKey(kind),
                documentId: 'doc1',
                blockIndex: 0,
                block: alert,
                onSurfaceAttach: attached.add,
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text(kind.name.toUpperCase()), findsOneWidget);
          expect(attached, hasLength(1));
          expect(attached.single.textOffsetInBlock, 0);
          expect(attached.single.textLength, 'Alert body'.length);
        }

        // 2. codeBlockBuilder & codeHighlighter preserve selection on codeContent only.
        final codeAttached = <MarkdownSelectionSurface>[];
        var receivedLanguage = '';
        await tester.pumpWidget(
          _wrapApp(
            MarkdownBlockRenderer(
              documentId: 'doc1',
              blockIndex: 0,
              block: const CodeBlock(code: 'print(42);', language: 'dart'),
              builders: MarkdownBuilders(
                codeHighlighter: (context, block, base) => [
                  TextSpan(
                    text: block.code,
                    style: base.copyWith(color: const Color(0xFF00AA00)),
                  ),
                ],
                codeBlockBuilder: (context, block, codeContent, theme) {
                  receivedLanguage = block.language ?? '';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('HEADER: ${block.language}'), codeContent],
                  );
                },
              ),
              onSurfaceAttach: codeAttached.add,
            ),
          ),
        );
        expect(receivedLanguage, 'dart');
        expect(find.text('HEADER: dart'), findsOneWidget);
        expect(codeAttached, hasLength(1));
        expect(codeAttached.single.textLength, 'print(42);'.length);

        // 3. Footnotes exclude "[1]" display label from selection surfaces.
        final fnAttached = <MarkdownSelectionSurface>[];
        const footnotes = FootnoteDefinitionsBlock(
          definitions: [
            FootnoteDefinition(
              label: '1',
              index: 1,
              children: [
                ParagraphBlock(inlines: [TextInline('First note')]),
              ],
            ),
            FootnoteDefinition(
              label: '2',
              index: 2,
              children: [
                ParagraphBlock(inlines: [TextInline('Second note')]),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          _wrapApp(
            MarkdownBlockRenderer(
              documentId: 'doc1',
              blockIndex: 0,
              block: footnotes,
              onSurfaceAttach: fnAttached.add,
            ),
          ),
        );
        expect(find.text('[1]'), findsOneWidget);
        expect(find.text('[2]'), findsOneWidget);
        expect(fnAttached, hasLength(2));
        final fnText = extractBlockRenderedText(footnotes);
        expect(fnText, 'First note\nSecond note');
        expect(fnAttached[0].textOffsetInBlock, 0);
        expect(fnAttached[1].textOffsetInBlock, 'First note\n'.length);

        // 4. LaTeX fallback formats Unicode cleanly while keeping canonical offsets.
        expect(formatLatexFallback(r'\alpha + \beta \leq \infty'), 'α + β ≤ ∞');
        expect(
          formatLatexFallback(r'x^2 + y_0 = \frac{a}{b}'),
          'x² + y₀ = a/b',
        );

        final latexAttached = <MarkdownSelectionSurface>[];
        const latexBlock = BlockLatexBlock(expression: r'\alpha + \beta');
        await tester.pumpWidget(
          _wrapApp(
            MarkdownBlockRenderer(
              documentId: 'doc1',
              blockIndex: 0,
              block: latexBlock,
              onSurfaceAttach: latexAttached.add,
            ),
          ),
        );
        expect(find.text('α + β', findRichText: true), findsOneWidget);
        expect(latexAttached, hasLength(1));
        expect(latexAttached.single.textLength, r'\alpha + \beta'.length);
      },
    );

    testWidgets(
      'custom builders (inlineLink, table, alert, latex, customInline), summary-less details, and rounded blockquote',
      (tester) async {
        // 1. Custom inlineLinkBuilder, inlineLatexBuilder, customInlineBuilder
        final inlineAttached = <MarkdownSelectionSurface>[];
        const richPara = ParagraphBlock(
          inlines: [
            LinkInline(
              destination: 'https://example.com',
              children: [TextInline('Go')],
            ),
            TextInline(' '),
            InlineLatexInline(r'\pi'),
            TextInline(' '),
            CustomInline(kind: 'file_path', text: 'lib/a.dart'),
          ],
        );

        await tester.pumpWidget(
          _wrapApp(
            MarkdownBlockRenderer(
              documentId: 'custom',
              blockIndex: 0,
              block: richPara,
              builders: MarkdownBuilders(
                inlineLinkBuilder: (_, link, spans, style, onTap) =>
                    TappableTextSpan(
                      children: spans,
                      style: style.copyWith(fontWeight: FontWeight.w700),
                      onTap: onTap,
                    ),
                inlineLatexBuilder: (_, latex, style) =>
                    TextSpan(text: 'PI', style: style),
                customInlineBuilder: (_, inline, style) => TextSpan(
                  text: inline.text,
                  style: style.copyWith(color: const Color(0xFFAA00AA)),
                ),
              ),
              onSurfaceAttach: inlineAttached.add,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(inlineAttached, hasLength(1));
        expect(
          inlineAttached.single.textLength,
          extractBlockRenderedText(richPara).length,
        );

        // 2. Custom tableBuilder, alertBuilder, blockLatexBuilder
        await tester.pumpWidget(
          _wrapApp(
            Column(
              children: [
                MarkdownBlockRenderer(
                  documentId: 'custom',
                  blockIndex: 1,
                  block: const TableBlock(
                    alignments: [TableColumnAlign.left],
                    header: TableRowNode(
                      cells: [
                        [TextInline('H')],
                      ],
                    ),
                    rows: [],
                  ),
                  builders: MarkdownBuilders(
                    tableBuilder: (_, _, _) => const Text('CUSTOM_TABLE'),
                  ),
                ),
                MarkdownBlockRenderer(
                  documentId: 'custom',
                  blockIndex: 2,
                  block: const AlertBlock(
                    kind: AlertKind.tip,
                    children: [
                      ParagraphBlock(inlines: [TextInline('Tip body')]),
                    ],
                  ),
                  builders: MarkdownBuilders(
                    alertBuilder: (_, alert, body, _) => Column(
                      children: [Text('CUSTOM_${alert.kind.name}'), body],
                    ),
                  ),
                ),
                MarkdownBlockRenderer(
                  documentId: 'custom',
                  blockIndex: 3,
                  block: const BlockLatexBlock(expression: 'E=mc^2'),
                  builders: MarkdownBuilders(
                    blockLatexBuilder: (_, latex, _) =>
                        Text('MATH:${latex.expression}'),
                  ),
                ),
              ],
            ),
          ),
        );
        expect(find.text('CUSTOM_TABLE'), findsOneWidget);
        expect(find.text('CUSTOM_tip'), findsOneWidget);
        expect(find.text('Tip body', findRichText: true), findsOneWidget);
        expect(find.text('MATH:E=mc^2'), findsOneWidget);

        // 3. Summary-less <details open> keeps child offset at 0, and
        //    rounded BlockquoteBlock renders cleanly without border assertion.
        final detailsAttached = <MarkdownSelectionSurface>[];
        await tester.pumpWidget(
          _wrapApp(
            theme: MarkdownThemeData.fallback().copyWith(
              blockquoteStyle: const MarkdownBlockquoteStyle(
                backgroundColor: Color(0x11000000),
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
              ),
            ),
            Column(
              children: [
                MarkdownBlockRenderer(
                  documentId: 'd',
                  blockIndex: 0,
                  block: const HtmlDetailsBlock(
                    initiallyOpen: true,
                    summary: [],
                    children: [
                      ParagraphBlock(inlines: [TextInline('Body only')]),
                    ],
                  ),
                  onSurfaceAttach: detailsAttached.add,
                ),
                const MarkdownBlockRenderer(
                  documentId: 'd',
                  blockIndex: 1,
                  block: BlockquoteBlock(
                    children: [
                      ParagraphBlock(inlines: [TextInline('Rounded quote')]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Details'), findsOneWidget);
        expect(detailsAttached, hasLength(1));
        expect(detailsAttached.single.textOffsetInBlock, 0);
        expect(detailsAttached.single.textLength, 'Body only'.length);
      },
    );

    testWidgets(
      'exhaustive 1-to-1 textOffsetInBlock alignment with extractBlockRenderedText across all parsed block types',
      (tester) async {
        const md = r'''
# Heading One

Paragraph with **bold**, *italic*, ~~strike~~, <u>under</u>, `code`, <kbd>Cmd</kbd>, and [link](https://example.com)[^1].

```dart
void main() {
  print('hi');
}
```

> Quoted first paragraph.
>
> Quoted second paragraph.

> [!WARNING]
> Be careful!
>
> - Warning bullet A
> - Warning bullet B

- Item one
  - Sub item 1
  - Sub item 2
- [x] Done task
- [ ] Todo task

1. First ordered
2. Second ordered

| Left | Center | Right |
| :--- | :----: | ----: |
| a | **b** | |
| 1 | 2 | 3 |

---

<details open>
<summary>Toggle **summary**</summary>

Details paragraph.

- Details list 1
- Details list 2
</details>

\[
\alpha + \beta = \gamma
\]

[^1]: Footnote explanation.
''';

        final parser = GfmMarkdownParser();
        final doc = parser.parse(md);
        expect(doc.blocks.length, greaterThanOrEqualTo(10));

        final surfacesByBlock = <int, List<MarkdownSelectionSurface>>{};

        await tester.pumpWidget(
          _wrapApp(
            width: 500.0,
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < doc.blocks.length; i++)
                    MarkdownBlockRenderer(
                      documentId: 'full-doc',
                      blockIndex: i,
                      block: doc.blocks[i],
                      onSurfaceAttach: (surface) {
                        surfacesByBlock
                            .putIfAbsent(surface.blockIndex, () => [])
                            .add(surface);
                      },
                    ),
                ],
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        for (var i = 0; i < doc.blocks.length; i++) {
          final block = doc.blocks[i];
          final canonicalBlockText = extractBlockRenderedText(block);
          final surfaces = surfacesByBlock[i] ?? const [];

          if (block is ThematicBreakBlock) {
            expect(canonicalBlockText, isEmpty);
            expect(surfaces, isEmpty);
            continue;
          }

          expect(
            surfaces,
            isNotEmpty,
            reason: 'Block #$i ($block) must attach at least one surface',
          );

          // Verify surfaces are non-overlapping and strictly within bounds.
          final sorted = surfaces.toList()
            ..sort(
              (a, b) => a.textOffsetInBlock.compareTo(b.textOffsetInBlock),
            );

          var previousEnd = 0;
          for (final surface in sorted) {
            final start = surface.textOffsetInBlock;
            final end = start + surface.textLength;
            expect(
              start,
              greaterThanOrEqualTo(previousEnd),
              reason: 'Overlapping surfaces in block #$i ($block)',
            );
            expect(
              end,
              lessThanOrEqualTo(canonicalBlockText.length),
              reason: 'Surface out of range in block #$i ($block)',
            );

            // Every gap between consecutive surfaces in a block must be a
            // canonical separator ('\n' or '\t', possibly multiple '\t' for
            // empty table cells).
            if (start > previousEnd) {
              final gap = canonicalBlockText.substring(previousEnd, start);
              expect(
                RegExp(r'^[\n\t]+$').hasMatch(gap),
                isTrue,
                reason:
                    'Unexpected non-separator gap "$gap" in block #$i ($block)',
              );
            }

            // For identity-mapped surfaces, rendered plain text must match the
            // canonical slice verbatim!
            final render = surface as RenderSelectableParagraph;
            if (render.offsetMapping.isIdentity) {
              expect(
                canonicalBlockText.substring(start, end),
                render.baseText.toPlainText(),
                reason: 'Text mismatch in block #$i ($block)',
              );
            }

            previousEnd = end;
          }

          // Trailing gap (if any) may only be empty-cell separators (e.g.
          // trailing empty cell after '\t' in a table row).
          if (previousEnd < canonicalBlockText.length) {
            final tail = canonicalBlockText.substring(previousEnd);
            expect(
              RegExp(r'^[\n\t]+$').hasMatch(tail),
              isTrue,
              reason: 'Uncovered trailing text "$tail" in block #$i ($block)',
            );
          }
        }
      },
    );
  });

  group(
    'Verifier regressions: textScaler, surface identity, stretched narrow tables',
    () {
      testWidgets(
        'SelectableParagraph and MarkdownListItemWidget inherit MediaQuery textScaler unless overridden',
        (tester) async {
          final normalSurfaces = <MarkdownSelectionSurface>[];
          final scaledSurfaces = <MarkdownSelectionSurface>[];
          const listBlock = ListBlock(
            ordered: true,
            start: 1,
            items: [
              ListItemNode(
                children: [
                  ParagraphBlock(inlines: [TextInline('Scaled item')]),
                ],
              ),
            ],
          );

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(800, 600),
                  textScaler: TextScaler.noScaling,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 400,
                    child: MarkdownBlockRenderer(
                      documentId: 'doc',
                      blockIndex: 0,
                      block: listBlock,
                      onSurfaceAttach: normalSurfaces.add,
                    ),
                  ),
                ),
              ),
            ),
          );

          final normalRender =
              normalSurfaces.single as RenderSelectableParagraph;
          final normalBox = normalRender.boxesForLocalRange(0, 11).first;
          expect(normalRender.textScaler, TextScaler.noScaling);

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(800, 600),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 400,
                    child: MarkdownBlockRenderer(
                      key: const ValueKey('scaled'),
                      documentId: 'doc',
                      blockIndex: 0,
                      block: listBlock,
                      onSurfaceAttach: scaledSurfaces.add,
                    ),
                  ),
                ),
              ),
            ),
          );

          final scaledRender =
              scaledSurfaces.single as RenderSelectableParagraph;
          final scaledBox = scaledRender.boxesForLocalRange(0, 11).first;
          expect(scaledRender.textScaler, const TextScaler.linear(2.0));
          expect(scaledBox.right, greaterThan(normalBox.right * 1.5));

          final listItemRender = tester.renderObject<RenderMarkdownListItem>(
            find.byType(MarkdownListItemWidget),
          );
          expect(listItemRender.textScaler, const TextScaler.linear(2.0));

          // Explicit textScaler override still wins over MediaQuery.
          final explicitSurfaces = <MarkdownSelectionSurface>[];
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(800, 600),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: SelectableParagraph(
                  documentId: 'doc',
                  blockIndex: 0,
                  textOffsetInBlock: 0,
                  text: const TextSpan(text: 'Fixed'),
                  textScaler: TextScaler.noScaling,
                  onSurfaceAttach: explicitSurfaces.add,
                ),
              ),
            ),
          );
          expect(
            (explicitSurfaces.single as RenderSelectableParagraph).textScaler,
            TextScaler.noScaling,
          );
        },
      );

      testWidgets(
        'updateSurfaceIdentity re-registers on blockIndex/offset shifts, null attach, and controller switches',
        (tester) async {
          final controllerA = _RecordingSurfaceController('A');
          final controllerB = _RecordingSurfaceController('B');

          Widget buildParagraph({
            int blockIndex = 0,
            int offset = 0,
            _RecordingSurfaceController? controller,
          }) {
            return _wrapApp(
              SelectableParagraph(
                documentId: 'doc1',
                blockIndex: blockIndex,
                textOffsetInBlock: offset,
                text: const TextSpan(text: 'Hello'),
                onSurfaceAttach: controller?.attach,
                onSurfaceDetach: controller?.detach,
              ),
            );
          }

          // Initial attach on controllerA.
          await tester.pumpWidget(buildParagraph(controller: controllerA));
          expect(controllerA.events, [('attach', 0, 0)]);

          // Rebuilding with identical controller tear-offs and coordinates does not churn.
          await tester.pumpWidget(buildParagraph(controller: controllerA));
          expect(controllerA.events, [('attach', 0, 0)]);

          // Shifting blockIndex detaches old coordinate and re-attaches new one.
          await tester.pumpWidget(
            buildParagraph(blockIndex: 2, controller: controllerA),
          );
          expect(controllerA.events, [
            ('attach', 0, 0),
            ('detach', 0, 0),
            ('attach', 2, 0),
          ]);

          // Shifting textOffsetInBlock detaches old offset and re-attaches new one.
          await tester.pumpWidget(
            buildParagraph(blockIndex: 2, offset: 15, controller: controllerA),
          );
          expect(controllerA.events, [
            ('attach', 0, 0),
            ('detach', 0, 0),
            ('attach', 2, 0),
            ('detach', 2, 0),
            ('attach', 2, 15),
          ]);

          // Switching controller tear-offs detaches from A and attaches to B.
          await tester.pumpWidget(
            buildParagraph(blockIndex: 2, offset: 15, controller: controllerB),
          );
          expect(controllerA.events.last, ('detach', 2, 15));
          expect(controllerB.events, [('attach', 2, 15)]);

          // Clearing onSurfaceAttach to null detaches from B.
          await tester.pumpWidget(
            buildParagraph(blockIndex: 2, offset: 15, controller: null),
          );
          expect(controllerB.events, [('attach', 2, 15), ('detach', 2, 15)]);

          // Restoring controllerB re-attaches cleanly.
          await tester.pumpWidget(
            buildParagraph(blockIndex: 2, offset: 15, controller: controllerB),
          );
          expect(controllerB.events, [
            ('attach', 2, 15),
            ('detach', 2, 15),
            ('attach', 2, 15),
          ]);
        },
      );

      testWidgets(
        'narrow MarkdownTableWidget under CrossAxisAlignment.stretch hugs Table width without stretching outer border',
        (tester) async {
          const narrowTable = TableBlock(
            alignments: [TableColumnAlign.left, TableColumnAlign.left],
            header: TableRowNode(
              cells: [
                [TextInline('K')],
                [TextInline('V')],
              ],
            ),
            rows: [
              TableRowNode(
                cells: [
                  [TextInline('a')],
                  [TextInline('b')],
                ],
              ),
            ],
          );

          await tester.pumpWidget(
            _wrapApp(
              width: 400.0,
              const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MarkdownBlockRenderer(
                    documentId: 'doc1',
                    blockIndex: 0,
                    block: narrowTable,
                  ),
                ],
              ),
            ),
          );

          expect(find.byType(SingleChildScrollView), findsNothing);
          final tableSize = tester.getSize(find.byType(Table));
          final clipSize = tester.getSize(find.byType(ClipRRect));

          expect(tableSize.width, lessThan(300.0));
          expect(
            clipSize.width,
            closeTo(tableSize.width, 0.01),
            reason: 'Outer bordered frame must not stretch past narrow Table',
          );
        },
      );

      testWidgets(
        'checked task-list checkbox computes contrasting checkmark in dark mode and honors custom theme colors',
        (tester) async {
          const taskListBlock = ListBlock(
            ordered: false,
            items: [
              ListItemNode(
                checked: true,
                children: [
                  ParagraphBlock(inlines: [TextInline('Completed task')]),
                ],
              ),
              ListItemNode(
                checked: false,
                children: [
                  ParagraphBlock(inlines: [TextInline('Open task')]),
                ],
              ),
            ],
          );

          // 1. Dark-mode near-white listBulletColor without custom checkbox
          //    colors must paint a contrasting dark checkmark (NOT white-on-white).
          final darkNearWhiteTheme = MarkdownThemeData.dark().copyWith(
            listBulletColor: const Color(0xFFF5F5F5),
          );
          await tester.pumpWidget(
            _wrapApp(
              theme: darkNearWhiteTheme,
              const MarkdownBlockRenderer(
                documentId: 'tasks-dark',
                blockIndex: 0,
                block: taskListBlock,
              ),
            ),
          );

          final checkedFinder = find.byWidgetPredicate(
            (w) =>
                w is MarkdownListItemWidget &&
                w.markerKind == MarkdownListMarkerKind.taskChecked,
          );
          expect(checkedFinder, findsOneWidget);
          expect(
            checkedFinder,
            paints
              ..rrect(color: const Color(0xFFF5F5F5))
              ..path(color: const Color(0xFF000000)),
          );

          // 2. Dark fill (light-mode default) paints a white checkmark.
          final lightDarkFillTheme = MarkdownThemeData.fallback().copyWith(
            listBulletColor: const Color(0xFF1F2328),
          );
          await tester.pumpWidget(
            _wrapApp(
              theme: lightDarkFillTheme,
              const MarkdownBlockRenderer(
                documentId: 'tasks-light',
                blockIndex: 0,
                block: taskListBlock,
              ),
            ),
          );
          expect(
            checkedFinder,
            paints
              ..rrect(color: const Color(0xFF1F2328))
              ..path(color: const Color(0xFFFFFFFF)),
          );

          // 3. Explicit listCheckboxFillColor / listCheckboxCheckColor override
          //    both fill and checkmark stroke, and participate in copyWith / ==.
          const customFill = Color(0xFFF97316);
          const customCheck = Color(0xFF112233);
          final customTheme = MarkdownThemeData.dark().copyWith(
            listCheckboxFillColor: customFill,
            listCheckboxCheckColor: customCheck,
          );
          expect(customTheme, isNot(equals(MarkdownThemeData.dark())));
          expect(
            customTheme,
            equals(
              MarkdownThemeData.dark().copyWith(
                listCheckboxFillColor: customFill,
                listCheckboxCheckColor: customCheck,
              ),
            ),
          );
          expect(
            customTheme.hashCode,
            equals(
              MarkdownThemeData.dark()
                  .copyWith(
                    listCheckboxFillColor: customFill,
                    listCheckboxCheckColor: customCheck,
                  )
                  .hashCode,
            ),
          );

          await tester.pumpWidget(
            _wrapApp(
              theme: customTheme,
              const MarkdownBlockRenderer(
                documentId: 'tasks-custom',
                blockIndex: 0,
                block: taskListBlock,
              ),
            ),
          );
          expect(
            checkedFinder,
            paints
              ..rrect(color: customFill)
              ..path(color: customCheck),
          );
        },
      );
    },
  );
}

class _RecordingSurfaceController {
  _RecordingSurfaceController(this.id);

  final String id;
  final List<(String, int, int)> events = [];

  void attach(MarkdownSelectionSurface surface) {
    events.add(('attach', surface.blockIndex, surface.textOffsetInBlock));
  }

  void detach(MarkdownSelectionSurface surface) {
    events.add(('detach', surface.blockIndex, surface.textOffsetInBlock));
  }
}
