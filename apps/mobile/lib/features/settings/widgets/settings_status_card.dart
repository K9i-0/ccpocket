import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';
import '../../../providers/machine_manager_cubit.dart';
import '../../../services/bridge_service.dart';
import '../models/settings_catalog.dart';
import '../sections/connection_settings_section.dart';
import '../state/settings_state.dart';
import 'bridge_update_status_tile.dart';
import 'settings_category_visuals.dart';
import 'settings_tiles.dart';
import 'usage_section.dart';

/// Hero card at the top of settings: Bridge status and plan usage at a glance.
class SettingsStatusCard extends StatelessWidget {
  const SettingsStatusCard({
    super.key,
    required this.state,
    required this.visibility,
    required this.onOpenCategory,
    required this.onUpdateBridge,
  });

  final SettingsState state;
  final SettingsVisibility visibility;
  final ValueChanged<SettingsCategory> onOpenCategory;
  final ValueChanged<MachineWithStatus> onUpdateBridge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = SettingsCategory.connection.color(theme.brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: 0.16),
                cs.surfaceContainerLow,
              ),
              Color.alphaBlend(
                cs.primary.withValues(alpha: 0.10),
                cs.surfaceContainerLow,
              ),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (visibility.hasActiveMachine)
                _ConnectedStatus(
                  state: state,
                  visibility: visibility,
                  accent: accent,
                  onOpenCategory: onOpenCategory,
                  onUpdateBridge: onUpdateBridge,
                )
              else
                _DisconnectedStatus(accent: accent),
              if (visibility.bridgeConnected) ...[
                Divider(
                  height: 1,
                  indent: 18,
                  endIndent: 18,
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
                // Plan usage lives here instead of on its own page, so the
                // usage shortcut on the home screen is a single hop back.
                SettingsItem(
                  id: SettingsEntryIds.usage,
                  child: UsageSection(
                    bridgeService: context.read<BridgeService>(),
                    embedded: true,
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DisconnectedStatus extends StatelessWidget {
  const _DisconnectedStatus({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('settings_status_disconnected'),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SettingsCategoryBadge(
            icon: Icons.link_off_rounded,
            color: theme.colorScheme.outline,
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.settingsStatusDisconnectedTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.settingsStatusDisconnectedBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedStatus extends StatelessWidget {
  const _ConnectedStatus({
    required this.state,
    required this.visibility,
    required this.accent,
    required this.onOpenCategory,
    required this.onUpdateBridge,
  });

  final SettingsState state;
  final SettingsVisibility visibility;
  final Color accent;
  final ValueChanged<SettingsCategory> onOpenCategory;
  final ValueChanged<MachineWithStatus> onUpdateBridge;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bridge = context.read<BridgeService>();
    final machineState = context.watch<MachineManagerCubit>().state;
    final machineWithStatus = activeMachineWithStatus(
      machineState,
      state.activeMachineId,
    );
    final machine = machineWithStatus?.machine;
    final isUpdating =
        machine != null && machineState.updatingMachineId == machine.id;
    final updateStatus = BridgeUpdateStatus.resolve(
      machineWithStatus: machineWithStatus,
      latestBridgeVersion: machineState.latestBridgeVersion,
      isCheckingLatestBridgeVersion: machineState.isCheckingLatestBridgeVersion,
      latestBridgeVersionError: machineState.latestBridgeVersionError,
    );
    final title =
        machine?.displayName ?? bridge.lastUrl ?? l.settingsNotConnected;
    final subtitle = machine != null ? bridge.lastUrl : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const ValueKey('settings_status_card'),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          onTap: () => onOpenCategory(SettingsCategory.connection),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SettingsCategoryBadge(
                      icon: Icons.computer_rounded,
                      color: accent,
                      size: 44,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(
                      status: machineWithStatus?.status,
                      connected: visibility.bridgeConnected,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _VersionChip(
                          version: updateStatus.currentVersion,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isUpdating)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (updateStatus.needsUpdate &&
                        machineWithStatus != null)
                      FilledButton.tonalIcon(
                        key: const ValueKey('settings_status_update_button'),
                        onPressed: () => onUpdateBridge(machineWithStatus),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: const Icon(Icons.system_update_rounded, size: 18),
                        label: Text(l.update),
                      )
                    else if (updateStatus.bridgeNeedsUpdate)
                      _InlineStatus(
                        icon: Icons.system_update_rounded,
                        color: cs.tertiary,
                        label: l.bridgeUpdateAvailable,
                      )
                    else if (updateStatus.isKnownUpToDate)
                      _InlineStatus(
                        icon: Icons.check_circle_rounded,
                        color: settingsSuccessColor(theme.brightness),
                        label: l.bridgeIsUpToDate,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.connected});

  final MachineStatus? status;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final online = connected || status == MachineStatus.online;
    final checking =
        !online && (status == null || status == MachineStatus.unknown);
    final color = online
        ? settingsSuccessColor(theme.brightness)
        : checking
        ? theme.colorScheme.outline
        : theme.colorScheme.error;
    final label = online
        ? l.settingsStatusOnline
        : checking
        ? l.settingsStatusChecking
        : l.settingsStatusOffline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({required this.version});

  final String? version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        version == null ? 'Bridge' : 'Bridge v$version',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
