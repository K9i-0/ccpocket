enum OfflinePendingActionKind { start, resume }

enum OfflinePendingActionState { queuedForReconnect, processing }

class OfflinePendingAction {
  const OfflinePendingAction({
    required this.id,
    required this.kind,
    required this.projectPath,
    required this.provider,
    required this.createdAt,
    this.state = OfflinePendingActionState.queuedForReconnect,
    this.canCancel = true,
    this.sessionId,
  });

  final String id;
  final OfflinePendingActionKind kind;
  final String projectPath;
  final String provider;
  final DateTime createdAt;
  final OfflinePendingActionState state;
  final bool canCancel;
  final String? sessionId;

  String get projectName {
    final normalized = projectPath.trim();
    if (normalized.isEmpty) return 'Unknown project';
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? normalized : parts.last;
  }
}
