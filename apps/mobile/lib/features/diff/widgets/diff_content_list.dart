import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/diff_parser.dart';
import 'diff_binary_notice.dart';
import 'diff_file_header.dart';
import 'diff_hunk_widget.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Single-file mode: no file header, but still support selection on hunks
    if (files.length == 1) {
      final file = files.first;
      if (file.isBinary) return const DiffBinaryNotice();
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: file.hunks.length,
        itemBuilder: (context, index) => DiffHunkWidget(
          hunk: file.hunks[index],
          selectionMode: selectionMode,
          selected: selectedHunkKeys.contains('0:$index'),
          onToggleSelection: onToggleHunkSelection != null
              ? () => onToggleHunkSelection!(0, index)
              : null,
        ),
      );
    }

    // Multi-file mode: all visible files in one scrollable list
    final visibleFiles = <int>[];
    for (var i = 0; i < files.length; i++) {
      if (!hiddenFileIndices.contains(i)) visibleFiles.add(i);
    }

    if (visibleFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off, size: 48, color: appColors.subtleText),
            const SizedBox(height: 12),
            Text(
              'All files filtered out',
              style: TextStyle(fontSize: 16, color: appColors.subtleText),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onClearHidden, child: const Text('Show all')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _countListItems(visibleFiles),
      itemBuilder: (context, index) =>
          _buildListItem(index, visibleFiles, appColors),
    );
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

  Widget _buildListItem(
    int index,
    List<int> visibleFiles,
    AppColors appColors,
  ) {
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
          return DiffFileHeader(
            file: file,
            collapsed: collapsed,
            onToggleCollapse: () => onToggleCollapse(fileIdx),
            selectionMode: selectionMode,
            selected: isFileFullySelected?.call(fileIdx) ?? false,
            partiallySelected: isFilePartiallySelected?.call(fileIdx) ?? false,
            onToggleSelection: onToggleFileSelection != null
                ? () => onToggleFileSelection!(fileIdx)
                : null,
          );
        }
        if (file.isBinary) {
          return const DiffBinaryNotice();
        }
        final hunkIdx = localIdx - 1;
        return DiffHunkWidget(
          hunk: file.hunks[hunkIdx],
          selectionMode: selectionMode,
          selected: selectedHunkKeys.contains('$fileIdx:$hunkIdx'),
          onToggleSelection: onToggleHunkSelection != null
              ? () => onToggleHunkSelection!(fileIdx, hunkIdx)
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
