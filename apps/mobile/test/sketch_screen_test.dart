import 'dart:ui' as ui;

import 'package:ccpocket/features/sketch/sketch_document.dart';
import 'package:ccpocket/features/sketch/sketch_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_painter/flutter_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openEditor(
  WidgetTester tester, {
  String? initialDocumentJson,
  ValueChanged<SketchResult?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<SketchResult>(
                MaterialPageRoute(
                  builder: (_) =>
                      SketchScreen(initialDocumentJson: initialDocumentJson),
                ),
              );
              onResult?.call(result);
            },
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

PainterController painterController(WidgetTester tester) =>
    tester.widget<FlutterPainter>(find.byType(FlutterPainter)).controller;

void main() {
  testWidgets('draws, undoes and redoes before confirming discarded changes', (
    tester,
  ) async {
    await openEditor(tester);
    final canvas = find.byKey(const ValueKey('sketch_canvas'));
    final controller = painterController(tester);
    final attach = find.byKey(const ValueKey('sketch_attach_button'));
    expect(tester.widget<TextButton>(attach).onPressed, isNull);
    await tester.drag(canvas, const Offset(60, 80));
    await tester.pumpAndSettle();
    expect(controller.drawables, isNotEmpty);
    expect(tester.widget<TextButton>(attach).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('sketch_undo_button')));
    await tester.pumpAndSettle();
    expect(controller.drawables, isEmpty);
    expect(tester.widget<TextButton>(attach).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('sketch_redo_button')));
    await tester.pumpAndSettle();
    expect(controller.drawables, isNotEmpty);

    await tester.tap(find.byKey(const ValueKey('sketch_close_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sketch_discard_button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sketch_keep_editing_button')));
    await tester.pumpAndSettle();
    expect(controller.drawables, isNotEmpty);
    await tester.tap(find.byKey(const ValueKey('sketch_close_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sketch_discard_button')));
    await tester.pumpAndSettle();
    expect(find.byType(SketchScreen), findsNothing);
  });

  testWidgets('cancels a blank editor without a discard dialog', (
    tester,
  ) async {
    var completed = false;
    await openEditor(
      tester,
      onResult: (result) {
        completed = true;
        expect(result, isNull);
      },
    );
    await tester.tap(find.byKey(const ValueKey('sketch_close_button')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('adds selectable text and deletes it with undo available', (
    tester,
  ) async {
    await openEditor(tester);
    await tester.tap(find.byKey(const ValueKey('sketch_text_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sketch_text_field')),
      'A quiet room',
    );
    await tester.tap(find.byKey(const ValueKey('sketch_text_confirm_button')));
    await tester.pumpAndSettle();
    final controller = painterController(tester);
    expect((controller.drawables.single as TextDrawable).text, 'A quiet room');
    expect(controller.selectedObjectDrawable, isA<TextDrawable>());

    await tester.tap(find.byKey(const ValueKey('sketch_delete_button')));
    await tester.pumpAndSettle();
    expect(controller.drawables, isEmpty);
    await tester.tap(find.byKey(const ValueKey('sketch_undo_button')));
    await tester.pumpAndSettle();
    expect(controller.drawables.single, isA<TextDrawable>());
  });

  testWidgets('failed restoration cannot overwrite the original attachment', (
    tester,
  ) async {
    await openEditor(tester, initialDocumentJson: '{broken');
    expect(find.byType(FlutterPainter), findsNothing);
    final attach = tester.widget<TextButton>(
      find.byKey(const ValueKey('sketch_attach_button')),
    );
    expect(attach.onPressed, isNull);
    expect(find.byType(SketchScreen), findsOneWidget);
  });

  testWidgets(
    'restores coordinates across viewport changes and exports white PNG',
    (tester) async {
      final document = SketchDocument(
        drawables: [
          FreeStyleDrawable(
            path: const [Offset(150, 200), Offset(450, 600)],
            color: Colors.black,
            strokeWidth: 12,
          ),
        ],
      );
      await openEditor(tester, initialDocumentJson: await document.encode());
      final controller = painterController(tester);
      expect(controller.painterKey.currentContext?.size, const Size(600, 800));

      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(controller.painterKey.currentContext?.size, const Size(600, 800));
      expect((controller.drawables.single as FreeStyleDrawable).path, const [
        Offset(150, 200),
        Offset(450, 600),
      ]);

      await tester.runAsync(() async {
        final rendered = await controller.renderImage(document.exportSize);
        try {
          expect(rendered.width, 1152);
          expect(rendered.height, 1536);
          final pixels = await rendered.toByteData();
          expect(pixels!.buffer.asUint8List().take(4), [255, 255, 255, 255]);
          final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
          expect(png!.buffer.asUint8List().take(8), [
            137,
            80,
            78,
            71,
            13,
            10,
            26,
            10,
          ]);
        } finally {
          rendered.dispose();
        }
      });
    },
  );
}
