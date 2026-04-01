import 'package:flutter/material.dart';

import '../state/git_view_cubit.dart';
import '../state/git_view_state.dart';
import 'branch_selector_sheet.dart';
import 'git_view_mode_segment.dart';

class GitProjectHeader extends StatelessWidget {
  final GitViewState state;
  final GitViewCubit cubit;

  const GitProjectHeader({super.key, required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      child: Container(
        key: const ValueKey('git_project_header'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GitHeaderControls(state: state, cubit: cubit),
            const SizedBox(height: 8),
            GitViewModeSegment(
              viewMode: state.viewMode,
              onChanged: cubit.switchMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _GitHeaderControls extends StatelessWidget {
  final GitViewState state;
  final GitViewCubit cubit;

  const _GitHeaderControls({required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BranchSelectorButton(
            state: state,
            projectPath: cubit.projectPath,
          ),
        ),
        const SizedBox(width: 8),
        _SyncActionRow(state: state, cubit: cubit),
      ],
    );
  }
}

class _BranchSelectorButton extends StatelessWidget {
  final GitViewState state;
  final String? projectPath;

  const _BranchSelectorButton({required this.state, required this.projectPath});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayName = state.currentBranch ?? '...';

    return LayoutBuilder(
      builder: (context, constraints) {
        final showWorktreeBadge =
            state.isWorktree && constraints.maxWidth > 240;

        return Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const ValueKey('branch_selector_button'),
            onTap: projectPath != null
                ? () => showBranchSelectorSheet(context, projectPath!)
                : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    state.isWorktree ? Icons.fork_right : Icons.commit,
                    size: 17,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  if (showWorktreeBadge) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'worktree',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SyncActionRow extends StatelessWidget {
  final GitViewState state;
  final GitViewCubit cubit;

  const _SyncActionRow({required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    final isBusy = state.staging || state.pulling || state.pushing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CompactCountActionButton(
          key: const ValueKey('pull_button'),
          icon: Icons.download,
          countLabel: state.hasUpstream ? '${state.commitsBehind}' : '-',
          accessibilityLabel: state.hasUpstream
              ? 'Pull ${state.commitsBehind} commits'
              : 'Pull unavailable',
          loading: state.pulling,
          onPressed: isBusy || !state.hasUpstream || state.commitsBehind == 0
              ? null
              : cubit.pull,
        ),
        const SizedBox(width: 8),
        _CompactCountActionButton(
          key: const ValueKey('push_button'),
          icon: Icons.upload,
          countLabel: state.hasUpstream ? '${state.commitsAhead}' : '-',
          accessibilityLabel: state.hasUpstream
              ? 'Push ${state.commitsAhead} commits'
              : 'Push unavailable',
          loading: state.pushing,
          onPressed: isBusy || state.commitsAhead == 0 ? null : cubit.push,
        ),
      ],
    );
  }
}

class _CompactCountActionButton extends StatelessWidget {
  final IconData icon;
  final String countLabel;
  final String accessibilityLabel;
  final VoidCallback? onPressed;
  final bool loading;

  const _CompactCountActionButton({
    super.key,
    required this.icon,
    required this.countLabel,
    required this.accessibilityLabel,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 56,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 40),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          visualDensity: VisualDensity.compact,
          side: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 14),
            const SizedBox(width: 3),
            Text(
              countLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );

    return Tooltip(
      message: accessibilityLabel,
      child: Semantics(button: true, label: accessibilityLabel, child: child),
    );
  }
}
