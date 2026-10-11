import 'package:path/path.dart' as p;

import '../../models/messages.dart';
import '../file_peek/markdown_link_handler.dart';

const _maxWorkspaceOutputLinks = 32;
const _maxWorkspaceOutputPathLength = 2048;

class WorkspaceOutputLink {
  final String path;
  final String label;

  const WorkspaceOutputLink({required this.path, required this.label});
}

/// Returns MCP resource links confirmed in the active workspace.
List<WorkspaceOutputLink> workspaceOutputLinksForMessage(
  ServerMessage message, {
  Set<String> knownPathSuffixes = const {},
  String? projectPath,
}) {
  if (message is! ToolResultMessage ||
      projectPath == null ||
      projectPath.trim().isEmpty ||
      knownPathSuffixes.isEmpty) {
    return const [];
  }

  final links = <String, WorkspaceOutputLink>{};
  for (final resource in message.mcpResourceLinks) {
    if (links.length >= _maxWorkspaceOutputLinks) break;
    if (resource.uri.length > _maxWorkspaceOutputPathLength) continue;
    final relativePath = _workspaceRelativeFilePath(
      resource.uri,
      projectPath: projectPath,
      knownPathSuffixes: knownPathSuffixes,
    );
    if (relativePath == null) continue;
    links.putIfAbsent(
      relativePath,
      () => WorkspaceOutputLink(path: relativePath, label: resource.name),
    );
  }

  return List.unmodifiable(links.values);
}

String? _workspaceRelativeFilePath(
  String uri, {
  required String? projectPath,
  required Set<String> knownPathSuffixes,
}) {
  if (projectPath == null ||
      projectPath.trim().isEmpty ||
      knownPathSuffixes.isEmpty) {
    return null;
  }
  final target = classifyMarkdownLink(
    uri,
    knownPathSuffixes: knownPathSuffixes,
  );
  if (target.kind != MarkdownLinkTargetKind.file) return null;

  final project = projectPath.trim();
  final windowsStyle = RegExp(r'^[A-Za-z]:[\\/]|^\\\\').hasMatch(project);
  final context = p.Context(
    style: windowsStyle ? p.Style.windows : p.Style.posix,
  );
  final rawPath = target.value
      .replaceFirst(RegExp(r'(:\d+){1,2}$'), '')
      .replaceAll('\\', '/');
  final windowsTarget = RegExp(r'^[A-Za-z]:/|^//').hasMatch(rawPath);
  final posixTarget = rawPath.startsWith('/') && !windowsTarget;
  if ((windowsTarget || posixTarget) && windowsTarget != windowsStyle) {
    return null;
  }

  final root = context.normalize(project);
  final resolved = context.normalize(
    context.isAbsolute(rawPath) ? rawPath : context.join(root, rawPath),
  );
  if (resolved == root || !context.isWithin(root, resolved)) return null;
  final relative = context.relative(resolved, from: root).replaceAll('\\', '/');
  if (relative.isEmpty || relative.startsWith('../')) return null;

  return knownPathSuffixes.contains(relative) ? relative : null;
}
