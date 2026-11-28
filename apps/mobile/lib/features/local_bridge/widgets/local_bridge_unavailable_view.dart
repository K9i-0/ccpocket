import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../data/local_bridge_launcher.dart';
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
    this.onStart,
    this.onUnregister,
    this.onOpenLoginItems,
    this.busy = LocalBridgeBusy.none,
    this.registration = LauncherRegistration.unavailable,
    this.problem,
    this.problemNodeVersion,
    this.startFailed = false,
  });

  /// Starts the Bridge from the app; null when this build cannot.
  final VoidCallback? onStart;

  /// Removes the app's LaunchAgent. Offered while it is registered but no
  /// Bridge of its own is running (waiting for Node, port taken, ...), so the
  /// user is never left with an agent they cannot turn off here.
  final VoidCallback? onUnregister;

  /// Opens System Settings > Login Items, offered while the agent is off
  /// there.
  final VoidCallback? onOpenLoginItems;
  final LocalBridgeBusy busy;
  final LauncherRegistration registration;

  /// Why the launcher could not start the Bridge, if it reported one.
  final LauncherProblem? problem;
  final String? problemNodeVersion;
  final bool startFailed;

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
        onStart == null
            ? l.localBridgeNotRunningBody(port)
            : l.localBridgeStartBody,
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
            if (phase == LocalBridgePhase.notRunning && onStart != null) ...[
              const SizedBox(height: 16),
              LocalBridgeStartPanel(
                port: port,
                busy: busy,
                registration: registration,
                problem: problem,
                problemNodeVersion: problemNodeVersion,
                startFailed: startFailed,
                onStart: onStart!,
                onOpenLoginItems: onOpenLoginItems,
              ),
              const SizedBox(height: 20),
              Text(
                l.localBridgeManualStartHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
            ] else if (command != null)
              const SizedBox(height: 16),
            if (command != null) CopyableCommand(command: command),
            const SizedBox(height: 20),
            Center(
              child: FilledButton.tonalIcon(
                key: const ValueKey('local_bridge_retry_button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.retry),
              ),
            ),
            if (onUnregister != null &&
                registration == LauncherRegistration.enabled) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  key: const ValueKey('local_bridge_unregister_button'),
                  onPressed: busy == LocalBridgeBusy.none ? onUnregister : null,
                  child: Text(l.localBridgeUnregister),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Start the Bridge" with whatever keeps it from starting.
class LocalBridgeStartPanel extends StatelessWidget {
  const LocalBridgeStartPanel({
    super.key,
    required this.port,
    required this.busy,
    required this.registration,
    required this.onStart,
    this.onOpenLoginItems,
    this.problem,
    this.problemNodeVersion,
    this.startFailed = false,
  });

  final VoidCallback? onOpenLoginItems;
  final int port;
  final LocalBridgeBusy busy;
  final LauncherRegistration registration;
  final VoidCallback onStart;
  final LauncherProblem? problem;
  final String? problemNodeVersion;
  final bool startFailed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final starting = busy == LocalBridgeBusy.starting;
    final message = registration == LauncherRegistration.requiresApproval
        ? l.localBridgeRequiresApproval
        : switch (problem) {
            LauncherProblem.nodeMissing => l.localBridgeNodeMissing,
            LauncherProblem.nodeTooOld => l.localBridgeNodeTooOld(
              problemNodeVersion ?? '',
            ),
            LauncherProblem.portInUse => l.localBridgePortInUse(port),
            LauncherProblem.installFailed => l.localBridgeInstallFailed,
            LauncherProblem.execFailed => l.localBridgeStartFailed,
            null => startFailed ? l.localBridgeStartFailed : null,
          };
    final needsNode =
        problem == LauncherProblem.nodeMissing ||
        problem == LauncherProblem.nodeTooOld;
    // While the agent waits for Node it retries by itself: nothing to press.
    final waitingForFix =
        registration == LauncherRegistration.enabled && problem != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null) ...[
          Text(
            message,
            key: const ValueKey('local_bridge_start_problem'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
          ),
          const SizedBox(height: 12),
        ],
        if (registration == LauncherRegistration.requiresApproval &&
            onOpenLoginItems != null) ...[
          Center(
            child: OutlinedButton.icon(
              key: const ValueKey('local_bridge_open_login_items_button'),
              onPressed: onOpenLoginItems,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(l.localBridgePermissionOpenSettings),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (needsNode) ...[
          const CopyableCommand(
            command: 'brew install node',
            label: 'Homebrew',
          ),
          const SizedBox(height: 12),
        ],
        if (starting)
          Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l.localBridgeStarting, textAlign: TextAlign.center),
            ],
          )
        else if (!waitingForFix)
          Center(
            child: FilledButton.icon(
              key: const ValueKey('local_bridge_start_button'),
              onPressed: busy == LocalBridgeBusy.none ? onStart : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l.localBridgeStart),
            ),
          ),
      ],
    );
  }
}
