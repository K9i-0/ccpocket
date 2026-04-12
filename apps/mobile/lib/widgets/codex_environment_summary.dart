import 'package:flutter/material.dart';

import '../models/messages.dart';
import '../theme/app_theme.dart';

class CodexEnvironmentSummary extends StatelessWidget {
  final String? model;
  final String? reasoningEffort;
  final String? approvalPolicy;
  final String? sandboxMode;
  final bool showDefaultReasoning;
  final bool compact;
  final String? leadingLabel;

  const CodexEnvironmentSummary({
    super.key,
    this.model,
    this.reasoningEffort,
    this.approvalPolicy,
    this.sandboxMode,
    this.showDefaultReasoning = false,
    this.compact = false,
    this.leadingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: compact ? 11 : 12,
      color: appColors.subtleText,
      height: 1.2,
    );

    final children = <Widget>[
      if (leadingLabel != null) Text(leadingLabel!, style: textStyle),
      if (_displayModelSummary(
            model,
            reasoningEffort,
            showDefaultWhenUnset: showDefaultReasoning,
          )
          case final modelText?)
        Text(modelText, style: textStyle, overflow: TextOverflow.ellipsis),
      if (_executionLabel(approvalPolicy: approvalPolicy)
          case final executionLabel?)
        _EnvironmentMeta(
          icon: _executionIcon(approvalPolicy: approvalPolicy),
          label: executionLabel,
          compact: compact,
        ),
      _EnvironmentMeta(
        icon: _sandboxIcon(sandboxMode),
        label: _sandboxLabel(sandboxMode),
        compact: compact,
      ),
    ];

    return Wrap(
      spacing: compact ? 6 : 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _EnvironmentMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const _EnvironmentMeta({
    required this.icon,
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: compact ? 11 : 12,
      color: appColors.subtleText,
      height: 1.2,
    );

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 12 : 14, color: appColors.subtleText),
            const SizedBox(width: 3),
            Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

String? _displayModelSummary(
  String? model,
  String? raw, {
  required bool showDefaultWhenUnset,
}) {
  if (model == null || model.isEmpty) return null;
  if (raw == null || raw.isEmpty) {
    return showDefaultWhenUnset ? '$model Default' : model;
  }
  ReasoningEffort? effort;
  for (final value in ReasoningEffort.values) {
    if (value.value == raw) {
      effort = value;
      break;
    }
  }
  final effortLabel = effort == null ? raw : effort.label;
  return '$model $effortLabel';
}

IconData _executionIcon({String? approvalPolicy}) {
  return switch (approvalPolicy) {
    'never' => Icons.flash_on,
    'on-failure' => Icons.auto_mode_outlined,
    'untrusted' => Icons.verified_user_outlined,
    'on-request' || null || '' => Icons.tune,
    _ => Icons.tune,
  };
}

String? _executionLabel({String? approvalPolicy}) {
  return switch (approvalPolicy) {
    'untrusted' => 'Untrusted',
    'on-request' => 'On Request',
    'on-failure' => 'On Failure',
    'never' => 'Never Ask',
    null || '' => null,
    final other => other,
  };
}

IconData _sandboxIcon(String? sandboxMode) {
  return switch (sandboxMode) {
    'off' || 'danger-full-access' => Icons.warning_amber,
    _ => Icons.shield_outlined,
  };
}

String _sandboxLabel(String? sandboxMode) {
  return switch (sandboxMode) {
    'off' || 'danger-full-access' => 'Sandbox Off',
    'on' || 'workspace-write' || 'read-only' || null || '' => 'Sandbox',
    final other => other,
  };
}
