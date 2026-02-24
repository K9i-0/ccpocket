import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../models/messages.dart';
import '../../../services/draft_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/session_card.dart';
import '../state/session_list_cubit.dart';
import '../state/session_list_state.dart';
import 'section_header.dart';
import 'session_filter_bar.dart';
import 'session_list_empty_state.dart';
import 'session_reconnect_banner.dart';

class HomeContent extends StatefulWidget {
  final BridgeConnectionState connectionState;
  final List<SessionInfo> sessions;
  final List<RecentSession> recentSessions;
  final Set<String> accumulatedProjectPaths;
  final String searchQuery;
  final bool isLoadingMore;
  final bool isInitialLoading;
  final bool hasMoreSessions;
  final String? currentProjectFilter;
  final VoidCallback onNewSession;
  final void Function(
    String sessionId, {
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
    String? provider,
    String? permissionMode,
    String? sandboxMode,
  })
  onTapRunning;
  final ValueChanged<String> onStopSession;
  final void Function(
    String sessionId,
    String toolUseId, {
    Map<String, dynamic>? updatedInput,
    bool clearContext,
  })?
  onApprovePermission;
  final void Function(String sessionId, String toolUseId)? onApproveAlways;
  final void Function(String sessionId, String toolUseId, {String? message})?
  onRejectPermission;
  final void Function(String sessionId, String toolUseId, String result)?
  onAnswerQuestion;
  final ValueChanged<RecentSession> onResumeSession;
  final ValueChanged<RecentSession> onLongPressRecentSession;
  final ValueChanged<SessionInfo> onLongPressRunningSession;
  final ValueChanged<String?> onSelectProject;
  final VoidCallback onLoadMore;
  final ProviderFilter providerFilter;
  final bool namedOnly;
  final VoidCallback onToggleProvider;
  final VoidCallback onToggleNamed;

  const HomeContent({
    super.key,
    required this.connectionState,
    required this.sessions,
    required this.recentSessions,
    required this.accumulatedProjectPaths,
    required this.searchQuery,
    required this.isLoadingMore,
    required this.isInitialLoading,
    required this.hasMoreSessions,
    required this.currentProjectFilter,
    required this.onNewSession,
    required this.onTapRunning,
    required this.onStopSession,
    this.onApprovePermission,
    this.onApproveAlways,
    this.onRejectPermission,
    this.onAnswerQuestion,
    required this.onResumeSession,
    required this.onLongPressRecentSession,
    required this.onLongPressRunningSession,
    required this.onSelectProject,
    required this.onLoadMore,
    required this.providerFilter,
    required this.namedOnly,
    required this.onToggleProvider,
    required this.onToggleNamed,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  SessionDisplayMode _displayMode = SessionDisplayMode.first;

  @override
  void initState() {
    super.initState();
    _loadDisplayMode();
  }

  Future<void> _loadDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('session_list_display_mode');
    if (modeStr != null && mounted) {
      setState(() {
        _displayMode = SessionDisplayMode.values.firstWhere(
          (m) => m.name == modeStr,
          orElse: () => SessionDisplayMode.first,
        );
      });
    }
  }

  void _toggleDisplayMode() async {
    final next = switch (_displayMode) {
      SessionDisplayMode.first => SessionDisplayMode.last,
      SessionDisplayMode.last => SessionDisplayMode.summary,
      SessionDisplayMode.summary => SessionDisplayMode.first,
    };
    setState(() => _displayMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_list_display_mode', next.name);
  }

  @override
  void didUpdateWidget(covariant HomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部から searchQuery がクリアされたら検索UIも閉じる
    if (widget.searchQuery.isEmpty && oldWidget.searchQuery.isNotEmpty) {
      setState(() => _isSearching = false);
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        context.read<SessionListCubit>().setSearchQuery('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final hasRunningSessions = widget.sessions.isNotEmpty;
    final hasRecentSessions = widget.recentSessions.isNotEmpty;
    final isReconnecting =
        widget.connectionState == BridgeConnectionState.reconnecting;

    // Compute derived state
    // Exclude running sessions from recent list to avoid duplicates
    final runningSessionIds = widget.sessions
        .expand(
          (s) => [s.id, if (s.claudeSessionId != null) s.claudeSessionId!],
        )
        .toSet();

    // Fallback for Codex sessions which use a short proxy ID instead of UUID
    bool isDuplicate(RecentSession rs) {
      if (runningSessionIds.contains(rs.sessionId)) return true;
      for (final s in widget.sessions) {
        if (s.provider == rs.provider &&
            s.projectPath == rs.projectPath &&
            s.createdAt == rs.created) {
          return true;
        }
      }
      return false;
    }

    // All filtering (project, provider, namedOnly, searchQuery) is applied
    // server-side. Only deduplicate running sessions here.
    final filteredSessions = widget.recentSessions
        .where((s) => !isDuplicate(s))
        .toList();

    final hasActiveFilter =
        widget.currentProjectFilter != null ||
        widget.providerFilter != ProviderFilter.all ||
        widget.namedOnly ||
        widget.searchQuery.isNotEmpty;

    if (!hasRunningSessions && !hasRecentSessions && !hasActiveFilter) {
      // Show skeleton while initial data is loading
      if (widget.isInitialLoading) {
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            if (isReconnecting) const SessionReconnectBanner(),
            SectionHeader(
              icon: Icons.history,
              label: 'Recent Sessions',
              color: appColors.subtleText,
            ),
            const SizedBox(height: 8),
            const _SessionListSkeleton(),
          ],
        );
      }

      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (isReconnecting) const SessionReconnectBanner(),
          const SizedBox(height: 80),
          SessionListEmptyState(onNewSession: widget.onNewSession),
        ],
      );
    }

    return ListView(
      key: const ValueKey('session_list'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        if (isReconnecting) const SessionReconnectBanner(),
        if (hasRunningSessions) ...[
          SectionHeader(
            icon: Icons.play_circle_filled,
            label: 'Running',
            color: appColors.statusRunning,
          ),
          const SizedBox(height: 4),
          for (final session in widget.sessions)
            Dismissible(
              key: ValueKey('running_session_${session.id}'),
              direction: DismissDirection.endToStart,
              background: const SizedBox.shrink(),
              secondaryBackground: _StopSessionSwipeBackground(
                color: Theme.of(context).colorScheme.error,
              ),
              confirmDismiss: (_) async {
                widget.onStopSession(session.id);
                // Keep the card visible until the bridge status actually updates.
                return false;
              },
              child: RunningSessionCard(
                session: session,
                onLongPress: () => widget.onLongPressRunningSession(session),
                onTap: () => widget.onTapRunning(
                  session.id,
                  projectPath: session.projectPath,
                  gitBranch: session.worktreePath != null
                      ? session.worktreeBranch
                      : session.gitBranch,
                  worktreePath: session.worktreePath,
                  provider: session.provider,
                  permissionMode: session.permissionMode,
                  sandboxMode: session.codexSandboxMode,
                ),
                onStop: () => widget.onStopSession(session.id),
                onApprove:
                    (
                      toolUseId, {
                      Map<String, dynamic>? updatedInput,
                      bool clearContext = false,
                    }) => widget.onApprovePermission?.call(
                      session.id,
                      toolUseId,
                      updatedInput: updatedInput,
                      clearContext: clearContext,
                    ),
                onApproveAlways: (toolUseId) =>
                    widget.onApproveAlways?.call(session.id, toolUseId),
                onReject: (toolUseId, {String? message}) => widget
                    .onRejectPermission
                    ?.call(session.id, toolUseId, message: message),
                onAnswer: (toolUseId, result) => widget.onAnswerQuestion?.call(
                  session.id,
                  toolUseId,
                  result,
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        // Show skeleton placeholder while waiting for recent sessions
        if (widget.isInitialLoading && !hasRecentSessions) ...[
          SectionHeader(
            icon: Icons.history,
            label: 'Recent Sessions',
            color: appColors.subtleText,
          ),
          const SizedBox(height: 8),
          const _SessionListSkeleton(),
        ] else if (hasRecentSessions || hasActiveFilter) ...[
          SectionHeader(
            icon: Icons.history,
            label: 'Recent Sessions',
            color: appColors.subtleText,
            trailing: IconButton(
              key: const ValueKey('search_button'),
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                size: 18,
                color: appColors.subtleText,
              ),
              onPressed: _toggleSearch,
              tooltip: 'Search',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (_isSearching) ...[
            const SizedBox(height: 4),
            TextField(
              key: const ValueKey('search_field'),
              controller: _searchController,
              autofocus: true,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: 'Search sessions...',
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: appColors.subtleText,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: appColors.subtleText.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: appColors.subtleText.withValues(alpha: 0.3),
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (v) =>
                  context.read<SessionListCubit>().setSearchQuery(v),
            ),
          ],
          const SizedBox(height: 8),
          SessionFilterBar(
            displayMode: _displayMode,
            onToggleDisplayMode: _toggleDisplayMode,
            providerFilter: widget.providerFilter,
            onToggleProviderFilter: widget.onToggleProvider,
            projects: widget.accumulatedProjectPaths.map((path) {
              return (path: path, name: path.split('/').last);
            }).toList(),
            currentProjectFilter: widget.currentProjectFilter,
            onProjectFilterChanged: widget.onSelectProject,
            namedOnly: widget.namedOnly,
            onToggleNamed: widget.onToggleNamed,
          ),
          const SizedBox(height: 8),
          for (final session in filteredSessions)
            RecentSessionCard(
              session: session,
              displayMode: _displayMode,
              draftText: context.read<DraftService>().getDraft(
                session.sessionId,
              ),
              onTap: () => widget.onResumeSession(session),
              onLongPress: () => widget.onLongPressRecentSession(session),
            ),
          if (widget.hasMoreSessions) ...[
            const SizedBox(height: 8),
            Center(
              child: widget.isLoadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton.icon(
                      key: const ValueKey('load_more_button'),
                      onPressed: widget.onLoadMore,
                      icon: const Icon(Icons.expand_more, size: 18),
                      label: const Text('Load More'),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _StopSessionSwipeBackground extends StatelessWidget {
  final Color color;

  const _StopSessionSwipeBackground({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Icon(Icons.stop_circle_outlined, color: color),
    );
  }
}

/// Skeleton placeholder that mimics a list of [RecentSessionCard] widgets.
///
/// Uses [Skeletonizer] to render dummy cards with a shimmer animation,
/// providing visual feedback while the initial session list is loading.
class _SessionListSkeleton extends StatelessWidget {
  const _SessionListSkeleton();

  static const _dummySessions = [
    RecentSession(
      sessionId: 'skeleton-1',
      firstPrompt: 'Implement the new feature for user authentication flow',
      messageCount: 12,
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'feat/auth',
      projectPath: '/projects/my-app',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-2',
      firstPrompt: 'Fix the CI pipeline build failure on main branch',
      messageCount: 8,
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'fix/ci',
      projectPath: '/projects/backend',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-3',
      firstPrompt: 'Add dark mode support to the settings page',
      messageCount: 5,
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'main',
      projectPath: '/projects/mobile',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-4',
      firstPrompt: 'Refactor database queries for better performance',
      messageCount: 15,
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'perf/db',
      projectPath: '/projects/api',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-5',
      firstPrompt: 'Update documentation for the REST API endpoints',
      messageCount: 3,
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'docs',
      projectPath: '/projects/docs',
      isSidechain: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Column(
        children: [
          for (final session in _dummySessions)
            RecentSessionCard(session: session, onTap: () {}),
        ],
      ),
    );
  }
}
