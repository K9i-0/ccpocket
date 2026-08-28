import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../file_transfer_downloader.dart';
import 'file_transfer_state.dart';

Uri? resolveFileDownloadUrl(String? httpBaseUrl, String downloadUrl) {
  final base = httpBaseUrl == null ? null : Uri.tryParse(httpBaseUrl);
  final uri = Uri.tryParse(downloadUrl);
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
  final capabilityPath = RegExp(r'^/api/media/[a-f0-9]{48}$')
      .hasMatch(resolved.path);
  if (!sameOrigin ||
      !capabilityPath ||
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

class FileTransferCubit extends Cubit<FileTransferState> {
  final BridgeService bridge;
  final FileTransferDownloader _downloader;
  final String Function() _requestIdFactory;
  final Duration requestTimeout;

  bool _cancelled = false;
  StreamSubscription<ServerMessage>? _responseSubscription;
  Timer? _responseTimer;
  Completer<ServerMessage>? _responseCompleter;

  FileTransferCubit({
    required this.bridge,
    FileTransferDownloader? downloader,
    String Function()? requestIdFactory,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _downloader = downloader ?? FileTransferDownloader(),
       _requestIdFactory = requestIdFactory ?? const Uuid().v4,
       super(const FileTransferState.idle());

  Future<void> start({
    required String projectPath,
    required String filePath,
  }) async {
    if (state is FileTransferPreparing || state is FileTransferDownloading) {
      return;
    }
    _cancelled = false;
    emit(const FileTransferState.preparing());
    final requestId = _requestIdFactory();

    try {
      final ready = await _prepareDownload(
        projectPath: projectPath,
        filePath: filePath,
        requestId: requestId,
      );
      if (_cancelled) return;
      final url = resolveFileDownloadUrl(bridge.httpBaseUrl, ready.downloadUrl);
      if (url == null) {
        throw const FileTransferDownloadException(
          'invalid_download_url',
          'The Bridge returned an invalid download URL.',
        );
      }
      final localPath = await _downloader.download(
        url: url,
        requestId: requestId,
        fileName: ready.fileName,
        expectedSizeBytes: ready.sizeBytes,
        onProgress: (receivedBytes, totalBytes) {
          if (_cancelled || isClosed) return;
          emit(
            FileTransferState.downloading(
              receivedBytes: receivedBytes,
              totalBytes: totalBytes,
            ),
          );
        },
      );
      if (_cancelled || isClosed) return;
      emit(
        FileTransferState.ready(
          localPath: localPath,
          fileName: ready.fileName,
          mimeType: ready.mimeType,
          sizeBytes: ready.sizeBytes,
        ),
      );
    } on FileTransferDownloadException catch (error) {
      if (_cancelled || isClosed) return;
      emit(
        FileTransferState.failed(errorCode: error.code, message: error.message),
      );
    } on TimeoutException {
      if (_cancelled || isClosed) return;
      emit(
        const FileTransferState.failed(
          errorCode: 'request_timeout',
          message: 'The Bridge did not respond in time.',
        ),
      );
    } catch (error) {
      if (_cancelled || isClosed) return;
      emit(
        FileTransferState.failed(
          errorCode: 'download_failed',
          message: 'The file could not be downloaded: $error',
        ),
      );
    }
  }

  Future<FileDownloadReadyMessage> _prepareDownload({
    required String projectPath,
    required String filePath,
    required String requestId,
  }) async {
    final completer = Completer<ServerMessage>();
    _responseCompleter = completer;
    _responseSubscription = bridge.messages.listen(
      (message) {
        if (_isMatchingResponse(message, requestId) && !completer.isCompleted) {
          completer.complete(message);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    _responseTimer = Timer(requestTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('The Bridge did not respond in time.'),
        );
      }
    });
    bridge.send(
      ClientMessage.prepareFileDownload(
        projectPath: projectPath,
        filePath: filePath,
        requestId: requestId,
      ),
    );

    try {
      return switch (await completer.future) {
        final FileDownloadReadyMessage ready => ready,
        ErrorMessage(
          errorCode: 'unsupported_message',
          message: 'prepare_file_download',
        ) =>
          throw const FileTransferDownloadException(
            'bridge_update_required',
            'Update the Bridge to download files.',
          ),
        ErrorMessage(errorCode: null, message: 'Invalid message format') =>
          throw const FileTransferDownloadException(
            'bridge_update_required',
            'Update the Bridge to download files.',
          ),
        final ErrorMessage error => throw FileTransferDownloadException(
          error.errorCode ?? 'download_failed',
          error.message,
        ),
        _ => throw const FileTransferDownloadException(
          'download_failed',
          'The Bridge returned an unexpected response.',
        ),
      };
    } finally {
      _clearPendingResponse(completer);
    }
  }

  void _clearPendingResponse(Completer<ServerMessage> completer) {
    if (!identical(_responseCompleter, completer)) return;
    _responseTimer?.cancel();
    _responseTimer = null;
    final subscription = _responseSubscription;
    _responseSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _responseCompleter = null;
  }

  void _cancelPendingResponse() {
    final completer = _responseCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        const FileTransferDownloadException(
          'cancelled',
          'The file transfer was cancelled.',
        ),
      );
    }
  }

  bool _isMatchingResponse(ServerMessage message, String requestId) {
    return switch (message) {
      FileDownloadReadyMessage(requestId: final value) => value == requestId,
      ErrorMessage(
        errorCode: 'unsupported_message',
        message: 'prepare_file_download',
      ) =>
        true,
      ErrorMessage(errorCode: null, message: 'Invalid message format') => true,
      ErrorMessage(requestId: final value) => value == requestId,
      _ => false,
    };
  }

  void cancel() {
    if (_cancelled || isClosed) return;
    _cancelled = true;
    _cancelPendingResponse();
    _downloader.cancel();
    emit(const FileTransferState.cancelled());
  }

  Future<void> cleanup() => _downloader.cleanup();

  Future<void> markShareFailed() async {
    await _downloader.cleanup();
    if (isClosed) return;
    emit(
      const FileTransferState.failed(
        errorCode: 'share_failed',
        message: 'The platform share sheet could not be opened.',
      ),
    );
  }

  @override
  Future<void> close() async {
    _cancelled = true;
    _cancelPendingResponse();
    _downloader.cancel();
    await _downloader.cleanup();
    return super.close();
  }
}
