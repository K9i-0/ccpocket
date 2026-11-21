import '../../models/messages.dart';

/// Build a compact settings summary for Claude session cards.
String buildSessionSettingsSummary({
  required bool isCodex,
  String? model,
  String? effort,
  bool fastMode = false,
  bool ultracode = false,
  String? permissionMode,
  String? executionMode,
  bool planMode = false,
  int? contextPercent,
}) {
  if (isCodex) return model ?? '';
  final effortLabel = claudeEffortByValue(effort)?.label;
  final modelParts = <String>[
    if (model != null && model.isNotEmpty) model,
    ?effortLabel,
    if (fastMode) 'Fast',
    if (ultracode) 'Ultracode',
  ];
  if (modelParts.isNotEmpty) model = modelParts.join(' · ');
  final parts = <String>[
    if (permissionMode == PermissionMode.auto.value)
      'auto'
    else if (executionMode == 'fullAccess' ||
        permissionMode == PermissionMode.bypassPermissions.value)
      'full-access'
    else if (executionMode == 'acceptEdits')
      'accept-edits'
    else
      'default',
    if (planMode) 'plan-on',
    // Share of the context window in use (Antigravity reports it).
    if (contextPercent != null) 'ctx $contextPercent%',
  ];
  if (model != null && model.isNotEmpty) {
    return '$model  ${parts.join("  ")}';
  }
  return parts.join('  ');
}
