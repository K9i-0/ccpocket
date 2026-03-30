import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/diff_parser.dart';
import 'diff_binary_notice.dart';
import 'diff_file_header.dart';
import 'diff_hunk_widget.dart';
import 'diff_image_widget.dart';

class DiffContentList extends StatelessWidget {
  final List<DiffFile> files;
  final Set<int> hiddenFileIndices;
  final Set<int> collapsedFileIndices;
  final ValueChanged<int> onToggleCollapse;
  final VoidCallback onClearHidden;
  final bool selectionMode;
  final Set<String> selectedHunkKeys;
  final ValueChanged<int>? onToggleFileSelection;
  final void Function(int fileIdx, int hunkIdx)? onToggleHunkSelection;
  final bool Function(int fileIdx)? isFileFullySelected;
  final bool Function(int fileIdx)? isFilePartiallySelected;
  final ValueChanged<int>? onLoadImage;
  final Set<int> loadingImageIndices;
  final ValueChanged<int>? onSwipeStage;
  final ValueChanged<int>? onSwipeUnstage;
  final ValueChanged<int>? onSwipeRevert;
  final ValueChanged<int>? onLongPressFile;
  final void Function(int fileIdx, int hunkIdx)? onSwipeStageHunk;
  final void Function(int fileIdx, int hunkIdx)? onSwipeUnstageHunk;
  final void Function(int fileIdx, int hunkIdx)? onSwipeRevertHunk;
  final void Function(int fileIdx, int hunkIdx)? onLongPressHunk;
  final bool lineWrapEnabled;
  final Set<String> stagedFilePaths;

  const DiffContentList({
    super.key,
    required this.files,
    required this.hiddenFileIndices,
    required this.collapsedFileIndices,
    required this.onToggleCollapse,
    required this.onClearHidden,
    this.selectionMode = false,
    this.selectedHunkKeys = const {},
    this.onToggleFileSelection,
    this.onToggleHunkSelection,
    this.isFileFullySelected,
    this.isFilePartiallySelected,
    this.onLoadImage,
    this.loadingImageIndices = const {},
    this.onSwipeStage,
    this.onSwipeUnstage,
    this.onSwipeRevert,
    this.onLongPressFile,
    this.onSwipeStageHunk,
    this.onSwipeUnstageHunk,
    this.onSwipeRevertHunk,
    this.onLongPressHunk,
    this.lineWrapEnabled = false,
    this.stagedFilePaths = const {},
  });

  FileStageStatus _stageStatusFor(DiffFile file) {
    if (stagedFilePaths.isEmpty) return FileStageStatus.unknown;
    return stagedFilePaths.contains(file.filePath)
        ? FileStageStatus.staged
        : FileStageStatus.unstaged;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Single-file mode: show file header + hunks (no filter/divider)
    if (files.length == 1) {
      final file = files.first;
      if (file.isBinary) {
        if (file.isImage && file.imageData != null) {
          return DiffImageWidget(
            file: file,
            imageData: file.imageData!,
            onLoadRequested: onLoadImage != null ? () => onLoadImage!(0) : null,
            loading: loadingImageIndices.contains(0),
          );
        }
        return const DiffBinaryNotice();
      }
      final collapsed = collapsedFileIndices.contains(0);
      final hunkCount = collapsed ? 0 : file.hunks.length;
      final lineNumberWidth = calcLineNumberWidth(file);
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 1 + hunkCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildFileHeader(0, file, collapsed);
          }
          final hunkIdx = index - 1;
          return DiffHunkWidget(
            hunk: file.hunks[hunkIdx],
            lineNumberWidth: lineNumberWidth,
            dismissKey: '${file.filePath}:$hunkIdx',
            selectionMode: selectionMode,
            selected: selectedHunkKeys.contains('0:$hunkIdx'),
            lineWrapEnabled: lineWrapEnabled,
            onToggleSelection: onToggleHunkSelection != null
                ? () => onToggleHunkSelection!(0, hunkIdx)
                : null,
            onLongPressHeader: !selectionMode && onLongPressHunk != null
                ? () => onLongPressHunk!(0, hunkIdx)
                : null,
            onSwipeStage: !selectionMode && onSwipeStageHunk != null
                ? () => onSwipeStageHunk!(0, hunkIdx)
                : null,
            onSwipeUnstage: !selectionMode && onSwipeUnstageHunk != null
                ? () => onSwipeUnstageHunk!(0, hunkIdx)
                : null,
            onSwipeRevert: !selectionMode && onSwipeRevertHunk != null
                ? () => onSwipeRevertHunk!(0, hunkIdx)
                : null,
          );
        },
      );
    }

    // Multi-file mode: all visible files in one scrollable list
    final visibleFiles = <int>[];
    for (var i = 0; i < files.length; i++) {
      if (!hiddenFileIndices.contains(i)) visibleFiles.add(i);
    }

    if (visibleFiles.isEmpty) {
      final l = AppLocalizations.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off, size: 48, color: appColors.subtleText),
            const SizedBox(height: 12),
            Text(
              l.allFilesFilteredOut,
              style: TextStyle(fontSize: 16, color: appColors.subtleText),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onClearHidden, child: Text(l.showAll)),
          ],
        ),
      );
    }

    final lineNumberWidths = {
      for (final i in visibleFiles) i: calcLineNumberWidth(files[i]),
    };

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _countListItems(visibleFiles),
      itemBuilder: (context, index) => _DiffListItem(
        index: index,
        visibleFiles: visibleFiles,
        files: files,
        lineNumberWidths: lineNumberWidths,
        collapsedFileIndices: collapsedFileIndices,
        selectionMode: selectionMode,
        selectedHunkKeys: selectedHunkKeys,
        onToggleCollapse: onToggleCollapse,
        onToggleFileSelection: onToggleFileSelection,
        onToggleHunkSelection: onToggleHunkSelection,
        isFileFullySelected: isFileFullySelected,
        isFilePartiallySelected: isFilePartiallySelected,
        onLoadImage: onLoadImage,
        loadingImageIndices: loadingImageIndices,
        onSwipeStage: onSwipeStage,
        onSwipeUnstage: onSwipeUnstage,
        onSwipeRevert: onSwipeRevert,
        onLongPressFile: onLongPressFile,
        onSwipeStageHunk: onSwipeStageHunk,
        onSwipeUnstageHunk: onSwipeUnstageHunk,
        onSwipeRevertHunk: onSwipeRevertHunk,
        onLongPressHunk: onLongPressHunk,
        lineWrapEnabled: lineWrapEnabled,
        stagedFilePaths: stagedFilePaths,
      ),
    );
  }

  Widget _buildFileHeader(int fileIdx, DiffFile file, bool collapsed) {
    final header = DiffFileHeader(
      file: file,
      collapsed: collapsed,
      onToggleCollapse: () => onToggleCollapse(fileIdx),
      selectionMode: selectionMode,
      selected: isFileFullySelected?.call(fileIdx) ?? false,
      partiallySelected: isFilePartiallySelected?.call(fileIdx) ?? false,
      onToggleSelection: onToggleFileSelection != null
          ? () => onToggleFileSelection!(fileIdx)
          : null,
      stageStatus: _stageStatusFor(file),
      onLongPress: onLongPressFile != null
          ? () => onLongPressFile!(fileIdx)
          : null,
    );
    if (onSwipeStage != null ||
        onSwipeUnstage != null ||
        onSwipeRevert != null) {
      return _SwipeStageDismissible(
        fileIdx: fileIdx,
        filePath: file.filePath,
        onSwipeStage: onSwipeStage,
        onSwipeUnstage: onSwipeUnstage,
        onSwipeRevert: onSwipeRevert,
        child: header,
      );
    }
    return header;
  }

  int _countListItems(List<int> visibleFiles) {
    var count = 0;
    for (var i = 0; i < visibleFiles.length; i++) {
      final fileIdx = visibleFiles[i];
      final file = files[fileIdx];
      final collapsed = collapsedFileIndices.contains(fileIdx);
      count += 1; // header
      if (!collapsed) {
        count += file.isBinary ? 1 : file.hunks.length;
      }
      if (i < visibleFiles.length - 1) count += 1; // divider
    }
    return count;
  }
}

class _DiffListItem extends StatelessWidget {
  final int index;
  final List<int> visibleFiles;
  final List<DiffFile> files;
  final Map<int, double> lineNumberWidths;
  final Set<int> collapsedFileIndices;
  final bool selectionMode;
  final Set<String> selectedHunkKeys;
  final ValueChanged<int> onToggleCollapse;
  final ValueChanged<int>? onToggleFileSelection;
  final void Function(int fileIdx, int hunkIdx)? onToggleHunkSelection;
  final bool Function(int fileIdx)? isFileFullySelected;
  final bool Function(int fileIdx)? isFilePartiallySelected;
  final ValueChanged<int>? onLoadImage;
  final Set<int> loadingImageIndices;
  final ValueChanged<int>? onSwipeStage;
  final ValueChanged<int>? onSwipeUnstage;
  final ValueChanged<int>? onSwipeRevert;
  final ValueChanged<int>? onLongPressFile;
  final void Function(int fileIdx, int hunkIdx)? onSwipeStageHunk;
  final void Function(int fileIdx, int hunkIdx)? onSwipeUnstageHunk;
  final void Function(int fileIdx, int hunkIdx)? onSwipeRevertHunk;
  final void Function(int fileIdx, int hunkIdx)? onLongPressHunk;
  final bool lineWrapEnabled;
  final Set<String> stagedFilePaths;

  const _DiffListItem({
    required this.index,
    required this.visibleFiles,
    required this.files,
    required this.lineNumberWidths,
    required this.collapsedFileIndices,
    required this.selectionMode,
    required this.selectedHunkKeys,
    required this.onToggleCollapse,
    this.onToggleFileSelection,
    this.onToggleHunkSelection,
    this.isFileFullySelected,
    this.isFilePartiallySelected,
    this.onLoadImage,
    this.loadingImageIndices = const {},
    this.onSwipeStage,
    this.onSwipeUnstage,
    this.onSwipeRevert,
    this.onLongPressFile,
    this.onSwipeStageHunk,
    this.onSwipeUnstageHunk,
    this.onSwipeRevertHunk,
    this.onLongPressHunk,
    this.lineWrapEnabled = false,
    this.stagedFilePaths = const {},
  });

  FileStageStatus _stageStatusFor(DiffFile file) {
    if (stagedFilePaths.isEmpty) return FileStageStatus.unknown;
    return stagedFilePaths.contains(file.filePath)
        ? FileStageStatus.staged
        : FileStageStatus.unstaged;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    var offset = 0;
    for (var i = 0; i < visibleFiles.length; i++) {
      final fileIdx = visibleFiles[i];
      final file = files[fileIdx];
      final collapsed = collapsedFileIndices.contains(fileIdx);
      final contentCount = collapsed
          ? 0
          : (file.isBinary ? 1 : file.hunks.length);
      final sectionSize = 1 + contentCount;

      if (index < offset + sectionSize) {
        final localIdx = index - offset;
        if (localIdx == 0) {
          final header = DiffFileHeader(
            file: file,
            collapsed: collapsed,
            onToggleCollapse: () => onToggleCollapse(fileIdx),
            selectionMode: selectionMode,
            selected: isFileFullySelected?.call(fileIdx) ?? false,
            partiallySelected: isFilePartiallySelected?.call(fileIdx) ?? false,
            onToggleSelection: onToggleFileSelection != null
                ? () => onToggleFileSelection!(fileIdx)
                : null,
            stageStatus: _stageStatusFor(file),
            onLongPress: onLongPressFile != null
                ? () => onLongPressFile!(fileIdx)
                : null,
          );
          if (onSwipeStage != null ||
              onSwipeUnstage != null ||
              onSwipeRevert != null) {
            return _SwipeStageDismissible(
              fileIdx: fileIdx,
              filePath: file.filePath,
              onSwipeStage: onSwipeStage,
              onSwipeUnstage: onSwipeUnstage,
              onSwipeRevert: onSwipeRevert,
              child: header,
            );
          }
          return header;
        }
        if (file.isBinary) {
          if (file.isImage && file.imageData != null) {
            return DiffImageWidget(
              file: file,
              imageData: file.imageData!,
              onLoadRequested: onLoadImage != null
                  ? () => onLoadImage!(fileIdx)
                  : null,
              loading: loadingImageIndices.contains(fileIdx),
            );
          }
          return const DiffBinaryNotice();
        }
        final hunkIdx = localIdx - 1;
        return DiffHunkWidget(
          hunk: file.hunks[hunkIdx],
          lineNumberWidth: lineNumberWidths[fileIdx]!,
          dismissKey: '${file.filePath}:$hunkIdx',
          selectionMode: selectionMode,
          selected: selectedHunkKeys.contains('$fileIdx:$hunkIdx'),
          lineWrapEnabled: lineWrapEnabled,
          onToggleSelection: onToggleHunkSelection != null
              ? () => onToggleHunkSelection!(fileIdx, hunkIdx)
              : null,
          onLongPressHeader: !selectionMode && onLongPressHunk != null
              ? () => onLongPressHunk!(fileIdx, hunkIdx)
              : null,
          onSwipeStage: !selectionMode && onSwipeStageHunk != null
              ? () => onSwipeStageHunk!(fileIdx, hunkIdx)
              : null,
          onSwipeUnstage: !selectionMode && onSwipeUnstageHunk != null
              ? () => onSwipeUnstageHunk!(fileIdx, hunkIdx)
              : null,
          onSwipeRevert: !selectionMode && onSwipeRevertHunk != null
              ? () => onSwipeRevertHunk!(fileIdx, hunkIdx)
              : null,
        );
      }

      offset += sectionSize;

      // Divider between files
      if (i < visibleFiles.length - 1) {
        if (index == offset) {
          return Divider(height: 24, thickness: 1, color: appColors.codeBorder);
        }
        offset += 1;
      }
    }
    return const SizedBox.shrink();
  }
}

/// Wraps a file header with swipe gestures:
/// - Right swipe → Stage (green)
/// - Left swipe → Unstage (amber) or Revert/Discard (red)
class _SwipeStageDismissible extends StatelessWidget {
  final int fileIdx;
  final String filePath;
  final ValueChanged<int>? onSwipeStage;
  final ValueChanged<int>? onSwipeUnstage;
  final ValueChanged<int>? onSwipeRevert;
  final Widget child;

  const _SwipeStageDismissible({
    required this.fileIdx,
    required this.filePath,
    this.onSwipeStage,
    this.onSwipeUnstage,
    this.onSwipeRevert,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Determine left swipe action: Revert takes priority, then Unstage
    final hasLeftAction = onSwipeRevert != null || onSwipeUnstage != null;
    final isRevert = onSwipeRevert != null;
    final leftLabel = isRevert ? 'Revert' : 'Unstage';
    final leftColor = isRevert ? cs.error : cs.tertiary;
    final leftIcon = isRevert ? Icons.undo : Icons.remove_circle_outline;

    // Determine swipe direction
    final direction = onSwipeStage != null && hasLeftAction
        ? DismissDirection.horizontal
        : onSwipeStage != null
        ? DismissDirection.startToEnd
        : hasLeftAction
        ? DismissDirection.endToStart
        : DismissDirection.none;

    return Dismissible(
      key: ValueKey('swipe_stage_$filePath'),
      direction: direction,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          onSwipeStage?.call(fileIdx);
        } else {
          if (onSwipeRevert != null) {
            onSwipeRevert!.call(fileIdx);
          } else {
            onSwipeUnstage?.call(fileIdx);
          }
        }
        return false;
      },
      background: onSwipeStage != null
          ? Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              color: cs.primary.withValues(alpha: 0.15),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Stage',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : hasLeftAction
          ? const SizedBox.shrink()
          : null,
      secondaryBackground: hasLeftAction
          ? Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: leftColor.withValues(alpha: 0.15),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    leftLabel,
                    style: TextStyle(
                      color: leftColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(leftIcon, color: leftColor, size: 20),
                ],
              ),
            )
          : null,
      child: child,
    );
  }
}
