import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

class SessionSwitcher extends StatelessWidget {
  final List<SessionInfo> otherSessions;
  final void Function(SessionInfo session) onSessionSelected;

  const SessionSwitcher({
    super.key,
    required this.otherSessions,
    required this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final approvalCount = otherSessions
        .where((s) => s.status == 'waiting_approval')
        .length;
    return PopupMenuButton<String>(
      key: const ValueKey('session_switcher'),
      icon: Badge(
        isLabelVisible: approvalCount > 0,
        label: Text('$approvalCount'),
        backgroundColor: appColors.statusApproval,
        child: Text(
          '${otherSessions.length + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: appColors.subtleText,
          ),
        ),
      ),
      tooltip: 'Switch session',
      onSelected: (sessionId) {
        final session = otherSessions.firstWhere((s) => s.id == sessionId);
        onSessionSelected(session);
      },
      itemBuilder: (context) => otherSessions.map((s) {
        final projectName = s.projectPath.split('/').last;
        final isApproval = s.status == 'waiting_approval';
        return PopupMenuItem<String>(
          value: s.id,
          child: Row(
            children: [
              if (isApproval)
                Icon(
                  Icons.warning_amber,
                  size: 16,
                  color: appColors.statusApproval,
                )
              else
                Icon(Icons.terminal, size: 16, color: appColors.subtleText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  projectName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isApproval ? FontWeight.w700 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                s.id.substring(0, 6),
                style: TextStyle(fontSize: 10, color: appColors.subtleText),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
