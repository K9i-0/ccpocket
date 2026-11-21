import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/model_picker_style.dart';

/// Shows a model (or option) picker as either a modal bottom sheet or an inline
/// popup menu anchored to [anchorContext].
Future<void> showModelPicker<T>({
  required BuildContext context,
  required ModelPickerStyle style,
  required String title,
  required List<T> values,
  required T? selected,
  required String Function(T) label,
  String? Function(T)? subtitle,
  required String Function(T) optionKey,
  required ValueChanged<T> onSelected,
  BuildContext? anchorContext,
  Color? checkColor,
  bool notifyWhenUnchanged = false,
}) async {
  if (values.isEmpty) return;

  if (style == ModelPickerStyle.popupMenu) {
    final chosen = await _showPopupModelMenu<T>(
      context: context,
      anchorContext: anchorContext,
      values: values,
      selected: selected,
      label: label,
      subtitle: subtitle,
      optionKey: optionKey,
      checkColor: checkColor,
    );
    if (chosen != null) {
      HapticFeedback.selectionClick();
      if (notifyWhenUnchanged || chosen != selected) onSelected(chosen);
    }
    return;
  }

  await _showBottomSheetModelPicker<T>(
    context: context,
    title: title,
    values: values,
    selected: selected,
    label: label,
    subtitle: subtitle,
    optionKey: optionKey,
    onSelected: onSelected,
    checkColor: checkColor,
    notifyWhenUnchanged: notifyWhenUnchanged,
  );
}

Future<T?> _showPopupModelMenu<T>({
  required BuildContext context,
  required BuildContext? anchorContext,
  required List<T> values,
  required T? selected,
  required String Function(T) label,
  String? Function(T)? subtitle,
  required String Function(T) optionKey,
  Color? checkColor,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  final anchor = (anchorContext ?? context).findRenderObject() as RenderBox?;
  final RelativeRect position;
  if (overlay != null && anchor != null && anchor.hasSize) {
    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );
  } else {
    position = const RelativeRect.fromLTRB(16, 100, 16, 16);
  }

  final cs = Theme.of(context).colorScheme;
  final maxHeight = MediaQuery.sizeOf(context).height * 0.55;

  return showMenu<T>(
    context: context,
    position: position,
    initialValue: selected,
    constraints: BoxConstraints(
      minWidth: 200,
      maxWidth: 320,
      maxHeight: maxHeight,
    ),
    items: [
      for (final value in values)
        PopupMenuItem<T>(
          key: ValueKey(optionKey(value)),
          value: value,
          height: 44,
          child: _PopupModelMenuItemRow(
            label: label(value),
            subtitle: subtitle?.call(value),
            selected: value == selected,
            checkColor: checkColor ?? cs.primary,
          ),
        ),
    ],
  );
}

class _PopupModelMenuItemRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final Color checkColor;

  const _PopupModelMenuItemRow({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.checkColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: hasSubtitle ? 6 : 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (hasSubtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check, size: 18, color: checkColor),
          ],
        ],
      ),
    );
  }
}

Future<void> _showBottomSheetModelPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> values,
  required T? selected,
  required String Function(T) label,
  String? Function(T)? subtitle,
  required String Function(T) optionKey,
  required ValueChanged<T> onSelected,
  Color? checkColor,
  bool notifyWhenUnchanged = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final value in values)
                    ListTile(
                      key: ValueKey(optionKey(value)),
                      title: Text(label(value)),
                      subtitle: subtitle?.call(value) == null
                          ? null
                          : Text(subtitle!(value)!),
                      trailing: value == selected
                          ? Icon(Icons.check, color: checkColor)
                          : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(sheetContext);
                        if (notifyWhenUnchanged || value != selected) {
                          onSelected(value);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
