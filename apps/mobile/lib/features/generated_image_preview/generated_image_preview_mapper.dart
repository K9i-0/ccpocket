import 'dart:convert';
import 'dart:typed_data';

import '../../models/messages.dart';
import 'generated_image_preview_item.dart';

typedef GeneratedImageItemCacheKey = ({
  String toolUseId,
  String imageId,
  String resolvedUrl,
  String mimeType,
  String content,
});

List<GeneratedImagePreviewItem> generatedImageItemsFromToolResults(
  List<ToolResultMessage> messages, {
  required String? httpBaseUrl,
  Map<GeneratedImageItemCacheKey, GeneratedImagePreviewItem>? itemCache,
}) {
  final items = <GeneratedImagePreviewItem>[];
  for (final message in messages) {
    for (final image in message.images) {
      final resolvedUrl = _resolveImageUrl(image.url, httpBaseUrl);
      if (resolvedUrl == null) continue;
      final cacheKey = (
        toolUseId: message.toolUseId,
        imageId: image.id,
        resolvedUrl: resolvedUrl,
        mimeType: image.mimeType,
        content: message.content,
      );
      final cachedItem = itemCache?[cacheKey];
      if (cachedItem != null) {
        items.add(cachedItem);
        continue;
      }
      final item = _itemFromImageRef(
        message: message,
        image: image,
        resolvedUrl: resolvedUrl,
      );
      items.add(item);
      if (itemCache != null) {
        if (itemCache.length >= 64) {
          itemCache.remove(itemCache.keys.first);
        }
        itemCache[cacheKey] = item;
      }
    }
  }
  return items;
}

GeneratedImagePreviewItem _itemFromImageRef({
  required ToolResultMessage message,
  required ImageRef image,
  required String resolvedUrl,
}) {
  final bytes = _decodeDataImageUrl(resolvedUrl);
  return GeneratedImagePreviewItem(
    id: '${message.toolUseId}:${image.id}',
    url: bytes == null ? resolvedUrl : null,
    bytes: bytes,
    mimeType: image.mimeType,
    prompt: _readPrefixedLine(message.content, 'revisedPrompt') ?? '',
    status: _readPrefixedLine(message.content, 'status'),
    savedPath: _readPrefixedLine(message.content, 'savedPath'),
    details: message.content.isEmpty ? null : message.content,
  );
}

bool canResolveGeneratedImageUrl(
  String imageUrl, {
  required String? httpBaseUrl,
}) {
  return _resolveImageUrl(imageUrl, httpBaseUrl) != null;
}

String? _resolveImageUrl(String imageUrl, String? httpBaseUrl) {
  if (imageUrl.isEmpty) return null;
  final uri = Uri.tryParse(imageUrl);
  if (imageUrl.startsWith('data:image/') || uri?.hasScheme == true) {
    return imageUrl;
  }
  if (httpBaseUrl == null) return null;
  return '$httpBaseUrl$imageUrl';
}

Uint8List? _decodeDataImageUrl(String url) {
  if (!url.startsWith('data:image/')) return null;
  const marker = ';base64,';
  final markerIndex = url.indexOf(marker);
  if (markerIndex == -1) return null;
  try {
    return base64Decode(url.substring(markerIndex + marker.length));
  } catch (_) {
    return null;
  }
}

String? _readPrefixedLine(String content, String key) {
  final prefix = '$key:';
  for (final line in content.split('\n')) {
    if (!line.startsWith(prefix)) continue;
    final value = line.substring(prefix.length).trim();
    return value.isEmpty ? null : value;
  }
  return null;
}
