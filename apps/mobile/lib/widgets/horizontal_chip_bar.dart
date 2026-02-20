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
              child: _buildChip(
                context,
                item,
                fontSize: fontSize,
                isSelected: item.isSelected,
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

  Widget _buildChip(
    BuildContext context,
    ChipItem item, {
    required double fontSize,
    required bool isSelected,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = isSelected ? selectedColor : unselectedTextColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onSelected,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? selectedColor.withValues(alpha: 0.5)
                  : cs.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
