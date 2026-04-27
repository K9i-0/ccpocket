import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../utils/diff_parser.dart';
import 'diff_binary_notice.dart';
import 'diff_file_header.dart';
import 'diff_hunk_widget.dart';
import 'diff_image_widget.dart';
import 'git_swipe_action_background.dart';

class DiffContentList extends StatelessWidget {
  final List<DiffFile> files;
  final AutoScrollController scrollController;
  final Set<int> collapsedFileIndices;
  final ValueChanged<int> onToggleCollapse;
  final ValueChanged<int>? onLoadImage;
  final Set<int> loadingImageIndices;
  final ValueChanged<int>? onSwipeStage;
  final ValueChanged<int>? onSwipeUnstage;
  final ValueChanged<int>? onSwipeRevert;
  final void Function(int fileIdx, Offset? position)? onLongPressFile;
  final void Function(int fileIdx, int hunkIdx)? onSwipeStageHunk;
  final void Function(int fileIdx, int hunkIdx)? onSwipeUnstageHunk;
  final void Function(int fileIdx, int hunkIdx)? onSwipeRevertHunk;
  final void Function(int fileIdx, int hunkIdx, Offset? position)?
  onLongPressHunk;
  final bool lineWrapEnabled;
  final Set<String> stagedFilePaths;

  const DiffContentList({
    super.key,
    required this.files,
    required this.scrollController,
    required this.collapsedFileIndices,
    required this.onToggleCollapse,
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
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [_buildFileSection(0, file)],
      );
    }

    // Multi-file mode: all visible files in one scrollable list
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: files.length * 2 - 1,
      itemBuilder: (context, index) {
        if (index.isOdd) {
          return const Divider(height: 24, thickness: 1);
        }
        final fileIdx = index ~/ 2;
        return _buildFileSection(fileIdx, files[fileIdx]);
      },
    );
  }

  Widget _buildFileSection(int fileIdx, DiffFile file) {
    final collapsed = collapsedFileIndices.contains(fileIdx);
    final header = DiffFileHeader(
      file: file,
      collapsed: collapsed,
      onToggleCollapse: () => onToggleCollapse(fileIdx),
      stageStatus: _stageStatusFor(file),
      onLongPress: onLongPressFile != null
          ? () => onLongPressFile!(fileIdx, null)
          : null,
      onShowActions: onLongPressFile != null
          ? (position) => onLongPressFile!(fileIdx, position)
          : null,
    );

    Widget section = AutoScrollTag(
      key: ValueKey('diff_file_tag_${file.filePath}'),
      controller: scrollController,
      index: fileIdx,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (!collapsed)
            if (file.isBinary)
              if (file.isImage && file.imageData != null)
                DiffImageWidget(
                  file: file,
                  imageData: file.imageData!,
                  onLoadRequested: onLoadImage != null
                      ? () => onLoadImage!(fileIdx)
                      : null,
                  loading: loadingImageIndices.contains(fileIdx),
                )
              else
                const DiffBinaryNotice()
            else
              ..._buildHunkWidgets(fileIdx, file),
        ],
      ),
    );

    if (onSwipeStage != null ||
        onSwipeUnstage != null ||
        onSwipeRevert != null) {
      section = _SwipeStageDismissible(
        fileIdx: fileIdx,
        filePath: file.filePath,
        onSwipeStage: onSwipeStage,
        onSwipeUnstage: onSwipeUnstage,
        onSwipeRevert: onSwipeRevert,
        child: section,
      );
    }
    return section;
  }

  List<Widget> _buildHunkWidgets(int fileIdx, DiffFile file) {
    final lineNumberWidth = calcLineNumberWidth(file);
    return [
      for (var hunkIdx = 0; hunkIdx < file.hunks.length; hunkIdx++)
        DiffHunkWidget(
          hunk: file.hunks[hunkIdx],
          lineNumberWidth: lineNumberWidth,
          dismissKey: '${file.filePath}:$hunkIdx',
          lineWrapEnabled: lineWrapEnabled,
          onLongPress: onLongPressHunk != null
              ? () => onLongPressHunk!(fileIdx, hunkIdx, null)
              : null,
          onShowActions: onLongPressHunk != null
              ? (position) => onLongPressHunk!(fileIdx, hunkIdx, position)
              : null,
          onSwipeStage: onSwipeStageHunk != null
              ? () => onSwipeStageHunk!(fileIdx, hunkIdx)
              : null,
          onSwipeUnstage: onSwipeUnstageHunk != null
              ? () => onSwipeUnstageHunk!(fileIdx, hunkIdx)
              : null,
          onSwipeRevert: onSwipeRevertHunk != null
              ? () => onSwipeRevertHunk!(fileIdx, hunkIdx)
              : null,
        ),
    ];
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
    // Determine left swipe action: Revert takes priority, then Unstage
    final hasLeftAction = onSwipeRevert != null || onSwipeUnstage != null;
    final isRevert = onSwipeRevert != null;
    final leftLabel = isRevert ? 'Revert' : 'Unstage';
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
          ? const GitSwipeActionBackground(
              alignment: Alignment.topLeft,
              padding: EdgeInsets.only(left: 12, top: 10),
              icon: Icons.add_circle_outline,
              label: 'Stage',
              tone: GitSwipeActionTone.primary,
            )
          : hasLeftAction
          ? const SizedBox.shrink()
          : null,
      secondaryBackground: hasLeftAction
          ? GitSwipeActionBackground(
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 12, top: 10),
              icon: leftIcon,
              label: leftLabel,
              tone: isRevert
                  ? GitSwipeActionTone.danger
                  : GitSwipeActionTone.neutral,
            )
          : null,
      child: child,
    );
  }
}
