import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/bridge_service.dart';
import '../file_transfer_downloader.dart';
import '../state/file_transfer_cubit.dart';
import '../state/file_transfer_state.dart';

typedef ShareFileCallback = Future<void> Function(ShareParams params);

bool get supportsProjectFileTransfer =>
    !kIsWeb && defaultTargetPlatform != TargetPlatform.linux;

Future<void> showProjectFileTransferDialog(
  BuildContext context, {
  required BridgeService bridge,
  required String projectPath,
  required String filePath,
  FileTransferDownloader? downloader,
  ShareFileCallback? shareFile,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider(
      create: (_) =>
          FileTransferCubit(bridge: bridge, downloader: downloader)
            ..start(projectPath: projectPath, filePath: filePath),
      child: FileTransferDialog(
        projectPath: projectPath,
        filePath: filePath,
        shareFile: shareFile,
      ),
    ),
  );
}

class FileTransferDialog extends StatelessWidget {
  final String projectPath;
  final String filePath;
  final ShareFileCallback? shareFile;

  const FileTransferDialog({
    super.key,
    required this.projectPath,
    required this.filePath,
    this.shareFile,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FileTransferCubit, FileTransferState>(
      listener: (context, state) async {
        switch (state) {
          case FileTransferReady():
            await _shareReadyFile(context, state);
          case FileTransferCancelled():
            if (context.mounted) Navigator.of(context).pop();
          default:
            break;
        }
      },
      builder: (context, state) => _FileTransferDialogBody(
        fileName: filePath.split('/').last,
        state: state,
        onCancel: context.read<FileTransferCubit>().cancel,
        onClose: () => Navigator.of(context).pop(),
        onRetry: () => context.read<FileTransferCubit>().start(
          projectPath: projectPath,
          filePath: filePath,
        ),
      ),
    );
  }

  Future<void> _shareReadyFile(
    BuildContext context,
    FileTransferReady ready,
  ) async {
    final cubit = context.read<FileTransferCubit>();
    final navigator = Navigator.of(context);
    final renderBox = context.findRenderObject();
    final sharePositionOrigin = renderBox is RenderBox
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    final params = ShareParams(
      files: [XFile(ready.localPath, mimeType: ready.mimeType)],
      fileNameOverrides: [ready.fileName],
      sharePositionOrigin: sharePositionOrigin,
    );

    try {
      if (shareFile != null) {
        await shareFile!(params);
      } else {
        await SharePlus.instance.share(params);
      }
      await cubit.cleanup();
      if (context.mounted) navigator.pop();
    } catch (_) {
      if (context.mounted) await cubit.markShareFailed();
    }
  }
}

class _FileTransferDialogBody extends StatelessWidget {
  final String fileName;
  final FileTransferState state;
  final VoidCallback onCancel;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  const _FileTransferDialogBody({
    required this.fileName,
    required this.state,
    required this.onCancel,
    required this.onClose,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.fileTransferShareOrSave),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 20),
            _FileTransferStatus(state: state),
          ],
        ),
      ),
      actions: switch (state) {
        FileTransferFailed() => [
          TextButton(
            key: const ValueKey('file_transfer_close_button'),
            onPressed: onClose,
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('file_transfer_retry_button'),
            onPressed: onRetry,
            child: Text(l.retry),
          ),
        ],
        FileTransferReady() => const [],
        FileTransferCancelled() => const [],
        _ => [
          TextButton(
            key: const ValueKey('file_transfer_cancel_button'),
            onPressed: onCancel,
            child: Text(l.cancel),
          ),
        ],
      },
    );
  }
}

class _FileTransferStatus extends StatelessWidget {
  final FileTransferState state;

  const _FileTransferStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return switch (state) {
      FileTransferIdle() || FileTransferPreparing() => _TransferInProgress(
        label: l.fileTransferPreparing,
      ),
      final FileTransferDownloading downloading => _TransferInProgress(
        label: l.fileTransferDownloading,
        receivedBytes: downloading.receivedBytes,
        totalBytes: downloading.totalBytes,
      ),
      FileTransferReady() => _TransferInProgress(
        label: l.fileTransferOpeningShareSheet,
      ),
      final FileTransferFailed failed => _TransferFailure(
        message: _localizedTransferError(l, failed.errorCode),
      ),
      FileTransferCancelled() => const SizedBox.shrink(),
    };
  }
}

class _TransferInProgress extends StatelessWidget {
  final String label;
  final int? receivedBytes;
  final int? totalBytes;

  const _TransferInProgress({
    required this.label,
    this.receivedBytes,
    this.totalBytes,
  });

  @override
  Widget build(BuildContext context) {
    final received = receivedBytes;
    final total = totalBytes;
    final progress = received != null && total != null && total > 0
        ? (received / total).clamp(0.0, 1.0)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          key: const ValueKey('file_transfer_progress_indicator'),
          value: progress,
        ),
        if (received != null && total != null) ...[
          const SizedBox(height: 8),
          Text(
            '${formatTransferBytes(received)} / ${formatTransferBytes(total)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _TransferFailure extends StatelessWidget {
  final String message;

  const _TransferFailure({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    );
  }
}

String _localizedTransferError(AppLocalizations l, String errorCode) {
  return switch (errorCode) {
    'file_download_not_allowed' => l.fileTransferErrorNotAllowed,
    'file_download_not_found' => l.fileTransferErrorNotFound,
    'file_download_not_file' => l.fileTransferErrorNotFile,
    'file_download_too_large' => l.fileTransferErrorTooLarge,
    'file_download_unavailable' => l.fileTransferErrorUnavailable,
    'bridge_update_required' => l.fileTransferErrorBridgeUpdate,
    'share_failed' => l.fileTransferErrorShareFailed,
    _ => l.fileTransferErrorFailed,
  };
}

String formatTransferBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}
