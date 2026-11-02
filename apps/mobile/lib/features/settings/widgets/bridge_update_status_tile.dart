import 'package:flutter/material.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';

class BridgeUpdateStatusTile extends StatelessWidget {
  final MachineWithStatus? machineWithStatus;
  final bool isUpdating;
  final String? latestBridgeVersion;
  final bool isCheckingLatestBridgeVersion;
  final String? latestBridgeVersionError;
  final VoidCallback? onRefreshLatestVersion;
  final VoidCallback? onUpdate;

  const BridgeUpdateStatusTile({
    super.key,
    required this.machineWithStatus,
    required this.isUpdating,
    this.latestBridgeVersion,
    this.isCheckingLatestBridgeVersion = false,
    this.latestBridgeVersionError,
    this.onRefreshLatestVersion,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final expectedVersion = AppConstants.expectedBridgeVersion;
    final updateTargetVersion =
        latestBridgeVersion != null &&
            compareSemanticVersions(latestBridgeVersion!, expectedVersion) > 0
        ? latestBridgeVersion!
        : expectedVersion;
    final machine = machineWithStatus?.machine;
    final versionInfo = machineWithStatus?.versionInfo;
    final hasSshSetup = machine?.canStartRemotely ?? false;
    final isOnline = machineWithStatus?.status == MachineStatus.online;
    final latestCheckFailed =
        latestBridgeVersion == null && latestBridgeVersionError != null;
    final bridgeNeedsUpdate =
        isOnline &&
        versionInfo != null &&
        versionInfo.needsUpdate(updateTargetVersion);
    final needsUpdate = bridgeNeedsUpdate && hasSshSetup;
    final canShowSetupHelp = bridgeNeedsUpdate && !hasSshSetup;
    final isKnownUpToDate =
        versionInfo != null &&
        !bridgeNeedsUpdate &&
        !isCheckingLatestBridgeVersion &&
        !latestCheckFailed;

    final title = bridgeNeedsUpdate
        ? l.bridgeUpdateAvailable
        : latestCheckFailed
        ? l.bridgeLatestVersionUnavailable
        : isKnownUpToDate
        ? l.bridgeIsUpToDate
        : l.updateBridge;
    final subtitle = canShowSetupHelp
        ? l.bridgeUpdateRequiresSetup
        : isCheckingLatestBridgeVersion
        ? l.bridgeLatestVersionChecking
        : versionInfo == null
        ? l.bridgeVersionUnknown
        : latestBridgeVersion != null
        ? l.bridgeVersionCurrentLatest(versionInfo.version, updateTargetVersion)
        : l.bridgeVersionCurrentExpected(versionInfo.version, expectedVersion);
    final icon = bridgeNeedsUpdate
        ? Icons.system_update
        : latestCheckFailed
        ? Icons.warning_amber_outlined
        : isKnownUpToDate
        ? Icons.check_circle_outline
        : Icons.info_outline;
    final iconColor = bridgeNeedsUpdate
        ? cs.tertiary
        : latestCheckFailed
        ? cs.error
        : isKnownUpToDate
        ? cs.primary
        : cs.onSurfaceVariant;

    return ListTile(
      key: canShowSetupHelp
          ? const ValueKey('settings_bridge_update_setup_tile')
          : null,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: canShowSetupHelp
          ? () => _showBridgeUpdateSetupSheet(context)
          : null,
      trailing: isUpdating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isCheckingLatestBridgeVersion
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : needsUpdate
          ? FilledButton.tonalIcon(
              key: const ValueKey('settings_update_bridge_button'),
              onPressed: onUpdate,
              icon: const Icon(Icons.system_update, size: 18),
              label: Text(l.update),
            )
          : canShowSetupHelp
          ? Icon(Icons.chevron_right, color: cs.onSurfaceVariant)
          : latestCheckFailed
          ? IconButton(
              key: const ValueKey('settings_bridge_latest_retry_button'),
              onPressed: onRefreshLatestVersion,
              icon: const Icon(Icons.refresh),
              tooltip: l.bridgeLatestVersionRetry,
            )
          : null,
    );
  }

  void _showBridgeUpdateSetupSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.bridgeUpdateSetupTitle,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.bridgeUpdateSetupDescription,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  _BridgeUpdateSetupStep(
                    index: 1,
                    text: l.bridgeUpdateSetupEnableSsh,
                  ),
                  const SizedBox(height: 12),
                  _BridgeUpdateSetupStep(
                    index: 2,
                    text: l.bridgeUpdateSetupRunCommand,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      l.bridgeUpdateSetupCommand,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BridgeUpdateSetupStep extends StatelessWidget {
  final int index;
  final String text;

  const _BridgeUpdateSetupStep({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
