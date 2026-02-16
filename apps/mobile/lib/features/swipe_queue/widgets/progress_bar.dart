import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Displays the progress of processing approval items in the queue.
///
/// Shows an animated progress bar, item count, and combo streak indicator.
class QueueProgressBar extends StatelessWidget {
  final int processed;
  final int total;
  final int streak;

  const QueueProgressBar({
    super.key,
    required this.processed,
    required this.total,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final progress = total > 0 ? processed / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$processed / $total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: appColors.subtleText,
                ),
              ),
              const Spacer(),
              if (streak >= 2)
                _buildStreakBadge(cs, streak)
              else
                // Placeholder to prevent layout shift
                const SizedBox(height: 28),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            // Animated progress bar — smoothly grows on each card processed
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, animatedProgress, _) {
                return LinearProgressIndicator(
                  value: animatedProgress,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    streak >= 5
                        ? cs.primary
                        : streak >= 3
                        ? cs.secondary
                        : cs.primary.withValues(alpha: 0.7),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBadge(ColorScheme cs, int streak) {
    final color = streak >= 5 ? cs.primary : cs.secondary;
    return TweenAnimationBuilder<double>(
      // ValueKey ensures the animation re-triggers on each streak change
      key: ValueKey(streak),
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              streak >= 5 ? '\u{1F525}' : '\u{26A1}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Text(
              '$streak streak',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
