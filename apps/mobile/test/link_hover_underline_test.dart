import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/link_hover_underline.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpMarkdown(
    WidgetTester tester,
    String data, {
    bool selectable = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: LinkHoverUnderline(
                child: MarkdownBody(
                  data: data,
                  selectable: selectable,
                  onTapLink: (_, _, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Rect> underlines(WidgetTester tester) => tester
      .state<LinkHoverUnderlineState>(find.byType(LinkHoverUnderline))
      .underlineRects;

  Future<TestGesture> hoverAt(WidgetTester tester, Offset position) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(position);
    await tester.pump();
    return gesture;
  }

  testWidgets('underlines the hovered link and clears on exit', (tester) async {
    await pumpMarkdown(tester, '[a link here](http://localhost:3000)');
    expect(underlines(tester), isEmpty);

    final gesture = await hoverAt(
      tester,
      tester.getTopLeft(find.byType(RichText).first) + const Offset(8, 8),
    );
    expect(underlines(tester), isNotEmpty);

    await gesture.moveTo(const Offset(390, 590));
    await tester.pump();
    expect(underlines(tester), isEmpty);
  });

  testWidgets('does not underline plain text next to a link', (tester) async {
    await pumpMarkdown(tester, 'plain words then [link](http://localhost)');

    await hoverAt(
      tester,
      tester.getTopLeft(find.byType(RichText).first) + const Offset(4, 8),
    );
    expect(underlines(tester), isEmpty);
  });

  testWidgets('underlines only the hovered link range', (tester) async {
    await pumpMarkdown(tester, '[first](http://a) and [second](http://b)');
    final origin = tester.getTopLeft(find.byType(RichText).first);

    await hoverAt(tester, origin + const Offset(6, 8));
    final rects = underlines(tester);
    expect(rects, hasLength(1));
    expect(rects.single.left, closeTo(0, 1));
    expect(rects.single.width, lessThan(80));
  });

  testWidgets('works for selectable markdown', (tester) async {
    await pumpMarkdown(
      tester,
      '[a link here](http://localhost:3000)',
      selectable: true,
    );

    await hoverAt(
      tester,
      tester.getTopLeft(find.byType(SelectableText).first) + const Offset(8, 8),
    );
    expect(underlines(tester), isNotEmpty);
  });
  testWidgets('underlines the trailing half of the last link character', (
    tester,
  ) async {
    await pumpMarkdown(tester, '[link](http://localhost)');
    final gesture = await hoverAt(tester, const Offset(8, 8));
    final rect = underlines(tester).single;
    await gesture.moveTo(Offset(rect.right - 1, rect.center.dy));
    await tester.pump();
    expect(underlines(tester), isNotEmpty);
  });

  testWidgets('clears hover when an ancestor scrolls', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: LinkHoverUnderline(
              child: MarkdownBody(
                data: List.generate(
                  50,
                  (i) => '[link $i](http://localhost)',
                ).join('\n\n'),
                onTapLink: (_, _, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await hoverAt(tester, const Offset(8, 8));
    expect(underlines(tester), isNotEmpty);
    controller.jumpTo(20);
    await tester.pump();
    expect(underlines(tester), isEmpty);
  });

  testWidgets('selectable link trailing character stays underlined', (
    tester,
  ) async {
    await pumpMarkdown(tester, '[link](http://localhost)', selectable: true);
    final gesture = await hoverAt(tester, const Offset(8, 8));
    final rect = underlines(tester).single;
    await gesture.moveTo(Offset(rect.right - 1, rect.center.dy));
    await tester.pump();
    expect(underlines(tester), isNotEmpty);
  });

  testWidgets('clears hover when child markdown scrolls', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkHoverUnderline(
            child: Markdown(
              controller: controller,
              padding: EdgeInsets.zero,
              data: List.generate(
                50,
                (i) => '[link $i](http://localhost)',
              ).join('\n\n'),
              onTapLink: (_, _, _) {},
            ),
          ),
        ),
      ),
    );
    await hoverAt(tester, const Offset(8, 8));
    expect(underlines(tester), isNotEmpty);
    controller.jumpTo(20);
    await tester.pump();
    expect(underlines(tester), isEmpty);
  });

  testWidgets('clears hover when markdown content changes', (tester) async {
    await pumpMarkdown(tester, '[link](http://localhost)');
    await hoverAt(tester, const Offset(8, 8));
    expect(underlines(tester), isNotEmpty);
    await pumpMarkdown(tester, 'updated plain text');
    expect(underlines(tester), isEmpty);
  });

  testWidgets('clears stale hover geometry after constraints change', (
    tester,
  ) async {
    final width = ValueNotifier<double>(400);
    addTearDown(width.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ValueListenableBuilder<double>(
              valueListenable: width,
              child: LinkHoverUnderline(
                child: MarkdownBody(
                  data: '[a link that wraps when the width changes](http://localhost)',
                  onTapLink: (_, _, _) {},
                ),
              ),
              builder: (_, value, child) =>
                  SizedBox(width: value, child: child),
            ),
          ),
        ),
      ),
    );
    await hoverAt(tester, const Offset(8, 8));
    expect(underlines(tester), isNotEmpty);
    width.value = 150;
    await tester.pump();
    expect(underlines(tester), isEmpty);
  });
}
