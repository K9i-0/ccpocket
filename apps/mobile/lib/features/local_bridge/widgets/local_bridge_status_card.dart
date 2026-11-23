import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/settings_tiles.dart';
import '../data/local_bridge_models.dart';
import '../state/local_bridge_state.dart';

/// Running state, version and the restart control.
class LocalBridgeStatusCard extends StatelessWidget {
  const LocalBridgeStatusCard({
    super.key,
    required this.status,
    required this.restartRequired,
    required this.busy,
    required this.onRestart,
  });

  final LocalBridgeStatus status;
  final bool restartRequired;
  final LocalBridgeBusy busy;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final restarting = busy == LocalBridgeBusy.restarting;

    return SettingsCard(
      key: const ValueKey('local_bridge_status_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: restarting ? cs.tertiary : Colors.green,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    restarting
                        ? l.localBridgeRestarting
                        : l.localBridgeStatusRunning,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (restarting)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (status.supervised)
                  OutlinedButton.icon(
                    key: const ValueKey('local_bridge_restart_button'),
                    onPressed: busy == LocalBridgeBusy.none ? onRestart : null,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: Text(l.restart),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.localBridgeStatusDetail(status.version, status.port),
              key: const ValueKey('local_bridge_status_detail'),
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              l.localBridgeStatusCounts(status.sessions, status.clients),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (!status.supervised) ...[
              const SizedBox(height: 10),
              Text(
                l.localBridgeNotSupervised,
                key: const ValueKey('local_bridge_not_supervised_note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            if (restartRequired && !restarting) ...[
              const SizedBox(height: 12),
              LocalBridgeRestartBanner(
                canRestart: status.supervised && busy == LocalBridgeBusy.none,
                onRestart: onRestart,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Changes apply after a restart" with the action when it is available.
class LocalBridgeRestartBanner extends StatelessWidget {
  const LocalBridgeRestartBanner({
    super.key,
    required this.canRestart,
    required this.onRestart,
  });

  final bool canRestart;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('local_bridge_restart_required_banner'),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: cs.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.localBridgeRestartRequired,
              style: TextStyle(color: cs.onTertiaryContainer),
            ),
          ),
          if (canRestart)
            TextButton(
              key: const ValueKey('local_bridge_restart_to_apply_button'),
              style: TextButton.styleFrom(
                foregroundColor: cs.onTertiaryContainer,
              ),
              onPressed: onRestart,
              child: Text(
                l.localBridgeRestartNow,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
