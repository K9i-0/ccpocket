import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/markdown_style.dart';

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

    // Only show result text for non-success cases (errors, stopped).
    // For success, the text is already displayed by AssistantBubble.
    final resultText = message.result;
    final showResultText =
        message.subtype != 'success' &&
        resultText != null &&
        resultText.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showResultText)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(
                vertical: AppSpacing.bubbleMarginV,
                horizontal: AppSpacing.bubbleMarginH,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.bubblePaddingV,
                horizontal: AppSpacing.bubblePaddingH,
              ),
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width *
                    AppSpacing.maxBubbleWidthFraction,
              ),
              decoration: BoxDecoration(
                color: appColors.assistantBubble,
                borderRadius: AppSpacing.assistantBubbleBorderRadius,
              ),
              child: MarkdownBody(
                data: resultText,
                selectable: true,
                styleSheet: buildMarkdownStyle(context),
                onTapLink: handleMarkdownLink,
              ),
            ),
          ),
        Center(
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
        ),
      ],
    );
  }
}
