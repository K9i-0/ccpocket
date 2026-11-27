import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

Widget _testApp({required Widget child}) {
  return Directionality(
    textDirection: TextDirection.ltr,
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

RenderSelectableParagraph _paragraph(WidgetTester tester, String text) {
  return tester.allRenderObjects
      .whereType<RenderSelectableParagraph>()
      .firstWhere((p) => p.text.toPlainText() == text);
}

Rect _globalRect(RenderSelectableParagraph p) =>
    p.localToGlobal(Offset.zero) & p.size;

Future<MarkdownSelectionController> _pump(
  WidgetTester tester,
  String data,
) async {
  final controller = MarkdownSelectionController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    _testApp(
      child: MarkdownSelectionScope(
        controller: controller,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Align(
            alignment: Alignment.topLeft,
            child: MarkdownView(documentId: 'doc', data: data),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
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
  await tester.pump();
  await mouse.removePointer();
}

void main() {
  group('mouse press beside the text', () {
    testWidgets('a drag from past the end of a line selects back from the '
        'line end', (tester) async {
      final controller = await _pump(tester, 'Alpha Beta\n\nSecond');
      final rect = _globalRect(_paragraph(tester, 'Alpha Beta'));

      // Well right of the last glyph, at the height of the line.
      final from = Offset(rect.right + 200, rect.center.dy);
      final to = Offset(rect.left - 20, rect.center.dy);
      await _drag(tester, from, to);

      expect(controller.getText(), 'Alpha Beta');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a drag from the list marker side selects the item text', (
      tester,
    ) async {
      final controller = await _pump(tester, '- Item one\n- Item two');
      final rect = _globalRect(_paragraph(tester, 'Item one'));

      // Left of the item text, in the marker and padding area.
      final from = Offset(5, rect.center.dy);
      expect(from.dx, lessThan(rect.left));
      final to = Offset(rect.right + 100, rect.center.dy);
      await _drag(tester, from, to);

      expect(controller.getText(), 'Item one');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a press in the gap between blocks still clears the '
        'selection and starts nothing', (tester) async {
      final controller = await _pump(tester, 'Alpha Beta\n\nSecond');
      final first = _globalRect(_paragraph(tester, 'Alpha Beta'));
      final second = _globalRect(_paragraph(tester, 'Second'));
      expect(second.top, greaterThan(first.bottom));

      controller.selectAll();
      expect(controller.hasSelection, isTrue);

      final gap = Offset(first.left + 10, (first.bottom + second.top) / 2);
      await _drag(tester, gap, Offset(first.right, first.center.dy));

      expect(controller.selection, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('canStartSelectionAt still vetoes a press beside the text', (
      tester,
    ) async {
      final controller = MarkdownSelectionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _testApp(
          child: MarkdownSelectionScope(
            controller: controller,
            canStartSelectionAt: (_) => false,
            child: const Align(
              alignment: Alignment.topLeft,
              child: MarkdownView(documentId: 'doc', data: 'Alpha Beta'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = _globalRect(_paragraph(tester, 'Alpha Beta'));

      await _drag(
        tester,
        Offset(rect.right + 200, rect.center.dy),
        Offset(rect.left, rect.center.dy),
      );

      expect(controller.selection, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });
}
