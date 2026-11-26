import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

Widget _app({
  required Widget child,
  required Size size,
  TextScaler scaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return Directionality(
    textDirection: ui.TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(size: size, textScaler: scaler, padding: padding),
      child: FocusScope(
        autofocus: true,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _longPress(WidgetTester tester, Offset at) async {
  final gesture = await tester.startGesture(at, kind: PointerDeviceKind.touch);
  await tester.pump(const Duration(milliseconds: 700));
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 400));
  // The menu's overlay entry is inserted on the frame after the release.
  await tester.pump(const Duration(milliseconds: 400));
}

/// The visible bar. The menu widget itself fills the overlay to position it.
Rect _menuRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(
        of: find.byType(MarkdownDefaultContextMenu),
        matching: find.byType(DecoratedBox),
      )
      .first,
);

void main() {
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('fits a 320lp screen at text scale $scale', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const size = Size(320, 640);
      await tester.pumpWidget(
        _app(
          size: size,
          scaler: TextScaler.linear(scale),
          child: const Padding(
            padding: EdgeInsets.only(top: 300),
            child: MarkdownView(data: 'Some **words** to select here.'),
          ),
        ),
      );
      await _longPress(
        tester,
        tester.getTopLeft(find.byType(MarkdownView)) + const Offset(20, 10),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Copy'), findsOneWidget);

      final bar = tester.getRect(
        find
            .descendant(
              of: find.byType(MarkdownDefaultContextMenu),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(bar.left, greaterThanOrEqualTo(0.0));
      expect(bar.right, lessThanOrEqualTo(size.width));
      expect(bar.top, greaterThanOrEqualTo(0.0));
      expect(bar.bottom, lessThanOrEqualTo(size.height));
    });
  }

  testWidgets('goes below a selection at the top of the screen', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        size: const Size(400, 640),
        padding: const EdgeInsets.only(top: 44),
        child: const Padding(
          padding: EdgeInsets.only(top: 48),
          child: MarkdownView(data: 'Top line of text.'),
        ),
      ),
    );
    final text = tester.getRect(find.byType(SelectableParagraph));
    await _longPress(tester, text.topLeft + const Offset(20, 8));
    expect(tester.takeException(), isNull);
    final bar = tester.getRect(
      find
          .descendant(
            of: find.byType(MarkdownDefaultContextMenu),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(bar.top, greaterThanOrEqualTo(text.bottom));
  });

  testWidgets('long labels scroll instead of overflowing', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        size: const Size(320, 640),
        child: Padding(
          padding: const EdgeInsets.only(top: 300),
          child: MarkdownSelectionScope(
            contextMenuBuilder: (context, state) => MarkdownDefaultContextMenu(
              state: state,
              labels: const MarkdownContextMenuLabels(
                copy: 'Kopieren in die Zwischenablage',
                copyAsMarkdown: 'Als Markdown-Quelltext kopieren',
                selectAll: 'Gesamten Text auswählen',
              ),
            ),
            child: const MarkdownView(data: 'Some words to select here.'),
          ),
        ),
      ),
    );
    await _longPress(
      tester,
      tester.getTopLeft(find.byType(MarkdownView)) + const Offset(20, 10),
    );
    expect(tester.takeException(), isNull);
    final bar = _menuRect(tester);
    expect(bar.left, greaterThanOrEqualTo(0.0));
    expect(bar.right, lessThanOrEqualTo(320.0));
    // The last button is reachable by scrolling the bar.
    await tester.drag(
      find.text('Kopieren in die Zwischenablage'),
      const Offset(-2000, 0),
    );
    await tester.pump();
    expect(
      tester.getRect(find.text('Gesamten Text auswählen')).right,
      lessThanOrEqualTo(bar.right),
    );
  });

  testWidgets('Select all then Copy as Markdown act on the selection', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      _app(
        size: const Size(800, 600),
        child: const Padding(
          padding: EdgeInsets.only(top: 200),
          child: MarkdownView(data: '# Title\n\nSome **bold** text.'),
        ),
      ),
    );
    await _longPress(
      tester,
      tester.getTopLeft(find.byType(MarkdownView)) + const Offset(20, 10),
    );
    await tester.tap(find.text('Select all'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Copy as Markdown'));
    await tester.pump();
    expect(clipboard, '# Title\n\nSome **bold** text.');
  });

  testWidgets('desktop: a mouse drag shows no menu, a right click does, and '
      'Escape closes it', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      _app(
        size: const Size(800, 600),
        child: const Padding(
          padding: EdgeInsets.only(top: 200),
          child: MarkdownView(data: 'Some words to select here.'),
        ),
      ),
    );
    final origin = tester.getTopLeft(find.byType(MarkdownView));
    final mouse = await tester.startGesture(
      origin + const Offset(5, 10),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveTo(origin + const Offset(120, 10));
    await tester.pump();
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Copy'), findsNothing);

    await tester.tapAt(
      origin + const Offset(40, 10),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Copy'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Copy'), findsNothing);
  });
}
