import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart' show pathBasename;
import '../../../theme/app_theme.dart';
import '../state/recent_session_filters.dart';
import '../state/session_list_state.dart';
import 'recent_session_filter_sheets.dart';

/// Quick filters for recent sessions, most used first.
///
/// Display settings (List / Grouped, card text) live in a separate sheet and
/// rarely used conditions in the advanced search sheet.
class SessionFilterBar extends StatelessWidget {
  final RecentSessionFilters filters;
  final bool supportsAdvancedFilters;
  final ProviderFilter providerFilter;
  final List<ProviderFilter> providerOptions;
  final ValueChanged<ProviderFilter> onProviderSelected;
  final List<RecentProjectOption> projects;
  final VoidCallback onOpenProjectPicker;
  final VoidCallback onTogglePinnedOnly;
  final ValueChanged<RecentDateFilter?> onDateFilterChanged;
  final VoidCallback onPickCustomDateRange;

  /// Conditions set only in advanced search (named only, content search…).
  final int advancedCount;
  final VoidCallback onOpenAdvancedSearch;

  /// Shown when any filter is active.
  final VoidCallback? onClearFilters;

  const SessionFilterBar({
    super.key,
    required this.filters,
    required this.supportsAdvancedFilters,
    required this.providerFilter,
    this.providerOptions = const [
      ProviderFilter.all,
      ProviderFilter.codex,
      ProviderFilter.claude,
    ],
    required this.onProviderSelected,
    required this.projects,
    required this.onOpenProjectPicker,
    required this.onTogglePinnedOnly,
    required this.onDateFilterChanged,
    required this.onPickCustomDateRange,
    required this.advancedCount,
    required this.onOpenAdvancedSearch,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chips = <Widget>[
      _ActionChip(
        key: const ValueKey('recent_pinned_only_chip'),
        icon: filters.pinnedOnly ? Icons.push_pin : Icons.push_pin_outlined,
        label: l.recentFilterPinnedOnly,
        tooltip: l.recentPinnedOnly,
        isActive: supportsAdvancedFilters && filters.pinnedOnly,
        isDisabled: !supportsAdvancedFilters,
        onTap: supportsAdvancedFilters
            ? onTogglePinnedOnly
            : () => showRecentBridgeUpdateHint(context),
      ),
      _ActionChip(
        key: const ValueKey('project_filter_chip'),
        icon: Icons.folder_outlined,
        label: _projectLabel(l),
        tooltip: l.tooltipProjectFilter,
        isActive: filters.projectKeys.isNotEmpty,
        trailingIcon: Icons.arrow_drop_down,
        onTap: onOpenProjectPicker,
      ),
      if (providerOptions.length > 1)
        _DropdownChip<ProviderFilter>(
          anchorKey: const ValueKey('provider_filter_chip'),
          icon: Icons.smart_toy_outlined,
          label: _providerLabel(l, providerFilter),
          tooltip: l.tooltipProviderFilter,
          items: [
            for (final option in providerOptions)
              (value: option, label: _providerLabel(l, option)),
          ],
          onSelected: onProviderSelected,
          isActive: providerFilter != ProviderFilter.all,
        ),
      if (supportsAdvancedFilters)
        _DropdownChip<RecentDatePreset?>(
          anchorKey: const ValueKey('period_filter_chip'),
          icon: Icons.event_outlined,
          label: recentDateFilterLabel(context, filters.dateFilter),
          items: [
            (value: null, label: l.recentDateAnyTime),
            for (final preset in RecentDatePreset.values)
              (value: preset, label: recentDatePresetLabel(l, preset)),
          ],
          onSelected: (preset) {
            if (preset == RecentDatePreset.custom) {
              onPickCustomDateRange();
            } else {
              onDateFilterChanged(
                preset == null ? null : RecentDateFilter(preset),
              );
            }
          },
          isActive: filters.dateFilter != null,
        )
      else
        _ActionChip(
          key: const ValueKey('period_filter_chip'),
          icon: Icons.event_outlined,
          label: l.recentFilterPeriod,
          isDisabled: true,
          onTap: () => showRecentBridgeUpdateHint(context),
        ),
      _ActionChip(
        key: const ValueKey('advanced_search_chip'),
        icon: Icons.manage_search,
        label: advancedCount > 0
            ? l.recentAdvancedConditions(advancedCount)
            : l.recentAdvancedSearch,
        isActive: advancedCount > 0,
        onTap: onOpenAdvancedSearch,
      ),
      if (onClearFilters != null)
        _ActionChip(
          key: const ValueKey('clear_filters_chip'),
          icon: Icons.close,
          label: l.recentFilterClear,
          onTap: onClearFilters!,
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            chips[i],
          ],
        ],
      ),
    );
  }

  String _projectLabel(AppLocalizations l) {
    final keys = filters.projectKeys;
    if (keys.isEmpty) return l.allProjects;
    final names = {for (final p in projects) p.key: p.name};
    final sorted = keys.toList()..sort();
    final first = names[sorted.first] ?? pathBasename(sorted.first);
    return keys.length == 1
        ? first
        : l.recentFilterProjectsSummary(first, keys.length - 1);
  }

  static String _providerLabel(AppLocalizations l, ProviderFilter filter) =>
      switch (filter) {
        ProviderFilter.all => l.allAiTools,
        ProviderFilter.claude => 'Claude',
        ProviderFilter.codex => 'Codex',
      };
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback onTap;
  final bool isActive;
  final bool isDisabled;
  final IconData? trailingIcon;

  const _ActionChip({
    super.key,
    required this.icon,
    required this.label,
    this.tooltip,
    required this.onTap,
    this.isActive = false,
    this.isDisabled = false,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;

    Widget chip = Material(
      color: isActive ? cs.primaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive
                  ? cs.primaryContainer
                  : cs.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? cs.onPrimaryContainer : appColors.subtleText,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? cs.onPrimaryContainer
                      : appColors.subtleText,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(
                  trailingIcon,
                  size: 16,
                  color: isActive
                      ? cs.onPrimaryContainer
                      : appColors.subtleText,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (isDisabled) chip = Opacity(opacity: 0.5, child: chip);

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: chip);
    }
    return chip;
  }
}

class _DropdownChip<T> extends StatelessWidget {
  final Key? anchorKey;
  final IconData icon;
  final String label;
  final String? tooltip;
  final List<({T value, String label})> items;
  final ValueChanged<T> onSelected;
  final bool isActive;

  const _DropdownChip({
    this.anchorKey,
    required this.icon,
    required this.label,
    this.tooltip,
    required this.items,
    required this.onSelected,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;

    Widget chip = MenuAnchor(
      key: anchorKey,
      builder: (context, controller, child) {
        return Material(
          color: isActive ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive
                      ? cs.primaryContainer
                      : cs.outlineVariant.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isActive
                        ? cs.onPrimaryContainer
                        : appColors.subtleText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? cs.onPrimaryContainer
                          : appColors.subtleText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: isActive
                        ? cs.onPrimaryContainer
                        : appColors.subtleText,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      menuChildren: items.map((item) {
        return MenuItemButton(
          onPressed: () => onSelected(item.value),
          child: Text(item.label),
        );
      }).toList(),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: chip);
    }
    return chip;
  }
}
