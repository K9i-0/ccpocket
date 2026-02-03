import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class ChatAppBarTitle extends StatelessWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;

  const ChatAppBarTitle({
    super.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    if (projectPath != null && projectPath!.isNotEmpty) {
      final projectName = projectPath!.split('/').last;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'project_name_$sessionId',
            child: Material(
              color: Colors.transparent,
              child: Text(
                projectName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (gitBranch != null && gitBranch!.isNotEmpty)
            Text(
              gitBranch!,
              style: TextStyle(fontSize: 12, color: appColors.subtleText),
            ),
        ],
      );
    }
    return Text('Session ${sessionId.substring(0, 8)}');
  }
}
