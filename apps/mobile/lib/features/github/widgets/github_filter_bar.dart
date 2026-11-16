import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../state/github_list_state.dart';

/// Filter chips above the list. Draft and dependabot filters exist only for
/// pull requests.
class GitHubFilterBar extends StatelessWidget {
  final GitHubItemKind kind;
  final GitHubFilters filters;
  final List<String> labels;
  final ValueChanged<bool> onHideDraftsChanged;
  final ValueChanged<bool> onDependabotOnlyChanged;
  final ValueChanged<String?> onLabelChanged;

  const GitHubFilterBar({
    super.key,
    required this.kind,
    required this.filters,
    required this.labels,
    required this.onHideDraftsChanged,
    required this.onDependabotOnlyChanged,
    required this.onLabelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isPr = kind == GitHubItemKind.pr;
    if (!isPr && labels.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      heightFactor: 1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          spacing: 8,
          children: [
            if (isPr)
              FilterChip(
                key: const ValueKey('github_filter_hide_drafts_chip'),
                label: Text(l.githubFilterHideDrafts),
                selected: filters.hideDrafts,
                onSelected: onHideDraftsChanged,
              ),
            if (isPr)
              FilterChip(
                key: const ValueKey('github_filter_dependabot_chip'),
                label: Text(l.githubFilterDependabotOnly),
                selected: filters.dependabotOnly,
                onSelected: onDependabotOnlyChanged,
              ),
            if (labels.isNotEmpty)
              _GitHubLabelFilterChip(
                selectedLabel: filters.label,
                labels: labels,
                onChanged: onLabelChanged,
              ),
          ],
        ),
      ),
    );
  }
}

class _GitHubLabelFilterChip extends StatelessWidget {
  final String? selectedLabel;
  final List<String> labels;
  final ValueChanged<String?> onChanged;

  const _GitHubLabelFilterChip({
    required this.selectedLabel,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selected = selectedLabel;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          key: const ValueKey('github_filter_label_all'),
          onPressed: () => onChanged(null),
          child: Text(l.githubFilterAllLabels),
        ),
        for (final label in labels)
          MenuItemButton(
            key: ValueKey('github_filter_label_$label'),
            onPressed: () => onChanged(label),
            child: Text(label),
          ),
      ],
      builder: (context, controller, _) => FilterChip(
        key: const ValueKey('github_filter_label_chip'),
        avatar: const Icon(Icons.label_outline, size: 16),
        label: Text(selected ?? l.githubFilterLabel),
        selected: selected != null,
        showCheckmark: false,
        onSelected: (_) =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
