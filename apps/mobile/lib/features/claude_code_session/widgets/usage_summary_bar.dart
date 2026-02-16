import 'package:flutter/material.dart';

/// Compact single-line usage summary shown above the chat.
///
/// Horizontally scrollable so it never wraps, keeping the message list visible.
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

    final items = <Widget>[];

    if (_hasCost) {
      items.add(
        _UsageStat(
          icon: Icons.attach_money,
          text: '\$${totalCost.toStringAsFixed(4)}',
        ),
      );
    }
    if (_hasDuration) {
      items.add(
        _UsageStat(
          icon: Icons.timer_outlined,
          text: _formatDuration(totalDuration!),
        ),
      );
    }
    if (_hasTokenUsage) {
      items.add(
        _UsageStat(
          icon: Icons.data_usage_outlined,
          text: _formatTokenSummary(
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            outputTokens: outputTokens,
          ),
        ),
      );
    }
    if (_hasToolUsage) {
      items.add(
        _UsageStat(
          icon: Icons.build_circle_outlined,
          text: _formatToolSummary(toolCalls: toolCalls, fileEdits: fileEdits),
        ),
      );
    }

    // Build separator-interleaved list
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '·',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }
      children.add(items[i]);
    }

    return Container(
      key: const ValueKey('usage_summary_bar'),
      height: 28,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
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
      final cacheText = _formatCompactNumber(cachedInputTokens);
      return 'in $inText($cacheText) / out $outText';
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
        Icon(icon, size: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.8),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
