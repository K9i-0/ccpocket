import '../../models/messages.dart';

/// Chat rows after context compaction: only the latest compaction boundary
/// and what follows it. Earlier messages stay in the session state (rewind
/// and edit use them) and are reachable from the boundary card.
///
/// Without a boundary, [olderHistoryAvailable] adds an older-history card
/// for messages dropped from the live window. [compacting] appends a
/// progress row. Applied before the performance-mode projection.
List<ChatEntry> compactionVisibleEntries(
  List<ChatEntry> entries, {
  required bool olderHistoryAvailable,
  required bool compacting,
}) {
  final boundary = entries.lastIndexWhere(
    (entry) =>
        entry is ServerChatEntry && entry.message is ContextCompactionMessage,
  );
  var visible = entries;
  if (boundary > 0) {
    visible = entries.sublist(boundary);
  } else if (boundary < 0 && olderHistoryAvailable && entries.isNotEmpty) {
    visible = [
      ServerChatEntry(
        const OlderHistoryMarkerMessage(),
        timestamp: entries.first.timestamp,
      ),
      ...entries,
    ];
  }
  if (!compacting) return visible;
  return [
    ...visible,
    ServerChatEntry(
      const ContextCompactingMessage(),
      timestamp: visible.isEmpty ? null : visible.last.timestamp,
    ),
  ];
}
