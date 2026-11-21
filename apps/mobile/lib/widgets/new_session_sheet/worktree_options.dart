import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../theme/app_theme.dart';
import 'project_choice.dart';

class NewSessionWorktreeOptions extends StatelessWidget {
  final AppColors appColors;
  final NewSessionWorktreeMode worktreeMode;
  final ValueChanged<NewSessionWorktreeMode> onWorktreeModeChanged;
  final List<WorktreeInfo>? worktrees;
  final WorktreeInfo? selectedWorktree;
  final ValueChanged<WorktreeInfo> onWorktreeSelected;
  final TextEditingController branchController;
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;

  const NewSessionWorktreeOptions({
    super.key,
    required this.appColors,
    required this.worktreeMode,
    required this.onWorktreeModeChanged,
    required this.worktrees,
    required this.selectedWorktree,
    required this.onWorktreeSelected,
    required this.branchController,
    required this.buildInputDecoration,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final hasWorktrees = worktrees != null && worktrees!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode selection: New / Existing
        if (hasWorktrees) ...[
          Row(
            children: [
              ChoiceChip(
                label: Text(
                  l.worktreeNew,
                  style: TextStyle(
                    fontSize: 12,
                    color: worktreeMode == NewSessionWorktreeMode.createNew
                        ? cs.onPrimaryContainer
                        : cs.onSurface,
                  ),
                ),
                checkmarkColor: cs.onPrimaryContainer,
                selected: worktreeMode == NewSessionWorktreeMode.createNew,
                onSelected: (_) =>
                    onWorktreeModeChanged(NewSessionWorktreeMode.createNew),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(
                  l.worktreeExisting(worktrees!.length),
                  style: TextStyle(
                    fontSize: 12,
                    color: worktreeMode == NewSessionWorktreeMode.useExisting
                        ? cs.onPrimaryContainer
                        : cs.onSurface,
                  ),
                ),
                checkmarkColor: cs.onPrimaryContainer,
                selected: worktreeMode == NewSessionWorktreeMode.useExisting,
                onSelected: (_) =>
                    onWorktreeModeChanged(NewSessionWorktreeMode.useExisting),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // New worktree: branch input
        if (worktreeMode == NewSessionWorktreeMode.createNew)
          TextField(
            key: const ValueKey('dialog_worktree_branch'),
            controller: branchController,
            decoration:
                buildInputDecoration(
                  l.branchOptional,
                  hintText: l.branchHint,
                  prefixIcon: const Icon(Icons.merge_outlined, size: 18),
                ).copyWith(
                  filled: true,
                  fillColor: Color.lerp(
                    cs.surfaceContainerHigh,
                    cs.onSurface,
                    0.05,
                  ),
                ),
            style: const TextStyle(fontSize: 13),
          ),
        // Existing worktree selection
        if (worktreeMode == NewSessionWorktreeMode.useExisting) ...[
          if (worktrees == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              ),
            )
          else if (worktrees!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l.noExistingWorktrees,
                style: TextStyle(fontSize: 13, color: appColors.subtleText),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final wt in worktrees!)
                      _WorktreeSelectionTile(
                        worktree: wt,
                        appColors: appColors,
                        isSelected:
                            selectedWorktree?.worktreePath == wt.worktreePath,
                        onTap: () => onWorktreeSelected(wt),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _WorktreeSelectionTile extends StatelessWidget {
  final WorktreeInfo worktree;
  final AppColors appColors;
  final bool isSelected;
  final VoidCallback onTap;

  const _WorktreeSelectionTile({
    required this.worktree,
    required this.appColors,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.tertiaryContainer.withValues(alpha: 0.3)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.fork_right,
              size: 18,
              color: isSelected ? cs.tertiary : appColors.subtleText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worktree.branch,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? cs.tertiary : null,
                    ),
                  ),
                  Text(
                    worktree.worktreePath.split('/').last,
                    style: TextStyle(fontSize: 11, color: appColors.subtleText),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: cs.tertiary),
          ],
        ),
      ),
    );
  }
}
