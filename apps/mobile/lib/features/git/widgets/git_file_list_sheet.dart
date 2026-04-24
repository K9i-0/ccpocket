import 'package:flutter/material.dart';

import '../../../utils/diff_parser.dart';
import '../../../widgets/workspace_pane_chrome.dart';
import '../state/git_view_state.dart';

Future<int?> showGitFileListSheet(
  BuildContext context, {
  required List<DiffFile> files,
  required GitViewMode viewMode,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    constraints: macOSModalBottomSheetConstraints(context),
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => GitFileListSheet(
        files: files,
        viewMode: viewMode,
        scrollController: scrollController,
      ),
    ),
  );
}

class GitFileListSheet extends StatefulWidget {
  final List<DiffFile> files;
  final GitViewMode viewMode;
  final ScrollController scrollController;

  const GitFileListSheet({
    super.key,
    required this.files,
    required this.viewMode,
    required this.scrollController,
  });

  @override
  State<GitFileListSheet> createState() => _GitFileListSheetState();
}

class _GitFileListSheetState extends State<GitFileListSheet> {
  late final GitFolderNode _root;
  late final Set<String> _expandedPaths;

  @override
  void initState() {
    super.initState();
    _root = buildGitFileTree(widget.files);
    _expandedPaths = {for (final path in initialExpandedTreePaths(_root)) path};
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final modeLabel = switch (widget.viewMode) {
      GitViewMode.unstaged => 'Changes',
      GitViewMode.staged => 'Staged',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          alignment: Alignment.center,
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Files',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.files.length} files • $modeLabel',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('git_file_list_close_button'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            key: const ValueKey('git_file_list_tree'),
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            children: _buildVisibleNodes(context),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildVisibleNodes(BuildContext context) {
    final children = <Widget>[];
    for (final node in _root.children) {
      children.addAll(_buildNodeWidgets(context, node, depth: 0));
    }
    return children;
  }

  List<Widget> _buildNodeWidgets(
    BuildContext context,
    GitFileTreeNode node, {
    required int depth,
  }) {
    final widgets = <Widget>[
      _GitFileTreeRow(
        node: node,
        depth: depth,
        expanded: node.isDirectory ? _expandedPaths.contains(node.path) : null,
        onTap: () {
          if (node case GitFileLeafNode(:final fileIndex)) {
            Navigator.of(context).pop(fileIndex);
            return;
          }
          setState(() {
            if (!_expandedPaths.add(node.path)) {
              _expandedPaths.remove(node.path);
            }
          });
        },
      ),
    ];

    if (!node.isDirectory || !_expandedPaths.contains(node.path)) {
      return widgets;
    }

    for (final child in node.children) {
      widgets.addAll(_buildNodeWidgets(context, child, depth: depth + 1));
    }
    return widgets;
  }
}

sealed class GitFileTreeNode {
  final String id;
  final String name;
  final String path;
  final List<GitFileTreeNode> children;

  const GitFileTreeNode({
    required this.id,
    required this.name,
    required this.path,
    this.children = const [],
  });

  bool get isDirectory => children.isNotEmpty;
}

class GitFolderNode extends GitFileTreeNode {
  const GitFolderNode({
    required super.id,
    required super.name,
    required super.path,
    required super.children,
  });

  int get fileCount => children.fold(
    0,
    (count, child) =>
        count +
        switch (child) {
          GitFolderNode() => child.fileCount,
          GitFileLeafNode() => 1,
        },
  );
}

class GitFileLeafNode extends GitFileTreeNode {
  final int fileIndex;
  final String parentPath;

  const GitFileLeafNode({
    required super.id,
    required super.name,
    required super.path,
    required this.fileIndex,
    required this.parentPath,
  });
}

GitFolderNode buildGitFileTree(List<DiffFile> files) {
  final root = _MutableFolderNode(name: '', path: '');

  for (var index = 0; index < files.length; index++) {
    final file = files[index];
    final segments = file.filePath.split('/');
    var current = root;
    var currentPath = '';

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final isLeaf = i == segments.length - 1;
      final nextPath = currentPath.isEmpty ? segment : '$currentPath/$segment';

      if (isLeaf) {
        current.files.add(
          GitFileLeafNode(
            id: 'file:$nextPath',
            name: segment,
            path: nextPath,
            fileIndex: index,
            parentPath: currentPath,
          ),
        );
      } else {
        current = current.folders.putIfAbsent(
          segment,
          () => _MutableFolderNode(name: segment, path: nextPath),
        );
      }

      currentPath = nextPath;
    }
  }

  return root.toImmutableRoot();
}

Set<String> initialExpandedTreePaths(GitFolderNode root) {
  final expanded = <String>{};

  void visit(GitFolderNode node) {
    for (final child in node.children) {
      if (child case GitFolderNode()) {
        expanded.add(child.path);
        visit(child);
      }
    }
  }

  visit(root);
  return expanded;
}

class _GitFileTreeRow extends StatelessWidget {
  final GitFileTreeNode node;
  final int depth;
  final bool? expanded;
  final VoidCallback onTap;

  const _GitFileTreeRow({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDirectory = node.isDirectory;
    final leadingIcon = isDirectory ? Icons.folder_outlined : Icons.description;
    final chevron = isDirectory
        ? Icon(
            expanded == true ? Icons.expand_more : Icons.chevron_right,
            size: 18,
            color: cs.onSurfaceVariant,
          )
        : const SizedBox(width: 18);

    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0),
      child: InkWell(
        key: ValueKey('git_tree_node_${node.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              chevron,
              const SizedBox(width: 2),
              Icon(leadingIcon, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: isDirectory
                    ? Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : _GitFileLabel(node: node as GitFileLeafNode),
              ),
              const SizedBox(width: 8),
              Text(
                isDirectory ? '${(node as GitFolderNode).fileCount}' : '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GitFileLabel extends StatelessWidget {
  final GitFileLeafNode node;

  const _GitFileLabel({required this.node});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          node.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (node.parentPath.isNotEmpty)
          Text(
            node.parentPath,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: cs.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _MutableFolderNode {
  final String name;
  final String path;
  final Map<String, _MutableFolderNode> folders = {};
  final List<GitFileLeafNode> files = [];

  _MutableFolderNode({required this.name, required this.path});

  GitFolderNode toImmutableRoot() => GitFolderNode(
    id: path.isEmpty ? 'root' : 'folder:$path',
    name: name,
    path: path,
    children: _sortedChildren(),
  );

  List<GitFileTreeNode> _sortedChildren() {
    final folderNodes = folders.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final fileNodes = files.toList()..sort((a, b) => a.name.compareTo(b.name));

    return [
      for (final folder in folderNodes)
        GitFolderNode(
          id: folder.path.isEmpty ? 'root' : 'folder:${folder.path}',
          name: folder.name,
          path: folder.path,
          children: folder._sortedChildren(),
        ),
      ...fileNodes,
    ];
  }
}
