import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../l10n/app_localizations.dart';

/// Narrow workspace navigation. Session actions remain available by long press
/// or secondary click; approvals are handled in the selected chat.
class CompactSessionList extends StatelessWidget {
  const CompactSessionList({
    super.key,
    required this.onBrowse,
    required this.sessions,
    required this.recentSessions,
    required this.selectedSessionId,
    required this.onRunningTap,
    required this.onRecentTap,
    required this.onRunningActions,
    required this.onRecentActions,
  });

  final VoidCallback onBrowse;
  final List<SessionInfo> sessions;
  final List<RecentSession> recentSessions;
  final String? selectedSessionId;
  final ValueChanged<SessionInfo> onRunningTap;
  final ValueChanged<RecentSession> onRecentTap;
  final void Function(SessionInfo, Offset?) onRunningActions;
  final void Function(RecentSession, Offset?) onRecentActions;

  @override
  Widget build(BuildContext context) {
    final recent = recentSessions
        .where((item) => !sessions.any((active) => active.id == item.sessionId))
        .toList();
    return ListView.builder(
      key: const ValueKey('compact_session_list'),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 88),
      itemCount: sessions.length + recent.length + 1,
      itemBuilder: (context, index) {
        if (index == sessions.length + recent.length) {
          return IconButton(
            key: const ValueKey('browse_sessions_button'),
            tooltip: AppLocalizations.of(context).search,
            onPressed: onBrowse,
            icon: const Icon(Icons.search),
          );
        }
        if (index < sessions.length) {
          final session = sessions[index];
          return CompactSessionTile(
            key: ValueKey('compact_session_${session.id}'),
            title: session.name ?? session.projectName,
            subtitle: '${session.projectName} · ${session.status}',
            selected: selectedSessionId == session.id,
            onTap: () => onRunningTap(session),
            onActions: (position) => onRunningActions(session, position),
          );
        }
        final session = recent[index - sessions.length];
        return CompactSessionTile(
          key: ValueKey('compact_session_${session.sessionId}'),
          title: session.name ?? session.summary ?? session.firstPrompt,
          subtitle: session.projectName,
          selected: selectedSessionId == session.sessionId,
          onTap: () => onRecentTap(session),
          onActions: (position) => onRecentActions(session, position),
        );
      },
    );
  }
}

class CompactSessionTile extends StatelessWidget {
  const CompactSessionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.onActions,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset?> onActions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Tooltip(
        message: '$title\n$subtitle',
        child: Material(
          color: selected ? colors.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            onLongPress: () => onActions(null),
            onSecondaryTapUp: (details) => onActions(details.globalPosition),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
