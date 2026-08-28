import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/bridge_service.dart';
import '../file_upload_transport.dart';
import '../state/file_upload_cubit.dart';
import '../state/file_upload_state.dart';

const int maxUploadFileCount = 20;
const int maxUploadFileBytes = 512 * 1024 * 1024;
const int maxUploadTotalBytes = 1024 * 1024 * 1024;

bool get supportsProjectFileUpload => !kIsWeb;

Future<List<String>?> showProjectFileUploadDialog(
  BuildContext context, {
  required BridgeService bridge,
  required String projectPath,
  required String directoryPath,
  required List<XFile> files,
  required List<int> fileSizes,
  FileUploadTransport? transport,
}) {
  return showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider(
      create: (_) => FileUploadCubit(
        bridge: bridge,
        projectPath: projectPath,
        directoryPath: directoryPath,
        files: files,
        fileSizes: fileSizes,
        transport: transport,
      ),
      child: FileUploadDialog(
        directoryPath: directoryPath,
        projectName: _projectName(projectPath),
      ),
    ),
  );
}

class FileUploadDialog extends StatelessWidget {
  final String directoryPath;
  final String projectName;

  const FileUploadDialog({
    super.key,
    required this.directoryPath,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileUploadCubit, FileUploadState>(
      builder: (context, state) {
        final l = AppLocalizations.of(context);
        final cubit = context.read<FileUploadCubit>();
        return PopScope<void>(
          canPop: false,
          child: AlertDialog(
            title: Text(l.fileUploadTitle),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l.fileUploadDestination}: $projectName/${directoryPath.isEmpty ? '' : directoryPath}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (!state.isRunning &&
                      !state.isComplete &&
                      state.errorMessage == null)
                    DropdownButtonFormField<FileUploadConflictPolicy>(
                      key: const ValueKey('file_upload_conflict_policy'),
                      initialValue: state.conflictPolicy,
                      decoration: InputDecoration(
                        labelText: l.fileUploadConflictLabel,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: FileUploadConflictPolicy.rename,
                          child: Text(l.fileUploadKeepBoth),
                        ),
                        DropdownMenuItem(
                          value: FileUploadConflictPolicy.overwrite,
                          child: Text(l.fileUploadReplace),
                        ),
                        DropdownMenuItem(
                          value: FileUploadConflictPolicy.skip,
                          child: Text(l.fileUploadSkip),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) cubit.setConflictPolicy(value);
                      },
                    ),
                  if (!state.isRunning &&
                      !state.isComplete &&
                      state.errorMessage == null)
                    const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: state.items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _UploadItemTile(item: state.items[index]),
                    ),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _localizedUploadError(
                              l,
                              state.items
                                  .where(
                                    (item) =>
                                        item.status ==
                                        FileUploadItemStatus.failed,
                                  )
                                  .firstOrNull
                                  ?.errorCode,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (state.isComplete) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(l.fileUploadComplete),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: _actions(context, state, cubit),
          ),
        );
      },
    );
  }

  List<Widget> _actions(
    BuildContext context,
    FileUploadState state,
    FileUploadCubit cubit,
  ) {
    final l = AppLocalizations.of(context);
    if (state.isComplete) {
      return [
        FilledButton(
          key: const ValueKey('file_upload_close_button'),
          onPressed: () => Navigator.of(context).pop(cubit.uploadedPaths),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ];
    }
    if (state.errorMessage != null) {
      return [
        TextButton(
          key: const ValueKey('file_upload_close_button'),
          onPressed: () => Navigator.of(context).pop(cubit.uploadedPaths),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('file_upload_retry_button'),
          onPressed: cubit.start,
          child: Text(l.retry),
        ),
      ];
    }
    if (state.isRunning) {
      return [
        TextButton(
          key: const ValueKey('file_upload_cancel_button'),
          onPressed: () {
            cubit.cancel();
            Navigator.of(context).pop(cubit.uploadedPaths);
          },
          child: Text(l.cancel),
        ),
      ];
    }
    return [
      TextButton(
        key: const ValueKey('file_upload_cancel_button'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l.cancel),
      ),
      FilledButton.icon(
        key: const ValueKey('file_upload_start_button'),
        onPressed: cubit.start,
        icon: const Icon(Icons.upload_file),
        label: Text(l.fileUploadAction),
      ),
    ];
  }
}

class _UploadItemTile extends StatelessWidget {
  final FileUploadItemState item;

  const _UploadItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final progress = item.sizeBytes > 0
        ? (item.sentBytes / item.sizeBytes).clamp(0.0, 1.0)
        : item.status == FileUploadItemStatus.complete
        ? 1.0
        : null;
    final label = switch (item.status) {
      FileUploadItemStatus.pending => _formatBytes(item.sizeBytes),
      FileUploadItemStatus.preparing => l.fileUploadPreparing,
      FileUploadItemStatus.uploading =>
        '${l.fileUploadUploading} ${_formatBytes(item.sentBytes)} / ${_formatBytes(item.sizeBytes)}',
      FileUploadItemStatus.finalizing => l.fileUploadFinalizing,
      FileUploadItemStatus.complete => l.fileUploadComplete,
      FileUploadItemStatus.skipped => l.fileUploadSkipped,
      FileUploadItemStatus.failed => item.errorCode ?? 'Failed',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.status == FileUploadItemStatus.complete
                    ? Icons.check_circle
                    : item.status == FileUploadItemStatus.skipped
                    ? Icons.skip_next
                    : item.status == FileUploadItemStatus.failed
                    ? Icons.error_outline
                    : Icons.insert_drive_file_outlined,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          if (item.status == FileUploadItemStatus.uploading) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              key: ValueKey('file_upload_progress_${item.id}'),
              value: progress,
            ),
          ],
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}

String _localizedUploadError(AppLocalizations l, String? code) {
  return switch (code) {
    'bridge_update_required' => l.fileUploadErrorBridgeUpdate,
    'file_upload_not_allowed' ||
    'file_upload_directory_changed' ||
    'file_upload_directory_not_found' => l.fileUploadErrorNotAllowed,
    'file_upload_too_large' || 'size_mismatch' => l.fileUploadErrorTooLarge,
    'file_upload_unavailable' => l.fileUploadErrorUnavailable,
    _ => l.fileUploadErrorFailed,
  };
}

String _projectName(String projectPath) {
  final parts = projectPath
      .split(RegExp(r'[/\\]'))
      .where((part) => part.isNotEmpty);
  return parts.isEmpty ? projectPath : parts.last;
}
