import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';

enum _ClaudeAuthStage {
  disconnected,
  idle,
  starting,
  waitingBrowser,
  waitingCode,
  authorizing,
  success,
  error,
  cancelled,
}

class ClaudeAuthSection extends StatefulWidget {
  final BridgeService bridgeService;
  final String? activeMachineName;

  const ClaudeAuthSection({
    super.key,
    required this.bridgeService,
    this.activeMachineName,
  });

  @override
  State<ClaudeAuthSection> createState() => _ClaudeAuthSectionState();
}

class _ClaudeAuthSectionState extends State<ClaudeAuthSection> {
  StreamSubscription<ServerMessage>? _messageSub;
  StreamSubscription<BridgeConnectionState>? _connectionSub;
  ClaudeAuthStatusMessage? _status;

  @override
  void initState() {
    super.initState();
    _messageSub = widget.bridgeService.messages.listen((msg) {
      if (msg is! ClaudeAuthStatusMessage || !mounted) return;
      setState(() {
        _status = msg;
      });
    });
    _connectionSub = widget.bridgeService.connectionStatus.listen((state) {
      if (state == BridgeConnectionState.connected) {
        _requestStatus();
      }
    });
    _requestStatus();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  void _requestStatus() {
    widget.bridgeService.send(ClientMessage.getClaudeAuthStatus());
  }

  _ClaudeAuthStage _resolveStage() {
    if (!widget.bridgeService.isConnected) {
      return _ClaudeAuthStage.disconnected;
    }

    final status = _status;
    if (status == null) return _ClaudeAuthStage.idle;
    if (status.authenticated) return _ClaudeAuthStage.success;

    return switch (status.state) {
      'starting' => _ClaudeAuthStage.starting,
      'waiting_browser' => _ClaudeAuthStage.waitingBrowser,
      'waiting_code' => _ClaudeAuthStage.waitingCode,
      'authorizing' => _ClaudeAuthStage.authorizing,
      'error' => _ClaudeAuthStage.error,
      'cancelled' => _ClaudeAuthStage.cancelled,
      'success' => _ClaudeAuthStage.success,
      _ => _ClaudeAuthStage.idle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stage = _resolveStage();
    final status = _status;
    final viewData = _ClaudeAuthViewData.from(
      stage: stage,
      colorScheme: colorScheme,
      status: status,
    );
    final guidance = _guidanceText(stage);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ClaudeAuthHeader(data: viewData),
            if (widget.activeMachineName != null) ...[
              const SizedBox(height: 12),
              _ClaudeAuthMachinePill(machineName: widget.activeMachineName!),
            ],
            const SizedBox(height: 12),
            Text(
              viewData.detailText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (guidance != null) ...[
              const SizedBox(height: 16),
              _ClaudeAuthGuidancePanel(text: guidance),
            ],
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _ClaudeAuthActionGroup(
                key: ValueKey(stage),
                stage: stage,
                bridgeConnected: widget.bridgeService.isConnected,
                onRefresh: _requestStatus,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _guidanceText(_ClaudeAuthStage stage) {
    return switch (stage) {
      _ClaudeAuthStage.disconnected => null,
      _ClaudeAuthStage.success => null,
      _ClaudeAuthStage.starting ||
      _ClaudeAuthStage.waitingBrowser ||
      _ClaudeAuthStage.waitingCode ||
      _ClaudeAuthStage.authorizing =>
        'Authentication appears to be in progress on the Bridge machine. Complete it there and return here to refresh status.',
      _ClaudeAuthStage.idle ||
      _ClaudeAuthStage.error ||
      _ClaudeAuthStage.cancelled =>
        'Run "claude auth login" on the Bridge machine. The ccpocket sign-in flow is hidden until the upstream Claude CLI login flow is reliable.',
    };
  }
}

class _ClaudeAuthViewData {
  final String title;
  final String chipLabel;
  final String detailText;
  final Color accentColor;
  final Color chipBackground;
  final IconData icon;

  const _ClaudeAuthViewData({
    required this.title,
    required this.chipLabel,
    required this.detailText,
    required this.accentColor,
    required this.chipBackground,
    required this.icon,
  });

  factory _ClaudeAuthViewData.from({
    required _ClaudeAuthStage stage,
    required ColorScheme colorScheme,
    required ClaudeAuthStatusMessage? status,
  }) {
    return switch (stage) {
      _ClaudeAuthStage.disconnected => _ClaudeAuthViewData(
        title: 'Claude Code',
        chipLabel: 'Bridge offline',
        detailText:
            'Connect to a Bridge machine to manage Claude Code sign-in.',
        accentColor: colorScheme.error,
        chipBackground: colorScheme.error.withValues(alpha: 0.14),
        icon: Icons.portable_wifi_off_outlined,
      ),
      _ClaudeAuthStage.idle => _ClaudeAuthViewData(
        title: 'Claude Code',
        chipLabel: 'Login required',
        detailText:
            status?.message ?? 'Claude Code is not logged in on this machine.',
        accentColor: colorScheme.primary,
        chipBackground: colorScheme.primary.withValues(alpha: 0.14),
        icon: Icons.verified_user_outlined,
      ),
      _ClaudeAuthStage.starting => _ClaudeAuthViewData(
        title: 'Claude Code',
        chipLabel: 'Preparing sign-in',
        detailText:
            status?.message ??
            'Preparing a browser sign-in flow on this machine...',
        accentColor: colorScheme.primary,
        chipBackground: colorScheme.primary.withValues(alpha: 0.14),
        icon: Icons.open_in_browser_outlined,
      ),
      _ClaudeAuthStage.waitingBrowser => _ClaudeAuthViewData(
        title: 'Claude Code',
        chipLabel: 'Complete in browser',
        detailText:
            status?.message ??
            'Finish the Claude sign-in flow in your browser.',
        accentColor: colorScheme.primary,
        chipBackground: colorScheme.primary.withValues(alpha: 0.14),
        icon: Icons.language_outlined,
      ),
      _ClaudeAuthStage.waitingCode => _ClaudeAuthViewData(
        title: 'Claude Code',
        chipLabel: 'Enter verification code',
        detailText:
            'Claude CLI is waiting for a verification code on the Bridge machine.',
        accentColor: colorScheme.primary,
        chipBackground: colorScheme.primary.withValues(alpha: 0.14),
        icon: Icons.password_outlined,
      ),
      _ClaudeAuthStage.authorizing => _ClaudeAuthViewData(
        title: 'Claude Code',
        chipLabel: 'Verifying',
        detailText:
            status?.message ??
            'Claude CLI is verifying the submitted code on the Bridge machine.',
        accentColor: colorScheme.primary,
        chipBackground: colorScheme.primary.withValues(alpha: 0.14),
        icon: Icons.sync_outlined,
      ),
      _ClaudeAuthStage.success => _ClaudeAuthViewData(
        title: 'Claude Code',
        chipLabel: 'Authenticated',
        detailText: switch (status?.source) {
          'api_key' =>
            'Authenticated via ANTHROPIC_API_KEY on the Bridge machine.',
          'oauth' => 'Claude Code is authenticated and ready to use.',
          _ => status?.message ?? 'Claude Code is authenticated.',
        },
        accentColor: colorScheme.secondary,
        chipBackground: colorScheme.secondary.withValues(alpha: 0.14),
        icon: Icons.verified_outlined,
      ),
      _ClaudeAuthStage.error => _ClaudeAuthViewData(
        title: 'Claude Code',
        chipLabel: 'Needs attention',
        detailText:
            status?.message ??
            'The last authentication attempt failed on the Bridge machine.',
        accentColor: colorScheme.error,
        chipBackground: colorScheme.error.withValues(alpha: 0.14),
        icon: Icons.error_outline,
      ),
      _ClaudeAuthStage.cancelled => _ClaudeAuthViewData(
        title: 'Claude Code',
        chipLabel: 'Cancelled',
        detailText:
            status?.message ??
            'The sign-in flow was cancelled before completion.',
        accentColor: colorScheme.onSurfaceVariant,
        chipBackground: colorScheme.surfaceContainerHighest,
        icon: Icons.do_disturb_alt_outlined,
      ),
    };
  }
}

class _ClaudeAuthHeader extends StatelessWidget {
  final _ClaudeAuthViewData data;

  const _ClaudeAuthHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: data.chipBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(data.icon, color: data.accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              _ClaudeAuthStatusChip(data: data),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClaudeAuthStatusChip extends StatelessWidget {
  final _ClaudeAuthViewData data;

  const _ClaudeAuthStatusChip({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: data.chipBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        data.chipLabel,
        style: theme.textTheme.labelMedium?.copyWith(
          color: data.accentColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ClaudeAuthMachinePill extends StatelessWidget {
  final String machineName;

  const _ClaudeAuthMachinePill({required this.machineName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.computer_outlined,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bridge machine: $machineName',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaudeAuthGuidancePanel extends StatelessWidget {
  final String text;

  const _ClaudeAuthGuidancePanel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How to sign in', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaudeAuthActionGroup extends StatelessWidget {
  final _ClaudeAuthStage stage;
  final bool bridgeConnected;
  final VoidCallback onRefresh;

  const _ClaudeAuthActionGroup({
    super.key,
    required this.stage,
    required this.bridgeConnected,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      _ClaudeAuthStage.disconnected => const SizedBox.shrink(),
      _ => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('claude_auth_refresh_button'),
            onPressed: bridgeConnected ? onRefresh : null,
            icon: const Icon(Icons.refresh_outlined, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ),
    };
  }
}
