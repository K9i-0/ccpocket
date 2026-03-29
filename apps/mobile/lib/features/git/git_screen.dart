import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../../services/bridge_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/diff_parser.dart';
import 'state/commit_cubit.dart';
import 'state/git_view_cubit.dart';
import 'state/git_view_state.dart';
import 'widgets/commit_bottom_sheet.dart';
import 'widgets/diff_content_list.dart';
import 'widgets/diff_empty_state.dart';
import 'widgets/diff_error_state.dart';
import 'widgets/diff_file_path_text.dart';
import 'widgets/diff_stats_badge.dart';

/// Dedicated screen for viewing unified diffs.
///
/// Two modes:
/// - **Individual diff**: Pass [initialDiff] with raw diff text (from tool_result).
/// - **Session-wide diff**: Pass [projectPath] to request `git diff` from Bridge.
///
/// Returns a [String] (reconstructed diff) via [Navigator.pop] when the user
/// selects hunks and taps the send-to-chat FAB.
@RoutePage()
class GitScreen extends StatelessWidget {
  /// Raw diff text for immediate display (individual tool result).
  final String? initialDiff;

  /// Project path — triggers `git diff` request on init.
  final String? projectPath;

  /// Display title (e.g. file path for individual diff).
  final String? title;

  /// Pre-selected hunk keys to restore selection state.
  final Set<String>? initialSelectedHunkKeys;

  const GitScreen({
    super.key,
    this.initialDiff,
    this.projectPath,
    this.title,
    this.initialSelectedHunkKeys,
  });

  @override
  Widget build(BuildContext context) {
    final bridge = context.read<BridgeService>();
    final isProjectMode = projectPath != null;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => GitViewCubit(
            bridge: bridge,
            initialDiff: initialDiff,
            projectPath: projectPath,
            initialSelectedHunkKeys: initialSelectedHunkKeys,
          ),
        ),
        if (isProjectMode)
          BlocProvider(
            create: (_) => CommitCubit(
              bridge: bridge,
              projectPath: projectPath!,
            ),
          ),
      ],
      child: _GitScreenBody(title: title, isProjectMode: isProjectMode),
    );
  }
}

class _GitScreenBody extends StatelessWidget {
  final String? title;
  final bool isProjectMode;

  const _GitScreenBody({this.title, this.isProjectMode = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GitViewCubit>().state;
    final cubit = context.read<GitViewCubit>();
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);

    final screenTitle = title ?? l.changes;

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle, overflow: TextOverflow.ellipsis),
        bottom: isProjectMode
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: _GitViewModeSegment(
                  viewMode: state.viewMode,
                  onChanged: cubit.switchMode,
                ),
              )
            : null,
        actions: [
          // Refresh (projectPath mode only)
          if (cubit.canRefresh && !state.selectionMode && !state.loading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l.refresh,
              onPressed: cubit.refresh,
            ),
          // Overflow menu for secondary actions
          if (state.files.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => _handleMenuAction(
                value,
                context,
                cubit,
                appColors,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'select',
                  child: ListTile(
                    leading: Icon(
                      Icons.alternate_email,
                      color: state.selectionMode
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(
                      state.selectionMode
                          ? l.cancelSelection
                          : l.selectAndAttach,
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (state.files.length > 1 && !state.selectionMode)
                  PopupMenuItem(
                    value: 'filter',
                    child: ListTile(
                      leading: const Icon(Icons.filter_list),
                      title: Text(l.filterFiles),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
        ],
      ),
      floatingActionButton: _buildFab(context, state, cubit, l),
      bottomNavigationBar: isProjectMode
          ? _DiffBottomBar(
              state: state,
              cubit: cubit,
              onCommit: () => showCommitBottomSheet(context),
              onPull: cubit.pull,
              onPush: cubit.push,
            )
          : null,
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? DiffErrorState(error: state.error!, errorCode: state.errorCode)
          : state.files.isEmpty
          ? DiffEmptyState(viewMode: isProjectMode ? state.viewMode : null)
          : DiffContentList(
              files: state.files,
              hiddenFileIndices: state.hiddenFileIndices,
              collapsedFileIndices: state.collapsedFileIndices,
              onToggleCollapse: cubit.toggleCollapse,
              onClearHidden: cubit.clearHidden,
              selectionMode: state.selectionMode,
              selectedHunkKeys: state.selectedHunkKeys,
              onToggleFileSelection: cubit.toggleFileSelection,
              onToggleHunkSelection: cubit.toggleHunkSelection,
              isFileFullySelected: cubit.isFileFullySelected,
              isFilePartiallySelected: cubit.isFilePartiallySelected,
              onLoadImage: cubit.loadImage,
              loadingImageIndices: state.loadingImageIndices,
              onSwipeStage: isProjectMode ? cubit.stageFile : null,
              onSwipeUnstage: isProjectMode ? cubit.unstageFile : null,
              // Long-press to enter selection mode
              onLongPressFile: isProjectMode && !state.selectionMode
                  ? (fileIdx) {
                      cubit.toggleSelectionMode();
                      cubit.toggleFileSelection(fileIdx);
                    }
                  : null,
            ),
    );
  }

  void _handleMenuAction(
    String action,
    BuildContext context,
    GitViewCubit cubit,
    AppColors appColors,
  ) {
    switch (action) {
      case 'select':
        cubit.toggleSelectionMode();
      case 'filter':
        _showFilterBottomSheet(context, appColors, cubit);
    }
  }

  Widget? _buildFab(
    BuildContext context,
    GitViewState state,
    GitViewCubit cubit,
    AppLocalizations l,
  ) {
    // Send-to-chat FAB (selection mode)
    if (state.selectionMode && cubit.hasAnySelection) {
      return FloatingActionButton.extended(
        key: const ValueKey('send_to_chat_fab'),
        onPressed: () {
          final selection = reconstructDiff(
            state.files,
            state.selectedHunkKeys,
          );
          context.router.maybePop(selection);
        },
        icon: const Icon(Icons.attach_file),
        label: Text(
          l.attachFilesAndHunks(
            cubit.selectionSummary.files,
            cubit.selectionSummary.hunks,
          ),
        ),
      );
    }

    return null;
  }

  void _showFilterBottomSheet(
    BuildContext context,
    AppColors appColors,
    GitViewCubit cubit,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return BlocBuilder<GitViewCubit, GitViewState>(
          bloc: cubit,
          builder: (context, state) {
            final l = AppLocalizations.of(context);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: Row(
                      children: [
                        Text(
                          l.filterFilesTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: appColors.toolResultTextExpanded,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: cubit.clearHidden,
                          child: Text(l.all),
                        ),
                        TextButton(
                          onPressed: () => cubit.setHiddenFiles(
                            Set<int>.from(
                              List.generate(state.files.length, (i) => i),
                            ),
                          ),
                          child: Text(l.none),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.files.length,
                      itemBuilder: (context, index) {
                        final file = state.files[index];
                        final visible = !state.hiddenFileIndices.contains(
                          index,
                        );
                        return CheckboxListTile(
                          value: visible,
                          onChanged: (_) => cubit.toggleFileVisibility(index),
                          title: DiffFilePathText(
                            filePath: file.filePath,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                          secondary: DiffStatsBadge(file: file),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// 2-tab segment: Changes (all) / Staged
class _GitViewModeSegment extends StatelessWidget {
  final GitViewMode viewMode;
  final ValueChanged<GitViewMode> onChanged;

  const _GitViewModeSegment({
    required this.viewMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SegmentedButton<GitViewMode>(
        segments: const [
          ButtonSegment(
            value: GitViewMode.all,
            label: Text('Changes'),
          ),
          ButtonSegment(
            value: GitViewMode.staged,
            label: Text('Staged'),
          ),
        ],
        selected: {viewMode},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// Bottom bar with diff summary stats and git action buttons (Pull / Commit / Push).
class _DiffBottomBar extends StatelessWidget {
  final GitViewState state;
  final GitViewCubit cubit;
  final VoidCallback onCommit;
  final VoidCallback onPull;
  final VoidCallback onPush;

  const _DiffBottomBar({
    required this.state,
    required this.cubit,
    required this.onCommit,
    required this.onPull,
    required this.onPush,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Calculate stats from visible files
    final files = state.files;
    var additions = 0;
    var deletions = 0;
    for (final f in files) {
      final s = f.stats;
      additions += s.added;
      deletions += s.removed;
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stats row
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (files.isNotEmpty) ...[
                      Text(
                        '${files.length} files',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (additions > 0)
                        Text(
                          '+$additions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      if (additions > 0 && deletions > 0)
                        const SizedBox(width: 4),
                      if (deletions > 0)
                        Text(
                          '-$deletions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.error,
                          ),
                        ),
                    ],
                    const Spacer(),
                    // Remote status badges
                    if (state.fetching)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (state.hasUpstream && state.commitsBehind > 0)
                      _RemoteBadge(
                        icon: Icons.arrow_downward,
                        count: state.commitsBehind,
                        color: cs.tertiary,
                      ),
                    if (state.hasUpstream && state.commitsAhead > 0)
                      _RemoteBadge(
                        icon: Icons.arrow_upward,
                        count: state.commitsAhead,
                        color: cs.primary,
                      ),
                    if (state.hasUpstream &&
                        state.commitsAhead == 0 &&
                        state.commitsBehind == 0 &&
                        !state.fetching)
                      Icon(Icons.check, size: 14, color: cs.onSurfaceVariant),
                    if (!state.hasUpstream && !state.fetching)
                      Text(
                        'No upstream',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              // Action buttons row
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      key: const ValueKey('pull_button'),
                      icon: Icons.download,
                      label: state.commitsBehind > 0
                          ? 'Pull (${state.commitsBehind})'
                          : 'Pull',
                      loading: state.pulling,
                      onPressed: _isBusy || !state.hasUpstream || state.commitsBehind == 0
                          ? null
                          : onPull,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      key: const ValueKey('commit_button'),
                      onPressed: _isBusy ? null : onCommit,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Commit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      key: const ValueKey('push_button'),
                      icon: Icons.upload,
                      label: state.commitsAhead > 0
                          ? 'Push (${state.commitsAhead})'
                          : 'Push',
                      loading: state.pushing,
                      onPressed: _isBusy || state.commitsAhead == 0
                          ? null
                          : onPush,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isBusy => state.staging || state.pulling || state.pushing;
}

/// Small badge showing ↑N or ↓N for remote ahead/behind.
class _RemoteBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _RemoteBadge({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 1),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined action button used in the bottom bar.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
