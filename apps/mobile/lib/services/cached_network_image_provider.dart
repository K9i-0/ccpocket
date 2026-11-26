import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import 'image_disk_cache.dart';

/// Disk-cached network [ImageProvider] backed by `package:http` and
/// [ImageDiskCache] (SHA-256 filenames in the temp directory on native
/// platforms, plain HTTP fetch on Web).
///
/// Features:
/// - Optional [cacheKey] (defaults to [url]) and [cacheMaxAge] (defaults to 7
///   days).
/// - In-flight request deduplication so concurrent widgets requesting the same
///   image trigger only a single HTTP request.
/// - Automatic recovery from unreadable, empty, or undecodable cached files by
///   deleting the corrupt entry and re-fetching from the network.
/// - Injectable [httpClient], [cacheDirectoryPath], and [clock] for unit tests.
@immutable
class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  static const Duration defaultCacheMaxAge = Duration(days: 7);

  static final Map<String, Future<Uint8List>> _inFlight = {};

  final String url;
  final double scale;
  final String? cacheKey;
  final Duration cacheMaxAge;
  final Map<String, String>? headers;
  final http.Client? httpClient;
  final String? cacheDirectoryPath;
  @visibleForTesting
  final DateTime Function()? clock;

  const CachedNetworkImageProvider(
    this.url, {
    this.scale = 1.0,
    this.cacheKey,
    this.cacheMaxAge = defaultCacheMaxAge,
    this.headers,
    this.httpClient,
    this.cacheDirectoryPath,
    this.clock,
  });

  String get effectiveCacheKey => cacheKey ?? url;

  @override
  Future<CachedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CachedNetworkImageProvider>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);
    final diskCache = ImageDiskCache(directoryPath: cacheDirectoryPath);
    try {
      chunkEvents.add(
        const ImageChunkEvent(
          cumulativeBytesLoaded: 0,
          expectedTotalBytes: null,
        ),
      );

      final cachedBytes = await diskCache.read(
        effectiveCacheKey,
        maxAge: cacheMaxAge,
        now: clock?.call(),
      );
      if (cachedBytes != null) {
        try {
          final buffer = await ui.ImmutableBuffer.fromUint8List(cachedBytes);
          return await decode(buffer);
        } catch (_) {
          // Corrupt or undecodable cache file: evict from disk and re-fetch.
          await diskCache.delete(effectiveCacheKey);
        }
      }

      final bytes = await _fetchDeduplicated(chunkEvents);
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await decode(buffer);
      await diskCache.write(effectiveCacheKey, bytes);
      return codec;
    } catch (_) {
      // Schedule eviction on a microtask so the cache has a chance to register
      // the key before we remove it.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      unawaited(
        chunkEvents.close().catchError((Object _, StackTrace _) {
          // Ignore stream close errors if listeners were already cancelled.
        }),
      );
    }
  }

  String get _inFlightKey {
    final dir = cacheDirectoryPath ?? '';
    final headerKey = headers == null || headers!.isEmpty
        ? ''
        : (headers!.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
              .map((e) => '${e.key}=${e.value}')
              .join('&');
    return '$dir\x00$effectiveCacheKey\x00$url\x00$headerKey';
  }

  Future<Uint8List> _fetchDeduplicated(
    StreamController<ImageChunkEvent> chunkEvents,
  ) {
    final key = _inFlightKey;
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _fetchFromNetwork(chunkEvents);
    _inFlight[key] = future;
    unawaited(
      future.then<void>(
        (_) => _clearInFlight(key, future),
        onError: (Object _, StackTrace _) => _clearInFlight(key, future),
      ),
    );
    return future;
  }

  static void _clearInFlight(String key, Future<Uint8List> future) {
    if (identical(_inFlight[key], future)) {
      _inFlight.remove(key);
    }
  }

  /// Retries transient connection failures, so a brief Bridge reconnect does
  /// not leave a screen that never rebuilds on a broken-image placeholder.
  /// HTTP error statuses are not retried.
  Future<Uint8List> _fetchFromNetwork(
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _fetchOnce(chunkEvents);
      } on http.ClientException {
        if (attempt >= _kMaxFetchAttempts) rethrow;
        await Future<void>.delayed(_kFetchRetryDelay * attempt);
      }
    }
  }

  static const _kMaxFetchAttempts = 3;
  static const _kFetchRetryDelay = Duration(milliseconds: 100);

  Future<Uint8List> _fetchOnce(
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    final resolved = Uri.base.resolve(url);
    final ownedClient = httpClient == null;
    final client = httpClient ?? http.Client();
    try {
      final request = http.Request('GET', resolved);
      if (headers != null) {
        request.headers.addAll(headers!);
      }

      final response = await client.send(request);
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw NetworkImageLoadException(
          statusCode: response.statusCode,
          uri: resolved,
        );
      }

      final expectedTotalBytes = response.contentLength;
      final builder = BytesBuilder(copy: false);
      var bytesLoaded = 0;

      await for (final chunk in response.stream) {
        builder.add(chunk);
        bytesLoaded += chunk.length;
        if (!chunkEvents.isClosed) {
          chunkEvents.add(
            ImageChunkEvent(
              cumulativeBytesLoaded: bytesLoaded,
              expectedTotalBytes: expectedTotalBytes,
            ),
          );
        }
      }

      final bytes = builder.takeBytes();
      if (bytes.isEmpty) {
        throw StateError('CachedNetworkImageProvider: $resolved is empty');
      }
      return bytes;
    } finally {
      if (ownedClient) {
        client.close();
      }
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CachedNetworkImageProvider &&
        other.url == url &&
        other.scale == scale &&
        other.cacheKey == cacheKey &&
        other.cacheMaxAge == cacheMaxAge &&
        other.cacheDirectoryPath == cacheDirectoryPath &&
        identical(other.httpClient, httpClient) &&
        mapEquals(other.headers, headers);
  }

  @override
  int get hashCode => Object.hash(
    url,
    scale,
    cacheKey,
    cacheMaxAge,
    cacheDirectoryPath,
    identityHashCode(httpClient),
    headers == null
        ? null
        : Object.hashAllUnordered(
            headers!.entries.map((e) => Object.hash(e.key, e.value)),
          ),
  );

  @override
  String toString() =>
      '${objectRuntimeType(this, 'CachedNetworkImageProvider')}("$url", scale: $scale)';
}
