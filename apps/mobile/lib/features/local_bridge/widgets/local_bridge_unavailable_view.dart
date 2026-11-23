import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/local_bridge_state.dart';
import 'copyable_command.dart';

/// Command that starts the stable Bridge with the user's Node.
const localBridgeStartCommand = 'npx --yes @ccpocket/bridge@1';

/// Shown instead of the management sections when no Bridge can be managed.
class LocalBridgeUnavailableView extends StatelessWidget {
  const LocalBridgeUnavailableView({
    super.key,
    required this.phase,
    required this.port,
    required this.onRetry,
    this.detail,
  });

  final LocalBridgePhase phase;
  final int port;
  final VoidCallback onRetry;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (icon, title, body) = switch (phase) {
      LocalBridgePhase.notRunning => (
        Icons.power_settings_new_rounded,
        l.localBridgeNotRunningTitle,
        l.localBridgeNotRunningBody(port),
      ),
      LocalBridgePhase.secretUnavailable => (
        Icons.lock_outline_rounded,
        l.localBridgeSecretUnavailableTitle,
        l.localBridgeSecretUnavailableBody,
      ),
      LocalBridgePhase.updateRequired => (
        Icons.system_update_alt_rounded,
        l.localBridgeUpdateRequiredTitle,
        l.localBridgeUpdateRequiredBody,
      ),
      _ => (Icons.error_outline_rounded, l.localBridgeErrorTitle, detail ?? ''),
    };
    final command = switch (phase) {
      LocalBridgePhase.notRunning =>
        port == 8765
            ? localBridgeStartCommand
            : '$localBridgeStartCommand --port $port',
      LocalBridgePhase.updateRequired => localBridgeStartCommand,
      _ => null,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Icon(icon, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              key: const ValueKey('local_bridge_unavailable_title'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            if (command != null) ...[
              const SizedBox(height: 16),
              CopyableCommand(command: command),
            ],
            const SizedBox(height: 20),
            Center(
              child: FilledButton.tonalIcon(
                key: const ValueKey('local_bridge_retry_button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.retry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
