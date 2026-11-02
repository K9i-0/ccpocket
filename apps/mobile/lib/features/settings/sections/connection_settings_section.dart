import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';
import '../../../providers/machine_manager_cubit.dart';
import '../../../services/bridge_service.dart';
import '../models/settings_catalog.dart';
import '../state/settings_state.dart';
import '../widgets/bridge_update_status_tile.dart';
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

class ConnectionSettingsSection extends StatelessWidget {
  const ConnectionSettingsSection({
    super.key,
    required this.state,
    required this.visibility,
    required this.onUpdateBridge,
  });

  final SettingsState state;
  final SettingsVisibility visibility;
  final ValueChanged<MachineWithStatus> onUpdateBridge;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          cardKey: const ValueKey('settings_connection_section_card'),
          children: [
            SettingsItem(
              id: SettingsEntryIds.bridgeMachine,
              child: SettingsNavTile(
                icon: Icons.computer_rounded,
                title: Text(l.settingsBridgeMachine),
                subtitle:
                    machine?.displayName ??
                    (bridge.lastUrl ?? l.settingsNotConnected),
              ),
            ),
            if (visibility.hasBridgeUrl)
              SettingsItem(
                id: SettingsEntryIds.localUrl,
                child: LocalUrlSettingsTile(bridgeUrl: bridge.lastUrl!),
              ),
            SettingsItem(
              id: SettingsEntryIds.bridgeUpdate,
              child: BridgeUpdateStatusTile(
                machineWithStatus: machineWithStatus,
                isUpdating: isUpdating,
                latestBridgeVersion: machineState.latestBridgeVersion,
                isCheckingLatestBridgeVersion:
                    machineState.isCheckingLatestBridgeVersion,
                latestBridgeVersionError: machineState.latestBridgeVersionError,
                onRefreshLatestVersion: () => machineManagerCubit
                    .refreshLatestBridgeVersion(forceRefresh: true),
                onUpdate: machineWithStatus == null
                    ? null
                    : () => onUpdateBridge(machineWithStatus),
              ),
            ),
          ],
        ),
        if (visibility.promptHistoryAvailable)
          SettingsItem(
            id: SettingsEntryIds.promptHistory,
            framed: true,
            child: PromptHistorySectionSlot(bridgeService: bridge),
          ),
      ],
    );
  }
}
