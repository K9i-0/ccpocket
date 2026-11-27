import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';
import '../../../providers/machine_manager_cubit.dart';
import '../../../services/bridge_service.dart';
import '../../../utils/bridge_url_display.dart';
import '../../../widgets/workspace_pane_chrome.dart';
import '../../local_bridge/local_bridge_screen.dart';
import '../../session_list/widgets/machine_edit_sheet.dart';
import '../../session_list/workspace_shell_screen.dart';
import '../models/settings_catalog.dart';
import '../state/settings_state.dart';
import '../widgets/bridge_update_status_tile.dart';
import '../widgets/connected_bridge_tools_card.dart';
import '../widgets/local_url_settings_tile.dart';
import '../widgets/prompt_history_section.dart';
import '../widgets/settings_tiles.dart';

/// Finds the machine that the app is currently pointed at.
MachineWithStatus? activeMachineWithStatus(
  MachineManagerState machineState,
  String? activeMachineId,
) {
  if (activeMachineId == null) return null;
  for (final item in machineState.machines) {
    if (item.machine.id == activeMachineId) return item;
  }
  return null;
}

/// Whether [url] points at the loopback interface of this machine.
bool isLoopbackBridgeUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final host = Uri.tryParse(url)?.host.toLowerCase();
  return host == '127.0.0.1' || host == 'localhost' || host == '::1';
}

class ConnectionSettingsSection extends StatelessWidget {
  const ConnectionSettingsSection({
    super.key,
    required this.state,
    required this.visibility,
    required this.onUpdateBridge,
    this.onOpenLocalBridge,
    this.toolsHttpClient,
  });

  final SettingsState state;
  final SettingsVisibility visibility;
  final ValueChanged<MachineWithStatus> onUpdateBridge;

  /// Navigates to the inline "Bridge on this Mac" Settings category when
  /// available; falls back to pushing [LocalBridgeScreen].
  final VoidCallback? onOpenLocalBridge;

  /// Optional HTTP client override for [ConnectedBridgeToolsCard] (tests).
  final http.Client? toolsHttpClient;

  Future<void> _editConnectedMachine(
    BuildContext context,
    MachineWithStatus machineWithStatus,
  ) async {
    final cubit = context.read<MachineManagerCubit>();
    final apiKey = await cubit.getApiKey(machineWithStatus.machine.id);
    final sshPassword = await cubit.getSshPassword(
      machineWithStatus.machine.id,
    );
    final sshPrivateKey = await cubit.getSshPrivateKey(
      machineWithStatus.machine.id,
    );
    final sshJumpPassword = await cubit.getSshJumpPassword(
      machineWithStatus.machine.id,
    );
    final sshJumpPrivateKey = await cubit.getSshJumpPrivateKey(
      machineWithStatus.machine.id,
    );
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: macOSModalBottomSheetConstraints(context),
      backgroundColor: Colors.transparent,
      builder: (_) => MachineEditSheet(
        machine: machineWithStatus.machine,
        existingApiKey: apiKey,
        existingSshPassword: sshPassword,
        existingSshPrivateKey: sshPrivateKey,
        existingSshJumpPassword: sshJumpPassword,
        existingSshJumpPrivateKey: sshJumpPrivateKey,
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {
              await cubit.updateMachine(
                machine,
                apiKey: apiKey,
                sshPassword: sshPassword,
                sshPrivateKey: sshPrivateKey,
                sshJumpPassword: sshJumpPassword,
                sshJumpPrivateKey: sshJumpPrivateKey,
                clearCredentials:
                    !machine.sshEnabled ||
                    machine.sshAuthType !=
                        machineWithStatus.machine.sshAuthType,
                clearJumpCredentials:
                    machine.sshJumpHost == null ||
                    machine.sshJumpAuthType !=
                        machineWithStatus.machine.sshJumpAuthType,
              );
              await cubit.checkHealth(machine.id);
            },
        onTestConnection: cubit.testConnectionWithCredentials,
      ),
    );
  }

  Future<void> _copyBridgeUrl(BuildContext context, String url) async {
    final display = displayBridgeUrl(url) ?? url;
    await Clipboard.setData(ClipboardData(text: display));
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.copiedToClipboard)));
  }

  void _disconnectBridge(BuildContext context, BridgeService bridge) {
    bridge.disconnect();
    final shell = WorkspaceShellScreen.maybeOf(context);
    if (shell != null) {
      shell.popCenterOverlay();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bridge = context.read<BridgeService>();
    final machineManagerCubit = context.watch<MachineManagerCubit>();
    final machineState = machineManagerCubit.state;
    final machineWithStatus = activeMachineWithStatus(
      machineState,
      state.activeMachineId,
    );
    final machine = machineWithStatus?.machine;
    final isUpdating =
        machine != null && machineState.updatingMachineId == machine.id;
    final openLocalBridge =
        onOpenLocalBridge ?? () => openLocalBridgeScreen(context);
    final isLocalLoopback =
        visibility.isMacOS &&
        visibility.bridgeConnected &&
        machine?.sshEnabled != true &&
        isLoopbackBridgeUrl(bridge.lastUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLocalLoopback)
          _ConnectedToThisMacBanner(onOpenLocalBridge: openLocalBridge),
        SettingsGroup(
          title: visibility.hasActiveMachine
              ? l.settingsConnectedBridgeSectionTitle
              : null,
          cardKey: const ValueKey('settings_connection_section_card'),
          children: [
            if (visibility.hasActiveMachine)
              SettingsItem(
                id: SettingsEntryIds.bridgeMachine,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsNavTile(
                      key: const ValueKey('settings_bridge_machine_tile'),
                      icon: Icons.computer_rounded,
                      title: Text(l.settingsBridgeMachine),
                      subtitle:
                          machine?.displayName ??
                          (displayBridgeUrl(bridge.lastUrl) ??
                              l.settingsNotConnected),
                      onTap: machineWithStatus == null
                          ? null
                          : () => _editConnectedMachine(
                              context,
                              machineWithStatus,
                            ),
                    ),
                    _ConnectedBridgeActionStrip(
                      canEdit: machineWithStatus != null,
                      canReconnect: bridge.lastUrl != null,
                      canCopyUrl: bridge.lastUrl != null,
                      canDisconnect: visibility.bridgeConnected,
                      onEdit: machineWithStatus == null
                          ? null
                          : () => _editConnectedMachine(
                              context,
                              machineWithStatus,
                            ),
                      onReconnect: bridge.lastUrl == null
                          ? null
                          : () => bridge.connect(bridge.lastUrl!),
                      onCopyUrl: bridge.lastUrl == null
                          ? null
                          : () => _copyBridgeUrl(context, bridge.lastUrl!),
                      onDisconnect: visibility.bridgeConnected
                          ? () => _disconnectBridge(context, bridge)
                          : null,
                    ),
                  ],
                ),
              ),
            if (visibility.isMacOS)
              SettingsItem(
                id: SettingsEntryIds.localBridge,
                child: SettingsNavTile(
                  key: const ValueKey('settings_local_bridge_tile'),
                  icon: Icons.dns_rounded,
                  title: Text(l.localBridgeTitle),
                  subtitle: l.localBridgeSettingsSubtitle,
                  onTap: openLocalBridge,
                ),
              ),
            if (visibility.hasActiveMachine && visibility.hasBridgeUrl)
              SettingsItem(
                id: SettingsEntryIds.localUrl,
                child: LocalUrlSettingsTile(bridgeUrl: bridge.lastUrl!),
              ),
            if (visibility.hasActiveMachine)
              SettingsItem(
                id: SettingsEntryIds.bridgeUpdate,
                child: BridgeUpdateStatusTile(
                  machineWithStatus: machineWithStatus,
                  isUpdating: isUpdating,
                  latestBridgeVersion: machineState.latestBridgeVersion,
                  isCheckingLatestBridgeVersion:
                      machineState.isCheckingLatestBridgeVersion,
                  latestBridgeVersionError:
                      machineState.latestBridgeVersionError,
                  onRefreshLatestVersion: () => machineManagerCubit
                      .refreshLatestBridgeVersion(forceRefresh: true),
                  onUpdate: machineWithStatus == null
                      ? null
                      : () => onUpdateBridge(machineWithStatus),
                  onOpenLocalBridge:
                      visibility.isMacOS && isLoopbackBridgeUrl(bridge.lastUrl)
                      ? openLocalBridge
                      : null,
                ),
              ),
          ],
        ),
        if (visibility.bridgeConnected && visibility.hasBridgeUrl)
          SettingsItem(
            id: SettingsEntryIds.bridgeDiagnostics,
            framed: true,
            child: _ConnectedBridgeDiagnosticsCard(
              bridge: bridge,
              machineWithStatus: machineWithStatus,
            ),
          ),
        if (visibility.bridgeConnected && visibility.hasBridgeUrl)
          SettingsItem(
            id: SettingsEntryIds.connectedBridgeTools,
            framed: true,
            child: ConnectedBridgeToolsCard(
              bridge: bridge,
              httpClient: toolsHttpClient,
            ),
          ),
        if (visibility.hasActiveMachine && visibility.promptHistoryAvailable)
          SettingsItem(
            id: SettingsEntryIds.promptHistory,
            framed: true,
            child: PromptHistorySectionSlot(bridgeService: bridge),
          ),
      ],
    );
  }
}

class _ConnectedToThisMacBanner extends StatelessWidget {
  const _ConnectedToThisMacBanner({required this.onOpenLocalBridge});

  final VoidCallback onOpenLocalBridge;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = SettingsAccent.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        key: const ValueKey('settings_connected_local_bridge_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.laptop_mac_rounded, size: 18, color: accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l.settingsConnectedToThisMacBadge,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('settings_jump_to_local_bridge_button'),
              onPressed: onOpenLocalBridge,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.dns_rounded, size: 16),
              label: Text(l.settingsOpenLocalBridgeAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedBridgeActionStrip extends StatelessWidget {
  const _ConnectedBridgeActionStrip({
    required this.canEdit,
    required this.canReconnect,
    required this.canCopyUrl,
    required this.canDisconnect,
    required this.onEdit,
    required this.onReconnect,
    required this.onCopyUrl,
    required this.onDisconnect,
  });

  final bool canEdit;
  final bool canReconnect;
  final bool canCopyUrl;
  final bool canDisconnect;
  final VoidCallback? onEdit;
  final VoidCallback? onReconnect;
  final VoidCallback? onCopyUrl;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    if (!canEdit && !canReconnect && !canCopyUrl && !canDisconnect) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (canEdit)
            OutlinedButton.icon(
              key: const ValueKey('settings_edit_bridge_button'),
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(l.settingsEditBridgeMachine),
            ),
          if (canReconnect)
            OutlinedButton.icon(
              key: const ValueKey('settings_reconnect_bridge_button'),
              onPressed: onReconnect,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l.settingsReconnectBridge),
            ),
          if (canCopyUrl)
            OutlinedButton.icon(
              key: const ValueKey('settings_copy_bridge_url_button'),
              onPressed: onCopyUrl,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.content_copy_rounded, size: 16),
              label: Text(l.settingsCopyBridgeUrl),
            ),
          if (canDisconnect)
            OutlinedButton.icon(
              key: const ValueKey('settings_disconnect_bridge_button'),
              onPressed: onDisconnect,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.link_off_rounded, size: 16),
              label: Text(l.settingsSwitchBridge),
            ),
        ],
      ),
    );
  }
}

class _ConnectedBridgeDiagnosticsCard extends StatelessWidget {
  const _ConnectedBridgeDiagnosticsCard({
    required this.bridge,
    required this.machineWithStatus,
  });

  final BridgeService bridge;
  final MachineWithStatus? machineWithStatus;

  String _transportLabel(AppLocalizations l) {
    final url = bridge.lastUrl;
    final machine = machineWithStatus?.machine;
    if (machine != null && machine.sshEnabled && isLoopbackBridgeUrl(url)) {
      return l.settingsBridgeTransportSshTunnel;
    }
    if (url != null && url.startsWith('wss://')) {
      return l.settingsBridgeTransportSecure;
    }
    return l.settingsBridgeTransportStandard;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final endpoint = displayBridgeUrl(bridge.lastUrl) ?? bridge.lastUrl ?? '';
    final version =
        bridge.bridgeVersion ?? machineWithStatus?.versionInfo?.version;
    final protocolVersion = bridge.protocolCompatibility?.selectedVersion;
    final allowedDirs = bridge.allowedDirs;

    return SettingsGroup(
      title: l.settingsBridgeDiagnosticsTitle,
      cardKey: const ValueKey('settings_bridge_diagnostics_card'),
      children: [
        _DiagnosticRow(
          label: l.settingsBridgeEndpointLabel,
          value: endpoint,
          monospace: true,
        ),
        _DiagnosticRow(
          label: l.settingsBridgeTransportLabel,
          value: _transportLabel(l),
        ),
        if (version != null && version.isNotEmpty)
          _DiagnosticRow(label: l.version, value: 'v$version', monospace: true),
        if (protocolVersion != null)
          _DiagnosticRow(
            label: l.settingsBridgeProtocolLabel,
            value: 'v$protocolVersion',
            monospace: true,
          ),
        _DiagnosticRow(
          label: l.settingsBridgeAllowedDirsLabel,
          value: allowedDirs.isEmpty
              ? l.settingsBridgeAllowedDirsAll
              : allowedDirs.join('\n'),
          monospace: allowedDirs.isNotEmpty,
        ),
      ],
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: monospace ? 'JetBrainsMono' : null,
                fontSize: monospace ? 12.5 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
