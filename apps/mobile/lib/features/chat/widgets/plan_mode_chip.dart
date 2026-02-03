import 'package:flutter/material.dart';

class PlanModeChip extends StatelessWidget {
  const PlanModeChip({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.tertiary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment, size: 12, color: cs.tertiary),
            const SizedBox(width: 4),
            Text(
              'Plan',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
