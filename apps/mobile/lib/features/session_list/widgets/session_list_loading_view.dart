import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../widgets/session_card.dart';
import 'section_header.dart';

/// Loading state shared by Bridge connection and initial session list fetches.
class SessionListLoadingView extends StatelessWidget {
  const SessionListLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final l = AppLocalizations.of(context);

    return ListView(
      key: const ValueKey('session_list_loading'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        SectionHeader(
          icon: Icons.history,
          label: l.recentSessions,
          color: color,
        ),
        const SizedBox(height: 8),
        const SessionListLoadingStatus(),
        const SizedBox(height: 12),
        const SessionListSkeleton(),
      ],
    );
  }
}

/// Visible and screen-reader friendly description of the loading state.
class SessionListLoadingStatus extends StatelessWidget {
  const SessionListLoadingStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Semantics(
      liveRegion: true,
      label: l.loadingSessions,
      excludeSemantics: true,
      child: Row(
        key: const ValueKey('session_list_loading_status'),
        children: [
          Icon(Icons.sync, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.loadingSessions,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder that mimics a list of [RecentSessionCard] widgets.
class SessionListSkeleton extends StatelessWidget {
  const SessionListSkeleton({super.key});

  static const _dummySessions = [
    RecentSession(
      sessionId: 'skeleton-1',
      firstPrompt: 'Implement the new feature for user authentication flow',
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'feat/auth',
      projectPath: '/projects/my-app',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-2',
      firstPrompt: 'Fix the CI pipeline build failure on main branch',
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'fix/ci',
      projectPath: '/projects/backend',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-3',
      firstPrompt: 'Add dark mode support to the settings page',
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'main',
      projectPath: '/projects/mobile',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-4',
      firstPrompt: 'Refactor database queries for better performance',
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'perf/db',
      projectPath: '/projects/api',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-5',
      firstPrompt: 'Update documentation for the REST API endpoints',
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'docs',
      projectPath: '/projects/docs',
      isSidechain: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Skeletonizer(
        child: Column(
          children: [
            for (final session in _dummySessions)
              RecentSessionCard(session: session, onTap: () {}),
          ],
        ),
      ),
    );
  }
}
