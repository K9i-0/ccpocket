import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ccpocket/features/generated_image_preview/generated_image_preview_item.dart';
import 'package:ccpocket/features/generated_image_preview/generated_image_preview_screen.dart';
import 'package:ccpocket/features/generated_image_preview/widgets/generated_image_chat_group.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Uint8List landscapePng;

  setUpAll(() async {
    landscapePng = await _createPng(width: 200, height: 100);
  });

  testWidgets('multiple images use equal square tiles in one row', (
    tester,
  ) async {
    final items = _items(landscapePng, count: 4);
    await tester.pumpWidget(_wrap(GeneratedImageChatGroup(items: items)));
    await tester.pumpAndSettle();

    final group = find.byKey(const ValueKey('generated_image_chat_group'));
    final aspectRatios = find.descendant(
      of: group,
      matching: find.byType(AspectRatio),
    );
    expect(aspectRatios, findsNWidgets(4));
    for (final widget in tester.widgetList<AspectRatio>(aspectRatios)) {
      expect(widget.aspectRatio, 1);
    }

    final tiles = [
      for (var index = 0; index < 4; index++)
        find.byKey(ValueKey('generated_image_chat_thumbnail_$index')),
    ];
    final sizes = [for (final tile in tiles) tester.getSize(tile)];
    expect(sizes.map((size) => size.width).toSet(), hasLength(1));
    expect(sizes.every((size) => size.aspectRatio == 1), isTrue);
    expect(tester.getTopLeft(tiles.first).dy, tester.getTopLeft(tiles.last).dy);
  });

  testWidgets('a single image keeps its intrinsic aspect ratio', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(GeneratedImageChatGroup(items: _items(landscapePng, count: 1))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    final group = find.byKey(const ValueKey('generated_image_chat_group'));
    final aspectRatio = tester.widget<AspectRatio>(
      find.descendant(of: group, matching: find.byType(AspectRatio)),
    );
    expect(aspectRatio.aspectRatio, closeTo(2, 0.01));
    final image = find.descendant(of: group, matching: find.byType(Image));
    final size = tester.getSize(image);
    expect(size.aspectRatio, closeTo(2, 0.01));
  });

  testWidgets('tapping a thumbnail opens the selected preview image', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(GeneratedImageChatGroup(items: _items(landscapePng, count: 3))),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('generated_image_chat_thumbnail_2')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GeneratedImagePreviewScreen), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Generated prompt 3'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: Align(alignment: Alignment.topCenter, child: child),
    ),
  );
}

List<GeneratedImagePreviewItem> _items(Uint8List bytes, {required int count}) {
  return [
    for (var index = 0; index < count; index++)
      GeneratedImagePreviewItem(
        id: 'generated-$index',
        bytes: bytes,
        mimeType: 'image/png',
        prompt: 'Generated prompt ${index + 1}',
      ),
  ];
}

Future<Uint8List> _createPng({required int width, required int height}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.amber,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return byteData!.buffer.asUint8List();
}
