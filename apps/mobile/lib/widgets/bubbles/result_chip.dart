import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../features/file_peek/file_path_syntax.dart';
import '../../features/file_peek/markdown_link_handler.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/markdown_style.dart';

class ResultChip extends StatelessWidget {
  final ResultMessage message;
  final FilePathTapCallback? onFileTap;

  const ResultChip({super.key, required this.message, this.onFileTap});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final fileSuffixes = onFileTap != null
        ? FilePathSyntax.buildSuffixSet(context.watch<FileListCubit>().state)
        : const <String>{};
    final parts = <String>[];
    if (message.cost != null) {
      parts.add('\$${message.cost!.toStringAsFixed(4)}');
    }
    if (message.duration != null) {
      parts.add('${(message.duration! / 1000).toStringAsFixed(1)}s');
    }
    if (message.inputTokens != null || message.outputTokens != null) {
      final inTok = message.inputTokens ?? 0;
      final outTok = message.outputTokens ?? 0;
      parts.add('${inTok}in/${outTok}out tok');
    }
    if (message.cachedInputTokens != null && message.cachedInputTokens! > 0) {
      parts.add('${message.cachedInputTokens} cached');
    }
    final String label;
    final Color chipColor;
    switch (message.subtype) {
      case 'success':
        final truncated = message.stopReason == 'max_tokens'
            ? ' [truncated]'
            : '';
        label =
            'Done${parts.isNotEmpty ? ' (${parts.join(", ")})' : ''}$truncated';
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
                onTapLink: buildChatMarkdownLinkHandler(
                  context,
                  onFileTap: onFileTap,
                  knownPathSuffixes: fileSuffixes,
                ),
                inlineSyntaxes: [
                  if (onFileTap != null) ...[
                    FilePathSyntax(knownPathSuffixes: fileSuffixes),
                    BareFilePathSyntax(knownPathSuffixes: fileSuffixes),
                  ],
                  ...colorCodeInlineSyntaxes,
                ],
                builders: {
                  if (onFileTap != null)
                    'filePath': FilePathBuilder(onTap: onFileTap),
                  ...markdownBuilders,
                },
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
