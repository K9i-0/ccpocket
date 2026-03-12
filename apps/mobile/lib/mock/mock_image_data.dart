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

const _width = 375.0;
const _height = 400.0;

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
