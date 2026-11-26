// Text scaling behaviour of the rendering layer.
//
// Provenance (behaviours mined by name from the reference suites, rewritten
// against markdown_kit's API):
// - gpt_markdown regression/list_text_scaling_test.dart (high)
// - gpt_markdown regression/nested_text_scaling_test.dart (high)
// - gpt_markdown regression/block_text_scaling_test.dart (high)
// - gpt_markdown regression/custom_block_scaling_test.dart (medium)
// - gpt_markdown regression/math_text_scaling_test.dart (low, fallback only)
// - flutter_md widget/inline_image_test.dart "constraints ... scale the font
//   size" (low)
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:markdown_kit/src/rendering/list_item_widget.dart';
import 'package:markdown_kit/src/rendering/table_widget.dart';

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
      final p = _firstPara(ro);
      if (p != null && p.text.toPlainText().contains(containing)) return ro;
    }
  }
  fail('No list item containing "$containing".');
}

RenderSelectableParagraph? _firstPara(RenderObject root) {
  RenderSelectableParagraph? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is RenderSelectableParagraph) {
      found = o;
      return;
    }
    o.visitChildren(visit);
  }

  visit(root);
  return found;
}

/// What a list item painted for its marker, in the item's own coordinates.
class _Marker {
  _Marker({this.circleCenter, this.circleRadius, this.box, this.ordinalDy});

  final Offset? circleCenter;
  final double? circleRadius;
  final Rect? box;
  final double? ordinalDy;
}

/// Geometry of an item: marker, and the first text line of its child.
class _ItemGeometry {
  _ItemGeometry({
    required this.marker,
    required this.firstLineTop,
    required this.firstLineHeight,
    required this.textLeft,
    required this.itemSize,
    required this.textDy,
  });

  final _Marker marker;
  final double firstLineTop;
  final double firstLineHeight;
  final double textLeft;
  final Size itemSize;

  /// dy at which the child paragraph was painted (first drawParagraph after
  /// the marker).
  final double? textDy;

  /// Vertical position of the marker centre as a fraction of the first line.
  double get centreFraction {
    final cy = marker.circleCenter?.dy ?? marker.box!.center.dy;
    return (cy - firstLineTop) / firstLineHeight;
  }
}

_ItemGeometry _geometry(WidgetTester tester, String containing) {
  final item = _item(tester, containing);
  final para = _firstPara(item)!;
  final canvas = TestRecordingCanvas();
  final context = TestRecordingPaintingContext(canvas);
  item.paint(context, Offset.zero);

  Offset? circleCenter;
  double? circleRadius;
  Rect? box;
  final paragraphDys = <double>[];
  for (final recorded in canvas.invocations) {
    final inv = recorded.invocation;
    final args = inv.positionalArguments;
    if (inv.memberName == #drawCircle && circleCenter == null) {
      circleCenter = args[0] as Offset;
      circleRadius = args[1] as double;
    } else if (inv.memberName == #drawRRect && box == null) {
      box = (args[0] as RRect).outerRect;
    } else if (inv.memberName == #drawRect && box == null) {
      box = args[0] as Rect;
    } else if (inv.memberName == #drawParagraph) {
      paragraphDys.add((args[1] as Offset).dy);
    }
  }

  final paraOrigin = item.globalToLocal(para.localToGlobal(Offset.zero));
  final firstLine = para
      .getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 1),
        boxHeightStyle: ui.BoxHeightStyle.max,
      )
      .first
      .toRect();

  final isOrdered = item.markerKind == MarkdownListMarkerKind.ordered;
  return _ItemGeometry(
    marker: _Marker(
      circleCenter: circleCenter,
      circleRadius: circleRadius,
      box: box,
      ordinalDy: isOrdered && paragraphDys.isNotEmpty
          ? paragraphDys.first
          : null,
    ),
    firstLineTop: paraOrigin.dy + firstLine.top,
    firstLineHeight: firstLine.height,
    textLeft: paraOrigin.dx,
    itemSize: item.size,
    textDy: isOrdered
        ? (paragraphDys.length > 1 ? paragraphDys[1] : null)
        : (paragraphDys.isNotEmpty ? paragraphDys.first : null),
  );
}

const _scales = <double>[1.0, 2.0, 3.0];

void main() {
  group('list markers follow the text scale', () {
    // REAL BUG: lib/src/rendering/list_item_widget.dart:390
    // `_paintBullet` — `centerY = top + baseline - fontSize * 0.34` uses the
    // unscaled font size while `baseline` comes from the scaled child, so the
    // bullet sinks toward the baseline as the text grows.
    testWidgets(
      'a bullet stays at the same height within its first line at 1x/2x/3x',
      (tester) async {
        final fractions = <double, double>{};
        for (final scale in _scales) {
          await tester.pumpWidget(
            _app(
              scaler: TextScaler.linear(scale),
              child: const MarkdownView(data: '- bullet item\n- second'),
            ),
          );
          final g = _geometry(tester, 'bullet item');
          expect(g.marker.circleCenter, isNotNull);
          fractions[scale] = g.centreFraction;
        }
        expect(
          fractions[2.0],
          closeTo(fractions[1.0]!, 0.04),
          reason: 'centre fractions by scale: $fractions',
        );
        expect(
          fractions[3.0],
          closeTo(fractions[1.0]!, 0.04),
          reason: 'centre fractions by scale: $fractions',
        );
      },
    );

    // REAL BUG: lib/src/rendering/list_item_widget.dart:392
    // `_paintBullet` — the radius is `bulletSize * 0.5` with no text scaler
    // applied, so a 5.5lp dot sits beside 45lp text at 3x.
    testWidgets('a bullet grows with the text scale', (tester) async {
      final radii = <double, double>{};
      for (final scale in _scales) {
        await tester.pumpWidget(
          _app(
            scaler: TextScaler.linear(scale),
            child: const MarkdownView(data: '- bullet item'),
          ),
        );
        radii[scale] = _geometry(tester, 'bullet item').marker.circleRadius!;
      }
      expect(radii[2.0], greaterThan(radii[1.0]! * 1.5), reason: '$radii');
      expect(radii[3.0], greaterThan(radii[2.0]!), reason: '$radii');
    });

    testWidgets('an ordinal shares the baseline of its text at 1x/2x/3x', (
      tester,
    ) async {
      for (final scale in _scales) {
        await tester.pumpWidget(
          _app(
            scaler: TextScaler.linear(scale),
            child: const MarkdownView(data: '1. first item\n2. second item'),
          ),
        );
        final g = _geometry(tester, 'first item');
        expect(g.marker.ordinalDy, isNotNull);
        expect(g.textDy, isNotNull);
        // Same style and scaler on both sides, so equal paint dy means equal
        // baselines.
        expect(
          g.marker.ordinalDy,
          closeTo(g.textDy!, 0.5),
          reason: 'scale $scale',
        );
      }
    });

    testWidgets('an ordinal is drawn at the scaled font size', (tester) async {
      final gutters = <double, double>{};
      for (final scale in _scales) {
        await tester.pumpWidget(
          _app(
            scaler: TextScaler.linear(scale),
            child: const MarkdownView(
              data: '8. eight\n9. nine\n10. ten\n11. eleven',
            ),
          ),
        );
        gutters[scale] = _geometry(tester, 'eleven').textLeft;
        // All items keep one text column at every scale.
        expect(
          _geometry(tester, 'eight').textLeft,
          gutters[scale],
          reason: 'scale $scale',
        );
      }
      // The gutter is sized from the scaled ordinal, so it has to widen.
      expect(
        gutters[2.0],
        greaterThan(gutters[1.0]! * 1.5),
        reason: '$gutters',
      );
      expect(gutters[3.0], greaterThan(gutters[2.0]!), reason: '$gutters');
    });

    // REAL BUG: lib/src/rendering/list_item_widget.dart:447
    // `_paintCheckbox` — same unscaled `fontSize * 0.34` offset as the bullet.
    testWidgets(
      'a task checkbox stays at the same height within its first line',
      (tester) async {
        for (final checked in [false, true]) {
          final fractions = <double, double>{};
          for (final scale in _scales) {
            await tester.pumpWidget(
              _app(
                scaler: TextScaler.linear(scale),
                child: MarkdownView(
                  data: checked ? '- [x] task item' : '- [ ] task item',
                ),
              ),
            );
            final g = _geometry(tester, 'task item');
            expect(g.marker.box, isNotNull);
            fractions[scale] = g.centreFraction;
          }
          expect(
            fractions[2.0],
            closeTo(fractions[1.0]!, 0.04),
            reason: 'checked=$checked fractions: $fractions',
          );
          expect(
            fractions[3.0],
            closeTo(fractions[1.0]!, 0.04),
            reason: 'checked=$checked fractions: $fractions',
          );
        }
      },
    );

    // REAL BUG: lib/src/rendering/list_item_widget.dart:446
    // `_paintCheckbox` — `boxSize = (fontSize * 0.92).clamp(12.0, 18.0)` is
    // computed from the unscaled font size, so the box never grows.
    testWidgets('a task checkbox grows with the text scale', (tester) async {
      final sides = <double, double>{};
      for (final scale in _scales) {
        await tester.pumpWidget(
          _app(
            scaler: TextScaler.linear(scale),
            child: const MarkdownView(data: '- [ ] task item'),
          ),
        );
        sides[scale] = _geometry(tester, 'task item').marker.box!.height;
      }
      expect(sides[2.0], greaterThan(sides[1.0]!), reason: '$sides');
      expect(sides[3.0], greaterThanOrEqualTo(sides[2.0]!), reason: '$sides');
    });

    testWidgets('a marker never overlaps the text column', (tester) async {
      for (final scale in _scales) {
        await tester.pumpWidget(
          _app(
            scaler: TextScaler.linear(scale),
            child: const MarkdownView(
              data: '- bullet item\n- [ ] open task\n- [x] done task',
            ),
          ),
        );
        final bullet = _geometry(tester, 'bullet item');
        expect(
          bullet.marker.circleCenter!.dx + bullet.marker.circleRadius!,
          lessThanOrEqualTo(bullet.textLeft),
          reason: 'scale $scale',
        );
        for (final label in ['open task', 'done task']) {
          final g = _geometry(tester, label);
          expect(
            g.marker.box!.right,
            lessThanOrEqualTo(g.textLeft),
            reason: '$label at scale $scale',
          );
          expect(g.marker.box!.left, greaterThanOrEqualTo(0.0));
        }
      }
    });

    // REAL BUG: consequence of the unscaled checkbox size in
    // list_item_widget.dart:446 `_paintCheckbox` — at 0.5x the 13.8lp box is taller
    // than the text and is painted above the top of its own item.
    testWidgets('a marker is painted inside its own item at every scale', (
      tester,
    ) async {
      for (final scale in [0.5, ..._scales]) {
        await tester.pumpWidget(
          _app(
            scaler: TextScaler.linear(scale),
            child: const MarkdownView(
              data: '- bullet item\n- [ ] open task\n- [x] done task',
            ),
          ),
        );
        for (final label in ['bullet item', 'open task', 'done task']) {
          final g = _geometry(tester, label);
          final top = g.marker.circleCenter != null
              ? g.marker.circleCenter!.dy - g.marker.circleRadius!
              : g.marker.box!.top;
          final bottom = g.marker.circleCenter != null
              ? g.marker.circleCenter!.dy + g.marker.circleRadius!
              : g.marker.box!.bottom;
          expect(top, greaterThanOrEqualTo(0.0), reason: '$label @ $scale');
          expect(
            bottom,
            lessThanOrEqualTo(g.itemSize.height),
            reason: '$label @ $scale',
          );
        }
      }
    });

    // REAL BUG: lib/src/rendering/list_item_widget.dart:305
    // `_fallbackMarkerHeight` — the minimum item height is
    // `fontSize * height` without the text scaler, so below 1x every item is
    // padded to the unscaled line height.
    testWidgets('below 1x an item is no taller than its text', (tester) async {
      await tester.pumpWidget(
        _app(
          scaler: const TextScaler.linear(0.5),
          child: const MarkdownView(data: '- small item\n- another'),
        ),
      );
      final item = _item(tester, 'small item');
      final para = _firstPara(item)!;
      expect(item.size.height, para.size.height);
    });

    testWidgets('markers return to their original place after scaling back', (
      tester,
    ) async {
      const md = '- bullet item\n\n1. first item\n\n- [x] done task';
      Future<List<double>> snapshot(double scale) async {
        await tester.pumpWidget(
          _app(
            scaler: TextScaler.linear(scale),
            child: const MarkdownView(documentId: 'roundtrip', data: md),
          ),
        );
        final bullet = _geometry(tester, 'bullet item');
        final ordinal = _geometry(tester, 'first item');
        final task = _geometry(tester, 'done task');
        return [
          bullet.marker.circleCenter!.dy,
          bullet.itemSize.height,
          ordinal.marker.ordinalDy!,
          ordinal.textLeft,
          task.marker.box!.center.dy,
          task.itemSize.height,
        ];
      }

      final before = await snapshot(1.0);
      final scaled = await snapshot(2.0);
      final after = await snapshot(1.0);
      expect(scaled, isNot(equals(before)));
      expect(after, before);
    });

    testWidgets('nested list markers keep aligning with their own first line', (
      tester,
    ) async {
      for (final scale in _scales) {
        await tester.pumpWidget(
          _app(
            scaler: TextScaler.linear(scale),
            child: const MarkdownView(
              data: '1. outer one\n   1. inner one\n   2. inner two',
            ),
          ),
        );
        for (final label in ['outer one', 'inner one', 'inner two']) {
          final g = _geometry(tester, label);
          expect(
            g.marker.ordinalDy,
            closeTo(g.textDy!, 0.5),
            reason: '$label @ $scale',
          );
        }
      }
    });
  });

  group('blocks scale exactly once', () {
    const blocks = <String, String>{
      'paragraph': 'Plain paragraph text',
      'heading': '## Heading text',
      'code block': '```\ncode line\n```',
      'quote': '> quoted text',
      'alert': '> [!TIP]\n> alert text',
      'bullet list': '- list text',
      'ordered list': '1. list text',
      'task list': '- [ ] list text',
      'table': '| a | b |\n| - | - |\n| c | d |',
      'footnote': 'Text[^1]\n\n[^1]: note text',
      'block latex': r'\[ x + y \]',
      'details':
          '<details open>\n<summary>Summary text</summary>\n\nbody text\n\n'
          '</details>',
    };

    for (final entry in blocks.entries) {
      testWidgets('${entry.key} grows with the ambient text scale', (
        tester,
      ) async {
        final heights = <double, double>{};
        for (final scale in _scales) {
          await tester.pumpWidget(
            _app(
              size: const Size(2000, 4000),
              scaler: TextScaler.linear(scale),
              child: MarkdownView(
                documentId: 'grow-${entry.key}-$scale',
                data: entry.value,
              ),
            ),
          );
          expect(_drain(tester), isEmpty, reason: 'scale $scale');
          heights[scale] = tester.getSize(find.byType(MarkdownView)).height;
        }
        expect(
          heights[2.0],
          greaterThan(heights[1.0]! * 1.3),
          reason: '$heights',
        );
        expect(
          heights[3.0],
          greaterThan(heights[2.0]! * 1.2),
          reason: '$heights',
        );
        // Scaling once: never more than proportional growth.
        expect(
          heights[2.0],
          lessThanOrEqualTo(heights[1.0]! * 2.0 + 0.01),
          reason: '$heights',
        );
        expect(
          heights[3.0],
          lessThanOrEqualTo(heights[1.0]! * 3.0 + 0.01),
          reason: '$heights',
        );
      });

      testWidgets(
        '${entry.key}: the textScaler parameter equals the ambient scaler',
        (tester) async {
          await tester.pumpWidget(
            _app(
              size: const Size(2000, 4000),
              scaler: const TextScaler.linear(2),
              child: MarkdownView(
                documentId: 'once-${entry.key}',
                data: entry.value,
              ),
            ),
          );
          final ambient = tester.getSize(find.byType(MarkdownView));

          await tester.pumpWidget(
            _app(
              size: const Size(2000, 4000),
              child: MarkdownView(
                documentId: 'once-${entry.key}',
                data: entry.value,
                textScaler: const TextScaler.linear(2),
              ),
            ),
          );
          final explicit = tester.getSize(find.byType(MarkdownView));
          expect(explicit, ambient);

          // An explicit scaler replaces the ambient one, it does not multiply.
          await tester.pumpWidget(
            _app(
              size: const Size(2000, 4000),
              scaler: const TextScaler.linear(2),
              child: MarkdownView(
                documentId: 'once-${entry.key}',
                data: entry.value,
                textScaler: const TextScaler.linear(2),
              ),
            ),
          );
          expect(tester.getSize(find.byType(MarkdownView)), ambient);
        },
      );
    }

    testWidgets('a single text line is exactly proportional to the scale', (
      tester,
    ) async {
      final heights = <double, double>{};
      for (final scale in _scales) {
        await tester.pumpWidget(
          _app(
            size: const Size(2000, 2000),
            scaler: TextScaler.linear(scale),
            child: const MarkdownView(data: '# Title\n\nbody'),
          ),
        );
        heights[scale] = _para(tester, 'Title').size.height;
      }
      // Line heights are rounded to whole pixels, hence the 1lp tolerance.
      expect(heights[2.0], closeTo(heights[1.0]! * 2, 1.0));
      expect(heights[3.0], closeTo(heights[1.0]! * 3, 1.0));
    });

    testWidgets(
      'list text is the same size as a plain paragraph at every scale',
      (tester) async {
        for (final scale in _scales) {
          await tester.pumpWidget(
            _app(
              size: const Size(2000, 2000),
              scaler: TextScaler.linear(scale),
              child: const MarkdownView(
                data:
                    'prose line\n\n- list line\n\n1. ordered line\n\n- [ ] task',
              ),
            ),
          );
          final prose = _para(tester, 'prose line').size.height;
          expect(_para(tester, 'list line').size.height, prose);
          expect(_para(tester, 'ordered line').size.height, prose);
          expect(_para(tester, 'task').size.height, prose);
          if (scale >= 1.0) {
            expect(_item(tester, 'list line').size.height, prose);
            expect(_item(tester, 'ordered line').size.height, prose);
            expect(_item(tester, 'task').size.height, prose);
          }
        }
      },
    );

    testWidgets('nested content scales once at every depth', (tester) async {
      const md =
          '> quote line\n>\n> - quoted item\n>\n>   > [!NOTE]\n>   > deep line';
      for (final scale in _scales) {
        await tester.pumpWidget(
          _app(
            size: const Size(2000, 2000),
            scaler: TextScaler.linear(scale),
            child: const MarkdownView(data: 'top line\n\n$md'),
          ),
        );
        final top = _para(tester, 'top line').size.height;
        for (final label in ['quote line', 'quoted item', 'deep line']) {
          expect(
            _para(tester, label).size.height,
            top,
            reason: '$label @ $scale',
          );
        }
      }
    });

    testWidgets('custom builders inherit the scale once', (tester) async {
      final seen = <String, double>{};
      Widget probe(String name) => Builder(
        builder: (context) {
          seen[name] = MediaQuery.textScalerOf(context).scale(10);
          return const SizedBox(width: 10, height: 10);
        },
      );
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            textScaler: const TextScaler.linear(2),
            data:
                '```dart\ncode\n```\n\n| a |\n| - |\n| b |\n\n'
                '> [!NOTE]\n> x\n\n'
                r'\[ x \]',
            builders: MarkdownBuilders(
              codeBlockBuilder: (c, b, content, t) => probe('code'),
              tableBuilder: (c, b, t) => probe('table'),
              alertBuilder: (c, b, body, t) => probe('alert'),
              blockLatexBuilder: (c, b, t) => probe('latex'),
            ),
          ),
        ),
      );
      expect(seen, {'code': 20.0, 'table': 20.0, 'alert': 20.0, 'latex': 20.0});
    });

    testWidgets(
      'a custom code block builder gets content that is scaled once',
      (tester) async {
        Future<double> codeHeight({
          TextScaler? ambient,
          TextScaler? own,
        }) async {
          await tester.pumpWidget(
            _app(
              size: const Size(2000, 2000),
              scaler: ambient ?? TextScaler.noScaling,
              child: MarkdownView(
                data: '```\nsingle\n```',
                textScaler: own,
                builders: MarkdownBuilders(
                  codeBlockBuilder: (c, b, content, t) => content,
                ),
              ),
            ),
          );
          return _para(tester, 'single').size.height;
        }

        final base = await codeHeight();
        expect(
          await codeHeight(ambient: const TextScaler.linear(2)),
          closeTo(base * 2, 0.01),
        );
        expect(
          await codeHeight(own: const TextScaler.linear(2)),
          closeTo(base * 2, 0.01),
        );
      },
    );
  });

  group('large text does not overflow', () {
    const everything = '''
# Heading one with several words

## Heading two with `inline code`

Paragraph with **bold**, *italic*, ~~struck~~, `code`, and a [link](https://x.example).

- bullet item with enough words to wrap around
  - nested bullet
    - deeper bullet
- [ ] open task
- [x] done task

1. first ordered
2. second ordered

> quote line one
>
> > nested quote

> [!NOTE]
> note body

> [!IMPORTANT]
> important body

> [!WARNING]
> warning body

```dart
void main() { print("a long line of code that will need to scroll"); }
```

| Name | Value | Notes |
| :--- | :---: | ----: |
| alpha | 1 | first |
| beta | 2 | second |

---

Footnote ref[^note].

<details open>
<summary>Summary with several words in it</summary>

Details body.

</details>

[^note]: Footnote body with several words.
''';

    for (final width in [320.0, 240.0]) {
      for (final scale in [2.0, 3.0]) {
        testWidgets(
          'every block type lays out at ${width.toInt()}lp and ${scale}x',
          (tester) async {
            await tester.pumpWidget(
              _app(
                size: Size(width, 800),
                scaler: TextScaler.linear(scale),
                child: MarkdownView(
                  documentId: 'overflow-$width-$scale',
                  data: everything,
                ),
              ),
            );
            await tester.pump();
            final errors = _drain(tester);
            expect(errors, isEmpty, reason: errors.join('\n'));
          },
        );
      }
    }

    testWidgets('deeply nested blocks lay out at 240lp and 3x', (tester) async {
      await tester.pumpWidget(
        _app(
          size: const Size(240, 800),
          scaler: const TextScaler.linear(3),
          child: const MarkdownView(
            data:
                '- a\n  - b\n    - c\n      > [!CAUTION]\n      > deep alert\n'
                '      >\n      > | h1 | h2 |\n      > | -- | -- |\n'
                '      > | c1 | c2 |\n\n'
                '      1. numbered\n      2. numbered two',
          ),
        ),
      );
      await tester.pump();
      final errors = _drain(tester);
      expect(errors, isEmpty, reason: errors.join('\n'));
    });

    testWidgets('a wide table scrolls instead of overflowing at 3x', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          size: const Size(320, 800),
          scaler: const TextScaler.linear(3),
          child: const MarkdownView(
            data:
                '| First column | Second column | Third column |\n'
                '| --- | --- | --- |\n| one | two | three |',
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      final scrollables = find.descendant(
        of: find.byType(MarkdownTableWidget),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scrollables, findsOneWidget);
      final table = tester.getSize(find.byType(Table));
      expect(table.width, greaterThan(320));
      expect(tester.getSize(find.byType(MarkdownTableWidget)).width, 320);
    });

    testWidgets('table columns are measured at the scaled font size', (
      tester,
    ) async {
      final widths = <double, double>{};
      for (final scale in _scales) {
        await tester.pumpWidget(
          _app(
            size: const Size(4000, 800),
            scaler: TextScaler.linear(scale),
            child: MarkdownView(
              theme: MarkdownThemeData.fallback().copyWith(
                tableStyle: const MarkdownTableStyle(maxColumnWidth: 5000),
              ),
              data: '| headword |\n| --- |\n| cell |',
            ),
          ),
        );
        widths[scale] = tester.getSize(find.byType(Table)).width;
        // The text fits on one line in its column at every scale.
        final header = _para(tester, 'headword');
        expect(
          header.size.width + 0.01,
          greaterThanOrEqualTo(header.getMaxIntrinsicWidth(double.infinity)),
          reason: 'scale $scale',
        );
      }
      expect(widths[2.0], greaterThan(widths[1.0]! * 1.5), reason: '$widths');
      expect(widths[3.0], greaterThan(widths[2.0]!), reason: '$widths');
    });

    // REAL BUG: lib/src/rendering/block_renderer.dart:1037
    // `_buildImageFallbackChip` — the chip is a `Text` inside a `WidgetSpan`.
    // RenderParagraph already paints WidgetSpan children scaled by the text
    // scale factor, and the inner `Text` applies the ambient scaler again, so
    // the chip is drawn at scale squared (4x at 2x, 9x at 3x).
    testWidgets('the default image chip scales once with the text', (
      tester,
    ) async {
      final heights = <double, double>{};
      for (final scale in _scales) {
        await tester.pumpWidget(
          _app(
            size: const Size(3000, 800),
            scaler: TextScaler.linear(scale),
            child: const MarkdownView(data: 'x ![chip](local.png) y'),
          ),
        );
        expect(_drain(tester), isEmpty);
        final box = tester.renderObject<RenderBox>(find.text('chip'));
        // Measured in global coordinates so paint-time scaling is included.
        heights[scale] =
            box.localToGlobal(Offset(0, box.size.height)).dy -
            box.localToGlobal(Offset.zero).dy;
      }
      expect(heights[2.0], closeTo(heights[1.0]! * 2, 1.5), reason: '$heights');
      expect(heights[3.0], closeTo(heights[1.0]! * 3, 1.5), reason: '$heights');
    });
  });

  group('nonlinear scalers', () {
    testWidgets('a clamped scaler is honoured by text and ordinals alike', (
      tester,
    ) async {
      final clamped = const TextScaler.linear(
        3,
      ).clamp(minScaleFactor: 1, maxScaleFactor: 1.5);
      await tester.pumpWidget(
        _app(
          scaler: clamped,
          child: const MarkdownView(data: 'prose\n\n1. ordered line'),
        ),
      );
      await tester.pumpWidget(
        _app(
          scaler: clamped,
          child: const MarkdownView(data: 'prose\n\n1. ordered line'),
        ),
      );
      final clampedHeight = _para(tester, 'prose').size.height;
      final g = _geometry(tester, 'ordered line');
      expect(g.marker.ordinalDy, closeTo(g.textDy!, 0.5));

      await tester.pumpWidget(
        _app(
          scaler: const TextScaler.linear(1.5),
          child: const MarkdownView(data: 'prose\n\n1. ordered line'),
        ),
      );
      expect(_para(tester, 'prose').size.height, clampedHeight);
    });
  });
}
