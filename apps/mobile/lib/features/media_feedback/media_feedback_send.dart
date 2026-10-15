import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'state/media_feedback_state.dart';

typedef FeedbackImage = ({Uint8List bytes, String mimeType});

/// Sources without a workspace path must travel as image attachments. Never
/// silently send instructions with an inaccessible URL as their only reference.
Future<({List<FeedbackImage> images, Map<String, int> indices})> feedbackImages(
  List<MediaFeedback> entries,
  List<FeedbackImage> existing, {
  Future<http.Response> Function(Uri)? get,
}) async {
  final images = [...existing];
  final seen = <String>{};
  final indices = <String, int>{};
  for (final entry in entries) {
    final media = entry.media;
    if (media.isVideo || media.path != null || !seen.add(media.key)) continue;
    final Uint8List bytes;
    if (media.base64 != null) {
      bytes = base64Decode(media.base64!);
    } else {
      final uri = Uri.tryParse(media.url ?? '');
      if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
        throw StateError('Missing image source');
      }
      final response = await (get ?? http.get)(uri)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw StateError('Image unavailable');
      bytes = response.bodyBytes;
    }
    if (bytes.isEmpty) throw StateError('Empty image');
    // The same attached image can also have instructions in its preview.
    final encoded = base64Encode(bytes);
    final existingIndex = images.indexWhere(
      (i) => base64Encode(i.bytes) == encoded,
    );
    if (existingIndex >= 0) {
      indices[media.key] = existingIndex + 1;
      continue;
    }
    if (images.length >= 5) throw StateError('Image limit exceeded');
    images.add((bytes: bytes, mimeType: media.mimeType));
    indices[media.key] = images.length;
  }
  return (images: images, indices: indices);
}
