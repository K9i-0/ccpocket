import 'package:flutter/material.dart';

/// Compact pin toggle shared by session cards and project headers.
class PinToggleButton extends StatelessWidget {
  const PinToggleButton({
    super.key,
    required this.isPinned,
    required this.onPressed,
    required this.pinTooltip,
    required this.unpinTooltip,
  });

  final bool isPinned;
  final VoidCallback? onPressed;
  final String pinTooltip;
  final String unpinTooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: isPinned ? unpinTooltip : pinTooltip,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 18),
      icon: Icon(
        isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        size: 17,
        color: onPressed == null
            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
            : isPinned
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
      ),
    );
  }
}
