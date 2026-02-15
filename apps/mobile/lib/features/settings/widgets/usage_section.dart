import 'dart:async';

import 'package:flutter/material.dart';

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
                      'Bridge に接続すると利用量を表示できます',
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
                        '取得に失敗しました',
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
              _UsageBar(label: '5時間', window: info.fiveHour!),
            if (info.fiveHour != null && info.sevenDay != null)
              const SizedBox(height: 10),
            if (info.sevenDay != null)
              _UsageBar(label: '7日間', window: info.sevenDay!),
          ],
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final UsageWindow window;
  const _UsageBar({required this.label, required this.window});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = window.utilization.clamp(0, 100).toDouble();
    final resetDt = window.resetsAtDateTime;
    final resetText = resetDt != null ? _formatResetTime(resetDt) : '';

    // Color based on utilization level
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
              label,
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
        if (resetText.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'リセット: $resetText',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  String _formatResetTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = local.difference(now);

    if (diff.isNegative) return 'リセット済み';

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
