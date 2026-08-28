import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../file_upload_transport.dart';
import 'file_upload_state.dart';

class FileUploadCubit extends Cubit<FileUploadState> {
  final BridgeService bridge;
  final String projectPath;
  final String directoryPath;
  final FileUploadTransport _transport;
  final String Function() _requestIdFactory;
  final Duration requestTimeout;
  final Map<String, XFile> _files;

  String? _activeUploadToken;
  bool _cancelled = false;
  StreamSubscription<ServerMessage>? _responseSubscription;
  Timer? _responseTimer;
  Completer<ServerMessage>? _responseCompleter;

  FileUploadCubit({
    required this.bridge,
    required this.projectPath,
    required this.directoryPath,
    required List<XFile> files,
    required List<int> fileSizes,
    FileUploadTransport? transport,
    String Function()? requestIdFactory,
    this.requestTimeout = const Duration(seconds: 20),
  }) : assert(files.length == fileSizes.length),
       _transport = transport ?? FileUploadTransport(),
       _requestIdFactory = requestIdFactory ?? const Uuid().v4,
       _files = {
         for (var index = 0; index < files.length; index++)
           '$index-${files[index].name}': files[index],
       },
       super(
         FileUploadState(
           items: [
             for (var index = 0; index < files.length; index++)
               FileUploadItemState(
                 id: '$index-${files[index].name}',
                 fileName: files[index].name,
                 sizeBytes: fileSizes[index],
               ),
           ],
         ),
       );

  void setConflictPolicy(FileUploadConflictPolicy policy) {
    if (state.isRunning) return;
    emit(state.copyWith(conflictPolicy: policy));
  }

  Future<void> start() async {
    if (state.isRunning || state.isComplete) return;
    _cancelled = false;
    emit(
      state.copyWith(isRunning: true, isCancelled: false, errorMessage: null),
    );

    for (final item in List<FileUploadItemState>.from(state.items)) {
      final current = _item(item.id);
      if (current.status == FileUploadItemStatus.complete ||
          current.status == FileUploadItemStatus.skipped) {
        continue;
      }
      if (_cancelled) return;
      try {
        await _uploadItem(current);
      } on FileUploadException catch (error) {
        _cancelActiveCapability();
        if (_cancelled || isClosed) return;
        _updateItem(
          current.id,
          (value) => value.copyWith(
            status: FileUploadItemStatus.failed,
            errorCode: error.code,
          ),
        );
        emit(state.copyWith(isRunning: false, errorMessage: error.message));
        return;
      } on TimeoutException {
        _cancelActiveCapability();
        if (_cancelled || isClosed) return;
        _updateItem(
          current.id,
          (value) => value.copyWith(
            status: FileUploadItemStatus.failed,
            errorCode: 'request_timeout',
          ),
        );
        emit(
          state.copyWith(
            isRunning: false,
            errorMessage: 'The Bridge did not respond in time.',
          ),
        );
        return;
      } catch (error) {
        _cancelActiveCapability();
        if (_cancelled || isClosed) return;
        _updateItem(
          current.id,
          (value) => value.copyWith(
            status: FileUploadItemStatus.failed,
            errorCode: 'upload_failed',
          ),
        );
        emit(
          state.copyWith(
            isRunning: false,
            errorMessage: 'The file could not be uploaded: $error',
          ),
        );
        return;
      }
    }

    if (!_cancelled && !isClosed) {
      emit(state.copyWith(isRunning: false, isComplete: true));
    }
  }

  Future<void> _uploadItem(FileUploadItemState item) async {
    final file = _files[item.id]!;
    final requestId = _requestIdFactory();
    _updateItem(
      item.id,
      (value) => value.copyWith(
        status: FileUploadItemStatus.preparing,
        sentBytes: 0,
        errorCode: null,
      ),
    );
    final ready = await _prepare(item, requestId);
    _activeUploadToken = ready.uploadToken;
    if (ready.fileName != item.fileName || ready.sizeBytes != item.sizeBytes) {
      throw const FileUploadException(
        'invalid_upload_response',
        'The Bridge returned upload metadata that does not match the file.',
      );
    }
    if (_cancelled) {
      _cancelActiveCapability();
      return;
    }
    final url = resolveFileUploadUrl(bridge.httpBaseUrl, ready.uploadUrl);
    if (url == null) {
      throw const FileUploadException(
        'invalid_upload_url',
        'The Bridge returned an invalid upload URL.',
      );
    }
    if (url.pathSegments.isEmpty ||
        url.pathSegments.last != ready.uploadToken) {
      throw const FileUploadException(
        'invalid_upload_response',
        'The Bridge returned mismatched upload capabilities.',
      );
    }
    _updateItem(
      item.id,
      (value) => value.copyWith(status: FileUploadItemStatus.uploading),
    );
    final transferred = await _transport.upload(
      url: url,
      file: file,
      expectedSizeBytes: item.sizeBytes,
      onProgress: (sent, _) {
        if (_cancelled || isClosed) return;
        _updateItem(item.id, (value) => value.copyWith(sentBytes: sent));
      },
    );
    if (_cancelled) return;
    _updateItem(
      item.id,
      (value) => value.copyWith(status: FileUploadItemStatus.finalizing),
    );
    final complete = await _finalize(
      requestId: requestId,
      uploadToken: ready.uploadToken,
      sha256: transferred.sha256,
    );
    if (!_isValidCompletion(item, complete, transferred.sha256)) {
      throw const FileUploadException(
        'file_upload_integrity_failed',
        'The Bridge returned an upload result that failed verification.',
      );
    }
    _activeUploadToken = null;
    _updateItem(
      item.id,
      (value) => value.copyWith(
        sentBytes: item.sizeBytes,
        status: complete.skipped
            ? FileUploadItemStatus.skipped
            : FileUploadItemStatus.complete,
        uploadedPath: complete.filePath,
      ),
    );
  }

  Future<FileUploadReadyMessage> _prepare(
    FileUploadItemState item,
    String requestId,
  ) async {
    final response = _waitForResponse(
      requestId,
      unsupportedType: 'prepare_file_upload',
    );
    bridge.send(
      ClientMessage.prepareFileUpload(
        projectPath: projectPath,
        directoryPath: directoryPath,
        fileName: item.fileName,
        sizeBytes: item.sizeBytes,
        conflictPolicy: state.conflictPolicy.name,
        requestId: requestId,
      ),
    );
    return switch (await response) {
      final FileUploadReadyMessage ready => ready,
      final ErrorMessage error => throw _errorFromBridge(error),
      _ => throw const FileUploadException(
        'upload_failed',
        'The Bridge returned an unexpected response.',
      ),
    };
  }

  Future<FileUploadCompleteMessage> _finalize({
    required String requestId,
    required String uploadToken,
    required String sha256,
  }) async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        final response = _waitForResponse(
          requestId,
          unsupportedType: 'finalize_file_upload',
        );
        bridge.send(
          ClientMessage.finalizeFileUpload(
            uploadToken: uploadToken,
            sha256: sha256,
            requestId: requestId,
          ),
        );
        return switch (await response) {
          final FileUploadCompleteMessage complete => complete,
          final ErrorMessage error => throw _errorFromBridge(error),
          _ => throw const FileUploadException(
            'upload_failed',
            'The Bridge returned an unexpected response.',
          ),
        };
      } on TimeoutException {
        if (attempt == 1) rethrow;
      }
    }
    throw StateError('Unreachable upload finalization state');
  }

  bool _isValidCompletion(
    FileUploadItemState item,
    FileUploadCompleteMessage complete,
    String transferredSha256,
  ) {
    final segments = directoryPath
        .replaceAll('\\', '/')
        .split('/')
        .where((segment) => segment.isNotEmpty && segment != '.')
        .toList();
    if (segments.contains('..') ||
        complete.fileName.isEmpty ||
        complete.fileName == '.' ||
        complete.fileName == '..' ||
        complete.fileName.contains('/') ||
        complete.fileName.contains('\\')) {
      return false;
    }
    final expectedPath = [...segments, complete.fileName].join('/');
    return complete.filePath == expectedPath &&
        complete.sizeBytes == item.sizeBytes &&
        complete.sha256.toLowerCase() == transferredSha256.toLowerCase();
  }

  Future<ServerMessage> _waitForResponse(
    String requestId, {
    required String unsupportedType,
  }) async {
    final completer = Completer<ServerMessage>();
    _responseCompleter = completer;
    _responseSubscription = bridge.messages.listen((message) {
      final matches = switch (message) {
        FileUploadReadyMessage(requestId: final value) =>
          unsupportedType == 'prepare_file_upload' && value == requestId,
        FileUploadCompleteMessage(requestId: final value) =>
          unsupportedType == 'finalize_file_upload' && value == requestId,
        ErrorMessage(errorCode: 'unsupported_message', message: final value) =>
          value == unsupportedType,
        ErrorMessage(errorCode: null, message: 'Invalid message format') =>
          true,
        ErrorMessage(requestId: final value) => value == requestId,
        _ => false,
      };
      if (matches && !completer.isCompleted) completer.complete(message);
    }, onError: completer.completeError);
    _responseTimer = Timer(requestTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Bridge response timeout'));
      }
    });
    try {
      return await completer.future;
    } finally {
      if (identical(_responseCompleter, completer)) {
        _responseTimer?.cancel();
        _responseTimer = null;
        final subscription = _responseSubscription;
        _responseSubscription = null;
        _responseCompleter = null;
        if (subscription != null) await subscription.cancel();
      }
    }
  }

  FileUploadException _errorFromBridge(ErrorMessage error) {
    if (error.errorCode == 'unsupported_message' ||
        (error.errorCode == null &&
            error.message == 'Invalid message format')) {
      return const FileUploadException(
        'bridge_update_required',
        'Update the Bridge to upload files.',
      );
    }
    return FileUploadException(
      error.errorCode ?? 'upload_failed',
      error.message,
    );
  }

  FileUploadItemState _item(String id) =>
      state.items.firstWhere((item) => item.id == id);

  void _updateItem(
    String id,
    FileUploadItemState Function(FileUploadItemState) update,
  ) {
    if (isClosed) return;
    emit(
      state.copyWith(
        items: [
          for (final item in state.items)
            if (item.id == id) update(item) else item,
        ],
      ),
    );
  }

  void cancel() {
    if (_cancelled || isClosed) return;
    _cancelled = true;
    _transport.cancel();
    _cancelPendingResponse();
    _cancelActiveCapability();
    emit(state.copyWith(isRunning: false, isCancelled: true));
  }

  void _cancelActiveCapability() {
    final token = _activeUploadToken;
    _activeUploadToken = null;
    if (token != null) bridge.send(ClientMessage.cancelFileUpload(token));
  }

  void _cancelPendingResponse() {
    final completer = _responseCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        const FileUploadException('cancelled', 'The upload was cancelled.'),
      );
    }
  }

  List<String> get uploadedPaths => state.items
      .where((item) => item.status == FileUploadItemStatus.complete)
      .map((item) => item.uploadedPath)
      .whereType<String>()
      .toList();

  @override
  Future<void> close() async {
    if (state.isRunning) cancel();
    return super.close();
  }
}
