import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';
import '../../../services/server_discovery_service.dart';
import 'discovered_servers_list.dart';
import 'machine_list.dart';

class ConnectForm extends StatelessWidget {
  final TextEditingController urlController;
  final TextEditingController apiKeyController;
  final List<DiscoveredServer> discoveredServers;
  final VoidCallback onConnect;
  final VoidCallback onScanQrCode;
  final VoidCallback? onViewSetupGuide;
  final ValueChanged<DiscoveredServer> onConnectToDiscovered;

  // Machine management
  final List<MachineWithStatus> machines;
  final String? startingMachineId;
  final String? updatingMachineId;
  final ValueChanged<MachineWithStatus>? onConnectToMachine;
  final ValueChanged<MachineWithStatus>? onStartMachine;
  final ValueChanged<MachineWithStatus>? onEditMachine;
  final ValueChanged<MachineWithStatus>? onDeleteMachine;
  final ValueChanged<MachineWithStatus>? onToggleFavorite;
  final ValueChanged<MachineWithStatus>? onUpdateMachine;
  final ValueChanged<MachineWithStatus>? onStopMachine;
  final VoidCallback? onAddMachine;
  final VoidCallback? onRefreshMachines;

  const ConnectForm({
    super.key,
    required this.urlController,
    required this.apiKeyController,
    required this.discoveredServers,
    required this.onConnect,
    required this.onScanQrCode,
    this.onViewSetupGuide,
    required this.onConnectToDiscovered,
    // Machine management
    this.machines = const [],
    this.startingMachineId,
    this.updatingMachineId,
    this.onConnectToMachine,
    this.onStartMachine,
    this.onEditMachine,
    this.onDeleteMachine,
    this.onToggleFavorite,
    this.onUpdateMachine,
    this.onStopMachine,
    this.onAddMachine,
    this.onRefreshMachines,
  });

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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.terminal,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.connectToBridgeServer,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),

          // Machines section (favorites + recent)
          if (_hasMachineHandlers) ...[
            MachineList(
              machines: machines,
              startingMachineId: startingMachineId,
              updatingMachineId: updatingMachineId,
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
            if (machines.isNotEmpty || discoveredServers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDivider(context, l.orConnectManually),
              const SizedBox(height: 16),
            ],
          ],

          // Discovered servers via mDNS
          if (discoveredServers.isNotEmpty) ...[
            DiscoveredServersList(
              servers: discoveredServers,
              onConnect: onConnectToDiscovered,
            ),
            const SizedBox(height: 16),
          ],

          // Manual input
          TextField(
            key: const ValueKey('server_url_field'),
            controller: urlController,
            decoration: InputDecoration(
              labelText: l.serverUrl,
              hintText: l.serverUrlHint,
              prefixIcon: const Icon(Icons.dns),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => onConnect(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('api_key_field'),
            controller: apiKeyController,
            decoration: InputDecoration(
              labelText: l.apiKeyOptional,
              hintText: l.apiKeyHint,
              prefixIcon: const Icon(Icons.key),
              border: const OutlineInputBorder(),
            ),
            obscureText: true,
            onSubmitted: (_) => onConnect(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: const ValueKey('connect_button'),
              onPressed: onConnect,
              icon: const Icon(Icons.link),
              label: Text(l.connect),
            ),
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                key: const ValueKey('scan_qr_button'),
                onPressed: onScanQrCode,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(l.scanQrCode),
              ),
            ),
          ],
          if (onViewSetupGuide != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              key: const ValueKey('setup_guide_button'),
              onPressed: onViewSetupGuide,
              icon: const Icon(Icons.lightbulb_outline, size: 18),
              label: Text(l.setupGuide),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context, String text) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ],
    );
  }
}
