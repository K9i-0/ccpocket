import 'dart:typed_data';

import 'package:ccpocket/features/file_peek/glb_preview_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reuses bytes for five minutes without extending expiry', (
    tester,
  ) async {
    final cache = GlbPreviewCache();
    addTearDown(cache.clear);
    final bytes = Uint8List(4);
    cache.put('https://bridge/api/media/version1', bytes);
    await tester.pump(const Duration(minutes: 4));
    expect(cache.get('https://bridge/api/media/version1'), same(bytes));
    expect(cache.get('https://bridge/api/media/version2'), isNull);
    expect(cache.get('https://other/api/media/version1'), isNull);
    await tester.pump(const Duration(minutes: 1));
    expect(cache.get('https://bridge/api/media/version1'), isNull);
  });

  test('evicts least recently used bytes and rejects oversized entries', () {
    final cache = GlbPreviewCache(maxBytes: 8);
    addTearDown(cache.clear);
    cache.put('a', Uint8List(4));
    cache.put('b', Uint8List(4));
    expect(cache.get('a'), isNotNull);
    cache.put('c', Uint8List(4));
    expect(cache.get('a'), isNotNull);
    expect(cache.get('b'), isNull);
    expect(cache.get('c'), isNotNull);
    cache.put('oversized', Uint8List(9));
    expect(cache.get('oversized'), isNull);
    expect(cache.get('a'), isNotNull);
    cache.remove('a');
    expect(cache.get('a'), isNull);
  });

  testWidgets('replacement cancels old expiry and releases byte budget', (
    tester,
  ) async {
    final cache = GlbPreviewCache(maxBytes: 8);
    addTearDown(cache.clear);
    cache.put('a', Uint8List(8));
    await tester.pump(const Duration(minutes: 4));
    final replacement = Uint8List(4);
    cache.put('a', replacement);
    cache.put('b', Uint8List(4));
    await tester.pump(const Duration(minutes: 1));
    expect(cache.get('a'), same(replacement));
    expect(cache.get('b'), isNotNull);
    await tester.pump(const Duration(minutes: 4));
    expect(cache.get('a'), isNull);
    expect(cache.get('b'), isNull);
  });
}
