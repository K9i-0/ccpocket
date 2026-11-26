// Table rendering.
//
// Provenance (behaviours mined by name from the reference suites, rewritten
// against markdown_kit's API):
// - gpt_markdown regression/issue_104_crlf_table_rendering_test.dart (high)
// - gpt_markdown regression/table_column_alignment_test.dart (high)
// - gpt_markdown block/table_overflow_test.dart — scroll half only; the
//   "wrap" overflow mode does not exist in markdown_kit (high)
// - gpt_markdown regression/style_sheet_fields_applied_test.dart "table
//   header text style applies", "table row stripes apply" (medium)
// - gpt_markdown regression/render_work_reuse_test.dart "identical tables
//   have independent scrolling ownership" (medium)
// - flutter_md widget/layout_optimizations_test.dart table cases (medium)
// - flutter_md widget/render_test.dart "aligned tables render without
//   exceptions" (medium)
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

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
          // OverflowBox so widths beyond the 800lp test surface are honoured.
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: size.width,
            maxWidth: size.width,
            child: SingleChildScrollView(child: child),
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

Rect _paraRect(WidgetTester tester, String substring) {
  final p = _para(tester, substring);
  return MatrixUtils.transformRect(
    p.getTransformTo(null),
    Offset.zero & p.size,
  );
}

List<String> _drain(WidgetTester tester) {
  final out = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    out.add(e.toString().split('\n').take(3).join(' / '));
  }
  return out;
}

/// Cell boxes (padding included) of the first table, row-major.
List<List<Rect>> _cells(WidgetTester tester, {int tableIndex = 0}) {
  final tableFinder = find.byType(Table).at(tableIndex);
  final table = tester.widget<Table>(tableFinder);
  final renderTable = tester.renderObject<RenderTable>(tableFinder);
  final rows = <List<Rect>>[];
  final boxes = <RenderBox>[];
  renderTable.visitChildren((child) => boxes.add(child as RenderBox));
  final columns = table.children.first.children.length;
  for (var r = 0; r < table.children.length; r++) {
    rows.add([
      for (var c = 0; c < columns; c++)
        MatrixUtils.transformRect(
          boxes[r * columns + c].getTransformTo(null),
          Offset.zero & boxes[r * columns + c].size,
        ),
    ]);
  }
  return rows;
}

Finder _tableScroll() => find.descendant(
  of: find.byType(MarkdownTableWidget),
  matching: find.byType(SingleChildScrollView),
);

void main() {
  group('line endings', () {
    const lines = ['| Name | Qty |', '| --- | --- |', '| apple | 3 |'];

    for (final entry in {
      r'\r\n': '\r\n',
      r'bare \r': '\r',
      r'\n': '\n',
    }.entries) {
      testWidgets('a table with ${entry.key} separators renders as a table', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(child: MarkdownView(data: lines.join(entry.value))),
        );
        expect(_drain(tester), isEmpty);
        expect(find.byType(Table), findsOneWidget);
        final cells = _cells(tester);
        expect(cells.length, 2);
        expect(cells.first.length, 2);
        expect(_para(tester, 'apple').text.toPlainText(), 'apple');
        expect(_para(tester, 'Qty').text.toPlainText(), 'Qty');
        expect(find.textContaining('|', findRichText: true), findsNothing);
        expect(find.textContaining('\r', findRichText: true), findsNothing);
      });
    }

    testWidgets('mixed separators and a trailing CRLF still give one table', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            data:
                'Intro\r\n\r\n| A | B |\r\n| --- | --- |\n| 1 | 2 |\r\n'
                '| 3 | 4 |\r\n\r\nOutro\r\n',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(find.byType(Table), findsOneWidget);
      expect(_cells(tester).length, 3);
      expect(_para(tester, 'Intro').text.toPlainText(), 'Intro');
      expect(_para(tester, 'Outro').text.toPlainText(), 'Outro');
    });
  });

  group('column alignment', () {
    const md =
        '| left header wide | centre header wide | right header wide | plain header wide |\n'
        '| :--- | :---: | ---: | --- |\n'
        '| L | C | R | P |';

    testWidgets('each alignment places the short cell text', (tester) async {
      await tester.pumpWidget(
        _app(
          size: const Size(1600, 600),
          child: const MarkdownView(data: md),
        ),
      );
      expect(_drain(tester), isEmpty);
      final cells = _cells(tester);
      const pad = 12.0;
      final l = _paraRect(tester, 'L');
      final c = _paraRect(tester, 'C');
      final r = _paraRect(tester, 'R');
      final p = _paraRect(tester, 'P');
      expect(l.left, closeTo(cells[1][0].left + pad, 0.01));
      expect(c.center.dx, closeTo(cells[1][1].center.dx, 0.01));
      expect(r.right, closeTo(cells[1][2].right - pad, 0.01));
      expect(p.left, closeTo(cells[1][3].left + pad, 0.01));
    });

    testWidgets('the header follows its column alignment too', (tester) async {
      await tester.pumpWidget(
        _app(
          size: const Size(1600, 600),
          child: const MarkdownView(
            data:
                '| L | C | R |\n| :--- | :---: | ---: |\n'
                '| a much wider body cell | a much wider body cell | a much wider body cell |',
          ),
        ),
      );
      final cells = _cells(tester);
      const pad = 12.0;
      expect(
        _paraRect(tester, 'L').left,
        closeTo(cells[0][0].left + pad, 0.01),
      );
      expect(
        _paraRect(tester, 'C').center.dx,
        closeTo(cells[0][1].center.dx, 0.01),
      );
      expect(
        _paraRect(tester, 'R').right,
        closeTo(cells[0][2].right - pad, 0.01),
      );
    });

    testWidgets('wrapped cell text is aligned line by line', (tester) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            theme: MarkdownThemeData.fallback().copyWith(
              tableStyle: const MarkdownTableStyle(maxColumnWidth: 140),
            ),
            data: '| H |\n| ---: |\n| aaa bbbbbb cc |',
          ),
        ),
      );
      final p = _para(tester, 'aaa');
      expect(p.textAlign, TextAlign.right);
      final lineBoxes = p.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: p.text.toPlainText().length),
      );
      final tops = {for (final b in lineBoxes) b.top};
      expect(tops.length, greaterThan(1), reason: 'cell text must wrap');
      final lastLineRight = lineBoxes
          .where((b) => b.top == tops.reduce((a, b) => a > b ? a : b))
          .map((b) => b.right)
          .reduce((a, b) => a > b ? a : b);
      expect(lastLineRight, closeTo(p.size.width, 0.5));
    });

    testWidgets('an ambient textAlign does not move a table column', (
      tester,
    ) async {
      Future<List<double>> lefts(Widget view) async {
        await tester.pumpWidget(_app(size: const Size(1600, 600), child: view));
        return [
          for (final k in ['L', 'C', 'R', 'P']) _paraRect(tester, k).left,
        ];
      }

      final plain = await lefts(const MarkdownView(data: md));
      final centred = await lefts(
        const DefaultTextStyle(
          style: TextStyle(fontSize: 30),
          textAlign: TextAlign.center,
          child: MarkdownView(data: md),
        ),
      );
      expect(centred, plain);
    });
  });

  group('horizontal overflow', () {
    const wide =
        '| Column one | Column two | Column three | Column four | Column five |\n'
        '| --- | --- | --- | --- | --- |\n'
        '| a | b | c | d | LASTCELL |';

    testWidgets('a wide table scrolls instead of overflowing', (tester) async {
      await tester.pumpWidget(
        _app(
          size: const Size(300, 600),
          child: const MarkdownView(data: wide),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(_tableScroll(), findsOneWidget);
      expect(tester.getSize(find.byType(MarkdownTableWidget)).width, 300.0);
      expect(tester.getSize(find.byType(Table)).width, greaterThan(300.0));
      // Columns keep their natural single-line width.
      expect(_para(tester, 'Column three').size.height, lessThan(30.0));
    });

    testWidgets('dragging the table reveals its last column', (tester) async {
      await tester.pumpWidget(
        _app(
          size: const Size(300, 600),
          child: const MarkdownView(data: wide),
        ),
      );
      expect(_paraRect(tester, 'LASTCELL').left, greaterThan(300.0));
      await tester.drag(_tableScroll(), const Offset(-2000, 0));
      await tester.pumpAndSettle();
      final last = _paraRect(tester, 'LASTCELL');
      expect(last.right, lessThanOrEqualTo(300.0));
      expect(last.left, greaterThanOrEqualTo(0.0));
    });

    testWidgets('a narrow table does not scroll and hugs its content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(data: '| a | b |\n| - | - |\n| c | d |'),
        ),
      );
      expect(_tableScroll(), findsNothing);
      final table = tester.getRect(find.byType(Table));
      expect(table.left, 0.0);
      expect(table.width, lessThan(420.0));
    });

    testWidgets('a table at exactly its natural width does not scroll, one '
        'pixel less does', (tester) async {
      double scrollableDistance() {
        if (_tableScroll().evaluate().isEmpty) return 0.0;
        final state = tester.state<ScrollableState>(
          find.descendant(
            of: _tableScroll(),
            matching: find.byType(Scrollable),
          ),
        );
        return state.position.maxScrollExtent;
      }

      await tester.pumpWidget(
        _app(
          size: const Size(1600, 600),
          child: const MarkdownView(data: wide),
        ),
      );
      final natural = tester.getSize(find.byType(Table)).width;
      expect(_tableScroll(), findsNothing);

      await tester.pumpWidget(
        _app(
          size: Size(natural, 600),
          child: const MarkdownView(data: wide),
        ),
      );
      // Note: table_widget.dart adds `borderWidth * (columns + 1)` to the
      // natural width although the borders are painted inside the cells, so
      // within that margin the table is wrapped in a scroll view that has
      // nothing to scroll. Only the observable behaviour is asserted here.
      expect(scrollableDistance(), 0.0);
      expect(tester.getSize(find.byType(Table)).width, natural);

      await tester.pumpWidget(
        _app(
          size: Size(natural - 1, 600),
          child: const MarkdownView(data: wide),
        ),
      );
      expect(_tableScroll(), findsOneWidget);
      expect(scrollableDistance(), closeTo(1.0, 0.01));
      expect(tester.getSize(find.byType(Table)).width, natural);
      expect(_drain(tester), isEmpty);
    });

    // REAL BUG (minor): lib/src/rendering/table_widget.dart:109-112 adds
    // `borderWidth * (columnCount + 1)` to the natural width, but the borders
    // are painted inside the cells and take no space. A viewport up to that
    // many pixels wider than the table still gets a horizontal scroll view
    // (with nothing to scroll) instead of the plain aligned table.
    testWidgets('a table that fits exactly is not wrapped in a scroll view', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          size: const Size(1600, 600),
          child: const MarkdownView(data: wide),
        ),
      );
      final natural = tester.getSize(find.byType(Table)).width;
      await tester.pumpWidget(
        _app(
          size: Size(natural, 600),
          child: const MarkdownView(data: wide),
        ),
      );
      expect(tester.getSize(find.byType(Table)).width, natural);
      expect(_tableScroll(), findsNothing);
    });

    testWidgets('widening the viewport drops the scroll view again', (
      tester,
    ) async {
      Future<void> at(double width) => tester.pumpWidget(
        _app(
          size: Size(width, 600),
          child: const MarkdownView(documentId: 'resize', data: wide),
        ),
      );
      await at(300);
      expect(_tableScroll(), findsOneWidget);
      await at(1600);
      expect(_tableScroll(), findsNothing);
      await at(300);
      expect(_tableScroll(), findsOneWidget);
      expect(_drain(tester), isEmpty);
    });

    testWidgets('two identical tables scroll independently', (tester) async {
      await tester.pumpWidget(
        _app(
          size: const Size(300, 600),
          child: const MarkdownView(data: '$wide\n\nbetween\n\n$wide'),
        ),
      );
      expect(_tableScroll(), findsNWidgets(2));
      await tester.drag(_tableScroll().first, const Offset(-150, 0));
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.byType(Table).at(0)).dx;
      final second = tester.getTopLeft(find.byType(Table).at(1)).dx;
      expect(first, lessThan(0.0));
      expect(second, 0.0);
    });

    testWidgets('a 24-column table lays out and scrolls', (tester) async {
      final header = [for (var i = 0; i < 24; i++) 'h$i'].join(' | ');
      final rule = List.filled(24, '---').join(' | ');
      final row = [for (var i = 0; i < 24; i++) 'c$i'].join(' | ');
      await tester.pumpWidget(
        _app(child: MarkdownView(data: '| $header |\n| $rule |\n| $row |')),
      );
      expect(_drain(tester), isEmpty);
      expect(_cells(tester).first.length, 24);
      expect(_tableScroll(), findsOneWidget);
    });
  });

  group('cell content', () {
    testWidgets('a short row is padded and a long row is cut to the header', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            data:
                '| a | b | c |\n| --- | --- | --- |\n'
                '| only |\n'
                '| one | two | three | EXTRA |\n'
                '| x | y | z |',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      final cells = _cells(tester);
      expect(cells.length, 4);
      for (final row in cells) {
        expect(row.length, 3);
      }
      // GFM drops cells beyond the header's column count.
      expect(find.textContaining('EXTRA', findRichText: true), findsNothing);
      expect(_para(tester, 'only').text.toPlainText(), 'only');
      // The padded row is as tall as a normal row.
      expect(cells[1][0].height, cells[3][0].height);
    });

    testWidgets('empty cells keep the grid intact', (tester) async {
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            data: '| a | b | c |\n| --- | --- | --- |\n|  | mid |  |\n| | | |',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      final cells = _cells(tester);
      expect(cells.length, 3);
      expect(cells[1].length, 3);
      for (final row in cells) {
        for (final cell in row) {
          expect(cell.width, greaterThanOrEqualTo(64.0));
          expect(cell.height, greaterThan(0.0));
        }
      }
      // Columns line up across rows.
      for (var c = 0; c < 3; c++) {
        expect(cells[1][c].left, cells[0][c].left);
        expect(cells[2][c].width, cells[0][c].width);
      }
    });

    testWidgets('a header-only table renders one row', (tester) async {
      await tester.pumpWidget(
        _app(child: const MarkdownView(data: '| solo | head |\n| --- | --- |')),
      );
      expect(_drain(tester), isEmpty);
      expect(_cells(tester).length, 1);
      expect(_para(tester, 'solo').text.toPlainText(), 'solo');
    });

    testWidgets('very long unbroken cell text is capped and wraps', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(child: MarkdownView(data: '| h |\n| --- |\n| ${'w' * 90} |')),
      );
      expect(_drain(tester), isEmpty);
      final cells = _cells(tester);
      expect(cells[1][0].width, closeTo(280.0, 0.01));
      final p = _para(tester, 'www');
      expect(p.size.width, lessThanOrEqualTo(280.0 - 24.0 + 0.01));
      expect(p.size.height, greaterThan(60.0));
      expect(_tableScroll(), findsNothing);
    });

    testWidgets('long prose in a cell wraps at word boundaries', (
      tester,
    ) async {
      final words = List.filled(14, 'word').join(' ');
      await tester.pumpWidget(
        _app(child: MarkdownView(data: '| h |\n| --- |\n| $words |')),
      );
      expect(_drain(tester), isEmpty);
      final p = _para(tester, 'word');
      expect(p.size.height, greaterThan(40.0));
      final boxes = p.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 4),
      );
      expect(boxes.length, 1, reason: 'a word is never split across lines');
    });

    testWidgets('inline formatting, links and code work inside cells', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data:
                '| kind | sample |\n| --- | --- |\n'
                '| mixed | **bold** *em* ~~gone~~ `code` [go](https://c.example) |\n'
                '| pipe | a \\| b |\n'
                '| break | top<br>bottom |',
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      final mixed = _para(tester, 'bold');
      expect(mixed.text.toPlainText(), 'bold em gone code go');
      expect(mixed.codeRangeCount, 1);
      expect(mixed.tappableRangeCount, 1);
      expect(_para(tester, 'a | b').text.toPlainText(), 'a | b');
      final broken = _para(tester, 'top');
      expect(broken.text.toPlainText(), 'top\nbottom');
      expect(
        broken.size.height,
        closeTo(_para(tester, 'a | b').size.height * 2, 1.0),
      );

      final start = mixed.text.toPlainText().lastIndexOf('go');
      final box = mixed
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + 2),
          )
          .first
          .toRect();
      await tester.tapAt(mixed.localToGlobal(box.center));
      expect(taps, ['https://c.example']);
    });

    testWidgets('rows are vertically centred against a taller neighbour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            data: '| a | b |\n| --- | --- |\n| short | one<br>two<br>three |',
          ),
        ),
      );
      final short = _paraRect(tester, 'short');
      final tall = _paraRect(tester, 'one');
      expect(short.center.dy, closeTo(tall.center.dy, 0.5));
    });
  });

  group('column widths', () {
    testWidgets('columns are never narrower than minColumnWidth', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(data: '| a | b |\n| - | - |\n| c | d |'),
        ),
      );
      for (final cell in _cells(tester).first) {
        expect(cell.width, closeTo(64.0, 0.01));
      }
    });

    testWidgets('minColumnWidth and maxColumnWidth come from the theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          size: const Size(800, 600),
          child: MarkdownView(
            theme: MarkdownThemeData.fallback().copyWith(
              tableStyle: const MarkdownTableStyle(
                minColumnWidth: 100,
                maxColumnWidth: 150,
              ),
            ),
            data:
                '| a | long |\n| - | - |\n'
                '| b | some much longer cell content here |',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      final cells = _cells(tester);
      expect(cells[0][0].width, closeTo(100.0, 0.01));
      expect(cells[0][1].width, closeTo(150.0, 0.01));
    });

    testWidgets('a min above the max wins rather than throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            theme: MarkdownThemeData.fallback().copyWith(
              tableStyle: const MarkdownTableStyle(
                minColumnWidth: 120,
                maxColumnWidth: 80,
              ),
            ),
            data: '| a |\n| - |\n| some longer text |',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(_cells(tester)[0][0].width, closeTo(120.0, 0.01));
    });

    testWidgets('a column is as wide as its widest cell, header or body', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          size: const Size(1200, 600),
          child: const MarkdownView(
            data:
                '| wide header here | h |\n| --- | --- |\n'
                '| x | wide body cell |',
          ),
        ),
      );
      final cells = _cells(tester);
      final header = _para(tester, 'wide header here');
      final body = _para(tester, 'wide body cell');
      expect(
        cells[0][0].width,
        greaterThanOrEqualTo(
          header.getMaxIntrinsicWidth(double.infinity) + 24.0,
        ),
      );
      expect(
        cells[0][1].width,
        greaterThanOrEqualTo(body.getMaxIntrinsicWidth(double.infinity) + 24.0),
      );
      // Neither wraps.
      expect(header.size.height, lessThan(30.0));
      expect(body.size.height, lessThan(30.0));
    });

    testWidgets('the table is the same size at every viewport that fits it', (
      tester,
    ) async {
      const md = '| alpha | beta |\n| --- | --- |\n| gamma | delta |';
      final sizes = <Size>[];
      for (final width in [300.0, 420.0, 900.0]) {
        await tester.pumpWidget(
          _app(
            size: Size(width, 600),
            child: const MarkdownView(data: md),
          ),
        );
        sizes.add(tester.getSize(find.byType(Table)));
      }
      expect(sizes.toSet().length, 1, reason: '$sizes');
    });
  });

  group('style', () {
    testWidgets('header background, header text style and stripes apply', (
      tester,
    ) async {
      const headerBg = Color(0xFF112233);
      const stripe = Color(0xFF445566);
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            theme: MarkdownThemeData.fallback().copyWith(
              tableStyle: const MarkdownTableStyle(
                headerBackground: headerBg,
                rowStripeColor: stripe,
                headerTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            data: '| head |\n| --- |\n| r1 |\n| r2 |\n| r3 |\n| r4 |',
          ),
        ),
      );
      final table = tester.widget<Table>(find.byType(Table));
      Color? bg(int row) =>
          (table.children[row].decoration as BoxDecoration?)?.color;
      expect(bg(0), headerBg);
      // Body rows alternate: exactly every other one is striped.
      final striped = [for (var r = 1; r <= 4; r++) bg(r) == stripe];
      expect(striped.where((s) => s).length, 2, reason: '$striped');
      expect(striped[0], isNot(striped[1]));
      expect(striped[1], isNot(striped[2]));

      final headStyle = _para(tester, 'head').text.style!;
      expect(headStyle.fontSize, 20);
      expect(headStyle.fontWeight, FontWeight.w900);
      final bodyStyle = _para(tester, 'r1').text.style!;
      expect(bodyStyle.fontSize, 15);
    });

    testWidgets('a zero border width draws no borders and still lays out', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            theme: MarkdownThemeData.fallback().copyWith(
              tableStyle: const MarkdownTableStyle(borderWidth: 0),
            ),
            data: '| a | b |\n| - | - |\n| c | d |',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(tester.widget<Table>(find.byType(Table)).border, isNull);
      expect(tester.getSize(find.byType(Table)).width, closeTo(128.0, 0.01));
    });

    testWidgets('a custom tableBuilder replaces the default table', (
      tester,
    ) async {
      TableBlock? seen;
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: '| a | b |\n| :- | -: |\n| c | d |',
            builders: MarkdownBuilders(
              tableBuilder: (context, table, theme) {
                seen = table;
                return const SizedBox(key: ValueKey('custom-table'), height: 9);
              },
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('custom-table')), findsOneWidget);
      expect(find.byType(Table), findsNothing);
      expect(seen!.alignments, [TableColumnAlign.left, TableColumnAlign.right]);
      expect(seen!.rows.length, 1);
    });
  });

  group('tables nested in other blocks', () {
    const table = '| one | two |\n| --- | --- |\n| 1 | 2 |';
    final wideTable =
        '| ${List.filled(6, 'wide column').join(' | ')} |\n'
        '| ${List.filled(6, '---').join(' | ')} |\n'
        '| ${List.filled(6, 'v').join(' | ')} |';

    testWidgets('a table inside a list item renders inside the item', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data:
                '- item text\n\n  ${table.replaceAll('\n', '\n  ')}\n\n- next',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(find.byType(Table), findsOneWidget);
      final tableRect = tester.getRect(find.byType(Table));
      expect(tableRect.left, closeTo(22.0, 0.01));
      expect(tableRect.top, greaterThan(_paraRect(tester, 'item text').bottom));
      expect(tableRect.bottom, lessThan(_paraRect(tester, 'next').top));
    });

    testWidgets('a table inside a quote renders inside the quote', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: '> quoted text\n>\n> ${table.replaceAll('\n', '\n> ')}',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(find.byType(Table), findsOneWidget);
      expect(tester.getRect(find.byType(Table)).left, closeTo(12.0, 0.01));
    });

    testWidgets('a table inside an alert and inside details renders', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            documentId: 'nested-table-details',
            data:
                '> [!NOTE]\n> ${table.replaceAll('\n', '\n> ')}\n\n'
                '<details open>\n<summary>More</summary>\n\n$table\n\n</details>',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(find.byType(Table), findsNWidgets(2));
    });

    testWidgets('a too-wide table in a list item scrolls inside the item', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          size: const Size(300, 600),
          child: MarkdownView(
            data: '- item\n\n  ${wideTable.replaceAll('\n', '\n  ')}',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(_tableScroll(), findsOneWidget);
      final viewport = tester.getRect(_tableScroll());
      expect(viewport.left, closeTo(22.0, 0.01));
      expect(viewport.right, lessThanOrEqualTo(300.0));
    });

    testWidgets('a too-wide table in a quote scrolls inside the quote', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          size: const Size(300, 600),
          child: MarkdownView(data: '> ${wideTable.replaceAll('\n', '\n> ')}'),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(_tableScroll(), findsOneWidget);
      final viewport = tester.getRect(_tableScroll());
      expect(viewport.right, lessThanOrEqualTo(300.0 - 8.0 + 0.01));
    });
  });

  group('larger tables', () {
    testWidgets('a 150-row table lays out with aligned columns', (
      tester,
    ) async {
      final rows = [for (var i = 0; i < 150; i++) '| r$i | value $i |'];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: '| k | v |\n| --- | --- |\n${rows.join('\n')}',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      final cells = _cells(tester);
      expect(cells.length, 151);
      expect(cells.last[1].left, cells.first[1].left);
      expect(cells.last[1].width, cells.first[1].width);
    });
  });
}
