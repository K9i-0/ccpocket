import 'package:flutter/material.dart';

enum CodexGoalStatus {
  active,
  paused,
  blocked,
  usageLimited,
  budgetLimited,
  complete,
}

@immutable
class CodexGoalCardData {
  final String objective;
  final CodexGoalStatus status;

  const CodexGoalCardData({
    required this.objective,
    this.status = CodexGoalStatus.active,
  });
}

class CodexGoalCard extends StatelessWidget {
  final CodexGoalCardData goal;
  final VoidCallback onEdit;
  final VoidCallback onTogglePaused;
  final VoidCallback onClear;

  const CodexGoalCard({
    super.key,
    required this.goal,
    required this.onEdit,
    required this.onTogglePaused,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(goal.status, cs);

    return Semantics(
      key: const ValueKey('goal_card'),
      container: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 2),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant, width: 0.75),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GoalHeader(
              status: goal.status,
              statusColor: statusColor,
              onEdit: onEdit,
              onTogglePaused: onTogglePaused,
              onClear: onClear,
            ),
            const SizedBox(height: 2),
            Text(
              goal.objective,
              key: const ValueKey('goal_objective'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalHeader extends StatelessWidget {
  final CodexGoalStatus status;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onTogglePaused;
  final VoidCallback onClear;

  const _GoalHeader({
    required this.status,
    required this.statusColor,
    required this.onEdit,
    required this.onTogglePaused,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPaused = status == CodexGoalStatus.paused;
    final canTogglePaused =
        status == CodexGoalStatus.active || status == CodexGoalStatus.paused;

    return Row(
      children: [
        Icon(Icons.track_changes, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          'Goal',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _GoalStatusChip(status: status, color: statusColor),
          ),
        ),
        _GoalActionButton(
          key: const ValueKey('goal_edit_button'),
          tooltip: 'Edit goal',
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        _GoalActionButton(
          key: const ValueKey('goal_pause_button'),
          tooltip: isPaused ? 'Resume goal' : 'Pause goal',
          icon: isPaused
              ? Icons.play_arrow_rounded
              : Icons.pause_circle_outline,
          onPressed: canTogglePaused ? onTogglePaused : null,
        ),
        _GoalActionButton(
          key: const ValueKey('goal_clear_button'),
          tooltip: 'Clear goal',
          icon: Icons.delete_outline,
          onPressed: onClear,
        ),
      ],
    );
  }
}

class _GoalStatusChip extends StatelessWidget {
  final CodexGoalStatus status;
  final Color color;

  const _GoalStatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('goal_status_chip'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GoalActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GoalActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      color: cs.onSurfaceVariant,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    );
  }
}

Color _statusColor(CodexGoalStatus status, ColorScheme cs) => switch (status) {
  CodexGoalStatus.active => cs.secondary,
  CodexGoalStatus.paused => cs.primary,
  CodexGoalStatus.blocked => cs.tertiary,
  CodexGoalStatus.usageLimited || CodexGoalStatus.budgetLimited => cs.error,
  CodexGoalStatus.complete => cs.secondary,
};

String _statusLabel(CodexGoalStatus status) => switch (status) {
  CodexGoalStatus.active => 'Pursuing',
  CodexGoalStatus.paused => 'Paused',
  CodexGoalStatus.blocked => 'Blocked',
  CodexGoalStatus.usageLimited => 'Usage limited',
  CodexGoalStatus.budgetLimited => 'Budget limited',
  CodexGoalStatus.complete => 'Complete',
};
