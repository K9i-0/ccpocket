enum OfflinePendingActionKind { start, resume }

class OfflinePendingAction {
  const OfflinePendingAction({
    required this.id,
    required this.kind,
    required this.projectPath,
    required this.provider,
    required this.createdAt,
    this.canCancel = true,
    this.sessionId,
  });

  final String id;
  final OfflinePendingActionKind kind;
  final String projectPath;
  final String provider;
  final DateTime createdAt;
  final bool canCancel;
  final String? sessionId;

  String get projectName {
    final normalized = projectPath.trim();
    if (normalized.isEmpty) return 'Unknown project';
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? normalized : parts.last;
  }

  String get title => switch (kind) {
    OfflinePendingActionKind.start => 'New session pending',
    OfflinePendingActionKind.resume => 'Resume pending',
  };
}
