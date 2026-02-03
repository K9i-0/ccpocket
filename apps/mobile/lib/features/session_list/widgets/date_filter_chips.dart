import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/horizontal_chip_bar.dart';
import '../state/session_list_state.dart';

class DateFilterChips extends StatelessWidget {
  final DateFilter selected;
  final ValueChanged<DateFilter> onSelected;

  const DateFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    const filters = [
      (DateFilter.all, 'All time'),
      (DateFilter.today, 'Today'),
      (DateFilter.thisWeek, 'This week'),
      (DateFilter.thisMonth, 'This month'),
    ];

    return HorizontalChipBar(
      selectedColor: cs.tertiary,
      selectedTextColor: cs.onTertiary,
      unselectedTextColor: appColors.subtleText,
      items: [
        for (final (filter, label) in filters)
          ChipItem(
            label: label,
            isSelected: selected == filter,
            onSelected: () => onSelected(filter),
          ),
      ],
    );
  }
}
