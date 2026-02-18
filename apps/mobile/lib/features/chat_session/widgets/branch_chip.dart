import 'package:flutter/material.dart';

/// A chip that displays the current branch name and indicates if it's a worktree.
///
/// Tapping the chip opens the worktree list sheet.
class BranchChip extends StatelessWidget {
  final String? branchName;
  final bool isWorktree;
  final VoidCallback onTap;

  const BranchChip({
    super.key,
    required this.branchName,
    required this.isWorktree,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayName = branchName ?? 'main';
    final isMainRepo = !isWorktree;
    final color = isMainRepo ? cs.primary : cs.tertiary;

    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMainRepo ? Icons.home_outlined : Icons.fork_right,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 80),
                child: Text(
                  isMainRepo ? 'main' : displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
