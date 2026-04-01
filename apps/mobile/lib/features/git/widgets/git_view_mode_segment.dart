import 'package:flutter/material.dart';

import '../state/git_view_state.dart';

class GitViewModeSegment extends StatelessWidget {
  final GitViewMode viewMode;
  final ValueChanged<GitViewMode> onChanged;

  const GitViewModeSegment({
    super.key,
    required this.viewMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedAlignment = viewMode == GitViewMode.unstaged
        ? Alignment.centerLeft
        : Alignment.centerRight;

    return Container(
      key: const ValueKey('git_view_mode_segment'),
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: selectedAlignment,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _ViewModeTabButton(
                  key: const ValueKey('unstaged_tab_button'),
                  label: 'Unstaged',
                  selected: viewMode == GitViewMode.unstaged,
                  onTap: () => onChanged(GitViewMode.unstaged),
                ),
              ),
              Expanded(
                child: _ViewModeTabButton(
                  key: const ValueKey('staged_tab_button'),
                  label: 'Staged',
                  selected: viewMode == GitViewMode.staged,
                  onTap: () => onChanged(GitViewMode.staged),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewModeTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ViewModeTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
