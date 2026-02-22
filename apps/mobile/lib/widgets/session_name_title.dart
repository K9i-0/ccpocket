import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/messages.dart';
import '../services/bridge_service.dart';
import 'rename_session_dialog.dart';

/// Tappable session name in the AppBar. Shows session name or project name.
/// Tap to rename via dialog.
class SessionNameTitle extends StatelessWidget {
  final String sessionId;
  final String? projectPath;

  const SessionNameTitle({
    super.key,
    required this.sessionId,
    this.projectPath,
  });

  @override
  Widget build(BuildContext context) {
    final bridge = context.read<BridgeService>();
    return StreamBuilder<List<SessionInfo>>(
      stream: bridge.sessionList,
      initialData: bridge.sessions,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? [];
        final session = sessions.where((s) => s.id == sessionId).firstOrNull;
        final name = session?.name;
        final fallback = projectPath?.split('/').last ?? '';

        return GestureDetector(
          onTap: () async {
            final newName = await showRenameSessionDialog(
              context,
              currentName: name,
            );
            if (newName == null || !context.mounted) return;
            bridge.renameSession(
              sessionId: sessionId,
              name: newName.isEmpty ? null : newName,
            );
          },
          child: Text(
            name != null && name.isNotEmpty ? name : fallback,
            style: TextStyle(
              fontSize: 14,
              color: name != null && name.isNotEmpty
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
