import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../models/protocol_version.dart';

/// Shown when the Bridge closed the connection with code 4001: it requires an
/// API key the app does not have. Explains how to show the pairing QR code on
/// the Bridge host and offers the ways to re-pair.
class BridgeAuthRequiredCard extends StatelessWidget {
  final BridgeAuthRejection rejection;
  final VoidCallback? onScanQrCode;
  final VoidCallback? onEnterApiKey;

  const BridgeAuthRequiredCard({
    super.key,
    required this.rejection,
    this.onScanQrCode,
    this.onEnterApiKey,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final onCard = colors.onErrorContainer;

    return Card(
      key: const ValueKey('bridge_auth_required_card'),
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.key, color: onCard),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.bridgeAuthRequiredTitle,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: onCard, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.bridgeAuthRequiredBody(rejection.label),
              style: TextStyle(color: onCard),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    bridgeStableMajorQrCommand,
                    style: TextStyle(color: onCard, fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  key: const ValueKey('copy_bridge_qr_command_button'),
                  onPressed: () => Clipboard.setData(
                    const ClipboardData(text: bridgeStableMajorQrCommand),
                  ),
                  tooltip: l.copy,
                  icon: Icon(Icons.copy, color: onCard),
                ),
              ],
            ),
            if (onScanQrCode != null || onEnterApiKey != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onScanQrCode case final onScan?)
                    FilledButton.icon(
                      key: const ValueKey('bridge_auth_scan_qr_button'),
                      onPressed: onScan,
                      style: FilledButton.styleFrom(
                        backgroundColor: onCard,
                        foregroundColor: colors.errorContainer,
                      ),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(l.scanQrCode),
                    ),
                  if (onEnterApiKey case final onEnter?)
                    OutlinedButton.icon(
                      key: const ValueKey('bridge_auth_enter_api_key_button'),
                      onPressed: onEnter,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: onCard,
                        side: BorderSide(color: onCard),
                      ),
                      icon: const Icon(Icons.edit),
                      label: Text(l.bridgeAuthEnterApiKey),
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
