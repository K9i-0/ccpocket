import 'package:material_ui/material_ui.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';
import 'settings_tiles.dart';

/// Derived Bridge version state shared by the status card and the tile.
class BridgeUpdateStatus {
  const BridgeUpdateStatus._({
    required this.expectedVersion,
    required this.updateTargetVersion,
    required this.currentVersion,
    required this.latestCheckFailed,
    required this.bridgeNeedsUpdate,
    required this.needsUpdate,
    required this.canShowSetupHelp,
    required this.updateFromDesktopApp,
    required this.setupMayNotApply,
    required this.isKnownUpToDate,
  });

  factory BridgeUpdateStatus.resolve({
    required MachineWithStatus? machineWithStatus,
    String? latestBridgeVersion,
    bool isCheckingLatestBridgeVersion = false,
    String? latestBridgeVersionError,
    bool isLocalBridge = false,
  }) {
    final expectedVersion = AppConstants.expectedBridgeVersion;
    final updateTargetVersion =
        latestBridgeVersion != null &&
            compareSemanticVersions(latestBridgeVersion, expectedVersion) > 0
        ? latestBridgeVersion
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
    // A Bridge older than the `managedBy` report says nothing about what
    // started it. On the Mac that hosts it, this app is where it is managed,
    // so point there instead of to the SSH setup.
    final updateFromDesktopApp =
        bridgeNeedsUpdate &&
        (versionInfo.isManagedByDesktopApp ||
            (isLocalBridge && versionInfo.managedBy == null));
    return BridgeUpdateStatus._(
      expectedVersion: expectedVersion,
      updateTargetVersion: updateTargetVersion,
      currentVersion: versionInfo?.version,
      latestCheckFailed: latestCheckFailed,
      bridgeNeedsUpdate: bridgeNeedsUpdate,
      needsUpdate: bridgeNeedsUpdate && hasSshSetup && !updateFromDesktopApp,
      canShowSetupHelp:
          bridgeNeedsUpdate && !hasSshSetup && !updateFromDesktopApp,
      updateFromDesktopApp: updateFromDesktopApp,
      setupMayNotApply:
          versionInfo?.managedBy == null &&
          (versionInfo?.platform == null || versionInfo?.platform == 'darwin'),
      isKnownUpToDate:
          versionInfo != null &&
          !bridgeNeedsUpdate &&
          !isCheckingLatestBridgeVersion &&
          !latestCheckFailed,
    );
  }

  final String expectedVersion;
  final String updateTargetVersion;
  final String? currentVersion;
  final bool latestCheckFailed;

  /// The running Bridge is older than the target version.
  final bool bridgeNeedsUpdate;

  /// An update is needed and can be started over SSH.
  final bool needsUpdate;

  /// An update is needed but SSH is not configured.
  final bool canShowSetupHelp;

  /// An update is needed and the CC Pocket desktop app runs this Bridge: it
  /// is updated by restarting it from that app, never over SSH.
  final bool updateFromDesktopApp;

  /// The Bridge does not say what started it and may be on a Mac, so the
  /// desktop app may run it and the `setup` instructions may be wrong for it.
  final bool setupMayNotApply;
  final bool isKnownUpToDate;
}

class BridgeUpdateStatusTile extends StatelessWidget {
  final MachineWithStatus? machineWithStatus;
  final bool isUpdating;
  final String? latestBridgeVersion;
  final bool isCheckingLatestBridgeVersion;
  final String? latestBridgeVersionError;
  final VoidCallback? onRefreshLatestVersion;
  final VoidCallback? onUpdate;

  /// Opens "Bridge on this Mac". Set only when this app runs on the Mac that
  /// hosts the connected Bridge.
  final VoidCallback? onOpenLocalBridge;

  const BridgeUpdateStatusTile({
    super.key,
    required this.machineWithStatus,
    required this.isUpdating,
    this.latestBridgeVersion,
    this.isCheckingLatestBridgeVersion = false,
    this.latestBridgeVersionError,
    this.onRefreshLatestVersion,
    this.onUpdate,
    this.onOpenLocalBridge,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final status = BridgeUpdateStatus.resolve(
      machineWithStatus: machineWithStatus,
      latestBridgeVersion: latestBridgeVersion,
      isCheckingLatestBridgeVersion: isCheckingLatestBridgeVersion,
      latestBridgeVersionError: latestBridgeVersionError,
      isLocalBridge: onOpenLocalBridge != null,
    );
    final expectedVersion = status.expectedVersion;
    final updateTargetVersion = status.updateTargetVersion;
    final versionInfo = machineWithStatus?.versionInfo;
    final latestCheckFailed = status.latestCheckFailed;
    final bridgeNeedsUpdate = status.bridgeNeedsUpdate;
    final needsUpdate = status.needsUpdate;
    final canShowSetupHelp = status.canShowSetupHelp;
    final isKnownUpToDate = status.isKnownUpToDate;
    final fromDesktopApp = status.updateFromDesktopApp;
    final openLocalBridge = fromDesktopApp ? onOpenLocalBridge : null;

    final title = bridgeNeedsUpdate
        ? l.bridgeUpdateAvailable
        : latestCheckFailed
        ? l.bridgeLatestVersionUnavailable
        : isKnownUpToDate
        ? l.bridgeIsUpToDate
        : l.updateBridge;
    final subtitle = openLocalBridge != null
        ? l.bridgeUpdateRestartHere
        : fromDesktopApp
        ? l.bridgeUpdateFromDesktopApp
        : canShowSetupHelp
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
        ? settingsSuccessColor(Theme.of(context).brightness)
        : cs.onSurfaceVariant;

    return ListTile(
      key: fromDesktopApp
          ? const ValueKey('settings_bridge_update_desktop_tile')
          : canShowSetupHelp
          ? const ValueKey('settings_bridge_update_setup_tile')
          : null,
      leading: SettingsLeadingIcon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap:
          openLocalBridge ??
          (fromDesktopApp
              ? () => _showBridgeUpdateDesktopSheet(context)
              : canShowSetupHelp
              ? () => _showBridgeUpdateSetupSheet(
                  context,
                  showDesktopNote: status.setupMayNotApply,
                )
              : null),
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
          : canShowSetupHelp || fromDesktopApp
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

  void _showBridgeUpdateSetupSheet(
    BuildContext context, {
    required bool showDesktopNote,
  }) {
    final l = AppLocalizations.of(context);
    _showBridgeUpdateSheet(
      context,
      title: l.bridgeUpdateSetupTitle,
      description: l.bridgeUpdateSetupDescription,
      steps: [l.bridgeUpdateSetupEnableSsh, l.bridgeUpdateSetupRunCommand],
      command: l.bridgeUpdateSetupCommand,
      note: showDesktopNote ? l.bridgeUpdateSetupDesktopNote : null,
    );
  }

  void _showBridgeUpdateDesktopSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    _showBridgeUpdateSheet(
      context,
      title: l.bridgeUpdateDesktopTitle,
      description: l.bridgeUpdateDesktopDescription,
      steps: [l.bridgeUpdateDesktopStepOpen, l.bridgeUpdateDesktopStepRestart],
      note: l.bridgeUpdateDesktopNoSetup,
    );
  }

  void _showBridgeUpdateSheet(
    BuildContext context, {
    required String title,
    required String description,
    required List<String> steps,
    String? command,
    String? note,
  }) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      key: const ValueKey('bridge_update_sheet_note'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note,
                            style: textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  for (final (index, step) in steps.indexed) ...[
                    if (index > 0) const SizedBox(height: 12),
                    _BridgeUpdateSetupStep(index: index + 1, text: step),
                  ],
                  if (command != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.65,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        command,
                        style: textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
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
