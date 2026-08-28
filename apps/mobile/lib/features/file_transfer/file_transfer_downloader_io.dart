import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef FileTransferProgress = void Function(int receivedBytes, int totalBytes);

class FileTransferDownloadException implements Exception {
  final String code;
  final String message;

  const FileTransferDownloadException(this.code, this.message);

  @override
  String toString() => message;
}

class FileTransferDownloader {
  final http.Client Function() _clientFactory;
  final Future<Directory> Function() _temporaryDirectory;

  http.Client? _client;
  File? _activeFile;
  Directory? _activeDirectory;
  bool _cancelled = false;

  FileTransferDownloader({
    http.Client Function()? clientFactory,
    Future<Directory> Function()? temporaryDirectory,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  Future<String> download({
    required Uri url,
    required String requestId,
    required String fileName,
    required int expectedSizeBytes,
    required FileTransferProgress onProgress,
  }) async {
    _cancelled = false;
    final file = await _createTargetFile(requestId, fileName);
    _activeFile = file;
    if (_cancelled) {
      await _deleteActiveFile();
      throw const FileTransferDownloadException(
        'cancelled',
        'The download was cancelled.',
      );
    }
    final client = _clientFactory();
    _client = client;

    try {
      final request = http.Request('GET', url)..followRedirects = false;
      final response = await client.send(request);
      if (response.statusCode != HttpStatus.ok) {
        throw FileTransferDownloadException(
          'http_${response.statusCode}',
          'The Bridge returned HTTP ${response.statusCode}.',
        );
      }
      final contentLength = response.contentLength;
      if (expectedSizeBytes < 0 ||
          (contentLength != null && contentLength != expectedSizeBytes)) {
        throw const FileTransferDownloadException(
          'size_mismatch',
          'The download size does not match the file prepared by the Bridge.',
        );
      }
      return await _writeResponse(
        response,
        file,
        expectedSizeBytes: expectedSizeBytes,
        onProgress: onProgress,
      );
    } on FileTransferDownloadException {
      await _deleteActiveFile();
      rethrow;
    } catch (error) {
      await _deleteActiveFile();
      if (_cancelled) {
        throw const FileTransferDownloadException(
          'cancelled',
          'The download was cancelled.',
        );
      }
      throw FileTransferDownloadException(
        'download_failed',
        'The file could not be downloaded: $error',
      );
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  Future<String> _writeResponse(
    http.StreamedResponse response,
    File file, {
    required int expectedSizeBytes,
    required FileTransferProgress onProgress,
  }) async {
    final totalBytes = expectedSizeBytes;
    var receivedBytes = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        if (_cancelled) {
          throw const FileTransferDownloadException(
            'cancelled',
            'The download was cancelled.',
          );
        }
        if (receivedBytes + chunk.length > expectedSizeBytes) {
          throw const FileTransferDownloadException(
            'size_mismatch',
            'The download exceeded the size prepared by the Bridge.',
          );
        }
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress(receivedBytes, totalBytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (_cancelled) {
      throw const FileTransferDownloadException(
        'cancelled',
        'The download was cancelled.',
      );
    }
    if (receivedBytes != expectedSizeBytes) {
      throw const FileTransferDownloadException(
        'incomplete_download',
        'The download ended before the complete file was received.',
      );
    }
    return file.path;
  }

  Future<File> _createTargetFile(String requestId, String fileName) async {
    final root = await _temporaryDirectory();
    final transferDirectory = Directory(
      path.join(
        root.path,
        'ccpocket-file-transfers',
        requestId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_'),
      ),
    );
    if (await transferDirectory.exists()) {
      await transferDirectory.delete(recursive: true);
    }
    await transferDirectory.create(recursive: true);
    _activeDirectory = transferDirectory;
    final safeName = path.basename(fileName.trim());
    final name = safeName.isEmpty ? 'download' : safeName;
    return File(path.join(transferDirectory.path, name));
  }

  void cancel() {
    _cancelled = true;
    _client?.close();
  }

  Future<void> cleanup() => _deleteActiveFile();

  Future<void> _deleteActiveFile() async {
    final file = _activeFile;
    _activeFile = null;
    final directory = _activeDirectory;
    _activeDirectory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    } else if (file != null && await file.exists()) {
      await file.delete();
    }
  }
}
