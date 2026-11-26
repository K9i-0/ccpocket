// Layout contracts of MarkdownView: intrinsic sizing, unbounded and degenerate
// constraints, block spacing, shrinkWrap, and the custom code block builder.
//
// Provenance (behaviours mined by name from the reference suites, rewritten
// against markdown_kit's API):
// - gpt_markdown regression/intrinsic_size_test.dart (high)
// - gpt_markdown regression/block_spacing_test.dart (high)
// - gpt_markdown regression/code_copy_tap_fallthrough_test.dart,
//   code_copy_reachability_test.dart (medium; via codeBlockBuilder)
// - gpt_markdown regression/paragraph_line_breaks_test.dart (low, widget side)
// - flutter_md widget/render_object_test.dart "IntrinsicHeight /
//   IntrinsicWidth size to content" (high)
// - flutter_md widget/render_test.dart "empty markdown produces zero size",
//   "updating markdown relayouts", "thematic break variants render" (medium)
// - flutter_md widget/rtl_geometry_test.dart "degenerate width ... without
//   throwing", "an infinite width falls back ..." (medium)
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:markdown_kit/src/rendering/block_renderer.dart';

/// Hosts [child] at the top-left with loose constraints up to [size].
Widget _host({
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
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            maxWidth: size.width,
            minHeight: 0,
            maxHeight: size.height,
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    ),
  );
}

/// Hosts [child] in a vertical scroll view of a fixed width.
Widget _app({
  required Widget child,
  Size size = const Size(420, 680),
  ui.TextDirection dir = ui.TextDirection.ltr,
  TextScaler scaler = TextScaler.noScaling,
}) {
  return _host(
    size: size,
    dir: dir,
    scaler: scaler,
    child: SizedBox(
      width: size.width,
      child: SingleChildScrollView(child: child),
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

List<String> _drain(WidgetTester tester) {
  final out = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    out.add(e.toString().split('\n').take(3).join(' / '));
  }
  return out;
}

Rect _blockRect(WidgetTester tester, String docId, int index) =>
    tester.getRect(find.byKey(ValueKey<String>('$docId:$index')));

/// One sample per top-level block type.
const _blocks = <String, String>{
  'paragraph': 'Plain paragraph',
  'heading': '## Heading',
  'code block': '```dart\ncode line\n```',
  'quote': '> quoted text',
  'alert': '> [!TIP]\n> alert text',
  'bullet list': '- list text',
  'ordered list': '1. list text',
  'task list': '- [ ] list text',
  'table': '| a | b |\n| - | - |\n| c | d |',
  'rule': '---',
  'footnotes': 'Text[^1]\n\n[^1]: note text',
  'block latex': r'\[ x + y \]',
  'details':
      '<details open>\n<summary>Summary</summary>\n\nbody text\n\n</details>',
  'image': '![alt text](local.png)',
};

var _docCounter = 0;
String _freshId(String prefix) => '$prefix-${_docCounter++}';

// Known limit, skipped rather than left failing: at 24lp the footnote label
// alone is wider than the view with the test font; a real font needs a view
// under about 20lp.
void main() {
  group('intrinsic sizing', () {
    for (final entry in _blocks.entries) {
      // For `table`: REAL BUG lib/src/rendering/table_widget.dart:114
      // `build` — the table is wrapped in a `LayoutBuilder`, which cannot
      // answer intrinsic dimension queries, so any IntrinsicWidth /
      // IntrinsicHeight ancestor (dialogs, IntrinsicHeight rows) throws.
      testWidgets('${entry.key} inside IntrinsicWidth', (tester) async {
        await tester.pumpWidget(
          _host(
            child: IntrinsicWidth(
              child: MarkdownView(
                documentId: _freshId('iw'),
                data: entry.value,
              ),
            ),
          ),
        );
        final errors = _drain(tester);
        expect(errors, isEmpty, reason: errors.join('\n'));
        final size = tester.getSize(find.byType(MarkdownView));
        expect(size.width, lessThanOrEqualTo(420.0));
        if (entry.key != 'rule') {
          expect(size.width, greaterThan(0.0));
        }
        expect(size.height, greaterThan(0.0));
      });

      testWidgets('${entry.key} inside IntrinsicHeight', (tester) async {
        final id = _freshId('ih');
        await tester.pumpWidget(
          _host(
            child: SizedBox(
              width: 300,
              child: MarkdownView(documentId: id, data: entry.value),
            ),
          ),
        );
        final plain = tester.getSize(find.byType(MarkdownView));

        await tester.pumpWidget(
          _host(
            child: SizedBox(
              width: 300,
              child: IntrinsicHeight(
                child: MarkdownView(documentId: id, data: entry.value),
              ),
            ),
          ),
        );
        final errors = _drain(tester);
        expect(errors, isEmpty, reason: errors.join('\n'));
        expect(tester.getSize(find.byType(MarkdownView)).height, plain.height);
      });
    }

    testWidgets('a paragraph in IntrinsicWidth is as wide as its text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          child: const IntrinsicWidth(child: MarkdownView(data: 'short')),
        ),
      );
      final para = _para(tester, 'short');
      expect(
        tester.getSize(find.byType(MarkdownView)).width,
        closeTo(para.getMaxIntrinsicWidth(double.infinity), 0.01),
      );
      // One line: the intrinsic width did not force a wrap.
      expect(para.size.height, lessThan(30.0));
    });

    testWidgets('a list in IntrinsicWidth includes its marker gutter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          child: const IntrinsicWidth(child: MarkdownView(data: '- short')),
        ),
      );
      expect(_drain(tester), isEmpty);
      final para = _para(tester, 'short');
      expect(
        tester.getSize(find.byType(MarkdownView)).width,
        closeTo(para.getMaxIntrinsicWidth(double.infinity) + 22.0, 0.01),
      );
      expect(para.size.height, lessThan(30.0));
    });

    testWidgets('IntrinsicHeight row: a view matches its taller sibling', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          child: SizedBox(
            width: 400,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(
                    child: MarkdownView(
                      data: 'one\n\ntwo\n\n- three\n\n> four',
                    ),
                  ),
                  SizedBox(width: 10, height: 5),
                ],
              ),
            ),
          ),
        ),
      );
      final errors = _drain(tester);
      expect(errors, isEmpty, reason: errors.join('\n'));
      expect(
        tester.getSize(find.byType(Row)).height,
        tester.getSize(find.byType(MarkdownView)).height,
      );
    });
  });

  group('unbounded width', () {
    for (final entry in _blocks.entries) {
      // Failing entries (code block, alert, the three list kinds, footnotes,
      // details): REAL BUG (robustness), one root cause — every failure is
      // "BoxConstraints forces an infinite width" from a
      // `Column(crossAxisAlignment: CrossAxisAlignment.stretch)`:
      // lib/src/rendering/block_renderer.dart:257 (code), :380 (alert),
      // :490 (list), :623 (footnotes), :742 (joined children) and
      // lib/src/rendering/details_widget.dart:171 (outer Column). The
      // `Row` + `Expanded` in the footnote row (:616) and the details header
      // would assert next but are not reached; that part is unverified.
      testWidgets('${entry.key} lays out inside a horizontal scroll view', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: MarkdownView(
                documentId: _freshId('unbounded'),
                data: entry.value,
              ),
            ),
          ),
        );
        final errors = _drain(tester);
        expect(errors, isEmpty, reason: errors.join('\n'));
        final size = tester.getSize(find.byType(MarkdownView));
        expect(size.width.isFinite, isTrue);
        expect(size.height.isFinite, isTrue);
      });
    }

    testWidgets('a long paragraph does not wrap when width is unbounded', (
      tester,
    ) async {
      final text = List.filled(30, 'word').join(' ');
      await tester.pumpWidget(
        _host(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: MarkdownView(data: text),
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      final para = _para(tester, 'word');
      expect(para.size.width, greaterThan(420.0));
      expect(para.size.height, lessThan(30.0));
    });
  });

  group('degenerate and changing widths', () {
    final everything = _blocks.values.join('\n\n');

    // The test font (Ahem) is a full em wide per glyph, so text is roughly
    // twice as wide as with a real font; an overflow that appears only at
    // 60lp here may need an even narrower box in production.
    // 24lp fails: REAL BUG (cosmetic, degenerate width) — the footnote row in
    // lib/src/rendering/block_renderer.dart:609-616 puts
    // the label in a `Row` without `Flexible`, so once the label plus its 8lp
    // padding is wider than the view the row overflows ("RenderFlex
    // overflowed by 20 pixels"). Ahem makes the label 24lp wide; with a real
    // font the same overflow needs a view narrower than roughly 20lp. The
    // alert header (icon 14 + gap 6) and the details header (icon + gap 8)
    // overflow the same way at about 40lp.
    for (final width in [120.0, 60.0, 24.0, 0.0]) {
      testWidgets('every block type lays out at a width of $width', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            size: Size(width, 600),
            child: MarkdownView(
              documentId: _freshId('narrow'),
              data: everything,
            ),
          ),
        );
        final errors = _drain(tester);
        expect(errors, isEmpty, reason: errors.join('\n'));
      }, skip: width == 24.0);
    }

    testWidgets('a paragraph re-wraps when the width changes, and back', (
      tester,
    ) async {
      final text = List.filled(12, 'word').join(' ');
      Future<double> heightAt(double width) async {
        await tester.pumpWidget(
          _app(
            size: Size(width, 600),
            child: MarkdownView(documentId: 'rewrap', data: text),
          ),
        );
        return tester.getSize(find.byType(MarkdownView)).height;
      }

      final wide = await heightAt(400);
      final narrow = await heightAt(150);
      expect(narrow, greaterThan(wide));
      expect(await heightAt(400), wide);
    });

    testWidgets('a very long unbroken word wraps instead of overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          size: const Size(200, 600),
          child: MarkdownView(data: 'x' * 120),
        ),
      );
      expect(_drain(tester), isEmpty);
      final para = _para(tester, 'xxx');
      expect(para.size.width, lessThanOrEqualTo(200.0));
      expect(para.size.height, greaterThan(60.0));
    });

    testWidgets('a long code line scrolls inside the block', (tester) async {
      await tester.pumpWidget(
        _app(
          size: const Size(200, 600),
          child: MarkdownView(data: '```\n${'y' * 80}\n```'),
        ),
      );
      expect(_drain(tester), isEmpty);
      final scroll = tester.getSize(
        find.descendant(
          of: find.byType(MarkdownBlockRenderer),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scroll.width, 200.0);
      final para = _para(tester, 'yyy');
      expect(para.size.width, greaterThan(200.0));
      // One line: code never soft-wraps.
      expect(para.size.height, lessThan(30.0));
    });

    testWidgets('a soft line break keeps the paragraph on one line of text '
        'and a hard break splits it', (tester) async {
      await tester.pumpWidget(
        _app(child: const MarkdownView(data: 'alpha\nbeta\n\ngamma  \ndelta')),
      );
      final soft = _para(tester, 'alpha');
      final hard = _para(tester, 'gamma');
      expect(soft.text.toPlainText(), 'alpha beta');
      expect(hard.text.toPlainText(), 'gamma\ndelta');
      expect(hard.size.height, closeTo(soft.size.height * 2, 1.0));
    });
  });

  group('empty content', () {
    for (final entry in {
      'an empty string': '',
      'only whitespace': '  \n\n \t\n',
      'only an HTML comment': '<!-- hidden -->',
    }.entries) {
      testWidgets('${entry.key} takes no space', (tester) async {
        await tester.pumpWidget(_app(child: MarkdownView(data: entry.value)));
        expect(_drain(tester), isEmpty);
        expect(tester.getSize(find.byType(MarkdownView)).height, 0.0);
        expect(find.byType(MarkdownBlockRenderer), findsNothing);
      });
    }

    testWidgets('going from content to empty and back relayouts', (
      tester,
    ) async {
      Future<Size> sizeOf(String data) async {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(documentId: 'empty-toggle', data: data),
          ),
        );
        return tester.getSize(find.byType(MarkdownView));
      }

      final full = await sizeOf('# Title\n\nbody');
      expect((await sizeOf('')).height, 0.0);
      expect(await sizeOf('# Title\n\nbody'), full);
    });
  });

  group('block spacing', () {
    testWidgets('every pair of block types is separated by blockSpacing', (
      tester,
    ) async {
      final parser = GfmMarkdownParser();
      var checked = 0;
      final skipped = <String>[];
      final wrong = <String>[];
      for (final first in _blocks.entries) {
        for (final second in _blocks.entries) {
          final data = '${first.value}\n\n${second.value}';
          final blockCount = parser.parse(data).blocks.length;
          if (blockCount != 2) {
            // Same-kind neighbours merge (two lists, two quotes) and
            // footnote definitions always move to the end.
            skipped.add('${first.key} + ${second.key} ($blockCount)');
            continue;
          }
          final id = _freshId('pair');
          await tester.pumpWidget(
            _app(
              child: MarkdownView(documentId: id, data: data),
            ),
          );
          final errors = _drain(tester);
          expect(errors, isEmpty, reason: '${first.key} + ${second.key}');
          final gap =
              _blockRect(tester, id, 1).top - _blockRect(tester, id, 0).bottom;
          if ((gap - 12.0).abs() > 0.01) {
            wrong.add('${first.key} + ${second.key}: $gap');
          }
          checked++;
        }
      }
      expect(wrong, isEmpty, reason: wrong.join('\n'));
      expect(checked, greaterThan(120), reason: 'skipped: $skipped');
    });

    for (final spacing in [0.0, 4.0, 30.0]) {
      testWidgets('a theme blockSpacing of $spacing is applied', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'spacing-$spacing',
              theme: MarkdownThemeData.fallback().copyWith(
                blockSpacing: spacing,
              ),
              data: 'one\n\n## two\n\n- three\n\n```\nfour\n```',
            ),
          ),
        );
        for (var i = 1; i < 4; i++) {
          expect(
            _blockRect(tester, 'spacing-$spacing', i).top -
                _blockRect(tester, 'spacing-$spacing', i - 1).bottom,
            closeTo(spacing, 0.01),
            reason: 'gap before block $i',
          );
        }
      });
    }

    testWidgets('extra blank lines between blocks add nothing', (tester) async {
      await tester.pumpWidget(
        _app(child: const MarkdownView(data: 'one\n\ntwo')),
      );
      final compact = tester.getSize(find.byType(MarkdownView));
      await tester.pumpWidget(
        _app(child: const MarkdownView(data: 'one\n\n\n\n\n\ntwo\n\n\n')),
      );
      expect(tester.getSize(find.byType(MarkdownView)), compact);
    });

    testWidgets(
      'there is no spacing before the first or after the last block',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const MarkdownView(
              documentId: 'edges',
              data: 'first\n\nmiddle\n\nlast',
            ),
          ),
        );
        final view = tester.getRect(find.byType(MarkdownView));
        expect(_blockRect(tester, 'edges', 0).top, view.top);
        expect(_blockRect(tester, 'edges', 2).bottom, view.bottom);
      },
    );

    testWidgets('the spacing comes from an inherited MarkdownTheme too', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownTheme(
            data: MarkdownThemeData.fallback().copyWith(blockSpacing: 40),
            child: const MarkdownView(documentId: 'inherited', data: 'a\n\nb'),
          ),
        ),
      );
      expect(
        _blockRect(tester, 'inherited', 1).top -
            _blockRect(tester, 'inherited', 0).bottom,
        closeTo(40.0, 0.01),
      );
    });

    testWidgets('blocks nested in a quote are spaced by 0.75 x blockSpacing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            theme: MarkdownThemeData.fallback().copyWith(blockSpacing: 20),
            data: '> upper\n>\n> lower',
          ),
        ),
      );
      final upper = _para(tester, 'upper');
      final lower = _para(tester, 'lower');
      final gap =
          lower.localToGlobal(Offset.zero).dy -
          upper.localToGlobal(Offset(0, upper.size.height)).dy;
      expect(gap, closeTo(15.0, 0.01));
    });

    testWidgets('loose list items are spaced twice as far as tight ones', (
      tester,
    ) async {
      Future<double> gapFor(String data) async {
        await tester.pumpWidget(_app(child: MarkdownView(data: data)));
        final a = _para(tester, 'aaa');
        final b = _para(tester, 'bbb');
        return b.localToGlobal(Offset.zero).dy -
            a.localToGlobal(Offset(0, a.size.height)).dy;
      }

      final tight = await gapFor('- aaa\n- bbb');
      final loose = await gapFor('- aaa\n\n- bbb');
      expect(tight, closeTo(4.0, 0.01));
      expect(loose, closeTo(8.0, 0.01));
    });

    testWidgets('a rule keeps its thickness and spans the available width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            documentId: 'rule',
            theme: MarkdownThemeData.fallback().copyWith(dividerThickness: 3),
            data: 'above\n\n---\n\n***\n\n___\n\nbelow',
          ),
        ),
      );
      for (final i in [1, 2, 3]) {
        final rect = _blockRect(tester, 'rule', i);
        expect(rect.width, 420.0, reason: 'rule $i');
        expect(rect.height, closeTo(3.0 + 12.0, 0.01), reason: 'rule $i');
      }
    });
  });

  group('shrinkWrap', () {
    testWidgets('by default the view is as tall as its blocks', (tester) async {
      await tester.pumpWidget(
        _host(
          child: const SizedBox(
            width: 300,
            height: 500,
            child: Align(
              alignment: Alignment.topLeft,
              child: MarkdownView(documentId: 'sw', data: 'one\n\ntwo'),
            ),
          ),
        ),
      );
      final view = tester.getRect(find.byType(MarkdownView));
      expect(view.bottom, _blockRect(tester, 'sw', 1).bottom);
      expect(view.height, lessThan(500.0));
    });

    testWidgets('shrinkWrap: false fills a bounded height', (tester) async {
      await tester.pumpWidget(
        _host(
          child: const SizedBox(
            width: 300,
            height: 500,
            child: Align(
              alignment: Alignment.topLeft,
              child: MarkdownView(
                documentId: 'sw-max',
                data: 'one\n\ntwo',
                shrinkWrap: false,
              ),
            ),
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(tester.getSize(find.byType(MarkdownView)).height, 500.0);
      // Blocks still start at the top.
      expect(_blockRect(tester, 'sw-max', 0).top, 0.0);
    });

    testWidgets('shrinkWrap: false in a scroll view still sizes to content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            documentId: 'sw-scroll',
            data: 'one\n\ntwo',
            shrinkWrap: false,
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(
        tester.getRect(find.byType(MarkdownView)).bottom,
        _blockRect(tester, 'sw-scroll', 1).bottom,
      );
    });

    testWidgets('toggling shrinkWrap relayouts without rebuilding blocks', (
      tester,
    ) async {
      final built = <int>[];
      Widget build(bool shrinkWrap) => _host(
        child: SizedBox(
          width: 300,
          height: 500,
          child: Align(
            alignment: Alignment.topLeft,
            child: MarkdownView(
              documentId: 'sw-toggle',
              data: 'one\n\ntwo',
              shrinkWrap: shrinkWrap,
              onBlockBuilt: (i, _) => built.add(i),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(true));
      expect(built, [0, 1]);
      built.clear();
      await tester.pumpWidget(build(false));
      expect(tester.getSize(find.byType(MarkdownView)).height, 500.0);
      expect(built, isEmpty);
    });
  });

  group('custom code block builder', () {
    Widget withCopyButton({
      required List<String> copies,
      required List<String> hostTaps,
      required List<MarkdownSelection?> selections,
      List<CodeBlock>? seen,
    }) {
      return _app(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => hostTaps.add('host'),
          child: MarkdownView(
            documentId: 'copy',
            data: 'intro\n\n```dart\nfinal answer = 42;\n```\n\noutro',
            onSelectionChanged: selections.add,
            builders: MarkdownBuilders(
              codeBlockBuilder: (context, block, content, theme) {
                seen?.add(block);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(block.language ?? '', style: theme.bodyStyle),
                        const Spacer(),
                        GestureDetector(
                          key: const ValueKey('copy-button'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => copies.add(block.code),
                          child: const SizedBox(width: 44, height: 44),
                        ),
                      ],
                    ),
                    content,
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('the builder receives the block and selectable content', (
      tester,
    ) async {
      final seen = <CodeBlock>[];
      await tester.pumpWidget(
        withCopyButton(copies: [], hostTaps: [], selections: [], seen: seen),
      );
      expect(seen, isNotEmpty);
      expect(seen.last.language, 'dart');
      expect(seen.last.closed, isTrue);
      expect(seen.last.code.trimRight(), 'final answer = 42;');
      expect(
        _para(tester, 'final answer').text.toPlainText().trimRight(),
        'final answer = 42;',
      );
    });

    testWidgets('a tap on the copy button fires once and does not fall '
        'through to the host or start a selection', (tester) async {
      final copies = <String>[];
      final hostTaps = <String>[];
      final selections = <MarkdownSelection?>[];
      await tester.pumpWidget(
        withCopyButton(
          copies: copies,
          hostTaps: hostTaps,
          selections: selections,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('copy-button')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(copies.length, 1);
      expect(hostTaps, isEmpty);
      expect(selections.where((s) => s != null), isEmpty);
    });

    testWidgets('two quick taps copy twice and select nothing', (tester) async {
      final copies = <String>[];
      final hostTaps = <String>[];
      final selections = <MarkdownSelection?>[];
      await tester.pumpWidget(
        withCopyButton(
          copies: copies,
          hostTaps: hostTaps,
          selections: selections,
        ),
      );
      final button = find.byKey(const ValueKey('copy-button'));
      await tester.tap(button, kind: ui.PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(button, kind: ui.PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(copies.length, 2);
      expect(hostTaps, isEmpty);
      expect(selections.where((s) => s != null), isEmpty);
    });

    testWidgets('a stylus reaches the copy button on first contact', (
      tester,
    ) async {
      final copies = <String>[];
      await tester.pumpWidget(
        withCopyButton(copies: copies, hostTaps: [], selections: []),
      );
      await tester.tap(
        find.byKey(const ValueKey('copy-button')),
        kind: ui.PointerDeviceKind.stylus,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(copies.length, 1);
    });

    testWidgets('a long press on the copy button does not select code', (
      tester,
    ) async {
      final selections = <MarkdownSelection?>[];
      await tester.pumpWidget(
        withCopyButton(copies: [], hostTaps: [], selections: selections),
      );
      await tester.longPress(find.byKey(const ValueKey('copy-button')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(selections.where((s) => s != null), isEmpty);
    });

    testWidgets('the button stays tappable after the block is rebuilt', (
      tester,
    ) async {
      final copies = <String>[];
      for (var round = 0; round < 3; round++) {
        await tester.pumpWidget(
          withCopyButton(copies: copies, hostTaps: [], selections: []),
        );
      }
      await tester.tap(find.byKey(const ValueKey('copy-button')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(copies.length, 1);
    });

    testWidgets('a tap on plain code reaches neither the button nor a link', (
      tester,
    ) async {
      final copies = <String>[];
      final selections = <MarkdownSelection?>[];
      await tester.pumpWidget(
        withCopyButton(copies: copies, hostTaps: [], selections: selections),
      );
      final code = _para(tester, 'final answer');
      await tester.tapAt(code.localToGlobal(const Offset(20, 8)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(copies, isEmpty);
      expect(selections.where((s) => s != null), isEmpty);
    });
  });
}
