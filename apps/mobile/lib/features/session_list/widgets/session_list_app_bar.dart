import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../services/app_update_service.dart';
import '../../../utils/platform_helper.dart';
import '../../../widgets/workspace_pane_chrome.dart';

/// Floating SliverAppBar for the session list screen.
///
/// Hides on scroll-down and snaps back on scroll-up (Material 3
/// enterAlways behaviour).
class SessionListSliverAppBar extends StatelessWidget {
  final VoidCallback onTitleTap;
  final VoidCallback onDisconnect;
  final VoidCallback? onOpenSettings;
  final bool forceElevated;
  final double? toolbarHeight;
  final String? bridgeLabel;

  /// False when the actions live in the iPhone Duo control strip instead.
  final bool showActions;

  const SessionListSliverAppBar({
    super.key,
    required this.onTitleTap,
    required this.onDisconnect,
    this.onOpenSettings,
    this.forceElevated = false,
    this.toolbarHeight,
    this.bridgeLabel,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SliverAppBar(
      floating: true,
      snap: true,
      forceElevated: forceElevated,
      toolbarHeight: toolbarHeight ?? kToolbarHeight,
      title: showActions
          ? GestureDetector(
              onTap: onTitleTap,
              child: _SessionListTitle(
                title: l.appTitle,
                subtitle: bridgeLabel,
              ),
            )
          : Row(
              children: [
                GestureDetector(
                  onTap: onTitleTap,
                  child: _SessionListTitle(title: l.appTitle),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: SessionListBridgeMenuButton(
                    bridgeLabel: bridgeLabel,
                    onOpenSettings:
                        onOpenSettings ??
                        () => context.router.navigate(
                          SettingsRoute(
                            focusAppUpdate:
                                AppUpdateService.instance.cachedUpdate != null,
                          ),
                        ),
                    onDisconnect: onDisconnect,
                  ),
                ),
              ],
            ),
      actions: [
        if (showActions) ...[
          IconButton(
            key: const ValueKey('settings_button'),
            icon: Badge(
              isLabelVisible: AppUpdateService.instance.cachedUpdate != null,
              smallSize: 8,
              child: const Icon(Icons.settings),
            ),
            onPressed:
                onOpenSettings ??
                () => context.router.navigate(
                  SettingsRoute(
                    focusAppUpdate:
                        AppUpdateService.instance.cachedUpdate != null,
                  ),
                ),
            tooltip: l.settings,
          ),
          IconButton(
            key: const ValueKey('disconnect_button'),
            icon: const Icon(Icons.link_off),
            onPressed: onDisconnect,
            tooltip: l.disconnect,
          ),
        ],
      ],
    );
  }
}

class SessionListPaneHeader extends StatelessWidget {
  final VoidCallback onTitleTap;
  final VoidCallback onOpenSettings;
  final VoidCallback? onDisconnect;
  final VoidCallback? onToggleSidebar;
  final String? bridgeLabel;

  /// False when the actions live in the iPhone Duo control strip instead.
  final bool showActions;

  const SessionListPaneHeader({
    super.key,
    required this.onTitleTap,
    required this.onOpenSettings,
    this.onDisconnect,
    this.onToggleSidebar,
    this.bridgeLabel,
    this.showActions = true,
  });

  String _sidebarToggleTooltip(AppLocalizations l) {
    if (!isDesktopPlatform) return l.menuToggleSidebar;
    final shortcut = isMacOSPlatform ? r'⌘\' : r'Ctrl+\';
    return '${l.menuToggleSidebar} ($shortcut)';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final disconnect = onDisconnect;
    final toggleSidebar = onToggleSidebar;
    final chrome = resolveWorkspacePaneChrome(
      platform: Theme.of(context).platform,
      isAdaptiveWorkspace: true,
      isLeftPaneVisible: true,
      slot: WorkspacePaneSlot.left,
    );
    final titleStyle = Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w700);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 300;
        final tightMacOS =
            chrome.useMacOSAdaptiveChrome && constraints.maxWidth < 252;
        final headerPadding = tightMacOS
            ? EdgeInsets.fromLTRB(
                chrome.leadingInset + 4,
                kWorkspacePaneVerticalPadding,
                4,
                kWorkspacePaneVerticalPadding,
              )
            : chrome.headerPadding(
                trailing: chrome.useMacOSAdaptiveChrome || !narrow ? 8 : 0,
              );

        return SizedBox(
          height: chrome.toolbarHeight,
          child: Padding(
            padding: headerPadding,
            child: Row(
              children: [
                if (toggleSidebar != null && chrome.useMacOSAdaptiveChrome)
                  _PaneHeaderActionButton(
                    key: const ValueKey('sidebar_toggle_button'),
                    tooltip: _sidebarToggleTooltip(l),
                    onPressed: toggleSidebar,
                    icon: const Icon(Icons.view_sidebar_outlined),
                    compact: true,
                    tight: tightMacOS,
                  ),
                if (!showActions) ...[
                  GestureDetector(
                    onTap: onTitleTap,
                    child: _SessionListTitle(
                      key: const ValueKey('session_list_pane_title'),
                      title: l.appTitle,
                      titleStyle: titleStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: SessionListBridgeMenuButton(
                      bridgeLabel: bridgeLabel,
                      onOpenSettings: onOpenSettings,
                      onDisconnect: onDisconnect,
                    ),
                  ),
                ] else if (!chrome.useMacOSAdaptiveChrome)
                  Expanded(
                    child: GestureDetector(
                      onTap: onTitleTap,
                      child: _SessionListTitle(
                        key: const ValueKey('session_list_pane_title'),
                        title: l.appTitle,
                        subtitle: bridgeLabel,
                        titleStyle: titleStyle,
                      ),
                    ),
                  )
                else
                  const Expanded(
                    child: MacOSWindowDragHandle(child: SizedBox.expand()),
                  ),
                if (showActions) ...[
                  if (toggleSidebar != null && !chrome.useMacOSAdaptiveChrome)
                    _PaneHeaderActionButton(
                      key: const ValueKey('sidebar_toggle_button'),
                      tooltip: _sidebarToggleTooltip(l),
                      onPressed: toggleSidebar,
                      icon: const Icon(Icons.view_sidebar_outlined),
                      compact: false,
                    ),
                  _PaneHeaderActionButton(
                    key: const ValueKey('settings_button'),
                    tooltip: l.settings,
                    onPressed: onOpenSettings,
                    icon: Badge(
                      isLabelVisible:
                          AppUpdateService.instance.cachedUpdate != null,
                      smallSize: 8,
                      child: const Icon(Icons.settings),
                    ),
                    compact: chrome.useMacOSAdaptiveChrome,
                    tight: tightMacOS,
                  ),
                  if (disconnect != null)
                    _PaneHeaderActionButton(
                      key: const ValueKey('disconnect_button'),
                      tooltip: l.disconnect,
                      onPressed: disconnect,
                      icon: const Icon(Icons.link_off),
                      compact: chrome.useMacOSAdaptiveChrome,
                      tight: tightMacOS,
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SessionListTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;

  const _SessionListTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final theme = Theme.of(context);
    final defaultTitleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    if (subtitle == null || subtitle.isEmpty) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: titleStyle ?? defaultTitleStyle,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle ?? defaultTitleStyle,
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _PaneHeaderActionButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;
  final Widget icon;
  final bool compact;
  final bool tight;

  const _PaneHeaderActionButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.compact = false,
    this.tight = false,
  });

  @override
  Widget build(BuildContext context) {
    final extent = tight ? 28.0 : 32.0;
    return IconButton(
      // Match the chat AppBar actions in the adjacent pane.
      iconSize: compact ? 18 : null,
      color: compact ? Theme.of(context).colorScheme.onSurfaceVariant : null,
      style: compact
          ? IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              minimumSize: Size.square(extent),
              maximumSize: Size.square(extent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            )
          : null,
      padding: compact ? EdgeInsets.zero : null,
      constraints: compact
          ? BoxConstraints.tightFor(width: extent, height: extent)
          : null,
      visualDensity: compact ? null : VisualDensity.compact,
      onPressed: onPressed,
      tooltip: tooltip,
      icon: icon,
    );
  }
}

/// The bridge label of the title row, opening the actions that left the app
/// bar for the iPhone Duo control strip: settings and disconnect.
class SessionListBridgeMenuButton extends StatelessWidget {
  const SessionListBridgeMenuButton({
    super.key,
    required this.bridgeLabel,
    required this.onOpenSettings,
    required this.onDisconnect,
  });

  final String? bridgeLabel;
  final VoidCallback onOpenSettings;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasUpdate = AppUpdateService.instance.cachedUpdate != null;
    final label = bridgeLabel;

    return PopupMenuButton<VoidCallback>(
      key: const ValueKey('session_list_bridge_menu'),
      tooltip: l.settings,
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        PopupMenuItem(
          key: const ValueKey('settings_button'),
          value: onOpenSettings,
          child: ListTile(
            leading: Badge(
              isLabelVisible: hasUpdate,
              smallSize: 8,
              child: const Icon(Icons.settings),
            ),
            title: Text(l.settings),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (onDisconnect case final disconnect?) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            key: const ValueKey('disconnect_button'),
            value: disconnect,
            child: ListTile(
              leading: Icon(Icons.link_off, color: cs.error),
              title: Text(l.disconnect, style: TextStyle(color: cs.error)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ],
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null && label.isNotEmpty)
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            Badge(
              isLabelVisible: hasUpdate,
              smallSize: 8,
              child: Icon(
                Icons.expand_more,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
