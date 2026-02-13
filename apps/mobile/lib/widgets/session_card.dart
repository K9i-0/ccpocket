import 'package:flutter/material.dart';

import '../models/messages.dart';
import '../theme/app_theme.dart';

/// Card for a currently running session
class RunningSessionCard extends StatelessWidget {
  final SessionInfo session;
  final VoidCallback onTap;
  final VoidCallback onStop;

  const RunningSessionCard({
    super.key,
    required this.session,
    required this.onTap,
    required this.onStop,
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

    final statusLabel = switch (session.status) {
      'starting' => 'Starting',
      'running' => 'Running',
      'waiting_approval' => 'Approval',
      _ => 'Idle',
    };

    final projectName = session.projectPath.split('/').last;
    final providerLabel = session.provider == 'codex' ? 'Codex' : 'Claude Code';
    final providerColor = session.provider == 'codex'
        ? Colors.deepOrange
        : Colors.blueGrey;
    final elapsed = _formatElapsed(session.lastActivityAt);
    final displayMessage = session.lastMessage
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

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
                    animate:
                        session.status == 'running' ||
                        session.status == 'starting',
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
                        color: providerColor,
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
      final dt = DateTime.parse(isoDate);
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
  final bool hideProjectBadge;

  const RecentSessionCard({
    super.key,
    required this.session,
    required this.onTap,
    this.hideProjectBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final providerLabel = session.provider == 'codex' ? 'Codex' : 'Claude Code';
    final providerColor = session.provider == 'codex'
        ? Colors.deepOrange
        : Colors.blueGrey;
    final dateStr = _formatDate(session.modified);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
      child: ListTile(
        onTap: onTap,
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
            _ProviderBadge(
              label: providerLabel,
              color: providerColor,
            ),
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
            Text(
              session.displayText,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
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

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
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
  final Color color;

  const _ProviderBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
