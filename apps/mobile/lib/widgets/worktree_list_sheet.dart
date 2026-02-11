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
  String? currentWorktreePath,
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
      currentWorktreePath: currentWorktreePath,
    ),
  );
}

class _WorktreeListContent extends StatefulWidget {
  final BridgeService bridge;
  final String projectPath;
  final String? currentWorktreePath;

  const _WorktreeListContent({
    required this.bridge,
    required this.projectPath,
    this.currentWorktreePath,
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

  bool get _isOnMainRepo => widget.currentWorktreePath == null;

  bool _isCurrentWorktree(WorktreeInfo wt) =>
      widget.currentWorktreePath == wt.worktreePath;

  Widget _buildMainRepoTile(BuildContext context, AppColors appColors) {
    final cs = Theme.of(context).colorScheme;
    final isCurrent = _isOnMainRepo;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isCurrent ? cs.primaryContainer.withValues(alpha: 0.3) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          Icons.home_outlined,
          size: 20,
          color: isCurrent ? cs.primary : appColors.subtleText,
        ),
        title: Text(
          'main repo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isCurrent ? cs.primary : null,
          ),
        ),
        subtitle: Text(
          widget.projectPath.split('/').last,
          style: TextStyle(fontSize: 11, color: appColors.subtleText),
        ),
        trailing: isCurrent
            ? Icon(Icons.check_circle, size: 20, color: cs.primary)
            : null,
      ),
    );
  }

  Widget _buildWorktreeTile(
    BuildContext context,
    AppColors appColors,
    WorktreeInfo wt,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isCurrent = _isCurrentWorktree(wt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isCurrent ? cs.tertiaryContainer.withValues(alpha: 0.3) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          Icons.fork_right,
          size: 20,
          color: isCurrent ? cs.tertiary : appColors.subtleText,
        ),
        title: Text(
          wt.branch,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isCurrent ? cs.tertiary : null,
          ),
        ),
        subtitle: Text(
          wt.worktreePath.split('/').last,
          style: TextStyle(fontSize: 11, color: appColors.subtleText),
        ),
        trailing: isCurrent
            ? Icon(Icons.check_circle, size: 20, color: cs.tertiary)
            : IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: cs.error,
                ),
                onPressed: () => _confirmRemove(wt),
                tooltip: 'Remove worktree',
              ),
      ),
    );
  }

  void _confirmRemove(WorktreeInfo wt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Worktree'),
        content: Text(
          'Remove worktree on branch "${wt.branch}"?\n'
          'Path: ${wt.worktreePath}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.bridge.removeWorktree(widget.projectPath, wt.worktreePath);
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
          else ...[
            // Main repo entry (always first)
            _buildMainRepoTile(context, appColors),
            // Worktree entries
            for (final wt in _worktrees!)
              _buildWorktreeTile(context, appColors, wt),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
