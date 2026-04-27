import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'slash_command_sheet.dart';

class FileMentionOverlay extends StatefulWidget {
  final List<SlashCommand> filteredPlugins;
  final List<String> filteredFiles;
  final int selectedIndex;
  final void Function(SlashCommand plugin)? onSelectPlugin;
  final void Function(String filePath) onSelect;
  final VoidCallback onDismiss;

  const FileMentionOverlay({
    super.key,
    this.filteredPlugins = const [],
    required this.filteredFiles,
    this.selectedIndex = 0,
    this.onSelectPlugin,
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
    final appColors = Theme.of(context).extension<AppColors>();
    final subtleText = appColors?.subtleText ?? cs.onSurfaceVariant;
    final itemCount =
        widget.filteredPlugins.length + widget.filteredFiles.length;
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
          itemCount: itemCount,
          itemBuilder: (context, index) {
            final pluginCount = widget.filteredPlugins.length;
            if (index < pluginCount) {
              final plugin = widget.filteredPlugins[index];
              final isSelected = index == widget.selectedIndex;
              return InkWell(
                key: ValueKey('plugin_completion_item_$index'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => widget.onSelectPlugin?.call(plugin),
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
                        plugin.icon,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plugin.command,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              plugin.description,
                              style: TextStyle(fontSize: 10, color: subtleText),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final file = widget.filteredFiles[index - pluginCount];
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
                    Icon(_fileIcon(file), size: 16, color: subtleText),
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
                              style: TextStyle(fontSize: 10, color: subtleText),
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
