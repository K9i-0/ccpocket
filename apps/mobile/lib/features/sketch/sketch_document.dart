import 'dart:convert';
import 'dart:ui';

import 'package:flutter_painter/flutter_painter.dart';

/// The canvas coordinate space travels with the strokes so reopening at a
/// different viewport size never stretches or clips the drawing.
class SketchDocument {
  const SketchDocument({
    this.canvasSize = const Size(600, 800),
    this.background = const Color(0xffffffff),
    this.drawables = const [],
  });

  final Size canvasSize;
  final Color background;
  final List<Drawable> drawables;

  Size get exportSize {
    const longestSide = 1536.0;
    final ratio = longestSide / canvasSize.longestSide;
    return Size(canvasSize.width * ratio, canvasSize.height * ratio);
  }

  Future<String> encode() async => jsonEncode({
    'version': 1,
    'width': canvasSize.width,
    'height': canvasSize.height,
    'background': background.toARGB32(),
    'drawing': await DrawableJsonCodec().encode(drawables),
  });

  static Future<SketchDocument> decode(String source) async {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic> || json['version'] != 1) {
      throw const FormatException('Unsupported sketch document');
    }
    final width = json['width'];
    final height = json['height'];
    final background = json['background'];
    if (width is! num ||
        height is! num ||
        !width.isFinite ||
        !height.isFinite ||
        width < 1 ||
        height < 1 ||
        width > 4096 ||
        height > 4096 ||
        background is! int ||
        background < 0 ||
        background > 0xffffffff) {
      throw const FormatException('Invalid sketch canvas');
    }
    _validateDrawableTypes(json['drawing']);
    return SketchDocument(
      canvasSize: Size(width.toDouble(), height.toDouble()),
      background: Color(background),
      drawables: await DrawableJsonCodec().decode(json['drawing']),
    );
  }

  // Accept only shapes this editor produces. In particular, decoding embedded
  // images would allocate resources that this sketch-only document does not own.
  static void _validateDrawableTypes(dynamic drawing) {
    if (drawing is! Map || drawing['drawables'] is! List) {
      throw const FormatException('Invalid sketch drawing');
    }
    for (final entry in drawing['drawables'] as List) {
      if (entry is! Map) throw const FormatException('Invalid sketch drawable');
      switch (entry['type']) {
        case 'group':
          _validateDrawableTypes(entry['data']);
        case 'freeStyle':
        case 'erase':
        case 'text':
        case 'arrow':
        case 'rectangle':
        case 'oval':
          break;
        default:
          throw const FormatException('Unsupported sketch drawable');
      }
    }
  }
}
