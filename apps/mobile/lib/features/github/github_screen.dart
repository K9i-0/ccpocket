import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../services/bridge_service.dart';
import '../../services/draft_service.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../session_list/workspace_shell_screen.dart';
import 'state/github_list_cubit.dart';
import 'state/github_list_state.dart';
import 'state/github_selection_cubit.dart';
import 'state/github_selection_state.dart';
import 'state/github_view_cache_service.dart';
import 'widgets/github_error_view.dart';
import 'widgets/github_filter_bar.dart';
import 'widgets/github_item_detail_sheet.dart';
import 'widgets/github_item_tile.dart';

/// Open issues and pull requests of a project, picked for one session.
///
/// The screen only reads from GitHub and sends nothing. What is picked here
/// is the session's selection in [GitHubSelectionCubit]: it shows up at once
/// as cards above that session's composer, and its URLs are appended to the
/// next message the user sends.
class GitHubScreen extends StatefulWidget {
  final String projectPath;

  /// The session the selection belongs to.
  final String sessionId;
  final bool embedded;
  final VoidCallback? onClose;

  const GitHubScreen({
    super.key,
    required this.projectPath,
    required this.sessionId,
    this.embedded = false,
    this.onClose,
  });

  @override
  State<GitHubScreen> createState() => _GitHubScreenState();
}

/// Tab order shown in the screen.
const _tabKinds = [GitHubItemKind.issue, GitHubItemKind.pr];

class _GitHubScreenState extends State<GitHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final GitHubListCubit _cubit;
  late final GitHubSelectionCubit _selection;
  bool _ownsCubit = false;

  GitHubItemKind get _kind => _tabKinds[_tabController.index];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabKinds.length, vsync: this)
      ..addListener(_onTabChanged);
    _selection = context.read<DraftService>().githubSelection;
    final bridge = context.read<BridgeService>();
    final cache = context.read<GitHubViewCacheService?>();
    if (cache == null || !cache.serves(bridge)) {
      _cubit = GitHubListCubit(bridge: bridge, projectPath: widget.projectPath);
      _ownsCubit = true;
      _loadAllTabs();
    } else {
      final lookup = cache.getOrCreate(widget.projectPath);
      _cubit = lookup.cubit;
      if (lookup.created) {
        _loadAllTabs();
      } else {
        // Show the cached list at once and bring it up to date behind it.
        _refreshLoadedTabs();
      }
    }
  }

  /// Loads every tab up front so each tab label shows its count.
  void _loadAllTabs() {
    for (final kind in _tabKinds) {
      _cubit.ensureLoaded(kind);
    }
  }

  void _refreshLoadedTabs() {
    for (final kind in _tabKinds) {
      if (!_cubit.state.tab(kind).loading) unawaited(_cubit.refresh(kind));
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _cubit.ensureLoaded(_kind);
    setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    if (_ownsCubit) unawaited(_cubit.close());
    super.dispose();
  }

  /// Adds every visible item of the current tab except drafts, which are
  /// not ready for work unless picked on purpose.
  void _selectAllVisible() {
    final state = _cubit.state;
    _selection.addAll(widget.sessionId, [
      for (final item in state.visibleItems(_kind))
        if (!item.isDraft)
          ?GitHubSelectedItem.fromSummary(
            item,
            _kind,
            repository: state.repository,
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final shell = WorkspaceShellScreen.maybeOf(context);
    final chrome = resolveWorkspacePaneChrome(
      platform: Theme.of(context).platform,
      isAdaptiveWorkspace: shell != null && !shell.isSinglePane,
      isLeftPaneVisible: shell?.isLeftPaneVisible ?? false,
      slot: WorkspacePaneSlot.right,
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider<GitHubListCubit>.value(value: _cubit),
        BlocProvider<GitHubSelectionCubit>.value(value: _selection),
      ],
      child: BlocBuilder<GitHubSelectionCubit, GitHubSelectionState>(
        builder: (context, _) {
          final selectedCount = _selection.items(widget.sessionId).length;
          return BlocBuilder<GitHubListCubit, GitHubListState>(
            builder: (context, state) => Scaffold(
              appBar: chrome.wrapAppBar(
                _GitHubAppBar(
                  state: state,
                  selectedCount: selectedCount,
                  chrome: chrome,
                  tabController: _tabController,
                  embedded: widget.embedded,
                  onClose: widget.onClose,
                  onSelectAll: _selectAllVisible,
                  onClearSelection: () => _selection.clear(widget.sessionId),
                  onRefresh: () => unawaited(_cubit.refresh(_kind)),
                ),
              ),
              body: Column(
                children: [
                  GitHubFilterBar(
                    kind: _kind,
                    filters: state.filters,
                    labels: state.availableLabels(_kind),
                    onHideDraftsChanged: _cubit.setHideDrafts,
                    onDependabotOnlyChanged: _cubit.setDependabotOnly,
                    onLabelChanged: _cubit.setLabel,
                  ),
                  if (selectedCount > 0 &&
                      state.visibleItems(_kind).any((item) => item.isDraft))
                    const _GitHubDraftNotice(),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        for (final kind in _tabKinds)
                          GitHubItemList(
                            key: ValueKey('github_list_${kind.value}'),
                            kind: kind,
                            projectPath: widget.projectPath,
                            sessionId: widget.sessionId,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Explains that "select all" left the drafts of the current tab out.
class _GitHubDraftNotice extends StatelessWidget {
  const _GitHubDraftNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        AppLocalizations.of(context).githubSelectAllSkipsDrafts,
        key: const ValueKey('github_draft_notice'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _GitHubAppBar extends StatelessWidget implements PreferredSizeWidget {
  final GitHubListState state;
  final int selectedCount;
  final WorkspacePaneChrome chrome;
  final TabController tabController;
  final bool embedded;
  final VoidCallback? onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onRefresh;

  const _GitHubAppBar({
    required this.state,
    required this.selectedCount,
    required this.chrome,
    required this.tabController,
    required this.embedded,
    required this.onClose,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onRefresh,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(chrome.toolbarHeight + kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repository = state.repository;
    final Widget? leading = embedded
        ? IconButton(
            key: const ValueKey('close_github_pane_button'),
            onPressed: onClose,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
          )
        : null;
    return AppBar(
      toolbarHeight: chrome.toolbarHeight,
      automaticallyImplyLeading: !embedded,
      leading: chrome.wrapLeading(leading),
      leadingWidth: chrome.resolveLeadingWidth(
        hasLeading: leading != null,
        baseWidth: kToolbarHeight,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedCount > 0)
            Text(
              l.githubSelectedCount(selectedCount),
              key: const ValueKey('github_selected_count'),
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(l.githubIssuesAndPrs, overflow: TextOverflow.ellipsis),
          if (repository != null && repository.isNotEmpty)
            Text(
              repository,
              key: const ValueKey('github_repository'),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: chrome.padActions([
        if (selectedCount > 0)
          IconButton(
            key: const ValueKey('github_clear_selection_button'),
            onPressed: onClearSelection,
            tooltip: l.githubClearSelection,
            icon: const Icon(Icons.deselect),
          ),
        IconButton(
          key: const ValueKey('github_select_all_button'),
          onPressed: onSelectAll,
          tooltip: l.githubSelectAll,
          icon: const Icon(Icons.select_all),
        ),
        IconButton(
          key: const ValueKey('github_refresh_button'),
          // Stays enabled while loading: a request stuck on a bad
          // connection can be replaced without waiting for its timeout.
          onPressed: onRefresh,
          tooltip: l.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ]),
      bottom: TabBar(
        controller: tabController,
        tabs: [
          for (final tabKind in _tabKinds)
            Tab(
              key: ValueKey(switch (tabKind) {
                GitHubItemKind.issue => 'github_tab_issues',
                GitHubItemKind.pr => 'github_tab_prs',
              }),
              text: _tabLabel(l, tabKind, state),
            ),
        ],
      ),
    );
  }

  String _tabLabel(
    AppLocalizations l,
    GitHubItemKind tabKind,
    GitHubListState state,
  ) {
    final name = switch (tabKind) {
      GitHubItemKind.issue => l.githubTabIssues,
      GitHubItemKind.pr => l.githubTabPrs,
    };
    final tab = state.tab(tabKind);
    return tab.loaded ? '$name (${tab.items.length})' : name;
  }
}

/// One tab's list with pull-to-refresh, empty, and error states.
class GitHubItemList extends StatelessWidget {
  final GitHubItemKind kind;
  final String projectPath;
  final String sessionId;

  const GitHubItemList({
    super.key,
    required this.kind,
    required this.projectPath,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GitHubListCubit>();
    final selection = context.watch<GitHubSelectionCubit>();
    return BlocBuilder<GitHubListCubit, GitHubListState>(
      builder: (context, state) {
        final tab = state.tab(kind);
        final failure = tab.failure;
        final items = state.visibleItems(kind);
        final Widget child;
        if (failure != null && !tab.loaded) {
          child = _GitHubScrollablePlaceholder(
            child: GitHubErrorView(
              failure: failure,
              onRetry: () => unawaited(cubit.refresh(kind)),
            ),
          );
        } else if (!tab.loaded) {
          child = const _GitHubScrollablePlaceholder(
            child: CircularProgressIndicator(),
          );
        } else if (items.isEmpty) {
          child = _GitHubScrollablePlaceholder(
            child: _GitHubEmptyState(
              kind: kind,
              filtered: tab.items.isNotEmpty,
            ),
          );
        } else {
          child = ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final selectable = GitHubSelectedItem.fromSummary(
                item,
                kind,
                repository: state.repository,
              );
              return GitHubItemTile(
                item: item,
                kind: kind,
                selected:
                    selectable != null &&
                    selection.isSelected(sessionId, selectable.url),
                onTap: () => unawaited(
                  showGitHubItemDetailSheet(
                    context,
                    projectPath: projectPath,
                    kind: kind,
                    summary: item,
                    selection: selectable == null
                        ? null
                        : (
                            cubit: selection,
                            sessionId: sessionId,
                            item: selectable,
                          ),
                  ),
                ),
                onToggleSelected: selectable == null
                    ? null
                    : () => selection.toggle(sessionId, selectable),
              );
            },
          );
        }
        return Column(
          children: [
            if (tab.loading && tab.loaded)
              const LinearProgressIndicator(minHeight: 2),
            if (failure != null && tab.loaded)
              _GitHubStaleBanner(
                failure: failure,
                onRetry: () => unawaited(cubit.refresh(kind)),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => cubit.refresh(kind),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Keeps short content scrollable so pull-to-refresh still works.
class _GitHubScrollablePlaceholder extends StatelessWidget {
  final Widget child;

  const _GitHubScrollablePlaceholder({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _GitHubEmptyState extends StatelessWidget {
  final GitHubItemKind kind;
  final bool filtered;

  const _GitHubEmptyState({required this.kind, required this.filtered});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        filtered
            ? l.githubEmptyFiltered
            : switch (kind) {
                GitHubItemKind.pr => l.githubEmptyPrs,
                GitHubItemKind.issue => l.githubEmptyIssues,
              },
        key: const ValueKey('github_empty_message'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A refresh failed while an earlier list is still on screen.
class _GitHubStaleBanner extends StatelessWidget {
  final GitHubFailure failure;
  final VoidCallback onRetry;

  const _GitHubStaleBanner({required this.failure, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                switch (failure.kind) {
                  GitHubFailureKind.ghMissing => l.githubErrorGhMissingTitle,
                  GitHubFailureKind.ghUnauthenticated =>
                    l.githubErrorUnauthenticatedTitle,
                  GitHubFailureKind.notGithub => l.githubErrorNotGithubTitle,
                  GitHubFailureKind.unsupported =>
                    l.githubErrorUnsupportedTitle,
                  GitHubFailureKind.timeout ||
                  GitHubFailureKind.disconnected ||
                  GitHubFailureKind.failed => l.githubErrorFailedTitle,
                },
                key: const ValueKey('github_stale_banner'),
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: Text(l.retry)),
          ],
        ),
      ),
    );
  }
}
