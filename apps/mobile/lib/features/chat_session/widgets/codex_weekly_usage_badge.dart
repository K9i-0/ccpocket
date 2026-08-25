import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';

/// Compact remaining-quota indicator for Codex chat app bars.
class CodexWeeklyUsageBadge extends StatefulWidget {
  final BridgeService bridgeService;
  final String sessionId;

  const CodexWeeklyUsageBadge({
    super.key,
    required this.bridgeService,
    required this.sessionId,
  });

  @override
  State<CodexWeeklyUsageBadge> createState() => _CodexWeeklyUsageBadgeState();
}

class _CodexWeeklyUsageBadgeState extends State<CodexWeeklyUsageBadge> {
  static const _refreshCooldown = Duration(minutes: 2);
  static const _requestTimeout = Duration(seconds: 15);

  StreamSubscription<UsageResultMessage>? _usageSubscription;
  StreamSubscription<BridgeConnectionState>? _connectionSubscription;
  StreamSubscription<ServerMessage>? _messageSubscription;
  Timer? _requestTimer;
  Timer? _cooldownTimer;
  UsageWindow? _weeklyUsage;
  String? _activeRequestId;
  late bool _isConnected;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.bridgeService.isConnected;
    // The shared cache may predate the current chat by an arbitrary amount.
    // Wait for the refresh below so an old quota is never shown as current.
    _weeklyUsage = null;
    _usageSubscription = widget.bridgeService.usageResults.listen(
      _handleUsageResult,
    );
    _connectionSubscription = widget.bridgeService.connectionStatus.listen((
      state,
    ) {
      if (!mounted) return;
      final wasConnected = _isConnected;
      final connected = state == BridgeConnectionState.connected;
      setState(() {
        _isConnected = connected;
        if (!connected) _weeklyUsage = null;
      });
      if (connected && !wasConnected) {
        _requestUsage(force: true);
      } else if (!connected) {
        _clearActiveRequest(allowImmediateRetry: true);
      }
    });
    _messageSubscription = widget.bridgeService
        .messagesForSession(widget.sessionId)
        .listen(_handleServerMessage);
    if (_isConnected) _requestUsage(force: true);
  }

  bool _matchesActiveRequest(String? requestId) {
    return _activeRequestId != null &&
        (requestId == null || requestId == _activeRequestId);
  }

  void _handleUsageResult(UsageResultMessage message) {
    if (!mounted) return;
    if (_matchesActiveRequest(message.requestId)) {
      _clearActiveRequest();
    }
    setState(() => _weeklyUsage = _weeklyWindow(message));
  }

  void _handleServerMessage(ServerMessage message) {
    if (!_isConnected) return;
    if (message is ResultMessage) {
      _requestUsage();
      return;
    }
    if (message is! ErrorMessage) return;
    final isUsageError =
        message.errorCode == 'usage_fetch_failed' ||
        message.message.startsWith('Failed to fetch usage:');
    if (isUsageError && _matchesActiveRequest(message.requestId)) {
      _clearActiveRequest(allowImmediateRetry: true);
    }
  }

  void _requestUsage({bool force = false}) {
    if (!_isConnected || _activeRequestId != null) return;
    if (!force && _cooldownTimer?.isActive == true) {
      return;
    }

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(_refreshCooldown, () => _cooldownTimer = null);
    _activeRequestId = widget.bridgeService.requestUsage();
    _requestTimer?.cancel();
    _requestTimer = Timer(_requestTimeout, () {
      if (mounted) _clearActiveRequest(allowImmediateRetry: true);
    });
  }

  void _clearActiveRequest({bool allowImmediateRetry = false}) {
    _requestTimer?.cancel();
    _requestTimer = null;
    _activeRequestId = null;
    if (allowImmediateRetry) {
      _cooldownTimer?.cancel();
      _cooldownTimer = null;
    }
  }

  @override
  void dispose() {
    _usageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    _requestTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weeklyUsage = _weeklyUsage;
    if (!_isConnected || weeklyUsage == null) {
      return const SizedBox.shrink();
    }

    final remaining = (100 - weeklyUsage.utilization.clamp(0, 100)).round();
    final cs = Theme.of(context).colorScheme;
    final color = remaining <= 10
        ? cs.error
        : remaining <= 30
        ? Colors.orange
        : cs.primary;
    final label = AppLocalizations.of(context)
        .codexWeeklyUsageRemaining(remaining);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: Semantics(
          container: true,
          label: label,
          child: ExcludeSemantics(
            child: Container(
              key: const ValueKey('codex_weekly_usage_badge'),
              constraints: const BoxConstraints(minWidth: 36, maxWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$remaining%',
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

UsageWindow? _weeklyWindow(UsageResultMessage? message) {
  if (message == null) return null;
  for (final info in message.providers) {
    if (info.provider == Provider.codex.value) return info.sevenDay;
  }
  return null;
}
