import 'package:material_ui/material_ui.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';
import '../../../utils/network_endpoint.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/adaptive_context_menu.dart';

/// Card widget for displaying a saved remote machine.
/// Uses a clean 2-row layout:
/// Row 1: Status dot + Name + Action button
/// Row 2: Metadata (host:port · version · last connected) + Menu
class MachineCard extends StatelessWidget {
  final MachineWithStatus machineWithStatus;
  final VoidCallback onConnect;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onUpdate;
  final VoidCallback? onStop;
  final String? latestBridgeVersion;
  final bool isStarting;
  final bool isUpdating;

  const MachineCard({
    super.key,
    required this.machineWithStatus,
    required this.onConnect,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
    this.onToggleFavorite,
    this.onUpdate,
    this.onStop,
    this.latestBridgeVersion,
    this.isStarting = false,
    this.isUpdating = false,
  });

  Machine get machine => machineWithStatus.machine;
  MachineStatus get status => machineWithStatus.status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final updateTargetVersion =
        latestBridgeVersion != null &&
            compareSemanticVersions(
                  latestBridgeVersion!,
                  AppConstants.expectedBridgeVersion,
                ) >
                0
        ? latestBridgeVersion!
        : AppConstants.expectedBridgeVersion;
    final needsUpdate = machineWithStatus.needsUpdate(updateTargetVersion);
    final canUpdateOverSsh = machineWithStatus.canUpdateOverSsh(
      updateTargetVersion,
    );

    return AdaptiveContextMenuRegion(
      onOpen: (position) => _openContextMenu(
        context,
        position,
        canUpdateOverSsh: canUpdateOverSsh,
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        // Subtle highlight for favorites
        color: machine.isFavorite
            ? colorScheme.primaryContainer.withValues(alpha: 0.15)
            : null,
        child: InkWell(
          onTap: status == MachineStatus.online ? onConnect : null,
          mouseCursor: status == MachineStatus.online
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Status + Name + Action button
                Row(
                  children: [
                    _StatusDot(status: status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        machine.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ActionButton(
                      status: status,
                      canStartRemotely: machine.canStartRemotely,
                      isStarting: isStarting,
                      onConnect: onConnect,
                      onStart: onStart,
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Row 2: Metadata line + Menu
                Row(
                  children: [
                    // Align with name (status dot width + spacing)
                    const SizedBox(width: 24),
                    Expanded(
                      child: _MetadataLine(
                        machine: machine,
                        versionInfo: machineWithStatus.versionInfo,
                        needsUpdate: needsUpdate,
                        lastError: machineWithStatus.lastError,
                        status: status,
                      ),
                    ),
                    // Menu button
                    _MenuButton(
                      machine: machine,
                      status: status,
                      canUpdateOverSsh: canUpdateOverSsh,
                      canStopOverSsh: machineWithStatus.canStopOverSsh,
                      colorScheme: colorScheme,
                      onEdit: onEdit,
                      onDelete: onDelete,
                      onToggleFavorite: onToggleFavorite,
                      onUpdate: onUpdate,
                      onStop: onStop,
                    ),
                  ],
                ),
                if (machineWithStatus.needsApiKey) ...[
                  const SizedBox(height: 6),
                  Row(
                    key: const ValueKey('machine_api_key_required'),
                    children: [
                      const SizedBox(width: 24),
                      Icon(Icons.key, size: 14, color: colorScheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).machineApiKeyRequired,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openContextMenu(
    BuildContext context,
    Offset? position, {
    required bool canUpdateOverSsh,
  }) async {
    final l = AppLocalizations.of(context);
    final canStart =
        (status == MachineStatus.offline ||
            status == MachineStatus.unreachable) &&
        machine.canStartRemotely &&
        !isStarting;
    final canUpdate = canUpdateOverSsh && onUpdate != null;
    final canStop = machineWithStatus.canStopOverSsh && onStop != null;

    final action = await showAdaptiveActionMenu<String>(
      context: context,
      position: position,
      items: [
        if (status == MachineStatus.online)
          AdaptiveActionMenuItem(
            key: const ValueKey('machine_context_connect'),
            value: 'connect',
            icon: Icons.link,
            label: l.connect,
          ),
        if (canStart)
          AdaptiveActionMenuItem(
            key: const ValueKey('machine_context_start'),
            value: 'start',
            icon: Icons.play_arrow,
            label: l.start,
          ),
        if (onToggleFavorite != null)
          AdaptiveActionMenuItem(
            key: const ValueKey('machine_context_favorite'),
            value: 'favorite',
            icon: machine.isFavorite ? Icons.star : Icons.star_border,
            label: machine.isFavorite ? l.unfavorite : l.favorite,
          ),
        AdaptiveActionMenuItem(
          key: const ValueKey('machine_context_edit'),
          value: 'edit',
          icon: Icons.edit_outlined,
          label: l.edit,
        ),
        if (canUpdate)
          AdaptiveActionMenuItem(
            key: const ValueKey('machine_context_update'),
            value: 'update',
            icon: Icons.system_update,
            label: l.updateBridge,
          ),
        if (canStop)
          AdaptiveActionMenuItem(
            key: const ValueKey('machine_context_stop'),
            value: 'stop',
            icon: Icons.stop_circle_outlined,
            label: l.stopServer,
            destructive: true,
          ),
        AdaptiveActionMenuItem(
          key: const ValueKey('machine_context_delete'),
          value: 'delete',
          icon: Icons.delete_outline,
          label: l.delete,
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'connect':
        onConnect();
      case 'start':
        onStart();
      case 'favorite':
        onToggleFavorite?.call();
      case 'edit':
        onEdit();
      case 'update':
        onUpdate?.call();
      case 'stop':
        onStop?.call();
      case 'delete':
        onDelete();
    }
  }
}

/// Small status dot (12x12)
class _StatusDot extends StatelessWidget {
  final MachineStatus status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      MachineStatus.online => appColors.statusOnline,
      MachineStatus.offline => colorScheme.error,
      MachineStatus.unreachable => appColors.statusApproval,
      MachineStatus.unknown => appColors.statusIdle,
    };

    final l = AppLocalizations.of(context);
    final tooltipMessage = switch (status) {
      MachineStatus.online => l.settingsStatusOnline,
      MachineStatus.offline => l.offline,
      MachineStatus.unreachable => l.unreachable,
      MachineStatus.unknown => l.checking,
    };

    return Tooltip(
      message: tooltipMessage,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: status == MachineStatus.online
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// Metadata line showing host:port · version · last connected
class _MetadataLine extends StatelessWidget {
  final Machine machine;
  final BridgeVersionInfo? versionInfo;
  final bool needsUpdate;
  final String? lastError;
  final MachineStatus status;

  const _MetadataLine({
    required this.machine,
    this.versionInfo,
    required this.needsUpdate,
    this.lastError,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Show error if present and not online
    if (lastError != null && status != MachineStatus.online) {
      final displayError = switch (lastError) {
        machineErrorBridgeNotFound => l.machineErrorBridgeNotFound,
        machineErrorSecureConnectionUnavailable =>
          l.machineErrorSecureConnectionUnavailable,
        _ => lastError!,
      };
      return Row(
        children: [
          Icon(Icons.error_outline, size: 12, color: colorScheme.error),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              displayError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    // Build metadata parts
    final parts = <InlineSpan>[];

    // Host:Port (if name is set, show host:port; otherwise show last connected)
    if (machine.name != null) {
      parts.add(TextSpan(text: formatHostPort(machine.host, machine.port)));
    } else {
      // For auto-saved machines, show last connected time
      parts.add(TextSpan(text: _formatLastConnected(machine.lastConnected, l)));
    }

    // Version (if available)
    if (versionInfo != null) {
      parts.add(const TextSpan(text: ' · '));
      if (needsUpdate) {
        parts.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(Icons.update, size: 12, color: colorScheme.tertiary),
            ),
          ),
        );
      }
      parts.add(
        TextSpan(
          text: 'v${versionInfo!.version}',
          style: needsUpdate ? TextStyle(color: colorScheme.tertiary) : null,
        ),
      );
    }

    // Last connected (for named machines)
    if (machine.name != null && machine.lastConnected != null) {
      parts.add(const TextSpan(text: ' · '));
      parts.add(TextSpan(text: _formatLastConnected(machine.lastConnected, l)));
    }

    // Favorite indicator
    if (machine.isFavorite) {
      parts.add(const TextSpan(text: ' · '));
      parts.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            Icons.star,
            size: 12,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 280;
        return Text.rich(
          TextSpan(children: parts),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.outline,
            fontSize: isCompact ? 11 : 12,
            height: 1.25,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  String _formatLastConnected(DateTime? lastConnected, AppLocalizations l) {
    if (lastConnected == null) return l.neverConnected;
    final now = DateTime.now();
    final diff = now.difference(lastConnected);

    if (diff.inMinutes < 1) return l.justNow;
    if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.daysAgo(diff.inDays);
    return '${lastConnected.month}/${lastConnected.day}';
  }
}

/// Menu button (three dots)
class _MenuButton extends StatelessWidget {
  final Machine machine;
  final MachineStatus status;
  final bool canUpdateOverSsh;
  final bool canStopOverSsh;
  final ColorScheme colorScheme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onUpdate;
  final VoidCallback? onStop;

  const _MenuButton({
    required this.machine,
    required this.status,
    required this.canUpdateOverSsh,
    required this.canStopOverSsh,
    required this.colorScheme,
    required this.onEdit,
    required this.onDelete,
    this.onToggleFavorite,
    this.onUpdate,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      width: kMinInteractiveDimension,
      height: kMinInteractiveDimension,
      child: PopupMenuButton<String>(
        key: ValueKey('machine_menu_${machine.id}'),
        icon: Icon(Icons.more_horiz, color: colorScheme.outline, size: 20),
        padding: EdgeInsets.zero,
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'delete') onDelete();
          if (value == 'favorite') onToggleFavorite?.call();
          if (value == 'update') onUpdate?.call();
          if (value == 'stop') onStop?.call();
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'favorite',
            child: Row(
              children: [
                Icon(
                  machine.isFavorite ? Icons.star : Icons.star_border,
                  size: 20,
                  color: machine.isFavorite
                      ? Theme.of(context).colorScheme.tertiary
                      : null,
                ),
                const SizedBox(width: 8),
                Text(machine.isFavorite ? l.unfavorite : l.favorite),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit, size: 20),
                const SizedBox(width: 8),
                Text(l.edit),
              ],
            ),
          ),
          if (canUpdateOverSsh)
            PopupMenuItem(
              value: 'update',
              child: Row(
                children: [
                  const Icon(Icons.system_update, size: 20),
                  const SizedBox(width: 8),
                  Text(l.updateBridge),
                ],
              ),
            ),
          if (canStopOverSsh)
            PopupMenuItem(
              value: 'stop',
              child: Row(
                children: [
                  Icon(
                    Icons.stop_circle,
                    size: 20,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.stopServer,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 20, color: colorScheme.error),
                const SizedBox(width: 8),
                Text(l.delete, style: TextStyle(color: colorScheme.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button based on status
class _ActionButton extends StatelessWidget {
  final MachineStatus status;
  final bool canStartRemotely;
  final bool isStarting;
  final VoidCallback onConnect;
  final VoidCallback onStart;

  const _ActionButton({
    required this.status,
    required this.canStartRemotely,
    required this.isStarting,
    required this.onConnect,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (status == MachineStatus.online) {
      return FilledButton(
        key: const ValueKey('machine_connect_button'),
        onPressed: onConnect,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(0, 36),
        ),
        child: Text(l.connect),
      );
    }

    if ((status == MachineStatus.offline ||
            status == MachineStatus.unreachable) &&
        canStartRemotely) {
      if (isStarting) {
        return SizedBox(
          width: 80,
          height: 36,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
          ),
        );
      }

      return OutlinedButton(
        onPressed: onStart,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(0, 36),
        ),
        child: Text(l.start),
      );
    }

    // Offline without SSH or unreachable - show status chip
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _statusText(l),
        style: TextStyle(
          color: colorScheme.outline,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _statusText(AppLocalizations l) {
    return switch (status) {
      MachineStatus.offline => l.offline,
      MachineStatus.unreachable => l.unreachable,
      MachineStatus.unknown => l.checking,
      MachineStatus.online => '',
    };
  }
}
