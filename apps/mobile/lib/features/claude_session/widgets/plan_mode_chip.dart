import 'package:flutter/material.dart';

class PlanModeChip extends StatelessWidget {
  const PlanModeChip({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: cs.tertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment, size: 11, color: cs.tertiary),
          const SizedBox(width: 3),
          Text(
            'Plan',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cs.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
