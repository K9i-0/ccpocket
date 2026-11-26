// Failing tests from the rendering / widget layer review. Each test asserts
// the correct behaviour and fails against the current implementation.
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
  bool scroll = true,
}) {
  Widget body = ColoredBox(color: const Color(0xFFFFFFFF), child: child);
  if (scroll) {
    body = SingleChildScrollView(child: body);
  }
  return Directionality(
    textDirection: dir,
    child: MediaQuery(
      data: MediaQueryData(size: size, textScaler: scaler),
      child: FocusScope(
        autofocus: true,
        child: _ReactiveOverlayShell(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: size.width, child: body),
          ),
        ),
      ),
    ),
  );
}

class _ReactiveOverlayShell extends StatefulWidget {
  const _ReactiveOverlayShell({required this.child});

  final Widget child;

  @override
  State<_ReactiveOverlayShell> createState() => _ReactiveOverlayShellState();
}

class _ReactiveOverlayShellState extends State<_ReactiveOverlayShell> {
  late final ValueNotifier<Widget> _childNotifier = ValueNotifier<Widget>(
    widget.child,
  );
  late final OverlayEntry _rootEntry = OverlayEntry(
    builder: (_) => ValueListenableBuilder<Widget>(
      valueListenable: _childNotifier,
      builder: (_, child, _) => child,
    ),
  );

  @override
  void didUpdateWidget(covariant _ReactiveOverlayShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _childNotifier.value = widget.child;
  }

  @override
  void dispose() {
    _childNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_rootEntry]);
  }
}

RenderSelectableParagraph _para(WidgetTester tester, String substring) {
  for (final element in find.bySubtype<RichText>().evaluate()) {
    final ro = element.renderObject;
    if (ro is RenderSelectableParagraph &&
        ro.text.toPlainText().contains(substring)) {
      return ro;
    }
  }
  throw StateError('No paragraph containing "$substring"');
}

Offset _globalOfText(WidgetTester tester, String paragraphSub, String needle) {
  final ro = _para(tester, paragraphSub);
  final plain = ro.text.toPlainText();
  final idx = plain.indexOf(needle);
  final boxes = ro.getBoxesForSelection(
    TextSelection(baseOffset: idx, extentOffset: idx + needle.length),
  );
  return ro.localToGlobal(boxes.first.toRect().center);
}

List<Object> _drainExceptions(WidgetTester tester) {
  final out = <Object>[];
  while (true) {
    final Object? e = tester.takeException() as Object?;
    if (e == null) break;
    out.add(e);
  }
  return out;
}

void main() {
  testWidgets('a11y: Markdown links expose a tap action to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final taps = <String>[];
    await tester.pumpWidget(
      _app(
        child: MarkdownView(
          data: 'See [Flutter site](https://flutter.dev) now.',
          builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
        ),
      ),
    );
    await tester.pump();
    // The link is its own semantics node below the paragraph, so it is found
    // in the semantics tree rather than through a widget.
    expect(find.semantics.byLabel('Flutter site'), findsOne);
    final all = <SemanticsNode>[];
    void visit(SemanticsNode n) {
      all.add(n);
      n.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(tester.getSemantics(find.byType(MarkdownView)));
    SemanticsNode top = tester.getSemantics(find.byType(MarkdownView));
    while (top.parent != null) {
      top = top.parent!;
    }
    all.clear();
    visit(top);
    final labels = all.map((n) => n.label).where((l) => l.isNotEmpty).toList();
    final tappable = all.where(
      (n) =>
          n.label.contains('Flutter site') &&
          n.getSemanticsData().hasAction(SemanticsAction.tap),
    );
    expect(tappable, isNotEmpty, reason: 'labels: $labels');
    tester.semantics.tap(find.semantics.byLabel('Flutter site'));
    expect(taps, ['https://flutter.dev']);
    handle.dispose();
  });

  testWidgets('ordered list: item text column stays aligned across 9. -> 10.', (
    tester,
  ) async {
    final md = [for (var i = 1; i <= 12; i++) '$i. item$i'].join('\n');
    await tester.pumpWidget(_app(child: MarkdownView(data: md)));
    await tester.pump();
    final x9 = _para(tester, 'item9').localToGlobal(Offset.zero).dx;
    final x10 = _para(tester, 'item10').localToGlobal(Offset.zero).dx;
    expect(x10, x9);
  });

  testWidgets(
    'SliverMarkdownView: expanded <details> stays expanded after scrolling away and back',
    (tester) async {
      final md =
          '<details>\n<summary>Open me</summary>\n\nHidden body\n\n</details>\n\n${[for (var i = 0; i < 80; i++) 'Paragraph number $i'].join('\n\n')}';
      final sc = ScrollController();
      await tester.pumpWidget(
        _app(
          scroll: false,
          child: MarkdownSelectionScope(
            child: CustomScrollView(
              controller: sc,
              slivers: [SliverMarkdownView(data: md)],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(_globalOfText(tester, 'Open me', 'Open'));
      await tester.pumpAndSettle();
      expect(find.text('Hidden body', findRichText: true), findsOneWidget);
      sc.jumpTo(2500);
      await tester.pumpAndSettle();
      expect(find.text('Hidden body', findRichText: true), findsNothing);
      sc.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Hidden body', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'table: a baseline-aligned inline widget in a cell lays out without asserting',
    (tester) async {
      await tester.pumpWidget(
        _app(
          size: const Size(320, 600),
          child: MarkdownView(
            data: '| Name | Colour |\n|---|---|\n| Primary | `#FF5733` |',
            builders: MarkdownBuilders(
              inlineCodeBuilder: (context, code, style, codeStyle) => TextSpan(
                children: [
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: SizedBox(width: 12, height: 12),
                  ),
                  TextSpan(text: code, style: style),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_drainExceptions(tester), isEmpty);
      expect(find.text('#FF5733', findRichText: true), findsNothing);
      expect(find.textContaining('#FF5733', findRichText: true), findsWidgets);
    },
  );

  testWidgets(
    'table: image chip in a cell is not squeezed to the 48px placeholder width',
    (tester) async {
      await tester.pumpWidget(
        _app(
          size: const Size(800, 600),
          child: const MarkdownView(
            data:
                '| Shot |\n|---|\n| ![screenshot of login](shots/login.png) |\n\n![screenshot of login](shots/login.png)',
          ),
        ),
      );
      await tester.pump();
      expect(_drainExceptions(tester), isEmpty);
      final chips = find.text('screenshot of login');
      expect(chips, findsNWidgets(2));
      final inTable = tester.getSize(chips.at(0));
      final inPara = tester.getSize(chips.at(1));
      expect(inTable.height, inPara.height, reason: '$inTable vs $inPara');
    },
  );

  testWidgets(
    'alert header does not overflow when nested in a list at 320lp / textScaler 3.0',
    (tester) async {
      await tester.pumpWidget(
        _app(
          size: const Size(320, 680),
          scaler: const TextScaler.linear(3),
          child: const MarkdownView(
            data: '- item\n\n  > [!IMPORTANT]\n  > body',
          ),
        ),
      );
      await tester.pump();
      final errors = _drainExceptions(tester);
      expect(errors, isEmpty, reason: errors.join('\n'));
    },
  );

  testWidgets(
    'MarkdownView in ListView.builder: expanded <details> stays expanded after scroll-off',
    (tester) async {
      final sc = ScrollController();
      await tester.pumpWidget(
        _app(
          scroll: false,
          child: MarkdownSelectionScope(
            child: ListView.builder(
              controller: sc,
              itemCount: 60,
              itemBuilder: (_, i) => i == 0
                  ? const MarkdownView(
                      documentId: 'm0',
                      data:
                          '<details>\n<summary>Open me</summary>\n\nHidden body\n\n</details>',
                    )
                  : SizedBox(height: 100, child: Text('row $i')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(_globalOfText(tester, 'Open me', 'Open'));
      await tester.pumpAndSettle();
      expect(find.text('Hidden body', findRichText: true), findsOneWidget);
      sc.jumpTo(3000);
      await tester.pumpAndSettle();
      sc.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Hidden body', findRichText: true), findsOneWidget);
    },
  );
}
