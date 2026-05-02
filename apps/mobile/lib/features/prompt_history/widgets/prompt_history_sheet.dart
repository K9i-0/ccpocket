import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/bridge_service.dart';
import '../../../services/prompt_history_service.dart';
import '../../../theme/app_theme.dart';
import '../state/prompt_history_cubit.dart';
import '../state/prompt_history_state.dart';
import 'prompt_history_tile.dart';

/// Bottom sheet displaying prompt history with sort and filter controls.
///
/// Creates its own [PromptHistoryCubit] scoped to the sheet lifetime.
class PromptHistorySheet extends StatelessWidget {
  final PromptHistoryService service;
  final BridgeService? bridgeService;
  final String? currentProjectPath;
  final String? currentBridgeId;
  final void Function(String text) onSelect;

  const PromptHistorySheet({
    super.key,
    required this.service,
    this.bridgeService,
    this.currentProjectPath,
    this.currentBridgeId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = PromptHistoryCubit(
          service,
          bridgeService: bridgeService,
          currentProjectPath: currentProjectPath,
          currentBridgeId: currentBridgeId,
        );
        Future.wait([
          service.getDefaultFilters(),
          service.getFiltersExpanded(),
        ]).then((values) {
          if (!cubit.isClosed) {
            cubit.restorePreferences(
              filters: values[0] as PromptHistoryFilters,
              filtersExpanded: values[1] as bool,
              syncFirst: true,
            );
          }
        });
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

          // Header with sort/filter controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BlocBuilder<PromptHistoryCubit, PromptHistoryState>(
              buildWhen: (previous, current) =>
                  previous.sortOrder != current.sortOrder ||
                  previous.filtersExpanded != current.filtersExpanded ||
                  previous.filters != current.filters,
              builder: (context, state) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          l.promptHistory,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _HeaderIconButton(
                          key: const ValueKey('prompt_history_filter_button'),
                          icon: Icons.filter_list,
                          selected: state.filters.hasActiveFilter,
                          tooltip: l.promptHistoryFilters,
                          onTap: () => context
                              .read<PromptHistoryCubit>()
                              .toggleFiltersExpanded(),
                        ),
                        const SizedBox(width: 4),
                        _SortCycleButton(sortOrder: state.sortOrder),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: state.filtersExpanded
                          ? _PromptHistoryFilterMenu(
                              filters: state.filters,
                              onChanged: (filters) => context
                                  .read<PromptHistoryCubit>()
                                  .setFilters(filters),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),

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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l.noPromptHistoryYet,
                            style: TextStyle(color: cs.outline),
                            textAlign: TextAlign.center,
                          ),
                          if (state.filters.currentProjectOnly) ...[
                            const SizedBox(height: 8),
                            Text(
                              key: const ValueKey(
                                'prompt_history_open_project_empty_hint',
                              ),
                              l.promptHistoryOpenProjectEmptyHint,
                              style: TextStyle(color: cs.outline, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

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
                      onTap: () {
                        Navigator.pop(context);
                        widget.onSelect(entry.text);
                      },
                      onToggleFavorite: () {
                        context.read<PromptHistoryCubit>().toggleFavorite(
                          entry,
                        );
                      },
                      onDelete: () {
                        context.read<PromptHistoryCubit>().delete(entry);
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

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SortCycleButton extends StatelessWidget {
  final PromptSortOrder sortOrder;

  const _SortCycleButton({required this.sortOrder});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = switch (sortOrder) {
      PromptSortOrder.frequency => l.frequent,
      PromptSortOrder.recency => l.recent,
      PromptSortOrder.favoritesFirst => l.favorite,
    };
    final icon = switch (sortOrder) {
      PromptSortOrder.frequency => Icons.repeat,
      PromptSortOrder.recency => Icons.schedule,
      PromptSortOrder.favoritesFirst => Icons.star,
    };
    return Tooltip(
      message: label,
      child: TextButton.icon(
        key: const ValueKey('prompt_history_sort_button'),
        onPressed: context.read<PromptHistoryCubit>().cycleSortOrder,
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PromptHistoryFilterMenu extends StatelessWidget {
  final PromptHistoryFilters filters;
  final ValueChanged<PromptHistoryFilters> onChanged;

  const _PromptHistoryFilterMenu({
    required this.filters,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _FilterChipButton(
            key: const ValueKey('prompt_history_self_filter_chip'),
            label: AppLocalizations.of(context).promptHistoryFilterThisDevice,
            selected: filters.selfOnly,
            onTap: () =>
                onChanged(filters.copyWith(selfOnly: !filters.selfOnly)),
          ),
          _FilterChipButton(
            key: const ValueKey('prompt_history_project_filter_chip'),
            label: AppLocalizations.of(context).promptHistoryFilterThisProject,
            selected: filters.currentProjectOnly,
            onTap: () => onChanged(
              filters.copyWith(currentProjectOnly: !filters.currentProjectOnly),
            ),
          ),
          _FilterChipButton(
            key: const ValueKey('prompt_history_bridge_filter_chip'),
            label: AppLocalizations.of(context).promptHistoryFilterThisBridge,
            selected: filters.currentBridgeOnly,
            onTap: () => onChanged(
              filters.copyWith(currentBridgeOnly: !filters.currentBridgeOnly),
            ),
          ),
          _FilterChipButton(
            key: const ValueKey('prompt_history_favorites_filter_chip'),
            label: AppLocalizations.of(context).promptHistoryFilterFavorites,
            selected: filters.favoritesOnly,
            onTap: () => onChanged(
              filters.copyWith(favoritesOnly: !filters.favoritesOnly),
            ),
          ),
          _FilterChipButton(
            key: const ValueKey('prompt_history_commands_filter_chip'),
            label: AppLocalizations.of(context).promptHistoryFilterCommands,
            selected: filters.commandsOnly,
            onTap: () => onChanged(
              filters.copyWith(commandsOnly: !filters.commandsOnly),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      selectedColor: cs.primaryContainer,
      checkmarkColor: cs.onPrimaryContainer,
    );
  }
}
