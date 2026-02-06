import 'package:flutter/material.dart';

import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

/// Displays a summary of tool uses from a subagent (Task tool).
///
/// This bubble replaces multiple tool_result messages with a compressed
/// summary, similar to how the Claude CLI displays subagent activities.
class ToolUseSummaryBubble extends StatelessWidget {
  final ToolUseSummaryMessage message;

  const ToolUseSummaryBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bubbleMarginH,
        vertical: AppSpacing.bubbleMarginV,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subagent icon
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              size: 14,
              color: appColors.subtleText,
            ),
          ),
          const SizedBox(width: 8),
          // Summary text
          Expanded(
            child: Text(
              message.summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: appColors.subtleText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
