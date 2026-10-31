import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../state/chat_session_cubit.dart';

/// Shows live background tasks (shells, monitors, subagents) of the current
/// session. A Claude turn can finish while these keep running, so the session
/// is not done even when its status is idle.
class SessionBackgroundTasksBar extends StatelessWidget {
  const SessionBackgroundTasksBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = context.select<ChatSessionCubit, List<BackgroundTaskInfo>>(
      (cubit) => cubit.state.backgroundTasks,
    );
    if (tasks.isEmpty) return const SizedBox.shrink();
    return BackgroundTasksBar(tasks: tasks);
  }
}

class BackgroundTasksBar extends StatelessWidget {
  const BackgroundTasksBar({super.key, required this.tasks});

  final List<BackgroundTaskInfo> tasks;

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
            ],
          ),
        ),
      ),
    );
  }
}
