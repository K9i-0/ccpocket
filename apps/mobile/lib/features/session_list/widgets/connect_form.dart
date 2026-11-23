import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';
import '../../../models/messages.dart';
import '../../../models/protocol_version.dart';
import '../../../utils/platform_helper.dart';
import '../../demo/demo_screen.dart';
import '../../local_bridge/local_bridge_screen.dart';
import 'bridge_auth_required_card.dart';
import 'machine_list.dart';
import 'protocol_incompatibility_card.dart';

class ConnectForm extends StatelessWidget {
  final VoidCallback onScanQrCode;
  final VoidCallback? onViewSetupGuide;

  // Machine management
  final List<MachineWithStatus> machines;
  final String? startingMachineId;
  final String? updatingMachineId;
  final String? latestBridgeVersion;
  final ValueChanged<MachineWithStatus>? onConnectToMachine;
  final ValueChanged<MachineWithStatus>? onStartMachine;
  final ValueChanged<MachineWithStatus>? onEditMachine;
  final ValueChanged<MachineWithStatus>? onDeleteMachine;
  final ValueChanged<MachineWithStatus>? onToggleFavorite;
  final ValueChanged<MachineWithStatus>? onUpdateMachine;
  final ValueChanged<MachineWithStatus>? onStopMachine;
  final VoidCallback? onAddMachine;
  final VoidCallback? onRefreshMachines;
  final ProtocolCompatibility? protocolCompatibility;

  /// Set when the last Bridge rejected this app's API key.
  final BridgeAuthRejection? authRejection;

  /// Whether to offer the screen that manages the Bridge on this Mac;
  /// defaults to the platform (tests override it).
  final bool? showLocalBridge;

  const ConnectForm({
    super.key,
    required this.onScanQrCode,
    this.onViewSetupGuide,
    // Machine management
    this.machines = const [],
    this.startingMachineId,
    this.updatingMachineId,
    this.latestBridgeVersion,
    this.onConnectToMachine,
    this.onStartMachine,
    this.onEditMachine,
    this.onDeleteMachine,
    this.onToggleFavorite,
    this.onUpdateMachine,
    this.onStopMachine,
    this.onAddMachine,
    this.onRefreshMachines,
    this.protocolCompatibility,
    this.authRejection,
    this.showLocalBridge,
  });

  /// The saved machine the rejected connection belongs to, if any.
  MachineWithStatus? _machineFor(BridgeAuthRejection rejection) {
    for (final entry in machines) {
      if (entry.machine.host == rejection.host &&
          (rejection.port == null || entry.machine.port == rejection.port)) {
        return entry;
      }
    }
    return null;
  }

  bool get _hasMachineHandlers =>
      onConnectToMachine != null &&
      onStartMachine != null &&
      onEditMachine != null &&
      onDeleteMachine != null &&
      onAddMachine != null;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.terminal,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.connectToBridgeServer,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (showLocalBridge ?? isMacOSPlatform) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('connect_local_bridge_button'),
              onPressed: () => openLocalBridgeScreen(context),
              icon: const Icon(Icons.dns_rounded),
              label: Text(l.localBridgeTitle),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('demo_try_button'),
            onPressed: () => Navigator.of(
              context,
            ).push<void>(MaterialPageRoute(builder: (_) => const DemoScreen())),
            icon: const Icon(Icons.play_circle_outline),
            label: Text(l.demoTry),
          ),
          const SizedBox(height: 24),

          if (authRejection case final rejection?) ...[
            BridgeAuthRequiredCard(
              rejection: rejection,
              onScanQrCode: !kIsWeb && !isDesktopPlatform ? onScanQrCode : null,
              // A Bridge on this Mac can be paired from its management
              // screen, without the terminal command.
              onOpenLocalBridge:
                  (showLocalBridge ?? isMacOSPlatform) &&
                      const {
                        'localhost',
                        '127.0.0.1',
                        '::1',
                        '[::1]',
                      }.contains(rejection.host.toLowerCase())
                  ? () => openLocalBridgeScreen(context)
                  : null,
              onEnterApiKey: switch ((_machineFor(rejection), onEditMachine)) {
                (final machine?, final onEdit?) => () => onEdit(machine),
                _ => null,
              },
            ),
            const SizedBox(height: 16),
          ],

          if (protocolCompatibility case final compatibility?
              when !compatibility.isCompatible) ...[
            ProtocolIncompatibilityCard(compatibility: compatibility),
            const SizedBox(height: 16),
          ],

          // Machines section (favorites + recent)
          if (_hasMachineHandlers) ...[
            MachineList(
              machines: machines,
              startingMachineId: startingMachineId,
              updatingMachineId: updatingMachineId,
              latestBridgeVersion: latestBridgeVersion,
              onConnect: onConnectToMachine!,
              onStart: onStartMachine!,
              onEdit: onEditMachine!,
              onDelete: onDeleteMachine!,
              onToggleFavorite: onToggleFavorite,
              onUpdate: onUpdateMachine,
              onStop: onStopMachine,
              onAddMachine: onAddMachine!,
              onRefresh: onRefreshMachines,
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          if (!kIsWeb && !isDesktopPlatform) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('scan_qr_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHigh,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  elevation: 0,
                ),
                onPressed: onScanQrCode,
                icon: Icon(
                  Icons.qr_code_scanner,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                  l.scanQrCode,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (onViewSetupGuide != null) ...[
            TextButton.icon(
              key: const ValueKey('setup_guide_button'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onViewSetupGuide,
              icon: Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: Text(
                l.setupGuide,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
