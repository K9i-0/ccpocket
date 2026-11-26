// Right-to-left behaviour of the rendering layer.
//
// Provenance (behaviours mined by name from the reference suites, rewritten
// against markdown_kit's API):
// - flutter_md widget/rtl_test.dart (high)
// - flutter_md widget/rtl_geometry_test.dart (high/medium)
// - flutter_md widget/layout_optimizations_test.dart "right-to-left lists
//   still place markers per item" (medium)
// - gpt_markdown regression/rtl_block_alignment_test.dart (high)
// - gpt_markdown regression/rtl_inline_widget_order_test.dart (medium)
// - gpt_markdown regression/inline_code_with_bidi_test.dart (medium)
// - gpt_markdown regression/table_column_alignment_test.dart (RTL half)
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:markdown_kit/src/rendering/block_renderer.dart';
import 'package:markdown_kit/src/rendering/list_item_widget.dart';

const _rtl = ui.TextDirection.rtl;
const _ltr = ui.TextDirection.ltr;

Widget _app({
  required Widget child,
  Size size = const Size(420, 680),
  ui.TextDirection dir = ui.TextDirection.ltr,
  TextScaler scaler = TextScaler.noScaling,
}) {
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
              child: SingleChildScrollView(child: child),
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

RenderSelectableParagraph _para(WidgetTester tester, String substring) {
  for (final ro in tester.allRenderObjects) {
    if (ro is RenderSelectableParagraph &&
        ro.text.toPlainText().contains(substring)) {
      return ro;
    }
  }
  fail('No RenderSelectableParagraph containing "$substring".');
}

Finder _paraFinder(String substring) => find.byWidgetPredicate(
  (w) => w is SelectableParagraph && w.text.toPlainText().contains(substring),
);

Rect _globalRect(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

Rect _paraRect(WidgetTester tester, String substring) =>
    _globalRect(_para(tester, substring));

/// Global rect of the glyphs of [needle].
Rect _glyphRect(WidgetTester tester, String needle, {String? within}) {
  final p = _para(tester, within ?? needle);
  final start = p.text.toPlainText().indexOf(needle);
  final boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + needle.length),
  );
  var rect = boxes.first.toRect();
  for (final b in boxes.skip(1)) {
    rect = rect.expandToInclude(b.toRect());
  }
  return MatrixUtils.transformRect(p.getTransformTo(null), rect);
}

List<String> _drain(WidgetTester tester) {
  final out = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    out.add(e.toString());
  }
  return out;
}

RenderMarkdownListItem _item(WidgetTester tester, String containing) {
  for (final ro in tester.allRenderObjects) {
    if (ro is RenderMarkdownListItem) {
      RenderSelectableParagraph? first;
      void visit(RenderObject o) {
        if (first != null) return;
        if (o is RenderSelectableParagraph) {
          first = o;
          return;
        }
        o.visitChildren(visit);
      }

      visit(ro);
      if (first != null && first!.text.toPlainText().contains(containing)) {
        return ro;
      }
    }
  }
  fail('No list item containing "$containing".');
}

/// Horizontal extent (item-local) of whatever the item painted as its marker.
({double left, double right}) _markerExtent(RenderMarkdownListItem item) {
  final canvas = TestRecordingCanvas();
  item.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  for (final recorded in canvas.invocations) {
    final inv = recorded.invocation;
    final args = inv.positionalArguments;
    if (inv.memberName == #drawCircle) {
      final c = args[0] as Offset;
      final r = args[1] as double;
      return (left: c.dx - r, right: c.dx + r);
    }
    if (inv.memberName == #drawRRect) {
      final r = (args[0] as RRect).outerRect;
      return (left: r.left, right: r.right);
    }
    if (inv.memberName == #drawRect) {
      final r = args[0] as Rect;
      return (left: r.left, right: r.right);
    }
    if (inv.memberName == #drawParagraph) {
      final p = args[0] as ui.Paragraph;
      final o = args[1] as Offset;
      return (left: o.dx, right: o.dx + p.longestLine);
    }
  }
  fail('The item painted no marker.');
}

/// Insets of the paragraph containing [text] inside its nearest [ClipRRect]
/// ancestor (the quote / alert frame).
({double left, double right}) _frameInsets(WidgetTester tester, String text) {
  final frame = tester.renderObject<RenderBox>(
    find
        .ancestor(of: _paraFinder(text), matching: find.byType(ClipRRect))
        .first,
  );
  final frameRect = _globalRect(frame);
  final textRect = _paraRect(tester, text);
  return (
    left: textRect.left - frameRect.left,
    right: frameRect.right - textRect.right,
  );
}

/// The one-sided bar of the quote / alert around the paragraph containing
/// [text], in the coordinates of the box that paints it.
({Rect bar, Size frame}) _sideBar(WidgetTester tester, String text) {
  final decorated = find.ancestor(
    of: _paraFinder(text),
    matching: find.byWidgetPredicate((w) {
      if (w is! DecoratedBox) return false;
      final decoration = w.decoration;
      if (decoration is! BoxDecoration) return false;
      final border = decoration.border;
      return border is BoxBorder && !border.isUniform;
    }),
  );
  final box = tester.renderObject<RenderBox>(decorated.first);
  final canvas = TestRecordingCanvas();
  box.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  for (final recorded in canvas.invocations) {
    final inv = recorded.invocation;
    if (inv.memberName == #drawPath) {
      return (
        bar: (inv.positionalArguments[0] as Path).getBounds(),
        frame: box.size,
      );
    }
    if (inv.memberName == #drawRect) {
      return (bar: inv.positionalArguments[0] as Rect, frame: box.size);
    }
  }
  fail('No side bar was painted around "$text".');
}

const _width = 420.0;

void main() {
  group('text blocks', () {
    testWidgets('an RTL paragraph sits against the right edge', (tester) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(data: 'שלום עולם'),
        ),
      );
      expect(_paraRect(tester, 'שלום').right, _width);
      expect(_para(tester, 'שלום').textDirection, _rtl);
    });

    testWidgets('an LTR paragraph sits against the left edge', (tester) async {
      await tester.pumpWidget(_app(child: const MarkdownView(data: 'hello')));
      expect(_paraRect(tester, 'hello').left, 0.0);
    });

    testWidgets('an RTL heading sits against the right edge', (tester) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(data: '## כותרת'),
        ),
      );
      expect(_paraRect(tester, 'כותרת').right, _width);
    });

    testWidgets('a wrapped RTL paragraph starts each line at the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          size: const Size(200, 600),
          child: const MarkdownView(
            data: 'אבג דהו זחט יכל מנס עפצ קרש תאב גדה',
          ),
        ),
      );
      final p = _para(tester, 'אבג');
      final all = p.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: p.text.toPlainText().length),
      );
      final tops = {for (final b in all) b.top};
      expect(tops.length, greaterThan(1), reason: 'the text must wrap');
      // The first logical character is at the right end of the first line.
      final first = p
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 1),
          )
          .first;
      expect(first.right, closeTo(p.size.width, 0.5));
    });

    testWidgets('the textDirection parameter overrides the ambient direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(data: 'שלום', textDirection: _rtl),
        ),
      );
      expect(_paraRect(tester, 'שלום').right, _width);

      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(data: 'hello', textDirection: _ltr),
        ),
      );
      expect(_paraRect(tester, 'hello').left, 0.0);
    });
  });

  group('lists', () {
    testWidgets('RTL bullet: marker on the right, content to its left', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(data: '- פריט ראשון\n- שני'),
        ),
      );
      final item = _item(tester, 'פריט');
      final marker = _markerExtent(item);
      final text = _paraRect(tester, 'פריט');
      final itemRect = _globalRect(item);
      expect(itemRect.right, _width);
      // Content ends where the gutter begins; the bullet is inside the gutter.
      expect(itemRect.right - text.right, closeTo(22.0, 0.01));
      expect(itemRect.left + marker.left, greaterThanOrEqualTo(text.right));
      expect(marker.right, lessThanOrEqualTo(item.size.width));
    });

    testWidgets('LTR bullet: marker on the left, content to its right', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(child: const MarkdownView(data: '- first item\n- second')),
      );
      final item = _item(tester, 'first item');
      final marker = _markerExtent(item);
      final text = _paraRect(tester, 'first item');
      expect(text.left, closeTo(22.0, 0.01));
      expect(marker.right, lessThanOrEqualTo(text.left));
    });

    testWidgets('RTL ordinals and checkboxes are also on the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(
            data: '1. אחד\n2. שתיים\n\n- [ ] פתוח\n- [x] סגור',
          ),
        ),
      );
      for (final label in ['אחד', 'שתיים', 'פתוח', 'סגור']) {
        final item = _item(tester, label);
        final marker = _markerExtent(item);
        final itemRect = _globalRect(item);
        final text = _paraRect(tester, label);
        expect(
          itemRect.left + marker.left,
          greaterThanOrEqualTo(text.right - 0.01),
          reason: label,
        );
        expect(marker.right, lessThanOrEqualTo(item.size.width + 0.01));
      }
    });

    testWidgets('nested RTL lists indent toward the left', (tester) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(data: '- חיצוני\n  - פנימי\n    - עמוק'),
        ),
      );
      final outer = _paraRect(tester, 'חיצוני').right;
      final inner = _paraRect(tester, 'פנימי').right;
      final deep = _paraRect(tester, 'עמוק').right;
      expect(inner, lessThan(outer));
      expect(deep, lessThan(inner));
      expect(outer - inner, closeTo(inner - deep, 0.01));
    });

    testWidgets('RTL ordered items keep one text column across 9 -> 10', (
      tester,
    ) async {
      final md = [for (var i = 8; i <= 11; i++) '$i. פריט$i'].join('\n');
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: MarkdownView(data: md),
        ),
      );
      expect(
        _paraRect(tester, 'פריט9').right,
        _paraRect(tester, 'פריט10').right,
      );
    });
  });

  group('quotes and alerts', () {
    testWidgets('LTR quote: the bar and the wide padding are on the left', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(child: const MarkdownView(data: '> quoted')),
      );
      final bar = _sideBar(tester, 'quoted');
      expect(bar.bar.left, 0.0);
      expect(bar.bar.width, closeTo(3.5, 0.01));
      final insets = _frameInsets(tester, 'quoted');
      expect(insets.left, closeTo(12.0, 0.01));
      expect(insets.right, closeTo(8.0, 0.01));
    });

    // REAL BUG: lib/src/rendering/block_renderer.dart:316
    // `_buildBlockquote` — the bar is `Border(left: ...)` and the padding is a
    // plain `EdgeInsets`, neither follows Directionality, so in RTL the bar
    // stays on the left while list gutters move to the right.
    testWidgets('RTL quote: the bar and the wide padding are on the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(data: '> ציטוט'),
        ),
      );
      final bar = _sideBar(tester, 'ציטוט');
      expect(
        bar.bar.right,
        closeTo(bar.frame.width, 0.01),
        reason: 'bar ${bar.bar} in frame ${bar.frame}',
      );
      final insets = _frameInsets(tester, 'ציטוט');
      expect(insets.right, closeTo(12.0, 0.01), reason: '$insets');
      expect(insets.left, closeTo(8.0, 0.01), reason: '$insets');
    });

    testWidgets('LTR alert: the accent bar is on the left', (tester) async {
      await tester.pumpWidget(
        _app(child: const MarkdownView(data: '> [!NOTE]\n> body text')),
      );
      final bar = _sideBar(tester, 'body text');
      expect(bar.bar.left, 0.0);
      expect(bar.bar.width, closeTo(3.5, 0.01));
    });

    // REAL BUG: lib/src/rendering/block_renderer.dart:371
    // `_buildAlert` — the accent bar is `Border(left: ...)` regardless of
    // Directionality.
    testWidgets('RTL alert: the accent bar is on the right', (tester) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(data: '> [!NOTE]\n> גוף'),
        ),
      );
      final bar = _sideBar(tester, 'גוף');
      expect(
        bar.bar.right,
        closeTo(bar.frame.width, 0.01),
        reason: 'bar ${bar.bar} in frame ${bar.frame}',
      );
    });

    testWidgets('RTL alert: the title follows its icon from the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(data: '> [!TIP]\n> גוף'),
        ),
      );
      final title = tester.getRect(find.text('TIP'));
      final icon = tester.getRect(
        find
            .descendant(
              of: find.byType(MarkdownBlockRenderer),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      expect(icon.left, greaterThanOrEqualTo(title.right));
    });

    testWidgets('a nested RTL quote child stays right-aligned', (tester) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(data: '> חיצוני ארוך יותר\n>\n> > פנימי'),
        ),
      );
      expect(_drain(tester), isEmpty);
      final outer = _paraRect(tester, 'חיצוני');
      final inner = _paraRect(tester, 'פנימי');
      // Both are right-aligned inside their frames, the inner one further in.
      expect(inner.right, lessThanOrEqualTo(outer.right));
    });
  });

  group('tables', () {
    testWidgets('RTL: the first column is on the right', (tester) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(
            data: '| ראשון | שני | שלישי |\n| --- | --- | --- |\n| א | ב | ג |',
          ),
        ),
      );
      final first = _paraRect(tester, 'ראשון');
      final second = _paraRect(tester, 'שני');
      final third = _paraRect(tester, 'שלישי');
      expect(first.left, greaterThan(second.right));
      expect(second.left, greaterThan(third.right));
      expect(tester.getRect(find.byType(Table)).right, _width);
    });

    testWidgets('LTR: the first column is on the left', (tester) async {
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            data: '| first | second |\n| --- | --- |\n| a | b |',
          ),
        ),
      );
      expect(
        _paraRect(tester, 'first').right,
        lessThan(_paraRect(tester, 'second').left),
      );
      expect(tester.getRect(find.byType(Table)).left, 0.0);
    });

    // REAL BUG: lib/src/rendering/table_widget.dart:388-399
    // `_buildCellWidget` — `TableColumnAlign.left` maps to `TextAlign.start` /
    // `AlignmentDirectional.centerStart` and `right` to `end`, so an explicit
    // GFM `:---` (left) column flips to the right under RTL.
    testWidgets('RTL: explicitly aligned columns keep their physical side', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(
            data:
                '| wide left head | wide right head |\n'
                '| :--- | ---: |\n'
                '| L | R |',
          ),
        ),
      );
      final leftHead = _paraRect(tester, 'wide left head');
      final rightHead = _paraRect(tester, 'wide right head');
      final l = _paraRect(tester, 'L');
      final r = _paraRect(tester, 'R');
      expect(l.left, closeTo(leftHead.left, 0.01), reason: ':--- means left');
      expect(r.right, closeTo(rightHead.right, 0.01), reason: '---: is right');
    });

    testWidgets('RTL: a wide table opens on its first column', (tester) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          size: const Size(300, 600),
          child: const MarkdownView(
            data:
                '| ראשון ארוך מאוד | שני ארוך מאוד | שלישי ארוך מאוד |\n'
                '| --- | --- | --- |\n| א | ב | ג |',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(tester.getSize(find.byType(Table)).width, greaterThan(300));
      final first = _paraRect(tester, 'ראשון');
      expect(first.right, lessThanOrEqualTo(300.0));
      expect(first.left, greaterThanOrEqualTo(0.0));
    });

    testWidgets('RTL: a link in a mirrored cell is hit where it is drawn', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: MarkdownView(
            data:
                '| א | ב |\n| --- | --- |\n'
                '| [first](https://1.example) | [second](https://2.example) |',
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      await tester.tapAt(_glyphRect(tester, 'first').center);
      await tester.tapAt(_glyphRect(tester, 'second').center);
      expect(taps, ['https://1.example', 'https://2.example']);
      expect(
        _glyphRect(tester, 'first').left,
        greaterThan(_glyphRect(tester, 'second').right),
      );
    });
  });

  group('code', () {
    // Failed until commit 47af3bcd wrapped the code paragraph in an LTR
    // Directionality (`_buildCodeBlock`); kept as a regression guard.
    testWidgets('a code block stays left-to-right in an RTL document', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(
            data: 'טקסט\n\n```dart\nfinal x = call(a, b);\nshort\n```',
          ),
        ),
      );
      final code = _para(tester, 'final x');
      expect(code.textDirection, _ltr);
      final short = _glyphRect(tester, 'short', within: 'final x');
      final long = _glyphRect(tester, 'final x = call(a, b);');
      expect(short.left, closeTo(long.left, 0.01));
    });

    testWidgets('an LTR code block is untouched', (tester) async {
      await tester.pumpWidget(
        _app(child: const MarkdownView(data: '```\nfinal x = 1;\nshort\n```')),
      );
      final code = _para(tester, 'final x');
      expect(code.textDirection, _ltr);
      expect(
        _glyphRect(tester, 'short', within: 'final x').left,
        closeTo(_glyphRect(tester, 'final x = 1;').left, 0.01),
      );
    });

    testWidgets(
      'inline code inside RTL text keeps its own characters in order',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dir: _rtl,
            child: const MarkdownView(data: 'לפני `abc def` אחרי'),
          ),
        );
        expect(_drain(tester), isEmpty);
        final p = _para(tester, 'abc def');
        expect(p.codeRangeCount, 1);
        expect(p.text.toPlainText(), 'לפני abc def אחרי');
        // Latin code reads left to right even inside an RTL paragraph...
        final a = _glyphRect(tester, 'abc', within: 'abc def');
        final d = _glyphRect(tester, 'def', within: 'abc def');
        expect(a.right, lessThanOrEqualTo(d.left));
        // ...while the Hebrew around it runs right to left.
        final before = _glyphRect(tester, 'לפני');
        final after = _glyphRect(tester, 'אחרי');
        expect(before.left, greaterThanOrEqualTo(d.right));
        expect(after.right, lessThanOrEqualTo(a.left));
      },
    );
  });

  group('inline widgets', () {
    MarkdownBuilders imageKeys() => MarkdownBuilders(
      imageBuilder: (context, image, theme) =>
          SizedBox(key: ValueKey<String>(image.source), width: 20, height: 20),
    );

    double x(WidgetTester tester, String key) =>
        tester.getCenter(find.byKey(ValueKey<String>(key))).dx;

    testWidgets('two inline images in an RTL paragraph keep reading order', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: MarkdownView(
            data: 'אחד ![a](a) שתיים ![b](b) שלוש',
            builders: imageKeys(),
          ),
        ),
      );
      expect(x(tester, 'a'), greaterThan(x(tester, 'b')));
    });

    testWidgets('four inline images in an RTL paragraph keep reading order', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: MarkdownView(
            data: 'א ![a](a) ב ![b](b) ג ![c](c) ד ![d](d) ה',
            builders: imageKeys(),
          ),
        ),
      );
      final xs = [
        for (final k in ['a', 'b', 'c', 'd']) x(tester, k),
      ];
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], lessThan(xs[i - 1]), reason: '$xs');
      }
    });

    testWidgets('an all-latin paragraph in an LTR document is untouched', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: 'one ![a](a) two ![b](b) three',
            builders: imageKeys(),
          ),
        ),
      );
      expect(x(tester, 'a'), lessThan(x(tester, 'b')));
    });

    testWidgets('images stay in reading order when the RTL paragraph wraps', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          size: const Size(160, 600),
          child: MarkdownView(
            data: 'אבגדה ![a](a) וזחטי ![b](b) כלמנס ![c](c) עפצקר',
            builders: imageKeys(),
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      final centers = [
        for (final k in ['a', 'b', 'c'])
          tester.getCenter(find.byKey(ValueKey<String>(k))),
      ];
      for (var i = 1; i < centers.length; i++) {
        final prev = centers[i - 1];
        final cur = centers[i];
        final sameLine = (prev.dy - cur.dy).abs() < 1.0;
        expect(
          sameLine ? cur.dx < prev.dx : cur.dy > prev.dy,
          isTrue,
          reason: '$centers',
        );
      }
    });
  });

  group('other blocks', () {
    // REAL BUG: lib/src/rendering/block_renderer.dart:613
    // `_buildFootnoteDefinitions` — the label uses
    // `EdgeInsets.only(right: 8.0, top: 1.0)`; in RTL the Row puts the label
    // on the right, so the 8lp gap ends up on the outside and the label
    // touches the footnote body.
    testWidgets('RTL footnote: there is a gap between label and body', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(data: 'טקסט[^1]\n\n[^1]: הערת שוליים'),
        ),
      );
      final label = tester.getRect(find.byType(Text));
      final body = _paraRect(tester, 'הערת');
      expect(label.left, greaterThan(body.right));
      expect(label.left - body.right, closeTo(8.0, 0.01));
    });

    testWidgets('LTR footnote: there is a gap between label and body', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(child: const MarkdownView(data: 'Text[^1]\n\n[^1]: the note')),
      );
      final label = tester.getRect(find.byType(Text));
      final body = _paraRect(tester, 'the note');
      expect(body.left - label.right, closeTo(8.0, 0.01));
    });

    testWidgets('RTL details: the disclosure icon is right of the summary', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(
            documentId: 'rtl-details',
            data:
                '<details open>\n<summary>תקציר</summary>\n\nגוף\n\n</details>',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      final icon = tester.getRect(find.byType(AnimatedRotation));
      final summary = _paraRect(tester, 'תקציר');
      expect(icon.left, greaterThanOrEqualTo(summary.right));
    });

    testWidgets('a link in an RTL paragraph is hit where it is drawn', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: MarkdownView(
            data: 'ראה [קישור](https://rtl.example) כאן',
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      await tester.tapAt(_glyphRect(tester, 'קישור').center);
      await tester.tapAt(_glyphRect(tester, 'ראה').center);
      expect(taps, ['https://rtl.example']);
    });
  });

  group('mirroring', () {
    const doc = '''
# Title

Paragraph text here.

- bullet one
- bullet two

1. ordered one
2. ordered two

> quote

> [!NOTE]
> alert

| a | b |
| - | - |
| c | d |

---

```
code
```
''';

    for (final width in [420.0, 260.0]) {
      testWidgets('an RTL document is as tall as its LTR twin at $width', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            size: Size(width, 800),
            child: const MarkdownView(data: doc),
          ),
        );
        final ltrSize = tester.getSize(find.byType(MarkdownView));
        await tester.pumpWidget(
          _app(
            dir: _rtl,
            size: Size(width, 800),
            child: const MarkdownView(data: doc),
          ),
        );
        expect(_drain(tester), isEmpty);
        expect(
          tester.getSize(find.byType(MarkdownView)).height,
          ltrSize.height,
        );
      });
    }

    testWidgets('paragraph and list text are mirror images of LTR', (
      tester,
    ) async {
      const md = 'para\n\n- item\n\n1. numbered';
      await tester.pumpWidget(_app(child: const MarkdownView(data: md)));
      final ltr = {
        for (final k in ['para', 'item', 'numbered']) k: _paraRect(tester, k),
      };
      await tester.pumpWidget(
        _app(
          dir: _rtl,
          child: const MarkdownView(data: md),
        ),
      );
      for (final k in ltr.keys) {
        final rtl = _paraRect(tester, k);
        expect(rtl.right, closeTo(_width - ltr[k]!.left, 0.01), reason: k);
        expect(rtl.width, closeTo(ltr[k]!.width, 0.01), reason: k);
      }
    });

    testWidgets('switching direction at runtime re-mirrors, and back', (
      tester,
    ) async {
      const md = 'para\n\n- item\n\n> quote';
      Future<List<Rect>> rects(ui.TextDirection dir) async {
        await tester.pumpWidget(
          _app(
            dir: dir,
            child: const MarkdownView(documentId: 'flip', data: md),
          ),
        );
        return [
          for (final k in ['para', 'item', 'quote']) _paraRect(tester, k),
        ];
      }

      final before = await rects(_ltr);
      final flipped = await rects(_rtl);
      final after = await rects(_ltr);
      expect(flipped, isNot(equals(before)));
      expect(flipped.first.right, _width);
      expect(after, before);
    });

    for (final width in [0.0, 1.0, 10.0, 40.0]) {
      testWidgets('a degenerate width of $width lays out in RTL', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            dir: _rtl,
            size: Size(width, 600),
            child: const MarkdownView(
              data: 'טקסט\n\n- פריט\n\n1. מספר\n\n> ציטוט\n\n---',
            ),
          ),
        );
        final errors = _drain(tester);
        expect(errors, isEmpty, reason: errors.join('\n'));
      });
    }
  });
}
