import 'dart:convert' hide Codec;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_painter/flutter_painter.dart';

/// The canvas coordinate space travels with the strokes so reopening at a
/// different viewport size never stretches or clips the drawing.
class SketchDocument {
  const SketchDocument({
    this.canvasSize = const Size(600, 800),
    this.background = const Color(0xffffffff),
    this.drawables = const [],
    this.backgroundImageBytes,
  });

  final Size canvasSize;
  final Color background;
  final List<Drawable> drawables;
  // Keep the unannotated source, never the flattened attachment preview.
  final Uint8List? backgroundImageBytes;

  /// The caller owns the returned image. Bound decoding before allocating the
  /// raster so a large camera photo does not require its full decoded size.
  static Future<Image> decodeBackground(Uint8List bytes) async {
    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    ImageDescriptor? descriptor;
    Codec? codec;
    try {
      descriptor = await ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        1536 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Size get exportSize {
    const longestSide = 1536.0;
    final ratio = longestSide / canvasSize.longestSide;
    return Size(canvasSize.width * ratio, canvasSize.height * ratio);
  }

  Future<String> encode() async => jsonEncode({
    'version': backgroundImageBytes == null ? 1 : 2,
    'width': canvasSize.width,
    'height': canvasSize.height,
    'background': background.toARGB32(),
    if (backgroundImageBytes != null)
      'backgroundImage': base64Encode(backgroundImageBytes!),
    'drawing': await DrawableJsonCodec().encode(drawables),
  });

  static Future<SketchDocument> decode(String source) async {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic> ||
        (json['version'] != 1 && json['version'] != 2)) {
      throw const FormatException('Unsupported sketch document');
    }
    final width = json['width'];
    final height = json['height'];
    final background = json['background'];
    if (width is! num ||
        height is! num ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0 ||
        width > 4096 ||
        height > 4096 ||
        background is! int ||
        background < 0 ||
        background > 0xffffffff) {
      throw const FormatException('Invalid sketch canvas');
    }
    _validateDrawableTypes(json['drawing']);
    Uint8List? imageBytes;
    if (json['version'] == 2) {
      final encodedImage = json['backgroundImage'];
      if (encodedImage is! String || encodedImage.isEmpty) {
        throw const FormatException('Missing sketch background image');
      }
      imageBytes = base64Decode(encodedImage);
    }
    return SketchDocument(
      canvasSize: Size(width.toDouble(), height.toDouble()),
      background: Color(background),
      backgroundImageBytes: imageBytes,
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
