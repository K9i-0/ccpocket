import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';

/// Settings セクション: Claude Code / Codex の定額プラン利用量表示
class UsageSection extends StatefulWidget {
  final BridgeService bridgeService;
  const UsageSection({super.key, required this.bridgeService});

  @override
  State<UsageSection> createState() => _UsageSectionState();
}

class _UsageSectionState extends State<UsageSection> {
  List<UsageInfo>? _providers;
  bool _loading = false;
  StreamSubscription<UsageResultMessage>? _sub;
  StreamSubscription<BridgeConnectionState>? _connSub;

  @override
  void initState() {
    super.initState();
    // Show cached data immediately if available
    final cached = widget.bridgeService.lastUsageResult;
    if (cached != null) {
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
        _fetchUsage();
      }
    });
    _fetchUsage();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  void _fetchUsage() {
    if (!widget.bridgeService.isConnected) return;
    setState(() => _loading = true);
    widget.bridgeService.requestUsage();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isConnected = widget.bridgeService.isConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Text(
                'USAGE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (_loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onSurfaceVariant,
                  ),
                )
              else if (isConnected)
                GestureDetector(
                  onTap: _fetchUsage,
                  child: Icon(
                    Icons.refresh,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (!isConnected)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).usageConnectToView,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_providers == null)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
            child: Column(
              children: [
                for (var i = 0; i < _providers!.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                  _ProviderUsageTile(info: _providers![i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ProviderUsageTile extends StatelessWidget {
  final UsageInfo info;
  const _ProviderUsageTile({required this.info});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final providerLabel = info.provider == 'claude' ? 'Claude Code' : 'Codex';
    final providerIcon = info.provider == 'claude'
        ? Icons.auto_awesome
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
              ),
            if (info.fiveHour != null && info.sevenDay != null)
              const SizedBox(height: 10),
            if (info.sevenDay != null)
              _UsageBar(
                label: AppLocalizations.of(context).usageSevenDay,
                window: info.sevenDay!,
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
  const _UsageBar({required this.label, required this.window});

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
    _oldPct = widget.window.utilization.clamp(0, 100).toDouble();
    _newPct = _oldPct;
    // Show initial value immediately without animation
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _UsageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.window.utilization.clamp(0, 100).toDouble();
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pct = _currentPct;
        final barColor = pct >= 90
            ? cs.error
            : pct >= 70
            ? Colors.orange
            : cs.primary;

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
          ],
        );
      },
    );
  }

  String? _formatResetTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = local.difference(now);

    if (diff.isNegative) return null;

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    final timeStr =
        '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (hours > 0) {
      return '$timeStr (${hours}h${minutes > 0 ? ' ${minutes}m' : ''})';
    }
    return '$timeStr (${minutes}m)';
  }
}
