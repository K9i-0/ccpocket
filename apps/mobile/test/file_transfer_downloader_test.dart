import 'dart:async';
import 'dart:io';

import 'package:ccpocket/features/file_transfer/file_transfer_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _StreamingClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  _StreamingClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'ccpocket-transfer-test-',
    );
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('streams a download to disk and reports incremental progress', () async {
    final progress = <(int, int)>[];
    final downloader = FileTransferDownloader(
      clientFactory: () => _StreamingClient((request) async {
        expect(request.followRedirects, isFalse);
        return http.StreamedResponse(
          Stream.fromIterable([
            [1, 2],
            [3, 4, 5],
          ]),
          200,
          contentLength: 5,
        );
      }),
      temporaryDirectory: () async => tempDirectory,
    );

    final localPath = await downloader.download(
      url: Uri.parse('http://localhost/file'),
      requestId: 'request-1',
      fileName: 'report.pdf',
      expectedSizeBytes: 5,
      onProgress: (received, total) => progress.add((received, total)),
    );

    expect(await File(localPath).readAsBytes(), [1, 2, 3, 4, 5]);
    expect(File(localPath).uri.pathSegments.last, 'report.pdf');
    expect(progress, [(2, 5), (5, 5)]);
    await downloader.cleanup();
    expect(await File(localPath).exists(), isFalse);
  });

  test('deletes an incomplete download', () async {
    final downloader = FileTransferDownloader(
      clientFactory: () => _StreamingClient(
        (_) async =>
            http.StreamedResponse(Stream.value([1, 2]), 200, contentLength: 5),
      ),
      temporaryDirectory: () async => tempDirectory,
    );

    await expectLater(
      downloader.download(
        url: Uri.parse('http://localhost/file'),
        requestId: 'request-2',
        fileName: '../unsafe.zip',
        expectedSizeBytes: 5,
        onProgress: (_, _) {},
      ),
      throwsA(
        isA<FileTransferDownloadException>().having(
          (error) => error.code,
          'code',
          'incomplete_download',
        ),
      ),
    );
    final transferDirectory = Directory(
      '${tempDirectory.path}/ccpocket-file-transfers',
    );
    expect(await transferDirectory.list().toList(), isEmpty);
  });

  test('cancels an active stream and removes the partial file', () async {
    final chunks = StreamController<List<int>>();
    final responseStarted = Completer<void>();
    final downloader = FileTransferDownloader(
      clientFactory: () => _StreamingClient((_) async {
        responseStarted.complete();
        return http.StreamedResponse(chunks.stream, 200, contentLength: 4);
      }),
      temporaryDirectory: () async => tempDirectory,
    );

    final future = downloader.download(
      url: Uri.parse('http://localhost/file'),
      requestId: 'request-3',
      fileName: 'movie.mp4',
      expectedSizeBytes: 4,
      onProgress: (_, _) {},
    );
    await responseStarted.future;
    chunks.add([1, 2]);
    await Future<void>.delayed(Duration.zero);
    downloader.cancel();
    await chunks.close();

    await expectLater(
      future,
      throwsA(
        isA<FileTransferDownloadException>().having(
          (error) => error.code,
          'code',
          'cancelled',
        ),
      ),
    );
    final transferDirectory = Directory(
      '${tempDirectory.path}/ccpocket-file-transfers',
    );
    expect(await transferDirectory.list().toList(), isEmpty);
  });

  test('cancels while the temporary directory is resolving', () async {
    final directoryCompleter = Completer<Directory>();
    var clientCreated = false;
    final downloader = FileTransferDownloader(
      clientFactory: () {
        clientCreated = true;
        return _StreamingClient((_) async {
          fail('The HTTP request must not start after cancellation.');
        });
      },
      temporaryDirectory: () => directoryCompleter.future,
    );

    final future = downloader.download(
      url: Uri.parse('http://localhost/file'),
      requestId: 'request-4',
      fileName: 'audio.wav',
      expectedSizeBytes: 4,
      onProgress: (_, _) {},
    );
    downloader.cancel();
    directoryCompleter.complete(tempDirectory);

    await expectLater(
      future,
      throwsA(
        isA<FileTransferDownloadException>().having(
          (error) => error.code,
          'code',
          'cancelled',
        ),
      ),
    );
    expect(clientCreated, isFalse);
    final transferDirectory = Directory(
      '${tempDirectory.path}/ccpocket-file-transfers',
    );
    expect(await transferDirectory.list().toList(), isEmpty);
  });

  test('stops before writing bytes beyond the prepared size', () async {
    final downloader = FileTransferDownloader(
      clientFactory: () => _StreamingClient(
        (_) async => http.StreamedResponse(Stream.value([1, 2, 3]), 200),
      ),
      temporaryDirectory: () async => tempDirectory,
    );

    await expectLater(
      downloader.download(
        url: Uri.parse('http://localhost/file'),
        requestId: 'request-5',
        fileName: 'oversized.zip',
        expectedSizeBytes: 2,
        onProgress: (_, _) {},
      ),
      throwsA(
        isA<FileTransferDownloadException>().having(
          (error) => error.code,
          'code',
          'size_mismatch',
        ),
      ),
    );
    final transferDirectory = Directory(
      '${tempDirectory.path}/ccpocket-file-transfers',
    );
    expect(await transferDirectory.list().toList(), isEmpty);
  });
}
