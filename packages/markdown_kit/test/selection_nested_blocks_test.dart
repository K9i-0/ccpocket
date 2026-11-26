// Selection and copy across nested block structures: lists in quotes, code
// in quotes and alerts, nested lists, tables and <details>.
//
// Gap inventory against the reference suite (flutter_md, MIT), by test name:
//
// selection/selection_nested_blocks_test.dart
//   (b) ported: the painter fragments agree with the block rendered text
//       [high] (here: every mounted surface tiles extractBlockRenderedText);
//       selecting the whole nested quote yields every child line [high]; a
//       highlight range inside the nested fence has geometry [high]; a nested
//       quote paints without exceptions [medium]; an unterminated fence
//       inside a quote does not hang [medium]; the markup formatter
//       round-trips a nested fence [high].
//   (d) not applicable: "parses into nested blocks" / "keeps the leaf inline
//       shape" (parser shape, owned by the parser tests); "a custom theme
//       builder also builds nested children" (rendering).
//
// selection/selection_widget_test.dart
//   (b) ported: drag selects the cells of a table [high]; drag selects the
//       items of a list [high]; selection spanning a table includes its
//       cells [high]; triple-click selects the whole block [medium].
//
// New here: <details> open / closed (unique documentId per test because the
// open state is cached per documentId + block position + summary).
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:markdown_kit/src/selection/selection_handles.dart';

Widget _testApp({required Widget child}) {
  return Directionality(
    key: UniqueKey(),
    textDirection: ui.TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
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

MarkdownPosition _pos(String doc, int block, int offset) =>
    MarkdownPosition(documentId: doc, blockIndex: block, offset: offset);

MarkdownSelection _sel(MarkdownPosition base, MarkdownPosition extent) =>
    MarkdownSelection(base: base, extent: extent);

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

/// Global centre of the first glyph of [needle] inside its paragraph, shifted
/// by [glyph] characters.
Offset _at(WidgetTester tester, String needle, {int glyph = 0}) {
  final p = _paragraph(tester, needle);
  final index = p.baseText.toPlainText().indexOf(needle) + glyph;
  final box = p.boxesForLocalRange(index, index + 1).first.toRect();
  return p.localToGlobal(box.center);
}

class _Mounted {
  _Mounted(this.controller, this.document, this.documentId);
  final MarkdownSelectionController controller;
  final MarkdownDocument document;
  final String documentId;

  String blockText(int index) =>
      extractBlockRenderedText(document.blocks[index]);
}

Future<_Mounted> _pump(
  WidgetTester tester,
  String markdown, {
  String documentId = 'doc',
  double width = 520,
}) async {
  final controller = MarkdownSelectionController();
  addTearDown(controller.dispose);
  final document = GfmMarkdownParser().parse(markdown);
  await tester.pumpWidget(
    _testApp(
      child: MarkdownSelectionScope(
        controller: controller,
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: width,
                child: MarkdownView(
                  document: document,
                  documentId: documentId,
                  theme: MarkdownThemeData.fallback(),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Mounted(controller, document, documentId);
}

Future<void> _mouseDrag(WidgetTester tester, Offset from, Offset to) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: from);
  await tester.pump();
  await mouse.down(from);
  await tester.pump();
  await mouse.moveTo(Offset.lerp(from, to, 0.5)!);
  await tester.pump();
  await mouse.moveTo(to);
  await tester.pump();
  await mouse.up();
  await mouse.removePointer();
  await tester.pump();
}

Future<void> _clicks(WidgetTester tester, Offset at, int count) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: at);
  for (var i = 0; i < count; i++) {
    await mouse.down(at);
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 40));
  }
  await mouse.removePointer();
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
}

void _onDesktop(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

const _samples = <String, String>{
  'list in quote': '> intro line\n>\n> - first item\n> - second item\n',
  'fence in quote': '> before\n>\n> ```dart\n> final x = 1;\n> print(x);\n> ```\n>\n> after\n',
  'alert with list and fence': '> [!NOTE]\n> Heads up\n>\n> - one\n> - two\n>\n> ```\n> code line\n> ```\n',
  'quote in quote': '> outer\n>\n> > inner one\n> > inner two\n>\n> tail\n',
  'nested lists': '- top one\n  - mid one\n    - deep one\n    - deep two\n  - mid two\n- top two\n',
  'ordered list with paragraph and fence': '1. first\n\n   continued paragraph\n\n   ```\n   in item\n   ```\n2. second\n',
  'task list': '- [x] done item\n- [ ] open item\n  - [ ] child item\n',
  'quote in list': '- item\n\n  > quoted in item\n\n- other\n',
  'table': '| Name | Value |\n|---|---|\n| alpha | 1 |\n| beta | 2 |\n',
  'table with inline formatting': '| Key | Note |\n|---|---|\n| `code` | **bold** text |\n| [link](https://x.example) | plain |\n',
  'open details': '<details open>\n<summary>Summary line</summary>\n\nbody paragraph\n\n- body item\n\n</details>\n',
};

final _separators = RegExp(r'^[\n\t]*$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mounted surfaces tile the block rendered text', () {
    var sampleIndex = 0;
    _samples.forEach((name, markdown) {
      final documentId = 'tile-${sampleIndex++}';
      testWidgets(name, (tester) async {
        final m = await _pump(tester, markdown, documentId: documentId);
        expect(tester.takeException(), isNull);

        for (var b = 0; b < m.document.blocks.length; b++) {
          final text = m.blockText(b);
          final surfaces =
              m.controller.mountedSurfaces
                  .where((s) => s.blockIndex == b)
                  .toList()
                ..sort(
                  (x, y) => x.textOffsetInBlock.compareTo(y.textOffsetInBlock),
                );
          if (text.isEmpty) {
            expect(surfaces, isEmpty, reason: 'block $b has no text');
            continue;
          }
          expect(surfaces, isNotEmpty, reason: 'block $b is not selectable');

          var cursor = 0;
          for (final s in surfaces) {
            expect(
              s.textOffsetInBlock,
              greaterThanOrEqualTo(cursor),
              reason: 'block $b: surfaces overlap at ${s.textOffsetInBlock}',
            );
            expect(s.blockEndOffset, lessThanOrEqualTo(text.length));
            expect(
              text.substring(cursor, s.textOffsetInBlock),
              matches(_separators),
              reason: 'block $b: text between surfaces is not a separator',
            );
            final painted = (s as RenderSelectableParagraph).baseText
                .toPlainText();
            if (painted.length == s.textLength) {
              expect(
                painted,
                text.substring(s.textOffsetInBlock, s.blockEndOffset),
                reason: 'block $b: surface at ${s.textOffsetInBlock}',
              );
            }
            cursor = s.blockEndOffset;
          }
          expect(
            text.substring(cursor),
            matches(_separators),
            reason: 'block $b: trailing text is not covered by a surface',
          );
        }
      });
    });
  });

  group('Select all across nested structures', () {
    var sampleIndex = 0;
    _samples.forEach((name, markdown) {
      final documentId = 'all-${sampleIndex++}';
      testWidgets('$name: plain copy is the rendered text and every surface '
          'is fully highlighted', (tester) async {
        final m = await _pump(tester, markdown, documentId: documentId);
        expect(m.controller.selectAll(), isTrue);
        await tester.pump();

        expect(
          m.controller.getText(),
          [
            for (var b = 0; b < m.document.blocks.length; b++)
              if (m.blockText(b).isNotEmpty) m.blockText(b),
          ].join('\n\n'),
        );
        final rects = m.controller.globalSelectionRects();
        expect(
          rects.length,
          greaterThanOrEqualTo(m.controller.mountedSurfaces.length),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('$name: Markdown copy parses back to the same rendered '
          'text', (tester) async {
        final m = await _pump(tester, markdown, documentId: 'md-$documentId');
        expect(m.controller.selectAll(), isTrue);
        final copied = m.controller.getMarkdown();
        final reparsed = GfmMarkdownParser().parse(copied);
        expect(
          extractDocumentRenderedText(reparsed),
          extractDocumentRenderedText(m.document),
          reason: 'copied markdown:\n$copied',
        );
        expect(
          reparsed.blocks.map((b) => b.runtimeType).toList(),
          m.document.blocks.map((b) => b.runtimeType).toList(),
        );
      });
    });
  });

  group('Partial selections inside nested structures', () {
    testWidgets('a range inside a quoted list copies the exact slice in '
        'both formats', (tester) async {
      final m = await _pump(
        tester,
        '> intro line\n>\n> - first item\n> - second item\n',
      );
      final text = m.blockText(0);
      final start = text.indexOf('rst item');
      final end = text.indexOf('second') + 3;
      m.controller.setSelection(
        _sel(_pos('doc', 0, start), _pos('doc', 0, end)),
      );

      expect(m.controller.getText(), text.substring(start, end));
      expect(m.controller.getText(), 'rst item\nsec');
      final markdown = m.controller.getMarkdown();
      expect(markdown, isNot(contains('intro')));
      expect(markdown, isNot(contains('ond item')));
      expect(markdown, contains('rst item'));
    });

    testWidgets('a range inside a quoted fence highlights only inside the '
        'code surface', (tester) async {
      final m = await _pump(
        tester,
        '> before\n>\n> ```dart\n> final x = 1;\n> print(x);\n> ```\n>\n> after\n',
      );
      final text = m.blockText(0);
      final start = text.indexOf('x = 1');
      final end = text.indexOf('print') + 5;
      m.controller.setSelection(
        _sel(_pos('doc', 0, start), _pos('doc', 0, end)),
      );
      await tester.pump();

      final code = _paragraph(tester, 'final x');
      final rects = m.controller.globalSelectionRects();
      expect(rects, isNotEmpty);
      final codeBounds = code.globalBounds!.inflate(0.5);
      for (final rect in rects) {
        expect(
          codeBounds.contains(rect.center),
          isTrue,
          reason: '$rect is outside the code surface $codeBounds',
        );
      }
      expect(m.controller.getText(), 'x = 1;\nprint');

      final endpoints = m.controller.selectionHandleEndpoints()!;
      expect(endpoints.startSurface, same(code));
      expect(endpoints.endSurface, same(code));
    });

    testWidgets('a range across two table rows copies tab and newline '
        'separated cells', (tester) async {
      final m = await _pump(
        tester,
        '| Name | Value |\n|---|---|\n| alpha | 1 |\n| beta | 2 |\n',
      );
      final text = m.blockText(0);
      expect(text, 'Name\tValue\nalpha\t1\nbeta\t2');
      final start = text.indexOf('alpha') + 2;
      final end = text.indexOf('beta') + 2;
      m.controller.setSelection(
        _sel(_pos('doc', 0, start), _pos('doc', 0, end)),
      );

      expect(m.controller.getText(), 'pha\t1\nbe');
      expect(m.controller.getMarkdown(), isNot(contains('Name')));
    });

    testWidgets('an endpoint on a separator between cells still resolves '
        'to a mounted cell', (tester) async {
      final m = await _pump(
        tester,
        '| Name | Value |\n|---|---|\n| alpha | 1 |\n| beta | 2 |\n',
      );
      final text = m.blockText(0);
      // Start right after "Name" (on the tab), end right after "alpha".
      m.controller.setSelection(
        _sel(_pos('doc', 0, 4), _pos('doc', 0, text.indexOf('alpha') + 5)),
      );
      await tester.pump();

      final endpoints = m.controller.selectionHandleEndpoints()!;
      expect(endpoints.hasStart && endpoints.hasEnd, isTrue);
      expect(endpoints.endSurface, same(_paragraph(tester, 'alpha')));
      expect(m.controller.getText(), '\tValue\nalpha');
    });

    testWidgets('a nested list range spanning three depths copies one line '
        'per item', (tester) async {
      final m = await _pump(
        tester,
        '- top one\n  - mid one\n    - deep one\n    - deep two\n  - mid two\n- top two\n',
      );
      final text = m.blockText(0);
      final start = text.indexOf('mid one');
      final end = text.indexOf('mid two') + 3;
      m.controller.setSelection(
        _sel(_pos('doc', 0, start), _pos('doc', 0, end)),
      );
      expect(m.controller.getText().split('\n'), [
        'mid one',
        'deep one',
        'deep two',
        'mid',
      ]);
    });
  });

  group('Pointer selection in nested structures', () {
    _onDesktop('a drag across table cells selects them in row order', (
      tester,
    ) async {
      final m = await _pump(
        tester,
        '| cellA | cellB |\n|---|---|\n| cellC | cellD |\n| cellE | cellF |\n',
      );
      final from = _at(tester, 'cellA') - const Offset(7, 0);
      final to = _at(tester, 'cellF', glyph: 4) + const Offset(7, 0);
      await _mouseDrag(tester, from, to);

      expect(
        m.controller.getText(),
        'cellA\tcellB\ncellC\tcellD\ncellE\tcellF',
      );
    });

    _onDesktop('a drag from the second row leaves the header out', (
      tester,
    ) async {
      final m = await _pump(
        tester,
        '| cellA | cellB |\n|---|---|\n| cellC | cellD |\n| cellE | cellF |\n',
      );
      final from = _at(tester, 'cellD') - const Offset(7, 0);
      final to = _at(tester, 'cellE', glyph: 4) + const Offset(7, 0);
      await _mouseDrag(tester, from, to);

      expect(m.controller.getText(), 'cellD\ncellE');
    });

    _onDesktop('a drag down a list selects its items one per line', (
      tester,
    ) async {
      final m = await _pump(tester, '- one item\n- two item\n- three item\n');
      final from = _at(tester, 'one item') - const Offset(7, 0);
      final to = _at(tester, 'three item', glyph: 4) + const Offset(7, 0);
      await _mouseDrag(tester, from, to);

      expect(m.controller.getText(), 'one item\ntwo item\nthree');
    });

    _onDesktop('a drag from a paragraph through a table into the next '
        'paragraph includes every cell', (tester) async {
      final m = await _pump(
        tester,
        'lead paragraph\n\n| cellA | cellB |\n|---|---|\n| cellC | cellD |\n\ntail paragraph\n',
      );
      final from = _at(tester, 'lead paragraph', glyph: 5) - const Offset(7, 0);
      final to = _at(tester, 'tail paragraph', glyph: 3) + const Offset(7, 0);
      await _mouseDrag(tester, from, to);

      expect(
        m.controller.getText(),
        'paragraph\n\ncellA\tcellB\ncellC\tcellD\n\ntail',
      );
      expect(
        m.controller.getMarkdown(),
        contains('| cellA | cellB |\n| --- | --- |\n| cellC | cellD |'),
      );
    });

    _onDesktop('a drag from a quoted paragraph into its nested list '
        'crosses the nesting', (tester) async {
      final m = await _pump(
        tester,
        '> intro line\n>\n> - first item\n> - second item\n',
      );
      final from = _at(tester, 'intro line', glyph: 6) - const Offset(7, 0);
      final to = _at(tester, 'second item', glyph: 5) + const Offset(7, 0);
      await _mouseDrag(tester, from, to);

      expect(m.controller.getText(), 'line\nfirst item\nsecond');
    });

    _onDesktop('a double-click inside a deep list item selects that word', (
      tester,
    ) async {
      final m = await _pump(
        tester,
        '- top one\n  - mid one\n    - deepest words here\n',
      );
      await _clicks(tester, _at(tester, 'words', glyph: 2), 2);
      expect(m.controller.getText(), 'words');
    });

    _onDesktop('a double-click inside a table cell selects only that cell '
        'word', (tester) async {
      final m = await _pump(
        tester,
        '| cellA | cellB |\n|---|---|\n| cellC | two words |\n',
      );
      await _clicks(tester, _at(tester, 'two words', glyph: 5), 2);
      expect(m.controller.getText(), 'words');
    });

    _onDesktop('a triple-click inside a quote selects the whole top-level '
        'block', (tester) async {
      final m = await _pump(
        tester,
        'outside\n\n> intro line\n>\n> - first item\n> - second item\n',
      );
      await _clicks(tester, _at(tester, 'first item', glyph: 2), 3);
      expect(
        m.controller.selection,
        _sel(_pos('doc', 1, 0), _pos('doc', 1, m.blockText(1).length)),
      );
      expect(m.controller.getText(), 'intro line\nfirst item\nsecond item');
    });

    testWidgets('a touch long-press inside a nested code block selects the '
        'pressed word and shows both handles', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final m = await _pump(
          tester,
          '> [!TIP]\n> Try this\n>\n> ```\n> alpha beta\n> ```\n',
        );
        final gesture = await tester.startGesture(
          _at(tester, 'beta', glyph: 1),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(m.controller.getText(), 'beta');
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.startHandleKey),
          findsOneWidget,
        );
        expect(
          find.byKey(MarkdownSelectionHandleOverlay.endHandleKey),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Robustness', () {
    testWidgets('an unterminated fence inside a quote renders, selects and '
        'copies', (tester) async {
      final m = await _pump(tester, '> before\n>\n> ```\n> never closed\n');
      expect(tester.takeException(), isNull);
      expect(m.controller.selectAll(), isTrue);
      expect(m.controller.getText(), contains('never closed'));
      expect(m.controller.getMarkdown(), contains('never closed'));
    });

    testWidgets('a quote whose body is only a fence is selectable', (
      tester,
    ) async {
      final m = await _pump(tester, '> ```\n> only code\n> ```\n');
      expect(m.controller.selectAll(), isTrue);
      expect(m.controller.getText(), 'only code');
    });

    testWidgets('a list item that holds only a nested list is selectable', (
      tester,
    ) async {
      final m = await _pump(tester, '- - inner only\n  - inner two\n');
      expect(tester.takeException(), isNull);
      expect(m.controller.selectAll(), isTrue);
      expect(m.controller.getText(), contains('inner only'));
      expect(m.controller.getText(), contains('inner two'));
    });

    testWidgets('a table with an empty cell keeps its column separators', (
      tester,
    ) async {
      final m = await _pump(
        tester,
        '| cellA | cellB | cellC |\n|---|---|---|\n| one |  | three |\n',
      );
      expect(m.controller.selectAll(), isTrue);
      expect(m.controller.getText(), 'cellA\tcellB\tcellC\none\t\tthree');
      expect(tester.takeException(), isNull);
    });
  });

  group('<details>', () {
    const body =
        '<summary>Summary line</summary>\n\nbody paragraph\n\n- body item\n\n</details>\n';

    testWidgets('open: the summary and the body are both selectable', (
      tester,
    ) async {
      final m = await _pump(
        tester,
        '<details open>\n$body',
        documentId: 'details-open-selectable',
      );
      expect(m.document.blocks.single, isA<HtmlDetailsBlock>());
      expect(m.controller.mountedSurfaces.length, greaterThanOrEqualTo(3));
      expect(m.controller.selectWordAtGlobal(_at(tester, 'paragraph')), isTrue);
      expect(m.controller.getText(), 'paragraph');
      expect(m.controller.selectWordAtGlobal(_at(tester, 'Summary')), isTrue);
      expect(m.controller.getText(), 'Summary');
    });

    testWidgets('open: select all copies summary then body, and Markdown '
        'copy keeps the details element', (tester) async {
      final m = await _pump(
        tester,
        '<details open>\n$body',
        documentId: 'details-open-copy',
      );
      expect(m.controller.selectAll(), isTrue);
      expect(m.controller.getText(), 'Summary line\nbody paragraph\nbody item');
      final markdown = m.controller.getMarkdown();
      expect(markdown, contains('<details'));
      expect(markdown, contains('<summary>Summary line</summary>'));
      expect(markdown, contains('- body item'));
      expect(markdown, contains('</details>'));
    });

    testWidgets('closed: only the summary is mounted and it is selectable', (
      tester,
    ) async {
      final m = await _pump(
        tester,
        '<details>\n$body',
        documentId: 'details-closed-summary',
      );
      expect(find.text('body paragraph', findRichText: true), findsNothing);
      expect(m.controller.mountedSurfaces, hasLength(1));
      expect(m.controller.selectWordAtGlobal(_at(tester, 'Summary')), isTrue);
      expect(m.controller.getText(), 'Summary');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a paragraph after an open details keeps its own block '
        'index for selection', (tester) async {
      final m = await _pump(
        tester,
        '<details open>\n$body\nafter details\n',
        documentId: 'details-open-after',
      );
      expect(m.document.blocks, hasLength(2));
      expect(
        m.controller.selectWordAtGlobal(_at(tester, 'after details')),
        isTrue,
      );
      expect(m.controller.selection!.base.blockIndex, 1);
      expect(m.controller.getText(), 'after');
    });
  });
}
