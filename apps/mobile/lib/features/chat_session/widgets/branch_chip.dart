import 'package:flutter/material.dart';

/// A compact branch indicator matching StatusIndicator's minimal aesthetic.
///
/// Tapping opens the worktree list sheet.
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

    return Tooltip(
      message: isMainRepo ? 'main repo' : 'worktree: $displayName',
      preferBelow: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMainRepo ? Icons.commit : Icons.fork_right,
                size: 13,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 72),
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
