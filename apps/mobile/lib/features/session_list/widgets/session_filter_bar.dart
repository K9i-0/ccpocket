import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';
import '../state/session_list_state.dart';

class SessionFilterBar extends StatelessWidget {
  final SessionDisplayMode displayMode;
  final VoidCallback onToggleDisplayMode;
  final ProviderFilter providerFilter;
  final VoidCallback onToggleProviderFilter;
  final List<({String path, String name})> projects;
  final String? currentProjectFilter;
  final ValueChanged<String?> onProjectFilterChanged;
  final bool namedOnly;
  final VoidCallback onToggleNamed;

  const SessionFilterBar({
    super.key,
    required this.displayMode,
    required this.onToggleDisplayMode,
    required this.providerFilter,
    required this.onToggleProviderFilter,
    required this.projects,
    required this.currentProjectFilter,
    required this.onProjectFilterChanged,
    required this.namedOnly,
    required this.onToggleNamed,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDisplayModeDropdown(context),
          const SizedBox(width: 8),
          _buildProviderDropdown(context),
          const SizedBox(width: 8),
          if (projects.isNotEmpty) ...[
            _buildProjectDropdown(context),
            const SizedBox(width: 8),
          ],
          _buildNamedToggle(context),
        ],
      ),
    );
  }

  Widget _buildDisplayModeDropdown(BuildContext context) {
    final label = switch (displayMode) {
      SessionDisplayMode.first => 'First',
      SessionDisplayMode.last => 'Last',
      SessionDisplayMode.summary => 'Summary',
    };

    return _ActionChip(
      icon: Icons.visibility_outlined,
      label: label,
      onTap: onToggleDisplayMode,
    );
  }

  Widget _buildProviderDropdown(BuildContext context) {
    final label = switch (providerFilter) {
      ProviderFilter.all => 'All Providers',
      ProviderFilter.claude => 'Claude',
      ProviderFilter.codex => 'Codex',
    };

    return _ActionChip(
      icon: Icons.smart_toy_outlined,
      label: label,
      onTap: onToggleProviderFilter,
      isActive: providerFilter != ProviderFilter.all,
    );
  }

  Widget _buildProjectDropdown(BuildContext context) {
    final currentProject = projects
        .where((p) => p.path == currentProjectFilter)
        .firstOrNull;

    return _DropdownChip<String?>(
      icon: Icons.folder_outlined,
      label: currentProject != null ? currentProject.name : 'All Projects',
      items: [
        (value: null, label: 'All Projects'),
        ...projects.map((p) => (value: p.path, label: p.name)),
      ],
      onSelected: onProjectFilterChanged,
      isActive: currentProjectFilter != null,
    );
  }

  Widget _buildNamedToggle(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;

    return Material(
      color: namedOnly ? cs.primaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggleNamed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: namedOnly
                  ? cs.primaryContainer
                  : cs.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.label_outlined,
                size: 14,
                color: namedOnly ? cs.onPrimaryContainer : appColors.subtleText,
              ),
              const SizedBox(width: 6),
              Text(
                'Named',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: namedOnly
                      ? cs.onPrimaryContainer
                      : appColors.subtleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;

    return Material(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownChip<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<({T value, String label})> items;
  final ValueChanged<T> onSelected;
  final bool isActive;

  const _DropdownChip({
    required this.icon,
    required this.label,
    required this.items,
    required this.onSelected,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;

    return MenuAnchor(
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
  }
}
