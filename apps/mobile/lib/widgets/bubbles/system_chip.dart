import 'package:flutter/material.dart';

import '../../models/messages.dart';
import '../../theme/app_theme.dart';
import '../codex_environment_summary.dart';

class SystemChip extends StatelessWidget {
  final SystemMessage message;
  const SystemChip({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final isCodexStarted =
        message.provider == 'codex' &&
        (message.subtype == 'init' || message.subtype == 'session_created');
    final label = isCodexStarted ? null : 'System: ${message.subtype}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Chip(
          label: isCodexStarted
              ? CodexEnvironmentSummary(
                  leadingLabel: 'Session started',
                  model: message.model,
                  reasoningEffort: message.modelReasoningEffort,
                  approvalPolicy: message.approvalPolicy,
                  approvalsReviewer: message.approvalsReviewer,
                  sandboxMode: message.sandboxMode,
                  showDefaultReasoning: true,
                )
              : Text(label!, style: const TextStyle(fontSize: 12)),
          backgroundColor: appColors.systemChip,
          side: BorderSide.none,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
