import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FileMentionOverlay extends StatefulWidget {
  final List<String> filteredFiles;
  final int selectedIndex;
  final void Function(String filePath) onSelect;
  final VoidCallback onDismiss;

  const FileMentionOverlay({
    super.key,
    required this.filteredFiles,
    this.selectedIndex = 0,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<FileMentionOverlay> createState() => _FileMentionOverlayState();
}

class _FileMentionOverlayState extends State<FileMentionOverlay> {
  static const _itemExtent = 52.0;
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant FileMentionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.filteredFiles.length != widget.filteredFiles.length) {
      _ensureSelectedVisible();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureSelectedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final itemTop = widget.selectedIndex * _itemExtent;
      final itemBottom = itemTop + _itemExtent;
      final visibleTop = position.pixels;
      final visibleBottom = visibleTop + position.viewportDimension;
      final target = itemTop < visibleTop
          ? itemTop
          : itemBottom > visibleBottom
          ? itemBottom - position.viewportDimension
          : null;
      if (target == null) return;
      _scrollController.jumpTo(target.clamp(0.0, position.maxScrollExtent));
    });
  }

  IconData _fileIcon(String path) {
    if (path.endsWith('.dart')) return Icons.code;
    if (path.endsWith('.ts') || path.endsWith('.tsx')) return Icons.javascript;
    if (path.endsWith('.json')) return Icons.data_object;
    if (path.endsWith('.yaml') || path.endsWith('.yml')) return Icons.settings;
    if (path.endsWith('.md')) return Icons.description;
    if (path.contains('/test/')) return Icons.science;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: cs.surfaceContainer,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant, width: 0.5),
        ),
        child: ListView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          itemExtent: _itemExtent,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: widget.filteredFiles.length,
          itemBuilder: (context, index) {
            final file = widget.filteredFiles[index];
            final fileName = file.split('/').last;
            final dirPath = file.contains('/')
                ? file.substring(0, file.lastIndexOf('/'))
                : '';
            final isSelected = index == widget.selectedIndex;
            return InkWell(
              key: ValueKey('file_completion_item_$index'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => widget.onSelect(file),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primaryContainer.withValues(alpha: 0.55)
                      : null,
                  border: Border(
                    left: BorderSide(
                      color: isSelected ? cs.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(9, 6, 12, 6),
                child: Row(
                  children: [
                    Icon(
                      _fileIcon(file),
                      size: 16,
                      color: appColors.subtleText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (dirPath.isNotEmpty)
                            Text(
                              dirPath,
                              style: TextStyle(
                                fontSize: 10,
                                color: appColors.subtleText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
