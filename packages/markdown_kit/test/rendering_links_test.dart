// Link tap / semantics behaviour of the rendering layer.
//
// Provenance (behaviours mined by name from the reference suites, rewritten
// against markdown_kit's API):
// - gpt_markdown regression/inline_tap_recognizer_identity_test.dart (high)
// - gpt_markdown regression/inline_tap_recognizer_churn_test.dart (high)
// - gpt_markdown regression/link_with_title_test.dart (medium)
// - gpt_markdown regression/image_link_label_test.dart (medium)
// - gpt_markdown regression/nested_link_label_widget_test.dart (medium)
// - flutter_md widget/render_test.dart "tapping a link invokes onLinkTap",
//   widget/render_coverage_test.dart "isLinkAtGlobal is glyph-tight" (medium)
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
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

/// Glyph boxes (global) of [needle] inside the paragraph containing it.
List<Rect> _boxesOf(WidgetTester tester, String needle, {String? within}) {
  final p = _para(tester, within ?? needle);
  final start = p.text.toPlainText().indexOf(needle);
  expect(start, isNonNegative, reason: '"$needle" not in paragraph');
  final boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + needle.length),
  );
  return [
    for (final b in boxes)
      MatrixUtils.transformRect(p.getTransformTo(null), b.toRect()),
  ];
}

Offset _centerOf(WidgetTester tester, String needle, {String? within}) =>
    _boxesOf(tester, needle, within: within).first.center;

List<String> _drain(WidgetTester tester) {
  final out = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    out.add(e.toString());
  }
  return out;
}

void main() {
  group('pointer taps', () {
    testWidgets('a tap on a link reports its destination exactly once', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: 'Go to [the docs](https://example.com/docs) please.',
            builders: MarkdownBuilders(
              onLinkTap: (url, title) => taps.add('$url|$title'),
            ),
          ),
        ),
      );
      await tester.tapAt(_centerOf(tester, 'the docs'));
      await tester.pump();
      expect(taps, ['https://example.com/docs|']);
    });

    testWidgets(
      'with semantics enabled a pointer tap is still delivered exactly once',
      (tester) async {
        final handle = tester.ensureSemantics();
        final taps = <String>[];
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              data: 'Go to [the docs](https://example.com/docs) please.',
              builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
            ),
          ),
        );
        await tester.pump();
        await tester.tapAt(_centerOf(tester, 'the docs'));
        await tester.pump();
        expect(taps, ['https://example.com/docs']);
        handle.dispose();
      },
    );

    testWidgets('a tap on plain text next to a link reports nothing', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: 'Before [link](https://a.example) after words.',
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      await tester.tapAt(_centerOf(tester, 'Before'));
      await tester.tapAt(_centerOf(tester, 'words'));
      await tester.pump();
      expect(taps, isEmpty);
    });

    testWidgets('the title of a link is passed on and is not rendered', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data:
                'A [first](https://one.example "Title One") and '
                "[second](https://two.example 'Two & <b>') and "
                '[third](https://three.example (Paren title)).',
            builders: MarkdownBuilders(
              onLinkTap: (url, title) => taps.add('$url|$title'),
            ),
          ),
        ),
      );
      final plain = _para(tester, 'first').text.toPlainText();
      expect(plain, 'A first and second and third.');
      await tester.tapAt(_centerOf(tester, 'first'));
      await tester.tapAt(_centerOf(tester, 'second'));
      await tester.tapAt(_centerOf(tester, 'third'));
      await tester.pump();
      expect(taps, [
        'https://one.example|Title One',
        'https://two.example|Two & <b>',
        'https://three.example|Paren title',
      ]);
    });

    testWidgets('emphasis nested in a link label is part of the link', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: 'x [plain **bold** *slanted* `mono`](https://n.example) y',
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      for (final word in ['plain', 'bold', 'slanted', 'mono']) {
        await tester.tapAt(_centerOf(tester, word));
      }
      await tester.pump();
      expect(taps, List.filled(4, 'https://n.example'));
    });

    testWidgets('a link that wraps is tappable on every line fragment', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          size: const Size(220, 600),
          child: MarkdownView(
            data:
                'Lead in [alpha bravo charlie delta echo foxtrot golf]'
                '(https://wrap.example) tail.',
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      final label = 'alpha bravo charlie delta echo foxtrot golf';
      final boxes = _boxesOf(tester, label);
      expect(
        boxes.length,
        greaterThan(1),
        reason: 'the label must wrap for this test to mean anything',
      );
      for (final box in boxes) {
        await tester.tapAt(box.center);
      }
      await tester.pump();
      expect(taps, List.filled(boxes.length, 'https://wrap.example'));

      // The empty area right of a short last line is not part of the link.
      taps.clear();
      final para = _para(tester, label);
      final paraRect = MatrixUtils.transformRect(
        para.getTransformTo(null),
        Offset.zero & para.size,
      );
      final tailBoxes = _boxesOf(tester, 'tail.', within: label);
      final afterTail = Offset(
        (tailBoxes.last.right + paraRect.right) / 2,
        tailBoxes.last.center.dy,
      );
      if (afterTail.dx > tailBoxes.last.right + 2) {
        await tester.tapAt(afterTail);
        await tester.pump();
        expect(taps, isEmpty);
      }
    });

    testWidgets('two adjacent links keep their own destinations', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: '[one](https://1.example)[two](https://2.example)',
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      await tester.tapAt(_centerOf(tester, 'two', within: 'onetwo'));
      await tester.tapAt(_centerOf(tester, 'one', within: 'onetwo'));
      await tester.pump();
      expect(taps, ['https://2.example', 'https://1.example']);
    });

    testWidgets(
      'links inside a heading, list, quote, alert and table cell all fire',
      (tester) async {
        final taps = <String>[];
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              data: [
                '# Head [hlink](https://h.example)',
                '',
                '- item [llink](https://l.example)',
                '',
                '> quoted [qlink](https://q.example)',
                '',
                '> [!NOTE]',
                '> noted [alink](https://a.example)',
                '',
                '| col |',
                '| --- |',
                '| [tlink](https://t.example) |',
              ].join('\n'),
              builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
            ),
          ),
        );
        for (final word in ['hlink', 'llink', 'qlink', 'alink', 'tlink']) {
          await tester.tapAt(_centerOf(tester, word));
        }
        await tester.pump();
        expect(taps, [
          'https://h.example',
          'https://l.example',
          'https://q.example',
          'https://a.example',
          'https://t.example',
        ]);
      },
    );

    testWidgets('an autolink and a bare URL are tappable', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: 'See <https://angle.example/x> or https://bare.example/y ok',
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      await tester.tapAt(_centerOf(tester, 'angle.example'));
      await tester.tapAt(_centerOf(tester, 'bare.example'));
      await tester.pump();
      expect(taps, ['https://angle.example/x', 'https://bare.example/y']);
    });

    testWidgets('a drag that starts on a link is not a tap', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: 'Go to [the docs](https://example.com/docs) please.',
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      final gesture = await tester.startGesture(_centerOf(tester, 'the docs'));
      await gesture.moveBy(const Offset(0, 60));
      await gesture.up();
      await tester.pump();
      expect(taps, isEmpty);
    });

    testWidgets('a secondary-button click on a link does not follow it', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: 'Go to [the docs](https://example.com/docs) please.',
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      await tester.tapAt(
        _centerOf(tester, 'the docs'),
        buttons: kSecondaryButton,
        kind: ui.PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(taps, isEmpty);
    });

    testWidgets('without onLinkTap a link renders and taps are harmless', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            data: 'Go to [the docs](https://example.com/docs) please.',
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(_centerOf(tester, 'the docs'));
      await tester.pump();
      expect(_drain(tester), isEmpty);
      // No callback means nothing to activate for a screen reader either.
      SemanticsNode root = tester.getSemantics(find.byType(MarkdownView));
      while (root.parent != null) {
        root = root.parent!;
      }
      var tappable = 0;
      void visit(SemanticsNode n) {
        if (n.getSemanticsData().hasAction(SemanticsAction.tap)) tappable++;
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(root);
      expect(tappable, 0);
      handle.dispose();
    });
  });

  group('images inside link labels', () {
    testWidgets('a badge link renders the image, not its source text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: '[![build passing](badge.png)](https://ci.example)',
            builders: MarkdownBuilders(
              imageBuilder: (context, image, theme) => SizedBox(
                key: ValueKey<String>('img:${image.source}'),
                width: 40,
                height: 20,
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('img:badge.png')), findsOneWidget);
      expect(
        find.textContaining('badge.png', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('![', findRichText: true), findsNothing);
    });

    testWidgets('tapping the image follows the surrounding link, once', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: 'x [![build passing](badge.png)](https://ci.example) y',
            builders: MarkdownBuilders(
              onLinkTap: (url, _) => taps.add(url),
              imageBuilder: (context, image, theme) => SizedBox(
                key: ValueKey<String>('img:${image.source}'),
                width: 40,
                height: 20,
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('img:badge.png'))),
      );
      await tester.pump();
      expect(taps, ['https://ci.example']);
    });

    testWidgets('an image and text can share one link', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: '[![logo](logo.png) **Project** home](https://p.example)',
            builders: MarkdownBuilders(
              onLinkTap: (url, _) => taps.add(url),
              imageBuilder: (context, image, theme) => SizedBox(
                key: ValueKey<String>('img:${image.source}'),
                width: 24,
                height: 24,
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('img:logo.png'))),
      );
      await tester.tapAt(_centerOf(tester, 'Project'));
      await tester.tapAt(_centerOf(tester, 'home'));
      await tester.pump();
      expect(taps, List.filled(3, 'https://p.example'));
    });

    testWidgets('a reference-style badge link resolves and renders', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data:
                '[![badge][img]][target]\n\n'
                '[img]: badge.svg\n[target]: https://ref.example',
            builders: MarkdownBuilders(
              onLinkTap: (url, _) => taps.add(url),
              imageBuilder: (context, image, theme) => SizedBox(
                key: ValueKey<String>('img:${image.source}'),
                width: 40,
                height: 20,
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('img:badge.svg')), findsOneWidget);
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('img:badge.svg'))),
      );
      await tester.pump();
      expect(taps, ['https://ref.example']);
    });

    testWidgets('a link around an image survives every streamed prefix', (
      tester,
    ) async {
      const full = 'Status: [![ok](ok.png)](https://s.example) done';
      for (var i = 1; i <= full.length; i++) {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'badge-stream',
              data: full.substring(0, i),
              isStreaming: i < full.length,
              builders: MarkdownBuilders(
                imageBuilder: (context, image, theme) =>
                    const SizedBox(width: 20, height: 20),
              ),
            ),
          ),
        );
        final errors = _drain(tester);
        expect(errors, isEmpty, reason: 'prefix length $i: $errors');
      }
    });
  });

  group('callback identity across rebuilds', () {
    testWidgets(
      'after the builders change a pointer tap reaches only the new callback',
      (tester) async {
        final first = <String>[];
        final second = <String>[];
        const data = 'Go to [the docs](https://example.com/docs) please.';
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              data: data,
              builders: MarkdownBuilders(onLinkTap: (url, _) => first.add(url)),
            ),
          ),
        );
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              data: data,
              builders: MarkdownBuilders(
                onLinkTap: (url, _) => second.add(url),
              ),
            ),
          ),
        );
        await tester.tapAt(_centerOf(tester, 'the docs'));
        await tester.pump();
        expect(first, isEmpty);
        expect(second, ['https://example.com/docs']);
      },
    );

    // REAL BUG: lib/src/rendering/selectable_paragraph.dart:147
    // `TappableTextSpan.compareTo` ignores `onTap`, so a span tree that
    // differs only in its tap closures compares `RenderComparison.identical`.
    // `updateTextAndMapping` (:1104) then refreshes `_baseText` (pointer taps
    // use it and are fine) but RenderParagraph's own `text` setter returns
    // early on `identical`, keeping the old span tree and its cached
    // semantics information; the screen-reader tap runs the previous closure.
    testWidgets(
      'after the builders change a semantics tap reaches only the new callback',
      (tester) async {
        final handle = tester.ensureSemantics();
        final first = <String>[];
        final second = <String>[];
        const data = 'Go to [the docs](https://example.com/docs) please.';
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              data: data,
              builders: MarkdownBuilders(onLinkTap: (url, _) => first.add(url)),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              data: data,
              builders: MarkdownBuilders(
                onLinkTap: (url, _) => second.add(url),
              ),
            ),
          ),
        );
        await tester.pump();
        tester.semantics.tap(find.semantics.byLabel('the docs'));
        await tester.pump();
        expect(first, isEmpty, reason: 'stale callback from the first build');
        expect(second, ['https://example.com/docs']);
        handle.dispose();
      },
    );

    // REAL BUG: same root cause as the semantics test above
    // (selectable_paragraph.dart:147 `TappableTextSpan.compareTo`).
    testWidgets(
      'a callback that is removed stops being reachable by a semantics tap',
      (tester) async {
        final handle = tester.ensureSemantics();
        final taps = <String>[];
        const data = 'Go to [the docs](https://example.com/docs) please.';
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              data: data,
              builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(_app(child: const MarkdownView(data: data)));
        await tester.pump();
        SemanticsNode root = tester.getSemantics(find.byType(MarkdownView));
        while (root.parent != null) {
          root = root.parent!;
        }
        final tappable = <String>[];
        void visit(SemanticsNode n) {
          if (n.getSemanticsData().hasAction(SemanticsAction.tap)) {
            tappable.add(n.label);
          }
          n.visitChildren((c) {
            visit(c);
            return true;
          });
        }

        visit(root);
        expect(tappable, isEmpty);
        await tester.tapAt(_centerOf(tester, 'the docs'));
        await tester.pump();
        expect(taps, isEmpty);
        handle.dispose();
      },
    );

    // REAL BUG: same root cause as the semantics test above
    // (selectable_paragraph.dart:147 `TappableTextSpan.compareTo`).
    testWidgets(
      'while text streams in, pointer and semantics taps use the live callback',
      (tester) async {
        final handle = tester.ensureSemantics();
        var generation = 0;
        final taps = <String>[];
        const head = 'Intro with [a link](https://stream.example).\n\n';
        const tail = 'Second paragraph that keeps on growing word by word.';

        Future<void> pumpAt(int length, {required bool streaming}) {
          generation++;
          final seen = generation;
          return tester.pumpWidget(
            _app(
              child: MarkdownView(
                documentId: 'stream-links',
                data: head + tail.substring(0, length),
                isStreaming: streaming,
                builders: MarkdownBuilders(
                  onLinkTap: (url, _) => taps.add('$seen:$url'),
                ),
              ),
            ),
          );
        }

        for (var i = 0; i <= tail.length; i += 7) {
          await pumpAt(i, streaming: true);
        }
        await pumpAt(tail.length, streaming: false);
        await tester.pump();
        final live = generation;

        await tester.tapAt(_centerOf(tester, 'a link'));
        await tester.pump();
        expect(taps, ['$live:https://stream.example']);

        taps.clear();
        tester.semantics.tap(find.semantics.byLabel('a link'));
        await tester.pump();
        expect(taps, ['$live:https://stream.example']);
        handle.dispose();
      },
    );

    testWidgets('a rebuild between pointer down and up does not redirect or '
        'drop the tap', (tester) async {
      final taps = <String>[];
      Widget build(String data) => _app(
        child: MarkdownView(
          documentId: 'mid-gesture',
          data: data,
          builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
        ),
      );
      await tester.pumpWidget(build('[pressed](https://pressed.example)'));
      final gesture = await tester.startGesture(_centerOf(tester, 'pressed'));
      await tester.pump();
      // Same glyph positions, different destination under the finger.
      await tester.pumpWidget(build('[pressed](https://other.example)'));
      await gesture.up();
      await tester.pump();
      expect(taps, ['https://pressed.example']);
    });

    testWidgets(
      'forty rebuilds of a document full of links leave taps working',
      (tester) async {
        final taps = <String>[];
        String doc(int round) => [
          for (var i = 0; i < 30; i++)
            '- row $i [link$i](https://x.example/$i) r$round',
        ].join('\n');
        final handle = tester.ensureSemantics();
        for (var round = 0; round < 40; round++) {
          await tester.pumpWidget(
            _app(
              child: MarkdownView(
                documentId: 'churn',
                data: doc(round),
                builders: MarkdownBuilders(
                  onLinkTap: (url, _) => taps.add('$round:$url'),
                ),
              ),
            ),
          );
          expect(_drain(tester), isEmpty, reason: 'round $round');
        }
        await tester.pump();
        await tester.tapAt(_centerOf(tester, 'link3 ', within: 'row 3 '));
        await tester.pump();
        expect(taps, ['39:https://x.example/3']);
        taps.clear();
        tester.semantics.tap(find.semantics.byLabel('link7'));
        await tester.pump();
        expect(taps, ['39:https://x.example/7']);
        handle.dispose();
      },
    );
  });

  group('custom link builder', () {
    testWidgets('receives the label spans and a working onTap', (tester) async {
      final taps = <String>[];
      VoidCallback? captured;
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: 'see [custom **label**](https://c.example "T") end',
            builders: MarkdownBuilders(
              onLinkTap: (url, title) => taps.add('$url|$title'),
              inlineLinkBuilder: (context, link, labelSpans, style, onTap) {
                captured = onTap;
                return TextSpan(
                  style: style,
                  children: [
                    const TextSpan(text: '<'),
                    ...labelSpans,
                  ],
                );
              },
            ),
          ),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(
        _para(tester, 'custom').text.toPlainText(),
        'see <custom label end',
      );
      expect(captured, isNotNull);
      captured!();
      expect(taps, ['https://c.example|T']);
    });
  });
}
