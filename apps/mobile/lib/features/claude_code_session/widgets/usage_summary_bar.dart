import 'package:flutter/material.dart';

/// Compact usage summary row shown in chat.
class UsageSummaryBar extends StatelessWidget {
  final double totalCost;
  final Duration? totalDuration;
  final int inputTokens;
  final int cachedInputTokens;
  final int outputTokens;
  final int toolCalls;
  final int fileEdits;

  const UsageSummaryBar({
    super.key,
    required this.totalCost,
    required this.totalDuration,
    required this.inputTokens,
    required this.cachedInputTokens,
    required this.outputTokens,
    required this.toolCalls,
    required this.fileEdits,
  });

  bool get _hasCost => totalCost > 0;
  bool get _hasDuration =>
      totalDuration != null && totalDuration! > Duration.zero;
  bool get _hasTokenUsage =>
      inputTokens > 0 || cachedInputTokens > 0 || outputTokens > 0;
  bool get _hasToolUsage => toolCalls > 0 || fileEdits > 0;

  @override
  Widget build(BuildContext context) {
    if (!_hasCost && !_hasDuration && !_hasTokenUsage) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('usage_summary_bar'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_hasCost)
            _UsageStat(
              icon: Icons.attach_money,
              text: '\$${totalCost.toStringAsFixed(4)}',
            ),
          if (_hasDuration)
            _UsageStat(
              icon: Icons.timer_outlined,
              text: _formatDuration(totalDuration!),
            ),
          if (_hasTokenUsage)
            _UsageStat(
              icon: Icons.data_usage_outlined,
              text: _formatTokenSummary(
                inputTokens: inputTokens,
                cachedInputTokens: cachedInputTokens,
                outputTokens: outputTokens,
              ),
            ),
          if (_hasToolUsage)
            _UsageStat(
              icon: Icons.build_circle_outlined,
              text: _formatToolSummary(
                toolCalls: toolCalls,
                fileEdits: fileEdits,
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    if (duration.inMinutes >= 1) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
    return '${duration.inSeconds}s';
  }

  static String _formatTokenSummary({
    required int inputTokens,
    required int cachedInputTokens,
    required int outputTokens,
  }) {
    final effectiveInput = inputTokens + cachedInputTokens;
    final inText = _formatCompactNumber(effectiveInput);
    final outText = _formatCompactNumber(outputTokens);
    if (cachedInputTokens > 0) {
      return 'in $inText (cache ${_formatCompactNumber(cachedInputTokens)}) / out $outText';
    }
    return 'in $inText / out $outText';
  }

  static String _formatToolSummary({
    required int toolCalls,
    required int fileEdits,
  }) {
    if (toolCalls <= 0) {
      return 'edits $fileEdits';
    }
    if (fileEdits <= 0) {
      return 'tools $toolCalls';
    }
    return 'tools $toolCalls / edits $fileEdits';
  }

  static String _formatCompactNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }
}

class _UsageStat extends StatelessWidget {
  final IconData icon;
  final String text;

  const _UsageStat({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
