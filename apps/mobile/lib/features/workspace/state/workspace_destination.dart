import 'package:flutter/foundation.dart';

import '../../../models/messages.dart';

sealed class WorkspaceToolPaneData {
  const WorkspaceToolPaneData();

  String get id;
  String get title;
  String? get sessionId;
}

class GitToolPaneData extends WorkspaceToolPaneData {
  final String projectPath;
  @override
  final String? sessionId;
  final String? worktreePath;

  const GitToolPaneData({
    required this.projectPath,
    this.sessionId,
    this.worktreePath,
  });

  @override
  String get id => 'git:$projectPath:${sessionId ?? ''}:${worktreePath ?? ''}';

  @override
  String get title => 'Git';
}

class ExploreToolPaneData extends WorkspaceToolPaneData {
  @override
  final String sessionId;
  final String projectPath;
  final List<String> initialFiles;
  final String initialPath;
  final List<String> recentPeekedFiles;

  const ExploreToolPaneData({
    required this.sessionId,
    required this.projectPath,
    required this.initialFiles,
    required this.initialPath,
    required this.recentPeekedFiles,
  });

  @override
  String get id => 'explore:$sessionId:$projectPath';

  @override
  String get title => 'Explorer';
}

class GalleryToolPaneData extends WorkspaceToolPaneData {
  @override
  final String sessionId;

  const GalleryToolPaneData({required this.sessionId});

  @override
  String get id => 'gallery:$sessionId';

  @override
  String get title => 'Gallery';
}

class WorkspaceSessionSelection {
  final String sessionId;
  final String? projectPath;
  final SessionWorkspaceInfo? workspace;
  final String? gitBranch;
  final String? worktreePath;
  final bool isPending;
  final Provider? provider;
  final String? permissionMode;
  final String? sandboxMode;
  final String? approvalPolicy;
  final String? approvalsReviewer;
  final ValueNotifier<SystemMessage?>? pendingSessionCreated;

  const WorkspaceSessionSelection({
    required this.sessionId,
    this.projectPath,
    this.workspace,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.provider,
    this.permissionMode,
    this.sandboxMode,
    this.approvalPolicy,
    this.approvalsReviewer,
    this.pendingSessionCreated,
  });
}
