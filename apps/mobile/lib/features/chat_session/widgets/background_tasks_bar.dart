import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../state/chat_session_cubit.dart';

/// Shows live background tasks of the current session: Claude shells,
/// monitors and subagents, or Codex terminals and child agents. A turn can
/// finish while these keep running.
class SessionBackgroundTasksBar extends StatelessWidget {
  const SessionBackgroundTasksBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = context.select<ChatSessionCubit, List<BackgroundTaskInfo>>(
      (cubit) => cubit.state.backgroundTasks,
    );
    if (tasks.isEmpty) return const SizedBox.shrink();
    // Between Claude turns, interrupting stops the background tasks. While a
    // turn runs, the input bar's stop button interrupts the turn instead.
    final canStop = context.select<ChatSessionCubit, bool>(
      (cubit) => !cubit.isCodex && cubit.state.status == ProcessStatus.idle,
    );
    return BackgroundTasksBar(
      tasks: tasks,
      onStop: canStop ? context.read<ChatSessionCubit>().interrupt : null,
    );
  }
}

class BackgroundTasksBar extends StatelessWidget {
  const BackgroundTasksBar({super.key, required this.tasks, this.onStop});

  final List<BackgroundTaskInfo> tasks;
  final VoidCallback? onStop;

  static String taskLabel(BackgroundTaskInfo task) {
    final description = task.description?.trim();
    if (description != null && description.isNotEmpty) return description;
    return task.subagentType ?? task.taskType;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final first = taskLabel(tasks.first);
    final more = tasks.length > 1
        ? ' · ${l.backgroundTasksMore(tasks.length - 1)}'
        : '';

    return Material(
      key: const ValueKey('background_tasks_bar'),
      color: cs.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l.backgroundTasksRunning,
                style: textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$first$more',
                  key: const ValueKey('background_tasks_bar_label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: cs.onSurface),
                ),
              ),
              if (onStop != null)
                IconButton(
                  key: const ValueKey('background_tasks_stop_button'),
                  tooltip: l.backgroundTasksStop,
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  iconSize: 20,
                  color: cs.error,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
