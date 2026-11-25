import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/platform_helper.dart';
import '../models/settings_catalog.dart';
import '../widgets/settings_tiles.dart';

/// Categories of desktop keyboard shortcuts shown in Settings and the
/// `⌘/` reference dialog.
enum DesktopShortcutGroup {
  application,
  navigation,
  session,
  viewPanes,
  composer,
}

/// A single documented keyboard shortcut with macOS and non-macOS keycaps.
@immutable
class DesktopShortcutItem {
  const DesktopShortcutItem({
    required this.id,
    required this.group,
    required this.label,
    required this.macKeys,
    required this.otherKeys,
    this.macOnly = false,
  });

  final String id;
  final DesktopShortcutGroup group;
  final String Function(AppLocalizations l) label;
  final List<String> macKeys;
  final List<String> otherKeys;
  final bool macOnly;

  List<String> keysFor({required bool isMacOS}) =>
      isMacOS ? macKeys : otherKeys;
}

/// Single source of truth for all desktop keyboard shortcuts displayed in
/// [ShortcutsSettingsSection] and [KeyboardShortcutsDialog].
abstract final class DesktopShortcutCatalog {
  static final List<DesktopShortcutItem> items = [
    // Application
    DesktopShortcutItem(
      id: 'open_settings',
      group: DesktopShortcutGroup.application,
      label: (l) => l.shortcutOpenSettings,
      macKeys: const ['⌘', ','],
      otherKeys: const ['Ctrl', ','],
    ),
    DesktopShortcutItem(
      id: 'open_local_bridge',
      group: DesktopShortcutGroup.application,
      label: (l) => l.shortcutOpenLocalBridge,
      macKeys: const ['⇧', '⌘', ','],
      otherKeys: const ['Ctrl', 'Shift', ','],
      macOnly: true,
    ),
    DesktopShortcutItem(
      id: 'show_shortcuts',
      group: DesktopShortcutGroup.application,
      label: (l) => l.shortcutShowShortcuts,
      macKeys: const ['⌘', '/'],
      otherKeys: const ['Ctrl', '/'],
    ),

    // Navigation
    DesktopShortcutItem(
      id: 'new_session',
      group: DesktopShortcutGroup.navigation,
      label: (l) => l.shortcutNewSession,
      macKeys: const ['⌘', 'N'],
      otherKeys: const ['Ctrl', 'N'],
    ),
    DesktopShortcutItem(
      id: 'quick_search',
      group: DesktopShortcutGroup.navigation,
      label: (l) => l.shortcutQuickSearch,
      macKeys: const ['⌘', 'K'],
      otherKeys: const ['Ctrl', 'K'],
    ),
    DesktopShortcutItem(
      id: 'switch_session_number',
      group: DesktopShortcutGroup.navigation,
      label: (l) => l.shortcutSwitchSessionNumber,
      macKeys: const ['⌘', '1–9'],
      otherKeys: const ['Ctrl', '1–9'],
    ),
    DesktopShortcutItem(
      id: 'close_active',
      group: DesktopShortcutGroup.navigation,
      label: (l) => l.shortcutCloseActive,
      macKeys: const ['⌘', 'W'],
      otherKeys: const ['Ctrl', 'W'],
    ),
    DesktopShortcutItem(
      id: 'refresh',
      group: DesktopShortcutGroup.navigation,
      label: (l) => l.shortcutRefresh,
      macKeys: const ['⌘', 'R'],
      otherKeys: const ['Ctrl', 'R'],
    ),

    // Session
    DesktopShortcutItem(
      id: 'approve_tool',
      group: DesktopShortcutGroup.session,
      label: (l) => l.shortcutApproveTool,
      macKeys: const ['⌘', '↩'],
      otherKeys: const ['Ctrl', 'Enter'],
    ),
    DesktopShortcutItem(
      id: 'permission_mode',
      group: DesktopShortcutGroup.session,
      label: (l) => l.shortcutPermissionMode,
      macKeys: const ['⇧', '⌘', 'P'],
      otherKeys: const ['Ctrl', 'Shift', 'P'],
    ),
    DesktopShortcutItem(
      id: 'stop_generation',
      group: DesktopShortcutGroup.session,
      label: (l) => l.shortcutStopGeneration,
      macKeys: const ['⌘', '.'],
      otherKeys: const ['Ctrl', '.'],
    ),

    // View & Panes
    DesktopShortcutItem(
      id: 'toggle_sidebar',
      group: DesktopShortcutGroup.viewPanes,
      label: (l) => l.shortcutToggleSidebar,
      macKeys: const ['⌘', r'\'],
      otherKeys: const ['Ctrl', r'\'],
    ),
    DesktopShortcutItem(
      id: 'toggle_git',
      group: DesktopShortcutGroup.viewPanes,
      label: (l) => l.shortcutToggleGitPane,
      macKeys: const ['⇧', '⌘', 'G'],
      otherKeys: const ['Ctrl', 'Shift', 'G'],
    ),
    DesktopShortcutItem(
      id: 'toggle_explorer',
      group: DesktopShortcutGroup.viewPanes,
      label: (l) => l.shortcutToggleExplorerPane,
      macKeys: const ['⇧', '⌘', 'E'],
      otherKeys: const ['Ctrl', 'Shift', 'E'],
    ),
    DesktopShortcutItem(
      id: 'toggle_gallery',
      group: DesktopShortcutGroup.viewPanes,
      label: (l) => l.shortcutToggleGalleryPane,
      macKeys: const ['⇧', '⌘', 'I'],
      otherKeys: const ['Ctrl', 'Shift', 'I'],
    ),
    DesktopShortcutItem(
      id: 'zoom_in',
      group: DesktopShortcutGroup.viewPanes,
      label: (l) => l.shortcutZoomIn,
      macKeys: const ['⌘', '+'],
      otherKeys: const ['Ctrl', '+'],
    ),
    DesktopShortcutItem(
      id: 'zoom_out',
      group: DesktopShortcutGroup.viewPanes,
      label: (l) => l.shortcutZoomOut,
      macKeys: const ['⌘', '-'],
      otherKeys: const ['Ctrl', '-'],
    ),
    DesktopShortcutItem(
      id: 'zoom_reset',
      group: DesktopShortcutGroup.viewPanes,
      label: (l) => l.shortcutZoomReset,
      macKeys: const ['⌘', '0'],
      otherKeys: const ['Ctrl', '0'],
    ),

    // Composer & Editing
    DesktopShortcutItem(
      id: 'send_message',
      group: DesktopShortcutGroup.composer,
      label: (l) => l.shortcutSendMessage,
      macKeys: const ['↩'],
      otherKeys: const ['Enter'],
    ),
    DesktopShortcutItem(
      id: 'insert_newline',
      group: DesktopShortcutGroup.composer,
      label: (l) => l.shortcutInsertNewline,
      macKeys: const ['⇧', '↩'],
      otherKeys: const ['Shift', 'Enter'],
    ),
    DesktopShortcutItem(
      id: 'find_in_browser',
      group: DesktopShortcutGroup.composer,
      label: (l) => l.shortcutFindInBrowser,
      macKeys: const ['⌘', 'F'],
      otherKeys: const ['Ctrl', 'F'],
    ),
    DesktopShortcutItem(
      id: 'dismiss_overlay',
      group: DesktopShortcutGroup.composer,
      label: (l) => l.shortcutDismissOverlay,
      macKeys: const ['Esc'],
      otherKeys: const ['Esc'],
    ),
  ];

  static List<DesktopShortcutItem> itemsForGroup(
    DesktopShortcutGroup group, {
    required bool isMacOS,
  }) => [
    for (final item in items)
      if (item.group == group && (!item.macOnly || isMacOS)) item,
  ];

  static String groupTitle(DesktopShortcutGroup group, AppLocalizations l) =>
      switch (group) {
        DesktopShortcutGroup.application => l.shortcutsGroupApplication,
        DesktopShortcutGroup.navigation => l.shortcutsGroupNavigation,
        DesktopShortcutGroup.session => l.shortcutsGroupSession,
        DesktopShortcutGroup.viewPanes => l.shortcutsGroupViewPanes,
        DesktopShortcutGroup.composer => l.shortcutsGroupComposer,
      };
}

/// Visual keycap pills (e.g. `⌘` `,` on macOS or `Ctrl` `+` `,` elsewhere).
class ShortcutKeyCaps extends StatelessWidget {
  const ShortcutKeyCaps({super.key, required this.keys});

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, keyLabel) in keys.indexed) ...[
          if (index > 0) const SizedBox(width: 4),
          Container(
            constraints: const BoxConstraints(minWidth: 26, minHeight: 24),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
            child: Text(
              keyLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Categorized list of desktop keyboard shortcuts rendered inside Settings.
class ShortcutsSettingsSection extends StatelessWidget {
  const ShortcutsSettingsSection({super.key, this.isMacOS});

  /// Overrides platform detection (tests).
  final bool? isMacOS;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final useMacOS = isMacOS ?? isMacOSPlatform;
    return SettingsItem(
      id: SettingsEntryIds.keyboardShortcuts,
      framed: true,
      child: Column(
        key: const ValueKey('shortcuts_settings_section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final group in DesktopShortcutGroup.values)
            _ShortcutGroupCard(
              title: DesktopShortcutCatalog.groupTitle(group, l),
              items: DesktopShortcutCatalog.itemsForGroup(
                group,
                isMacOS: useMacOS,
              ),
              isMacOS: useMacOS,
            ),
        ],
      ),
    );
  }
}

class _ShortcutGroupCard extends StatelessWidget {
  const _ShortcutGroupCard({
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
    if (items.isEmpty) return const SizedBox.shrink();
    return SettingsGroup(
      title: title,
      children: [
        for (final item in items)
          ShortcutReferenceRow(
            key: ValueKey('shortcut_row_${item.id}'),
            label: item.label(l),
            keys: item.keysFor(isMacOS: isMacOS),
          ),
      ],
    );
  }
}

/// Single label + keycap row reused by Settings and [KeyboardShortcutsDialog].
class ShortcutReferenceRow extends StatelessWidget {
  const ShortcutReferenceRow({
    super.key,
    required this.label,
    required this.keys,
  });

  final String label;
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 12),
          ShortcutKeyCaps(keys: keys),
        ],
      ),
    );
  }
}
