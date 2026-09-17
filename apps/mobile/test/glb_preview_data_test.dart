import 'dart:convert';
import 'dart:typed_data';

import 'package:ccpocket/features/file_peek/glb_preview_data.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/file_type_icon.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List glb(Map<String, dynamic> json) {
  final text = utf8.encode(jsonEncode(json));
  final padded = (text.length + 3) & ~3;
  final bytes = Uint8List(20 + padded);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, 0x46546c67, Endian.little);
  data.setUint32(4, 2, Endian.little);
  data.setUint32(8, bytes.length, Endian.little);
  data.setUint32(12, padded, Endian.little);
  data.setUint32(16, 0x4e4f534a, Endian.little);
  bytes.fillRange(20, bytes.length, 32);
  bytes.setRange(20, 20 + text.length, text);
  return bytes;
}

void main() {
  test('identifies GLB paths and uses a dedicated request', () {
    expect(isGlbPath('models/Robot.GLB'), isTrue);
    expect(isGlbPath('robot.blend'), isFalse);
    expect(fileVisualKindForPath('robot.glb'), FileVisualKind.model);
    expect(
      jsonDecode(
        ClientMessage.readModelFile('/p', 'robot.glb', requestId: 'r').toJson(),
      ),
      {
        'type': 'read_model_file',
        'projectPath': '/p',
        'filePath': 'robot.glb',
        'requestId': 'r',
      },
    );
  });
  test('accepts embedded resources', () {
    validatePreviewGlb(
      glb({
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': 0},
        ],
        'images': [
          {'uri': 'data:image/png;base64,AA=='},
        ],
      }),
    );
  });
  test('rejects external buffers and images', () {
    for (final key in ['buffers', 'images']) {
      for (final uri in [
        'texture.png',
        '../secret',
        'https://example.com/t.png',
        'file:///secret',
      ]) {
        expect(
          () => validatePreviewGlb(
            glb({
              key: [
                {'uri': uri},
              ],
            }),
          ),
          throwsFormatException,
        );
      }
    }
  });
  test('rejects malformed and oversized binaries before import', () {
    expect(() => validatePreviewGlb(Uint8List(0)), throwsFormatException);
    final bytes = glb({
      'asset': {'version': '2.0'},
    });
    bytes[0] = 0;
    expect(() => validatePreviewGlb(bytes), throwsFormatException);
    expect(
      () => validatePreviewGlb(Uint8List(maxGlbPreviewBytes + 1)),
      throwsFormatException,
    );
    final truncated = glb({});
    ByteData.sublistView(truncated).setUint32(12, 0xffffffff, Endian.little);
    expect(() => validatePreviewGlb(truncated), throwsFormatException);
  });
}
