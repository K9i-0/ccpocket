import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../theme/app_theme.dart';
import '../../settings/state/settings_state.dart';

class CodexUsageStreamSummary extends StatelessWidget {
  final BridgeService bridgeService;
  final UsageDisplayMode displayMode;
  final VoidCallback? onTap;

  const CodexUsageStreamSummary({
    super.key,
    required this.bridgeService,
    required this.displayMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UsageResultMessage>(
      stream: bridgeService.usageResults,
      initialData: bridgeService.lastUsageResult,
      builder: (context, snapshot) {
        final usage = _codexUsage(snapshot.data);
        if (usage == null || !usage.hasData) return const SizedBox.shrink();
        return CodexUsageSummary(
          usage: usage,
          displayMode: displayMode,
          onTap: onTap,
        );
      },
    );
  }
}

class CodexUsageSummary extends StatelessWidget {
  final UsageInfo usage;
  final UsageDisplayMode displayMode;
  final VoidCallback? onTap;

  const CodexUsageSummary({
    super.key,
    required this.usage,
    required this.displayMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = switch (displayMode) {
      UsageDisplayMode.remaining => l.usageDisplayModeRemaining,
      UsageDisplayMode.used => l.usageDisplayModeUsed,
    };
    final metrics = <Widget>[
      if (usage.fiveHour != null)
        _UsageMetric(
          key: const ValueKey('codex_usage_5h_indicator'),
          label: '5h',
          window: usage.fiveHour!,
          displayMode: displayMode,
        ),
      if (usage.sevenDay != null)
        _UsageMetric(
          key: const ValueKey('codex_usage_1w_indicator'),
          label: '1w',
          window: usage.sevenDay!,
          displayMode: displayMode,
        ),
    ];
    final semanticMetrics = <String>[
      if (usage.fiveHour != null)
        '5h ${_displayPercentage(usage.fiveHour!, displayMode).toStringAsFixed(0)}%',
      if (usage.sevenDay != null)
        '1w ${_displayPercentage(usage.sevenDay!, displayMode).toStringAsFixed(0)}%',
    ];

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: InkWell(
          key: const ValueKey('codex_usage_summary_button'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Semantics(
            container: true,
            button: onTap != null,
            excludeSemantics: true,
            label: ['Codex $label', ...semanticMetrics].join(', '),
            hint: onTap == null ? null : l.usageOpenSettingsHint,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                key: const ValueKey('codex_usage_summary'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Codex $label',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  for (final metric in metrics) ...[
                    const SizedBox(width: 8),
                    metric,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UsageMetric extends StatelessWidget {
  final String label;
  final UsageWindow window;
  final UsageDisplayMode displayMode;

  const _UsageMetric({
    super.key,
    required this.label,
    required this.window,
    required this.displayMode,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = _displayPercentage(window, displayMode);
    final color = _indicatorColor(context, percentage, displayMode);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ${percentage.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 24,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 4,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

double _displayPercentage(UsageWindow window, UsageDisplayMode displayMode) {
  final used = window.utilization.clamp(0, 100).toDouble();
  return switch (displayMode) {
    UsageDisplayMode.remaining => 100 - used,
    UsageDisplayMode.used => used,
  };
}

Color _indicatorColor(
  BuildContext context,
  double percentage,
  UsageDisplayMode displayMode,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final appColors = Theme.of(context).extension<AppColors>()!;
  return switch (displayMode) {
    UsageDisplayMode.used =>
      percentage >= 90
          ? colorScheme.error
          : percentage >= 70
          ? Colors.orange
          : appColors.statusOnline,
    UsageDisplayMode.remaining =>
      percentage <= 10
          ? colorScheme.error
          : percentage <= 30
          ? Colors.orange
          : appColors.statusOnline,
  };
}

UsageInfo? _codexUsage(UsageResultMessage? result) {
  if (result == null) return null;
  for (final usage in result.providers) {
    if (usage.provider == Provider.codex.value) return usage;
  }
  return null;
}
