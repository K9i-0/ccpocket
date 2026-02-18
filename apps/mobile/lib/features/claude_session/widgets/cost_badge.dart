import 'package:flutter/material.dart';

/// Displays session cost and optionally message count with context indicator.
class CostBadge extends StatelessWidget {
  final double totalCost;

  /// Optional message count for context usage estimation.
  final int? messageCount;

  /// Estimated max messages before context limit (~200k tokens ≈ ~150 messages).
  static const int estimatedMaxMessages = 150;

  const CostBadge({super.key, required this.totalCost, this.messageCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Calculate context usage percentage if message count available
    final contextPercent = messageCount != null
        ? (messageCount! / estimatedMaxMessages).clamp(0.0, 1.0)
        : null;

    // Determine warning level
    final isWarning = contextPercent != null && contextPercent > 0.7;
    final isCritical = contextPercent != null && contextPercent > 0.9;

    final badgeColor = isCritical
        ? cs.error
        : isWarning
        ? cs.tertiary
        : cs.secondary;

    return Tooltip(
      message: messageCount != null
          ? '$messageCount messages (~${(contextPercent! * 100).toInt()}% context)'
          : 'Session cost',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: isCritical
                ? Border.all(color: badgeColor.withValues(alpha: 0.5), width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Context usage indicator
              if (contextPercent != null) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: contextPercent,
                        strokeWidth: 2,
                        backgroundColor: badgeColor.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(badgeColor),
                      ),
                      if (isCritical)
                        Icon(Icons.warning_rounded, size: 8, color: badgeColor),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],
              // Cost text
              Text(
                '\$${totalCost.toStringAsFixed(4)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
