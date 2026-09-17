import 'dart:async';
import 'dart:typed_data';

/// Validated source bytes only; scenes and GPU resources belong to the viewer.
/// Full capability URLs isolate servers and change when Bridge sees a new file
/// version. Expiry is measured from insertion, never extended by cache hits.
class GlbPreviewCache {
  GlbPreviewCache({
    this.ttl = const Duration(minutes: 5),
    this.maxBytes = 100 * 1024 * 1024,
  });

  static final shared = GlbPreviewCache();
  final Duration ttl;
  final int maxBytes;
  final _entries = <String, _CachedGlb>{};
  int _size = 0;

  Uint8List? get(String url) {
    final entry = _entries.remove(url);
    if (entry == null) return null;
    _entries[url] = entry;
    if (!DateTime.now().isBefore(entry.expiresAt)) {
      remove(url);
      return null;
    }
    return entry.bytes;
  }

  void put(String url, Uint8List bytes) {
    remove(url);
    if (bytes.length > maxBytes) return;
    while (_size + bytes.length > maxBytes && _entries.isNotEmpty) {
      remove(_entries.keys.first);
    }
    _entries[url] = _CachedGlb(
      bytes,
      Timer(ttl, () => remove(url)),
      DateTime.now().add(ttl),
    );
    _size += bytes.length;
  }

  void remove(String url) {
    final entry = _entries.remove(url);
    if (entry == null) return;
    entry.timer.cancel();
    _size -= entry.bytes.length;
  }

  void clear() {
    for (final key in _entries.keys.toList()) {
      remove(key);
    }
  }
}

class _CachedGlb {
  _CachedGlb(this.bytes, this.timer, this.expiresAt);
  final Uint8List bytes;
  final Timer timer;
  final DateTime expiresAt;
}
