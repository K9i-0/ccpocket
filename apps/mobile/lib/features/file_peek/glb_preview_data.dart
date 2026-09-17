import 'dart:convert';
import 'dart:typed_data';

import '../../utils/media_file_types.dart';

const maxGlbPreviewBytes = 50 * 1024 * 1024;

bool isGlbPath(String path) => mediaFileExtensionForPath(path) == 'glb';

/// Only self-contained glTF 2 binaries are accepted. Never resolve model URIs
/// against the Bridge or arbitrary network locations.
void validatePreviewGlb(Uint8List bytes) {
  if (bytes.length > maxGlbPreviewBytes) {
    throw const FormatException('model_too_large');
  }
  if (bytes.length < 20) throw const FormatException('Invalid GLB');
  final data = ByteData.sublistView(bytes);
  if (data.getUint32(0, Endian.little) != 0x46546c67 ||
      data.getUint32(4, Endian.little) != 2 ||
      data.getUint32(8, Endian.little) != bytes.length ||
      data.getUint32(16, Endian.little) != 0x4e4f534a) {
    throw const FormatException('Invalid GLB');
  }
  final length = data.getUint32(12, Endian.little);
  if (length > bytes.length - 20) throw const FormatException('Invalid GLB');
  final json = jsonDecode(
    utf8.decode(bytes.sublist(20, 20 + length)),
  ) as Map<String, dynamic>;
  for (final key in ['buffers', 'images']) {
    for (final item in (json[key] as List? ?? const [])) {
      final uri = (item as Map)['uri'];
      if (uri != null && !(uri is String && uri.startsWith('data:'))) {
        throw const FormatException('External resources are not supported');
      }
    }
  }
}
