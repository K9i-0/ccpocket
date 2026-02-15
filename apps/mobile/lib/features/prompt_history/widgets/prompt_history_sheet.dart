import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

class _PromptHistorySheetBody extends StatelessWidget {
  final String? currentProjectPath;
  final void Function(String text) onSelect;

  const _PromptHistorySheetBody({
    this.currentProjectPath,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  'Prompt History',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                        _buildSortChip(
                          context,
                          label: 'Recent',
                          value: PromptSortOrder.recency,
                          current: sortOrder,
                          cs: cs,
                        ),
                        const SizedBox(width: 4),
                        _buildSortChip(
                          context,
                          label: 'Frequent',
                          value: PromptSortOrder.frequency,
                          current: sortOrder,
                          cs: cs,
                        ),
                        const SizedBox(width: 4),
                        _buildSortChip(
                          context,
                          icon: Icons.star,
                          value: PromptSortOrder.favoritesFirst,
                          current: sortOrder,
                          cs: cs,
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
                hintText: 'Search...',
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
                    _buildProjectChip(
                      context,
                      label: 'All',
                      value: null,
                      current: data.filter,
                      cs: cs,
                    ),
                    const SizedBox(width: 6),
                    for (final path in data.projects) ...[
                      _buildProjectChip(
                        context,
                        label: path.split('/').last,
                        value: path,
                        current: data.filter,
                        cs: cs,
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
                if (state.isLoading) {
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
                            ? 'No matching prompts'
                            : 'No prompt history yet',
                        style: TextStyle(color: cs.outline),
                      ),
                    ),
                  );
                }

                final showProjectBadge = state.projectFilter == null;

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: state.prompts.length,
                  itemBuilder: (context, index) {
                    final entry = state.prompts[index];
                    return PromptHistoryTile(
                      entry: entry,
                      showProjectBadge: showProjectBadge,
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(entry.text);
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

  Widget _buildSortChip(
    BuildContext context, {
    String? label,
    IconData? icon,
    required PromptSortOrder value,
    required PromptSortOrder current,
    required ColorScheme cs,
  }) {
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

  Widget _buildProjectChip(
    BuildContext context, {
    required String label,
    required String? value,
    required String? current,
    required ColorScheme cs,
  }) {
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
