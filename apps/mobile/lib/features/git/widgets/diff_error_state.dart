import 'package:flutter/material.dart';

import '../../project_setup/widgets/project_setup_action.dart';

import '../../../theme/app_theme.dart';

class DiffErrorState extends StatelessWidget {
  final String error;
  final String? errorCode;
  final String? projectPath;
  final VoidCallback? onInitialized;

  const DiffErrorState({
    super.key,
    required this.error,
    this.errorCode,
    this.projectPath,
    this.onInitialized,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final isGitUnavailable = errorCode == 'git_not_available';
    final color = isGitUnavailable
        ? appColors.warningText
        : appColors.errorText;
    final icon = isGitUnavailable ? Icons.info_outline : Icons.error_outline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            if (isGitUnavailable && projectPath != null)
              ProjectSetupAction(
                projectPath: projectPath!,
                trust: false,
                onDone: onInitialized,
              ),
            Text(
              error,
              style: TextStyle(color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
