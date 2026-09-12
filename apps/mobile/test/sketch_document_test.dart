import 'dart:convert';

import 'package:ccpocket/features/sketch/sketch_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_painter/flutter_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'round trips canvas dimensions, strokes, erasing, shapes and text',
    () async {
      final original = SketchDocument(
        canvasSize: const Size(480, 720),
        drawables: [
          FreeStyleDrawable(
            path: const [Offset(24, 32), Offset(200, 400)],
            color: Colors.blue,
            strokeWidth: 6,
          ),
          EraseDrawable(
            path: const [Offset(60, 90), Offset(80, 90)],
            strokeWidth: 18,
          ),
          ArrowDrawable(position: const Offset(100, 100), length: 140),
          RectangleDrawable(
            position: const Offset(100, 200),
            size: const Size(100, 80),
          ),
          OvalDrawable(
            position: const Offset(200, 300),
            size: const Size(90, 70),
          ),
          TextDrawable(
            position: const Offset(240, 360),
            text: 'A quiet room',
            style: const TextStyle(color: Colors.black, fontSize: 32),
          ),
        ],
      );

      final encoded = await original.encode();
      final restored = await SketchDocument.decode(encoded);

      expect(restored.canvasSize, const Size(480, 720));
      expect(restored.background, Colors.white);
      expect(restored.exportSize, const Size(1024, 1536));
      expect(restored.drawables.map((drawable) => drawable.runtimeType), [
        FreeStyleDrawable,
        EraseDrawable,
        ArrowDrawable,
        RectangleDrawable,
        OvalDrawable,
        TextDrawable,
      ]);
      expect((restored.drawables.first as FreeStyleDrawable).path, const [
        Offset(24, 32),
        Offset(200, 400),
      ]);
      expect((restored.drawables.last as TextDrawable).text, 'A quiet room');
      expect(jsonDecode(await restored.encode()), jsonDecode(encoded));
    },
  );

  test('bounds export resolution in either orientation', () {
    expect(const SketchDocument().exportSize, const Size(1152, 1536));
    expect(
      const SketchDocument(canvasSize: Size(2000, 1000)).exportSize,
      const Size(1536, 768),
    );
  });

  test(
    'rejects invalid or unsupported drafts before restoring a canvas',
    () async {
      final valid = jsonDecode(
        await const SketchDocument().encode(),
      ) as Map<String, dynamic>;
      for (final source in [
        'not json',
        '[]',
        jsonEncode({...valid, 'version': 2}),
        jsonEncode({...valid, 'width': 0}),
        jsonEncode({...valid, 'height': 1000000}),
        jsonEncode({...valid, 'drawing': {}}),
      ]) {
        await expectLater(
          SketchDocument.decode(source),
          throwsA(isA<FormatException>()),
        );
      }
    },
  );
}
