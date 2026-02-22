import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/prompt_history_service.dart';
import '../../../theme/app_theme.dart';
import '../state/prompt_history_cubit.dart';
import '../state/prompt_history_state.dart';
import 'prompt_history_tile.dart';

/// Bottom sheet displaying prompt history with search, sort, and project filter.
///
/// Creates its own [PromptHistoryCubit] scoped to the sheet lifetime.
class PromptHistorySheet extends StatelessWidget {
  final PromptHistoryService service;
  final String? currentProjectPath;
  final void Function(String text) onSelect;

  const PromptHistorySheet({
    super.key,
    required this.service,
    this.currentProjectPath,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = PromptHistoryCubit(service);
        if (currentProjectPath != null) {
          cubit.setProjectFilter(currentProjectPath);
        } else {
          cubit.load();
        }
        return cubit;
      },
      child: _PromptHistorySheetBody(
        currentProjectPath: currentProjectPath,
        onSelect: onSelect,
      ),
    );
  }
}

class _PromptHistorySheetBody extends StatefulWidget {
  final String? currentProjectPath;
  final void Function(String text) onSelect;

  const _PromptHistorySheetBody({
    this.currentProjectPath,
    required this.onSelect,
  });

  @override
  State<_PromptHistorySheetBody> createState() =>
      _PromptHistorySheetBodyState();
}

class _PromptHistorySheetBodyState extends State<_PromptHistorySheetBody> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<PromptHistoryCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
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

          // Header with sort chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  l.promptHistory,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                BlocSelector<
                  PromptHistoryCubit,
                  PromptHistoryState,
                  PromptSortOrder
                >(
                  selector: (state) => state.sortOrder,
                  builder: (context, sortOrder) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SortChip(
                          label: l.frequent,
                          value: PromptSortOrder.frequency,
                          current: sortOrder,
                        ),
                        const SizedBox(width: 4),
                        _SortChip(
                          label: l.recent,
                          value: PromptSortOrder.recency,
                          current: sortOrder,
                        ),
                        const SizedBox(width: 4),
                        _SortChip(
                          icon: Icons.star,
                          value: PromptSortOrder.favoritesFirst,
                          current: sortOrder,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('prompt_history_search'),
              decoration: InputDecoration(
                hintText: l.searchHint,
                prefixIcon: Icon(Icons.search, size: 20, color: cs.outline),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerLow,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (query) {
                context.read<PromptHistoryCubit>().setSearchQuery(query);
              },
            ),
          ),
          const SizedBox(height: 8),

          // Project filter chips
          BlocSelector<
            PromptHistoryCubit,
            PromptHistoryState,
            ({String? filter, List<String> projects})
          >(
            selector: (state) => (
              filter: state.projectFilter,
              projects: state.availableProjects,
            ),
            builder: (context, data) {
              if (data.projects.isEmpty) return const SizedBox.shrink();

              return SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _ProjectChip(
                      label: l.all,
                      value: null,
                      current: data.filter,
                    ),
                    const SizedBox(width: 6),
                    for (final path in data.projects) ...[
                      _ProjectChip(
                        label: path.split('/').last,
                        value: path,
                        current: data.filter,
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              );
            },
          ),

          const Divider(height: 1),

          // List
          Flexible(
            child: BlocBuilder<PromptHistoryCubit, PromptHistoryState>(
              builder: (context, state) {
                if (state.isLoading && state.prompts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (state.prompts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        state.searchQuery.isNotEmpty
                            ? l.noMatchingPrompts
                            : l.noPromptHistoryYet,
                        style: TextStyle(color: cs.outline),
                      ),
                    ),
                  );
                }

                final showProjectBadge = state.projectFilter == null;
                // +1 for the loading indicator when there are more items
                final itemCount =
                    state.prompts.length + (state.hasMore ? 1 : 0);

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index >= state.prompts.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final entry = state.prompts[index];
                    return PromptHistoryTile(
                      entry: entry,
                      showProjectBadge: showProjectBadge,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onSelect(entry.text);
                      },
                      onToggleFavorite: () {
                        context.read<PromptHistoryCubit>().toggleFavorite(
                          entry.id,
                        );
                      },
                      onDelete: () {
                        context.read<PromptHistoryCubit>().delete(entry.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final PromptSortOrder value;
  final PromptSortOrder current;

  const _SortChip({
    this.label,
    this.icon,
    required this.value,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = value == current;
    return GestureDetector(
      onTap: () => context.read<PromptHistoryCubit>().setSortOrder(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: icon != null
            ? Icon(
                icon,
                size: 14,
                color: isSelected ? cs.onPrimaryContainer : cs.outline,
              )
            : Text(
                label!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? cs.onPrimaryContainer : cs.outline,
                ),
              ),
      ),
    );
  }
}

class _ProjectChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? current;

  const _ProjectChip({
    required this.label,
    required this.value,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = value == current;
    return GestureDetector(
      onTap: () => context.read<PromptHistoryCubit>().setProjectFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
