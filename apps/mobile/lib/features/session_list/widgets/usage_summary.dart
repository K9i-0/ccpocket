import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../theme/app_theme.dart';
import '../../settings/state/settings_state.dart';

/// Compact plan usage for the Running header, fed by the Bridge usage stream.
class UsageStreamSummary extends StatelessWidget {
  final BridgeService bridgeService;
  final UsageDisplayMode displayMode;
  final VoidCallback? onTap;

  const UsageStreamSummary({
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
        final providers = usageSummaryProviders(
          snapshot.data?.providers ?? const [],
        );
        if (providers.isEmpty) return const SizedBox.shrink();
        return UsageSummary(
          providers: providers,
          displayMode: displayMode,
          onTap: onTap,
        );
      },
    );
  }
}

/// Providers with usage data, in display order (Claude first, then Codex).
List<UsageInfo> usageSummaryProviders(List<UsageInfo> providers) {
  return [
    for (final provider in Provider.values)
      ...providers.where(
        (usage) => usage.provider == provider.value && usage.hasData,
      ),
  ];
}

/// Compact usage summary. A single provider renders on one line
/// ("Codex Remaining 5h 68% ▬ 1w 42% ▬"). When several providers have data,
/// the display mode label is shown once and each provider gets its own smaller
/// line, stacked vertically and right-aligned so the bars line up.
class UsageSummary extends StatelessWidget {
  final List<UsageInfo> providers;
  final UsageDisplayMode displayMode;
  final VoidCallback? onTap;

  const UsageSummary({
    super.key,
    required this.providers,
    required this.displayMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final modeLabel = switch (displayMode) {
      UsageDisplayMode.remaining => l.usageDisplayModeRemaining,
      UsageDisplayMode.used => l.usageDisplayModeUsed,
    };
    final visible = usageSummaryProviders(providers);
    if (visible.isEmpty) return const SizedBox.shrink();
    final stacked = visible.length > 1;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    final semanticsLabel = stacked
        ? [
            modeLabel,
            for (final usage in visible)
              [
                _providerLabel(usage),
                ..._semanticMetrics(usage, displayMode),
              ].join(' '),
          ].join(', ')
        : [
            '${_providerLabel(visible.single)} $modeLabel',
            ..._semanticMetrics(visible.single, displayMode),
          ].join(', ');

    final Widget content = stacked
        ? Row(
            key: const ValueKey('usage_summary'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(modeLabel, style: labelStyle),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (index, usage) in visible.indexed) ...[
                    if (index > 0) const SizedBox(height: 2),
                    _ProviderUsageLine(
                      key: ValueKey('usage_summary_${usage.provider}'),
                      usage: usage,
                      displayMode: displayMode,
                      label: _providerLabel(usage),
                      fontSize: 10,
                    ),
                  ],
                ],
              ),
            ],
          )
        : _ProviderUsageLine(
            key: const ValueKey('usage_summary'),
            usage: visible.single,
            displayMode: displayMode,
            label: '${_providerLabel(visible.single)} $modeLabel',
            fontSize: 11,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('usage_summary_button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Semantics(
          container: true,
          button: onTap != null,
          excludeSemantics: true,
          label: semanticsLabel,
          hint: onTap == null ? null : l.usageOpenSettingsHint,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            // Keep single-line content aligned with the header's visual row
            // while the surrounding InkWell fills its 44px tap target. The
            // stacked layout is centered vertically to use the full height.
            alignment: stacked
                ? Alignment.centerRight
                : const Alignment(1, -0.15),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _ProviderUsageLine extends StatelessWidget {
  final UsageInfo usage;
  final UsageDisplayMode displayMode;
  final String label;
  final double fontSize;

  const _ProviderUsageLine({
    super.key,
    required this.usage,
    required this.displayMode,
    required this.label,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (usage.fiveHour != null) ...[
          const SizedBox(width: 8),
          _UsageMetric(
            key: ValueKey('${usage.provider}_usage_5h_indicator'),
            label: '5h',
            window: usage.fiveHour!,
            displayMode: displayMode,
            fontSize: fontSize,
          ),
        ],
        if (usage.sevenDay != null) ...[
          const SizedBox(width: 8),
          _UsageMetric(
            key: ValueKey('${usage.provider}_usage_1w_indicator'),
            label: '1w',
            window: usage.sevenDay!,
            displayMode: displayMode,
            fontSize: fontSize,
          ),
        ],
      ],
    );
  }
}

class _UsageMetric extends StatelessWidget {
  final String label;
  final UsageWindow window;
  final UsageDisplayMode displayMode;
  final double fontSize;

  const _UsageMetric({
    super.key,
    required this.label,
    required this.window,
    required this.displayMode,
    required this.fontSize,
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
            fontSize: fontSize,
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

String _providerLabel(UsageInfo usage) {
  for (final provider in Provider.values) {
    if (provider.value == usage.provider) return provider.label;
  }
  return usage.provider;
}

List<String> _semanticMetrics(
  UsageInfo usage,
  UsageDisplayMode displayMode,
) => [
  if (usage.fiveHour != null)
    '5h ${_displayPercentage(usage.fiveHour!, displayMode).toStringAsFixed(0)}%',
  if (usage.sevenDay != null)
    '1w ${_displayPercentage(usage.sevenDay!, displayMode).toStringAsFixed(0)}%',
];

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
