import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';

/// Count of work left running after the turn (agents, shells, monitors,
/// terminals). Kept small so it does not compete with the status label.
class SessionCountBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const SessionCountBadge({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extends a header action's tap target to the header's edges while the
/// visible button keeps its size. The button still handles its own taps and
/// semantics; this region only catches the surrounding misses.
class SessionCardHeaderTapRegion extends StatelessWidget {
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Widget child;

  const SessionCardHeaderTapRegion({
    super.key,
    required this.onTap,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Center(child: child),
      ),
    );
  }
}

class SessionQueuedInputBadge extends StatelessWidget {
  final QueuedInputItem item;

  const SessionQueuedInputBadge({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final imageLabel = item.imageCount > 0
        ? ' · ${l.queuedInputImageCount(item.imageCount)}'
        : '';
    final semanticsLabel = '${l.queuedInputForNextTurn}$imageLabel';

    return Semantics(
      label: semanticsLabel,
      child: Tooltip(
        message: semanticsLabel,
        child: Container(
          key: const ValueKey('session_card_queue_badge'),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.32),
              width: 0.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 12,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                l.sessionCardQueuedInput,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimaryContainer,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RunningSessionStopButton extends StatelessWidget {
  final VoidCallback onPressed;

  const RunningSessionStopButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return IconButton(
      key: const ValueKey('running_session_stop_button'),
      onPressed: onPressed,
      tooltip: l.stopSession,
      icon: const Icon(Icons.stop_circle_outlined),
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 28),
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.error,
        backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.26),
      ),
    );
  }
}

String? formatSessionAgentLabel(String? nickname, String? role) {
  final trimmedNickname = nickname?.trim();
  final trimmedRole = role?.trim();
  final hasNickname = trimmedNickname != null && trimmedNickname.isNotEmpty;
  final hasRole = trimmedRole != null && trimmedRole.isNotEmpty;
  if (!hasNickname && !hasRole) return null;
  if (hasNickname && hasRole) return '$trimmedNickname [$trimmedRole]';
  return hasNickname ? trimmedNickname : '[$trimmedRole]';
}

class SessionAgentLabel extends StatelessWidget {
  final String label;

  const SessionAgentLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.smart_toy_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
