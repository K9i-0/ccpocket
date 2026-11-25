import 'package:material_ui/material_ui.dart';

import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../codex_environment_summary.dart';

class SystemChip extends StatelessWidget {
  final SystemMessage message;
  const SystemChip({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;
    final isCodexStarted =
        message.provider == 'codex' &&
        (message.subtype == 'init' || message.subtype == 'session_created');
    final label = isCodexStarted ? null : 'System: ${message.subtype}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bubbleMarginH,
        vertical: 6,
      ),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: isCodexStarted
                ? CodexEnvironmentSummary(
                    leadingLabel: 'Session started',
                    model: message.model,
                    reasoningEffort: message.modelReasoningEffort,
                    approvalPolicy: message.approvalPolicy,
                    approvalsReviewer: message.approvalsReviewer,
                    sandboxMode: message.sandboxMode,
                    showDefaultReasoning: true,
                    compact: true,
                  )
                : Text(
                    label!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: appColors.subtleText,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
