import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_transfer_state.freezed.dart';

@freezed
sealed class FileTransferState with _$FileTransferState {
  const factory FileTransferState.idle() = FileTransferIdle;

  const factory FileTransferState.preparing() = FileTransferPreparing;

  const factory FileTransferState.downloading({
    required int receivedBytes,
    required int totalBytes,
  }) = FileTransferDownloading;

  const factory FileTransferState.ready({
    required String localPath,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) = FileTransferReady;

  const factory FileTransferState.failed({
    required String errorCode,
    required String message,
  }) = FileTransferFailed;

  const factory FileTransferState.cancelled() = FileTransferCancelled;
}
