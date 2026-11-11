import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../state/chat_session_cubit.dart';
import '../state/chat_session_state.dart';

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
      onTap: () => _showLiveSheet(context),
    );
  }

  /// Lists the tasks and follows the session while the sheet stays open.
  void _showLiveSheet(BuildContext context) {
    final cubit = context.read<ChatSessionCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: BlocConsumer<ChatSessionCubit, ChatSessionState>(
          listenWhen: (prev, next) =>
              prev.backgroundTasks.isNotEmpty && next.backgroundTasks.isEmpty,
          listener: (context, _) => Navigator.of(context).maybePop(),
          buildWhen: (prev, next) =>
              prev.backgroundTasks != next.backgroundTasks,
          builder: (_, state) =>
              BackgroundTasksSheet(tasks: state.backgroundTasks),
        ),
      ),
    );
  }
}

class BackgroundTasksBar extends StatelessWidget {
  const BackgroundTasksBar({
    super.key,
    required this.tasks,
    this.onStop,
    this.onTap,
  });

  final List<BackgroundTaskInfo> tasks;
  final VoidCallback? onStop;

  /// Opens the task list. Defaults to a sheet with the current [tasks].
  final VoidCallback? onTap;

  static String taskLabel(BackgroundTaskInfo task) {
    final description = task.description?.trim();
    if (description != null && description.isNotEmpty) return description;
    return taskKindLabel(task);
  }

  /// Short name of what kind of task this is.
  static String taskKindLabel(BackgroundTaskInfo task) =>
      task.subagentType ??
      switch (task.taskType) {
        'local_bash' => 'Shell',
        'codex_terminal' => 'Terminal',
        'monitor' => 'Monitor',
        'local_workflow' => 'Workflow',
        'local_agent' || 'remote_agent' || 'codex_agent' => 'Agent',
        final other => other,
      };

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
      child: InkWell(
        onTap:
            onTap ??
            () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => BackgroundTasksSheet(tasks: tasks),
            ),
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
      ),
    );
  }
}

/// Plain list of the running background tasks.
class BackgroundTasksSheet extends StatelessWidget {
  const BackgroundTasksSheet({super.key, required this.tasks});

  final List<BackgroundTaskInfo> tasks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          key: const ValueKey('background_tasks_sheet'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${l.backgroundTasksRunning} (${tasks.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [for (final task in tasks) _buildTile(task, cs)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BackgroundTaskInfo task, ColorScheme cs) {
    final label = BackgroundTasksBar.taskLabel(task);
    final kind = BackgroundTasksBar.taskKindLabel(task);
    return ListTile(
      key: ValueKey('background_task_${task.taskId}'),
      dense: true,
      leading: Icon(
        task.isAgent ? Icons.smart_toy_outlined : Icons.terminal,
        size: 20,
        color: cs.onSurfaceVariant,
      ),
      title: Text(label),
      subtitle: kind == label ? null : Text(kind),
    );
  }
}
