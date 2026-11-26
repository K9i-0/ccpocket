import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/file_peek/file_path_syntax.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../markdown/ccpocket_markdown.dart';

class ResultChip extends StatelessWidget {
  final ResultMessage message;
  final FilePathTapCallback? onFileTap;
  final bool showSuccessResultText;
  final String? documentId;
  final int documentOrder;

  const ResultChip({
    super.key,
    required this.message,
    this.onFileTap,
    this.showSuccessResultText = false,
    this.documentId,
    this.documentOrder = 0,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final fileSuffixes = onFileTap != null
        ? FilePathSyntax.cachedSuffixSet(context.watch<FileListCubit>().state)
        : const <String>{};
    final parts = <String>[];
    if (message.cost != null) {
      parts.add('\$${message.cost!.toStringAsFixed(4)}');
    }
    if (message.duration != null) {
      parts.add('${(message.duration! / 1000).toStringAsFixed(1)}s');
    }
    if (message.inputTokens != null ||
        message.outputTokens != null ||
        (message.thoughtTokens != null && message.thoughtTokens! > 0)) {
      final inTok = message.inputTokens ?? 0;
      final outTok = message.outputTokens ?? 0;
      final thoughtPart =
          message.thoughtTokens != null && message.thoughtTokens! > 0
          ? '/${message.thoughtTokens}thought'
          : '';
      parts.add('${inTok}in/${outTok}out$thoughtPart tok');
    }
    if (message.cachedInputTokens != null && message.cachedInputTokens! > 0) {
      parts.add('${message.cachedInputTokens} cached');
    }
    final String label;
    final _ResultKind kind;
    switch (message.subtype) {
      case 'success':
        final truncated = message.stopReason == 'max_tokens'
            ? ' [truncated]'
            : '';
        label =
            'Done${parts.isNotEmpty ? ' (${parts.join(", ")})' : ''}$truncated';
        kind = _ResultKind.success;
      // Codex reports a user interrupt as an `interrupted` turn.
      case 'stopped' || 'interrupted':
        label = 'Stopped';
        kind = _ResultKind.stopped;
      default:
        label = 'Error: ${message.error ?? 'unknown'}';
        kind = _ResultKind.error;
    }

    // Success text is a fallback when its assistant message is missing.
    final resultText = message.result;
    final showResultText =
        (message.subtype != 'success' || showSuccessResultText) &&
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
              child: CcpocketMarkdown(
                data: resultText,
                documentId: documentId,
                documentOrder: documentOrder,
                onFileTap: onFileTap,
                knownPathSuffixes: fileSuffixes,
                useChatLinkHandler: true,
              ),
            ),
          ),
        _ResultMetadataRow(label: label, kind: kind),
      ],
    );
  }
}

enum _ResultKind { success, stopped, error }

class _ResultMetadataRow extends StatelessWidget {
  final String label;
  final _ResultKind kind;

  const _ResultMetadataRow({required this.label, required this.kind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;

    if (kind == _ResultKind.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.bubbleMarginH,
          vertical: 6,
        ),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: appColors.errorBubble,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: appColors.errorBubbleBorder.withValues(alpha: 0.45),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 13,
                    color: appColors.errorText,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: appColors.errorText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final hairlineColor = cs.outlineVariant.withValues(alpha: 0.75);
    final mutedColor = appColors.subtleText;
    final icon = kind == _ResultKind.success
        ? Icons.check_rounded
        : Icons.stop_circle_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bubbleMarginH,
        vertical: 6,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              child: Divider(height: 1, color: hairlineColor),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 12, color: mutedColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: mutedColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 20,
              child: Divider(height: 1, color: hairlineColor),
            ),
          ],
        ),
      ),
    );
  }
}
