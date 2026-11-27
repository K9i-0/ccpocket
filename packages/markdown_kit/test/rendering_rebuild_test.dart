// Rebuild correctness of MarkdownView's per-block widget cache: every input
// that changes the output must take effect without a remount and without a
// stale cached block, and inputs that change nothing must rebuild nothing.
//
// Provenance (behaviours mined by name from the reference suites, rewritten
// against markdown_kit's API):
// - gpt_markdown regression/theme_change_rebuild_test.dart (high)
// - gpt_markdown regression/config_change_rebuild_test.dart (high)
// - gpt_markdown regression/render_work_reuse_test.dart (medium)
// - gpt_markdown integration/html_tags_widget_test.dart "changing the map
//   re-renders" (medium; as parserOptions.enableHtml)
// - flutter_md widget/painter_reuse_test.dart "the same text and an equal
//   theme change nothing", "a changed theme value rebuilds the same text",
//   "new text reports a change" (high)
// - flutter_md widget/widget_test.dart, widget/render_test.dart "updating
//   markdown relayouts", "custom link style is applied via theme" (medium)
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:markdown_kit/src/rendering/list_item_widget.dart';
import 'package:markdown_kit/src/rendering/table_widget.dart';

PageStorageBucket _bucket = PageStorageBucket();

Widget _app({
  required Widget child,
  Size size = const Size(420, 680),
  ui.TextDirection dir = ui.TextDirection.ltr,
  TextScaler scaler = TextScaler.noScaling,
}) {
  // Routes provide a PageStorage; <details> keeps its open state there.
  return PageStorage(
    bucket: _bucket,
    child: Directionality(
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

List<String> _allParagraphTexts(WidgetTester tester) => [
  for (final ro in tester.allRenderObjects)
    if (ro is RenderSelectableParagraph) ro.text.toPlainText(),
];

List<String> _drain(WidgetTester tester) {
  final out = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    out.add(e.toString().split('\n').take(3).join(' / '));
  }
  return out;
}

/// The style in effect for the first occurrence of [needle].
TextStyle _styleOf(WidgetTester tester, String needle) {
  final p = _para(tester, needle);
  final index = p.text.toPlainText().indexOf(needle);
  TextStyle? found;
  var cursor = 0;
  void walk(InlineSpan span, TextStyle inherited) {
    if (found != null) return;
    final style = inherited.merge(span.style);
    if (span is TextSpan) {
      final text = span.text;
      if (text != null) {
        if (index >= cursor && index < cursor + text.length) {
          found = style;
          return;
        }
        cursor += text.length;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child, style);
      }
    } else {
      cursor += 1;
    }
  }

  walk(p.text, const TextStyle());
  return found ?? fail('No style for "$needle".');
}

const _doc = '''
# Heading

Body with `inline` and a [link](https://x.example).

- item

```dart
code();
```
''';

/// Pumps a view over [_doc] and records which blocks were built / reused.
class _Probe {
  final built = <int>[];
  final reused = <int>[];

  void reset() {
    built.clear();
    reused.clear();
  }

  Widget view({
    String data = _doc,
    String documentId = 'probe',
    MarkdownThemeData? theme,
    MarkdownBuilders builders = const MarkdownBuilders(),
    MarkdownParserOptions parserOptions = const MarkdownParserOptions(),
    MarkdownParser? parser,
    MarkdownDocument? document,
    bool selectable = true,
    Color? selectionColor,
    TextScaler? textScaler,
    ui.TextDirection? textDirection,
    bool isStreaming = false,
  }) {
    return MarkdownView(
      documentId: documentId,
      data: data,
      document: document,
      theme: theme,
      builders: builders,
      parserOptions: parserOptions,
      parser: parser,
      selectable: selectable,
      selectionColor: selectionColor,
      textScaler: textScaler,
      textDirection: textDirection,
      isStreaming: isStreaming,
      onBlockBuilt: (i, _) => built.add(i),
      onBlockReused: (i, _) => reused.add(i),
    );
  }
}

class _WrapperHost {
  int calls = 0;

  Widget wrap(int index, MarkdownBlock block, Widget child) {
    calls++;
    return child;
  }
}

void main() {
  setUp(() => _bucket = PageStorageBucket());

  group('nothing changed', () {
    testWidgets('rebuilding with identical inputs reuses every block', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view()));
      expect(probe.built, [0, 1, 2, 3]);
      final paragraphs = [
        for (final ro in tester.allRenderObjects)
          if (ro is RenderSelectableParagraph) ro,
      ];
      for (var round = 0; round < 5; round++) {
        probe.reset();
        await tester.pumpWidget(_app(child: probe.view()));
        expect(probe.built, isEmpty, reason: 'round $round');
        expect(probe.reused, [0, 1, 2, 3], reason: 'round $round');
      }
      final after = [
        for (final ro in tester.allRenderObjects)
          if (ro is RenderSelectableParagraph) ro,
      ];
      expect(after.length, paragraphs.length);
      for (var i = 0; i < after.length; i++) {
        expect(identical(after[i], paragraphs[i]), isTrue);
      }
    });

    testWidgets('an equal but distinct theme instance rebuilds nothing', (
      tester,
    ) async {
      final probe = _Probe();
      MarkdownThemeData make() => MarkdownThemeData.fallback().copyWith(
        linkStyle: const TextStyle(color: Color(0xFF123456)),
        blockSpacing: 9,
      );
      await tester.pumpWidget(_app(child: probe.view(theme: make())));
      probe.reset();
      await tester.pumpWidget(_app(child: probe.view(theme: make())));
      expect(probe.built, isEmpty);
      expect(probe.reused, [0, 1, 2, 3]);
    });

    testWidgets('equal builders (same callbacks) rebuild nothing', (
      tester,
    ) async {
      final probe = _Probe();
      void onTap(String url, String title) {}
      InlineSpan code(
        BuildContext context,
        String code,
        TextStyle style,
        MarkdownInlineCodeStyle codeStyle,
      ) => TextSpan(text: code, style: style);
      await tester.pumpWidget(
        _app(
          child: probe.view(
            builders: MarkdownBuilders(
              onLinkTap: onTap,
              inlineCodeBuilder: code,
            ),
          ),
        ),
      );
      probe.reset();
      await tester.pumpWidget(
        _app(
          child: probe.view(
            builders: MarkdownBuilders(
              onLinkTap: onTap,
              inlineCodeBuilder: code,
            ),
          ),
        ),
      );
      expect(probe.built, isEmpty);
    });

    testWidgets('an unrelated ancestor rebuild does not rebuild blocks', (
      tester,
    ) async {
      final probe = _Probe();
      final view = probe.view();
      await tester.pumpWidget(
        _app(
          child: Padding(padding: const EdgeInsets.all(1), child: view),
        ),
      );
      probe.reset();
      await tester.pumpWidget(
        _app(
          child: Padding(padding: const EdgeInsets.all(7), child: view),
        ),
      );
      expect(probe.built, isEmpty);
      expect(probe.reused, isEmpty, reason: 'same widget instance: no build');
    });
  });

  group('data', () {
    testWidgets('editing one block rebuilds that block only', (tester) async {
      final probe = _Probe();
      await tester.pumpWidget(
        _app(child: probe.view(data: 'one\n\ntwo\n\nthree')),
      );
      probe.reset();
      await tester.pumpWidget(
        _app(child: probe.view(data: 'one\n\nTWO\n\nthree')),
      );
      expect(probe.built, [1]);
      expect(probe.reused, [0, 2]);
      expect(_allParagraphTexts(tester), ['one', 'TWO', 'three']);
    });

    testWidgets('inserting a block in front leaves no stale block behind', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view(data: 'one\n\ntwo')));
      final oneRender = _para(tester, 'one');
      await tester.pumpWidget(
        _app(child: probe.view(data: '# zero\n\none\n\ntwo')),
      );
      expect(_allParagraphTexts(tester), ['zero', 'one', 'two']);
      // The paragraph moved down with its render object; the heading in
      // front of it is new.
      expect(identical(_para(tester, 'one'), oneRender), isTrue);
      expect(
        _para(tester, 'zero').text.style!.fontSize,
        MarkdownThemeData.fallback().h1Style.fontSize,
      );
    });

    testWidgets('removing blocks removes their widgets', (tester) async {
      final probe = _Probe();
      await tester.pumpWidget(
        _app(child: probe.view(data: 'one\n\ntwo\n\nthree')),
      );
      final tall = tester.getSize(find.byType(MarkdownView)).height;
      probe.reset();
      await tester.pumpWidget(_app(child: probe.view(data: 'one')));
      expect(probe.built, isEmpty);
      expect(_allParagraphTexts(tester), ['one']);
      expect(tester.getSize(find.byType(MarkdownView)).height, lessThan(tall));
    });

    testWidgets('a block that changes type is rebuilt as the new type', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view(data: 'text\n\ntail')));
      await tester.pumpWidget(_app(child: probe.view(data: '- text\n\ntail')));
      expect(find.byType(MarkdownListItemWidget), findsOneWidget);
      await tester.pumpWidget(
        _app(child: probe.view(data: '| text |\n| - |\n\ntail')),
      );
      expect(find.byType(MarkdownListItemWidget), findsNothing);
      expect(find.byType(Table), findsOneWidget);
      await tester.pumpWidget(_app(child: probe.view(data: '> text\n\ntail')));
      expect(find.byType(Table), findsNothing);
      expect(_drain(tester), isEmpty);
      expect(_allParagraphTexts(tester), ['text', 'tail']);
    });

    testWidgets('a pre-parsed document replaces data, and updates', (
      tester,
    ) async {
      final probe = _Probe();
      final parser = GfmMarkdownParser();
      await tester.pumpWidget(_app(child: probe.view(data: 'from data')));
      await tester.pumpWidget(
        _app(
          child: probe.view(
            data: 'ignored',
            document: parser.parse('from document\n\nsecond'),
          ),
        ),
      );
      expect(_allParagraphTexts(tester), ['from document', 'second']);
      probe.reset();
      await tester.pumpWidget(
        _app(
          child: probe.view(
            data: 'ignored',
            document: parser.parse('from document\n\nchanged'),
          ),
        ),
      );
      expect(probe.built, [1]);
      expect(_allParagraphTexts(tester), ['from document', 'changed']);
      await tester.pumpWidget(_app(child: probe.view(data: 'back to data')));
      expect(_allParagraphTexts(tester), ['back to data']);
    });
  });

  group('theme', () {
    testWidgets('a new theme rebuilds every block and takes effect', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view()));
      final heading = _para(tester, 'Heading');
      expect(_styleOf(tester, 'link').color, const Color(0xFF0969DA));

      probe.reset();
      final custom = MarkdownThemeData.fallback().copyWith(
        linkStyle: const TextStyle(color: Color(0xFFAA0000)),
        h1Style: const TextStyle(fontSize: 40, color: Color(0xFF00AA00)),
        bodyStyle: const TextStyle(fontSize: 18, color: Color(0xFF0000AA)),
      );
      await tester.pumpWidget(_app(child: probe.view(theme: custom)));
      expect(probe.built, [0, 1, 2, 3]);
      expect(_styleOf(tester, 'link').color, const Color(0xFFAA0000));
      expect(_styleOf(tester, 'Heading').fontSize, 40);
      expect(_styleOf(tester, 'Body').fontSize, 18);
      expect(_styleOf(tester, 'item').color, const Color(0xFF0000AA));
      // Updated in place: the render objects survive the theme change.
      expect(identical(_para(tester, 'Heading'), heading), isTrue);
    });

    testWidgets('inline code follows a light/dark switch', (tester) async {
      final probe = _Probe();
      await tester.pumpWidget(
        _app(child: probe.view(theme: MarkdownThemeData.fallback())),
      );
      final light = _para(tester, 'inline').inlineCodeStyle;
      final lightColor = _styleOf(tester, 'Body').color;
      await tester.pumpWidget(
        _app(child: probe.view(theme: MarkdownThemeData.dark())),
      );
      final dark = _para(tester, 'inline').inlineCodeStyle;
      expect(dark, MarkdownThemeData.dark().inlineCodeStyle);
      expect(dark, isNot(light));
      expect(_styleOf(tester, 'Body').color, isNot(lightColor));
      expect(
        _styleOf(tester, 'Body').color,
        MarkdownThemeData.dark().bodyStyle.color,
      );
      await tester.pumpWidget(
        _app(child: probe.view(theme: MarkdownThemeData.fallback())),
      );
      expect(_para(tester, 'inline').inlineCodeStyle, light);
      expect(_styleOf(tester, 'Body').color, lightColor);
    });

    testWidgets('an inherited MarkdownTheme change takes effect', (
      tester,
    ) async {
      final probe = _Probe();
      Widget themed(Color link) => _app(
        child: MarkdownTheme(
          data: MarkdownThemeData.fallback().copyWith(
            linkStyle: TextStyle(color: link),
          ),
          child: probe.view(),
        ),
      );
      await tester.pumpWidget(themed(const Color(0xFF111111)));
      expect(_styleOf(tester, 'link').color, const Color(0xFF111111));
      probe.reset();
      await tester.pumpWidget(themed(const Color(0xFF222222)));
      expect(_styleOf(tester, 'link').color, const Color(0xFF222222));
      expect(probe.built, [0, 1, 2, 3]);
    });

    testWidgets('an explicit theme wins over the inherited one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownTheme(
            data: MarkdownThemeData.fallback().copyWith(
              linkStyle: const TextStyle(color: Color(0xFF111111)),
            ),
            child: MarkdownView(
              data: _doc,
              theme: MarkdownThemeData.fallback().copyWith(
                linkStyle: const TextStyle(color: Color(0xFF333333)),
              ),
            ),
          ),
        ),
      );
      expect(_styleOf(tester, 'link').color, const Color(0xFF333333));
    });

    testWidgets('list, table and code block colours follow the theme', (
      tester,
    ) async {
      const bullet = Color(0xFFAB0000);
      const headerBg = Color(0xFF00AB00);
      const codeBg = Color(0xFF0000AB);
      const data = '- item\n\n| a |\n| - |\n| b |\n\n```\ncode\n```';
      await tester.pumpWidget(_app(child: const MarkdownView(data: data)));
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: data,
            theme: MarkdownThemeData.fallback().copyWith(
              listBulletColor: bullet,
              tableStyle: const MarkdownTableStyle(headerBackground: headerBg),
              codeBlockStyle: const MarkdownCodeBlockStyle(
                backgroundColor: codeBg,
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .renderObject<RenderMarkdownListItem>(
              find.byType(MarkdownListItemWidget),
            )
            .markerColor,
        bullet,
      );
      final table = tester.widget<Table>(find.byType(Table));
      expect(
        (table.children.first.decoration! as BoxDecoration).color,
        headerBg,
      );
      final codeDecoration = tester
          .widgetList<DecoratedBox>(
            find.ancestor(
              of: find.byWidgetPredicate(
                (w) =>
                    w is SelectableParagraph &&
                    w.text.toPlainText().contains('code'),
              ),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => (d.decoration as BoxDecoration).color);
      expect(codeDecoration, contains(codeBg));
    });

    testWidgets('changing blockSpacing moves the blocks', (tester) async {
      final probe = _Probe();
      Future<double> gap(double spacing) async {
        await tester.pumpWidget(
          _app(
            child: probe.view(
              data: 'one\n\ntwo',
              theme: MarkdownThemeData.fallback().copyWith(
                blockSpacing: spacing,
              ),
            ),
          ),
        );
        return tester.getRect(find.byKey(const ValueKey('probe:1'))).top -
            tester.getRect(find.byKey(const ValueKey('probe:0'))).bottom;
      }

      expect(await gap(12), closeTo(12, 0.01));
      expect(await gap(30), closeTo(30, 0.01));
      expect(await gap(0), closeTo(0, 0.01));
    });
  });

  group('builders', () {
    testWidgets('a new inlineCodeBuilder takes effect without a remount', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view()));
      final body = _para(tester, 'Body');
      expect(body.codeRangeCount, 1);
      probe.reset();
      await tester.pumpWidget(
        _app(
          child: probe.view(
            builders: MarkdownBuilders(
              inlineCodeBuilder: (context, code, style, codeStyle) =>
                  TextSpan(text: '<$code>', style: style),
            ),
          ),
        ),
      );
      expect(probe.built, [0, 1, 2, 3]);
      expect(identical(_para(tester, 'Body'), body), isTrue);
      expect(body.text.toPlainText(), contains('<inline>'));
      expect(body.codeRangeCount, 0);

      await tester.pumpWidget(_app(child: probe.view()));
      expect(body.text.toPlainText(), isNot(contains('<inline>')));
      expect(body.codeRangeCount, 1);
    });

    testWidgets('a new codeBlockBuilder and codeHighlighter take effect', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view()));
      expect(find.byKey(const ValueKey('frame')), findsNothing);
      await tester.pumpWidget(
        _app(
          child: probe.view(
            builders: MarkdownBuilders(
              codeBlockBuilder: (context, block, content, theme) =>
                  Container(key: const ValueKey('frame'), child: content),
              codeHighlighter: (context, block, style) => [
                TextSpan(
                  text: block.code,
                  style: style.copyWith(color: const Color(0xFFFF00FF)),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('frame')), findsOneWidget);
      expect(_styleOf(tester, 'code();').color, const Color(0xFFFF00FF));
      await tester.pumpWidget(_app(child: probe.view()));
      expect(find.byKey(const ValueKey('frame')), findsNothing);
      expect(_styleOf(tester, 'code();').color, isNot(const Color(0xFFFF00FF)));
    });

    testWidgets('table, alert, image and link builders can be swapped', (
      tester,
    ) async {
      const data =
          '| a |\n| - |\n| b |\n\n> [!NOTE]\n> body\n\n'
          'x ![alt](pic.png) [go](https://g.example)';
      Widget view(String tag) => _app(
        child: MarkdownView(
          documentId: 'swap',
          data: data,
          builders: MarkdownBuilders(
            tableBuilder: (c, t, th) =>
                SizedBox(key: ValueKey('table-$tag'), height: 5),
            alertBuilder: (c, a, body, th) =>
                KeyedSubtree(key: ValueKey('alert-$tag'), child: body),
            imageBuilder: (c, i, th) =>
                SizedBox(key: ValueKey('image-$tag'), width: 5, height: 5),
            inlineLinkBuilder: (c, link, spans, style, onTap) =>
                TextSpan(text: 'link-$tag', style: style),
          ),
        ),
      );
      await tester.pumpWidget(view('one'));
      for (final kind in ['table', 'alert', 'image']) {
        expect(find.byKey(ValueKey('$kind-one')), findsOneWidget);
      }
      expect(_para(tester, 'link-one'), isNotNull);

      await tester.pumpWidget(view('two'));
      for (final kind in ['table', 'alert', 'image']) {
        expect(find.byKey(ValueKey('$kind-one')), findsNothing);
        expect(find.byKey(ValueKey('$kind-two')), findsOneWidget);
      }
      expect(_para(tester, 'link-two'), isNotNull);
      expect(_drain(tester), isEmpty);

      await tester.pumpWidget(
        _app(
          child: const MarkdownView(documentId: 'swap', data: data),
        ),
      );
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('NOTE'), findsOneWidget);
      expect(_para(tester, 'go'), isNotNull);
    });

    testWidgets('builders created inline on every build still render right', (
      tester,
    ) async {
      var generation = 0;
      Widget view() {
        generation++;
        final tag = 'g$generation';
        return _app(
          child: MarkdownView(
            documentId: 'inline-builders',
            data: 'has `code` here',
            builders: MarkdownBuilders(
              inlineCodeBuilder: (context, code, style, codeStyle) =>
                  TextSpan(text: '$code-$tag', style: style),
            ),
          ),
        );
      }

      for (var i = 0; i < 4; i++) {
        await tester.pumpWidget(view());
        expect(
          _para(tester, 'has').text.toPlainText(),
          'has code-g$generation here',
        );
      }
    });
  });

  group('parser', () {
    testWidgets('parserOptions take effect without a remount', (tester) async {
      final probe = _Probe();
      const data =
          r'Price $x$ and <kbd>K</kbd>.'
          '\n\n> [!NOTE]\n> body';
      await tester.pumpWidget(_app(child: probe.view(data: data)));
      final para = _para(tester, 'Price');
      expect(para.text.toPlainText(), r'Price $x$ and K.');
      expect(find.text('NOTE'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          child: probe.view(
            data: data,
            parserOptions: const MarkdownParserOptions(enableDollarLatex: true),
          ),
        ),
      );
      expect(identical(_para(tester, 'Price'), para), isTrue);
      expect(para.text.toPlainText(), 'Price x and K.');

      await tester.pumpWidget(
        _app(
          child: probe.view(
            data: data,
            parserOptions: const MarkdownParserOptions(enableAlerts: false),
          ),
        ),
      );
      expect(find.text('NOTE'), findsNothing);
      expect(_para(tester, 'body').text.toPlainText(), contains('[!NOTE]'));

      await tester.pumpWidget(
        _app(
          child: probe.view(
            data: data,
            parserOptions: const MarkdownParserOptions(enableHtml: false),
          ),
        ),
      );
      expect(_para(tester, 'Price').text.toPlainText(), contains('<kbd>'));

      await tester.pumpWidget(_app(child: probe.view(data: data)));
      expect(_para(tester, 'Price').text.toPlainText(), r'Price $x$ and K.');
      expect(find.text('NOTE'), findsOneWidget);
      expect(_drain(tester), isEmpty);
    });

    testWidgets('softBreakAsHardBreak toggles line breaks in place', (
      tester,
    ) async {
      final probe = _Probe();
      const data = 'line one\nline two';
      await tester.pumpWidget(_app(child: probe.view(data: data)));
      final soft = _para(tester, 'line one').size.height;
      await tester.pumpWidget(
        _app(
          child: probe.view(
            data: data,
            parserOptions: const MarkdownParserOptions(
              softBreakAsHardBreak: true,
            ),
          ),
        ),
      );
      expect(
        _para(tester, 'line one').text.toPlainText(),
        'line one\nline two',
      );
      expect(_para(tester, 'line one').size.height, closeTo(soft * 2, 1.0));
      await tester.pumpWidget(_app(child: probe.view(data: data)));
      expect(_para(tester, 'line one').size.height, soft);
    });

    testWidgets('equal parserOptions do not re-parse into new blocks', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(
        _app(
          child: probe.view(
            parserOptions: const MarkdownParserOptions(enableDollarLatex: true),
          ),
        ),
      );
      probe.reset();
      await tester.pumpWidget(
        _app(
          child: probe.view(
            // ignore: prefer_const_constructors
            parserOptions: MarkdownParserOptions(enableDollarLatex: true),
          ),
        ),
      );
      expect(probe.built, isEmpty);
    });

    testWidgets('a custom parser is used and can be swapped', (tester) async {
      final probe = _Probe();
      await tester.pumpWidget(
        _app(
          child: probe.view(data: 'ignored', parser: _FixedParser('alpha')),
        ),
      );
      expect(_allParagraphTexts(tester), ['alpha']);
      await tester.pumpWidget(
        _app(
          child: probe.view(data: 'ignored', parser: _FixedParser('beta')),
        ),
      );
      expect(_allParagraphTexts(tester), ['beta']);
      await tester.pumpWidget(_app(child: probe.view(data: 'plain')));
      expect(_allParagraphTexts(tester), ['plain']);
    });
  });

  group('text scale and direction', () {
    testWidgets('a textScaler change relayouts cached blocks', (tester) async {
      final probe = _Probe();
      const data = 'para\n\n- item\n\n| cell |\n| - |\n| body |';
      await tester.pumpWidget(_app(child: probe.view(data: data)));
      final paraHeight = _para(tester, 'para').size.height;
      final itemHeight = _para(tester, 'item').size.height;
      final tableWidth = tester.getSize(find.byType(Table)).width;

      probe.reset();
      await tester.pumpWidget(
        _app(
          child: probe.view(data: data, textScaler: const TextScaler.linear(2)),
        ),
      );
      expect(_para(tester, 'para').size.height, closeTo(paraHeight * 2, 1.0));
      expect(_para(tester, 'item').size.height, closeTo(itemHeight * 2, 1.0));
      expect(tester.getSize(find.byType(Table)).width, greaterThan(tableWidth));

      // Between two explicit scalers the cached block widgets are reused.
      probe.reset();
      final para = _para(tester, 'para');
      await tester.pumpWidget(
        _app(
          child: probe.view(data: data, textScaler: const TextScaler.linear(3)),
        ),
      );
      expect(probe.built, isEmpty, reason: 'the cache key is unchanged');
      expect(identical(_para(tester, 'para'), para), isTrue);
      expect(para.size.height, closeTo(paraHeight * 3, 1.0));

      await tester.pumpWidget(_app(child: probe.view(data: data)));
      expect(_para(tester, 'para').size.height, paraHeight);
      expect(tester.getSize(find.byType(Table)).width, tableWidth);
    });

    // `wrapWithTextOverrides` — the MediaQuery / Directionality wrapper is
    // only inserted when the override is non-null, so going from null to a
    // value (or back) changes the widget type at the root of MarkdownView and
    // remounts the whole subtree: the standalone selection scope, every
    // block, scroll offsets and any active selection are thrown away.
    for (final kind in ['textScaler', 'textDirection']) {
      testWidgets('introducing a $kind override does not remount the blocks', (
        tester,
      ) async {
        final probe = _Probe();
        const data = 'para\n\n- item';
        await tester.pumpWidget(_app(child: probe.view(data: data)));
        final para = _para(tester, 'para');
        probe.reset();
        await tester.pumpWidget(
          _app(
            child: kind == 'textScaler'
                ? probe.view(data: data, textScaler: const TextScaler.linear(2))
                : probe.view(data: data, textDirection: ui.TextDirection.rtl),
          ),
        );
        expect(
          identical(_para(tester, 'para'), para),
          isTrue,
          reason: 'the paragraph render object was recreated',
        );
        expect(probe.built, isEmpty);
      });
    }

    testWidgets('an ambient text scale change relayouts cached blocks', (
      tester,
    ) async {
      final probe = _Probe();
      final view = probe.view(data: 'para\n\n1. item');
      await tester.pumpWidget(_app(child: view));
      final height = tester.getSize(find.byType(MarkdownView)).height;
      await tester.pumpWidget(
        _app(scaler: const TextScaler.linear(2), child: view),
      );
      expect(
        tester.getSize(find.byType(MarkdownView)).height,
        greaterThan(height * 1.5),
      );
      await tester.pumpWidget(_app(child: view));
      expect(tester.getSize(find.byType(MarkdownView)).height, height);
    });

    testWidgets('a textDirection change re-aligns cached blocks', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view(data: 'para\n\n- item')));
      expect(_para(tester, 'para').localToGlobal(Offset.zero).dx, 0.0);
      probe.reset();
      await tester.pumpWidget(
        _app(
          child: probe.view(
            data: 'para\n\n- item',
            textDirection: ui.TextDirection.rtl,
          ),
        ),
      );
      final para = _para(tester, 'para');
      expect(para.textDirection, ui.TextDirection.rtl);
      expect(para.localToGlobal(Offset(para.size.width, 0)).dx, 420.0);
      expect(
        tester
            .renderObject<RenderMarkdownListItem>(
              find.byType(MarkdownListItemWidget),
            )
            .textDirection,
        ui.TextDirection.rtl,
      );
    });
  });

  group('selection inputs', () {
    testWidgets('toggling selectable registers and unregisters surfaces', (
      tester,
    ) async {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      Widget scoped({required bool selectable}) => _app(
        child: MarkdownSelectionScope(
          controller: controller,
          // The default keepDocumentOnDispose: true must not keep a view that
          // was switched to not selectable within reach of Select all.
          child: MarkdownView(
            documentId: 'probe',
            data: _doc,
            selectable: selectable,
          ),
        ),
      );
      await tester.pumpWidget(scoped(selectable: true));
      final mounted = controller.mountedSurfaces.length;
      expect(mounted, greaterThanOrEqualTo(4));
      expect(controller.documentForId('probe'), isNotNull);

      await tester.pumpWidget(scoped(selectable: false));
      expect(controller.mountedSurfaces, isEmpty);
      expect(controller.selectAll(documentId: 'probe'), isFalse);
      expect(_allParagraphTexts(tester).length, mounted);

      await tester.pumpWidget(scoped(selectable: true));
      expect(controller.mountedSurfaces.length, mounted);
      expect(controller.selectAll(documentId: 'probe'), isTrue);
      expect(controller.getText(), contains('Heading'));
      expect(_drain(tester), isEmpty);
    });

    testWidgets('selectable: false works without any scope and back', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view(selectable: false)));
      expect(find.byType(MarkdownSelectionScope), findsNothing);
      final texts = _allParagraphTexts(tester);
      await tester.pumpWidget(_app(child: probe.view()));
      expect(find.byType(MarkdownSelectionScope), findsOneWidget);
      expect(_allParagraphTexts(tester), texts);
      await tester.pumpWidget(_app(child: probe.view(selectable: false)));
      expect(find.byType(MarkdownSelectionScope), findsNothing);
      expect(_drain(tester), isEmpty);
    });

    testWidgets('a selectionColor change reaches every cached paragraph', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(
        _app(child: probe.view(selectionColor: const Color(0x33FF0000))),
      );
      await tester.pumpWidget(
        _app(child: probe.view(selectionColor: const Color(0x3300FF00))),
      );
      for (final ro in tester.allRenderObjects) {
        if (ro is RenderSelectableParagraph) {
          expect(ro.highlightColor, const Color(0x3300FF00));
        }
      }
    });
  });

  group('documentId', () {
    testWidgets('a documentId change re-keys every block', (tester) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view(documentId: 'first')));
      expect(find.byKey(const ValueKey('first:0')), findsOneWidget);
      probe.reset();
      await tester.pumpWidget(_app(child: probe.view(documentId: 'second')));
      expect(probe.built, [0, 1, 2, 3]);
      expect(find.byKey(const ValueKey('first:0')), findsNothing);
      expect(find.byKey(const ValueKey('second:3')), findsOneWidget);
      final ids = tester
          .widgetList<SelectableParagraph>(find.byType(SelectableParagraph))
          .map((p) => p.documentId)
          .toSet();
      expect(ids, {'second'});
    });

    testWidgets(
      'a documentId change moves the registration in a shared scope',
      (tester) async {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);
        Widget scoped(String id) => _app(
          child: MarkdownSelectionScope(
            controller: controller,
            child: MarkdownView(
              documentId: id,
              data: 'content of $id',
              keepDocumentOnDispose: false,
            ),
          ),
        );
        await tester.pumpWidget(scoped('doc-a'));
        expect(controller.documentForId('doc-a'), isNotNull);
        await tester.pumpWidget(scoped('doc-b'));
        expect(controller.documentForId('doc-b'), isNotNull);
        expect(controller.documentForId('doc-a'), isNull);
        expect(controller.selectAll(), isTrue);
        expect(controller.getText(), 'content of doc-b');
      },
    );

    testWidgets('details open state does not leak across documentIds', (
      tester,
    ) async {
      const data =
          '<details>\n<summary>Toggle me</summary>\n\nSecret body\n\n</details>';
      Widget view(String id) => _app(
        child: MarkdownView(documentId: id, data: data),
      );
      await tester.pumpWidget(view('rebuild-details-a'));
      expect(find.textContaining('Secret', findRichText: true), findsNothing);
      final summary = _para(tester, 'Toggle me');
      await tester.tapAt(summary.localToGlobal(const Offset(4, 4)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Secret', findRichText: true), findsOneWidget);

      await tester.pumpWidget(view('rebuild-details-b'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Secret', findRichText: true), findsNothing);

      await tester.pumpWidget(view('rebuild-details-a'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Secret', findRichText: true), findsOneWidget);
    });
  });

  group('blocks added or removed in the middle', () {
    const before = 'alpha\n\nbravo\n\ncharlie\n\ndelta';
    const inserted = 'alpha\n\nbravo\n\nnew one\n\ncharlie\n\ndelta';

    testWidgets('a block typed into the middle keeps the ones after it', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view(data: before)));
      final charlie = _para(tester, 'charlie');
      final delta = _para(tester, 'delta');
      probe.reset();

      await tester.pumpWidget(_app(child: probe.view(data: inserted)));

      expect(_allParagraphTexts(tester), [
        'alpha',
        'bravo',
        'new one',
        'charlie',
        'delta',
      ]);
      expect(probe.reused, [0, 1]);
      expect(identical(_para(tester, 'charlie'), charlie), isTrue);
      expect(identical(_para(tester, 'delta'), delta), isTrue);
      // They answer to their new index, which is what a selection addresses.
      expect(_para(tester, 'new one').blockIndex, 2);
      expect(charlie.blockIndex, 3);
      expect(delta.blockIndex, 4);
      expect(_drain(tester), isEmpty);
    });

    testWidgets('a block removed from the middle keeps the ones after it', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view(data: inserted)));
      final charlie = _para(tester, 'charlie');
      final delta = _para(tester, 'delta');
      probe.reset();

      await tester.pumpWidget(_app(child: probe.view(data: before)));

      expect(_allParagraphTexts(tester), [
        'alpha',
        'bravo',
        'charlie',
        'delta',
      ]);
      expect(probe.reused, [0, 1]);
      expect(identical(_para(tester, 'charlie'), charlie), isTrue);
      expect(identical(_para(tester, 'delta'), delta), isTrue);
      expect(charlie.blockIndex, 2);
      expect(delta.blockIndex, 3);
      expect(_drain(tester), isEmpty);
    });

    testWidgets('a moved block is not laid out again', (tester) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view(data: before)));
      final delta = _para(tester, 'delta');
      await tester.pumpWidget(_app(child: probe.view(data: inserted)));
      // Still clean: the insertion moved it without marking it for layout.
      expect(delta.debugNeedsLayout, isFalse);
      final top = delta.localToGlobal(Offset.zero).dy;
      await tester.pumpWidget(_app(child: probe.view(data: before)));
      expect(delta.localToGlobal(Offset.zero).dy, lessThan(top));
    });

    testWidgets(
      'a selection made after an insertion lands on the moved block',
      (tester) async {
        final controller = MarkdownSelectionController();
        addTearDown(controller.dispose);
        Widget view(String data) => _app(
          child: MarkdownSelectionScope(
            controller: controller,
            child: MarkdownView(documentId: 'moved', data: data),
          ),
        );
        await tester.pumpWidget(view(before));
        await tester.pumpWidget(view(inserted));
        await tester.pump();

        final charlie = _para(tester, 'charlie');
        await tester.longPressAt(charlie.localToGlobal(const Offset(8, 8)));
        await tester.pump();

        final selection = controller.selection!;
        expect(selection.base.blockIndex, 3);
        expect(controller.getText(), 'charlie');
        await tester.tapAt(const Offset(400, 600));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a selection held while a block is put before it stays on its '
        'text', (tester) async {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      Widget view(String data) => _app(
        child: MarkdownSelectionScope(
          controller: controller,
          child: MarkdownView(documentId: 'held', data: data),
        ),
      );
      await tester.pumpWidget(view(before));
      final charlie = _para(tester, 'charlie');
      await tester.longPressAt(charlie.localToGlobal(const Offset(8, 8)));
      await tester.pump();
      expect(controller.getText(), 'charlie');
      expect(controller.selection!.base.blockIndex, 2);

      // The block moves from index 2 to 3 while it is selected.
      await tester.pumpWidget(view(inserted));
      await tester.pump();
      await tester.pump();
      expect(_drain(tester), isEmpty);
      expect(identical(_para(tester, 'charlie'), charlie), isTrue);
      expect(controller.getText(), 'charlie');
      expect(controller.selection!.base.blockIndex, 3);
      // The highlight is on the moved paragraph and nowhere else.
      expect(
        charlie.selectionHighlightRange,
        const TextRange(start: 0, end: 7),
      );
      expect(_para(tester, 'new one').selectionHighlightRange, isNull);

      // And back, with the block removed again.
      await tester.pumpWidget(view(before));
      await tester.pump();
      await tester.pump();
      expect(_drain(tester), isEmpty);
      expect(controller.getText(), 'charlie');
      expect(controller.selection!.base.blockIndex, 2);
      expect(
        charlie.selectionHighlightRange,
        const TextRange(start: 0, end: 7),
      );

      await tester.tapAt(const Offset(400, 600));
      await tester.pumpAndSettle();
    });

    testWidgets('a scrolled table keeps its offset when a block is put before '
        'it', (tester) async {
      final table =
          '| ${List.filled(8, 'wide column').join(' | ')} |\n'
          '| ${List.filled(8, '---').join(' | ')} |\n'
          '| ${List.filled(8, 'v').join(' | ')} |';
      Widget view(String data) => _app(
        child: MarkdownView(documentId: 'table-moved', data: data),
      );
      await tester.pumpWidget(view('lead\n\n$table'));
      final scroller = find.descendant(
        of: find.byType(MarkdownTableWidget),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroller, const Offset(-200, 0));
      await tester.pumpAndSettle();
      final left = tester.getTopLeft(find.byType(Table)).dx;
      expect(left, lessThan(-100.0));

      await tester.pumpWidget(view('lead\n\nadded\n\n$table'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(Table)).dx, left);
    });

    testWidgets('equal blocks side by side do not collide', (tester) async {
      final probe = _Probe();
      await tester.pumpWidget(
        _app(child: probe.view(data: 'same\n\nsame\n\nsame')),
      );
      await tester.pumpWidget(
        _app(child: probe.view(data: 'same\n\nsame\n\nsame\n\nsame')),
      );
      await tester.pumpWidget(_app(child: probe.view(data: 'same\n\nsame')));
      expect(_allParagraphTexts(tester), ['same', 'same']);
      expect(_drain(tester), isEmpty);
    });

    testWidgets('a reply that grows at the end is matched as before', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(
        _app(child: probe.view(data: 'one\n\ntw', isStreaming: true)),
      );
      final one = _para(tester, 'one');
      final tail = _para(tester, 'tw');
      probe.reset();
      await tester.pumpWidget(
        _app(child: probe.view(data: 'one\n\ntwo\n\nthr', isStreaming: true)),
      );
      expect(probe.reused, [0]);
      expect(probe.built, [1, 2]);
      expect(identical(_para(tester, 'one'), one), isTrue);
      // The block still being written keeps its place and render object.
      expect(identical(_para(tester, 'two'), tail), isTrue);
    });

    testWidgets('a moved block keeps its element through a theme change', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_app(child: probe.view(data: before)));
      final delta = _para(tester, 'delta');
      await tester.pumpWidget(_app(child: probe.view(data: inserted)));
      await tester.pumpWidget(
        _app(
          child: probe.view(data: inserted, theme: MarkdownThemeData.dark()),
        ),
      );
      expect(identical(_para(tester, 'delta'), delta), isTrue);
      expect(
        _styleOf(tester, 'delta').color,
        MarkdownThemeData.dark().bodyStyle.color,
      );
    });

    testWidgets('an open details block stays open when a block is put before '
        'it', (tester) async {
      const details =
          '<details>\n<summary>Open me</summary>\n\nInner body\n\n</details>';
      Widget view(String data) => _app(
        child: MarkdownView(documentId: 'details-moved', data: data),
      );
      await tester.pumpWidget(view('lead\n\n$details'));
      await tester.tapAt(
        _para(tester, 'Open me').localToGlobal(const Offset(4, 4)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Inner', findRichText: true), findsOneWidget);

      await tester.pumpWidget(view('lead\n\nadded\n\n$details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Inner', findRichText: true), findsOneWidget);

      // And it is found open again after being taken out of the tree.
      await tester.pumpWidget(_app(child: const SizedBox()));
      await tester.pumpWidget(view('lead\n\nadded\n\n$details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Inner', findRichText: true), findsOneWidget);
    });
  });

  group('blockWrapper', () {
    Widget wrap(int index, MarkdownBlock block, Widget child) => KeyedSubtree(
      key: ValueKey<String>('wrapped-$index-${block.runtimeType}'),
      child: child,
    );

    testWidgets('wraps every top-level block with its index and block', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data: '# Title\n\nBody\n\n- a',
            blockWrapper: wrap,
          ),
        ),
      );
      for (final key in [
        'wrapped-0-HeadingBlock',
        'wrapped-1-ParagraphBlock',
        'wrapped-2-ListBlock',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      }
      // The wrapper holds the block it was given.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('wrapped-1-ParagraphBlock')),
          matching: find.text('Body', findRichText: true),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is not called again for blocks that did not change', (
      tester,
    ) async {
      final calls = <int>[];
      Widget counting(int index, MarkdownBlock block, Widget child) {
        calls.add(index);
        return child;
      }

      Widget view(String data) => _app(
        child: MarkdownView(data: data, blockWrapper: counting),
      );
      await tester.pumpWidget(view('one\n\ntwo'));
      expect(calls, [0, 1]);
      calls.clear();
      await tester.pumpWidget(view('one\n\ntwo!'));
      expect(calls, [1]);
    });

    testWidgets('a method passed as the wrapper does not rebuild the blocks', (
      tester,
    ) async {
      // Each `host.wrap` is a new object that is equal to the last one.
      final host = _WrapperHost();
      final probe = <int>[];
      Widget view() => _app(
        child: MarkdownView(
          data: 'one\n\ntwo',
          blockWrapper: host.wrap,
          onBlockBuilt: (i, _) => probe.add(i),
        ),
      );
      await tester.pumpWidget(view());
      expect(host.calls, 2);
      probe.clear();
      await tester.pumpWidget(view());
      expect(host.calls, 2);
      expect(probe, isEmpty);
    });

    testWidgets('a moved block is wrapped again with its new index', (
      tester,
    ) async {
      Widget view(String data) => _app(
        child: MarkdownView(data: data, blockWrapper: wrap),
      );
      await tester.pumpWidget(view('one\n\ntwo'));
      await tester.pumpWidget(view('one\n\n# new\n\ntwo'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('wrapped-2-ParagraphBlock')),
          matching: find.text('two', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('wrapped-1-HeadingBlock')),
        findsOneWidget,
      );
    });

    testWidgets('a moved block keeps its render object inside the wrapper', (
      tester,
    ) async {
      Widget pad(int index, MarkdownBlock block, Widget child) =>
          Padding(padding: const EdgeInsets.only(left: 4), child: child);
      Widget view(String data) => _app(
        child: MarkdownView(data: data, blockWrapper: pad),
      );
      await tester.pumpWidget(view('one\n\ntwo'));
      final two = _para(tester, 'two');
      await tester.pumpWidget(view('one\n\n# new\n\ntwo'));
      expect(identical(_para(tester, 'two'), two), isTrue);
      expect(two.blockIndex, 2);
    });

    testWidgets('a different wrapper rebuilds every block', (tester) async {
      Widget other(int index, MarkdownBlock block, Widget child) =>
          KeyedSubtree(key: ValueKey<String>('other-$index'), child: child);
      Widget view(MarkdownBlockWrapper? wrapper) => _app(
        child: MarkdownView(data: 'one\n\ntwo', blockWrapper: wrapper),
      );
      await tester.pumpWidget(view(wrap));
      await tester.pumpWidget(view(other));
      expect(find.byKey(const ValueKey<String>('other-0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('other-1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('wrapped-0-ParagraphBlock')),
        findsNothing,
      );
      await tester.pumpWidget(view(null));
      expect(find.byKey(const ValueKey<String>('other-0')), findsNothing);
      expect(_allParagraphTexts(tester), ['one', 'two']);
    });

    testWidgets('wraps the blocks a SliverMarkdownView builds', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(420, 680)),
            child: MarkdownSelectionScope(
              child: CustomScrollView(
                slivers: [
                  SliverMarkdownView(
                    data: '# Title\n\nBody',
                    blockWrapper: wrap,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('wrapped-0-HeadingBlock')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('wrapped-1-ParagraphBlock')),
        findsOneWidget,
      );
    });
  });

  group('state kept across rebuilds', () {
    testWidgets('an open details block stays open through a theme change', (
      tester,
    ) async {
      const data =
          'lead\n\n<details>\n<summary>Open me</summary>\n\nInner body\n\n'
          '</details>';
      Widget view(MarkdownThemeData theme) => _app(
        child: MarkdownView(
          documentId: 'rebuild-details-theme',
          data: data,
          theme: theme,
        ),
      );
      await tester.pumpWidget(view(MarkdownThemeData.fallback()));
      await tester.tapAt(
        _para(tester, 'Open me').localToGlobal(const Offset(4, 4)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Inner', findRichText: true), findsOneWidget);
      await tester.pumpWidget(view(MarkdownThemeData.dark()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Inner', findRichText: true), findsOneWidget);
      expect(
        _styleOf(tester, 'Inner').color,
        MarkdownThemeData.dark().bodyStyle.color,
      );
    });

    testWidgets('a scrolled table keeps its offset through a theme change', (
      tester,
    ) async {
      final data =
          '| ${List.filled(8, 'wide column').join(' | ')} |\n'
          '| ${List.filled(8, '---').join(' | ')} |\n'
          '| ${List.filled(8, 'v').join(' | ')} |';
      Widget view(MarkdownThemeData theme) => _app(
        child: MarkdownView(documentId: 'table-keep', data: data, theme: theme),
      );
      await tester.pumpWidget(view(MarkdownThemeData.fallback()));
      final scroller = find.descendant(
        of: find.byType(MarkdownTableWidget),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroller, const Offset(-200, 0));
      await tester.pumpAndSettle();
      final left = tester.getTopLeft(find.byType(Table)).dx;
      expect(left, lessThan(-100.0));
      await tester.pumpWidget(view(MarkdownThemeData.dark()));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(Table)).dx, left);
    });
  });
}

class _FixedParser implements MarkdownParser {
  _FixedParser(this.text);

  final String text;

  @override
  MarkdownDocument parse(String markdown, {bool isStreaming = false}) {
    return MarkdownDocument(
      blocks: [
        ParagraphBlock(inlines: [TextInline(text)]),
      ],
    );
  }
}
