typedef FileTransferProgress = void Function(int receivedBytes, int totalBytes);

class FileTransferDownloadException implements Exception {
  final String code;
  final String message;

  const FileTransferDownloadException(this.code, this.message);

  @override
  String toString() => message;
}

class FileTransferDownloader {
  FileTransferDownloader({
    Object Function()? clientFactory,
    Future<Object> Function()? temporaryDirectory,
  });

  Future<String> download({
    required Uri url,
    required String requestId,
    required String fileName,
    required int expectedSizeBytes,
    required FileTransferProgress onProgress,
  }) {
    return Future.error(
      const FileTransferDownloadException(
        'unsupported_platform',
        'File sharing is unavailable on this platform.',
      ),
    );
  }

  void cancel() {}

  Future<void> cleanup() async {}
}
