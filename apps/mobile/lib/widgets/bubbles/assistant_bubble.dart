import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/markdown_style.dart';

class AssistantBubble extends StatelessWidget {
  final AssistantServerMessage message;
  const AssistantBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final content in message.message.content)
          switch (content) {
            TextContent(:final text) => Align(
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
                  maxWidth: MediaQuery.of(context).size.width *
                      AppSpacing.maxBubbleWidthFraction,
                ),
                decoration: BoxDecoration(
                  color: appColors.assistantBubble,
                  borderRadius: AppSpacing.assistantBubbleBorderRadius,
                ),
                child: MarkdownBody(
                  data: text,
                  selectable: true,
                  styleSheet: buildMarkdownStyle(context),
                ),
              ),
            ),
            ToolUseContent(:final name, :final input) => ToolUseTile(
              name: name,
              input: input,
            ),
          },
      ],
    );
  }
}

class ToolUseTile extends StatelessWidget {
  final String name;
  final Map<String, dynamic> input;
  const ToolUseTile({super.key, required this.name, required this.input});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final inputStr = const JsonEncoder.withIndent('  ').convert(input);
    final preview = inputStr.length > 200
        ? '${inputStr.substring(0, 200)}...'
        : inputStr;
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: '$name\n$inputStr'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.bubbleMarginV,
          horizontal: AppSpacing.bubbleMarginH,
        ),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: appColors.toolBubble,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: appColors.toolBubbleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: appColors.toolIcon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.build, size: 14, color: appColors.toolIcon),
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              preview,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: appColors.subtleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
