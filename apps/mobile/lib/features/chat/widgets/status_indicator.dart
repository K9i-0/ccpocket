import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

/// Compact status indicator that shows only a colored icon.
/// Tap to show a tooltip with status text.
class StatusIndicator extends StatelessWidget {
  final ProcessStatus status;
  const StatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final (color, label) = switch (status) {
      ProcessStatus.starting => (appColors.statusStarting, 'Starting'),
      ProcessStatus.idle => (appColors.statusIdle, 'Idle'),
      ProcessStatus.running => (appColors.statusRunning, 'Running'),
      ProcessStatus.waitingApproval => (appColors.statusApproval, 'Approval'),
      ProcessStatus.clearing => (appColors.statusRunning, 'Clearing'),
    };

    final isAnimating = status == ProcessStatus.running ||
        status == ProcessStatus.starting ||
        status == ProcessStatus.clearing;

    return Tooltip(
      message: label,
      preferBelow: true,
      triggerMode: TooltipTriggerMode.tap,
      child: Padding(
        key: const ValueKey('status_indicator'),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isAnimating
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
