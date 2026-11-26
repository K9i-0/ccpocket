// Extra SliverMarkdownView coverage: laziness, cache extent, data swaps while
// scrolled, spacing, and degenerate block counts.
//
// Provenance (behaviours mined by name from the reference suites, rewritten
// against markdown_kit's API):
// - gpt_markdown plusparse/sliver_test.dart "long documents build only
//   viewport segments and scroll correctly", "... preserves a single
//   document" (high)
// - gpt_markdown regression/block_spacing_test.dart "SliverGptMarkdown agrees
//   with GptMarkdown" (high)
// - gpt_markdown regression/inline_patterns_code_and_autolink_test.dart "the
//   sliver view skips code spans too" (low; as builder parity)
// - flutter_md widget/render_test.dart "empty markdown produces zero size"
//   (medium)
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

const _viewport = Size(420, 400);

Widget _app({
  required List<Widget> slivers,
  ScrollController? controller,
  Size size = _viewport,
  double? cacheExtent,
  ui.TextDirection dir = ui.TextDirection.ltr,
  TextScaler scaler = TextScaler.noScaling,
  bool withScope = true,
  MarkdownSelectionController? selection,
}) {
  Widget scroll = CustomScrollView(
    controller: controller,
    scrollCacheExtent: cacheExtent == null
        ? null
        : ScrollCacheExtent.pixels(cacheExtent),
    slivers: slivers,
  );
  if (withScope) {
    scroll = MarkdownSelectionScope(controller: selection, child: scroll);
  }
  return Directionality(
    textDirection: dir,
    child: MediaQuery(
      data: MediaQueryData(size: size, textScaler: scaler),
      child: FocusScope(
        autofocus: true,
        child: _OverlayShell(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: scroll,
            ),
          ),
        ),
      ),
    ),
  );
}

class _OverlayShell extends StatefulWidget {
  const _OverlayShell({required this.child});

  final Widget child;

  @override
  State<_OverlayShell> createState() => _OverlayShellState();
}

class _OverlayShellState extends State<_OverlayShell> {
  late final ValueNotifier<Widget> _child = ValueNotifier<Widget>(widget.child);
  late final OverlayEntry _entry = OverlayEntry(
    builder: (_) => ValueListenableBuilder<Widget>(
      valueListenable: _child,
      builder: (_, child, _) => child,
    ),
  );

  @override
  void didUpdateWidget(covariant _OverlayShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _child.value = widget.child;
  }

  @override
  void dispose() {
    _child.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

List<String> _texts(WidgetTester tester) => [
  for (final ro in tester.allRenderObjects)
    if (ro is RenderSelectableParagraph) ro.text.toPlainText(),
];

RenderSelectableParagraph _para(WidgetTester tester, String substring) {
  for (final ro in tester.allRenderObjects) {
    if (ro is RenderSelectableParagraph &&
        ro.text.toPlainText().contains(substring)) {
      return ro;
    }
  }
  fail('No RenderSelectableParagraph containing "$substring".');
}

List<String> _drain(WidgetTester tester) {
  final out = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    out.add(e.toString().split('\n').take(3).join(' / '));
  }
  return out;
}

String _paragraphs(int count, {String prefix = 'Paragraph'}) => [
  for (var i = 0; i < count; i++) '$prefix ${i.toString().padLeft(3, '0')}',
].join('\n\n');

Finder _block(String docId, int index) =>
    find.byKey(ValueKey<String>('$docId:$index'));

void main() {
  group('degenerate block counts', () {
    for (final entry in {
      'an empty string': '',
      'only whitespace': '\n \n\t\n',
      'only an HTML comment': '<!-- nothing -->',
    }.entries) {
      testWidgets('${entry.key} builds no blocks and no scroll extent', (
        tester,
      ) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final built = <int>[];
        await tester.pumpWidget(
          _app(
            controller: controller,
            slivers: [
              SliverMarkdownView(
                data: entry.value,
                onBlockBuilt: (i, _) => built.add(i),
              ),
            ],
          ),
        );
        expect(_drain(tester), isEmpty);
        expect(built, isEmpty);
        expect(find.byType(MarkdownBlockRenderer), findsNothing);
        expect(controller.position.maxScrollExtent, 0.0);
      });
    }

    testWidgets('a single block renders at the top with no spacing', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          controller: controller,
          slivers: const [
            SliverMarkdownView(documentId: 'single', data: 'Only block'),
          ],
        ),
      );
      expect(_texts(tester), ['Only block']);
      expect(tester.getTopLeft(_block('single', 0)), Offset.zero);
      expect(controller.position.maxScrollExtent, 0.0);
    });

    testWidgets('empty slivers sit harmlessly between other slivers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          slivers: const [
            SliverToBoxAdapter(child: SizedBox(height: 30, child: Text('top'))),
            SliverMarkdownView(data: ''),
            SliverToBoxAdapter(
              child: SizedBox(height: 30, child: Text('bottom')),
            ),
          ],
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(tester.getTopLeft(find.text('bottom')).dy, 30.0);
    });

    testWidgets('it works without a MarkdownSelectionScope ancestor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          withScope: false,
          slivers: const [SliverMarkdownView(data: '# Title\n\nbody')],
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(_texts(tester), ['Title', 'body']);
    });
  });

  group('lazy building', () {
    testWidgets('a long document builds only what the viewport needs', (
      tester,
    ) async {
      final built = <int>{};
      await tester.pumpWidget(
        _app(
          cacheExtent: 0,
          slivers: [
            SliverMarkdownView(
              data: _paragraphs(400),
              onBlockBuilt: (i, _) => built.add(i),
            ),
          ],
        ),
      );
      // 400lp viewport, 23lp lines + 12lp spacing: about a dozen blocks.
      expect(built.length, lessThan(20));
      expect(built, contains(0));
      expect(built.reduce((a, b) => a > b ? a : b), lessThan(20));
      expect(
        find.byType(MarkdownBlockRenderer).evaluate().length,
        lessThan(20),
      );
    });

    testWidgets('a larger cache extent builds more, never fewer', (
      tester,
    ) async {
      Future<int> builtWith(double extent) async {
        final built = <int>{};
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _app(
            cacheExtent: extent,
            slivers: [
              SliverMarkdownView(
                data: _paragraphs(400),
                onBlockBuilt: (i, _) => built.add(i),
              ),
            ],
          ),
        );
        return built.length;
      }

      final none = await builtWith(0);
      final some = await builtWith(400);
      final lots = await builtWith(2000);
      expect(some, greaterThan(none));
      expect(lots, greaterThan(some));
      expect(lots, lessThan(400));
    });

    testWidgets('scrolling builds the blocks that come into view and drops '
        'the ones that leave', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          controller: controller,
          cacheExtent: 0,
          slivers: [
            SliverMarkdownView(documentId: 'lazy', data: _paragraphs(400)),
          ],
        ),
      );
      expect(_block('lazy', 0), findsOneWidget);
      expect(_block('lazy', 200), findsNothing);

      controller.jumpTo(controller.position.maxScrollExtent / 2);
      await tester.pump();
      expect(_block('lazy', 0), findsNothing);
      final mid = _texts(tester);
      expect(mid, isNotEmpty);
      expect(mid.length, lessThan(20));

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(_texts(tester).last, 'Paragraph 399');
      expect(
        tester.getRect(_block('lazy', 399)).bottom,
        closeTo(_viewport.height, 0.01),
      );

      controller.jumpTo(0);
      await tester.pump();
      expect(_texts(tester).first, 'Paragraph 000');
      expect(tester.getTopLeft(_block('lazy', 0)), Offset.zero);
      expect(_drain(tester), isEmpty);
    });

    testWidgets('onBlockBuilt reports the index together with its block', (
      tester,
    ) async {
      final seen = <int, MarkdownBlock>{};
      await tester.pumpWidget(
        _app(
          slivers: [
            SliverMarkdownView(
              data: '# Title\n\nbody\n\n- item',
              onBlockBuilt: (i, block) => seen[i] = block,
            ),
          ],
        ),
      );
      expect(seen[0], isA<HeadingBlock>());
      expect(seen[1], isA<ParagraphBlock>());
      expect(seen[2], isA<ListBlock>());
    });
  });

  group('spacing', () {
    const data = '# Title\n\nbody text\n\n- item\n\n```\ncode\n```\n\n> quote';

    testWidgets('consecutive blocks are separated by blockSpacing only', (
      tester,
    ) async {
      for (final spacing in [0.0, 12.0, 28.0]) {
        await tester.pumpWidget(
          _app(
            slivers: [
              SliverMarkdownView(
                documentId: 'gap-$spacing',
                data: data,
                theme: MarkdownThemeData.fallback().copyWith(
                  blockSpacing: spacing,
                ),
              ),
            ],
          ),
        );
        expect(tester.getTopLeft(_block('gap-$spacing', 0)).dy, 0.0);
        for (var i = 1; i < 5; i++) {
          expect(
            tester.getRect(_block('gap-$spacing', i)).top -
                tester.getRect(_block('gap-$spacing', i - 1)).bottom,
            closeTo(spacing, 0.01),
            reason: 'spacing $spacing before block $i',
          );
        }
      }
    });

    testWidgets('the sliver is exactly as tall as a MarkdownView', (
      tester,
    ) async {
      final long =
          '$data\n\n${_paragraphs(30)}\n\n| a | b |\n| - | - |\n| c | d |';
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          controller: controller,
          cacheExtent: 100000,
          slivers: [SliverMarkdownView(data: long)],
        ),
      );
      final sliverExtent =
          controller.position.maxScrollExtent +
          controller.position.viewportDimension;

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(
          slivers: [SliverToBoxAdapter(child: MarkdownView(data: long))],
        ),
      );
      expect(
        sliverExtent,
        closeTo(tester.getSize(find.byType(MarkdownView)).height, 0.01),
      );
    });

    testWidgets('blocks are laid out at the full cross-axis width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          slivers: const [SliverMarkdownView(documentId: 'width', data: data)],
        ),
      );
      for (var i = 0; i < 5; i++) {
        expect(tester.getRect(_block('width', i)).left, 0.0);
        expect(
          tester.getRect(_block('width', i)).right,
          lessThanOrEqualTo(420.0),
        );
      }
      expect(_drain(tester), isEmpty);
    });

    testWidgets('SliverPadding around the sliver insets every block', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          slivers: const [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 20, 24, 0),
              sliver: SliverMarkdownView(documentId: 'padded', data: data),
            ),
          ],
        ),
      );
      expect(tester.getTopLeft(_block('padded', 0)), const Offset(16, 20));
      // The code block stretches across the padded width.
      expect(tester.getRect(_block('padded', 3)).right, 420.0 - 24.0);
    });
  });

  group('data swaps while scrolled', () {
    testWidgets('swapping to a shorter document clamps the scroll offset', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget build(String data) => _app(
        controller: controller,
        slivers: [SliverMarkdownView(documentId: 'swap', data: data)],
      );
      await tester.pumpWidget(build(_paragraphs(300)));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(_texts(tester).last, 'Paragraph 299');

      await tester.pumpWidget(build(_paragraphs(3, prefix: 'Short')));
      await tester.pumpAndSettle();
      expect(_drain(tester), isEmpty);
      expect(_texts(tester), ['Short 000', 'Short 001', 'Short 002']);
      expect(controller.offset, 0.0);
    });

    testWidgets('swapping content at the same offset shows only new blocks', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget build(String data) => _app(
        controller: controller,
        cacheExtent: 0,
        slivers: [SliverMarkdownView(documentId: 'swap2', data: data)],
      );
      await tester.pumpWidget(build(_paragraphs(300, prefix: 'Old')));
      controller.jumpTo(3000);
      await tester.pump();
      expect(_texts(tester).every((t) => t.startsWith('Old')), isTrue);

      await tester.pumpWidget(build(_paragraphs(300, prefix: 'New')));
      await tester.pump();
      final texts = _texts(tester);
      expect(texts, isNotEmpty);
      expect(texts.every((t) => t.startsWith('New')), isTrue, reason: '$texts');
      expect(controller.offset, 3000.0);
      expect(_drain(tester), isEmpty);
    });

    testWidgets('a visible block that changes type is replaced in place', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget build(String middle) => _app(
        controller: controller,
        slivers: [
          SliverMarkdownView(
            documentId: 'retype',
            data: '${_paragraphs(40)}\n\n$middle\n\n${_paragraphs(40)}',
          ),
        ],
      );
      await tester.pumpWidget(build('MIDDLE paragraph'));
      controller.jumpTo(40 * 35.0 - 100);
      await tester.pump();
      expect(_para(tester, 'MIDDLE'), isNotNull);

      await tester.pumpWidget(build('| MIDDLE |\n| --- |\n| cell |'));
      await tester.pump();
      expect(find.byType(Table), findsOneWidget);
      await tester.pumpWidget(build('- MIDDLE item'));
      await tester.pump();
      expect(find.byType(Table), findsNothing);
      expect(find.byType(MarkdownListItemWidget), findsOneWidget);
      expect(_drain(tester), isEmpty);
    });

    testWidgets('text appended while at the bottom extends the extent', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget build(int count) => _app(
        controller: controller,
        slivers: [
          SliverMarkdownView(
            documentId: 'append',
            data: _paragraphs(count),
            isStreaming: true,
          ),
        ],
      );
      await tester.pumpWidget(build(50));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      final before = controller.position.maxScrollExtent;
      final offset = controller.offset;
      for (var count = 51; count <= 60; count++) {
        await tester.pumpWidget(build(count));
        await tester.pump();
        expect(_drain(tester), isEmpty, reason: 'count $count');
      }
      expect(controller.position.maxScrollExtent, greaterThan(before));
      expect(controller.offset, offset, reason: 'no jump while appending');
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(_texts(tester).last, 'Paragraph 059');
    });

    testWidgets('a documentId change while scrolled re-keys visible blocks', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget build(String id) => _app(
        controller: controller,
        slivers: [SliverMarkdownView(documentId: id, data: _paragraphs(100))],
      );
      await tester.pumpWidget(build('id-a'));
      controller.jumpTo(700);
      await tester.pump();
      await tester.pumpWidget(build('id-b'));
      await tester.pump();
      expect(_drain(tester), isEmpty);
      final ids = tester
          .widgetList<SelectableParagraph>(find.byType(SelectableParagraph))
          .map((p) => p.documentId)
          .toSet();
      expect(ids, {'id-b'});
    });
  });

  group('configuration changes', () {
    testWidgets('a theme change reaches the visible blocks', (tester) async {
      Widget build(MarkdownThemeData theme) => _app(
        slivers: [
          SliverMarkdownView(
            documentId: 'themed',
            data: _paragraphs(60),
            theme: theme,
          ),
        ],
      );
      await tester.pumpWidget(build(MarkdownThemeData.fallback()));
      final first = _para(tester, 'Paragraph 000');
      expect(
        first.text.style!.color,
        MarkdownThemeData.fallback().bodyStyle.color,
      );
      await tester.pumpWidget(build(MarkdownThemeData.dark()));
      expect(identical(_para(tester, 'Paragraph 000'), first), isTrue);
      expect(first.text.style!.color, MarkdownThemeData.dark().bodyStyle.color);
    });

    testWidgets('an inherited MarkdownTheme applies to the sliver', (
      tester,
    ) async {
      await tester.pumpWidget(
        MarkdownTheme(
          data: MarkdownThemeData.fallback().copyWith(
            bodyStyle: const TextStyle(fontSize: 30, color: Color(0xFF010203)),
          ),
          child: _app(slivers: const [SliverMarkdownView(data: 'body')]),
        ),
      );
      expect(_para(tester, 'body').text.style!.fontSize, 30);
    });

    testWidgets('textScaler and textDirection apply to built blocks', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(slivers: const [SliverMarkdownView(data: 'body\n\n- item')]),
      );
      final height = _para(tester, 'body').size.height;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(
          slivers: const [
            SliverMarkdownView(
              data: 'body\n\n- item',
              textScaler: TextScaler.linear(2),
              textDirection: ui.TextDirection.rtl,
            ),
          ],
        ),
      );
      expect(_drain(tester), isEmpty);
      final body = _para(tester, 'body');
      expect(body.size.height, closeTo(height * 2, 1.0));
      expect(body.textDirection, ui.TextDirection.rtl);
      expect(body.localToGlobal(Offset(body.size.width, 0)).dx, 420.0);
    });

    testWidgets('builders and link taps work inside the sliver', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          slivers: [
            SliverMarkdownView(
              data: 'Use `code` or [go](https://sliver.example)',
              builders: MarkdownBuilders(
                onLinkTap: (url, _) => taps.add(url),
                inlineCodeBuilder: (context, code, style, codeStyle) =>
                    TextSpan(text: '[$code]', style: style),
              ),
            ),
          ],
        ),
      );
      final p = _para(tester, 'Use');
      expect(p.text.toPlainText(), 'Use [code] or go');
      final start = p.text.toPlainText().lastIndexOf('go');
      final box = p
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + 2),
          )
          .first
          .toRect();
      await tester.tapAt(p.localToGlobal(box.center));
      expect(taps, ['https://sliver.example']);
    });

    testWidgets('selectable: false registers nothing with the scope', (
      tester,
    ) async {
      final selection = MarkdownSelectionController();
      addTearDown(selection.dispose);
      await tester.pumpWidget(
        _app(
          selection: selection,
          slivers: [
            SliverMarkdownView(
              documentId: 'unselectable',
              data: _paragraphs(5),
              selectable: false,
            ),
          ],
        ),
      );
      expect(selection.mountedSurfaces, isEmpty);
      expect(selection.documentForId('unselectable'), isNull);
      expect(_texts(tester).length, 5);
    });
  });

  group('several slivers', () {
    testWidgets('two documents in one scroll view keep their own blocks', (
      tester,
    ) async {
      final selection = MarkdownSelectionController();
      addTearDown(selection.dispose);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          controller: controller,
          selection: selection,
          slivers: [
            SliverMarkdownView(
              documentId: 'first-doc',
              data: _paragraphs(3, prefix: 'First'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
            SliverMarkdownView(
              documentId: 'second-doc',
              documentOrder: 1,
              data: _paragraphs(3, prefix: 'Second'),
            ),
          ],
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(_texts(tester), [
        'First 000',
        'First 001',
        'First 002',
        'Second 000',
        'Second 001',
        'Second 002',
      ]);
      expect(
        tester.getRect(_block('second-doc', 0)).top -
            tester.getRect(_block('first-doc', 2)).bottom,
        closeTo(40.0, 0.01),
      );
      expect(selection.documents.map((d) => d.id), ['first-doc', 'second-doc']);
    });
  });
}
