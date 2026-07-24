import 'dart:typed_data';

/// One generated image and the generation metadata shown in its preview.
class GeneratedImagePreviewItem {
  final String id;
  final String? url;
  final Uint8List? bytes;
  final String mimeType;
  final String prompt;
  final String? status;
  final String? savedPath;
  final String? details;

  const GeneratedImagePreviewItem({
    required this.id,
    this.url,
    this.bytes,
    required this.mimeType,
    required this.prompt,
    this.status,
    this.savedPath,
    this.details,
  }) : assert(bytes != null || (url != null && url != ''));

  bool get hasDetails =>
      status?.isNotEmpty == true ||
      savedPath?.isNotEmpty == true ||
      details?.isNotEmpty == true;
}
