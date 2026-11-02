import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../services/app_update_service.dart';
import '../../../widgets/workspace_pane_chrome.dart';

/// Floating SliverAppBar for the session list screen.
///
/// Hides on scroll-down and snaps back on scroll-up (Material 3
/// enterAlways behaviour).
class SessionListSliverAppBar extends StatelessWidget {
  final VoidCallback onTitleTap;
  final VoidCallback onDisconnect;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenGallery;
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
    this.onOpenGallery,
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
                  child: _BridgeMenuButton(
                    bridgeLabel: bridgeLabel,
                    onOpenSettings:
                        onOpenSettings ??
                        () => context.router.navigate(SettingsRoute()),
                    onOpenGallery:
                        onOpenGallery ??
                        () => context.router.navigate(GalleryRoute()),
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
                () => context.router.navigate(SettingsRoute()),
            tooltip: l.settings,
          ),
          IconButton(
            key: const ValueKey('gallery_button'),
            icon: const Icon(Icons.collections),
            onPressed:
                onOpenGallery ?? () => context.router.navigate(GalleryRoute()),
            tooltip: l.gallery,
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
  final VoidCallback? onOpenGallery;
  final VoidCallback? onDisconnect;
  final String? bridgeLabel;

  /// False when the actions live in the iPhone Duo control strip instead.
  final bool showActions;

  const SessionListPaneHeader({
    super.key,
    required this.onTitleTap,
    required this.onOpenSettings,
    this.onOpenGallery,
    this.onDisconnect,
    this.bridgeLabel,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final openGallery = onOpenGallery;
    final disconnect = onDisconnect;
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

        return SizedBox(
          height: chrome.toolbarHeight,
          child: Padding(
            padding: chrome.headerPadding(
              trailing: chrome.useMacOSAdaptiveChrome || !narrow ? 8 : 0,
            ),
            child: Row(
              children: [
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
                    child: _BridgeMenuButton(
                      bridgeLabel: bridgeLabel,
                      onOpenSettings: onOpenSettings,
                      onOpenGallery: onOpenGallery,
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
                  ),
                  if (openGallery != null)
                    _PaneHeaderActionButton(
                      key: const ValueKey('gallery_button'),
                      tooltip: l.gallery,
                      onPressed: openGallery,
                      icon: const Icon(Icons.collections_outlined),
                      compact: chrome.useMacOSAdaptiveChrome,
                    ),
                  if (disconnect != null)
                    _PaneHeaderActionButton(
                      key: const ValueKey('disconnect_button'),
                      tooltip: l.disconnect,
                      onPressed: disconnect,
                      icon: const Icon(Icons.link_off),
                      compact: chrome.useMacOSAdaptiveChrome,
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

  const _PaneHeaderActionButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      // Match the chat AppBar actions in the adjacent pane.
      iconSize: compact ? 18 : null,
      color: compact ? Theme.of(context).colorScheme.onSurfaceVariant : null,
      padding: compact ? EdgeInsets.zero : null,
      constraints: compact
          ? const BoxConstraints(minWidth: 32, minHeight: 32)
          : null,
      visualDensity: compact ? null : VisualDensity.compact,
      onPressed: onPressed,
      tooltip: tooltip,
      icon: icon,
    );
  }
}

/// The bridge label of the title row, opening the actions that left the app
/// bar for the iPhone Duo control strip: gallery, settings and disconnect.
class _BridgeMenuButton extends StatelessWidget {
  const _BridgeMenuButton({
    required this.bridgeLabel,
    required this.onOpenSettings,
    required this.onOpenGallery,
    required this.onDisconnect,
  });

  final String? bridgeLabel;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenGallery;
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
        if (onOpenGallery case final openGallery?)
          PopupMenuItem(
            key: const ValueKey('gallery_button'),
            value: openGallery,
            child: ListTile(
              leading: const Icon(Icons.collections_outlined),
              title: Text(l.gallery),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
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
