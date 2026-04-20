import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../services/app_update_service.dart';

/// Floating SliverAppBar for the session list screen.
///
/// Hides on scroll-down and snaps back on scroll-up (Material 3
/// enterAlways behaviour).
class SessionListSliverAppBar extends StatelessWidget {
  final VoidCallback onTitleTap;
  final VoidCallback onDisconnect;
  final bool forceElevated;

  const SessionListSliverAppBar({
    super.key,
    required this.onTitleTap,
    required this.onDisconnect,
    this.forceElevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SliverAppBar(
      floating: true,
      snap: true,
      forceElevated: forceElevated,
      title: GestureDetector(onTap: onTitleTap, child: Text(l.appTitle)),
      actions: [
        IconButton(
          key: const ValueKey('settings_button'),
          icon: Badge(
            isLabelVisible: AppUpdateService.instance.cachedUpdate != null,
            smallSize: 8,
            child: const Icon(Icons.settings),
          ),
          onPressed: () => context.router.navigate(SettingsRoute()),
          tooltip: l.settings,
        ),
        IconButton(
          key: const ValueKey('gallery_button'),
          icon: const Icon(Icons.collections),
          onPressed: () => context.router.navigate(GalleryRoute()),
          tooltip: l.gallery,
        ),
        IconButton(
          key: const ValueKey('disconnect_button'),
          icon: const Icon(Icons.link_off),
          onPressed: onDisconnect,
          tooltip: l.disconnect,
        ),
      ],
    );
  }
}

class SessionListPaneHeader extends StatelessWidget {
  final VoidCallback onTitleTap;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenGallery;
  final VoidCallback? onDisconnect;
  final VoidCallback? onTogglePaneVisibility;

  const SessionListPaneHeader({
    super.key,
    required this.onTitleTap,
    required this.onOpenSettings,
    this.onOpenGallery,
    this.onDisconnect,
    this.onTogglePaneVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final openGallery = onOpenGallery;
    final disconnect = onDisconnect;
    final togglePaneVisibility = onTogglePaneVisibility;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTitleTap,
              child: Text(
                l.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
          ),
          _PaneHeaderActionButton(
            key: const ValueKey('settings_button'),
            tooltip: l.settings,
            onPressed: onOpenSettings,
            icon: Badge(
              isLabelVisible: AppUpdateService.instance.cachedUpdate != null,
              smallSize: 8,
              child: const Icon(Icons.settings),
            ),
          ),
          if (openGallery != null)
            _PaneHeaderActionButton(
              key: const ValueKey('gallery_button'),
              tooltip: l.gallery,
              onPressed: openGallery,
              icon: const Icon(Icons.collections_outlined),
            ),
          if (disconnect != null)
            _PaneHeaderActionButton(
              key: const ValueKey('disconnect_button'),
              tooltip: l.disconnect,
              onPressed: disconnect,
              icon: const Icon(Icons.link_off),
            ),
          if (togglePaneVisibility != null)
            _PaneHeaderActionButton(
              key: const ValueKey('collapse_left_pane_button'),
              tooltip: 'Hide sessions',
              onPressed: togglePaneVisibility,
              icon: const Icon(Icons.chevron_left),
            ),
        ],
      ),
    );
  }
}

class _PaneHeaderActionButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;
  final Widget icon;

  const _PaneHeaderActionButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      tooltip: tooltip,
      icon: icon,
    );
  }
}
