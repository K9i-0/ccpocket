import '../models/messages.dart';

/// Last activity for the exact project choice used by each session.
/// Group membership alone is never evidence that a group or sibling was used.
Map<String, DateTime> projectUsage(List<RecentSession> sessions) {
  final usage = <String, DateTime>{};
  for (final session in sessions) {
    if (session.isSidechain) continue;
    final projectId = session.workspace?.projectId;
    final isGroup = session.workspaceKind == 'project';
    if (isGroup && (projectId == null || projectId.isEmpty)) continue;
    if (!isGroup && session.projectPath.isEmpty) continue;
    final key = isGroup
        ? 'project:$projectId'
        : 'folder:${session.projectPath}';
    final usedAt =
        DateTime.tryParse(session.modified) ??
        DateTime.tryParse(session.created);
    if (usedAt == null) continue;
    final previous = usage[key];
    if (previous == null || usedAt.isAfter(previous)) usage[key] = usedAt;
  }
  return usage;
}
