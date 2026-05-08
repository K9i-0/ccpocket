import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../l10n/app_localizations.dart';
import '../../models/git_diff_interaction_mode.dart';
import '../../services/bridge_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/diff_parser.dart'
    show DiffSelection, reconstructDiff, reconstructUnifiedDiff;
import '../../widgets/adaptive_context_menu.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../file_peek/file_peek_sheet.dart';
import '../session_list/workspace_shell_screen.dart';
import '../settings/state/settings_cubit.dart';
import 'state/commit_cubit.dart';
import 'state/git_view_cubit.dart';
import 'state/git_view_cache_service.dart';
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
  final ValueChanged<String>? onFilePeekOpened;

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
    this.onFilePeekOpened,
  });

  @override
  State<GitScreen> createState() => _GitScreenState();
}

class _GitScreenState extends State<GitScreen> {
  late final AutoScrollController _scrollController;
  late final ValueNotifier<int?> _scrollToFileIndex;
  GitViewCubit? _cachedCubit;
  String? _cachedCubitKey;
  bool _didScheduleCachedRefresh = false;

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
    final cachedLookup = _resolveCachedCubit(context);
    final gitViewCubit = cachedLookup?.cubit;

    if (cachedLookup != null &&
        !cachedLookup.created &&
        !_didScheduleCachedRefresh) {
      _didScheduleCachedRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        gitViewCubit?.refresh();
      });
    }

    return MultiBlocProvider(
      providers: [
        if (gitViewCubit != null)
          BlocProvider<GitViewCubit>.value(value: gitViewCubit)
        else
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
        projectPath: widget.projectPath,
        isProjectMode: isProjectMode,
        scrollController: _scrollController,
        scrollToFileIndex: _scrollToFileIndex,
        embedded: widget.embedded,
        onClose: widget.onClose,
        onRequestChange: widget.onRequestChange,
        onFilePeekOpened: widget.onFilePeekOpened,
      ),
    );
  }

  GitViewCacheLookup? _resolveCachedCubit(BuildContext context) {
    final sessionId = widget.sessionId;
    final projectPath = widget.projectPath;
    if (widget.initialDiff != null ||
        sessionId == null ||
        projectPath == null) {
      return null;
    }

    final key = '$sessionId\n$projectPath\n${widget.worktreePath ?? ''}';
    if (_cachedCubit != null && _cachedCubitKey == key) {
      return GitViewCacheLookup(cubit: _cachedCubit!, created: false);
    }

    GitViewCacheLookup lookup;
    try {
      lookup = context.read<GitViewCacheService>().getOrCreate(
        sessionId: sessionId,
        projectPath: projectPath,
        worktreePath: widget.worktreePath,
      );
    } catch (_) {
      return null;
    }
    _cachedCubit = lookup.cubit;
    _cachedCubitKey = key;
    _didScheduleCachedRefresh = lookup.created;
    return lookup;
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
  final ValueChanged<String>? onFilePeekOpened;

  const _GitScreenBody({
    this.title,
    this.projectPath,
    this.isProjectMode = false,
    required this.scrollController,
    required this.scrollToFileIndex,
    this.embedded = false,
    this.onClose,
    this.onRequestChange,
    this.onFilePeekOpened,
  });

  final String? projectPath;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GitViewCubit>().state;
    final cubit = context.read<GitViewCubit>();
    final interactionMode = _gitDiffInteractionModeOf(context);
    final l = AppLocalizations.of(context);
    final shell = WorkspaceShellScreen.maybeOf(context);
    final chrome = resolveWorkspacePaneChrome(
      platform: Theme.of(context).platform,
      isAdaptiveWorkspace: shell != null && !shell.isSinglePane,
      isLeftPaneVisible: shell?.isLeftPaneVisible ?? false,
      slot: WorkspacePaneSlot.right,
    );

    final screenTitle = title ?? l.changes;
    final leading = embedded
        ? IconButton(
            key: const ValueKey('close_git_pane_button'),
            onPressed: onClose,
            style: chrome.useMacOSAdaptiveChrome
                ? chrome.compactButtonStyle()
                : null,
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          )
        : null;

    return Scaffold(
      appBar: chrome.wrapAppBar(
        AppBar(
          toolbarHeight: chrome.toolbarHeight,
          automaticallyImplyLeading: !embedded,
          leading: chrome.wrapLeading(leading),
          leadingWidth: chrome.resolveLeadingWidth(
            hasLeading: leading != null,
            baseWidth: chrome.useMacOSAdaptiveChrome
                ? kWorkspaceMacOSToolbarLeadingSlotWidth
                : kToolbarHeight,
          ),
          titleSpacing: chrome.resolveTitleSpacing(hasLeading: leading != null),
          title: chrome.wrapTitle(
            Text(screenTitle, overflow: TextOverflow.ellipsis),
          ),
          actions: chrome.padActions([
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
                style: chrome.useMacOSAdaptiveChrome
                    ? chrome.compactButtonStyle()
                    : null,
                onPressed: cubit.refresh,
              ),
          ]),
        ),
      ),
      bottomNavigationBar: isProjectMode
          ? _DiffBottomBar(
              state: state,
              cubit: cubit,
              onCommit: () => showCommitBottomSheet(context),
              onRevertAll: () => _confirmRevert(
                context,
                title: l.gitDiscardAllChangesTitle,
                message: l.gitDiscardVisibleUnstagedChangesMessage,
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
              interactionMode: interactionMode,
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

  GitDiffInteractionMode _gitDiffInteractionModeOf(BuildContext context) {
    try {
      return context.select(
        (SettingsCubit cubit) => cubit.state.gitDiffInteractionMode,
      );
    } catch (_) {
      return GitDiffInteractionMode.quickActions;
    }
  }

  void _showFileActionSheet(
    BuildContext context,
    GitViewCubit cubit,
    GitViewState state,
    int fileIdx,
    Offset? position,
  ) async {
    if (fileIdx >= state.files.length) return;
    final file = state.files[fileIdx];
    final isStaged = state.viewMode == GitViewMode.staged;

    final action = await showAdaptiveActionMenu<String>(
      context: context,
      position: position,
      header: _DiffActionMenuHeader(filePath: file.filePath),
      items: [
        const AdaptiveActionMenuItem(
          key: ValueKey('git_view_file_action'),
          value: 'view_file',
          icon: Icons.description_outlined,
          label: 'View File',
          subtitle: 'Open the full current file',
        ),
        if (!isStaged)
          const AdaptiveActionMenuItem(
            value: 'stage',
            icon: Icons.add_circle_outline,
            label: 'Stage',
          ),
        if (isStaged)
          const AdaptiveActionMenuItem(
            value: 'unstage',
            icon: Icons.remove_circle_outline,
            label: 'Unstage',
          ),
        if (!isStaged)
          const AdaptiveActionMenuItem(
            value: 'revert',
            icon: Icons.undo,
            label: 'Revert',
            subtitle: 'Discard all changes in this file',
            destructive: true,
          ),
        const AdaptiveActionMenuItem(
          value: 'request_change',
          icon: Icons.rate_review_outlined,
          label: 'Request Change',
          subtitle: 'Send this file back to AI with feedback',
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'view_file':
        _openFilePeek(context, file.filePath);
      case 'stage':
        cubit.stageFile(fileIdx);
      case 'unstage':
        cubit.unstageFile(fileIdx);
      case 'revert':
        _confirmRevert(
          context,
          title: AppLocalizations.of(context).gitDiscardChangeTitle,
          message: AppLocalizations.of(
            context,
          ).gitDiscardFileUnstagedChangesMessage,
          onConfirm: () => cubit.revertFile(fileIdx),
        );
      case 'request_change':
        _requestChange(
          context,
          DiffSelection(diffText: reconstructUnifiedDiff(file)),
        );
    }
  }

  void _showHunkActionSheet(
    BuildContext context,
    GitViewCubit cubit,
    GitViewState state,
    int fileIdx,
    int hunkIdx,
    Offset? position,
  ) async {
    if (fileIdx >= state.files.length) return;
    final file = state.files[fileIdx];
    if (hunkIdx >= file.hunks.length) return;
    final hunk = file.hunks[hunkIdx];
    final isStaged = state.viewMode == GitViewMode.staged;

    final action = await showAdaptiveActionMenu<String>(
      context: context,
      position: position,
      header: _DiffActionMenuHeader(
        filePath: file.filePath,
        subtitle: hunk.header,
      ),
      items: [
        const AdaptiveActionMenuItem(
          key: ValueKey('git_view_file_action'),
          value: 'view_file',
          icon: Icons.description_outlined,
          label: 'View File',
          subtitle: 'Open the full current file',
        ),
        if (!isStaged)
          const AdaptiveActionMenuItem(
            value: 'stage',
            icon: Icons.add_circle_outline,
            label: 'Stage',
          ),
        if (isStaged)
          const AdaptiveActionMenuItem(
            value: 'unstage',
            icon: Icons.remove_circle_outline,
            label: 'Unstage',
          ),
        if (!isStaged)
          const AdaptiveActionMenuItem(
            value: 'revert',
            icon: Icons.undo,
            label: 'Revert',
            subtitle: 'Discard changes in this hunk',
            destructive: true,
          ),
        const AdaptiveActionMenuItem(
          value: 'request_change',
          icon: Icons.rate_review_outlined,
          label: 'Request Change',
          subtitle: 'Send this hunk back to AI with feedback',
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'view_file':
        _openFilePeek(context, file.filePath);
      case 'stage':
        cubit.stageHunk(fileIdx, hunkIdx);
      case 'unstage':
        cubit.unstageHunk(fileIdx, hunkIdx);
      case 'revert':
        _confirmRevert(
          context,
          title: AppLocalizations.of(context).gitDiscardChangeTitle,
          message: AppLocalizations.of(
            context,
          ).gitDiscardHunkUnstagedChangesMessage,
          onConfirm: () => cubit.revertHunk(fileIdx, hunkIdx),
        );
      case 'request_change':
        _requestChange(
          context,
          reconstructDiff(state.files, {'$fileIdx:$hunkIdx'}),
        );
    }
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

  Future<void> _openFilePeek(BuildContext context, String filePath) {
    final projectPath = this.projectPath;
    if (projectPath == null || projectPath.isEmpty) {
      return Future<void>.value();
    }
    return showFilePeekSheet(
      context,
      bridge: context.read<BridgeService>(),
      projectPath: projectPath,
      filePath: filePath,
      onOpened: () => onFilePeekOpened?.call(filePath),
    );
  }
}

class _DiffActionMenuHeader extends StatelessWidget {
  final String filePath;
  final String? subtitle;

  const _DiffActionMenuHeader({required this.filePath, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final subtleText = Theme.of(context).extension<AppColors>()!.subtleText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filePath,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: subtleText,
            ),
          ),
        ],
      ],
    );
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
  final GitDiffInteractionMode interactionMode;
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
    Offset? position,
  )
  onShowFileActionSheet;
  final void Function(
    BuildContext context,
    GitViewCubit cubit,
    GitViewState state,
    int fileIdx,
    int hunkIdx,
    Offset? position,
  )
  onShowHunkActionSheet;

  const _GitScreenContent({
    required this.state,
    required this.cubit,
    required this.isProjectMode,
    required this.interactionMode,
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
              title: AppLocalizations.of(context).gitDiscardChangeTitle,
              message: AppLocalizations.of(
                context,
              ).gitDiscardFileUnstagedChangesMessage,
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
              title: AppLocalizations.of(context).gitDiscardChangeTitle,
              message: AppLocalizations.of(
                context,
              ).gitDiscardHunkUnstagedChangesMessage,
              onConfirm: () => cubit.revertHunk(fileIdx, hunkIdx),
            )
          : null,
      onLongPressFile: isProjectMode
          ? (fileIdx, position) =>
                onShowFileActionSheet(context, cubit, state, fileIdx, position)
          : null,
      onLongPressHunk: isProjectMode
          ? (fileIdx, hunkIdx, position) => onShowHunkActionSheet(
              context,
              cubit,
              state,
              fileIdx,
              hunkIdx,
              position,
            )
          : null,
      lineWrapEnabled: interactionMode == GitDiffInteractionMode.quickActions
          ? state.lineWrapEnabled
          : false,
      interactionMode: interactionMode,
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
