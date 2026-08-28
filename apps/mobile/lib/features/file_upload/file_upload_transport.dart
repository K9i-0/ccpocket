import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;

typedef FileUploadProgress = void Function(int sentBytes, int totalBytes);

class FileUploadException implements Exception {
  final String code;
  final String message;

  const FileUploadException(this.code, this.message);

  @override
  String toString() => message;
}

class FileUploadTransportResult {
  final String sha256;
  final int sentBytes;

  const FileUploadTransportResult({
    required this.sha256,
    required this.sentBytes,
  });
}

Uri? resolveFileUploadUrl(String? httpBaseUrl, String uploadUrl) {
  final base = httpBaseUrl == null ? null : Uri.tryParse(httpBaseUrl);
  final uri = Uri.tryParse(uploadUrl);
  if (base == null ||
      uri == null ||
      (base.scheme != 'http' && base.scheme != 'https')) {
    return null;
  }
  final resolved = base.resolveUri(uri);
  final sameOrigin =
      resolved.scheme == base.scheme &&
      resolved.host == base.host &&
      _effectivePort(resolved) == _effectivePort(base);
  if (!sameOrigin ||
      !RegExp(r'^/api/uploads/[a-f0-9]{48}$').hasMatch(resolved.path) ||
      resolved.userInfo.isNotEmpty ||
      resolved.hasQuery ||
      resolved.hasFragment) {
    return null;
  }
  return resolved;
}

int _effectivePort(Uri uri) => uri.hasPort
    ? uri.port
    : switch (uri.scheme) {
        'https' => 443,
        _ => 80,
      };

class FileUploadTransport {
  final http.Client Function() _clientFactory;
  http.Client? _client;
  bool _cancelled = false;

  FileUploadTransport({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  Future<FileUploadTransportResult> upload({
    required Uri url,
    required XFile file,
    required int expectedSizeBytes,
    required FileUploadProgress onProgress,
  }) async {
    _cancelled = false;
    final client = _clientFactory();
    _client = client;
    final digestSink = _DigestSink();
    final hashSink = sha256.startChunkedConversion(digestSink);
    var sentBytes = 0;

    try {
      final request = http.StreamedRequest('PUT', url)
        ..followRedirects = false
        ..contentLength = expectedSizeBytes;
      final responseFuture = client.send(request);
      final writeFuture = () async {
        try {
          await request.sink.addStream(
            file.openRead().map((chunk) {
              if (_cancelled) {
                throw const FileUploadException(
                  'cancelled',
                  'The upload was cancelled.',
                );
              }
              sentBytes += chunk.length;
              if (sentBytes > expectedSizeBytes) {
                throw const FileUploadException(
                  'size_mismatch',
                  'The selected file changed while it was being uploaded.',
                );
              }
              hashSink.add(chunk);
              onProgress(sentBytes, expectedSizeBytes);
              return chunk;
            }),
          );
        } finally {
          await request.sink.close();
        }
      }();
      final completed = await Future.wait<Object?>([
        writeFuture,
        responseFuture,
      ]);
      hashSink.close();
      final response = completed[1]! as http.StreamedResponse;
      await response.stream.drain<void>();
      if (_cancelled) {
        throw const FileUploadException(
          'cancelled',
          'The upload was cancelled.',
        );
      }
      if (sentBytes != expectedSizeBytes) {
        throw const FileUploadException(
          'size_mismatch',
          'The selected file changed while it was being uploaded.',
        );
      }
      if (response.statusCode != 201) {
        throw FileUploadException(
          'http_${response.statusCode}',
          'The Bridge returned HTTP ${response.statusCode}.',
        );
      }
      final localSha256 = digestSink.value!.toString();
      final receivedBytes = int.tryParse(
        response.headers['x-received-bytes'] ?? '',
      );
      final bridgeSha256 = response.headers['x-file-sha256'];
      if (receivedBytes != expectedSizeBytes || bridgeSha256 != localSha256) {
        throw const FileUploadException(
          'integrity_failed',
          'The uploaded file failed integrity verification.',
        );
      }
      return FileUploadTransportResult(
        sha256: localSha256,
        sentBytes: sentBytes,
      );
    } on FileUploadException {
      rethrow;
    } catch (error) {
      if (_cancelled) {
        throw const FileUploadException(
          'cancelled',
          'The upload was cancelled.',
        );
      }
      throw FileUploadException(
        'upload_failed',
        'The file could not be uploaded: $error',
      );
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  void cancel() {
    _cancelled = true;
    _client?.close();
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
