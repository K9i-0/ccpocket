import 'dart:async';
import 'dart:io';

/// A preview-owned copy: seeking never needs HTTP once preparation succeeds.
/// Do not infer local filesystem access from a loopback URL (SSH tunnels can
/// also use loopback). Always obtain bytes through the Bridge capability URL.
class LocalMediaSnapshot {
  final int maxBytes;
  final Duration timeout;
  final bool enabled;
  HttpClient? _client;
  Directory? _directory;
  Future<String>? _preparation;
  bool _disposed = false;

  LocalMediaSnapshot({
    this.maxBytes = 128 * 1024 * 1024,
    this.timeout = const Duration(seconds: 3),
    bool? enabled,
  }) : enabled =
           enabled ??
           (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  Future<String> prepare(String url) => _preparation ??= _prepare(url);

  Future<String> _prepare(String url) async {
    final uri = Uri.tryParse(url);
    if (_disposed || !enabled || uri == null || !_isLoopbackHttp(uri)) {
      return url;
    }
    final client = _client = HttpClient();
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      client.close(force: true);
    });
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close();
      final length = response.contentLength;
      // Require a bounded, complete response. Large files remain streamed.
      if (response.statusCode != HttpStatus.ok ||
          length <= 0 ||
          length > maxBytes ||
          timedOut ||
          _disposed) {
        return url;
      }
      _directory = await Directory.systemTemp.createTemp('ccpocket-media-');
      final file = File('${_directory!.path}/preview');
      final sink = file.openWrite();
      var received = 0;
      try {
        await sink.addStream(
          response.map((chunk) {
            received += chunk.length;
            if (_disposed || timedOut || received > length) {
              throw const HttpException('Media snapshot cancelled');
            }
            return chunk;
          }),
        );
      } finally {
        await sink.close();
      }
      if (!_disposed && !timedOut && received == length) {
        return file.uri.toString();
      }
    } catch (_) {
      // Download, timeout and disk failures retain ordinary HTTP playback.
    } finally {
      timer.cancel();
      client.close(force: true);
      _client = null;
    }
    await _deleteDirectory();
    return url;
  }

  Future<void> dispose() async {
    _disposed = true;
    _client?.close(force: true);
    await _preparation;
    await _deleteDirectory();
  }

  Future<void> _deleteDirectory() async {
    final directory = _directory;
    _directory = null;
    try {
      await directory?.delete(recursive: true);
    } on FileSystemException {
      // OS temp cleanup remains a fallback if deletion is unavailable.
    }
  }
}

bool _isLoopbackHttp(Uri uri) {
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  final host = uri.host.replaceAll('[', '').replaceAll(']', '');
  return host.toLowerCase() == 'localhost' ||
      (InternetAddress.tryParse(host)?.isLoopback ?? false);
}
