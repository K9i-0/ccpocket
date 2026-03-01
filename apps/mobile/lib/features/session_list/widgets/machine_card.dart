import 'package:flutter/material.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';
import '../../../theme/app_theme.dart';

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
    this.isStarting = false,
    this.isUpdating = false,
  });

  Machine get machine => machineWithStatus.machine;
  MachineStatus get status => machineWithStatus.status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final needsUpdate = machineWithStatus.needsUpdate(
      AppConstants.expectedBridgeVersion,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // Subtle highlight for favorites
      color: machine.isFavorite
          ? colorScheme.primaryContainer.withValues(alpha: 0.15)
          : null,
      child: InkWell(
        onTap: status == MachineStatus.online ? onConnect : null,
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
                    isUpdating: isUpdating,
                    needsUpdate: needsUpdate,
                    onConnect: onConnect,
                    onStart: onStart,
                    onUpdate: onUpdate,
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
                    needsUpdate: needsUpdate,
                    colorScheme: colorScheme,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onToggleFavorite: onToggleFavorite,
                    onUpdate: onUpdate,
                    onStop: onStop,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

    return Container(
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
      return Row(
        children: [
          Icon(Icons.error_outline, size: 12, color: colorScheme.error),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              lastError!,
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
      parts.add(TextSpan(text: '${machine.host}:${machine.port}'));
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

    return Text.rich(
      TextSpan(children: parts),
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.outline,
        fontSize: 12,
      ),
      overflow: TextOverflow.ellipsis,
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
  final bool needsUpdate;
  final ColorScheme colorScheme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onUpdate;
  final VoidCallback? onStop;

  const _MenuButton({
    required this.machine,
    required this.needsUpdate,
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
      width: 32,
      height: 32,
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
          if (needsUpdate && machine.canStartRemotely)
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
          if (machine.canStartRemotely)
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
  final bool isUpdating;
  final bool needsUpdate;
  final VoidCallback onConnect;
  final VoidCallback onStart;
  final VoidCallback? onUpdate;

  const _ActionButton({
    required this.status,
    required this.canStartRemotely,
    required this.isStarting,
    this.isUpdating = false,
    this.needsUpdate = false,
    required this.onConnect,
    required this.onStart,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    // Show updating spinner
    if (isUpdating) {
      return SizedBox(
        width: 80,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.tertiary,
            ),
          ),
        ),
      );
    }

    if (status == MachineStatus.online) {
      // If needs update and SSH available, show Update button
      if (needsUpdate && canStartRemotely && onUpdate != null) {
        return FilledButton.tonal(
          onPressed: onUpdate,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 36),
            backgroundColor: colorScheme.tertiary.withValues(alpha: 0.15),
            foregroundColor: colorScheme.tertiary,
          ),
          child: Text(l.update),
        );
      }

      return FilledButton(
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
