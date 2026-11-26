import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ccpocket/services/cached_network_image_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

final _validPng = Uint8List.fromList([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, //
  0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, //
  0x42, 0x60, 0x82,
]);

Future<ui.Image> _resolveImage(CachedNetworkImageProvider provider) {
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete(info.image);
      }
    },
    onError: (Object error, StackTrace? stack) {
      stream.removeListener(listener);
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
    },
  );
  stream.addListener(listener);
  return completer.future;
}

String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cacheDir;

  setUp(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    cacheDir = await Directory.systemTemp.createTemp('ccpocket_img_cache_');
  });

  tearDown(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  });

  group('CachedNetworkImageProvider', () {
    test(
      'fetches on disk miss, persists SHA-256 file, and serves disk hit',
      () async {
        var httpCalls = 0;
        final client = MockClient((request) async {
          httpCalls++;
          return http.Response.bytes(_validPng, 200);
        });

        const url = 'https://example.com/images/sample.png';
        final first = CachedNetworkImageProvider(
          url,
          httpClient: client,
          cacheDirectoryPath: cacheDir.path,
        );

        final image1 = await _resolveImage(first);
        expect(image1.width, 1);
        expect(image1.height, 1);
        expect(httpCalls, 1);

        final cachedFile = File(p.join(cacheDir.path, _sha256(url)));
        expect(await cachedFile.exists(), isTrue);
        expect(await cachedFile.readAsBytes(), _validPng);

        // Clear Flutter's in-memory ImageCache so the next load must read disk.
        PaintingBinding.instance.imageCache.clear();

        final second = CachedNetworkImageProvider(
          url,
          httpClient: client,
          cacheDirectoryPath: cacheDir.path,
        );
        final image2 = await _resolveImage(second);
        expect(image2.width, 1);
        expect(httpCalls, 1);
      },
    );

    test(
      're-fetches from network when disk cache entry exceeds cacheMaxAge',
      () async {
        var httpCalls = 0;
        final client = MockClient((request) async {
          httpCalls++;
          return http.Response.bytes(_validPng, 200);
        });

        const url = 'https://example.com/images/expiring.png';
        final initial = CachedNetworkImageProvider(
          url,
          cacheMaxAge: const Duration(hours: 1),
          httpClient: client,
          cacheDirectoryPath: cacheDir.path,
        );
        await _resolveImage(initial);
        expect(httpCalls, 1);

        PaintingBinding.instance.imageCache.clear();

        // Advance clock past TTL without sleeping.
        final futureTime = DateTime.now().add(const Duration(hours: 2));
        final expired = CachedNetworkImageProvider(
          url,
          cacheMaxAge: const Duration(hours: 1),
          httpClient: client,
          cacheDirectoryPath: cacheDir.path,
          clock: () => futureTime,
        );
        await _resolveImage(expired);
        expect(httpCalls, 2);
      },
    );

    test(
      'shares disk cache entries across URLs when custom cacheKey matches',
      () async {
        var httpCalls = 0;
        final client = MockClient((request) async {
          httpCalls++;
          return http.Response.bytes(_validPng, 200);
        });

        final providerA = CachedNetworkImageProvider(
          'https://example.com/images/asset.png?token=abc',
          cacheKey: 'thumb:asset-1',
          httpClient: client,
          cacheDirectoryPath: cacheDir.path,
        );
        await _resolveImage(providerA);
        expect(httpCalls, 1);

        PaintingBinding.instance.imageCache.clear();

        final providerB = CachedNetworkImageProvider(
          'https://example.com/images/asset.png?token=xyz',
          cacheKey: 'thumb:asset-1',
          httpClient: client,
          cacheDirectoryPath: cacheDir.path,
        );
        await _resolveImage(providerB);
        expect(httpCalls, 1);
      },
    );

    test('deduplicates concurrent in-flight HTTP requests', () async {
      var httpCalls = 0;
      final gate = Completer<void>();
      final client = MockClient((request) async {
        httpCalls++;
        await gate.future;
        return http.Response.bytes(_validPng, 200);
      });

      const url = 'https://example.com/images/concurrent.png';
      // Distinct scale values bypass Flutter's in-memory ImageCache dedupe so
      // both providers enter loadImage concurrently and hit _inFlight dedupe.
      final provider1 = CachedNetworkImageProvider(
        url,
        scale: 1.0,
        httpClient: client,
        cacheDirectoryPath: cacheDir.path,
      );
      final provider2 = CachedNetworkImageProvider(
        url,
        scale: 2.0,
        httpClient: client,
        cacheDirectoryPath: cacheDir.path,
      );

      final future1 = _resolveImage(provider1);
      final future2 = _resolveImage(provider2);

      // Give both loads a chance to reach the network layer.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();

      final results = await Future.wait([future1, future2]);
      expect(results[0].width, 1);
      expect(results[1].width, 1);
      expect(httpCalls, 1);
    });

    test(
      'recovers from corrupt cached bytes by deleting and re-fetching',
      () async {
        var httpCalls = 0;
        final client = MockClient((request) async {
          httpCalls++;
          return http.Response.bytes(_validPng, 200);
        });

        const url = 'https://example.com/images/corrupt.png';
        final cachedFile = File(p.join(cacheDir.path, _sha256(url)));
        await cachedFile.writeAsBytes([1, 2, 3, 4, 5], flush: true);

        final provider = CachedNetworkImageProvider(
          url,
          httpClient: client,
          cacheDirectoryPath: cacheDir.path,
        );
        final image = await _resolveImage(provider);
        expect(image.width, 1);
        expect(httpCalls, 1);
        expect(await cachedFile.readAsBytes(), _validPng);

        // Subsequent load uses repaired cache file without network fetch.
        PaintingBinding.instance.imageCache.clear();
        await _resolveImage(provider);
        expect(httpCalls, 1);
      },
    );

    test(
      'recovers from empty cached file by deleting and re-fetching',
      () async {
        var httpCalls = 0;
        final client = MockClient((request) async {
          httpCalls++;
          return http.Response.bytes(_validPng, 200);
        });

        const url = 'https://example.com/images/empty.png';
        final cachedFile = File(p.join(cacheDir.path, _sha256(url)));
        await cachedFile.writeAsBytes(const [], flush: true);

        final provider = CachedNetworkImageProvider(
          url,
          httpClient: client,
          cacheDirectoryPath: cacheDir.path,
        );
        await _resolveImage(provider);
        expect(httpCalls, 1);
        expect(await cachedFile.readAsBytes(), _validPng);
      },
    );

    test(
      'forwards custom HTTP headers and evicts failed requests for retry',
      () async {
        var httpCalls = 0;
        String? capturedAuth;
        final client = MockClient((request) async {
          httpCalls++;
          capturedAuth = request.headers['authorization'];
          if (httpCalls == 1) {
            return http.Response('error', 500);
          }
          return http.Response.bytes(_validPng, 200);
        });

        const url = 'https://example.com/images/protected.png';
        final provider = CachedNetworkImageProvider(
          url,
          headers: const {'authorization': 'Bearer secret'},
          httpClient: client,
          cacheDirectoryPath: cacheDir.path,
        );

        await expectLater(
          _resolveImage(provider),
          throwsA(isA<NetworkImageLoadException>()),
        );
        expect(capturedAuth, 'Bearer secret');

        // Allow scheduled microtask eviction to run, then retry should succeed.
        await Future<void>.delayed(Duration.zero);
        final image = await _resolveImage(provider);
        expect(image.width, 1);
        expect(httpCalls, 2);
      },
    );
  });
}
