import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_upload_state.freezed.dart';

enum FileUploadConflictPolicy { rename, overwrite, skip }

enum FileUploadItemStatus {
  pending,
  preparing,
  uploading,
  finalizing,
  complete,
  skipped,
  failed,
}

@freezed
abstract class FileUploadItemState with _$FileUploadItemState {
  const factory FileUploadItemState({
    required String id,
    required String fileName,
    required int sizeBytes,
    @Default(0) int sentBytes,
    @Default(FileUploadItemStatus.pending) FileUploadItemStatus status,
    String? uploadedPath,
    String? errorCode,
  }) = _FileUploadItemState;
}

@freezed
abstract class FileUploadState with _$FileUploadState {
  const factory FileUploadState({
    @Default([]) List<FileUploadItemState> items,
    @Default(FileUploadConflictPolicy.rename)
    FileUploadConflictPolicy conflictPolicy,
    @Default(false) bool isRunning,
    @Default(false) bool isCancelled,
    @Default(false) bool isComplete,
    String? errorMessage,
  }) = _FileUploadState;
}
