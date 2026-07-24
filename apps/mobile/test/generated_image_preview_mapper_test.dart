import 'package:ccpocket/features/generated_image_preview/generated_image_preview_item.dart';
import 'package:ccpocket/features/generated_image_preview/generated_image_preview_mapper.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dataUrl =
      'data:image/png;base64,'
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
      'AAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==';
  const message = ToolResultMessage(
    toolUseId: 'image-generation-1',
    toolName: 'ImageGeneration',
    content: 'status: completed\nrevisedPrompt: Cached prompt',
    images: [ImageRef(id: 'image-1', url: dataUrl, mimeType: 'image/png')],
  );

  test('resolves a data URL without an HTTP base URL', () {
    final items = generatedImageItemsFromToolResults([
      message,
    ], httpBaseUrl: null);

    expect(items, hasLength(1));
    expect(items.single.bytes, isNotEmpty);
    expect(items.single.url, isNull);
  });

  test('skips a relative image when an HTTP base URL is unavailable', () {
    const relativeMessage = ToolResultMessage(
      toolUseId: 'image-generation-relative',
      toolName: 'ImageGeneration',
      content: 'status: completed',
      images: [
        ImageRef(
          id: 'relative-image',
          url: '/images/generated.png',
          mimeType: 'image/png',
        ),
      ],
    );

    expect(
      generatedImageItemsFromToolResults([relativeMessage], httpBaseUrl: null),
      isEmpty,
    );
  });

  test('reuses decoded data images from the supplied bounded cache', () {
    final cache = <GeneratedImageItemCacheKey, GeneratedImagePreviewItem>{};

    final first = generatedImageItemsFromToolResults(
      [message],
      httpBaseUrl: null,
      itemCache: cache,
    );
    final second = generatedImageItemsFromToolResults(
      [message],
      httpBaseUrl: null,
      itemCache: cache,
    );

    expect(cache, hasLength(1));
    expect(identical(first.single, second.single), isTrue);
    expect(identical(first.single.bytes, second.single.bytes), isTrue);
  });
}
