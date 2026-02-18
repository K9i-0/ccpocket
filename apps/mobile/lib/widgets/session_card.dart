import 'package:flutter/material.dart';

import '../models/messages.dart';
import '../theme/app_theme.dart';
import '../theme/provider_style.dart';
import '../utils/command_parser.dart';

/// Card for a currently running session
class RunningSessionCard extends StatelessWidget {
  final SessionInfo session;
  final VoidCallback onTap;
  final VoidCallback onStop;
  final ValueChanged<String>? onApprove;
  final ValueChanged<String>? onReject;

  const RunningSessionCard({
    super.key,
    required this.session,
    required this.onTap,
    required this.onStop,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final statusColor = switch (session.status) {
      'starting' => appColors.statusStarting,
      'running' => appColors.statusRunning,
      'waiting_approval' => appColors.statusApproval,
      _ => appColors.statusIdle,
    };

    final permission = session.pendingPermission;
    final hasPermission =
        session.status == 'waiting_approval' && permission != null;
    final statusLabel = switch (session.status) {
      'starting' => 'Starting',
      'running' => 'Running',
      'waiting_approval' when hasPermission =>
        'Approval · ${permission.toolName}',
      'waiting_approval' => 'Approval',
      _ => 'Idle',
    };

    final projectName = session.projectPath.split('/').last;
    final provider = providerFromRaw(session.provider);
    final providerLabel = provider.label;
    final providerStyle = providerStyleFor(context, provider);
    final elapsed = _formatElapsed(session.lastActivityAt);
    final displayMessage = formatCommandText(
      session.lastMessage.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    final codexSummary = session.provider == 'codex'
        ? _buildCodexSettingsSummary(
            model: session.codexModel,
            sandboxMode: session.codexSandboxMode,
            approvalPolicy: session.codexApprovalPolicy,
          )
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: statusColor.withValues(alpha: 0.12),
              child: Row(
                children: [
                  _StatusDot(
                    color: statusColor,
                    animate: session.status != 'idle',
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 28,
                    height: 20,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.stop_circle_outlined, size: 16),
                      onPressed: onStop,
                      tooltip: 'Stop session',
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            // Approval area (shown when waiting for permission)
            if (hasPermission)
              _ApprovalArea(
                permission: permission,
                statusColor: statusColor,
                onApprove: () => onApprove?.call(permission.toolUseId),
                onReject: () => onReject?.call(permission.toolUseId),
              ),
            // Content (same structure as RecentSessionCard)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row: project badge + elapsed
                  Row(
                    children: [
                      Hero(
                        tag: 'project_name_${session.id}',
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              projectName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ProviderBadge(
                        label: providerLabel,
                        style: providerStyle,
                      ),
                      const Spacer(),
                      Text(
                        elapsed,
                        style: TextStyle(
                          fontSize: 11,
                          color: appColors.subtleText,
                        ),
                      ),
                    ],
                  ),
                  // Last message
                  if (displayMessage.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      displayMessage,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (codexSummary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      codexSummary,
                      style: TextStyle(
                        fontSize: 11,
                        color: appColors.subtleText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Git branch + message count
                  if (session.gitBranch.isNotEmpty ||
                      session.messageCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (session.gitBranch.isNotEmpty) ...[
                          Icon(
                            Icons.fork_right,
                            size: 13,
                            color: appColors.subtleText,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              session.gitBranch,
                              style: TextStyle(
                                fontSize: 11,
                                color: appColors.subtleText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (session.messageCount > 0) ...[
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 12,
                            color: appColors.subtleText,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${session.messageCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: appColors.subtleText,
                            ),
                          ),
                        ],
                        if (session.worktreePath != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.account_tree_outlined,
                            size: 12,
                            color: appColors.subtleText,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'worktree',
                            style: TextStyle(
                              fontSize: 11,
                              color: appColors.subtleText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}

class _ApprovalArea extends StatelessWidget {
  final PermissionRequestMessage permission;
  final Color statusColor;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApprovalArea({
    required this.permission,
    required this.statusColor,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: statusColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            permission.summary,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: 28,
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12),
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: FilledButton.tonalIcon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12),
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    foregroundColor: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _StatusDot({required this.color, required this.animate});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

/// Card for a recent (past) session from sessions-index.json
class RecentSessionCard extends StatelessWidget {
  final RecentSession session;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool hideProjectBadge;
  final SessionDisplayMode displayMode;
  final String? draftText;

  const RecentSessionCard({
    super.key,
    required this.session,
    required this.onTap,
    this.onLongPress,
    this.hideProjectBadge = false,
    this.displayMode = SessionDisplayMode.first,
    this.draftText,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final provider = providerFromRaw(session.provider);
    final providerLabel = provider.label;
    final providerStyle = providerStyleFor(context, provider);
    final codexSummary = session.provider == 'codex'
        ? _buildCodexSettingsSummary(
            model: session.codexModel,
            sandboxMode: session.codexSandboxMode,
            approvalPolicy: session.codexApprovalPolicy,
          )
        : null;
    final dateStr = _formatDateRange(session.created, session.modified);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Row(
          children: [
            if (!hideProjectBadge) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  session.projectName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
            ] else
              const Spacer(),
            _ProviderBadge(label: providerLabel, style: providerStyle),
            const SizedBox(width: 8),
            Text(
              dateStr,
              style: TextStyle(fontSize: 11, color: appColors.subtleText),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (draftText != null && draftText!.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: Icon(
                      Icons.edit_note,
                      size: 14,
                      color: appColors.subtleText,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      draftText!,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: appColors.subtleText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                _displayTextForMode(session, displayMode),
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (codexSummary != null) ...[
              const SizedBox(height: 4),
              Text(
                codexSummary,
                style: TextStyle(fontSize: 11, color: appColors.subtleText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                if (session.gitBranch.isNotEmpty) ...[
                  Icon(Icons.fork_right, size: 13, color: appColors.subtleText),
                  const SizedBox(width: 2),
                  Text(
                    session.gitBranch,
                    style: TextStyle(fontSize: 11, color: appColors.subtleText),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(
                  Icons.chat_bubble_outline,
                  size: 12,
                  color: appColors.subtleText,
                ),
                const SizedBox(width: 3),
                Text(
                  '${session.messageCount}',
                  style: TextStyle(fontSize: 11, color: appColors.subtleText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _displayTextForMode(
    RecentSession session,
    SessionDisplayMode mode,
  ) {
    final String raw;
    switch (mode) {
      case SessionDisplayMode.first:
        raw = session.firstPrompt.isNotEmpty
            ? session.firstPrompt
            : session.displayText;
      case SessionDisplayMode.last:
        final text = session.lastPrompt ?? session.firstPrompt;
        raw = text.isNotEmpty ? text : '(no description)';
      case SessionDisplayMode.summary:
        final text = session.summary ?? session.firstPrompt;
        raw = text.isNotEmpty ? text : '(no description)';
    }
    return formatCommandText(raw);
  }

  String _formatDateRange(String createdIso, String modifiedIso) {
    if (modifiedIso.isEmpty) return _formatDate(createdIso);
    final modified = _formatDate(modifiedIso);
    if (createdIso.isEmpty || createdIso == modifiedIso) return modified;
    try {
      final first = DateTime.parse(createdIso).toLocal();
      final last = DateTime.parse(modifiedIso).toLocal();
      // Same minute → single timestamp
      if (first.year == last.year &&
          first.month == last.month &&
          first.day == last.day &&
          first.hour == last.hour &&
          first.minute == last.minute) {
        return modified;
      }
      final firstTime =
          '${first.hour.toString().padLeft(2, '0')}:${first.minute.toString().padLeft(2, '0')}';
      final lastTime =
          '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
      // Same day → "Today 10:00–12:30"
      if (first.year == last.year &&
          first.month == last.month &&
          first.day == last.day) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final dtDate = DateTime(first.year, first.month, first.day);
        if (dtDate == today) return 'Today $firstTime–$lastTime';
        if (dtDate == yesterday) return 'Yesterday $firstTime–$lastTime';
        return '${first.month}/${first.day} $firstTime–$lastTime';
      }
      // Different days → "1/10 10:00–1/11 12:30"
      return '${first.month}/${first.day} $firstTime–${last.month}/${last.day} $lastTime';
    } catch (_) {
      return modified;
    }
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dtDate = DateTime(dt.year, dt.month, dt.day);

      final time =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      if (dtDate == today) return 'Today $time';
      if (dtDate == yesterday) return 'Yesterday $time';
      return '${dt.month}/${dt.day} $time';
    } catch (_) {
      return '';
    }
  }
}

class _ProviderBadge extends StatelessWidget {
  final String label;
  final ProviderStyle style;

  const _ProviderBadge({required this.label, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: style.foreground,
        ),
      ),
    );
  }
}

String _buildCodexSettingsSummary({
  String? model,
  String? sandboxMode,
  String? approvalPolicy,
}) {
  final modelText = (model == null || model.isEmpty) ? 'model:auto' : model;
  final sandboxText = (sandboxMode == null || sandboxMode.isEmpty)
      ? 'sandbox:default'
      : 'sandbox:$sandboxMode';
  final approvalText = (approvalPolicy == null || approvalPolicy.isEmpty)
      ? 'approval:default'
      : 'approval:$approvalPolicy';
  return '$modelText  $sandboxText  $approvalText';
}
