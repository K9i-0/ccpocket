import 'package:flutter/material.dart';

import '../utils/platform_helper.dart';

class AdaptiveActionMenuItem<T> {
  final T value;
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool destructive;

  const AdaptiveActionMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.subtitle,
    this.destructive = false,
  });
}

Future<T?> showAdaptiveActionMenu<T>({
  required BuildContext context,
  required List<AdaptiveActionMenuItem<T>> items,
  Offset? position,
  Widget? header,
}) {
  if (isDesktopPlatform && position != null) {
    return _showDesktopActionMenu(
      context: context,
      items: items,
      position: position,
      header: header,
    );
  }
  return _showMobileActionSheet(context: context, items: items, header: header);
}

Future<T?> _showDesktopActionMenu<T>({
  required BuildContext context,
  required List<AdaptiveActionMenuItem<T>> items,
  required Offset position,
  Widget? header,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final localPosition = overlay.globalToLocal(position);
  final menuPosition = RelativeRect.fromRect(
    Rect.fromLTWH(localPosition.dx, localPosition.dy, 0, 0),
    Offset.zero & overlay.size,
  );

  return showMenu<T>(
    context: context,
    position: menuPosition,
    items: [
      if (header != null)
        PopupMenuItem<T>(
          enabled: false,
          height: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: header,
        ),
      if (header != null) const PopupMenuDivider(height: 1),
      for (final item in items)
        PopupMenuItem<T>(
          value: item.value,
          child: _AdaptiveActionMenuRow(item: item, dense: true),
        ),
    ],
  );
}

Future<T?> _showMobileActionSheet<T>({
  required BuildContext context,
  required List<AdaptiveActionMenuItem<T>> items,
  Widget? header,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: header,
            ),
            const Divider(height: 1),
          ],
          for (final item in items)
            ListTile(
              leading: Icon(
                item.icon,
                color: item.destructive
                    ? Theme.of(sheetContext).colorScheme.error
                    : null,
              ),
              title: Text(
                item.label,
                style: item.destructive
                    ? TextStyle(color: Theme.of(sheetContext).colorScheme.error)
                    : null,
              ),
              subtitle: item.subtitle == null ? null : Text(item.subtitle!),
              onTap: () => Navigator.of(sheetContext).pop(item.value),
            ),
        ],
      ),
    ),
  );
}

class AdaptiveContextMenuRegion extends StatelessWidget {
  final Widget child;
  final ValueChanged<Offset?> onOpen;
  final bool enableLongPress;

  const AdaptiveContextMenuRegion({
    super.key,
    required this.child,
    required this.onOpen,
    this.enableLongPress = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => onOpen(details.globalPosition),
      onLongPressStart: enableLongPress
          ? (details) => onOpen(details.globalPosition)
          : null,
      child: child,
    );
  }
}

class _AdaptiveActionMenuRow<T> extends StatelessWidget {
  final AdaptiveActionMenuItem<T> item;
  final bool dense;

  const _AdaptiveActionMenuRow({required this.item, required this.dense});

  @override
  Widget build(BuildContext context) {
    final color = item.destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: dense ? 18 : 20, color: color),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  color: item.destructive
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
              if (item.subtitle != null)
                Text(
                  item.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
