import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/settings_tiles.dart';
import '../data/local_bridge_models.dart';

/// Pairing QR code for the addresses other devices can reach.
///
/// The code carries the API key, so it stays hidden until asked for.
class LocalBridgePairingCard extends StatefulWidget {
  const LocalBridgePairingCard({
    super.key,
    required this.pairing,
    required this.canRotateApiKey,
    required this.onRotateApiKey,
  });

  final LocalBridgePairing pairing;
  final bool canRotateApiKey;
  final VoidCallback? onRotateApiKey;

  @override
  State<LocalBridgePairingCard> createState() => _LocalBridgePairingCardState();
}

class _LocalBridgePairingCardState extends State<LocalBridgePairingCard> {
  int _selected = 0;
  bool _showQr = false;

  Future<void> _copy(String link) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copied = AppLocalizations.of(context).copied;
    await Clipboard.setData(ClipboardData(text: link));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final connections = widget.pairing.connections;
    final selected = connections.isEmpty
        ? null
        : connections[_selected.clamp(0, connections.length - 1)];

    return SettingsCard(
      key: const ValueKey('local_bridge_pairing_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.localBridgePairingBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (!widget.pairing.authRequired) ...[
              const SizedBox(height: 10),
              Text(
                l.localBridgeAuthDisabled,
                key: const ValueKey('local_bridge_auth_disabled_note'),
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
            const SizedBox(height: 12),
            if (selected == null)
              Text(
                l.localBridgePairingNoAddress,
                key: const ValueKey('local_bridge_no_address_note'),
              )
            else ...[
              if (connections.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final (index, connection) in connections.indexed)
                        ChoiceChip(
                          key: ValueKey(
                            'local_bridge_address_chip:${connection.label}',
                          ),
                          label: Text(connection.label),
                          selected: index == _selected,
                          onSelected: (_) => setState(() => _selected = index),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SelectableText(
                selected.wsUrl,
                key: const ValueKey('local_bridge_ws_url'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              if (_showQr) ...[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    key: const ValueKey('local_bridge_qr_code'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: selected.deepLink,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.localBridgePairingSensitive,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('local_bridge_toggle_qr_button'),
                    onPressed: () => setState(() => _showQr = !_showQr),
                    icon: Icon(
                      _showQr
                          ? Icons.visibility_off_rounded
                          : Icons.qr_code_2_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _showQr ? l.localBridgeHideQr : l.localBridgeShowQr,
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('local_bridge_copy_link_button'),
                    onPressed: () => _copy(selected.deepLink),
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: Text(l.localBridgeCopyLink),
                  ),
                  if (widget.canRotateApiKey)
                    TextButton.icon(
                      key: const ValueKey('local_bridge_rotate_key_button'),
                      onPressed: widget.onRotateApiKey,
                      icon: const Icon(Icons.key_rounded, size: 18),
                      label: Text(l.localBridgeRotateKey),
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
