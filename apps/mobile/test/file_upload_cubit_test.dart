import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/file_upload/file_upload_transport.dart';
import 'package:ccpocket/features/file_upload/state/file_upload_cubit.dart';
import 'package:ccpocket/features/file_upload/state/file_upload_state.dart';
import 'package:ccpocket/features/file_upload/widgets/file_upload_dialog.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

class _TestTransport extends FileUploadTransport {
  final List<String> uploadedFiles = [];
  bool cancelled = false;

  @override
  Future<FileUploadTransportResult> upload({
    required Uri url,
    required XFile file,
    required int expectedSizeBytes,
    required FileUploadProgress onProgress,
  }) async {
    expect(
      url.toString(),
      'http://bridge.local:8765/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    uploadedFiles.add(file.name);
    onProgress(expectedSizeBytes, expectedSizeBytes);
    return FileUploadTransportResult(
      sha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      sentBytes: expectedSizeBytes,
    );
  }

  @override
  void cancel() => cancelled = true;
}

XFile _testFile(String name) => XFile(p.join('tmp', name));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('resolves only same-origin upload capability URLs', () {
    expect(
      resolveFileUploadUrl(
        'http://localhost:8765',
        '/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ).toString(),
      'http://localhost:8765/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    expect(
      resolveFileUploadUrl(
        'http://localhost:8765',
        'http://example.com/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      isNull,
    );
    expect(
      resolveFileUploadUrl(
        'http://localhost:8765',
        '/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa?token=x',
      ),
      isNull,
    );
  });

  test('prepares, streams, finalizes, and records the uploaded path', () async {
    final bridge = _TestBridgeService();
    final transport = _TestTransport();
    final file = _testFile('report.txt');
    final cubit = FileUploadCubit(
      bridge: bridge,
      projectPath: '/project',
      directoryPath: 'docs',
      files: [file],
      fileSizes: const [5],
      transport: transport,
      requestIdFactory: () => 'upload-1',
    );
    addTearDown(() async {
      await cubit.close();
      bridge.dispose();
    });

    final upload = cubit.start();
    await Future<void>.delayed(Duration.zero);
    expect(jsonDecode(bridge.sentMessages.single.toJson()), {
      'type': 'prepare_file_upload',
      'projectPath': '/project',
      'directoryPath': 'docs',
      'fileName': 'report.txt',
      'sizeBytes': 5,
      'conflictPolicy': 'rename',
      'requestId': 'upload-1',
    });
    bridge.emit(
      const FileUploadReadyMessage(
        requestId: 'upload-1',
        fileName: 'report.txt',
        sizeBytes: 5,
        uploadUrl:
            '/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        uploadToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final finalize = jsonDecode(bridge.sentMessages.last.toJson());
    expect(finalize, {
      'type': 'finalize_file_upload',
      'uploadToken': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'sha256':
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      'requestId': 'upload-1',
    });
    bridge.emit(
      const FileUploadCompleteMessage(
        requestId: 'upload-1',
        filePath: 'docs/report.txt',
        fileName: 'report.txt',
        sizeBytes: 5,
        sha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        skipped: false,
      ),
    );
    await upload;

    expect(cubit.state.isComplete, isTrue);
    expect(cubit.state.items.single.status, FileUploadItemStatus.complete);
    expect(cubit.uploadedPaths, ['docs/report.txt']);
  });

  test(
    'surfaces old Bridge guidance and cancels active HTTP uploads',
    () async {
      final bridge = _TestBridgeService();
      final transport = _TestTransport();
      final cubit = FileUploadCubit(
        bridge: bridge,
        projectPath: '/project',
        directoryPath: '',
        files: [_testFile('one.bin')],
        fileSizes: const [1],
        transport: transport,
        requestIdFactory: () => 'upload-2',
      );
      addTearDown(() async {
        await cubit.close();
        bridge.dispose();
      });

      final upload = cubit.start();
      await Future<void>.delayed(Duration.zero);
      bridge.emit(
        const ErrorMessage(
          message: 'prepare_file_upload',
          errorCode: 'unsupported_message',
        ),
      );
      await upload;
      expect(cubit.state.items.single.errorCode, 'bridge_update_required');

      cubit.cancel();
      expect(transport.cancelled, isTrue);
      expect(cubit.state.isCancelled, isTrue);
    },
  );

  testWidgets('shows current destination and defaults conflicts to keep both', (
    tester,
  ) async {
    final bridge = _TestBridgeService();
    final cubit = FileUploadCubit(
      bridge: bridge,
      projectPath: '/project',
      directoryPath: 'docs',
      files: [_testFile('report.pdf')],
      fileSizes: const [1024],
      transport: _TestTransport(),
    );
    addTearDown(() async {
      await cubit.close();
      bridge.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(
            body: FileUploadDialog(
              directoryPath: 'docs',
              projectName: 'project',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Destination: project/docs'), findsOneWidget);
    expect(find.text('Keep both'), findsOneWidget);
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isFalse,
    );
    expect(
      find.byKey(const ValueKey('file_upload_start_button')),
      findsOneWidget,
    );
  });

  test(
    'cancel completes immediately while waiting for Bridge preparation',
    () async {
      final bridge = _TestBridgeService();
      final cubit = FileUploadCubit(
        bridge: bridge,
        projectPath: '/project',
        directoryPath: '',
        files: [_testFile('pending.bin')],
        fileSizes: const [1],
        requestTimeout: const Duration(seconds: 10),
      );
      addTearDown(() async {
        await cubit.close();
        bridge.dispose();
      });

      final upload = cubit.start();
      await Future<void>.delayed(Duration.zero);
      cubit.cancel();
      await upload.timeout(const Duration(seconds: 1));

      expect(cubit.state.isCancelled, isTrue);
    },
  );

  test(
    'rejects ready metadata that does not match the selected file',
    () async {
      final bridge = _TestBridgeService();
      final transport = _TestTransport();
      final cubit = FileUploadCubit(
        bridge: bridge,
        projectPath: '/project',
        directoryPath: '',
        files: [_testFile('one.bin')],
        fileSizes: const [1],
        transport: transport,
        requestIdFactory: () => 'upload-metadata',
      );
      addTearDown(() async {
        await cubit.close();
        bridge.dispose();
      });

      final upload = cubit.start();
      await Future<void>.delayed(Duration.zero);
      bridge.emit(
        const FileUploadReadyMessage(
          requestId: 'upload-metadata',
          fileName: 'other.bin',
          sizeBytes: 1,
          uploadUrl:
              '/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          uploadToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      );
      await upload;

      expect(transport.uploadedFiles, isEmpty);
      expect(cubit.state.items.single.errorCode, 'invalid_upload_response');
      expect(
        bridge.sentMessages.map(
          (message) => jsonDecode(message.toJson())['type'],
        ),
        contains('cancel_file_upload'),
      );
    },
  );

  test('rejects completion metadata with a different digest', () async {
    final bridge = _TestBridgeService();
    final cubit = FileUploadCubit(
      bridge: bridge,
      projectPath: '/project',
      directoryPath: 'docs',
      files: [_testFile('one.bin')],
      fileSizes: const [1],
      transport: _TestTransport(),
      requestIdFactory: () => 'upload-integrity',
    );
    addTearDown(() async {
      await cubit.close();
      bridge.dispose();
    });

    final upload = cubit.start();
    await Future<void>.delayed(Duration.zero);
    bridge.emit(
      const FileUploadReadyMessage(
        requestId: 'upload-integrity',
        fileName: 'one.bin',
        sizeBytes: 1,
        uploadUrl:
            '/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        uploadToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    bridge.emit(
      const FileUploadCompleteMessage(
        requestId: 'upload-integrity',
        filePath: 'docs/one.bin',
        fileName: 'one.bin',
        sizeBytes: 1,
        sha256: 'different',
        skipped: false,
      ),
    );
    await upload;

    expect(cubit.state.items.single.errorCode, 'file_upload_integrity_failed');
    expect(
      bridge.sentMessages.map(
        (message) => jsonDecode(message.toJson())['type'],
      ),
      contains('cancel_file_upload'),
    );
  });

  test('retries finalization with the same capability after a timeout', () async {
    final bridge = _TestBridgeService();
    final cubit = FileUploadCubit(
      bridge: bridge,
      projectPath: '/project',
      directoryPath: '',
      files: [_testFile('one.bin')],
      fileSizes: const [1],
      transport: _TestTransport(),
      requestIdFactory: () => 'upload-retry-finalize',
      requestTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(() async {
      await cubit.close();
      bridge.dispose();
    });

    final upload = cubit.start();
    await Future<void>.delayed(Duration.zero);
    bridge.emit(
      const FileUploadReadyMessage(
        requestId: 'upload-retry-finalize',
        fileName: 'one.bin',
        sizeBytes: 1,
        uploadUrl:
            '/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        uploadToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 45));
    final finalizeMessages = bridge.sentMessages
        .map((message) => jsonDecode(message.toJson()) as Map<String, dynamic>)
        .where((message) => message['type'] == 'finalize_file_upload')
        .toList();
    expect(finalizeMessages, hasLength(2));
    expect(finalizeMessages.map((message) => message['uploadToken']).toSet(), {
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    });
    bridge.emit(
      const FileUploadCompleteMessage(
        requestId: 'upload-retry-finalize',
        filePath: 'one.bin',
        fileName: 'one.bin',
        sizeBytes: 1,
        sha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        skipped: false,
      ),
    );
    await upload;

    expect(cubit.state.isComplete, isTrue);
  });
}
