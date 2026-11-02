import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';
import '../../../models/messages.dart';
import '../../../providers/machine_manager_cubit.dart';
import '../../../services/bridge_service.dart';
import '../models/settings_catalog.dart';
import '../sections/connection_settings_section.dart';
import '../state/settings_cubit.dart';
import '../state/settings_state.dart';
import 'bridge_update_status_tile.dart';
import 'settings_category_visuals.dart';
import 'settings_tiles.dart';

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
          child: visibility.hasActiveMachine
              ? _ConnectedStatus(
                  state: state,
                  visibility: visibility,
                  accent: accent,
                  onOpenCategory: onOpenCategory,
                  onUpdateBridge: onUpdateBridge,
                )
              : _DisconnectedStatus(accent: accent),
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
        if (visibility.bridgeConnected)
          _UsageGlance(
            bridge: bridge,
            onTap: () => onOpenCategory(SettingsCategory.usage),
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

/// Compact usage bars. Reads cached results only; fetching is owned by the
/// usage page so opening settings never sends an extra request.
class _UsageGlance extends StatelessWidget {
  const _UsageGlance({required this.bridge, required this.onTap});

  final BridgeService bridge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UsageResultMessage>(
      stream: bridge.usageResults,
      initialData: bridge.lastUsageResult,
      builder: (context, snapshot) {
        final providers = [
          for (final info in snapshot.data?.providers ?? const <UsageInfo>[])
            if (info.hasData) info,
        ];
        if (providers.isEmpty) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final mode = context.select(
          (SettingsCubit cubit) => cubit.state.usageDisplayMode,
        );
        return InkWell(
          key: const ValueKey('settings_status_usage'),
          onTap: onTap,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(22),
          ),
          child: Column(
            children: [
              Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: cs.outlineVariant.withValues(alpha: 0.6),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                child: Column(
                  children: [
                    for (final (index, info) in providers.indexed) ...[
                      if (index > 0) const SizedBox(height: 8),
                      _UsageBar(info: info, mode: mode),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.info, required this.mode});

  final UsageInfo info;
  final UsageDisplayMode mode;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final window = info.fiveHour ?? info.sevenDay!;
    final windowLabel = info.fiveHour != null
        ? l.usageFiveHour
        : l.usageSevenDay;
    final used = window.utilization.clamp(0, 100).toDouble();
    final shown = mode == UsageDisplayMode.remaining ? 100 - used : used;
    final barColor = used >= 90
        ? cs.error
        : used >= 70
        ? const Color(0xFFF59E0B)
        : SettingsCategory.usage.color(theme.brightness);
    final name = info.provider.isEmpty
        ? info.provider
        : info.provider[0].toUpperCase() + info.provider.substring(1);
    final modeLabel = mode == UsageDisplayMode.remaining
        ? l.usageDisplayModeRemaining
        : l.usageDisplayModeUsed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$modeLabel · $windowLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${shown.round()}%',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: shown / 100,
            minHeight: 7,
            color: barColor,
            backgroundColor: cs.surface.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
