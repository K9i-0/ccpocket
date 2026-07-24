// Programmatically generated PNG images for mock image diff scenarios.
//
// Creates two visually distinct images (Before / After) that demonstrate
// realistic diff use cases: color changes, element repositioning, etc.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Generates a pair of mock images for diff testing.
/// Returns (oldBytes, newBytes) as PNG-encoded Uint8List.
Future<(Uint8List, Uint8List)> generateMockDiffImages() async {
  final oldBytes = await _renderPng(_drawBeforeImage);
  final newBytes = await _renderPng(_drawAfterImage);
  return (oldBytes, newBytes);
}

/// Generates a pair for "new file" scenario (only after exists).
Future<Uint8List> generateMockNewFileImage() async {
  return _renderPng(_drawAfterImage);
}

/// Generates four lightweight proposal-sheet images for the generated-image
/// preview mock. They intentionally share one visual system while keeping each
/// page distinct, making page navigation easy to verify.
Future<List<Uint8List>> generateMockGeneratedImages() async {
  final images = <Uint8List>[];
  for (var index = 0; index < 4; index++) {
    images.add(await _renderGeneratedConcept(index));
  }
  return images;
}

/// Generates a landscape image so the chat preview can verify that a single
/// generated image keeps its original aspect ratio.
Future<Uint8List> generateMockGeneratedLandscapeImage() async {
  const size = Size(1080, 640);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _drawGeneratedLandscapeConcept(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return byteData!.buffer.asUint8List();
}

const _width = 375.0;
const _height = 400.0;
const _generatedSize = Size(720, 900);

Future<Uint8List> _renderPng(void Function(Canvas, Size) painter) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = Size(_width, _height);
  painter(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return byteData!.buffer.asUint8List();
}

Future<Uint8List> _renderGeneratedConcept(int index) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _drawGeneratedConcept(canvas, _generatedSize, index);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    _generatedSize.width.toInt(),
    _generatedSize.height.toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return byteData!.buffer.asUint8List();
}

void _drawGeneratedConcept(Canvas canvas, Size size, int index) {
  const paperColors = [
    Color(0xFFFFFCF4),
    Color(0xFFF8FBFF),
    Color(0xFFFFFAF7),
    Color(0xFFF8FFF9),
  ];
  const accentColors = [
    Color(0xFFFFD92F),
    Color(0xFFFFB347),
    Color(0xFFFFD92F),
    Color(0xFFB8E986),
  ];
  const titles = [
    'AI TEAMMATE',
    'MORNING FLOW',
    'CHARACTER LOOP',
    'NAME IDEAS',
  ];
  const subtitles = [
    'Talk, delegate, and keep moving',
    'Four steps to start the day',
    'One partner across every task',
    'A small workshop for big ideas',
  ];

  canvas.drawRect(Offset.zero & size, Paint()..color = paperColors[index]);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(28, 28, size.width - 56, size.height - 56),
      const Radius.circular(22),
    ),
    Paint()
      ..color = const Color(0xFF202020)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(82, 72, size.width - 164, 84),
      const Radius.circular(42),
    ),
    Paint()..color = accentColors[index].withValues(alpha: 0.72),
  );
  _paintGeneratedText(
    canvas,
    titles[index],
    const Offset(0, 88),
    size.width,
    fontSize: 42,
    fontWeight: FontWeight.w800,
    textAlign: TextAlign.center,
  );
  _paintGeneratedText(
    canvas,
    subtitles[index],
    const Offset(50, 166),
    size.width - 100,
    fontSize: 20,
    textAlign: TextAlign.center,
  );

  for (var row = 0; row < 3; row++) {
    _drawGeneratedStep(
      canvas,
      Rect.fromLTWH(64, 236 + row * 182, size.width - 128, 142),
      number: row + 1,
      accent: accentColors[index],
      mirrored: (row + index).isOdd,
    );
  }

  _paintGeneratedText(
    canvas,
    'CODEX  +  CC POCKET',
    Offset(50, size.height - 88),
    size.width - 100,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    textAlign: TextAlign.center,
    color: const Color(0xFF555555),
  );
}

void _drawGeneratedLandscapeConcept(Canvas canvas, Size size) {
  const accent = Color(0xFFFFD92F);
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFCF4));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(28, 28, size.width - 56, size.height - 56),
      const Radius.circular(24),
    ),
    Paint()
      ..color = const Color(0xFF202020)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(290, 64, 500, 76),
      const Radius.circular(38),
    ),
    Paint()..color = accent.withValues(alpha: 0.72),
  );
  _paintGeneratedText(
    canvas,
    'ONE WIDE CONCEPT',
    const Offset(0, 80),
    size.width,
    fontSize: 38,
    fontWeight: FontWeight.w800,
    textAlign: TextAlign.center,
  );
  _paintGeneratedText(
    canvas,
    'A single image keeps its original landscape ratio',
    const Offset(100, 158),
    size.width - 200,
    fontSize: 21,
    textAlign: TextAlign.center,
  );

  for (var column = 0; column < 3; column++) {
    final rect = Rect.fromLTWH(62 + column * 342, 232, 300, 260);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      Paint()
        ..color = const Color(0xFF202020)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      Offset(rect.center.dx, rect.top + 80),
      42,
      Paint()..color = accent.withValues(alpha: 0.58),
    );
    _paintGeneratedText(
      canvas,
      '${column + 1}  ${const ['ASK', 'MAKE', 'SHARE'][column]}',
      Offset(rect.left + 24, rect.top + 145),
      rect.width - 48,
      fontSize: 25,
      fontWeight: FontWeight.w800,
      textAlign: TextAlign.center,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 48, rect.top + 202, rect.width - 96, 10),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFBDBDBD),
    );
  }
}

void _drawGeneratedStep(
  Canvas canvas,
  Rect rect, {
  required int number,
  required Color accent,
  required bool mirrored,
}) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(20)),
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(20)),
    Paint()
      ..color = const Color(0xFF272727)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );

  final avatarX = mirrored ? rect.right - 74 : rect.left + 74;
  canvas.drawCircle(
    Offset(avatarX, rect.top + 60),
    36,
    Paint()..color = accent.withValues(alpha: 0.58),
  );
  canvas.drawCircle(
    Offset(avatarX - 12, rect.top + 56),
    4,
    Paint()..color = const Color(0xFF202020),
  );
  canvas.drawCircle(
    Offset(avatarX + 12, rect.top + 56),
    4,
    Paint()..color = const Color(0xFF202020),
  );
  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(avatarX, rect.top + 61),
      width: 30,
      height: 22,
    ),
    0.2,
    2.7,
    false,
    Paint()
      ..color = const Color(0xFF202020)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );

  final textLeft = mirrored ? rect.left + 28 : rect.left + 142;
  final textWidth = rect.width - 170;
  _paintGeneratedText(
    canvas,
    '$number  ${switch (number) {
      1 => 'ASK',
      2 => 'MAKE',
      _ => 'REVIEW',
    }}',
    Offset(textLeft, rect.top + 28),
    textWidth,
    fontSize: 24,
    fontWeight: FontWeight.w800,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(textLeft, rect.top + 72, textWidth * 0.9, 10),
      const Radius.circular(5),
    ),
    Paint()..color = const Color(0xFFBDBDBD),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(textLeft, rect.top + 94, textWidth * 0.68, 10),
      const Radius.circular(5),
    ),
    Paint()..color = const Color(0xFFD8D8D8),
  );
}

void _paintGeneratedText(
  Canvas canvas,
  String text,
  Offset offset,
  double width, {
  required double fontSize,
  FontWeight fontWeight = FontWeight.w500,
  TextAlign textAlign = TextAlign.left,
  Color color = const Color(0xFF202020),
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: 0.5,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: textAlign,
  )..layout(minWidth: width, maxWidth: width);
  painter.paint(canvas, offset);
}

// ---------------------------------------------------------------------------
// Before image: A simple app mockup with a blue header and basic layout
// ---------------------------------------------------------------------------

void _drawBeforeImage(Canvas canvas, Size size) {
  // Background
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF5F5F5));

  // Header bar (blue)
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _width, 56),
    Paint()..color = const Color(0xFF1976D2),
  );

  // Header title placeholder
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 18, 120, 20),
      const Radius.circular(4),
    ),
    Paint()..color = const Color(0x40FFFFFF),
  );

  // Search bar
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 72, _width - 32, 44),
      const Radius.circular(22),
    ),
    Paint()..color = const Color(0xFFE0E0E0),
  );

  // Search icon circle
  canvas.drawCircle(
    const Offset(40, 94),
    12,
    Paint()..color = const Color(0xFF9E9E9E),
  );

  // Card 1 (old style — sharp corners, no shadow effect)
  _drawOldCard(canvas, 132, 'assets/icon.png', 3);

  // Card 2
  _drawOldCard(canvas, 224, 'settings.dart', 5);

  // Bottom nav bar (old: 4 items)
  canvas.drawRect(
    Rect.fromLTWH(0, size.height - 56, _width, 56),
    Paint()..color = Colors.white,
  );
  canvas.drawRect(
    Rect.fromLTWH(0, size.height - 56, _width, 0.5),
    Paint()..color = const Color(0xFFE0E0E0),
  );
  for (var i = 0; i < 4; i++) {
    final x = _width / 4 * i + _width / 8;
    // Icon dot
    canvas.drawCircle(
      Offset(x, size.height - 36),
      8,
      Paint()
        ..color = i == 0 ? const Color(0xFF1976D2) : const Color(0xFFBDBDBD),
    );
    // Label
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 16, size.height - 20, 32, 8),
        const Radius.circular(2),
      ),
      Paint()
        ..color = i == 0 ? const Color(0xFF1976D2) : const Color(0xFFBDBDBD),
    );
  }

  // FAB (old position: bottom right)
  canvas.drawCircle(
    Offset(_width - 44, size.height - 80),
    24,
    Paint()..color = const Color(0xFF1976D2),
  );
  // Plus icon on FAB
  canvas.drawRect(
    Rect.fromLTWH(_width - 44 - 8, size.height - 80 - 1.5, 16, 3),
    Paint()..color = Colors.white,
  );
  canvas.drawRect(
    Rect.fromLTWH(_width - 44 - 1.5, size.height - 80 - 8, 3, 16),
    Paint()..color = Colors.white,
  );
}

void _drawOldCard(Canvas canvas, double y, String label, int lineCount) {
  // Sharp-cornered card
  canvas.drawRect(
    Rect.fromLTWH(16, y, _width - 32, 76),
    Paint()..color = Colors.white,
  );
  // Border
  canvas.drawRect(
    Rect.fromLTWH(16, y, _width - 32, 76),
    Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  // Icon placeholder
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(28, y + 12, 40, 40),
      const Radius.circular(8),
    ),
    Paint()..color = const Color(0xFFE0E0E0),
  );
  // Title placeholder
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(80, y + 14, 140, 14),
      const Radius.circular(3),
    ),
    Paint()..color = const Color(0xFFBDBDBD),
  );
  // Subtitle placeholder
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(80, y + 36, 200, 10),
      const Radius.circular(3),
    ),
    Paint()..color = const Color(0xFFE0E0E0),
  );
  // Badge
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(80, y + 54, 40, 14),
      const Radius.circular(7),
    ),
    Paint()..color = const Color(0xFFE3F2FD),
  );
}

// ---------------------------------------------------------------------------
// After image: Redesigned with rounded cards, new accent color, 5 nav items
// ---------------------------------------------------------------------------

void _drawAfterImage(Canvas canvas, Size size) {
  // Background (slightly different)
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFAFAFA));

  // Header bar (new: purple accent with gradient feel)
  final headerPaint = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFF7C4DFF), Color(0xFF536DFE)],
    ).createShader(const Rect.fromLTWH(0, 0, _width, 56));
  canvas.drawRect(const Rect.fromLTWH(0, 0, _width, 56), headerPaint);

  // Header title placeholder (larger)
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 16, 160, 24),
      const Radius.circular(6),
    ),
    Paint()..color = const Color(0x40FFFFFF),
  );

  // Search bar (with slight shadow effect via layering)
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 72, _width - 32, 48),
      const Radius.circular(24),
    ),
    Paint()..color = Colors.white,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 72, _width - 32, 48),
      const Radius.circular(24),
    ),
    Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );

  // Search icon circle
  canvas.drawCircle(
    const Offset(42, 96),
    12,
    Paint()..color = const Color(0xFF9E9E9E),
  );

  // Card 1 (new style — rounded corners)
  _drawNewCard(canvas, 136, true);

  // Card 2
  _drawNewCard(canvas, 232, false);

  // Bottom nav bar (new: 5 items with center FAB)
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height - 60, _width, 60),
      const Radius.circular(0),
    ),
    Paint()..color = Colors.white,
  );
  canvas.drawRect(
    Rect.fromLTWH(0, size.height - 60, _width, 0.5),
    Paint()..color = const Color(0xFFE0E0E0),
  );
  for (var i = 0; i < 5; i++) {
    if (i == 2) continue; // Center is FAB
    final x = _width / 5 * i + _width / 10;
    canvas.drawCircle(
      Offset(x, size.height - 38),
      8,
      Paint()
        ..color = i == 0 ? const Color(0xFF7C4DFF) : const Color(0xFFBDBDBD),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 16, size.height - 22, 32, 8),
        const Radius.circular(2),
      ),
      Paint()
        ..color = i == 0 ? const Color(0xFF7C4DFF) : const Color(0xFFBDBDBD),
    );
  }

  // Center FAB (elevated, new position)
  canvas.drawCircle(
    Offset(_width / 2, size.height - 60),
    28,
    Paint()..color = const Color(0xFF7C4DFF),
  );
  // Plus icon on FAB
  canvas.drawRect(
    Rect.fromLTWH(_width / 2 - 9, size.height - 60 - 1.5, 18, 3),
    Paint()..color = Colors.white,
  );
  canvas.drawRect(
    Rect.fromLTWH(_width / 2 - 1.5, size.height - 60 - 9, 3, 18),
    Paint()..color = Colors.white,
  );
}

void _drawNewCard(Canvas canvas, double y, bool highlighted) {
  // Rounded card with subtle shadow
  final rrect = RRect.fromRectAndRadius(
    Rect.fromLTWH(16, y, _width - 32, 80),
    const Radius.circular(16),
  );
  // Shadow
  canvas.drawRRect(
    rrect.shift(const Offset(0, 2)),
    Paint()..color = const Color(0x1A000000),
  );
  canvas.drawRRect(rrect, Paint()..color = Colors.white);

  // Icon placeholder (circular)
  canvas.drawCircle(
    Offset(48, y + 40),
    20,
    Paint()
      ..color = highlighted ? const Color(0xFFEDE7F6) : const Color(0xFFF5F5F5),
  );

  // Inner icon dot
  canvas.drawCircle(
    Offset(48, y + 40),
    8,
    Paint()
      ..color = highlighted ? const Color(0xFF7C4DFF) : const Color(0xFFBDBDBD),
  );

  // Title placeholder
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(80, y + 16, 160, 16),
      const Radius.circular(4),
    ),
    Paint()..color = const Color(0xFFBDBDBD),
  );
  // Subtitle placeholder
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(80, y + 40, 220, 12),
      const Radius.circular(3),
    ),
    Paint()..color = const Color(0xFFE0E0E0),
  );
  // Badge (new pill style)
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(80, y + 58, 48, 14),
      const Radius.circular(7),
    ),
    Paint()
      ..color = highlighted ? const Color(0xFFEDE7F6) : const Color(0xFFF5F5F5),
  );
}
