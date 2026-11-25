import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/platform_helper.dart';
import '../sections/shortcuts_settings_section.dart';

/// Quick-reference dialog for desktop keyboard shortcuts (`⌘/`).
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key, this.isMacOS});

  /// Overrides platform detection (tests).
  final bool? isMacOS;

  static Future<void> show(BuildContext context, {bool? isMacOS}) {
    return showDialog<void>(
      context: context,
      builder: (_) => KeyboardShortcutsDialog(isMacOS: isMacOS),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final useMacOS = isMacOS ?? isMacOSPlatform;

    return Dialog(
      key: const ValueKey('keyboard_shortcuts_dialog'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.keyboard_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.shortcutsDialogTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('keyboard_shortcuts_close_button'),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final group in DesktopShortcutGroup.values)
                      _DialogShortcutGroup(
                        title: DesktopShortcutCatalog.groupTitle(group, l),
                        items: DesktopShortcutCatalog.itemsForGroup(
                          group,
                          isMacOS: useMacOS,
                        ),
                        isMacOS: useMacOS,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogShortcutGroup extends StatelessWidget {
  const _DialogShortcutGroup({
    required this.title,
    required this.items,
    required this.isMacOS,
  });

  final String title;
  final List<DesktopShortcutItem> items;
  final bool isMacOS;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          for (final item in items)
            ShortcutReferenceRow(
              key: ValueKey('dialog_shortcut_row_${item.id}'),
              label: item.label(l),
              keys: item.keysFor(isMacOS: isMacOS),
            ),
        ],
      ),
    );
  }
}
