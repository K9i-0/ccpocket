import 'package:flutter/material.dart';

class CostBadge extends StatelessWidget {
  final double totalCost;
  const CostBadge({super.key, required this.totalCost});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '\$${totalCost.toStringAsFixed(4)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.secondary,
          ),
        ),
      ),
    );
  }
}
