import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/horizontal_chip_bar.dart';
import '../state/session_list_state.dart';

/// Filter chips for provider toggle and named-only filter.
///
/// Provider cycles through All → Claude → Codex on each tap.
/// Named is a simple on/off toggle.
class SessionFilterChips extends StatelessWidget {
  final ProviderFilter providerFilter;
  final bool namedOnly;
  final VoidCallback onToggleProvider;
  final VoidCallback onToggleNamed;

  const SessionFilterChips({
    super.key,
    required this.providerFilter,
    required this.namedOnly,
    required this.onToggleProvider,
    required this.onToggleNamed,
  });

  String get _providerLabel => switch (providerFilter) {
    ProviderFilter.all => 'All',
    ProviderFilter.claude => 'Claude',
    ProviderFilter.codex => 'Codex',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    final isProviderActive = providerFilter != ProviderFilter.all;

    return HorizontalChipBar(
      height: 36,
      fontSize: 12,
      showFade: false,
      selectedColor: cs.primary,
      selectedTextColor: cs.onPrimary,
      unselectedTextColor: appColors.subtleText,
      items: [
        ChipItem(
          label: _providerLabel,
          isSelected: isProviderActive,
          onSelected: onToggleProvider,
        ),
        ChipItem(
          label: 'Named',
          isSelected: namedOnly,
          onSelected: onToggleNamed,
        ),
      ],
    );
  }
}
