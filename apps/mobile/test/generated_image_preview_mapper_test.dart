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

  test('keeps the disk cache key stable when Bridge image URLs change', () {
    const firstMessage = ToolResultMessage(
      toolUseId: 'image-generation-stable',
      toolName: 'ImageGeneration',
      content:
          'status: completed\n'
          'revisedPrompt: Stable image\n'
          'Generated 1 image',
      images: [
        ImageRef(
          id: 'bridge-image-1',
          url: '/images/random-1',
          mimeType: 'image/png',
        ),
      ],
    );
    const restoredMessage = ToolResultMessage(
      toolUseId: 'image-generation-stable',
      toolName: 'ImageGeneration',
      content: 'status: completed\nrevisedPrompt: Stable image',
      images: [
        ImageRef(
          id: 'bridge-image-2',
          url: '/images/random-2',
          mimeType: 'image/png',
        ),
      ],
    );

    final first = generatedImageItemsFromToolResults([
      firstMessage,
    ], httpBaseUrl: 'http://localhost:8765').single;
    final restored = generatedImageItemsFromToolResults([
      restoredMessage,
    ], httpBaseUrl: 'http://localhost:8765').single;

    expect(first.url, isNot(restored.url));
    expect(first.cacheKey, isNotNull);
    expect(first.cacheKey, restored.cacheKey);
  });

  test('changes the disk cache key when content-addressed image id changes', () {
    const firstMessage = ToolResultMessage(
      toolUseId: 'image-generation-content-addressed',
      toolName: 'ImageGeneration',
      content: 'Generated 1 image',
      images: [
        ImageRef(
          id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          url: '/images/first',
          mimeType: 'image/png',
        ),
      ],
    );
    const changedMessage = ToolResultMessage(
      toolUseId: 'image-generation-content-addressed',
      toolName: 'ImageGeneration',
      content: 'Generated 1 image',
      images: [
        ImageRef(
          id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          url: '/images/second',
          mimeType: 'image/png',
        ),
      ],
    );

    final first = generatedImageItemsFromToolResults([
      firstMessage,
    ], httpBaseUrl: 'http://localhost:8765').single;
    final changed = generatedImageItemsFromToolResults([
      changedMessage,
    ], httpBaseUrl: 'http://localhost:8765').single;

    expect(first.cacheKey, isNot(changed.cacheKey));
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
