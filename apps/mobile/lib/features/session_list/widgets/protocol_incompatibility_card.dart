import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/protocol_version.dart';

class ProtocolIncompatibilityCard extends StatelessWidget {
  final ProtocolCompatibility compatibility;

  const ProtocolIncompatibilityCard({super.key, required this.compatibility});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final target = compatibility.updateTarget;
    final body = switch (target) {
      ProtocolUpdateTarget.app => l.protocolUpdateAppBody,
      ProtocolUpdateTarget.bridge => l.protocolUpdateBridgeBody,
      ProtocolUpdateTarget.both => l.protocolUpdateBothBody,
    };
    final showBridgeCommand = target != ProtocolUpdateTarget.app;

    return Card(
      key: const ValueKey('protocol_incompatibility_card'),
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update_alt, color: colors.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.protocolIncompatibleTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: TextStyle(color: colors.onErrorContainer)),
            const SizedBox(height: 8),
            Text(
              l.protocolRangeDetails(
                appProtocolMinVersion,
                appProtocolMaxVersion,
                compatibility.bridgeMinVersion,
                compatibility.bridgeMaxVersion,
              ),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onErrorContainer),
            ),
            if (showBridgeCommand) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      bridgeStableMajorSetupCommand,
                      style: TextStyle(
                        color: colors.onErrorContainer,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('copy_bridge_update_command_button'),
                    onPressed: () => Clipboard.setData(
                      const ClipboardData(text: bridgeStableMajorSetupCommand),
                    ),
                    tooltip: l.copy,
                    icon: Icon(Icons.copy, color: colors.onErrorContainer),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
