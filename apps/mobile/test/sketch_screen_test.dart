import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';

import 'package:ccpocket/features/sketch/sketch_document.dart';
import 'package:ccpocket/features/sketch/sketch_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_painter/flutter_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_native_image.dart';

Future<void> openEditor(
  WidgetTester tester, {
  String? initialDocumentJson,
  Uint8List? backgroundImageBytes,
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
                  builder: (_) => SketchScreen(
                    initialDocumentJson: initialDocumentJson,
                    backgroundImageBytes: backgroundImageBytes,
                  ),
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
  await pumpNativeImageUntil(
    tester,
    () =>
        find
            .byKey(const ValueKey('sketch_attach_button'))
            .evaluate()
            .isNotEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty,
  );
}

PainterController painterController(WidgetTester tester) =>
    tester.widget<FlutterPainter>(find.byType(FlutterPainter)).controller;

void main() {
  testWidgets(
    'image annotations export separately and erasing preserves the background',
    (tester) async {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAYAAAD/Rn+7AAAAM0lEQVR4nO3OMQ0AAAjAMEQgDIk4BRVkHDv6N7J6Pgs6YNAgHTBokA4YNEgHDBqkAwavLQitSbvtcAR/AAAAAElFTkSuQmCC',
      );
      SketchResult? result;
      await openEditor(
        tester,
        backgroundImageBytes: bytes,
        onResult: (value) => result = value,
      );
      final controller = painterController(tester);
      expect(controller.painterKey.currentContext?.size, const Size(800, 400));
      expect(controller.value.background, isA<ImageBackgroundDrawable>());
      controller.addDrawables([
        FreeStyleDrawable(
          path: const [Offset(150, 200), Offset(650, 200)],
          color: const Color(0xffff0000),
          strokeWidth: 40,
        ),
        EraseDrawable(
          path: const [Offset(390, 200), Offset(410, 200)],
          strokeWidth: 80,
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sketch_attach_button')));
      await pumpNativeImageUntil(tester, () => result != null);
      expect(result, isNotNull);
      final restored = await SketchDocument.decode(result!.documentJson);
      expect(restored.backgroundImageBytes, bytes);
      expect(restored.drawables, hasLength(2));
      await tester.runAsync(() async {
        final image = await SketchDocument.decodeBackground(result!.bytes);
        try {
          expect(image.width, 1536);
          expect(image.height, 768);
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          List<int> at(int x, int y) => pixels.sublist(
            (y * image.width + x) * 4,
            (y * image.width + x) * 4 + 4,
          );
          expect(at(0, 0), [20, 80, 160, 255]);
          expect(at(576, 384), [255, 0, 0, 255]);
          expect(at(768, 384), [20, 80, 160, 255]);
        } finally {
          image.dispose();
        }
      });
      await openEditor(tester, initialDocumentJson: result!.documentJson);
      final reopened = painterController(tester);
      expect(reopened.drawables, hasLength(2));
      expect(
        (reopened.value.background as ImageBackgroundDrawable).image.width,
        40,
      );
      reopened.clearDrawables();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('sketch_attach_button')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('invalid image cannot replace an attachment', (tester) async {
    await openEditor(
      tester,
      backgroundImageBytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(find.byType(FlutterPainter), findsNothing);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('sketch_attach_button')),
          )
          .onPressed,
      isNull,
    );
  });

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
