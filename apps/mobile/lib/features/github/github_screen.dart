import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../services/bridge_service.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../session_list/workspace_shell_screen.dart';
import 'state/github_list_cubit.dart';
import 'state/github_list_state.dart';
import 'state/github_view_cache_service.dart';
import 'widgets/github_error_view.dart';
import 'widgets/github_filter_bar.dart';
import 'widgets/github_item_detail_sheet.dart';
import 'widgets/github_item_tile.dart';
import 'widgets/github_triage_sheet.dart';

export 'widgets/github_triage_sheet.dart' show GitHubTriageTarget;

/// Open issues and pull requests of a project, with multi-select to hand
/// them to the triage skill.
///
/// The screen only reads from GitHub. It produces a `/triage ...` prompt and
/// leaves sending to its opener: [onSubmitTriage] when embedded in a tool
/// pane, otherwise the prompt is the route's pop result.
@RoutePage()
class GitHubScreen extends StatefulWidget {
  final String projectPath;
  final GitHubTriageTarget triageTarget;
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<String>? onSubmitTriage;

  const GitHubScreen({
    super.key,
    required this.projectPath,
    this.triageTarget = GitHubTriageTarget.newSession,
    this.embedded = false,
    this.onClose,
    this.onSubmitTriage,
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
  bool _ownsCubit = false;

  GitHubItemKind get _kind => _tabKinds[_tabController.index];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabKinds.length, vsync: this)
      ..addListener(_onTabChanged);
    final bridge = context.read<BridgeService>();
    final cache = context.read<GitHubViewCacheService?>();
    if (cache == null || !cache.serves(bridge)) {
      _cubit = GitHubListCubit(bridge: bridge, projectPath: widget.projectPath);
      _ownsCubit = true;
      _cubit.ensureLoaded(_kind);
    } else {
      final lookup = cache.getOrCreate(widget.projectPath);
      _cubit = lookup.cubit;
      if (lookup.created) {
        _cubit.ensureLoaded(_kind);
      } else {
        // Show the cached list at once and bring it up to date behind it.
        _refreshLoadedTabs();
      }
    }
  }

  void _refreshLoadedTabs() {
    for (final kind in _tabKinds) {
      final tab = _cubit.state.tab(kind);
      if (kind == _kind || tab.loaded) {
        if (!tab.loading) unawaited(_cubit.refresh(kind));
      }
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

  Future<void> _requestTriage() async {
    final numbers = _cubit.state.selectedNumbers;
    if (numbers.isEmpty) return;
    final prompt = await showGitHubTriageSheet(
      context,
      numbers: numbers,
      target: widget.triageTarget,
    );
    if (prompt == null || prompt.isEmpty || !mounted) return;
    _cubit.clearSelection();
    final onSubmit = widget.onSubmitTriage;
    if (onSubmit != null) {
      onSubmit(prompt);
    } else {
      Navigator.of(context).pop(prompt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GitHubListCubit>.value(
      value: _cubit,
      child: BlocBuilder<GitHubListCubit, GitHubListState>(
        builder: (context, state) {
          final selecting = state.selectionMode;
          final shell = WorkspaceShellScreen.maybeOf(context);
          final chrome = resolveWorkspacePaneChrome(
            platform: Theme.of(context).platform,
            isAdaptiveWorkspace: shell != null && !shell.isSinglePane,
            isLeftPaneVisible: shell?.isLeftPaneVisible ?? false,
            slot: WorkspacePaneSlot.right,
          );
          return PopScope(
            canPop: !selecting,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && selecting) _cubit.clearSelection();
            },
            child: Scaffold(
              appBar: chrome.wrapAppBar(
                _GitHubAppBar(
                  state: state,
                  kind: _kind,
                  chrome: chrome,
                  tabController: _tabController,
                  embedded: widget.embedded,
                  onClose: widget.onClose,
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
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: selecting
                  ? GitHubSelectionBar(
                      count: state.selected.length,
                      onRequestTriage: _requestTriage,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _GitHubAppBar extends StatelessWidget implements PreferredSizeWidget {
  final GitHubListState state;
  final GitHubItemKind kind;
  final WorkspacePaneChrome chrome;
  final TabController tabController;
  final bool embedded;
  final VoidCallback? onClose;

  const _GitHubAppBar({
    required this.state,
    required this.kind,
    required this.chrome,
    required this.tabController,
    required this.embedded,
    required this.onClose,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(chrome.toolbarHeight + kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<GitHubListCubit>();
    final selecting = state.selectionMode;
    final repository = state.repository;
    final Widget? leading = selecting
        ? IconButton(
            key: const ValueKey('github_cancel_selection_button'),
            onPressed: cubit.clearSelection,
            tooltip: l.githubCancelSelection,
            icon: const Icon(Icons.close),
          )
        : embedded
        ? IconButton(
            key: const ValueKey('close_github_pane_button'),
            onPressed: onClose,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
          )
        : null;
    return AppBar(
      toolbarHeight: chrome.toolbarHeight,
      automaticallyImplyLeading: !embedded && !selecting,
      leading: chrome.wrapLeading(leading),
      leadingWidth: chrome.resolveLeadingWidth(
        hasLeading: leading != null,
        baseWidth: kToolbarHeight,
      ),
      title: selecting
          ? Text(
              l.githubSelectedCount(state.selected.length),
              key: const ValueKey('github_selected_count'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
        if (selecting)
          TextButton(
            key: const ValueKey('github_select_all_button'),
            onPressed: () => cubit.selectAllVisible(kind),
            child: Text(l.githubSelectAll),
          )
        else
          IconButton(
            key: const ValueKey('github_refresh_button'),
            onPressed: state.tab(kind).loading
                ? null
                : () => unawaited(cubit.refresh(kind)),
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

  const GitHubItemList({
    super.key,
    required this.kind,
    required this.projectPath,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GitHubListCubit>();
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
          child = const Center(child: CircularProgressIndicator());
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
              return GitHubItemTile(
                item: item,
                kind: kind,
                selectionMode: state.selectionMode,
                selected: state.selected.contains(item.number),
                onTap: () => state.selectionMode
                    ? cubit.toggleSelected(item.number)
                    : unawaited(
                        showGitHubItemDetailSheet(
                          context,
                          projectPath: projectPath,
                          kind: kind,
                          summary: item,
                        ),
                      ),
                onLongPress: () => state.selectionMode
                    ? cubit.toggleSelected(item.number)
                    : cubit.startSelection(item.number),
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

/// Bottom bar shown in multi-select mode.
class GitHubSelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onRequestTriage;

  const GitHubSelectionBar({
    super.key,
    required this.count,
    required this.onRequestTriage,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.githubSelectAllSkipsDrafts,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('github_request_triage_button'),
                  onPressed: count == 0 ? null : onRequestTriage,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: Text('${l.githubRequestTriage} ($count)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
