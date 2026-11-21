import '../../models/messages.dart';

/// Result returned when the user submits the new session sheet.
class NewSessionParams {
  final String projectPath;
  final String? initialPrompt;
  final bool isNewProject;
  final String? projectId;
  final String? workspaceKind;
  final Provider provider;
  final PermissionMode? claudePermissionMode;
  final ExecutionMode executionMode;
  final CodexPermissionsMode codexPermissionsMode;
  final CodexApprovalPolicy codexApprovalPolicy;
  final bool codexAutoReviewEnabled;
  final String? codexProfile;
  final bool codexApprovalPolicyOverridden;
  final bool codexAutoReviewOverridden;
  final bool codexModelOverridden;
  final bool codexSandboxModeOverridden;
  final bool codexReasoningEffortOverridden;
  final bool codexNetworkAccessOverridden;
  final bool codexWebSearchModeOverridden;
  final bool planMode;
  final bool useWorktree;
  final String? worktreeBranch;
  final String? existingWorktreePath;
  final String? model;
  final SandboxMode? sandboxMode;
  final ReasoningEffort? modelReasoningEffort;
  final CodexSpeed codexSpeed;
  final bool? networkAccessEnabled;
  final WebSearchMode? webSearchMode;
  final List<String> additionalWritableRoots;
  final String? claudeModel;
  final ClaudeEffort? claudeEffort;
  final bool? claudeFastMode;
  final bool? claudeUltracode;
  final int? claudeMaxTurns;
  final double? claudeMaxBudgetUsd;
  final String? claudeFallbackModel;
  final bool? claudeForkSession;
  final bool? claudePersistSession;

  /// Antigravity start options. The mode is kept apart from [executionMode]
  /// and [planMode], which cannot say `auto` or `bypassPermissions`.
  final PermissionMode? antigravityPermissionMode;

  /// Model family (`gemini-3.8-flash`); null starts on the account default.
  final String? antigravityModel;
  final String? antigravityThoughtLevel;

  NewSessionParams({
    required this.projectPath,
    this.initialPrompt,
    this.isNewProject = false,
    this.projectId,
    this.workspaceKind,
    this.provider = Provider.codex,
    PermissionMode? claudePermissionMode,
    ExecutionMode? executionMode,
    CodexPermissionsMode? codexPermissionsMode,
    CodexApprovalPolicy? codexApprovalPolicy,
    this.codexAutoReviewEnabled = false,
    this.codexProfile,
    this.codexApprovalPolicyOverridden = false,
    this.codexAutoReviewOverridden = false,
    this.codexModelOverridden = false,
    this.codexSandboxModeOverridden = false,
    this.codexReasoningEffortOverridden = false,
    this.codexNetworkAccessOverridden = false,
    this.codexWebSearchModeOverridden = false,
    bool? planMode,
    PermissionMode? permissionMode,
    this.useWorktree = false,
    this.worktreeBranch,
    this.existingWorktreePath,
    this.model,
    this.sandboxMode,
    this.modelReasoningEffort,
    this.codexSpeed = CodexSpeed.standard,
    this.networkAccessEnabled,
    this.webSearchMode,
    this.additionalWritableRoots = const [],
    this.claudeModel,
    this.claudeEffort,
    this.claudeFastMode,
    this.claudeUltracode,
    this.claudeMaxTurns,
    this.claudeMaxBudgetUsd,
    this.claudeFallbackModel,
    this.claudeForkSession,
    this.claudePersistSession,
    PermissionMode? antigravityPermissionMode,
    this.antigravityModel,
    this.antigravityThoughtLevel,
  }) : antigravityPermissionMode = provider == Provider.antigravity
           ? (antigravityPermissionMode ?? permissionMode)
           : null,
       claudePermissionMode = provider == Provider.claude
           ? (claudePermissionMode ?? permissionMode)
           : null,
       executionMode =
           executionMode ??
           deriveExecutionMode(
             provider: provider.value,
             permissionMode: permissionMode?.value,
           ),
       codexPermissionsMode =
           codexPermissionsMode ??
           (codexApprovalPolicy != null || sandboxMode != null
               ? codexPermissionsModeFromSettings(
                   approvalPolicy: codexApprovalPolicy?.value,
                   approvalsReviewer: codexAutoReviewEnabled
                       ? 'auto_review'
                       : 'user',
                   sandboxMode: sandboxMode?.value,
                 )
               : CodexPermissionsMode.defaultPermissions),
       codexApprovalPolicy =
           codexApprovalPolicy ??
           (provider == Provider.codex
               ? CodexApprovalPolicy.onRequest
               : CodexApprovalPolicy.onRequest),
       planMode = planMode ?? (permissionMode == PermissionMode.plan);

  String get codexApprovalsReviewer =>
      codexApprovalPolicy == CodexApprovalPolicy.onRequest &&
          codexAutoReviewEnabled
      ? 'auto_review'
      : 'user';

  PermissionMode get permissionMode {
    if (provider == Provider.claude && claudePermissionMode != null) {
      return claudePermissionMode!;
    }
    final mode = legacyPermissionModeFromModes(
      provider,
      executionMode: executionMode,
      planMode: planMode,
    );
    if (provider != Provider.antigravity) return mode;
    // What the account really offers is checked when the session starts.
    return antigravityPermissionMode ?? antigravityStartPermissionMode(mode);
  }

  /// The same agent options aimed at another project's main checkout.
  ///
  /// Unlike [copyWith], the project identity is replaced as a whole and
  /// everything tied to the previous project (worktree, extra roots, Codex
  /// profile) is dropped.
  NewSessionParams forProject({
    required String projectPath,
    String? projectId,
    String? workspaceKind,
  }) {
    return NewSessionParams(
      projectPath: projectPath,
      projectId: projectId,
      workspaceKind: workspaceKind,
      provider: provider,
      claudePermissionMode: claudePermissionMode,
      executionMode: executionMode,
      codexPermissionsMode: codexPermissionsMode,
      codexApprovalPolicy: codexApprovalPolicy,
      codexAutoReviewEnabled: codexAutoReviewEnabled,
      codexApprovalPolicyOverridden: codexApprovalPolicyOverridden,
      codexAutoReviewOverridden: codexAutoReviewOverridden,
      codexModelOverridden: codexModelOverridden,
      codexSandboxModeOverridden: codexSandboxModeOverridden,
      codexReasoningEffortOverridden: codexReasoningEffortOverridden,
      codexNetworkAccessOverridden: codexNetworkAccessOverridden,
      codexWebSearchModeOverridden: codexWebSearchModeOverridden,
      planMode: planMode,
      model: model,
      sandboxMode: sandboxMode,
      modelReasoningEffort: modelReasoningEffort,
      codexSpeed: codexSpeed,
      networkAccessEnabled: networkAccessEnabled,
      webSearchMode: webSearchMode,
      claudeModel: claudeModel,
      claudeEffort: claudeEffort,
      claudeFastMode: claudeFastMode,
      claudeUltracode: claudeUltracode,
      claudeMaxTurns: claudeMaxTurns,
      claudeMaxBudgetUsd: claudeMaxBudgetUsd,
      claudeFallbackModel: claudeFallbackModel,
      claudeForkSession: claudeForkSession,
      claudePersistSession: claudePersistSession,
      antigravityPermissionMode: antigravityPermissionMode,
      antigravityModel: antigravityModel,
      antigravityThoughtLevel: antigravityThoughtLevel,
    );
  }

  NewSessionParams copyWith({
    String? projectPath,
    String? projectId,
    String? workspaceKind,
    Provider? provider,
    PermissionMode? claudePermissionMode,
    ExecutionMode? executionMode,
    CodexPermissionsMode? codexPermissionsMode,
    CodexApprovalPolicy? codexApprovalPolicy,
    bool? codexAutoReviewEnabled,
    String? codexProfile,
    bool? codexApprovalPolicyOverridden,
    bool? codexAutoReviewOverridden,
    bool? codexModelOverridden,
    bool? codexSandboxModeOverridden,
    bool? codexReasoningEffortOverridden,
    bool? codexNetworkAccessOverridden,
    bool? codexWebSearchModeOverridden,
    bool? planMode,
    bool? useWorktree,
    String? worktreeBranch,
    String? existingWorktreePath,
    String? model,
    SandboxMode? sandboxMode,
    ReasoningEffort? modelReasoningEffort,
    CodexSpeed? codexSpeed,
    bool? networkAccessEnabled,
    WebSearchMode? webSearchMode,
    List<String>? additionalWritableRoots,
    String? claudeModel,
    ClaudeEffort? claudeEffort,
    bool? claudeFastMode,
    bool? claudeUltracode,
    PermissionMode? antigravityPermissionMode,
    String? antigravityModel,
    String? antigravityThoughtLevel,
    int? claudeMaxTurns,
    double? claudeMaxBudgetUsd,
    String? claudeFallbackModel,
    bool? claudeForkSession,
    bool? claudePersistSession,
  }) {
    return NewSessionParams(
      projectPath: projectPath ?? this.projectPath,
      initialPrompt: projectPath == null || projectPath == this.projectPath
          ? initialPrompt
          : null,
      isNewProject:
          (projectPath == null || projectPath == this.projectPath) &&
          isNewProject,
      projectId: projectId ?? this.projectId,
      workspaceKind: workspaceKind ?? this.workspaceKind,
      provider: provider ?? this.provider,
      claudePermissionMode: claudePermissionMode ?? this.claudePermissionMode,
      executionMode: executionMode ?? this.executionMode,
      codexPermissionsMode: codexPermissionsMode ?? this.codexPermissionsMode,
      codexApprovalPolicy: codexApprovalPolicy ?? this.codexApprovalPolicy,
      codexAutoReviewEnabled:
          codexAutoReviewEnabled ?? this.codexAutoReviewEnabled,
      codexProfile: codexProfile ?? this.codexProfile,
      codexApprovalPolicyOverridden:
          codexApprovalPolicyOverridden ?? this.codexApprovalPolicyOverridden,
      codexAutoReviewOverridden:
          codexAutoReviewOverridden ?? this.codexAutoReviewOverridden,
      codexModelOverridden: codexModelOverridden ?? this.codexModelOverridden,
      codexSandboxModeOverridden:
          codexSandboxModeOverridden ?? this.codexSandboxModeOverridden,
      codexReasoningEffortOverridden:
          codexReasoningEffortOverridden ?? this.codexReasoningEffortOverridden,
      codexNetworkAccessOverridden:
          codexNetworkAccessOverridden ?? this.codexNetworkAccessOverridden,
      codexWebSearchModeOverridden:
          codexWebSearchModeOverridden ?? this.codexWebSearchModeOverridden,
      planMode: planMode ?? this.planMode,
      useWorktree: useWorktree ?? this.useWorktree,
      worktreeBranch: worktreeBranch ?? this.worktreeBranch,
      existingWorktreePath: existingWorktreePath ?? this.existingWorktreePath,
      model: model ?? this.model,
      sandboxMode: sandboxMode ?? this.sandboxMode,
      modelReasoningEffort: modelReasoningEffort ?? this.modelReasoningEffort,
      codexSpeed: codexSpeed ?? this.codexSpeed,
      networkAccessEnabled: networkAccessEnabled ?? this.networkAccessEnabled,
      webSearchMode: webSearchMode ?? this.webSearchMode,
      additionalWritableRoots:
          additionalWritableRoots ?? this.additionalWritableRoots,
      claudeModel: claudeModel ?? this.claudeModel,
      claudeEffort: claudeEffort ?? this.claudeEffort,
      claudeFastMode: claudeFastMode ?? this.claudeFastMode,
      claudeUltracode: claudeUltracode ?? this.claudeUltracode,
      antigravityPermissionMode:
          antigravityPermissionMode ?? this.antigravityPermissionMode,
      antigravityModel: antigravityModel ?? this.antigravityModel,
      antigravityThoughtLevel:
          antigravityThoughtLevel ?? this.antigravityThoughtLevel,
      claudeMaxTurns: claudeMaxTurns ?? this.claudeMaxTurns,
      claudeMaxBudgetUsd: claudeMaxBudgetUsd ?? this.claudeMaxBudgetUsd,
      claudeFallbackModel: claudeFallbackModel ?? this.claudeFallbackModel,
      claudeForkSession: claudeForkSession ?? this.claudeForkSession,
      claudePersistSession: claudePersistSession ?? this.claudePersistSession,
    );
  }
}

T? enumByValue<T>(List<T> values, String? raw, String Function(T) readValue) {
  if (raw == null || raw.isEmpty) return null;
  for (final v in values) {
    if (readValue(v) == raw) return v;
  }
  return null;
}

SandboxMode? sandboxModeFromRaw(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  // Accept both external ("on"/"off") and internal ("workspace-write"/"danger-full-access") formats.
  if (raw == 'danger-full-access') return SandboxMode.off;
  if (raw == 'workspace-write') return SandboxMode.on;
  return enumByValue(SandboxMode.values, raw, (v) => v.value);
}

ReasoningEffort? reasoningEffortFromRaw(String? raw) =>
    reasoningEffortByValue(raw);

const _fallbackCodexReasoningEfforts = <ReasoningEffort>[
  ReasoningEffort.low,
  ReasoningEffort.medium,
  ReasoningEffort.high,
  ReasoningEffort.xhigh,
];

List<ReasoningEffort> _ccPocketCodexReasoningOverrides(String? model) =>
    codexSupportsNoneReasoningEffort(model)
    ? const [ReasoningEffort.none]
    : const [];

Map<String, List<ReasoningEffort>> normalizeCodexModelReasoningEfforts(
  Map<String, List<String>> raw,
) {
  return raw.map((model, values) {
    final efforts = <ReasoningEffort>[
      ..._ccPocketCodexReasoningOverrides(model),
    ];
    for (final effort
        in values.map(reasoningEffortFromRaw).whereType<ReasoningEffort>()) {
      if (codexSupportsReasoningEffort(model, effort) &&
          !efforts.contains(effort)) {
        efforts.add(effort);
      }
    }
    return MapEntry(model, efforts.toList(growable: false));
  });
}

List<ReasoningEffort> codexReasoningEffortsForModel(
  String? model,
  Map<String, List<ReasoningEffort>> modelEfforts,
) {
  if (model != null && modelEfforts.containsKey(model)) {
    final efforts = modelEfforts[model] ?? const [];
    if (efforts.isNotEmpty) return efforts;
  }
  return [
    ..._ccPocketCodexReasoningOverrides(model),
    ..._fallbackCodexReasoningEfforts,
  ];
}

WebSearchMode? webSearchModeFromRaw(String? raw) =>
    enumByValue(WebSearchMode.values, raw, (v) => v.value);

Provider _providerFromRaw(String? raw) =>
    enumByValue(Provider.values, raw, (v) => v.value) ?? Provider.codex;

PermissionMode? permissionModeFromRaw(String? raw) =>
    enumByValue(PermissionMode.values, raw, (v) => v.value);

ExecutionMode _executionModeFromRawWithDefault(
  String? raw, {
  String? provider,
  String? permissionMode,
  String? approvalPolicy,
}) => deriveExecutionMode(
  provider: provider,
  executionMode: raw,
  permissionMode: permissionMode,
  approvalPolicy: approvalPolicy,
);

ClaudeEffort? claudeEffortFromRaw(String? raw) =>
    enumByValue(ClaudeEffort.values, raw, (v) => v.value);

/// Serialize [NewSessionParams] to JSON for SharedPreferences.
///
/// Session-specific values (worktree branch/path, useWorktree,
/// maxTurns, maxBudgetUsd) are intentionally excluded to avoid
/// dangerous or stale defaults on next session creation.
Map<String, dynamic> sessionStartDefaultsToJson(NewSessionParams params) {
  return {
    'projectPath': params.projectPath,
    'projectId': params.projectId,
    'workspaceKind': params.workspaceKind,
    'provider': params.provider.value,
    'executionMode': params.executionMode.value,
    'codexPermissionsMode': params.codexPermissionsMode.value,
    'codexApprovalPolicy': params.codexApprovalPolicy.value,
    'codexAutoReviewEnabled': params.codexAutoReviewEnabled,
    'planMode': params.planMode,
    'permissionMode': params.permissionMode.value,
    // NOTE: useWorktree, worktreeBranch, existingWorktreePath are
    // session-specific and intentionally NOT persisted.
    'model': params.model,
    'sandboxMode': params.sandboxMode?.value,
    'modelReasoningEffort': params.modelReasoningEffort?.value,
    'serviceTier': params.codexSpeed.value,
    'networkAccessEnabled': params.networkAccessEnabled,
    'webSearchMode': params.webSearchMode?.value,
    'claudeModel': params.claudeModel,
    'claudeEffort': params.claudeEffort?.value,
    'claudeFastMode': params.claudeFastMode,
    // NOTE: claudeMaxTurns, claudeMaxBudgetUsd are session-specific
    // and intentionally NOT persisted.
    'claudeFallbackModel': params.claudeFallbackModel,
    'claudeForkSession': params.claudeForkSession,
    'claudePersistSession': params.claudePersistSession,
    'antigravityModel': params.antigravityModel,
    'antigravityThoughtLevel': params.antigravityThoughtLevel,
  };
}

/// Deserialize [NewSessionParams] from JSON stored in SharedPreferences.
NewSessionParams? sessionStartDefaultsFromJson(Map<String, dynamic> json) {
  final projectPath = json['projectPath'] as String?;
  if (projectPath == null || projectPath.isEmpty) return null;
  final workspaceKind = json['workspaceKind'] as String?;
  if (workspaceKind != null && workspaceKind != 'project') return null;
  final codexModel = normalizeCodexModelForAvailableList(
    json['model'] as String?,
    defaultNewSessionCodexModels,
  );
  return NewSessionParams(
    projectPath: projectPath,
    projectId: json['projectId'] as String?,
    workspaceKind: workspaceKind,
    provider: _providerFromRaw(json['provider'] as String?),
    claudePermissionMode: permissionModeFromRaw(
      json['permissionMode'] as String?,
    ),
    executionMode: _executionModeFromRawWithDefault(
      json['executionMode'] as String?,
      provider: json['provider'] as String?,
      permissionMode: json['permissionMode'] as String?,
    ),
    codexPermissionsMode: codexPermissionsModeFromRaw(
      json['codexPermissionsMode'] as String?,
    ),
    codexApprovalPolicy:
        codexApprovalPolicyFromRaw(json['codexApprovalPolicy'] as String?) ??
        codexApprovalPolicyFromLegacyExecutionMode(
          json['executionMode'] as String?,
        ),
    codexAutoReviewEnabled: json['codexAutoReviewEnabled'] as bool? ?? false,
    planMode: derivePlanMode(
      planMode: json['planMode'] as bool?,
      permissionMode: json['permissionMode'] as String?,
    ),
    // useWorktree, worktreeBranch, existingWorktreePath default to off/null
    model: codexModel ?? json['model'] as String?,
    sandboxMode: sandboxModeFromRaw(json['sandboxMode'] as String?),
    modelReasoningEffort: reasoningEffortFromRaw(
      json['modelReasoningEffort'] as String?,
    ),
    codexSpeed: codexSpeedFromRaw(json['serviceTier'] as String?),
    networkAccessEnabled: json['networkAccessEnabled'] as bool?,
    webSearchMode: webSearchModeFromRaw(json['webSearchMode'] as String?),
    claudeModel: json['claudeModel'] as String?,
    claudeEffort: claudeEffortFromRaw(json['claudeEffort'] as String?),
    claudeFastMode: json['claudeFastMode'] as bool?,
    // claudeMaxTurns, claudeMaxBudgetUsd default to null
    claudeFallbackModel: json['claudeFallbackModel'] as String?,
    claudeForkSession: json['claudeForkSession'] as bool?,
    claudePersistSession: json['claudePersistSession'] as bool?,
    antigravityPermissionMode: permissionModeFromRaw(
      json['permissionMode'] as String?,
    ),
    antigravityModel: json['antigravityModel'] as String?,
    antigravityThoughtLevel: json['antigravityThoughtLevel'] as String?,
  );
}

/// Fallback Codex models when Bridge hasn't delivered a list yet.
const defaultNewSessionCodexModels = defaultCodexModels;
