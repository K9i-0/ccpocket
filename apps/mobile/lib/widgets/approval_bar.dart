import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../theme/app_theme.dart';
import '../theme/code_text_style.dart';
import '../utils/platform_helper.dart';
import 'expandable_summary_text.dart';
import 'google_search_text_selection.dart';

enum PlanApprovalUiMode { claude, codex }

/// Bottom bar that presents tool-use / plan approval controls.
///
/// Pure presentation — all actions are dispatched via callbacks.
class ApprovalBar extends StatelessWidget {
  final AppColors appColors;
  final PermissionRequestMessage? pendingPermission;
  final bool isPlanApproval;
  final TextEditingController planFeedbackController;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onApproveAlways;
  final VoidCallback? onViewPlan;

  /// Callback for "Accept & Clear Context" button (plan approval only).
  final VoidCallback? onApproveClearContext;
  final PlanApprovalUiMode planApprovalUiMode;

  /// When true, labels `acceptForSession` as session-scoped ("This Session" /
  /// "セッション中許可") instead of permanent ("Permanently allow").
  final bool useSessionApprovalLabel;

  const ApprovalBar({
    super.key,
    required this.appColors,
    required this.pendingPermission,
    required this.isPlanApproval,
    required this.planFeedbackController,
    required this.onApprove,
    required this.onReject,
    required this.onApproveAlways,
    this.onViewPlan,
    this.onApproveClearContext,
    this.planApprovalUiMode = PlanApprovalUiMode.claude,
    this.useSessionApprovalLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final presentation = pendingPermission?.presentation;
    final l = AppLocalizations.of(context);
    final summary = pendingPermission != null
        ? (isPlanApproval ? l.planApprovalSummary : pendingPermission!.summary)
        : l.toolApprovalSummary;
    final toolName = isPlanApproval
        ? l.planApproval
        : presentation?.title ?? pendingPermission?.displayToolName;
    final detailLines = isPlanApproval
        ? const <String>[]
        : (presentation?.secondaryDetails ?? const <String>[]);
    final accentColor = isPlanApproval ? cs.primary : appColors.permissionIcon;

    return Container(
      decoration: ShapeDecoration(
        color: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.85 : 0.9),
            width: 1,
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ApprovalHeader(
                appColors: appColors,
                accentColor: accentColor,
                surfaceColor: cs.surfaceContainerHigh,
                isPlanApproval: isPlanApproval,
                toolName: toolName,
                summary: summary,
                primaryTarget: presentation?.primaryTarget,
                detailLines: detailLines,
                onViewPlan: onViewPlan,
              ),
              if (isPlanApproval &&
                  planApprovalUiMode == PlanApprovalUiMode.claude) ...[
                const SizedBox(height: 12),
                _KeepPlanningCard(
                  planFeedbackController: planFeedbackController,
                  onReject: onReject,
                ),
                const SizedBox(height: 10),
              ] else
                const SizedBox(height: 12),
              _ApprovalButtons(
                pendingPermission: pendingPermission,
                isPlanApproval: isPlanApproval,
                planApprovalUiMode: planApprovalUiMode,
                useSessionApprovalLabel: useSessionApprovalLabel,
                onApprove: onApprove,
                onReject: onReject,
                onApproveAlways: onApproveAlways,
                onApproveClearContext: onApproveClearContext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApprovalHeader extends StatelessWidget {
  final AppColors appColors;
  final Color accentColor;
  final Color surfaceColor;
  final bool isPlanApproval;
  final String? toolName;
  final String summary;
  final String? primaryTarget;
  final List<String> detailLines;
  final VoidCallback? onViewPlan;

  const _ApprovalHeader({
    required this.appColors,
    required this.accentColor,
    required this.surfaceColor,
    required this.isPlanApproval,
    required this.toolName,
    required this.summary,
    required this.primaryTarget,
    required this.detailLines,
    this.onViewPlan,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryTargetText = primaryTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: accentColor.withValues(alpha: isDark ? 0.28 : 0.22),
                  width: 1,
                ),
              ),
              child: Icon(
                isPlanApproval ? Icons.assignment : Icons.shield,
                color: accentColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GoogleSearchSelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toolName ?? l.approvalRequired,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ExpandableSummaryText(
                      text: summary,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      backgroundColor: surfaceColor,
                    ),
                    if (!isPlanApproval && primaryTargetText != null) ...[
                      const SizedBox(height: 10),
                      _PrimaryTargetCard(
                        text: primaryTargetText,
                        appColors: appColors,
                      ),
                    ],
                    if (detailLines.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...detailLines.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isPlanApproval && onViewPlan != null)
              IconButton(
                key: const ValueKey('view_plan_header_button'),
                icon: Icon(Icons.open_in_full, size: 18, color: cs.primary),
                tooltip: l.viewEditPlan,
                onPressed: onViewPlan,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ],
    );
  }
}

class _PrimaryTargetCard extends StatelessWidget {
  final String text;
  final AppColors appColors;

  const _PrimaryTargetCard({required this.text, required this.appColors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final codeSettings = codeTextSettingsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: appColors.codeBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.75 : 0.85),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: codeSettings.style(
          fontSize: 12,
          color: cs.onSurface,
          height: 1.45,
        ),
      ),
    );
  }
}

/// "Keep Planning" card with feedback input + send button.
class _KeepPlanningCard extends StatelessWidget {
  final TextEditingController planFeedbackController;
  final VoidCallback onReject;

  const _KeepPlanningCard({
    required this.planFeedbackController,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      key: const ValueKey('keep_planning_card'),
      decoration: BoxDecoration(
        color: isDark
            ? cs.onSurface.withValues(alpha: 0.04)
            : cs.surfaceContainerLow,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.75 : 0.85),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.keepPlanning,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('plan_feedback_input'),
                  controller: planFeedbackController,
                  onTapOutside: isDesktopPlatform
                      ? null
                      : (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    hintText: l.keepPlanningHint,
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                    filled: true,
                    fillColor: isDark ? cs.surface : cs.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.75),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.75),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  maxLines: 3,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const ValueKey('reject_button'),
                icon: Icon(Icons.send, size: 19, color: cs.primary),
                tooltip: l.sendFeedbackKeepPlanning,
                onPressed: onReject,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalButtons extends StatelessWidget {
  final PermissionRequestMessage? pendingPermission;
  final bool isPlanApproval;
  final PlanApprovalUiMode planApprovalUiMode;
  final bool useSessionApprovalLabel;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onApproveAlways;
  final VoidCallback? onApproveClearContext;

  const _ApprovalButtons({
    this.pendingPermission,
    required this.isPlanApproval,
    required this.planApprovalUiMode,
    required this.useSessionApprovalLabel,
    required this.onApprove,
    required this.onReject,
    required this.onApproveAlways,
    this.onApproveClearContext,
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
    final subtleOutlineStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      minimumSize: const Size(0, 40),
      foregroundColor: cs.onSurfaceVariant,
      side: BorderSide(
        color: cs.outlineVariant.withValues(alpha: isDark ? 0.85 : 1.0),
      ),
      shape: buttonShape,
    );
    final secondaryTonalStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      minimumSize: const Size(0, 40),
      backgroundColor: cs.onSurface.withValues(alpha: isDark ? 0.11 : 0.07),
      foregroundColor: cs.onSurface,
      side: BorderSide(
        color: cs.outlineVariant.withValues(alpha: isDark ? 0.55 : 0.65),
      ),
      shape: buttonShape,
    );
    final primarySolidStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      minimumSize: const Size(0, 40),
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      shape: buttonShape,
    );

    if (isPlanApproval) {
      if (planApprovalUiMode == PlanApprovalUiMode.codex) {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('reject_button'),
                onPressed: onReject,
                style: subtleOutlineStyle,
                child: Text(
                  l.continuePlanning,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const ValueKey('approve_button'),
                onPressed: onApprove,
                style: primarySolidStyle,
                child: Text(
                  l.acceptPlan,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      return Row(
        children: [
          if (onApproveClearContext != null) ...[
            Expanded(
              child: FilledButton.tonal(
                key: const ValueKey('approve_clear_context_button'),
                onPressed: onApproveClearContext,
                style: secondaryTonalStyle,
                child: Text(
                  l.acceptAndClear,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: FilledButton(
              key: const ValueKey('approve_button'),
              onPressed: onApprove,
              style: primarySolidStyle,
              child: Text(
                l.acceptPlan,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    final isCodex = planApprovalUiMode == PlanApprovalUiMode.codex;
    final useSessionLabel = isCodex || useSessionApprovalLabel;
    final canReject = pendingPermission?.canDecline ?? true;
    final canApproveAlways = pendingPermission?.canApproveForSession ?? true;
    final canApprove = pendingPermission?.canApprove ?? true;
    final rejectLabel = pendingPermission?.showsCancelAction ?? false
        ? l.cancel
        : l.reject;
    final alwaysMain = useSessionLabel ? l.approveSessionMain : l.approveAlways;
    final alwaysSub = useSessionLabel
        ? l.approveSessionSub
        : l.approveAlwaysSub;
    final buttons = <Widget>[
      if (canReject)
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('reject_button'),
            onPressed: onReject,
            style: subtleOutlineStyle,
            child: Text(
              rejectLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      if (canApproveAlways) ...[
        if (canReject) const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonal(
            key: const ValueKey('approve_always_button'),
            onPressed: onApproveAlways,
            style: secondaryTonalStyle,
            child: Text(
              useSessionLabel || alwaysSub.isEmpty
                  ? alwaysMain
                  : '$alwaysMain $alwaysSub',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
      if (canApprove) ...[
        if (canReject || canApproveAlways) const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            key: const ValueKey('approve_button'),
            onPressed: onApprove,
            style: primarySolidStyle,
            child: Text(
              isCodex ? l.approve : l.approveOnce,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ];
    return Row(children: buttons);
  }
}
