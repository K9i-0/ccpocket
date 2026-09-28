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
}
