import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../l10n/app_localizations.dart';
import '../../services/bridge_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/diff_parser.dart'
    show DiffSelection, reconstructDiff, reconstructUnifiedDiff;
import 'state/commit_cubit.dart';
import 'state/git_view_cubit.dart';
import 'state/git_view_state.dart';
import 'widgets/commit_bottom_sheet.dart';
import 'widgets/diff_content_list.dart';
import 'widgets/diff_empty_state.dart';
import 'widgets/diff_error_state.dart';
import 'widgets/git_project_header.dart';
import 'widgets/git_file_list_sheet.dart';

/// Dedicated screen for viewing unified diffs.
///
/// Two modes:
/// - **Individual diff**: Pass [initialDiff] with raw diff text (from tool_result).
/// - **Session-wide diff**: Pass [projectPath] to request `git diff` from Bridge.
///
/// Returns a [DiffSelection] via [Navigator.pop] when Request Change is chosen.
@RoutePage()
class GitScreen extends StatefulWidget {
  /// Raw diff text for immediate display (individual tool result).
  final String? initialDiff;

  /// Project path — triggers `git diff` request on init.
  final String? projectPath;

  /// Display title (e.g. file path for individual diff).
  final String? title;

  /// Worktree path (if the session runs in a worktree).
  final String? worktreePath;

  /// Session ID (for updating session branch info after checkout).
  final String? sessionId;
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<DiffSelection>? onRequestChange;

  const GitScreen({
    super.key,
    this.initialDiff,
    this.projectPath,
    this.title,
    this.worktreePath,
    this.sessionId,
    this.embedded = false,
    this.onClose,
    this.onRequestChange,
  });

  @override
  State<GitScreen> createState() => _GitScreenState();
}

class _GitScreenState extends State<GitScreen> {
  late final AutoScrollController _scrollController;
  late final ValueNotifier<int?> _scrollToFileIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController();
    _scrollToFileIndex = ValueNotifier<int?>(null)
      ..addListener(_handleScrollTo);
  }

  @override
  void dispose() {
    _scrollToFileIndex
      ..removeListener(_handleScrollTo)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleScrollTo() async {
    final index = _scrollToFileIndex.value;
    if (index == null) return;
    _scrollToFileIndex.value = null;
    await _scrollController.scrollToIndex(
      index,
      preferPosition: AutoScrollPosition.begin,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bridge = context.read<BridgeService>();
    final isProjectMode = widget.projectPath != null;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => GitViewCubit(
            bridge: bridge,
            initialDiff: widget.initialDiff,
            projectPath: widget.projectPath,
            worktreePath: widget.worktreePath,
            sessionId: widget.sessionId,
          ),
        ),
        if (isProjectMode)
          BlocProvider(
            create: (_) => CommitCubit(
              bridge: bridge,
              projectPath: widget.projectPath!,
              sessionId: widget.sessionId,
            ),
          ),
      ],
      child: _GitScreenBody(
        title: widget.title,
        isProjectMode: isProjectMode,
        scrollController: _scrollController,
        scrollToFileIndex: _scrollToFileIndex,
        embedded: widget.embedded,
        onClose: widget.onClose,
        onRequestChange: widget.onRequestChange,
      ),
    );
  }
}

class _GitScreenBody extends StatelessWidget {
  final String? title;
  final bool isProjectMode;
  final AutoScrollController scrollController;
  final ValueNotifier<int?> scrollToFileIndex;
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<DiffSelection>? onRequestChange;

  const _GitScreenBody({
    this.title,
    this.isProjectMode = false,
    required this.scrollController,
    required this.scrollToFileIndex,
    this.embedded = false,
    this.onClose,
    this.onRequestChange,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GitViewCubit>().state;
    final cubit = context.read<GitViewCubit>();
    final l = AppLocalizations.of(context);

    final screenTitle = title ?? l.changes;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        leading: embedded
            ? IconButton(
                key: const ValueKey('close_git_pane_button'),
                onPressed: onClose,
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              )
            : null,
        title: Text(screenTitle, overflow: TextOverflow.ellipsis),
        actions: [
          if (isProjectMode && !state.loading)
            _FileListAppBarButton(
              state: state,
              onPressed: state.files.isEmpty
                  ? null
                  : () async {
                      final selectedIndex = await showGitFileListSheet(
                        context,
                        files: state.files,
                        viewMode: state.viewMode,
                      );
                      if (selectedIndex != null) {
                        scrollToFileIndex.value = selectedIndex;
                      }
                    },
            ),
          // Refresh (projectPath mode only)
          if (cubit.canRefresh && !state.loading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l.refresh,
              onPressed: cubit.refresh,
            ),
        ],
      ),
      bottomNavigationBar: isProjectMode
          ? _DiffBottomBar(
              state: state,
              cubit: cubit,
              onCommit: () => showCommitBottomSheet(context),
              onRevertAll: () => _confirmRevert(
                context,
                title: 'すべての変更を破棄しますか',
                message: '表示中の未ステージ変更をすべて破棄します。',
                onConfirm: cubit.revertAll,
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isProjectMode) GitProjectHeader(state: state, cubit: cubit),
          Expanded(
            child: _GitScreenContent(
              state: state,
              cubit: cubit,
              isProjectMode: isProjectMode,
              onConfirmRevert: _confirmRevert,
              onShowFileActionSheet: _showFileActionSheet,
              onShowHunkActionSheet: _showHunkActionSheet,
              scrollController: scrollController,
            ),
          ),
        ],
      ),
    );
  }

  void _showFileActionSheet(
    BuildContext context,
    GitViewCubit cubit,
    GitViewState state,
    int fileIdx,
  ) {
    if (fileIdx >= state.files.length) return;
    final file = state.files[fileIdx];
    final cs = Theme.of(context).colorScheme;
    final isStaged = state.viewMode == GitViewMode.staged;

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                file.filePath,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            // Stage (only in Changes tab)
            if (!isStaged)
              ListTile(
                leading: Icon(Icons.add_circle_outline, color: cs.primary),
                title: const Text('Stage'),
                onTap: () {
                  Navigator.pop(context);
                  cubit.stageFile(fileIdx);
                },
              ),
            // Unstage (only in Staged tab)
            if (isStaged)
              ListTile(
                leading: Icon(Icons.remove_circle_outline, color: cs.tertiary),
                title: const Text('Unstage'),
                onTap: () {
                  Navigator.pop(context);
                  cubit.unstageFile(fileIdx);
                },
              ),
            // Revert (only in Changes tab)
            if (!isStaged)
              ListTile(
                leading: Icon(Icons.undo, color: cs.error),
                title: const Text('Revert'),
                subtitle: const Text('Discard all changes in this file'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmRevert(
                    context,
                    title: 'この変更を破棄しますか',
                    message: 'このファイルの未ステージ変更をすべて破棄します。',
                    onConfirm: () => cubit.revertFile(fileIdx),
                  );
                },
              ),
            // Request Change (always available)
            ListTile(
              leading: Icon(Icons.rate_review_outlined, color: cs.secondary),
              title: const Text('Request Change'),
              subtitle: const Text('Send this file back to AI with feedback'),
              onTap: () {
                Navigator.pop(context);
                _requestChange(
                  context,
                  DiffSelection(diffText: reconstructUnifiedDiff(file)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHunkActionSheet(
    BuildContext context,
    GitViewCubit cubit,
    GitViewState state,
    int fileIdx,
    int hunkIdx,
  ) {
    if (fileIdx >= state.files.length) return;
    final file = state.files[fileIdx];
    if (hunkIdx >= file.hunks.length) return;
    final hunk = file.hunks[hunkIdx];
    final cs = Theme.of(context).colorScheme;
    final isStaged = state.viewMode == GitViewMode.staged;

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                file.filePath,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                hunk.header,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Theme.of(context).extension<AppColors>()!.subtleText,
                ),
              ),
            ),
            const Divider(height: 1),
            if (!isStaged)
              ListTile(
                leading: Icon(Icons.add_circle_outline, color: cs.primary),
                title: const Text('Stage'),
                onTap: () {
                  Navigator.pop(context);
                  cubit.stageHunk(fileIdx, hunkIdx);
                },
              ),
            if (isStaged)
              ListTile(
                leading: Icon(Icons.remove_circle_outline, color: cs.tertiary),
                title: const Text('Unstage'),
                onTap: () {
                  Navigator.pop(context);
                  cubit.unstageHunk(fileIdx, hunkIdx);
                },
              ),
            if (!isStaged)
              ListTile(
                leading: Icon(Icons.undo, color: cs.error),
                title: const Text('Revert'),
                subtitle: const Text('Discard changes in this hunk'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmRevert(
                    context,
                    title: 'この変更を破棄しますか',
                    message: 'このハンクの未ステージ変更を破棄します。',
                    onConfirm: () => cubit.revertHunk(fileIdx, hunkIdx),
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.rate_review_outlined, color: cs.secondary),
              title: const Text('Request Change'),
              subtitle: const Text('Send this hunk back to AI with feedback'),
              onTap: () {
                Navigator.pop(context);
                _requestChange(
                  context,
                  reconstructDiff(state.files, {'$fileIdx:$hunkIdx'}),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRevert(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revert'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onConfirm();
    }
  }

  void _requestChange(BuildContext context, DiffSelection selection) {
    if (embedded && onRequestChange != null) {
      onRequestChange!(selection);
      return;
    }
    context.router.maybePop(selection);
  }
}

class _FileListAppBarButton extends StatelessWidget {
  final GitViewState state;
  final VoidCallback? onPressed;

  const _FileListAppBarButton({required this.state, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IconButton(
      key: const ValueKey('git_file_list_button'),
      tooltip: 'Files',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.topic_outlined),
          if (state.files.isNotEmpty)
            Positioned(
              right: -8,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  '${state.files.length}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GitScreenContent extends StatelessWidget {
  final GitViewState state;
  final GitViewCubit cubit;
  final bool isProjectMode;
  final AutoScrollController scrollController;
  final Future<void> Function(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  })
  onConfirmRevert;
  final void Function(
    BuildContext context,
    GitViewCubit cubit,
    GitViewState state,
    int fileIdx,
  )
  onShowFileActionSheet;
  final void Function(
    BuildContext context,
    GitViewCubit cubit,
    GitViewState state,
    int fileIdx,
    int hunkIdx,
  )
  onShowHunkActionSheet;

  const _GitScreenContent({
    required this.state,
    required this.cubit,
    required this.isProjectMode,
    required this.scrollController,
    required this.onConfirmRevert,
    required this.onShowFileActionSheet,
    required this.onShowHunkActionSheet,
  });

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return DiffErrorState(error: state.error!, errorCode: state.errorCode);
    }

    if (state.files.isEmpty) {
      return DiffEmptyState(viewMode: isProjectMode ? state.viewMode : null);
    }

    return DiffContentList(
      files: state.files,
      scrollController: scrollController,
      collapsedFileIndices: state.collapsedFileIndices,
      onToggleCollapse: cubit.toggleCollapse,
      onLoadImage: cubit.loadImage,
      loadingImageIndices: state.loadingImageIndices,
      onSwipeStage: isProjectMode && state.viewMode != GitViewMode.staged
          ? cubit.stageFile
          : null,
      onSwipeUnstage: isProjectMode && state.viewMode == GitViewMode.staged
          ? cubit.unstageFile
          : null,
      onSwipeRevert: isProjectMode && state.viewMode != GitViewMode.staged
          ? (fileIdx) => onConfirmRevert(
              context,
              title: 'この変更を破棄しますか',
              message: 'このファイルの未ステージ変更をすべて破棄します。',
              onConfirm: () => cubit.revertFile(fileIdx),
            )
          : null,
      onSwipeStageHunk: isProjectMode && state.viewMode == GitViewMode.unstaged
          ? cubit.stageHunk
          : null,
      onSwipeUnstageHunk: isProjectMode && state.viewMode == GitViewMode.staged
          ? cubit.unstageHunk
          : null,
      onSwipeRevertHunk: isProjectMode && state.viewMode == GitViewMode.unstaged
          ? (fileIdx, hunkIdx) => onConfirmRevert(
              context,
              title: 'この変更を破棄しますか',
              message: 'このハンクの未ステージ変更を破棄します。',
              onConfirm: () => cubit.revertHunk(fileIdx, hunkIdx),
            )
          : null,
      onLongPressFile: isProjectMode
          ? (fileIdx) => onShowFileActionSheet(context, cubit, state, fileIdx)
          : null,
      onLongPressHunk: isProjectMode
          ? (fileIdx, hunkIdx) =>
                onShowHunkActionSheet(context, cubit, state, fileIdx, hunkIdx)
          : null,
      lineWrapEnabled: state.lineWrapEnabled,
    );
  }
}

/// Bottom bar with diff summary stats and context-aware git action buttons.
class _DiffBottomBar extends StatelessWidget {
  final GitViewState state;
  final GitViewCubit cubit;
  final VoidCallback onCommit;
  final VoidCallback onRevertAll;

  const _DiffBottomBar({
    required this.state,
    required this.cubit,
    required this.onCommit,
    required this.onRevertAll,
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
                  ],
                ),
              ),
              // Action buttons row
              Row(
                children: state.viewMode == GitViewMode.unstaged
                    ? [
                        Expanded(
                          child: _ActionButton(
                            key: const ValueKey('revert_all_button'),
                            icon: Icons.undo,
                            label: 'Revert All',
                            isError: true,
                            onPressed: _isBusy || files.isEmpty
                                ? null
                                : onRevertAll,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            key: const ValueKey('stage_all_button'),
                            icon: Icons.add_circle_outline,
                            label: 'Stage All',
                            primary: true,
                            onPressed: _isBusy || files.isEmpty
                                ? null
                                : cubit.stageAll,
                          ),
                        ),
                      ]
                    : [
                        Expanded(
                          child: _ActionButton(
                            key: const ValueKey('unstage_all_button'),
                            icon: Icons.remove_circle_outline,
                            label: 'Unstage All',
                            onPressed: _isBusy || files.isEmpty
                                ? null
                                : cubit.unstageAll,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            key: const ValueKey('commit_button'),
                            icon: Icons.check,
                            label: 'Commit',
                            primary: true,
                            onPressed: _isBusy ? null : onCommit,
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

/// Action button used in the bottom bar.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool isError;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.primary = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 12);

    if (primary) {
      if (isError) {
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: padding,
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            shape: shape,
          ),
          child: child,
        );
      }
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: padding,
          shape: shape,
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
        child: child,
      );
    }

    if (isError) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: padding,
          foregroundColor: cs.error,
          backgroundColor: cs.surface,
          shape: shape,
          side: BorderSide(
            color: onPressed != null
                ? cs.error
                : cs.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: padding,
        foregroundColor: cs.tertiary,
        backgroundColor: cs.surface,
        shape: shape,
        side: BorderSide(
          color: onPressed != null
              ? cs.tertiary.withValues(alpha: 0.7)
              : cs.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: child,
    );
  }
}
