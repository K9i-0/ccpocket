import '../../models/messages.dart';

enum NewSessionProjectChoiceKind { workspaceProject, workspaceFolder, recent }

class NewSessionProjectChoice {
  const NewSessionProjectChoice({
    required this.kind,
    required this.id,
    required this.name,
    required this.path,
    this.workspaceProject,
  });

  final NewSessionProjectChoiceKind kind;
  final String id;
  final String name;
  final String path;
  final WorkspaceProject? workspaceProject;

  String get tileKey => switch (kind) {
    NewSessionProjectChoiceKind.workspaceProject =>
      'workspace_project_${id}_tile',
    NewSessionProjectChoiceKind.workspaceFolder =>
      'workspace_folder_${path}_tile',
    NewSessionProjectChoiceKind.recent => 'recent_project_${path}_tile',
  };
}

bool isSameOrDescendantPath(String path, String root) {
  String normalize(String value) =>
      value.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
  final normalizedPath = normalize(path);
  final normalizedRoot = normalize(root);
  return normalizedPath == normalizedRoot ||
      normalizedPath.startsWith('$normalizedRoot/');
}

/// Worktree selection mode.
enum NewSessionWorktreeMode {
  /// Create a new worktree (default).
  createNew,

  /// Use an existing worktree.
  useExisting,
}
