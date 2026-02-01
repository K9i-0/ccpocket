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
    final label = message.subtype == 'success'
        ? 'Done${parts.isNotEmpty ? ' (${parts.join(", ")})' : ''}'
        : 'Error: ${message.error ?? 'unknown'}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          backgroundColor: message.subtype == 'success'
              ? appColors.successChip
              : appColors.errorChip,
          side: BorderSide.none,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
