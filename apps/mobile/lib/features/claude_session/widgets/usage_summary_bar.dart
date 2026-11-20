import 'package:material_ui/material_ui.dart';

/// Compact single-line usage summary shown above the chat.
///
/// Horizontally scrollable so it never wraps, keeping the message list visible.
class UsageSummaryBar extends StatelessWidget {
  final double totalCost;
  final Duration? totalDuration;
  final int inputTokens;
  final int cachedInputTokens;
  final int outputTokens;
  final int thoughtTokens;
  final int toolCalls;
  final int fileEdits;

  /// Tokens in the context window and its size, where the agent reports them
  /// (Antigravity).
  final int? contextUsed;
  final int? contextSize;

  const UsageSummaryBar({
    super.key,
    required this.totalCost,
    required this.totalDuration,
    required this.inputTokens,
    required this.cachedInputTokens,
    required this.outputTokens,
    this.thoughtTokens = 0,
    required this.toolCalls,
    required this.fileEdits,
    this.contextUsed,
    this.contextSize,
  });

  // Nothing is in the window before the first turn; `0%` says nothing.
  bool get _hasContext =>
      (contextUsed ?? 0) > 0 && contextSize != null && contextSize! > 0;

  bool get _hasCost => totalCost > 0;
  bool get _hasDuration =>
      totalDuration != null && totalDuration! > Duration.zero;
  bool get _hasTokenUsage =>
      inputTokens > 0 ||
      cachedInputTokens > 0 ||
      outputTokens > 0 ||
      thoughtTokens > 0;
  bool get _hasToolUsage => toolCalls > 0 || fileEdits > 0;

  @override
  Widget build(BuildContext context) {
    if (!_hasCost && !_hasDuration && !_hasTokenUsage && !_hasContext) {
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
            thoughtTokens: thoughtTokens,
          ),
        ),
      );
    }
    if (_hasContext) {
      items.add(
        _UsageStat(
          key: const ValueKey('usage_summary_context'),
          icon: Icons.donut_large_outlined,
          text: formatContextUsage(contextUsed!, contextSize!),
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

    return SizedBox(
      key: const ValueKey('usage_summary_bar'),
      height: 22,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  /// `ctx 12% (126k / 1.0M)`: share of the context window in use.
  static String formatContextUsage(int used, int size) {
    final percent = used <= 0 ? 0 : (used / size * 100).round().clamp(1, 100);
    return 'ctx $percent% (${_formatCompactNumber(used)} / '
        '${_formatCompactNumber(size)})';
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
    int thoughtTokens = 0,
  }) {
    final effectiveInput = inputTokens + cachedInputTokens;
    final inText = _formatCompactNumber(effectiveInput);
    final outText = _formatCompactNumber(outputTokens);
    final inPart = cachedInputTokens > 0
        ? 'in $inText(${_formatCompactNumber(cachedInputTokens)})'
        : 'in $inText';
    final thoughtPart = thoughtTokens > 0
        ? ' / thought ${_formatCompactNumber(thoughtTokens)}'
        : '';
    return '$inPart / out $outText$thoughtPart';
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

  const _UsageStat({super.key, required this.icon, required this.text});

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
