import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../models/messages.dart';
import '../../../services/draft_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/session_card.dart';
import '../session_list_screen.dart';
import '../state/session_list_cubit.dart';
import 'project_filter_chips.dart';
import 'section_header.dart';
import 'session_list_empty_state.dart';
import 'session_reconnect_banner.dart';

class HomeContent extends StatefulWidget {
  final BridgeConnectionState connectionState;
  final List<SessionInfo> sessions;
  final List<RecentSession> recentSessions;
  final Set<String> accumulatedProjectPaths;
  final String? selectedProject;
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
  })
  onTapRunning;
  final ValueChanged<String> onStopSession;
  final ValueChanged<RecentSession> onResumeSession;
  final ValueChanged<RecentSession> onLongPressRecentSession;
  final ValueChanged<String?> onSelectProject;
  final VoidCallback onLoadMore;

  const HomeContent({
    super.key,
    required this.connectionState,
    required this.sessions,
    required this.recentSessions,
    required this.accumulatedProjectPaths,
    required this.selectedProject,
    required this.searchQuery,
    required this.isLoadingMore,
    required this.isInitialLoading,
    required this.hasMoreSessions,
    required this.currentProjectFilter,
    required this.onNewSession,
    required this.onTapRunning,
    required this.onStopSession,
    required this.onResumeSession,
    required this.onLongPressRecentSession,
    required this.onSelectProject,
    required this.onLoadMore,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  SessionDisplayMode _displayMode = SessionDisplayMode.first;

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
        .map((s) => s.claudeSessionId ?? s.id)
        .toSet();
    var filteredSessions = widget.currentProjectFilter != null
        ? widget.recentSessions
        : filterByProject(widget.recentSessions, widget.selectedProject);
    filteredSessions = filterByQuery(filteredSessions, widget.searchQuery);
    filteredSessions = filteredSessions
        .where((s) => !runningSessionIds.contains(s.sessionId))
        .toList();

    final hasActiveFilter = widget.currentProjectFilter != null;

    if (!hasRunningSessions && !hasRecentSessions && !hasActiveFilter) {
      // Show skeleton while initial data is loading
      if (widget.isInitialLoading) {
        return ListView(
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
            RunningSessionCard(
              session: session,
              onTap: () => widget.onTapRunning(
                session.id,
                projectPath: session.projectPath,
                gitBranch: session.worktreePath != null
                    ? session.worktreeBranch
                    : session.gitBranch,
                worktreePath: session.worktreePath,
                provider: session.provider,
              ),
              onStop: () => widget.onStopSession(session.id),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SessionDisplayModeToggle(
                  key: const ValueKey('session_display_mode_toggle'),
                  mode: _displayMode,
                  onChanged: (mode) => setState(() => _displayMode = mode),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: const ValueKey('search_button'),
                  icon: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    size: 18,
                    color: appColors.subtleText,
                  ),
                  onPressed: _toggleSearch,
                  tooltip: 'Search',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          if (_isSearching) ...[
            const SizedBox(height: 4),
            TextField(
              key: const ValueKey('search_field'),
              controller: _searchController,
              autofocus: true,
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
          if (widget.accumulatedProjectPaths.length > 1) ...[
            const SizedBox(height: 8),
            ProjectFilterChips(
              accumulatedProjectPaths: widget.accumulatedProjectPaths,
              recentSessions: widget.recentSessions,
              currentFilterPath: widget.currentProjectFilter,
              onSelected: widget.onSelectProject,
            ),
          ],
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
              hideProjectBadge: widget.selectedProject != null,
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

class _SessionDisplayModeToggle extends StatelessWidget {
  final SessionDisplayMode mode;
  final ValueChanged<SessionDisplayMode> onChanged;

  const _SessionDisplayModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SegmentedButton<SessionDisplayMode>(
      segments: const [
        ButtonSegment(value: SessionDisplayMode.first, label: Text('First')),
        ButtonSegment(value: SessionDisplayMode.last, label: Text('Last')),
        ButtonSegment(value: SessionDisplayMode.summary, label: Text('Sum.')),
      ],
      selected: {mode},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedBackgroundColor: colorScheme.primaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        textStyle: const TextStyle(fontSize: 10),
      ),
    );
  }
}
