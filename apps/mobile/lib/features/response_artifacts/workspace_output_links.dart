import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;

import '../../models/messages.dart';
import '../file_peek/markdown_link_handler.dart';

const _maxWorkspaceOutputLinks = 32;
// Keep Markdown parsing and line allocation bounded for large command output.
const _maxWorkspaceOutputScanLength = 256 * 1024;
const _maxWorkspaceOutputLineLength = 4 * 1024;
const _maxWorkspaceOutputPathLength = 256;
const _maxWorkspaceOutputLabelLength = 256;

class WorkspaceOutputLink {
  final String path;
  final String label;

  const WorkspaceOutputLink({required this.path, required this.label});
}

typedef _CachedWorkspaceLinks = ({
  Set<String> suffixes,
  String? projectPath,
  List<WorkspaceOutputLink> links,
});
final _messageLinks = Expando<_CachedWorkspaceLinks>('workspace output links');

/// Returns Markdown links to files confirmed in the active workspace.
List<WorkspaceOutputLink> workspaceOutputLinks(
  String text, {
  Set<String> knownPathSuffixes = const {},
  String? projectPath,
}) {
  final boundedText = _boundedWorkspaceOutputText(text);
  if (knownPathSuffixes.isEmpty ||
      projectPath == null ||
      !boundedText.contains('[')) {
    return const [];
  }
  final links = <String, WorkspaceOutputLink>{};
  void visit(md.Node node) {
    if (links.length >= _maxWorkspaceOutputLinks) return;
    if (node is! md.Element) return;
    if (node.tag == 'a' || node.tag == 'img') {
      final href = node.attributes[node.tag == 'img' ? 'src' : 'href'];
      if (href != null && href.length <= _maxWorkspaceOutputPathLength) {
        final relativePath = _workspaceRelativeFilePath(
          href,
          projectPath: projectPath,
          knownPathSuffixes: knownPathSuffixes,
        );
        if (relativePath != null) {
          final rawLabel = node.tag == 'img'
              ? node.attributes['alt'] ?? ''
              : node.textContent;
          final label = rawLabel.length <= _maxWorkspaceOutputLabelLength
              ? rawLabel
              : rawLabel.substring(0, _maxWorkspaceOutputLabelLength);
          links.putIfAbsent(
            relativePath,
            () => WorkspaceOutputLink(path: relativePath, label: label),
          );
        }
      }
    }
    if (node.tag == 'code' || node.tag == 'pre') return;
    for (final child in node.children ?? const <md.Node>[]) {
      visit(child);
    }
  }

  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  for (final node in document.parseLines(boundedText.split('\n'))) {
    if (links.length >= _maxWorkspaceOutputLinks) break;
    visit(node);
  }
  return List.unmodifiable(links.values);
}

String _boundedWorkspaceOutputText(String text) {
  if (text.length <= _maxWorkspaceOutputLineLength) return text;

  final output = StringBuffer();
  var position = 0;
  var scanned = 0;
  while (position < text.length && scanned < _maxWorkspaceOutputScanLength) {
    final remainingBudget = _maxWorkspaceOutputScanLength - scanned;
    var lineEnd = position;
    while (lineEnd < text.length &&
        lineEnd - position < remainingBudget &&
        text.codeUnitAt(lineEnd) != 0x0a) {
      lineEnd++;
    }
    final lineLength = lineEnd - position;
    final retainedLineEnd =
        position +
        (lineLength < _maxWorkspaceOutputLineLength
            ? lineLength
            : _maxWorkspaceOutputLineLength);
    output.write(text.substring(position, retainedLineEnd));
    scanned += lineLength;
    if (lineEnd >= text.length || text.codeUnitAt(lineEnd) != 0x0a) break;
    if (scanned >= _maxWorkspaceOutputScanLength) break;
    output.write('\n');
    scanned++;
    position = lineEnd + 1;
  }
  return output.toString();
}

List<WorkspaceOutputLink> workspaceOutputLinksForMessage(
  ServerMessage message, {
  Set<String> knownPathSuffixes = const {},
  String? projectPath,
}) {
  final cached = _messageLinks[message];
  if (cached != null &&
      identical(cached.suffixes, knownPathSuffixes) &&
      cached.projectPath == projectPath) {
    return cached.links;
  }
  final text = switch (message) {
    AssistantServerMessage(:final message) => _boundedAssistantText(
      message.content,
    ),
    ToolResultMessage(:final content) => content,
    ResultMessage(:final result) => result ?? '',
    _ => '',
  };
  final byPath = <String, WorkspaceOutputLink>{};
  if (message is ToolResultMessage) {
    for (final candidate in message.outputLinkCandidates) {
      if (candidate.syntax != 'markdown') continue;
      final relativePath = _workspaceRelativeFilePath(
        candidate.href,
        projectPath: projectPath,
        knownPathSuffixes: knownPathSuffixes,
      );
      if (relativePath == null) continue;
      if (byPath.length >= _maxWorkspaceOutputLinks) break;
      byPath.putIfAbsent(
        relativePath,
        () => WorkspaceOutputLink(
          path: relativePath,
          label: candidate.label ?? '',
        ),
      );
    }
  }
  if (byPath.length < _maxWorkspaceOutputLinks) {
    for (final link in workspaceOutputLinks(
      text,
      knownPathSuffixes: knownPathSuffixes,
      projectPath: projectPath,
    )) {
      final existing = byPath[link.path];
      if (existing != null) {
        if (existing.label.isEmpty && link.label.isNotEmpty) {
          byPath[link.path] = link;
        }
        continue;
      }
      if (byPath.length >= _maxWorkspaceOutputLinks) break;
      byPath[link.path] = link;
    }
  }
  final result = List<WorkspaceOutputLink>.unmodifiable(byPath.values);
  _messageLinks[message] = (
    suffixes: knownPathSuffixes,
    projectPath: projectPath,
    links: result,
  );
  return result;
}

String? _workspaceRelativeFilePath(
  String href, {
  required String? projectPath,
  required Set<String> knownPathSuffixes,
}) {
  if (projectPath == null ||
      projectPath.trim().isEmpty ||
      knownPathSuffixes.isEmpty) {
    return null;
  }
  final target = classifyMarkdownLink(
    href,
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

String _boundedAssistantText(List<AssistantContent> content) {
  final text = StringBuffer();
  var remaining = _maxWorkspaceOutputScanLength;
  for (final block in content.whereType<TextContent>()) {
    if (remaining <= 0) break;
    if (text.length > 0) {
      text.write('\n\n');
      remaining -= 2;
      if (remaining <= 0) break;
    }
    final value = block.text;
    if (value.length <= remaining) {
      text.write(value);
      remaining -= value.length;
    } else {
      text.write(value.substring(0, remaining));
      break;
    }
  }
  return text.toString();
}
