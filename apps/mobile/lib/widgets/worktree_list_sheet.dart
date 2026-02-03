import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messages.dart';
import '../services/bridge_service.dart';
import '../theme/app_theme.dart';

/// Shows a bottom sheet listing git worktrees for a project.
Future<void> showWorktreeListSheet({
  required BuildContext context,
  required BridgeService bridge,
  required String projectPath,
}) {
  bridge.requestWorktreeList(projectPath);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _WorktreeListContent(
      bridge: bridge,
      projectPath: projectPath,
    ),
  );
}

class _WorktreeListContent extends StatefulWidget {
  final BridgeService bridge;
  final String projectPath;

  const _WorktreeListContent({
    required this.bridge,
    required this.projectPath,
  });

  @override
  State<_WorktreeListContent> createState() => _WorktreeListContentState();
}

class _WorktreeListContentState extends State<_WorktreeListContent> {
  List<WorktreeInfo>? _worktrees;
  StreamSubscription<WorktreeListMessage>? _sub;
  StreamSubscription<ServerMessage>? _removeSub;

  @override
  void initState() {
    super.initState();
    _sub = widget.bridge.worktreeList.listen((msg) {
      if (mounted) setState(() => _worktrees = msg.worktrees);
    });
    _removeSub = widget.bridge.messages.listen((msg) {
      if (msg is WorktreeRemovedMessage && mounted) {
        // Refresh list after removal
        widget.bridge.requestWorktreeList(widget.projectPath);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _removeSub?.cancel();
    super.dispose();
  }

  void _confirmRemove(WorktreeInfo wt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Worktree'),
        content: Text('Remove worktree on branch "${wt.branch}"?\n'
            'Path: ${wt.worktreePath}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.bridge.removeWorktree(
                widget.projectPath,
                wt.worktreePath,
              );
            },
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: appColors.subtleText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.account_tree_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Worktrees',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_worktrees == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (_worktrees!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No worktrees found',
                  style: TextStyle(color: appColors.subtleText),
                ),
              ),
            )
          else
            for (final wt in _worktrees!)
              ListTile(
                leading: Icon(
                  Icons.fork_right,
                  size: 20,
                  color: appColors.subtleText,
                ),
                title: Text(
                  wt.branch,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  wt.worktreePath.split('/').last,
                  style: TextStyle(fontSize: 11, color: appColors.subtleText),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _confirmRemove(wt),
                  tooltip: 'Remove worktree',
                ),
              ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
