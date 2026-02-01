import 'package:flutter/material.dart';

import '../../models/messages.dart';
import '../../theme/app_theme.dart';

class ResultChip extends StatelessWidget {
  final ResultMessage message;
  const ResultChip({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final parts = <String>[];
    if (message.cost != null) {
      parts.add('\$${message.cost!.toStringAsFixed(4)}');
    }
    if (message.duration != null) {
      parts.add('${(message.duration! / 1000).toStringAsFixed(1)}s');
    }
    final String label;
    final Color chipColor;
    switch (message.subtype) {
      case 'success':
        label = 'Done${parts.isNotEmpty ? ' (${parts.join(", ")})' : ''}';
        chipColor = appColors.successChip;
      case 'stopped':
        label = 'Stopped';
        chipColor = appColors.subtleText.withValues(alpha: 0.2);
      default:
        label = 'Error: ${message.error ?? 'unknown'}';
        chipColor = appColors.errorChip;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          backgroundColor: chipColor,
          side: BorderSide.none,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
