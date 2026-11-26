import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../theme/app_theme.dart';
import '../../theme/code_text_style.dart';
import '../expandable_summary_text.dart';
import 'ask_user_widgets.dart';

class SessionApprovalSection extends StatelessWidget {
  final Widget child;

  const SessionApprovalSection({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: isDark
            ? cs.onSurface.withValues(alpha: 0.025)
            : cs.surfaceContainerLow.withValues(alpha: 0.65),
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.55 : 0.7),
            width: 0.75,
          ),
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.75 : 0.85),
            width: 1,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _SessionPrimaryTargetCodeBlock extends StatelessWidget {
  final String text;

  const _SessionPrimaryTargetCodeBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.extension<AppColors>()!;
    final codeSettings = codeTextSettingsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: appColors.codeBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.75 : 0.85),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: codeSettings.style(
          fontSize: 11.5,
          color: cs.onSurface,
          height: 1.4,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class SessionCardToolSuggestionArea extends StatelessWidget {
  final PermissionRequestMessage permission;
  final Color statusColor;
  final VoidCallback onTap;

  const SessionCardToolSuggestionArea({
    super.key,
    required this.permission,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SessionApprovalSection(
      key: const ValueKey('session_tool_suggestion_area'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.extension_outlined,
                  size: 14,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  permission.suggestedToolName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            permission.toolSuggestionReason,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          SessionCardOpenButton(onTap: onTap),
        ],
      ),
    );
  }
}

/// Approval area for normal tool execution (Bash, Edit, etc.)
class SessionCardToolApprovalArea extends StatelessWidget {
  final PermissionRequestMessage permission;
  final Color statusColor;
  final VoidCallback onApprove;
  final VoidCallback? onApproveAlways;
  final VoidCallback onReject;
  final bool isCodex;

  const SessionCardToolApprovalArea({
    super.key,
    required this.permission,
    required this.statusColor,
    required this.onApprove,
    this.onApproveAlways,
    required this.onReject,
    this.isCodex = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    final presentation = permission.presentation;
    final detailLines = presentation.secondaryDetails;
    final canReject = permission.canDecline;
    final canApproveAlways =
        permission.canApproveForSession && onApproveAlways != null;
    final canApprove = permission.canApprove;
    final rejectLabel = permission.showsCancelAction ? l.cancel : l.reject;
    final alwaysMain = isCodex ? l.approveSessionMain : l.approveAlways;
    final alwaysSub = isCodex ? l.approveSessionSub : l.approveAlwaysSub;
    final alwaysLabel = isCodex || alwaysSub.isEmpty
        ? alwaysMain
        : '$alwaysMain $alwaysSub';
    final approveLabel = isCodex ? l.approve : l.approveOnce;
    final sectionBg = isDark
        ? Color.alphaBlend(
            cs.onSurface.withValues(alpha: 0.025),
            cs.surfaceContainerHigh,
          )
        : Color.alphaBlend(
            cs.surfaceContainerLow.withValues(alpha: 0.65),
            cs.surfaceContainerHigh,
          );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );

    final buttons = <Widget>[
      if (canReject)
        OutlinedButton(
          key: const ValueKey('reject_button'),
          onPressed: onReject,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: cs.onSurfaceVariant,
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.85 : 1.0),
            ),
            shape: buttonShape,
          ),
          child: Text(
            rejectLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      if (canApproveAlways)
        FilledButton.tonal(
          key: const ValueKey('approve_always_button'),
          onPressed: onApproveAlways,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: cs.onSurface.withValues(
              alpha: isDark ? 0.11 : 0.07,
            ),
            foregroundColor: cs.onSurface,
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.55 : 0.65),
            ),
            shape: buttonShape,
          ),
          child: Text(
            alwaysLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      if (canApprove)
        FilledButton(
          key: const ValueKey('approve_button'),
          onPressed: onApprove,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: buttonShape,
          ),
          child: Text(
            approveLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
    ];

    return SessionApprovalSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            presentation.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          ExpandableSummaryText(
            text: presentation.summary,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
            maxLines: 2,
            backgroundColor: sectionBg,
          ),
          if (presentation.primaryTarget != null) ...[
            const SizedBox(height: 8),
            _SessionPrimaryTargetCodeBlock(text: presentation.primaryTarget!),
          ],
          if (detailLines.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...detailLines
                .take(5)
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: buttons,
            ),
          ),
        ],
      ),
    );
  }
}

/// Approval area for ExitPlanMode (plan review).
class SessionCardPlanApprovalArea extends StatelessWidget {
  final Color statusColor;
  final TextEditingController planFeedbackController;
  final bool canOpenPlan;
  final VoidCallback onOpenPlan;
  final VoidCallback onApprove;
  final VoidCallback onApproveClearContext;
  final VoidCallback onKeepPlanning;

  const SessionCardPlanApprovalArea({
    super.key,
    required this.statusColor,
    required this.planFeedbackController,
    required this.canOpenPlan,
    required this.onOpenPlan,
    required this.onApprove,
    required this.onApproveClearContext,
    required this.onKeepPlanning,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );

    return SessionApprovalSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    l.planApprovalSummaryCard,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (canOpenPlan)
                IconButton(
                  onPressed: onOpenPlan,
                  icon: const Icon(Icons.open_in_full, size: 19),
                  color: cs.primary,
                  tooltip: l.viewEditPlan,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.keepPlanning,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('plan_feedback_input'),
                  controller: planFeedbackController,
                  style: const TextStyle(fontSize: 13),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    hintText: l.keepPlanningHint,
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                    filled: true,
                    fillColor: isDark ? cs.surface : cs.surfaceContainerHigh,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                  ),
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const ValueKey('reject_button'),
                onPressed: onKeepPlanning,
                icon: Icon(Icons.send, size: 18, color: cs.primary),
                tooltip: l.sendFeedbackKeepPlanning,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  key: const ValueKey('approve_clear_context_button'),
                  onPressed: onApproveClearContext,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    backgroundColor: cs.onSurface.withValues(
                      alpha: isDark ? 0.11 : 0.07,
                    ),
                    foregroundColor: cs.onSurface,
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.55 : 0.65,
                      ),
                    ),
                    shape: buttonShape,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l.acceptAndClear,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('approve_button'),
                  onPressed: onApprove,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: buttonShape,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l.acceptPlan,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

/// Plan approval area for Codex sessions in session list.
class SessionCardCodexPlanApprovalArea extends StatelessWidget {
  final Color statusColor;
  final bool canOpenPlan;
  final VoidCallback onOpenPlan;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const SessionCardCodexPlanApprovalArea({
    super.key,
    required this.statusColor,
    required this.canOpenPlan,
    required this.onOpenPlan,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );

    return SessionApprovalSection(
      key: const ValueKey('codex_plan_approval_area'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    l.planApprovalSummaryCard,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (canOpenPlan)
                IconButton(
                  onPressed: onOpenPlan,
                  icon: const Icon(Icons.open_in_full, size: 19),
                  color: cs.primary,
                  tooltip: l.viewEditPlan,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('reject_button'),
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    foregroundColor: cs.onSurfaceVariant,
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.85 : 1.0,
                      ),
                    ),
                    shape: buttonShape,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l.continuePlanning,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('approve_button'),
                  onPressed: onApprove,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: buttonShape,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l.acceptPlan,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

/// "Open" button for questions without options.
class SessionCardOpenButton extends StatelessWidget {
  final VoidCallback onTap;

  const SessionCardOpenButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: sessionCardButtonHeight,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.open_in_new, size: 14),
          label: const Text('Open'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            foregroundColor: cs.onSurface,
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.85 : 1.0),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
