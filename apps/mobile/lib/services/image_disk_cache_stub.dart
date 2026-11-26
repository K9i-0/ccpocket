import 'dart:typed_data';

/// Web/non-IO stub for disk-backed image caching.
///
/// On web platforms without `dart:io`, disk caching is a no-op and callers fall
/// back to plain HTTP fetches (relying on the browser HTTP cache and Flutter's
/// in-memory `ImageCache`).
class ImageDiskCache {
  final String? directoryPath;

  const ImageDiskCache({this.directoryPath});

  Future<Uint8List?> read(
    String cacheKey, {
    required Duration maxAge,
    DateTime? now,
  }) async => null;

  Future<void> write(String cacheKey, Uint8List bytes) async {}

  Future<void> delete(String cacheKey) async {}
}
