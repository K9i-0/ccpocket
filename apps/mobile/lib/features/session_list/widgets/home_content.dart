import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/session_card.dart';
import '../session_list_screen.dart';
import '../state/session_list_state.dart';
import 'date_filter_chips.dart';
import 'project_filter_chips.dart';
import 'section_header.dart';
import 'session_list_empty_state.dart';
import 'session_reconnect_banner.dart';

class HomeContent extends StatelessWidget {
  final BridgeConnectionState connectionState;
  final List<SessionInfo> sessions;
  final List<RecentSession> recentSessions;
  final Set<String> accumulatedProjectPaths;
  final String? selectedProject;
  final DateFilter dateFilter;
  final String searchQuery;
  final bool isLoadingMore;
  final bool hasMoreSessions;
  final String? currentProjectFilter;
  final VoidCallback onNewSession;
  final void Function(String sessionId, {String? projectPath}) onTapRunning;
  final ValueChanged<String> onStopSession;
  final ValueChanged<RecentSession> onResumeSession;
  final ValueChanged<String?> onSelectProject;
  final ValueChanged<DateFilter> onSelectDateFilter;
  final VoidCallback onLoadMore;

  const HomeContent({
    super.key,
    required this.connectionState,
    required this.sessions,
    required this.recentSessions,
    required this.accumulatedProjectPaths,
    required this.selectedProject,
    required this.dateFilter,
    required this.searchQuery,
    required this.isLoadingMore,
    required this.hasMoreSessions,
    required this.currentProjectFilter,
    required this.onNewSession,
    required this.onTapRunning,
    required this.onStopSession,
    required this.onResumeSession,
    required this.onSelectProject,
    required this.onSelectDateFilter,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final hasRunningSessions = sessions.isNotEmpty;
    final hasRecentSessions = recentSessions.isNotEmpty;
    final isReconnecting =
        connectionState == BridgeConnectionState.reconnecting;

    // Compute derived state
    var filteredSessions = currentProjectFilter != null
        ? recentSessions
        : filterByProject(recentSessions, selectedProject);
    filteredSessions = filterByDate(filteredSessions, dateFilter);
    filteredSessions = filterByQuery(filteredSessions, searchQuery);

    if (!hasRunningSessions && !hasRecentSessions) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (isReconnecting) const SessionReconnectBanner(),
          const SizedBox(height: 80),
          SessionListEmptyState(onNewSession: onNewSession),
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
          for (final session in sessions)
            RunningSessionCard(
              session: session,
              onTap: () =>
                  onTapRunning(session.id, projectPath: session.projectPath),
              onStop: () => onStopSession(session.id),
            ),
          const SizedBox(height: 16),
        ],
        if (hasRecentSessions) ...[
          SectionHeader(
            icon: Icons.history,
            label: 'Recent Sessions',
            color: appColors.subtleText,
          ),
          if (accumulatedProjectPaths.length > 1) ...[
            const SizedBox(height: 8),
            ProjectFilterChips(
              accumulatedProjectPaths: accumulatedProjectPaths,
              recentSessions: recentSessions,
              currentFilterPath: currentProjectFilter,
              onSelected: onSelectProject,
            ),
          ],
          const SizedBox(height: 4),
          DateFilterChips(selected: dateFilter, onSelected: onSelectDateFilter),
          const SizedBox(height: 8),
          for (final session in filteredSessions)
            RecentSessionCard(
              session: session,
              onTap: () => onResumeSession(session),
              hideProjectBadge: selectedProject != null,
            ),
          if (hasMoreSessions) ...[
            const SizedBox(height: 8),
            Center(
              child: isLoadingMore
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
                      onPressed: onLoadMore,
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
