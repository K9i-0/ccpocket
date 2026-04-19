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
          onPressed: () => context.router.push(SettingsRoute()),
          tooltip: l.settings,
        ),
        IconButton(
          key: const ValueKey('gallery_button'),
          icon: const Icon(Icons.collections),
          onPressed: () => context.router.push(GalleryRoute()),
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
  final VoidCallback? onNewSession;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenGallery;
  final VoidCallback? onDisconnect;

  const SessionListPaneHeader({
    super.key,
    required this.onTitleTap,
    this.onNewSession,
    required this.onOpenSettings,
    this.onOpenGallery,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onTitleTap,
                  child: Text(
                    l.appTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('settings_button'),
                icon: Badge(
                  isLabelVisible:
                      AppUpdateService.instance.cachedUpdate != null,
                  smallSize: 8,
                  child: const Icon(Icons.settings),
                ),
                onPressed: onOpenSettings,
                tooltip: l.settings,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onNewSession != null)
                FilledButton.icon(
                  key: const ValueKey('new_session_header_button'),
                  onPressed: onNewSession,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              if (onOpenGallery != null)
                OutlinedButton.icon(
                  key: const ValueKey('gallery_button'),
                  onPressed: onOpenGallery,
                  icon: const Icon(Icons.collections_outlined, size: 18),
                  label: Text(l.gallery),
                ),
              if (onDisconnect != null)
                IconButton(
                  key: const ValueKey('disconnect_button'),
                  icon: const Icon(Icons.link_off),
                  onPressed: onDisconnect,
                  tooltip: l.disconnect,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
