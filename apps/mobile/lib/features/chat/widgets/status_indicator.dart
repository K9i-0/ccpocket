import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

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
    };
    return Padding(
      key: const ValueKey('status_indicator'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow:
                    (status == ProcessStatus.running ||
                        status == ProcessStatus.starting)
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
