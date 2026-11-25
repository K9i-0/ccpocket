import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../theme/swarm_colors.dart';
import '../state/chat_session_cubit.dart';
import '../state/chat_session_state.dart';

bool _isSwarmTask(BackgroundTaskInfo task) => task.subagentType == 'swarm';

String _stripSwarmPrefix(String text) {
  const prefix = 'Swarm: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}

/// Shows live background tasks of the current session: Claude shells,
/// monitors and subagents, Codex terminals and child agents, or Antigravity
/// swarm workers. A turn can finish while these keep running.
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
      (cubit) =>
          cubit.supportsBackgroundTaskStop &&
          cubit.state.status == ProcessStatus.idle,
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

  static String taskLabel(BackgroundTaskInfo task, {bool stripSwarm = false}) {
    final rawDescription = task.description?.trim();
    final description = stripSwarm && rawDescription != null
        ? _stripSwarmPrefix(rawDescription)
        : rawDescription;
    final base = (description != null && description.isNotEmpty)
        ? description
        : taskKindLabel(task);
    final summary = task.summary?.trim();
    if (summary != null && summary.isNotEmpty && summary != base) {
      return '$base — $summary';
    }
    return base;
  }

  /// Short name of what kind of task this is.
  static String taskKindLabel(BackgroundTaskInfo task) =>
      task.subagentType ??
      switch (task.taskType) {
        'local_bash' => 'Shell',
        'codex_terminal' || 'antigravity_terminal' => 'Terminal',
        'antigravity_timer' => 'Timer',
        'monitor' => 'Monitor',
        'local_workflow' => 'Workflow',
        'local_agent' ||
        'remote_agent' ||
        'codex_agent' ||
        'antigravity_agent' => 'Agent',
        final other => other,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final isSwarmOnly = tasks.isNotEmpty && tasks.every(_isSwarmTask);
    final first = taskLabel(tasks.first, stripSwarm: isSwarmOnly);
    final more = tasks.length > 1
        ? ' · ${l.backgroundTasksMore(tasks.length - 1)}'
        : '';
    final leadingLabel = isSwarmOnly
        ? 'Swarm (${tasks.length})'
        : l.backgroundTasksRunning;

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
                if (isSwarmOnly) ...[
                  Icon(Icons.hub_outlined, size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                ],
                Text(
                  leadingLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: isSwarmOnly ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                // The icon and colour of the worker named next, as on its board posts.
                if (isSwarmOnly && tasks.first.swarmIndex != null) ...[
                  SwarmMemberIcon(
                    key: const ValueKey('background_tasks_bar_swarm_icon'),
                    index: tasks.first.swarmIndex,
                    size: 15,
                    color: swarmWorkerColor(
                      Theme.of(context).brightness,
                      tasks.first.swarmIndex!,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
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
                  )
                else
                  Icon(
                    Icons.keyboard_arrow_up,
                    size: 16,
                    color: cs.onSurfaceVariant,
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
    final l = AppLocalizations.of(context);
    final isSwarmOnly = tasks.isNotEmpty && tasks.every(_isSwarmTask);
    final headerTitle = isSwarmOnly
        ? 'Swarm (${tasks.length})'
        : '${l.backgroundTasksRunning} (${tasks.length})';

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
                child: Row(
                  children: [
                    if (isSwarmOnly) ...[
                      Icon(
                        Icons.hub_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      headerTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final task in tasks) _BackgroundTaskTile(task: task),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundTaskTile extends StatelessWidget {
  final BackgroundTaskInfo task;

  const _BackgroundTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSwarm = _isSwarmTask(task);
    final rawDescription = task.description?.trim();
    final description = isSwarm && rawDescription != null
        ? _stripSwarmPrefix(rawDescription)
        : rawDescription;
    final kind = BackgroundTasksBar.taskKindLabel(task);
    final title = (description != null && description.isNotEmpty)
        ? description
        : kind;
    final summary = task.summary?.trim();
    final tool = task.lastToolName?.trim();
    final isWaiting = isSwarm && summary == 'Waiting';
    final subtitleParts = <String>[
      if (!isSwarm && kind != title) kind,
      if (summary != null && summary.isNotEmpty && summary != title) summary,
      if (tool != null && tool.isNotEmpty) tool,
    ];
    final leadingColor = !isSwarm
        ? cs.onSurfaceVariant
        : task.swarmIndex != null
        ? swarmWorkerColor(
            Theme.of(context).brightness,
            task.swarmIndex!,
          ).withValues(alpha: isWaiting ? 0.55 : 1)
        : isWaiting
        ? cs.onSurfaceVariant
        : cs.tertiary;
    return ListTile(
      key: ValueKey('background_task_${task.taskId}'),
      dense: true,
      leading: isSwarm
          ? SwarmMemberIcon(
              key: ValueKey('background_task_icon_${task.taskId}'),
              index: task.swarmIndex,
              size: 22,
              // A numbered swarm worker keeps its colour while it waits, dimmed.
              color: leadingColor,
            )
          : Icon(
              task.isAgent ? Icons.smart_toy_outlined : Icons.terminal,
              size: 20,
              color: leadingColor,
            ),
      title: Text(
        title,
        style: isSwarm
            ? TextStyle(
                fontWeight: isWaiting ? FontWeight.w500 : FontWeight.w600,
                color: isWaiting ? cs.onSurfaceVariant : cs.onSurface,
              )
            : null,
      ),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
    );
  }
}
