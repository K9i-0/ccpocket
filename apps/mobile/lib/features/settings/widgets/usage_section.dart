import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../theme/app_theme.dart';
import '../models/usage_pace.dart';
import '../state/settings_cubit.dart';
import '../state/settings_state.dart';

/// Settings セクション: Codex 利用量表示 + Claude 公式ページ導線
class UsageSection extends StatefulWidget {
  final BridgeService bridgeService;
  const UsageSection({super.key, required this.bridgeService});

  @override
  State<UsageSection> createState() => _UsageSectionState();
}

class _UsageSectionState extends State<UsageSection> {
  static const _autoRefreshCooldown = Duration(minutes: 2);

  List<UsageInfo>? _providers;
  bool _loading = false;
  StreamSubscription<UsageResultMessage>? _sub;
  StreamSubscription<BridgeConnectionState>? _connSub;
  DateTime? _lastFetchAt;

  UsageInfo? get _codexInfo {
    final providers = _providers;
    if (providers == null) return null;
    for (final info in providers) {
      if (info.provider == Provider.codex.value) {
        return info;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final cached = widget.bridgeService.lastUsageResult;
    if (widget.bridgeService.isConnected && cached != null) {
      _providers = cached.providers;
    }
    _sub = widget.bridgeService.usageResults.listen((msg) {
      if (mounted) {
        setState(() {
          _providers = msg.providers;
          _loading = false;
        });
      }
    });
    _connSub = widget.bridgeService.connectionStatus.listen((state) {
      if (mounted && state == BridgeConnectionState.connected) {
        _fetchUsage(onlyIfMissing: true);
      }
    });
    _fetchUsage(onlyIfMissing: true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  void _fetchUsage({bool onlyIfMissing = false, bool force = false}) {
    if (!widget.bridgeService.isConnected) return;
    if (_loading) return;
    if (!force && onlyIfMissing && _providers != null) return;

    final now = DateTime.now();
    if (!force &&
        _lastFetchAt != null &&
        now.difference(_lastFetchAt!) < _autoRefreshCooldown) {
      return;
    }

    _lastFetchAt = now;
    setState(() => _loading = true);
    widget.bridgeService.requestUsage();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final codexInfo = _codexInfo;
    final usageDisplayMode = context.select(
      (SettingsCubit cubit) => cubit.state.usageDisplayMode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Text(
                l.settingsUsageSectionTitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _UsageDisplayModeButton(mode: usageDisplayMode),
              const SizedBox(width: 8),
              if (_loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onSurfaceVariant,
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _fetchUsage(force: true),
                  child: Icon(
                    Icons.refresh,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (codexInfo != null)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            key: const ValueKey('codex_usage_card'),
            child: _ProviderUsageTile(
              info: codexInfo,
              displayMode: usageDisplayMode,
            ),
          )
        else if (_providers == null)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            key: const ValueKey('codex_usage_card'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : Text(
                        AppLocalizations.of(context).usageFetchFailed,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
          )
        else
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            key: const ValueKey('codex_usage_card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.settingsUsageNoCodexData,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const _ClaudeUsageLinksCard(),
      ],
    );
  }
}

class _UsageDisplayModeButton extends StatelessWidget {
  final UsageDisplayMode mode;

  const _UsageDisplayModeButton({required this.mode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final label = switch (mode) {
      UsageDisplayMode.remaining => l.usageDisplayModeRemaining,
      UsageDisplayMode.used => l.usageDisplayModeUsed,
    };

    return Tooltip(
      message: label,
      child: TextButton(
        key: const ValueKey('usage_display_mode_button'),
        onPressed: context.read<SettingsCubit>().toggleUsageDisplayMode,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          foregroundColor: cs.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ClaudeUsageLinksCard extends StatelessWidget {
  const _ClaudeUsageLinksCard();

  Future<void> _openExternalUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.smart_toy_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                const Text(
                  'Claude',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l.settingsClaudeUsageDescription,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
          ListTile(
            key: const ValueKey('claude_api_billing_tile'),
            leading: Icon(Icons.receipt_long_outlined, color: cs.primary),
            title: Text(l.settingsClaudeApiBilling),
            subtitle: const Text('platform.claude.com/settings/billing'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openExternalUrl(AppConstants.claudeApiBillingUrl),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: cs.outlineVariant,
          ),
          ListTile(
            key: const ValueKey('claude_subscription_usage_tile'),
            leading: Icon(Icons.query_stats_outlined, color: cs.primary),
            title: Text(l.settingsClaudeSubscriptionUsage),
            subtitle: const Text('claude.ai/settings/usage'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () =>
                _openExternalUrl(AppConstants.claudeSubscriptionUsageUrl),
          ),
        ],
      ),
    );
  }
}

class _ProviderUsageTile extends StatelessWidget {
  final UsageInfo info;
  final UsageDisplayMode displayMode;
  const _ProviderUsageTile({required this.info, required this.displayMode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final providerLabel = info.provider == 'claude' ? 'Claude' : 'Codex';
    final providerIcon = info.provider == 'claude'
        ? Icons.smart_toy_outlined
        : Icons.code;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(providerIcon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                providerLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (info.hasError)
            Text(
              info.error!,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            )
          else ...[
            if (info.fiveHour != null)
              _UsageBar(
                label: AppLocalizations.of(context).usageFiveHour,
                window: info.fiveHour!,
                windowDuration: const Duration(hours: 5),
                displayMode: displayMode,
              ),
            if (info.fiveHour != null && info.sevenDay != null)
              const SizedBox(height: 10),
            if (info.sevenDay != null)
              _UsageBar(
                label: AppLocalizations.of(context).usageSevenDay,
                window: info.sevenDay!,
                windowDuration: const Duration(days: 7),
                displayMode: displayMode,
              ),
          ],
        ],
      ),
    );
  }
}

class _UsageBar extends StatefulWidget {
  final String label;
  final UsageWindow window;
  final Duration windowDuration;
  final UsageDisplayMode displayMode;
  const _UsageBar({
    required this.label,
    required this.window,
    required this.windowDuration,
    required this.displayMode,
  });

  @override
  State<_UsageBar> createState() => _UsageBarState();
}

class _UsageBarState extends State<_UsageBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _oldPct;
  late double _newPct;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _oldPct = _targetPct;
    _newPct = _oldPct;
    // Show initial value immediately without animation
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _UsageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = _targetPct;
    if (incoming != _newPct) {
      _oldPct = _currentPct;
      _newPct = incoming;
      _controller
        ..reset()
        ..forward();
    }
  }

  double get _currentPct {
    final curved = Curves.easeInOut.transform(_controller.value);
    return _oldPct + (_newPct - _oldPct) * curved;
  }

  double get _targetPct {
    final used = widget.window.utilization.clamp(0, 100).toDouble();
    return switch (widget.displayMode) {
      UsageDisplayMode.remaining => 100 - used,
      UsageDisplayMode.used => used,
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final resetDt = widget.window.resetsAtDateTime;
    final resetTimeStr = resetDt != null ? _formatResetTime(resetDt) : null;
    final resetDisplay = resetDt != null
        ? (resetTimeStr != null
              ? l.usageResetAt(resetTimeStr)
              : l.usageAlreadyReset)
        : null;
    final pace = UsagePace.calculate(
      window: widget.window,
      windowDuration: widget.windowDuration,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pct = _currentPct;
        final barColor = _barColor(cs, pct);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.label,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: barColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            if (resetDisplay != null) ...[
              const SizedBox(height: 2),
              Text(
                resetDisplay,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
            if (pace?.isReliable ?? false) ...[
              const SizedBox(height: 6),
              _UsagePaceIndicator(pace: pace!),
            ],
          ],
        );
      },
    );
  }

  Color _barColor(ColorScheme cs, double pct) {
    return switch (widget.displayMode) {
      UsageDisplayMode.used =>
        pct >= 90
            ? cs.error
            : pct >= 70
            ? Colors.orange
            : cs.primary,
      UsageDisplayMode.remaining =>
        pct <= 10
            ? cs.error
            : pct <= 30
            ? Colors.orange
            : cs.primary,
    };
  }

  String? _formatResetTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = local.difference(now);

    if (diff.isNegative) return null;

    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes % 60;

    final timeStr =
        '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (days > 0) {
      return '$timeStr (${days}d${hours > 0 ? '${hours}h' : ''}${minutes > 0 ? '${minutes}m' : ''})';
    }
    if (hours > 0) {
      return '$timeStr (${hours}h${minutes > 0 ? '${minutes}m' : ''})';
    }
    return '$timeStr (${minutes}m)';
  }
}

class _UsagePaceIndicator extends StatelessWidget {
  final UsagePace pace;

  const _UsagePaceIndicator({required this.pace});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>();
    final color = _paceColor(cs, appColors, pace.stage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_paceIcon(pace.stage), size: 14, color: color),
                  const SizedBox(width: 5),
                  Text(
                    _paceStageLabel(l, pace.stage),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
              Text(
                l.usagePaceExpected(pace.expectedUsedPercent.round()),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _projectionLabel(l, pace),
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _paceStageLabel(AppLocalizations l, UsagePaceStage stage) {
  return switch (stage) {
    UsagePaceStage.onTrack => l.usagePaceOnTrack,
    UsagePaceStage.slightlyAhead => l.usagePaceSlightlyAhead,
    UsagePaceStage.ahead => l.usagePaceAhead,
    UsagePaceStage.farAhead => l.usagePaceFarAhead,
    UsagePaceStage.slightlyBehind => l.usagePaceSlightlyBehind,
    UsagePaceStage.behind => l.usagePaceBehind,
    UsagePaceStage.farBehind => l.usagePaceFarBehind,
  };
}

String _projectionLabel(AppLocalizations l, UsagePace pace) {
  if (pace.actualUsedPercent >= 100) return l.usagePaceAtLimit;
  if (pace.willLastToReset) return l.usagePaceWillLast;
  final timeUntilLimit = pace.timeUntilLimit;
  if (timeUntilLimit == null) return l.usagePaceWillLast;
  return l.usagePaceRunsOutIn(_formatCompactDuration(timeUntilLimit));
}

String _formatCompactDuration(Duration duration) {
  if (duration < const Duration(minutes: 1)) return '<1m';
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  if (days > 0) return '${days}d${hours > 0 ? ' ${hours}h' : ''}';
  if (duration.inHours > 0) {
    return '${duration.inHours}h${minutes > 0 ? ' ${minutes}m' : ''}';
  }
  return '${duration.inMinutes}m';
}

Color _paceColor(ColorScheme cs, AppColors? appColors, UsagePaceStage stage) {
  return switch (stage) {
    UsagePaceStage.onTrack => appColors?.statusOnline ?? cs.secondary,
    UsagePaceStage.slightlyAhead => cs.tertiary,
    UsagePaceStage.ahead || UsagePaceStage.farAhead => cs.error,
    UsagePaceStage.slightlyBehind ||
    UsagePaceStage.behind ||
    UsagePaceStage.farBehind => cs.secondary,
  };
}

IconData _paceIcon(UsagePaceStage stage) {
  return switch (stage) {
    UsagePaceStage.onTrack => Icons.check_circle_outline,
    UsagePaceStage.slightlyAhead ||
    UsagePaceStage.ahead ||
    UsagePaceStage.farAhead => Icons.trending_up,
    UsagePaceStage.slightlyBehind ||
    UsagePaceStage.behind ||
    UsagePaceStage.farBehind => Icons.trending_down,
  };
}
