import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/file_transfer/file_transfer_downloader.dart';
import 'package:ccpocket/features/file_transfer/state/file_transfer_cubit.dart';
import 'package:ccpocket/features/file_transfer/state/file_transfer_state.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestBridgeService extends BridgeService {
  final controller = StreamController<ServerMessage>.broadcast();
  final sentMessages = <ClientMessage>[];

  @override
  Stream<ServerMessage> get messages => controller.stream;

  @override
  String? get httpBaseUrl => 'http://bridge.local:8765';

  @override
  void send(ClientMessage message) => sentMessages.add(message);

  void emit(ServerMessage message) => controller.add(message);

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

class _TestDownloader extends FileTransferDownloader {
  bool cancelled = false;
  bool cleanedUp = false;

  @override
  Future<String> download({
    required Uri url,
    required String requestId,
    required String fileName,
    required int expectedSizeBytes,
    required FileTransferProgress onProgress,
  }) async {
    expect(
      url.toString(),
      'http://bridge.local:8765/api/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    onProgress(5, 10);
    onProgress(10, 10);
    return '/tmp/$fileName';
  }

  @override
  void cancel() => cancelled = true;

  @override
  Future<void> cleanup() async => cleanedUp = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('resolves relative and absolute download URLs safely', () {
    expect(
      resolveFileDownloadUrl(
        'http://localhost:8765',
        '/api/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ).toString(),
      'http://localhost:8765/api/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    expect(
      resolveFileDownloadUrl(
        'http://localhost:8765',
        'http://localhost:8765/api/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ).toString(),
      'http://localhost:8765/api/media/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
    expect(
      resolveFileDownloadUrl(
        'http://localhost:8765',
        'https://example.com/api/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      isNull,
    );
    expect(
      resolveFileDownloadUrl('http://localhost:8765', 'file:///private'),
      isNull,
    );
  });

  test('prepares, downloads, and exposes a share-ready file', () async {
    final bridge = _TestBridgeService();
    final downloader = _TestDownloader();
    final cubit = FileTransferCubit(
      bridge: bridge,
      downloader: downloader,
      requestIdFactory: () => 'download-1',
    );
    addTearDown(() async {
      await cubit.close();
      bridge.dispose();
    });
    final states = <FileTransferState>[];
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);

    final startFuture = cubit.start(
      projectPath: '/project',
      filePath: 'build/report.pdf',
    );
    await Future<void>.delayed(Duration.zero);
    expect(jsonDecode(bridge.sentMessages.single.toJson()), {
      'type': 'prepare_file_download',
      'projectPath': '/project',
      'filePath': 'build/report.pdf',
      'requestId': 'download-1',
    });
    bridge.emit(
      const FileDownloadReadyMessage(
        requestId: 'download-1',
        filePath: 'build/report.pdf',
        fileName: 'report.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 10,
        downloadUrl:
            '/api/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    );
    await startFuture;
    await Future<void>.delayed(Duration.zero);

    expect(states.first, isA<FileTransferPreparing>());
    expect(
      states.whereType<FileTransferDownloading>().map(
        (state) => state.receivedBytes,
      ),
      [5, 10],
    );
    final ready = cubit.state as FileTransferReady;
    expect(ready.localPath, '/tmp/report.pdf');
    expect(ready.mimeType, 'application/pdf');
  });

  test('surfaces Bridge errors and update requirements', () async {
    final bridge = _TestBridgeService();
    final cubit = FileTransferCubit(
      bridge: bridge,
      downloader: _TestDownloader(),
      requestIdFactory: () => 'download-2',
    );
    addTearDown(() async {
      await cubit.close();
      bridge.dispose();
    });

    final failedFuture = cubit.start(
      projectPath: '/project',
      filePath: 'missing.zip',
    );
    await Future<void>.delayed(Duration.zero);
    bridge.emit(
      const ErrorMessage(
        message: 'File not found.',
        errorCode: 'file_download_not_found',
        requestId: 'download-2',
      ),
    );
    await failedFuture;
    expect(
      (cubit.state as FileTransferFailed).errorCode,
      'file_download_not_found',
    );

    final unsupportedFuture = cubit.start(
      projectPath: '/project',
      filePath: 'missing.zip',
    );
    await Future<void>.delayed(Duration.zero);
    bridge.emit(
      const ErrorMessage(
        message: 'prepare_file_download',
        errorCode: 'unsupported_message',
      ),
    );
    await unsupportedFuture;
    expect(
      (cubit.state as FileTransferFailed).errorCode,
      'bridge_update_required',
    );

    final legacyUnsupportedFuture = cubit.start(
      projectPath: '/project',
      filePath: 'missing.zip',
    );
    await Future<void>.delayed(Duration.zero);
    bridge.emit(const ErrorMessage(message: 'Invalid message format'));
    await legacyUnsupportedFuture;
    expect(
      (cubit.state as FileTransferFailed).errorCode,
      'bridge_update_required',
    );
  });
}
