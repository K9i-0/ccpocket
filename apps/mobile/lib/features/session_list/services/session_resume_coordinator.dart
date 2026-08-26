import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/messages.dart';
import '../../../models/offline_pending_action.dart';
import '../../../services/bridge_service.dart';
import 'codex_project_profile_store.dart';
import 'session_start_defaults_store.dart';

const _claudeSessionSettingsPrefix = 'claude_session_settings_';

class ClaudeSessionSettingsStore {
  const ClaudeSessionSettingsStore();

  Future<Map<String, dynamic>?> load(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_claudeSessionSettingsPrefix$sessionId');
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String sessionId, Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load(sessionId);
    await prefs.setString(
      '$_claudeSessionSettingsPrefix$sessionId',
      jsonEncode(<String, dynamic>{...?existing, ...settings}),
    );
  }
}

class CodexRecentResumeSettings {
  final String? permissionMode;
  final String? executionMode;
  final String? approvalPolicy;
  final String? approvalsReviewer;
  final String? codexPermissionsMode;
  final String? sandboxMode;
  final String? model;
  final String? modelReasoningEffort;
  final String? serviceTier;
  final bool? networkAccessEnabled;
  final String? webSearchMode;
  final List<String>? additionalWritableRoots;

  const CodexRecentResumeSettings({
    this.permissionMode,
    this.executionMode,
    this.approvalPolicy,
    this.approvalsReviewer,
    this.codexPermissionsMode,
    this.sandboxMode,
    this.model,
    this.modelReasoningEffort,
    this.serviceTier,
    this.networkAccessEnabled,
    this.webSearchMode,
    this.additionalWritableRoots,
  });
}

CodexRecentResumeSettings factualCodexResumeSettings(
  RecentSession session,
  List<String> availableCodexModels,
) {
  final useCodexProfile = session.codexProfile?.isNotEmpty ?? false;
  final approvalPolicy = session.codexApprovalPolicy;
  final permissionsMode = codexPermissionsModeFromRaw(
    session.codexPermissionsMode,
  );
  final useCustomPermissions =
      permissionsMode == CodexPermissionsMode.custom || useCodexProfile;
  final model =
      normalizeCodexModelForAvailableList(
        session.codexModel,
        availableCodexModels,
      ) ??
      sanitizeCodexModelName(session.codexModel);
  final permissionMode = useCodexProfile || approvalPolicy == null
      ? null
      : (approvalPolicy == CodexApprovalPolicy.never.value
            ? PermissionMode.bypassPermissions.value
            : PermissionMode.acceptEdits.value);
  final executionMode = useCodexProfile || approvalPolicy == null
      ? null
      : deriveExecutionMode(
          provider: Provider.codex.value,
          executionMode: session.executionMode,
          permissionMode: session.permissionMode,
          approvalPolicy: approvalPolicy,
        ).value;

  return CodexRecentResumeSettings(
    permissionMode: permissionMode,
    executionMode: executionMode,
    approvalPolicy: useCustomPermissions ? null : approvalPolicy,
    approvalsReviewer: useCustomPermissions
        ? null
        : session.codexApprovalsReviewer,
    codexPermissionsMode: useCodexProfile ? null : permissionsMode?.value,
    sandboxMode: useCustomPermissions ? null : session.codexSandboxMode,
    model: useCodexProfile ? null : model,
    modelReasoningEffort: useCodexProfile
        ? null
        : session.codexModelReasoningEffort,
    serviceTier: session.codexServiceTier,
    networkAccessEnabled: useCustomPermissions
        ? null
        : session.codexNetworkAccessEnabled,
    webSearchMode: useCodexProfile ? null : session.codexWebSearchMode,
    additionalWritableRoots: useCustomPermissions
        ? null
        : session.codexAdditionalWritableRoots,
  );
}

enum SessionResumeDisposition { dispatched, alreadyQueued }

class SessionResumeIdentityException implements Exception {
  final String message;
  const SessionResumeIdentityException(this.message);

  @override
  String toString() => 'SessionResumeIdentityException: $message';
}

class SessionResumeDispatch {
  final SessionResumeDisposition disposition;
  final String projectPath;
  final String gitBranch;

  const SessionResumeDispatch({
    required this.disposition,
    required this.projectPath,
    required this.gitBranch,
  });
}

class SessionResumeCoordinator {
  SessionResumeCoordinator({
    required BridgeService bridge,
    SessionStartDefaultsStore defaultsStore = const SessionStartDefaultsStore(),
    ClaudeSessionSettingsStore claudeSettingsStore =
        const ClaudeSessionSettingsStore(),
    CodexProjectProfileStore codexProfileStore =
        const CodexProjectProfileStore(),
  }) : _bridge = bridge,
       _defaultsStore = defaultsStore,
       _claudeSettingsStore = claudeSettingsStore,
       _codexProfileStore = codexProfileStore;

  final BridgeService _bridge;
  final SessionStartDefaultsStore _defaultsStore;
  final ClaudeSessionSettingsStore _claudeSettingsStore;
  final CodexProjectProfileStore _codexProfileStore;
  final Set<String> _claimedResumeRequestIds = <String>{};

  Future<SessionResumeDispatch> resume(
    RecentSession session, {
    String? resumeRequestId,
    bool allowReadOnlyProbe = false,
  }) async {
    final provider = session.provider ?? Provider.claude.value;
    final projectPath = session.resumeCwd?.isNotEmpty == true
        ? session.resumeCwd!
        : session.projectPath;
    final ownership = session.ownership;
    final route = ownership?.routeForProvider(provider);
    final isExplicitReadOnlyProbe =
        allowReadOnlyProbe &&
        route == SessionOwnershipRoute.readOnlyHistory &&
        ownership?.can(SessionCapability.resume) == true &&
        (ownership?.attachmentState == SessionAttachmentState.externalActive ||
            ownership?.attachmentState ==
                SessionAttachmentState.externalUnknown);
    if (ownership == null ||
        (route != SessionOwnershipRoute.externalIdleResume &&
            !isExplicitReadOnlyProbe) ||
        ownership.providerThreadId != session.sessionId) {
      throw const SessionResumeIdentityException(
        'External resume requires an external-idle tuple or an explicit read-only probe.',
      );
    }
    if (resumeRequestId != null &&
        _claimedResumeRequestIds.contains(resumeRequestId)) {
      return SessionResumeDispatch(
        disposition: SessionResumeDisposition.alreadyQueued,
        projectPath: projectPath,
        gitBranch: session.gitBranch,
      );
    }
    if (_isQueued(session.sessionId, provider)) {
      return SessionResumeDispatch(
        disposition: SessionResumeDisposition.alreadyQueued,
        projectPath: projectPath,
        gitBranch: session.gitBranch,
      );
    }

    final isCodex = provider == Provider.codex.value;
    final sessionSettings = isCodex
        ? null
        : await _claudeSettingsStore.load(session.sessionId);
    final claudeDefaults = isCodex
        ? null
        : await _defaultsStore.loadFor(Provider.claude);
    final permissionMode =
        sessionSettings?['permissionMode'] as String? ??
        session.effectivePermissionMode;
    final executionMode = deriveExecutionMode(
      provider: Provider.claude.value,
      executionMode: sessionSettings?['executionMode'] as String?,
      permissionMode: permissionMode,
    ).value;
    final planMode = derivePlanMode(
      planMode: sessionSettings?['planMode'] as bool?,
      permissionMode: permissionMode,
    );
    final codexSettings = isCodex
        ? factualCodexResumeSettings(session, _bridge.codexModels)
        : null;
    final useCodexProfile =
        isCodex && (session.codexProfile?.isNotEmpty ?? false);
    final claudeEffort =
        sessionSettings?['claudeEffort'] as String? ??
        claudeDefaults?.claudeEffort?.value;
    final claudeFallbackModel =
        sessionSettings?['claudeFallbackModel'] as String? ??
        claudeDefaults?.claudeFallbackModel;
    final claudeForkSession =
        sessionSettings?['claudeForkSession'] as bool? ??
        claudeDefaults?.claudeForkSession;
    final claudePersistSession =
        sessionSettings?['claudePersistSession'] as bool? ??
        claudeDefaults?.claudePersistSession;
    final claudeSandboxMode =
        sessionSettings?['sandboxMode'] as String? ??
        claudeDefaults?.sandboxMode?.value;
    final claudeModel =
        sessionSettings?['claudeModel'] as String? ??
        claudeDefaults?.claudeModel;

    if (resumeRequestId != null) {
      _claimedResumeRequestIds.add(resumeRequestId);
    }

    _bridge.resumeSession(
      session.sessionId,
      projectPath,
      providerThreadId: ownership.providerThreadId,
      bridgeGeneration: ownership.bridgeGeneration,
      expectedOwner: ownership.owner,
      permissionMode: isCodex ? codexSettings?.permissionMode : permissionMode,
      executionMode: isCodex ? codexSettings?.executionMode : executionMode,
      approvalPolicy: isCodex ? codexSettings?.approvalPolicy : null,
      approvalsReviewer: isCodex ? codexSettings?.approvalsReviewer : null,
      codexPermissionsMode: isCodex
          ? codexSettings?.codexPermissionsMode
          : null,
      planMode: isCodex
          ? (useCodexProfile ? null : session.planMode)
          : planMode,
      effort: !isCodex ? claudeEffort : null,
      maxTurns: !isCodex ? claudeDefaults?.claudeMaxTurns : null,
      maxBudgetUsd: !isCodex ? claudeDefaults?.claudeMaxBudgetUsd : null,
      fallbackModel: !isCodex ? claudeFallbackModel : null,
      forkSession: !isCodex ? claudeForkSession : null,
      persistSession: !isCodex ? claudePersistSession : null,
      profile: isCodex ? session.codexProfile : null,
      provider: provider,
      sandboxMode: isCodex ? codexSettings?.sandboxMode : claudeSandboxMode,
      model: isCodex ? codexSettings?.model : claudeModel,
      modelReasoningEffort: isCodex
          ? codexSettings?.modelReasoningEffort
          : null,
      serviceTier: isCodex ? codexSettings?.serviceTier : null,
      networkAccessEnabled: isCodex
          ? codexSettings?.networkAccessEnabled
          : null,
      webSearchMode: isCodex ? codexSettings?.webSearchMode : null,
      additionalWritableRoots: isCodex
          ? codexSettings?.additionalWritableRoots
          : null,
      resumeRequestId: resumeRequestId,
    );

    if (isCodex) {
      unawaited(
        _codexProfileStore.save(session.projectPath, session.codexProfile),
      );
    } else {
      unawaited(
        _claudeSettingsStore.save(session.sessionId, {
          'permissionMode': permissionMode,
          'executionMode': executionMode,
          'planMode': planMode,
          'sandboxMode': ?claudeSandboxMode,
          'claudeEffort': ?claudeEffort,
          'claudeModel': ?claudeModel,
          'claudeFallbackModel': ?claudeFallbackModel,
          'claudeForkSession': ?claudeForkSession,
          'claudePersistSession': ?claudePersistSession,
        }),
      );
    }

    return SessionResumeDispatch(
      disposition: SessionResumeDisposition.dispatched,
      projectPath: projectPath,
      gitBranch: session.gitBranch,
    );
  }

  bool _isQueued(String sessionId, String provider) {
    return _bridge.offlinePendingActions.any(
      (action) =>
          action.kind == OfflinePendingActionKind.resume &&
          action.sessionId == sessionId &&
          action.provider == provider,
    );
  }
}
