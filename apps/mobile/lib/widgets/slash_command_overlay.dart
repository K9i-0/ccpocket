import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'slash_command_sheet.dart';

class SlashCommandOverlay extends StatefulWidget {
  final List<SlashCommand> filteredCommands;
  final int selectedIndex;
  final void Function(SlashCommand command) onSelect;
  final VoidCallback onDismiss;

  const SlashCommandOverlay({
    super.key,
    required this.filteredCommands,
    this.selectedIndex = 0,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<SlashCommandOverlay> createState() => _SlashCommandOverlayState();
}

class _SlashCommandOverlayState extends State<SlashCommandOverlay> {
  static const _itemExtent = 42.0;
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant SlashCommandOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.filteredCommands.length != widget.filteredCommands.length) {
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
          itemCount: widget.filteredCommands.length,
          itemBuilder: (context, index) {
            final cmd = widget.filteredCommands[index];
            final cs = Theme.of(context).colorScheme;
            final iconColor = switch (cmd.category) {
              SlashCommandCategory.project => cs.secondary,
              SlashCommandCategory.skill => cs.tertiary,
              SlashCommandCategory.app => cs.primary,
              SlashCommandCategory.plugin => cs.primary,
              SlashCommandCategory.builtin => appColors.subtleText,
            };
            final isSelected = index == widget.selectedIndex;
            return InkWell(
              key: ValueKey('slash_completion_item_$index'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => widget.onSelect(cmd),
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
                padding: const EdgeInsets.fromLTRB(9, 8, 12, 8),
                child: Row(
                  children: [
                    Icon(cmd.icon, size: 18, color: iconColor),
                    const SizedBox(width: 10),
                    Text(
                      cmd.command,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: cs.primary,
                      ),
                    ),
                    if (cmd.category != SlashCommandCategory.builtin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          switch (cmd.category) {
                            SlashCommandCategory.project => 'project',
                            SlashCommandCategory.skill => 'skill',
                            SlashCommandCategory.app => 'app',
                            SlashCommandCategory.plugin => 'plugin',
                            SlashCommandCategory.builtin => 'builtin',
                          },
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cmd.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: appColors.subtleText,
                        ),
                        overflow: TextOverflow.ellipsis,
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
