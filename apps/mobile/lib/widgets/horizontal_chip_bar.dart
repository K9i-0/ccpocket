import 'package:flutter/material.dart';

/// A single chip item for [HorizontalChipBar].
class ChipItem {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final Widget? avatar;

  const ChipItem({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.avatar,
  });
}

/// Horizontal scrollable [ChoiceChip] bar with optional fade edge.
class HorizontalChipBar extends StatelessWidget {
  final List<ChipItem> items;
  final double height;
  final Color selectedColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final double fontSize;
  final bool showFade;

  const HorizontalChipBar({
    super.key,
    required this.items,
    this.height = 32,
    required this.selectedColor,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    this.fontSize = 11,
    this.showFade = false,
  });

  @override
  Widget build(BuildContext context) {
    final list = SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 4, right: 28),
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: item.avatar,
                label: Text(item.label),
                selected: item.isSelected,
                onSelected: (_) => item.onSelected(),
                labelStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: item.isSelected
                      ? selectedTextColor
                      : unselectedTextColor,
                ),
                selectedColor: selectedColor,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );

    if (!showFade) return list;

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white,
          Colors.white,
          Colors.white,
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.85, 0.92, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: list,
    );
  }
}
