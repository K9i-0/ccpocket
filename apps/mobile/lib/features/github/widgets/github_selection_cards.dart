import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/github_selection_cubit.dart';
import '../state/github_selection_state.dart';

/// The issues and pull requests picked for a session, shown above its
/// composer until they are sent or removed.
class GitHubSelectionCards extends StatelessWidget {
  final GitHubSelectionCubit cubit;
  final String sessionId;

  const GitHubSelectionCards({
    super.key,
    required this.cubit,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GitHubSelectionCubit, GitHubSelectionState>(
      bloc: cubit,
      builder: (context, _) {
        final items = cubit.items(sessionId);
        if (items.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 48,
          child: ListView.separated(
            key: const ValueKey('github_selection_cards_list'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => Center(
              child: _GitHubSelectionCard(
                item: items[index],
                onRemove: () => cubit.remove(sessionId, items[index].url),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GitHubSelectionCard extends StatelessWidget {
  final GitHubSelectedItem item;
  final VoidCallback onRemove;

  const _GitHubSelectionCard({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputChip(
      key: ValueKey('github_selection_card_${item.number}'),
      avatar: Icon(
        item.isPullRequest ? Icons.merge_type : Icons.adjust,
        size: 18,
        color: colorScheme.onSurfaceVariant,
      ),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(
          '#${item.number} ${item.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      deleteIcon: const Icon(Icons.close, size: 18),
      deleteButtonTooltipMessage: AppLocalizations.of(context).githubDeselect,
      onDeleted: onRemove,
    );
  }
}
