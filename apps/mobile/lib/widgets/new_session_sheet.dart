import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/session_list/session_list_screen.dart'
    show recentProjects, shortenPath;
import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../models/new_session_tab.dart';
import '../services/bridge_service.dart';
import '../theme/app_theme.dart';
import '../theme/provider_style.dart';
import 'workspace_pane_chrome.dart';

/// Result returned when the user submits the new session sheet.
class NewSessionParams {
  final String projectPath;
  final Provider provider;
  final PermissionMode? claudePermissionMode;
  final ExecutionMode executionMode;
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
  final bool? networkAccessEnabled;
  final WebSearchMode? webSearchMode;
  final List<String> additionalWritableRoots;
  final String? claudeModel;
  final ClaudeEffort? claudeEffort;
  final int? claudeMaxTurns;
  final double? claudeMaxBudgetUsd;
  final String? claudeFallbackModel;
  final bool? claudeForkSession;
  final bool? claudePersistSession;

  NewSessionParams({
    required this.projectPath,
    this.provider = Provider.codex,
    PermissionMode? claudePermissionMode,
    ExecutionMode? executionMode,
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
    this.networkAccessEnabled,
    this.webSearchMode,
    this.additionalWritableRoots = const [],
    this.claudeModel,
    this.claudeEffort,
    this.claudeMaxTurns,
    this.claudeMaxBudgetUsd,
    this.claudeFallbackModel,
    this.claudeForkSession,
    this.claudePersistSession,
  }) : claudePermissionMode = provider == Provider.claude
           ? (claudePermissionMode ?? permissionMode)
           : null,
       executionMode =
           executionMode ??
           deriveExecutionMode(
             provider: provider.value,
             permissionMode: permissionMode?.value,
           ),
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
    return legacyPermissionModeFromModes(
      provider,
      executionMode: executionMode,
      planMode: planMode,
    );
  }

  NewSessionParams copyWith({
    String? projectPath,
    Provider? provider,
    PermissionMode? claudePermissionMode,
    ExecutionMode? executionMode,
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
    bool? networkAccessEnabled,
    WebSearchMode? webSearchMode,
    List<String>? additionalWritableRoots,
    String? claudeModel,
    ClaudeEffort? claudeEffort,
    int? claudeMaxTurns,
    double? claudeMaxBudgetUsd,
    String? claudeFallbackModel,
    bool? claudeForkSession,
    bool? claudePersistSession,
  }) {
    return NewSessionParams(
      projectPath: projectPath ?? this.projectPath,
      provider: provider ?? this.provider,
      claudePermissionMode: claudePermissionMode ?? this.claudePermissionMode,
      executionMode: executionMode ?? this.executionMode,
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
      networkAccessEnabled: networkAccessEnabled ?? this.networkAccessEnabled,
      webSearchMode: webSearchMode ?? this.webSearchMode,
      additionalWritableRoots:
          additionalWritableRoots ?? this.additionalWritableRoots,
      claudeModel: claudeModel ?? this.claudeModel,
      claudeEffort: claudeEffort ?? this.claudeEffort,
      claudeMaxTurns: claudeMaxTurns ?? this.claudeMaxTurns,
      claudeMaxBudgetUsd: claudeMaxBudgetUsd ?? this.claudeMaxBudgetUsd,
      claudeFallbackModel: claudeFallbackModel ?? this.claudeFallbackModel,
      claudeForkSession: claudeForkSession ?? this.claudeForkSession,
      claudePersistSession: claudePersistSession ?? this.claudePersistSession,
    );
  }
}

// ---- Serialization helpers for SharedPreferences ----

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
    enumByValue(ReasoningEffort.values, raw, (v) => v.value);

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
    'provider': params.provider.value,
    'executionMode': params.executionMode.value,
    'codexApprovalPolicy': params.codexApprovalPolicy.value,
    'codexAutoReviewEnabled': params.codexAutoReviewEnabled,
    'planMode': params.planMode,
    'permissionMode': params.permissionMode.value,
    // NOTE: useWorktree, worktreeBranch, existingWorktreePath are
    // session-specific and intentionally NOT persisted.
    'model': params.model,
    'sandboxMode': params.sandboxMode?.value,
    'modelReasoningEffort': params.modelReasoningEffort?.value,
    'networkAccessEnabled': params.networkAccessEnabled,
    'webSearchMode': params.webSearchMode?.value,
    'claudeModel': params.claudeModel,
    'claudeEffort': params.claudeEffort?.value,
    // NOTE: claudeMaxTurns, claudeMaxBudgetUsd are session-specific
    // and intentionally NOT persisted.
    'claudeFallbackModel': params.claudeFallbackModel,
    'claudeForkSession': params.claudeForkSession,
    'claudePersistSession': params.claudePersistSession,
  };
}

/// Deserialize [NewSessionParams] from JSON stored in SharedPreferences.
NewSessionParams? sessionStartDefaultsFromJson(Map<String, dynamic> json) {
  final projectPath = json['projectPath'] as String?;
  if (projectPath == null || projectPath.isEmpty) return null;
  final codexModel = normalizeCodexModelForAvailableList(
    json['model'] as String?,
    _defaultCodexModels,
  );
  return NewSessionParams(
    projectPath: projectPath,
    provider: _providerFromRaw(json['provider'] as String?),
    claudePermissionMode: permissionModeFromRaw(
      json['permissionMode'] as String?,
    ),
    executionMode: _executionModeFromRawWithDefault(
      json['executionMode'] as String?,
      provider: json['provider'] as String?,
      permissionMode: json['permissionMode'] as String?,
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
    networkAccessEnabled: json['networkAccessEnabled'] as bool?,
    webSearchMode: webSearchModeFromRaw(json['webSearchMode'] as String?),
    claudeModel: json['claudeModel'] as String?,
    claudeEffort: claudeEffortFromRaw(json['claudeEffort'] as String?),
    // claudeMaxTurns, claudeMaxBudgetUsd default to null
    claudeFallbackModel: json['claudeFallbackModel'] as String?,
    claudeForkSession: json['claudeForkSession'] as bool?,
    claudePersistSession: json['claudePersistSession'] as bool?,
  );
}

/// Shows a modal bottom sheet for creating a new Claude Code session.
///
/// Returns [NewSessionParams] if the user starts a session, or null on cancel.
/// [projectHistory] is the Bridge-managed project history (preferred).
/// [recentProjects] is the fallback from session-based history.
/// [bridge] is required for fetching existing worktree list.
/// Shows a modal bottom sheet for creating a new session.
///
/// When [lockProvider] is true the provider toggle is disabled so the user
/// cannot switch between Claude Code and Codex. This is used when starting a
/// new session from a recent session's long-press menu, where the provider
/// should remain the same as the original session.
Future<NewSessionParams?> showNewSessionSheet({
  required BuildContext context,
  required List<({String path, String name})> recentProjects,
  List<String> projectHistory = const [],
  BridgeService? bridge,
  NewSessionParams? initialParams,
  bool lockProvider = false,
  List<NewSessionTab> visibleTabs = defaultNewSessionTabs,
}) {
  return showModalBottomSheet<NewSessionParams>(
    context: context,
    isScrollControlled: true,
    constraints: macOSModalBottomSheetConstraints(context),
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _NewSessionSheetContent(
      recentProjects: recentProjects,
      projectHistory: projectHistory,
      bridge: bridge,
      initialParams: initialParams,
      lockProvider: lockProvider,
      visibleTabs: visibleTabs,
    ),
  );
}

/// Number of recent projects shown by default (collapsed).
const _defaultRecentProjects = 5;

/// Maximum number of recent projects shown when expanded.
const _maxRecentProjects = 20;

const _additionalWritableRootHistoryKey =
    'new_session_additional_writable_root_history';
const _maxAdditionalWritableRootHistory = 20;

class _NewSessionSheetContent extends StatefulWidget {
  final List<({String path, String name})> recentProjects;
  final List<String> projectHistory;
  final BridgeService? bridge;
  final NewSessionParams? initialParams;
  final bool lockProvider;
  final List<NewSessionTab> visibleTabs;

  const _NewSessionSheetContent({
    required this.recentProjects,
    this.projectHistory = const [],
    this.bridge,
    this.initialParams,
    this.lockProvider = false,
    this.visibleTabs = defaultNewSessionTabs,
  });

  @override
  State<_NewSessionSheetContent> createState() =>
      _NewSessionSheetContentState();
}

/// Worktree selection mode.
enum _WorktreeMode {
  /// Create a new worktree (default).
  createNew,

  /// Use an existing worktree.
  useExisting,
}

enum _CodexApprovalChoice {
  untrusted,
  onRequest,
  autoReview,
  never;

  static _CodexApprovalChoice from({
    required CodexApprovalPolicy policy,
    required bool autoReviewEnabled,
  }) {
    if (policy == CodexApprovalPolicy.onRequest && autoReviewEnabled) {
      return _CodexApprovalChoice.autoReview;
    }
    return switch (policy) {
      CodexApprovalPolicy.untrusted => _CodexApprovalChoice.untrusted,
      CodexApprovalPolicy.onRequest ||
      CodexApprovalPolicy.onFailure => _CodexApprovalChoice.onRequest,
      CodexApprovalPolicy.never => _CodexApprovalChoice.never,
    };
  }

  CodexApprovalPolicy get policy => switch (this) {
    _CodexApprovalChoice.untrusted => CodexApprovalPolicy.untrusted,
    _CodexApprovalChoice.onRequest ||
    _CodexApprovalChoice.autoReview => CodexApprovalPolicy.onRequest,
    _CodexApprovalChoice.never => CodexApprovalPolicy.never,
  };

  bool get autoReviewEnabled => this == _CodexApprovalChoice.autoReview;
}

/// Fallback Codex models when Bridge hasn't delivered a list yet.
const _defaultCodexModels = defaultCodexModels;

/// Fallback Claude models when Bridge hasn't delivered a list yet.
const _defaultClaudeModels = <String>[
  'claude-opus-4-7',
  'claude-opus-4-7[1m]',
  'claude-opus-4-6',
  'claude-opus-4-6[1m]',
  'claude-sonnet-4-6',
  'claude-haiku-4-6',
];

class _NewSessionSheetContentState extends State<_NewSessionSheetContent> {
  final _pathController = TextEditingController();
  final _branchController = TextEditingController();
  final _claudeMaxTurnsController = TextEditingController();
  final _claudeMaxBudgetController = TextEditingController();
  final _additionalWritableRootController = TextEditingController();
  late final PageController _pageController;
  var _provider = Provider.codex;
  var _claudePermissionMode = PermissionMode.defaultMode;
  var _executionMode = ExecutionMode.defaultMode;
  var _codexApprovalPolicy = CodexApprovalPolicy.onRequest;
  var _codexAutoReviewEnabled = false;
  var _planMode = false;
  var _useWorktree = false;
  var _worktreeMode = _WorktreeMode.createNew;
  WorktreeInfo? _selectedWorktree;
  List<WorktreeInfo>? _worktrees;
  StreamSubscription<WorktreeListMessage>? _worktreeSub;
  StreamSubscription<List<RecentSession>>? _recentSub;
  StreamSubscription<List<String>>? _projectHistorySub;

  /// Live-updated recent projects (initially from widget, updated via stream).
  late List<({String path, String name})> _liveRecentProjects;

  /// Live-updated project history (initially from widget, updated via stream).
  late List<String> _liveProjectHistory;

  // Claude-specific options
  String? _selectedClaudeModel;
  String? _selectedClaudeFallbackModel;
  ClaudeEffort _claudeEffort = ClaudeEffort.medium;
  bool _claudeForkSession = false;
  bool _claudePersistSession = true;

  // Model lists from Bridge (with fallbacks)
  late final List<String> _claudeModelList;
  late final List<String> _codexModelList;
  late final List<String> _codexProfiles;

  // Codex-specific options
  String? _selectedModel;
  String? _selectedCodexProfile;
  var _claudeSandboxMode = SandboxMode.off; // Claude default = OFF
  var _codexSandboxMode = SandboxMode.on; // Codex default = ON
  ReasoningEffort _modelReasoningEffort = ReasoningEffort.high;
  bool _networkAccessEnabled = true;
  WebSearchMode? _webSearchMode;
  bool _codexApprovalPolicyTouched = false;
  bool _codexAutoReviewTouched = false;
  bool _codexModelTouched = false;
  bool _codexSandboxModeTouched = false;
  bool _codexReasoningEffortTouched = false;
  bool _codexNetworkAccessTouched = false;
  bool _codexWebSearchTouched = false;
  var _additionalWritableRoots = <String>[];
  var _additionalWritableRootHistory = <String>[];

  // Project list expansion
  bool _isProjectListExpanded = false;

  // Inline validation errors
  String? _maxTurnsError;
  String? _maxBudgetError;

  // Provider-aware sandbox accessor (keeps existing `_sandboxMode` usage intact)
  SandboxMode get _sandboxMode =>
      _provider == Provider.claude ? _claudeSandboxMode : _codexSandboxMode;
  set _sandboxMode(SandboxMode v) {
    if (_provider == Provider.claude) {
      _claudeSandboxMode = v;
    } else {
      _codexSandboxMode = v;
    }
  }

  bool get _hasPath => _pathController.text.trim().isNotEmpty;

  /// All merged projects (up to [_maxRecentProjects]).
  List<({String path, String name})> get _allMergedProjects {
    List<({String path, String name})> merged;
    if (_liveProjectHistory.isEmpty) {
      merged = _liveRecentProjects;
    } else {
      final seen = <String>{};
      final result = <({String path, String name})>[];
      for (final path in _liveProjectHistory) {
        if (seen.add(path)) {
          final name = path.split('/').last;
          result.add((path: path, name: name));
        }
      }
      for (final project in _liveRecentProjects) {
        if (seen.add(project.path)) {
          result.add(project);
        }
      }
      merged = result;
    }
    if (merged.length > _maxRecentProjects) {
      return merged.sublist(0, _maxRecentProjects);
    }
    return merged;
  }

  /// Merge projectHistory (Bridge-managed, preferred) with recentProjects (session fallback).
  /// projectHistory paths are shown first; recentProjects paths not already covered are appended.
  /// Returns collapsed ([_defaultRecentProjects]) or expanded ([_maxRecentProjects]) list.
  List<({String path, String name})> get _effectiveProjects {
    final all = _allMergedProjects;
    if (!_isProjectListExpanded && all.length > _defaultRecentProjects) {
      return all.sublist(0, _defaultRecentProjects);
    }
    return all;
  }

  /// Whether the project list has more items than the default collapsed count.
  bool get _canExpandProjects =>
      _allMergedProjects.length > _defaultRecentProjects;

  @override
  void initState() {
    super.initState();
    final initialProvider =
        widget.initialParams?.provider ?? widget.visibleTabs.first.toProvider();
    final initialPage = widget.visibleTabs
        .indexWhere((t) => t.toProvider() == initialProvider)
        .clamp(0, widget.visibleTabs.length - 1);
    _pageController = PageController(initialPage: initialPage);
    _provider = initialProvider;
    // Use the latest cached recent sessions from BridgeService if available,
    // because the broadcast stream may have already fired before this listener
    // was registered.
    final cachedSessions = widget.bridge?.recentSessions;
    _liveRecentProjects = (cachedSessions != null && cachedSessions.isNotEmpty)
        ? recentProjects(cachedSessions)
        : widget.recentProjects;
    // Use the latest cached project history from BridgeService if available,
    // because the broadcast stream may have already fired before this listener
    // was registered.
    _liveProjectHistory =
        widget.bridge?.projectHistory ?? widget.projectHistory;

    // Load available models from Bridge (with hardcoded fallbacks).
    final bridgeClaudeModels = widget.bridge?.claudeModels ?? const [];
    _claudeModelList = bridgeClaudeModels.isNotEmpty
        ? bridgeClaudeModels
        : _defaultClaudeModels;
    final bridgeCodexModels = widget.bridge?.codexModels ?? const [];
    _codexModelList = bridgeCodexModels.isNotEmpty
        ? bridgeCodexModels
        : _defaultCodexModels;
    _codexProfiles = widget.bridge?.codexProfiles ?? const [];
    final defaultCodexProfile = widget.bridge?.defaultCodexProfile;
    if (_codexProfiles.contains(defaultCodexProfile)) {
      _selectedCodexProfile = defaultCodexProfile;
    }
    _worktreeSub = widget.bridge?.worktreeList.listen((msg) {
      if (mounted) setState(() => _worktrees = msg.worktrees);
    });
    // Subscribe to live updates so projects appear even if data arrives
    // after the sheet is already open (e.g. right after connection).
    _recentSub = widget.bridge?.recentSessionsStream.listen((sessions) {
      if (mounted) {
        setState(() => _liveRecentProjects = recentProjects(sessions));
      }
    });
    _projectHistorySub = widget.bridge?.projectHistoryStream.listen((projects) {
      if (mounted) {
        setState(() => _liveProjectHistory = projects);
      }
    });
    unawaited(_loadAdditionalWritableRootHistory());
    _applyInitialParams();
    // Pre-fill project path with allowedDirs prefix when the path is empty
    // and the server has exactly one allowed directory.
    if (_pathController.text.isEmpty) {
      final dirs = widget.bridge?.allowedDirs ?? const [];
      if (dirs.length == 1) {
        final prefix = dirs.first.endsWith('/') ? dirs.first : '${dirs.first}/';
        _pathController.text = prefix;
        // Place cursor at the end so the user can type the project name.
        _pathController.selection = TextSelection.collapsed(
          offset: prefix.length,
        );
      }
    }
    if (_useWorktree) {
      _fetchWorktrees();
    }
  }

  @override
  void dispose() {
    _worktreeSub?.cancel();
    _recentSub?.cancel();
    _projectHistorySub?.cancel();
    _pageController.dispose();
    _pathController.dispose();
    _branchController.dispose();
    _claudeMaxTurnsController.dispose();
    _claudeMaxBudgetController.dispose();
    _additionalWritableRootController.dispose();
    super.dispose();
  }

  void _onWorktreeToggle(bool val) {
    setState(() {
      _useWorktree = val;
      if (val) {
        _fetchWorktrees();
      } else {
        _worktreeMode = _WorktreeMode.createNew;
        _selectedWorktree = null;
        _worktrees = null;
      }
    });
  }

  void _applyInitialParams() {
    final p = widget.initialParams;
    if (p == null) return;

    _pathController.text = p.projectPath;
    // Validate provider is in visibleTabs; fall back to first tab if hidden.
    final isVisible = widget.visibleTabs.any(
      (t) => t.toProvider() == p.provider,
    );
    _provider = isVisible ? p.provider : widget.visibleTabs.first.toProvider();
    _executionMode = p.executionMode;
    _claudePermissionMode = p.provider == Provider.claude
        ? p.permissionMode
        : PermissionMode.defaultMode;
    _codexApprovalPolicy =
        p.codexApprovalPolicy == CodexApprovalPolicy.onFailure
        ? CodexApprovalPolicy.onRequest
        : p.codexApprovalPolicy;
    _codexAutoReviewEnabled =
        _codexApprovalPolicy == CodexApprovalPolicy.onRequest &&
        p.codexAutoReviewEnabled;
    _planMode = p.planMode;
    _useWorktree = p.useWorktree || p.existingWorktreePath != null;
    _branchController.text = p.worktreeBranch ?? "";
    final normalizedCodexModel = normalizeCodexModelForAvailableList(
      p.model,
      _codexModelList,
    );
    _selectedModel = _codexModelList.contains(normalizedCodexModel)
        ? normalizedCodexModel
        : null;
    _selectedCodexProfile = _codexProfiles.contains(p.codexProfile)
        ? p.codexProfile
        : null;
    if (p.provider == Provider.claude) {
      _claudeSandboxMode = p.sandboxMode ?? SandboxMode.off;
    } else {
      _codexSandboxMode = p.sandboxMode ?? SandboxMode.on;
    }
    _modelReasoningEffort = p.modelReasoningEffort ?? _modelReasoningEffort;
    _networkAccessEnabled = p.networkAccessEnabled ?? _networkAccessEnabled;
    _webSearchMode = p.webSearchMode;
    _additionalWritableRoots = [...p.additionalWritableRoots];
    _selectedClaudeModel = _claudeModelList.contains(p.claudeModel)
        ? p.claudeModel
        : null;
    _claudeEffort = p.claudeEffort ?? _claudeEffort;
    _claudeMaxTurnsController.text = p.claudeMaxTurns?.toString() ?? "";
    _claudeMaxBudgetController.text = p.claudeMaxBudgetUsd?.toString() ?? "";
    _selectedClaudeFallbackModel =
        _claudeModelList.contains(p.claudeFallbackModel)
        ? p.claudeFallbackModel
        : null;
    _claudeForkSession = p.claudeForkSession ?? _claudeForkSession;
    _claudePersistSession = p.claudePersistSession ?? _claudePersistSession;
    _codexApprovalPolicyTouched = p.codexApprovalPolicyOverridden;
    _codexAutoReviewTouched = p.codexAutoReviewOverridden;
    _codexModelTouched = p.codexModelOverridden;
    _codexSandboxModeTouched = p.codexSandboxModeOverridden;
    _codexReasoningEffortTouched = p.codexReasoningEffortOverridden;
    _codexNetworkAccessTouched = p.codexNetworkAccessOverridden;
    _codexWebSearchTouched = p.codexWebSearchModeOverridden;

    if (p.existingWorktreePath != null) {
      _worktreeMode = _WorktreeMode.useExisting;
      _selectedWorktree = WorktreeInfo(
        worktreePath: p.existingWorktreePath!,
        branch: p.worktreeBranch ?? "",
        projectPath: p.projectPath,
      );
    }
  }

  void _fetchWorktrees() {
    final path = _pathController.text.trim();
    if (path.isNotEmpty && widget.bridge != null) {
      setState(() => _worktrees = null); // reset to loading
      widget.bridge!.requestWorktreeList(path);
    }
  }

  void _onProjectSelected(String path) {
    setState(() {
      _pathController.text = path;
      // Re-fetch worktrees if worktree mode is active
      if (_useWorktree) {
        _worktrees = null;
        _selectedWorktree = null;
        widget.bridge?.requestWorktreeList(path);
      }
    });
  }

  List<String> get _addDirSuggestions {
    final selectedProject = _pathController.text.trim();
    final seen = <String>{..._additionalWritableRoots, selectedProject};
    return _uniquePaths([
          ..._additionalWritableRootHistory,
          ..._allMergedProjects.map((project) => project.path),
        ])
        .where((path) => path.trim().isNotEmpty && !seen.contains(path))
        .take(8)
        .toList();
  }

  void _addWritableRoot(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return;
    _rememberAdditionalWritableRoot(normalized);
    if (_additionalWritableRoots.contains(normalized)) return;
    setState(() {
      _additionalWritableRoots = [..._additionalWritableRoots, normalized];
    });
  }

  void _removeWritableRoot(String path) {
    setState(() {
      _additionalWritableRoots = [
        for (final root in _additionalWritableRoots)
          if (root != path) root,
      ];
    });
  }

  Future<void> _openAddWritableRootSheet() async {
    final prefix = _additionalWritableRootDefaultPrefix;
    _additionalWritableRootController.text = prefix;
    _additionalWritableRootController.selection = TextSelection.collapsed(
      offset: prefix.length,
    );
    final selected = await _showAddWritableRootSheet(
      context: context,
      controller: _additionalWritableRootController,
      suggestions: _addDirSuggestions,
    );
    if (selected == null || !mounted) return;
    _addWritableRoot(selected);
  }

  String get _additionalWritableRootDefaultPrefix {
    final selectedProject = _pathController.text.trim();
    final allowedDirs = widget.bridge?.allowedDirs ?? const [];
    final containingAllowedDirs = allowedDirs.where(
      (dir) => _isSameOrChildPath(selectedProject, dir),
    );
    final base = containingAllowedDirs.isNotEmpty
        ? containingAllowedDirs.reduce((a, b) => a.length >= b.length ? a : b)
        : (allowedDirs.isNotEmpty
              ? allowedDirs.first
              : _homePrefixFromPath(selectedProject));
    if (base.isEmpty) return '';
    return base.endsWith('/') ? base : '$base/';
  }

  bool _isSameOrChildPath(String path, String parent) {
    if (path.isEmpty || parent.isEmpty) return false;
    final normalizedParent = parent.endsWith('/')
        ? parent.substring(0, parent.length - 1)
        : parent;
    return path == normalizedParent || path.startsWith('$normalizedParent/');
  }

  String _homePrefixFromPath(String path) {
    final match = RegExp(r'^/Users/[^/]+').firstMatch(path);
    if (match != null) return match.group(0)!;
    return '';
  }

  Future<void> _loadAdditionalWritableRootHistory() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final stored = prefs.getStringList(_additionalWritableRootHistoryKey) ?? [];
    setState(() {
      _additionalWritableRootHistory = _uniquePaths([
        ..._additionalWritableRootHistory,
        ...stored,
      ]).take(_maxAdditionalWritableRootHistory).toList();
    });
  }

  void _rememberAdditionalWritableRoot(String path) {
    final nextHistory = _uniquePaths([
      path,
      ..._additionalWritableRootHistory,
    ]).take(_maxAdditionalWritableRootHistory).toList();
    setState(() => _additionalWritableRootHistory = nextHistory);
    unawaited(_saveAdditionalWritableRootHistory(nextHistory));
  }

  Future<void> _saveAdditionalWritableRootHistory(List<String> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_additionalWritableRootHistoryKey, history);
    } catch (_) {
      // SharedPreferences can be unavailable in widget tests.
    }
  }

  List<String> _uniquePaths(Iterable<String> paths) {
    final seen = <String>{};
    final result = <String>[];
    for (final path in paths) {
      final normalized = path.trim();
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      result.add(normalized);
    }
    return result;
  }

  Future<void> _onProjectRemoved(String path) async {
    final l = AppLocalizations.of(context);
    final name = path.split('/').last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.removeProjectTitle),
        content: Text(l.removeProjectConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.bridge?.removeProjectHistory(path);
    setState(() {
      // Clear path input if the removed project was selected.
      if (_pathController.text == path) {
        _pathController.clear();
      }
    });
  }

  /// Validate Max Turns field inline. Returns true if valid.
  bool _validateMaxTurns() {
    final raw = _claudeMaxTurnsController.text.trim();
    if (raw.isEmpty) {
      _maxTurnsError = null;
      return true;
    }
    final value = int.tryParse(raw);
    if (value == null || value < 1) {
      _maxTurnsError = AppLocalizations.of(context).maxTurnsError;
      return false;
    }
    _maxTurnsError = null;
    return true;
  }

  /// Validate Max Budget field inline. Returns true if valid.
  bool _validateMaxBudget() {
    final raw = _claudeMaxBudgetController.text.trim();
    if (raw.isEmpty) {
      _maxBudgetError = null;
      return true;
    }
    final value = double.tryParse(raw);
    if (value == null || value < 0) {
      _maxBudgetError = AppLocalizations.of(context).maxBudgetError;
      return false;
    }
    _maxBudgetError = null;
    return true;
  }

  NewSessionParams _buildParams() {
    final path = _pathController.text.trim();
    final branch = _branchController.text.trim();
    final isCodex = _provider == Provider.codex;
    final claudeMaxTurns = int.tryParse(_claudeMaxTurnsController.text.trim());
    final claudeMaxBudgetUsd = double.tryParse(
      _claudeMaxBudgetController.text.trim(),
    );

    final useExisting =
        _useWorktree && _worktreeMode == _WorktreeMode.useExisting;

    return NewSessionParams(
      projectPath: path,
      provider: _provider,
      claudePermissionMode: !isCodex ? _claudePermissionMode : null,
      executionMode: _executionMode,
      codexApprovalPolicy: _codexApprovalPolicy,
      codexAutoReviewEnabled:
          isCodex &&
          _codexApprovalPolicy == CodexApprovalPolicy.onRequest &&
          _codexAutoReviewEnabled,
      codexProfile: isCodex ? _selectedCodexProfile : null,
      codexApprovalPolicyOverridden: isCodex && _codexApprovalPolicyTouched,
      codexAutoReviewOverridden: isCodex && _codexAutoReviewTouched,
      codexModelOverridden: isCodex && _codexModelTouched,
      codexSandboxModeOverridden: isCodex && _codexSandboxModeTouched,
      codexReasoningEffortOverridden: isCodex && _codexReasoningEffortTouched,
      codexNetworkAccessOverridden: isCodex && _codexNetworkAccessTouched,
      codexWebSearchModeOverridden: isCodex && _codexWebSearchTouched,
      planMode: isCodex ? false : _planMode,
      useWorktree: useExisting ? false : _useWorktree,
      worktreeBranch: useExisting
          ? _selectedWorktree?.branch
          : (branch.isNotEmpty ? branch : null),
      existingWorktreePath: useExisting
          ? _selectedWorktree?.worktreePath
          : null,
      model: isCodex ? _selectedModel : null,
      sandboxMode: _sandboxMode,
      modelReasoningEffort: isCodex ? _modelReasoningEffort : null,
      networkAccessEnabled: isCodex ? _networkAccessEnabled : null,
      webSearchMode: isCodex ? _webSearchMode : null,
      additionalWritableRoots: isCodex ? _additionalWritableRoots : const [],
      claudeModel: !isCodex ? _selectedClaudeModel : null,
      claudeEffort: !isCodex ? _claudeEffort : null,
      claudeMaxTurns: !isCodex ? claudeMaxTurns : null,
      claudeMaxBudgetUsd: !isCodex ? claudeMaxBudgetUsd : null,
      claudeFallbackModel: !isCodex ? _selectedClaudeFallbackModel : null,
      claudeForkSession: !isCodex ? _claudeForkSession : null,
      claudePersistSession: !isCodex ? _claudePersistSession : null,
    );
  }

  void _start() {
    // Run inline validation
    final turnsOk = _validateMaxTurns();
    final budgetOk = _validateMaxBudget();
    if (!turnsOk || !budgetOk) {
      setState(() {});
      return;
    }

    Navigator.pop(context, _buildParams());
  }

  InputDecoration _buildInputDecoration(
    String label, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: prefixIcon,
      errorText: errorText,
      isDense: true,
      filled: true,
      fillColor: cs.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _buildPage(Provider pageProvider) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final accent = providerStyleFor(context, pageProvider).foreground;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_effectiveProjects.isNotEmpty) ...[
            _RecentProjectsSection(
              appColors: appColors,
              accentColor: accent,
              projects: _effectiveProjects,
              selectedPath: _pathController.text,
              onProjectSelected: _onProjectSelected,
              onProjectRemoved: _onProjectRemoved,
              canExpand: _canExpandProjects,
              isExpanded: _isProjectListExpanded,
              onToggleExpand: () {
                setState(() {
                  _isProjectListExpanded = !_isProjectListExpanded;
                });
              },
            ),
            _SheetDivider(appColors: appColors),
          ],
          if ((widget.bridge?.allowedDirs.length ?? 0) > 1)
            _AllowedDirChips(
              dirs: widget.bridge!.allowedDirs,
              onSelected: (dir) {
                final prefix = dir.endsWith('/') ? dir : '$dir/';
                setState(() {
                  _pathController.text = prefix;
                  _pathController.selection = TextSelection.collapsed(
                    offset: prefix.length,
                  );
                });
              },
            ),
          _PathInput(
            controller: _pathController,
            decoration: _buildInputDecoration(
              AppLocalizations.of(context).projectPath,
              hintText: AppLocalizations.of(context).projectPathHint,
            ),
            onChanged: () => setState(() {}),
          ),
          if (pageProvider == Provider.codex) ...[
            const SizedBox(height: 12),
            _AdditionalWritableRootsSection(
              roots: _additionalWritableRoots,
              onAddPressed: _openAddWritableRootSheet,
              onDeleted: _removeWritableRoot,
            ),
          ],
          const SizedBox(height: 12),
          _OptionsSection(
            appColors: appColors,
            provider: pageProvider,
            claudePermissionMode: _claudePermissionMode,
            onClaudePermissionModeChanged: (value) {
              setState(() => _claudePermissionMode = value);
            },
            executionMode: _executionMode,
            onExecutionModeChanged: (value) {
              setState(() => _executionMode = value);
            },
            codexApprovalPolicy: _codexApprovalPolicy,
            codexAutoReviewEnabled: _codexAutoReviewEnabled,
            onCodexApprovalChoiceChanged: (value) {
              setState(() {
                _codexApprovalPolicy = value.policy;
                _codexAutoReviewEnabled = value.autoReviewEnabled;
                _codexApprovalPolicyTouched = true;
                _codexAutoReviewTouched = true;
              });
            },
            codexProfiles: _codexProfiles,
            selectedCodexProfile: _selectedCodexProfile,
            onCodexProfileChanged: (value) {
              setState(() {
                _selectedCodexProfile = value;
              });
            },
            planMode: _planMode,
            onPlanModeChanged: (value) {
              setState(() => _planMode = value);
            },
            useWorktree: _useWorktree,
            onWorktreeToggle: _onWorktreeToggle,
            worktreeMode: _worktreeMode,
            onWorktreeModeChanged: (mode) {
              setState(() {
                _worktreeMode = mode;
                if (mode == _WorktreeMode.createNew) {
                  _selectedWorktree = null;
                }
              });
            },
            worktrees: _worktrees,
            selectedWorktree: _selectedWorktree,
            onWorktreeSelected: (wt) {
              setState(() => _selectedWorktree = wt);
            },
            branchController: _branchController,
            buildInputDecoration: _buildInputDecoration,
            // Claude advanced
            claudeModels: _claudeModelList,
            selectedClaudeModel: _selectedClaudeModel,
            onClaudeModelChanged: (value) {
              setState(() => _selectedClaudeModel = value);
            },
            claudeEffort: _claudeEffort,
            onClaudeEffortChanged: (value) {
              setState(() => _claudeEffort = value);
            },
            claudeMaxTurnsController: _claudeMaxTurnsController,
            maxTurnsError: _maxTurnsError,
            onMaxTurnsChanged: () {
              setState(() => _validateMaxTurns());
            },
            claudeMaxBudgetController: _claudeMaxBudgetController,
            maxBudgetError: _maxBudgetError,
            onMaxBudgetChanged: () {
              setState(() => _validateMaxBudget());
            },
            selectedClaudeFallbackModel: _selectedClaudeFallbackModel,
            onClaudeFallbackModelChanged: (value) {
              setState(() => _selectedClaudeFallbackModel = value);
            },
            claudeForkSession: _claudeForkSession,
            onClaudeForkSessionChanged: (value) {
              setState(() => _claudeForkSession = value);
            },
            claudePersistSession: _claudePersistSession,
            onClaudePersistSessionChanged: (value) {
              setState(() => _claudePersistSession = value);
            },
            // Codex advanced
            codexModels: _codexModelList,
            selectedModel: _selectedModel,
            onSelectedModelChanged: (value) {
              setState(() {
                _selectedModel = value;
                _codexModelTouched = true;
              });
            },
            sandboxMode: _sandboxMode,
            onSandboxModeChanged: (value) {
              setState(() {
                _sandboxMode = value;
                if (_provider == Provider.codex) {
                  _codexSandboxModeTouched = true;
                }
              });
            },
            modelReasoningEffort: _modelReasoningEffort,
            onModelReasoningEffortChanged: (value) {
              setState(() {
                _modelReasoningEffort = value;
                _codexReasoningEffortTouched = true;
              });
            },
            webSearchMode: _webSearchMode,
            onWebSearchModeChanged: (value) {
              setState(() {
                _webSearchMode = value;
                _codexWebSearchTouched = true;
              });
            },
            networkAccessEnabled: _networkAccessEnabled,
            onNetworkAccessChanged: (value) {
              setState(() {
                _networkAccessEnabled = value;
                _codexNetworkAccessTouched = true;
              });
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _onProviderChanged(Provider p) {
    setState(() => _provider = p);
    final page = widget.visibleTabs
        .indexWhere((t) => t.toProvider() == p)
        .clamp(0, widget.visibleTabs.length - 1);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Desktop keyboard shortcut handler for the new session sheet.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Tab: cycle provider (only when not locked, multiple tabs, and no text field focused)
    if (event.logicalKey == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isShiftPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !widget.lockProvider &&
        widget.visibleTabs.length > 1) {
      // Only toggle if no text field has focus (check for primary focus)
      final focus = FocusManager.instance.primaryFocus;
      final isInTextField = focus?.context?.widget is EditableText;
      if (!isInTextField) {
        final currentIndex = widget.visibleTabs.indexWhere(
          (t) => t.toProvider() == _provider,
        );
        final nextIndex = (currentIndex + 1) % widget.visibleTabs.length;
        _onProviderChanged(widget.visibleTabs[nextIndex].toProvider());
        return KeyEventResult.handled;
      }
    }

    // Cmd+Enter: start session
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        HardwareKeyboard.instance.isMetaPressed) {
      if (_hasPath) _start();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DragHandle(appColors: appColors),
              _SheetTitle(
                provider: _provider,
                lockProvider: widget.lockProvider,
                visibleTabs: widget.visibleTabs,
                onProviderChanged: _onProviderChanged,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: widget.lockProvider || widget.visibleTabs.length <= 1
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  onPageChanged: (index) {
                    setState(() {
                      _provider = widget.visibleTabs[index].toProvider();
                    });
                  },
                  children: [
                    for (final tab in widget.visibleTabs)
                      _buildPage(tab.toProvider()),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SheetActions(
                provider: _provider,
                canStart:
                    _hasPath &&
                    (!_useWorktree ||
                        _worktreeMode == _WorktreeMode.createNew ||
                        _selectedWorktree != null),
                onStart: _start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Extracted StatelessWidget classes
// ---------------------------------------------------------------------------

class _DragHandle extends StatelessWidget {
  final AppColors appColors;

  const _DragHandle({required this.appColors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: appColors.subtleText.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final Provider provider;
  final bool lockProvider;
  final List<NewSessionTab> visibleTabs;
  final ValueChanged<Provider> onProviderChanged;

  const _SheetTitle({
    required this.provider,
    required this.lockProvider,
    required this.visibleTabs,
    required this.onProviderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final showToggle = visibleTabs.length > 1 && !lockProvider;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.newSession,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (showToggle) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  for (final tab in visibleTabs)
                    Expanded(
                      child: _ProviderToggleButton(
                        provider: tab.toProvider(),
                        isSelected: provider == tab.toProvider(),
                        isLocked: lockProvider,
                        onTap: () {
                          if (!lockProvider) {
                            onProviderChanged(tab.toProvider());
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentProjectsSection extends StatelessWidget {
  final AppColors appColors;
  final Color accentColor;
  final List<({String path, String name})> projects;
  final String selectedPath;
  final ValueChanged<String> onProjectSelected;
  final Future<void> Function(String path)? onProjectRemoved;
  final bool canExpand;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  const _RecentProjectsSection({
    required this.appColors,
    required this.accentColor,
    required this.projects,
    required this.selectedPath,
    required this.onProjectSelected,
    this.onProjectRemoved,
    this.canExpand = false,
    this.isExpanded = false,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l.recentProjects,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: appColors.subtleText,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final project in projects)
          Slidable(
            key: ValueKey('project_${project.path}'),
            endActionPane: onProjectRemoved != null
                ? ActionPane(
                    motion: const BehindMotion(),
                    extentRatio: 0.18,
                    children: [
                      CustomSlidableAction(
                        onPressed: (_) => onProjectRemoved?.call(project.path),
                        backgroundColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
            child: _ProjectTile(
              project: project,
              appColors: appColors,
              accentColor: accentColor,
              isSelected: selectedPath == project.path,
              onTap: () => onProjectSelected(project.path),
            ),
          ),
        if (canExpand)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              onPressed: onToggleExpand,
              icon: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 18,
              ),
              label: Text(
                isExpanded ? l.showLess : l.showMore,
                style: const TextStyle(fontSize: 13),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final ({String path, String name}) project;
  final AppColors appColors;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProjectTile({
    required this.project,
    required this.appColors,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                Icons.folder_outlined,
                size: 22,
                color: isSelected ? accentColor : appColors.subtleText,
              ),
              title: Text(
                project.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? accentColor : null,
                ),
              ),
              subtitle: Text(
                shortenPath(project.path),
                style: TextStyle(fontSize: 11, color: appColors.subtleText),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle, size: 20, color: accentColor)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  final AppColors appColors;

  const _SheetDivider({required this.appColors});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: appColors.subtleText.withValues(alpha: 0.2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l.orEnterPath,
              style: TextStyle(fontSize: 11, color: appColors.subtleText),
            ),
          ),
          Expanded(
            child: Divider(color: appColors.subtleText.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }
}

class _AllowedDirChips extends StatelessWidget {
  final List<String> dirs;
  final ValueChanged<String> onSelected;

  const _AllowedDirChips({required this.dirs, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: dirs.map((dir) {
          final trimmed = dir.endsWith('/')
              ? dir.substring(0, dir.length - 1)
              : dir;
          final label = trimmed.split('/').last;
          return ActionChip(
            label: Text(label),
            avatar: const Icon(Icons.folder, size: 16),
            onPressed: () => onSelected(dir),
          );
        }).toList(),
      ),
    );
  }
}

class _PathInput extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final VoidCallback onChanged;

  const _PathInput({
    required this.controller,
    required this.decoration,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        key: const ValueKey('dialog_project_path'),
        controller: controller,
        decoration: decoration,
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _AdditionalWritableRootsSection extends StatelessWidget {
  final List<String> roots;
  final VoidCallback onAddPressed;
  final ValueChanged<String> onDeleted;

  const _AdditionalWritableRootsSection({
    required this.roots,
    required this.onAddPressed,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final infoButton = _AdditionalWritableRootsInfoButton(
      message:
          '${l.additionalWritableRootsDescription}\n${l.additionalWritableRootsTooltip}',
    );
    final addButton = ActionChip(
      key: const ValueKey('additional_writable_root_add_button'),
      avatar: const Icon(Icons.add, size: 18),
      label: Text(l.add),
      onPressed: onAddPressed,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.create_new_folder_outlined,
                  size: 18,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.additionalWritableRootsTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                infoButton,
                const SizedBox(width: 8),
                addButton,
              ],
            ),
            if (roots.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final root in roots)
                    InputChip(
                      key: ValueKey(
                        'additional_writable_root_${root.hashCode}',
                      ),
                      label: Text(shortenPath(root)),
                      tooltip: root,
                      onDeleted: () => onDeleted(root),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdditionalWritableRootsInfoButton extends StatefulWidget {
  final String message;

  const _AdditionalWritableRootsInfoButton({required this.message});

  @override
  State<_AdditionalWritableRootsInfoButton> createState() =>
      _AdditionalWritableRootsInfoButtonState();
}

class _AdditionalWritableRootsInfoButtonState
    extends State<_AdditionalWritableRootsInfoButton> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      key: _tooltipKey,
      message: widget.message,
      triggerMode: TooltipTriggerMode.manual,
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
        onPressed: () => _tooltipKey.currentState?.ensureTooltipVisible(),
      ),
    );
  }
}

Future<String?> _showAddWritableRootSheet({
  required BuildContext context,
  required TextEditingController controller,
  required List<String> suggestions,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _AddWritableRootSheet(controller: controller, suggestions: suggestions),
  );
}

class _AddWritableRootSheet extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;

  const _AddWritableRootSheet({
    required this.controller,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.addDirectory,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l.additionalWritableRootsTooltip,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('additional_writable_root_field'),
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l.directoryPath,
                hintText: '/Users/me/Workspace/other-project',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isNotEmpty) Navigator.pop(context, trimmed);
              },
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l.additionalWritableRootsSuggestions,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in suggestions)
                    ActionChip(
                      label: Text(shortenPath(suggestion)),
                      tooltip: suggestion,
                      onPressed: () => Navigator.pop(context, suggestion),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const ValueKey('additional_writable_root_submit_button'),
                  onPressed: () {
                    final trimmed = controller.text.trim();
                    if (trimmed.isNotEmpty) Navigator.pop(context, trimmed);
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionsSection extends StatelessWidget {
  final AppColors appColors;
  final Provider provider;
  final PermissionMode claudePermissionMode;
  final ValueChanged<PermissionMode> onClaudePermissionModeChanged;
  final ExecutionMode executionMode;
  final ValueChanged<ExecutionMode> onExecutionModeChanged;
  final CodexApprovalPolicy codexApprovalPolicy;
  final bool codexAutoReviewEnabled;
  final ValueChanged<_CodexApprovalChoice> onCodexApprovalChoiceChanged;
  final List<String> codexProfiles;
  final String? selectedCodexProfile;
  final ValueChanged<String?> onCodexProfileChanged;
  final bool planMode;
  final ValueChanged<bool> onPlanModeChanged;
  final bool useWorktree;
  final ValueChanged<bool> onWorktreeToggle;
  final _WorktreeMode worktreeMode;
  final ValueChanged<_WorktreeMode> onWorktreeModeChanged;
  final List<WorktreeInfo>? worktrees;
  final WorktreeInfo? selectedWorktree;
  final ValueChanged<WorktreeInfo> onWorktreeSelected;
  final TextEditingController branchController;
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;

  // Claude advanced
  final List<String> claudeModels;
  final String? selectedClaudeModel;
  final ValueChanged<String?> onClaudeModelChanged;
  final ClaudeEffort claudeEffort;
  final ValueChanged<ClaudeEffort> onClaudeEffortChanged;
  final TextEditingController claudeMaxTurnsController;
  final String? maxTurnsError;
  final VoidCallback onMaxTurnsChanged;
  final TextEditingController claudeMaxBudgetController;
  final String? maxBudgetError;
  final VoidCallback onMaxBudgetChanged;
  final String? selectedClaudeFallbackModel;
  final ValueChanged<String?> onClaudeFallbackModelChanged;
  final bool claudeForkSession;
  final ValueChanged<bool> onClaudeForkSessionChanged;
  final bool claudePersistSession;
  final ValueChanged<bool> onClaudePersistSessionChanged;

  // Codex advanced
  final List<String> codexModels;
  final String? selectedModel;
  final ValueChanged<String?> onSelectedModelChanged;
  final SandboxMode sandboxMode;
  final ValueChanged<SandboxMode> onSandboxModeChanged;
  final ReasoningEffort modelReasoningEffort;
  final ValueChanged<ReasoningEffort> onModelReasoningEffortChanged;
  final WebSearchMode? webSearchMode;
  final ValueChanged<WebSearchMode?> onWebSearchModeChanged;
  final bool networkAccessEnabled;
  final ValueChanged<bool> onNetworkAccessChanged;

  const _OptionsSection({
    required this.appColors,
    required this.provider,
    required this.claudePermissionMode,
    required this.onClaudePermissionModeChanged,
    required this.executionMode,
    required this.onExecutionModeChanged,
    required this.codexApprovalPolicy,
    required this.codexAutoReviewEnabled,
    required this.onCodexApprovalChoiceChanged,
    required this.codexProfiles,
    required this.selectedCodexProfile,
    required this.onCodexProfileChanged,
    required this.planMode,
    required this.onPlanModeChanged,
    required this.useWorktree,
    required this.onWorktreeToggle,
    required this.worktreeMode,
    required this.onWorktreeModeChanged,
    required this.worktrees,
    required this.selectedWorktree,
    required this.onWorktreeSelected,
    required this.branchController,
    required this.buildInputDecoration,
    required this.claudeModels,
    required this.selectedClaudeModel,
    required this.onClaudeModelChanged,
    required this.claudeEffort,
    required this.onClaudeEffortChanged,
    required this.claudeMaxTurnsController,
    required this.maxTurnsError,
    required this.onMaxTurnsChanged,
    required this.claudeMaxBudgetController,
    required this.maxBudgetError,
    required this.onMaxBudgetChanged,
    required this.selectedClaudeFallbackModel,
    required this.onClaudeFallbackModelChanged,
    required this.claudeForkSession,
    required this.onClaudeForkSessionChanged,
    required this.claudePersistSession,
    required this.onClaudePersistSessionChanged,
    required this.codexModels,
    required this.selectedModel,
    required this.onSelectedModelChanged,
    required this.sandboxMode,
    required this.onSandboxModeChanged,
    required this.modelReasoningEffort,
    required this.onModelReasoningEffortChanged,
    required this.webSearchMode,
    required this.onWebSearchModeChanged,
    required this.networkAccessEnabled,
    required this.onNetworkAccessChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selectedPermissionMode = provider == Provider.claude
        ? claudePermissionMode
        : legacyPermissionModeFromModes(
            provider,
            executionMode: executionMode,
            planMode: planMode,
          );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final autoModeColor = isDark
        ? appColors.warningText
        : appColors.warningBubbleBorder;

    // -- Description helpers --

    String permissionDescription(PermissionMode mode) {
      return switch (mode) {
        PermissionMode.defaultMode => l.permissionDefaultDescription,
        PermissionMode.auto => l.permissionAutoDescription,
        PermissionMode.acceptEdits => l.permissionAcceptEditsDescription,
        PermissionMode.plan => l.permissionPlanDescription,
        PermissionMode.bypassPermissions => l.permissionBypassDescription,
      };
    }

    String sandboxDescription(SandboxMode mode) {
      final isClaude = provider == Provider.claude;
      if (isClaude) {
        return mode == SandboxMode.on
            ? l.sandboxRestrictedDescription
            : l.sandboxNativeDescription;
      }
      return mode == SandboxMode.on
          ? l.sandboxRestrictedDescription
          : l.sandboxNativeCautionDescription;
    }

    // -- Icon helpers --

    final codexApprovalChoice = _CodexApprovalChoice.from(
      policy: codexApprovalPolicy,
      autoReviewEnabled: codexAutoReviewEnabled,
    );

    IconData codexApprovalIcon(_CodexApprovalChoice choice) => switch (choice) {
      _CodexApprovalChoice.untrusted => Icons.verified_user_outlined,
      _CodexApprovalChoice.onRequest => Icons.tune,
      _CodexApprovalChoice.autoReview => Icons.auto_mode_outlined,
      _CodexApprovalChoice.never => Icons.flash_on,
    };

    String codexApprovalLabel(_CodexApprovalChoice choice) => switch (choice) {
      _CodexApprovalChoice.untrusted => 'Untrusted',
      _CodexApprovalChoice.onRequest => 'On Request',
      _CodexApprovalChoice.autoReview => 'Auto Review',
      _CodexApprovalChoice.never => 'Never Ask',
    };

    String codexApprovalDescription(_CodexApprovalChoice choice) {
      return switch (choice) {
        _CodexApprovalChoice.untrusted => l.codexApprovalUntrustedDescription,
        _CodexApprovalChoice.onRequest => l.codexApprovalOnRequestDescription,
        _CodexApprovalChoice.autoReview => l.codexAutoReviewDescription,
        _CodexApprovalChoice.never => l.codexApprovalNeverDescription,
      };
    }

    IconData permissionIcon(PermissionMode mode) => switch (mode) {
      PermissionMode.defaultMode => Icons.tune,
      PermissionMode.auto => Icons.auto_mode_outlined,
      PermissionMode.acceptEdits => Icons.edit_note,
      PermissionMode.plan => Icons.assignment_outlined,
      PermissionMode.bypassPermissions => Icons.flash_on,
    };

    final isClaude = provider == Provider.claude;

    IconData sandboxIcon(SandboxMode mode) => mode == SandboxMode.on
        ? Icons.shield_outlined
        : (isClaude ? Icons.code : Icons.warning_amber);

    String sandboxLabel(SandboxMode mode) => isClaude
        ? (mode == SandboxMode.on ? 'Sandbox (Safe Mode)' : 'Standard')
        : mode.label;

    // -- Selector field widget (shows current selection with description) --

    Widget modeSelectorField({
      required String label,
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      Color? accentColor,
      Key? key,
    }) {
      final cs = Theme.of(context).colorScheme;
      return InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: buildInputDecoration(label).copyWith(
            suffixIcon: Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 13, color: accentColor),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // -- BottomSheet helpers --

    void showModeSheet<T>({
      required String title,
      String? subtitle,
      required List<T> modes,
      required T currentMode,
      required IconData Function(T) iconFor,
      required String Function(T) labelFor,
      required String Function(T) descriptionFor,
      required ValueChanged<T> onSelected,
      Color Function(T, ColorScheme)? colorFor,
    }) {
      showModalBottomSheet(
        context: context,
        builder: (sheetContext) {
          final sheetCs = Theme.of(sheetContext).colorScheme;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: sheetCs.onSurface,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: sheetCs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final mode in modes)
                          ListTile(
                            leading: Icon(
                              iconFor(mode),
                              color: mode == currentMode
                                  ? (colorFor?.call(mode, sheetCs) ??
                                        sheetCs.primary)
                                  : sheetCs.onSurfaceVariant,
                            ),
                            title: Text(labelFor(mode)),
                            subtitle: descriptionFor(mode).isNotEmpty
                                ? Text(
                                    descriptionFor(mode),
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                            trailing: mode == currentMode
                                ? Icon(
                                    Icons.check,
                                    color:
                                        colorFor?.call(mode, sheetCs) ??
                                        sheetCs.primary,
                                    size: 20,
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              onSelected(mode);
                            },
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Environment',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: appColors.subtleText,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (provider == Provider.codex && codexProfiles.isNotEmpty) ...[
            DropdownButtonFormField<String?>(
              key: const ValueKey('dialog_codex_profile'),
              initialValue: selectedCodexProfile,
              isExpanded: true,
              decoration: buildInputDecoration('Profile'),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    l.defaultLabel,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                for (final profile in codexProfiles)
                  DropdownMenuItem<String?>(
                    value: profile,
                    child: Text(profile, style: const TextStyle(fontSize: 13)),
                  ),
              ],
              onChanged: onCodexProfileChanged,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l.codexProfilePrecedenceNote,
                style: TextStyle(
                  fontSize: 12,
                  color: appColors.subtleText,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          provider == Provider.codex
              ? modeSelectorField(
                  key: const ValueKey('dialog_codex_approval_policy'),
                  label: l.approval,
                  icon: codexApprovalIcon(codexApprovalChoice),
                  title: codexApprovalLabel(codexApprovalChoice),
                  subtitle: codexApprovalDescription(codexApprovalChoice),
                  onTap: () => showModeSheet<_CodexApprovalChoice>(
                    title: l.approval,
                    subtitle: l.sheetSubtitleApproval,
                    modes: const [
                      _CodexApprovalChoice.untrusted,
                      _CodexApprovalChoice.onRequest,
                      _CodexApprovalChoice.autoReview,
                      _CodexApprovalChoice.never,
                    ],
                    currentMode: codexApprovalChoice,
                    iconFor: codexApprovalIcon,
                    labelFor: codexApprovalLabel,
                    descriptionFor: codexApprovalDescription,
                    onSelected: onCodexApprovalChoiceChanged,
                    colorFor: (mode, cs) => switch (mode) {
                      _CodexApprovalChoice.never => cs.error,
                      _CodexApprovalChoice.autoReview => cs.primary,
                      _ => cs.primary,
                    },
                  ),
                )
              : modeSelectorField(
                  key: const ValueKey('dialog_permission_mode'),
                  label: l.approval,
                  icon: permissionIcon(selectedPermissionMode),
                  title: selectedPermissionMode.label,
                  subtitle: permissionDescription(selectedPermissionMode),
                  accentColor: switch (selectedPermissionMode) {
                    PermissionMode.auto => autoModeColor,
                    PermissionMode.bypassPermissions => Theme.of(
                      context,
                    ).colorScheme.error,
                    _ => null,
                  },
                  onTap: () => showModeSheet<PermissionMode>(
                    title: l.approval,
                    subtitle: l.sheetSubtitleApproval,
                    modes: PermissionMode.values,
                    currentMode: selectedPermissionMode,
                    iconFor: permissionIcon,
                    labelFor: (m) => m.label,
                    descriptionFor: permissionDescription,
                    onSelected: (value) {
                      onClaudePermissionModeChanged(value);
                      switch (value) {
                        case PermissionMode.defaultMode:
                          onExecutionModeChanged(ExecutionMode.defaultMode);
                          onPlanModeChanged(false);
                        case PermissionMode.auto:
                          onExecutionModeChanged(ExecutionMode.defaultMode);
                          onPlanModeChanged(false);
                        case PermissionMode.acceptEdits:
                          onExecutionModeChanged(ExecutionMode.acceptEdits);
                          onPlanModeChanged(false);
                        case PermissionMode.plan:
                          onExecutionModeChanged(ExecutionMode.defaultMode);
                          onPlanModeChanged(true);
                        case PermissionMode.bypassPermissions:
                          onExecutionModeChanged(ExecutionMode.fullAccess);
                          onPlanModeChanged(false);
                      }
                    },
                    colorFor: (mode, cs) => switch (mode) {
                      PermissionMode.auto => autoModeColor,
                      PermissionMode.bypassPermissions => cs.error,
                      _ => cs.primary,
                    },
                  ),
                ),
          const SizedBox(height: 8),
          modeSelectorField(
            key: const ValueKey('dialog_sandbox'),
            label: l.sandbox,
            icon: sandboxIcon(sandboxMode),
            title: sandboxLabel(sandboxMode),
            subtitle: sandboxDescription(sandboxMode),
            onTap: () => showModeSheet<SandboxMode>(
              title: l.sandbox,
              subtitle: isClaude
                  ? l.sheetSubtitleSandboxClaude
                  : l.sheetSubtitleSandboxCodex,
              modes: isClaude
                  ? SandboxMode.values.reversed.toList()
                  : SandboxMode.values,
              currentMode: sandboxMode,
              iconFor: sandboxIcon,
              labelFor: sandboxLabel,
              descriptionFor: sandboxDescription,
              onSelected: onSandboxModeChanged,
              colorFor: (mode, cs) {
                if (!isClaude && mode == SandboxMode.off) return cs.error;
                return cs.primary;
              },
            ),
          ),
          const SizedBox(height: 8),
          // -- Model selector --
          modeSelectorField(
            key: ValueKey(
              provider == Provider.claude
                  ? 'dialog_claude_model'
                  : 'dialog_codex_model',
            ),
            label: l.model,
            icon: Icons.smart_toy_outlined,
            title: provider == Provider.claude
                ? (selectedClaudeModel ?? claudeModels.firstOrNull ?? '')
                : (selectedModel ?? codexModels.firstOrNull ?? ''),
            subtitle: '',
            onTap: () {
              final models = provider == Provider.claude
                  ? claudeModels
                  : codexModels;
              final current = provider == Provider.claude
                  ? (selectedClaudeModel ?? models.firstOrNull)
                  : (selectedModel ?? models.firstOrNull);
              final onChanged = provider == Provider.claude
                  ? onClaudeModelChanged
                  : onSelectedModelChanged;
              showModeSheet<String>(
                title: l.model,
                subtitle: l.sheetSubtitleModel,
                modes: models,
                currentMode: current ?? '',
                iconFor: (_) => Icons.smart_toy_outlined,
                labelFor: (m) => m,
                descriptionFor: (_) => '',
                onSelected: (m) => onChanged(m),
              );
            },
          ),
          const SizedBox(height: 8),
          // -- Effort / Reasoning selector --
          // Claude Effort is only meaningful for Opus models.
          if (provider == Provider.claude &&
              _isOpusModel(selectedClaudeModel ?? claudeModels.firstOrNull))
            modeSelectorField(
              key: const ValueKey('dialog_claude_effort'),
              label: l.effort,
              icon: Icons.speed,
              title: claudeEffort.label,
              subtitle: _claudeEffortDescription(claudeEffort, l),
              onTap: () => showModeSheet<ClaudeEffort>(
                title: l.effort,
                subtitle: l.sheetSubtitleEffort,
                modes: ClaudeEffort.values,
                currentMode: claudeEffort,
                iconFor: (_) => Icons.speed,
                labelFor: (e) => e.label,
                descriptionFor: (e) => _claudeEffortDescription(e, l),
                onSelected: onClaudeEffortChanged,
              ),
            ),
          if (provider == Provider.codex)
            modeSelectorField(
              key: const ValueKey('dialog_codex_reasoning_effort'),
              label: l.reasoning,
              icon: Icons.psychology,
              title: modelReasoningEffort.label,
              subtitle: _reasoningEffortDescription(modelReasoningEffort, l),
              onTap: () => showModeSheet<ReasoningEffort>(
                title: l.reasoning,
                subtitle: l.sheetSubtitleEffort,
                modes: ReasoningEffort.values,
                currentMode: modelReasoningEffort,
                iconFor: (_) => Icons.psychology,
                labelFor: (e) => e.label,
                descriptionFor: (e) => _reasoningEffortDescription(e, l),
                onSelected: onModelReasoningEffortChanged,
              ),
            ),
          const SizedBox(height: 8),
          // Worktree toggle (shared) + inline options when expanded
          _WorktreeToggleTile(
            useWorktree: useWorktree,
            onChanged: onWorktreeToggle,
            worktreeOptions: useWorktree
                ? _WorktreeOptions(
                    appColors: appColors,
                    worktreeMode: worktreeMode,
                    onWorktreeModeChanged: onWorktreeModeChanged,
                    worktrees: worktrees,
                    selectedWorktree: selectedWorktree,
                    onWorktreeSelected: onWorktreeSelected,
                    branchController: branchController,
                    buildInputDecoration: buildInputDecoration,
                  )
                : null,
          ),
          // Advanced section (unified for both providers)
          const SizedBox(height: 8),
          _AdvancedOptions(
            provider: provider,
            buildInputDecoration: buildInputDecoration,
            // Claude
            claudeModels: claudeModels,
            claudeMaxTurnsController: claudeMaxTurnsController,
            maxTurnsError: maxTurnsError,
            onMaxTurnsChanged: onMaxTurnsChanged,
            claudeMaxBudgetController: claudeMaxBudgetController,
            maxBudgetError: maxBudgetError,
            onMaxBudgetChanged: onMaxBudgetChanged,
            selectedClaudeFallbackModel: selectedClaudeFallbackModel,
            onClaudeFallbackModelChanged: onClaudeFallbackModelChanged,
            claudeForkSession: claudeForkSession,
            onClaudeForkSessionChanged: onClaudeForkSessionChanged,
            claudePersistSession: claudePersistSession,
            onClaudePersistSessionChanged: onClaudePersistSessionChanged,
            // Codex
            webSearchMode: webSearchMode,
            onWebSearchModeChanged: onWebSearchModeChanged,
            networkAccessEnabled: networkAccessEnabled,
            onNetworkAccessChanged: onNetworkAccessChanged,
          ),
        ],
      ),
    );
  }
}

class _WorktreeToggleTile extends StatelessWidget {
  final bool useWorktree;
  final ValueChanged<bool> onChanged;
  final Widget? worktreeOptions;

  const _WorktreeToggleTile({
    required this.useWorktree,
    required this.onChanged,
    this.worktreeOptions,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const ValueKey('dialog_worktree'),
            borderRadius: worktreeOptions != null
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            onTap: () => onChanged(!useWorktree),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 18,
                    color: useWorktree ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.worktree,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tooltip(
                    message:
                        'Creates an isolated git working tree for this session.',
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IgnorePointer(
                    child: Switch.adaptive(
                      value: useWorktree,
                      onChanged: onChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (worktreeOptions != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: worktreeOptions!,
            ),
        ],
      ),
    );
  }
}

bool _isOpusModel(String? model) {
  if (model == null) return true; // default model may be opus
  return model.toLowerCase().contains('opus');
}

String _claudeEffortDescription(ClaudeEffort effort, AppLocalizations l) {
  return switch (effort) {
    ClaudeEffort.low => l.claudeEffortLowDesc,
    ClaudeEffort.medium => l.claudeEffortMediumDesc,
    ClaudeEffort.high => l.claudeEffortHighDesc,
    ClaudeEffort.max => l.claudeEffortMaxDesc,
  };
}

String _reasoningEffortDescription(ReasoningEffort effort, AppLocalizations l) {
  return switch (effort) {
    ReasoningEffort.minimal => l.reasoningEffortMinimalDesc,
    ReasoningEffort.low => l.reasoningEffortLowDesc,
    ReasoningEffort.medium => l.reasoningEffortMediumDesc,
    ReasoningEffort.high => l.reasoningEffortHighDesc,
    ReasoningEffort.xhigh => l.reasoningEffortXhighDesc,
  };
}

class _ResponsiveOptionRow extends StatelessWidget {
  final Widget leading;
  final Widget trailing;

  const _ResponsiveOptionRow({required this.leading, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [leading, const SizedBox(height: 8), trailing],
          );
        }

        return Row(
          children: [
            Expanded(child: leading),
            const SizedBox(width: 12),
            Expanded(child: trailing),
          ],
        );
      },
    );
  }
}

class _AdvancedOptions extends StatelessWidget {
  final Provider provider;
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;

  // Claude
  final List<String> claudeModels;
  final TextEditingController claudeMaxTurnsController;
  final String? maxTurnsError;
  final VoidCallback onMaxTurnsChanged;
  final TextEditingController claudeMaxBudgetController;
  final String? maxBudgetError;
  final VoidCallback onMaxBudgetChanged;
  final String? selectedClaudeFallbackModel;
  final ValueChanged<String?> onClaudeFallbackModelChanged;
  final bool claudeForkSession;
  final ValueChanged<bool> onClaudeForkSessionChanged;
  final bool claudePersistSession;
  final ValueChanged<bool> onClaudePersistSessionChanged;

  // Codex
  final WebSearchMode? webSearchMode;
  final ValueChanged<WebSearchMode?> onWebSearchModeChanged;
  final bool networkAccessEnabled;
  final ValueChanged<bool> onNetworkAccessChanged;

  const _AdvancedOptions({
    required this.provider,
    required this.buildInputDecoration,
    required this.claudeModels,
    required this.claudeMaxTurnsController,
    required this.maxTurnsError,
    required this.onMaxTurnsChanged,
    required this.claudeMaxBudgetController,
    required this.maxBudgetError,
    required this.onMaxBudgetChanged,
    required this.selectedClaudeFallbackModel,
    required this.onClaudeFallbackModelChanged,
    required this.claudeForkSession,
    required this.onClaudeForkSessionChanged,
    required this.claudePersistSession,
    required this.onClaudePersistSessionChanged,
    required this.webSearchMode,
    required this.onWebSearchModeChanged,
    required this.networkAccessEnabled,
    required this.onNetworkAccessChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: ValueKey('dialog_advanced_${provider.value}'),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Text(
          l.advanced,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: provider == Provider.claude
            ? _ClaudeAdvancedOptions(
                buildInputDecoration: buildInputDecoration,
                claudeModels: claudeModels,
                claudeMaxTurnsController: claudeMaxTurnsController,
                maxTurnsError: maxTurnsError,
                onMaxTurnsChanged: onMaxTurnsChanged,
                claudeMaxBudgetController: claudeMaxBudgetController,
                maxBudgetError: maxBudgetError,
                onMaxBudgetChanged: onMaxBudgetChanged,
                selectedClaudeFallbackModel: selectedClaudeFallbackModel,
                onClaudeFallbackModelChanged: onClaudeFallbackModelChanged,
                claudeForkSession: claudeForkSession,
                onClaudeForkSessionChanged: onClaudeForkSessionChanged,
                claudePersistSession: claudePersistSession,
                onClaudePersistSessionChanged: onClaudePersistSessionChanged,
              ).buildChildren(context)
            : _CodexAdvancedOptions(
                buildInputDecoration: buildInputDecoration,
                webSearchMode: webSearchMode,
                onWebSearchModeChanged: onWebSearchModeChanged,
                networkAccessEnabled: networkAccessEnabled,
                onNetworkAccessChanged: onNetworkAccessChanged,
              ).buildChildren(context),
      ),
    );
  }
}

class _ClaudeAdvancedOptions extends StatelessWidget {
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;
  final List<String> claudeModels;
  final TextEditingController claudeMaxTurnsController;
  final String? maxTurnsError;
  final VoidCallback onMaxTurnsChanged;
  final TextEditingController claudeMaxBudgetController;
  final String? maxBudgetError;
  final VoidCallback onMaxBudgetChanged;
  final String? selectedClaudeFallbackModel;
  final ValueChanged<String?> onClaudeFallbackModelChanged;
  final bool claudeForkSession;
  final ValueChanged<bool> onClaudeForkSessionChanged;
  final bool claudePersistSession;
  final ValueChanged<bool> onClaudePersistSessionChanged;

  const _ClaudeAdvancedOptions({
    required this.buildInputDecoration,
    required this.claudeModels,
    required this.claudeMaxTurnsController,
    required this.maxTurnsError,
    required this.onMaxTurnsChanged,
    required this.claudeMaxBudgetController,
    required this.maxBudgetError,
    required this.onMaxBudgetChanged,
    required this.selectedClaudeFallbackModel,
    required this.onClaudeFallbackModelChanged,
    required this.claudeForkSession,
    required this.onClaudeForkSessionChanged,
    required this.claudePersistSession,
    required this.onClaudePersistSessionChanged,
  });

  List<Widget> buildChildren(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      TextField(
        key: const ValueKey('dialog_claude_max_turns'),
        controller: claudeMaxTurnsController,
        keyboardType: TextInputType.number,
        decoration: buildInputDecoration(
          l.maxTurns,
          hintText: l.maxTurnsHint,
          errorText: maxTurnsError,
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (_) {
          onMaxTurnsChanged();
        },
      ),
      const SizedBox(height: 8),
      _ResponsiveOptionRow(
        leading: TextField(
          key: const ValueKey('dialog_claude_max_budget'),
          controller: claudeMaxBudgetController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: buildInputDecoration(
            l.maxBudgetUsd,
            hintText: l.maxBudgetHint,
            errorText: maxBudgetError,
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: (_) {
            onMaxBudgetChanged();
          },
        ),
        trailing: DropdownButtonFormField<String?>(
          key: const ValueKey('dialog_claude_fallback_model'),
          initialValue: selectedClaudeFallbackModel,
          isExpanded: true,
          decoration: buildInputDecoration(l.fallbackModel),
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l.defaultLabel, style: const TextStyle(fontSize: 13)),
            ),
            for (final model in claudeModels)
              DropdownMenuItem<String?>(
                value: model,
                child: Text(model, style: const TextStyle(fontSize: 13)),
              ),
          ],
          onChanged: (value) => onClaudeFallbackModelChanged(value),
        ),
      ),
      const SizedBox(height: 4),
      SwitchListTile(
        key: const ValueKey('dialog_claude_fork_session'),
        contentPadding: EdgeInsets.zero,
        title: Text(
          l.forkSessionOnResume,
          style: const TextStyle(fontSize: 13),
        ),
        value: claudeForkSession,
        onChanged: (value) {
          onClaudeForkSessionChanged(value);
        },
      ),
      SwitchListTile(
        key: const ValueKey('dialog_claude_persist_session'),
        contentPadding: EdgeInsets.zero,
        title: Text(
          l.persistSessionHistory,
          style: const TextStyle(fontSize: 13),
        ),
        value: claudePersistSession,
        onChanged: (value) {
          onClaudePersistSessionChanged(value);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: buildChildren(context));
  }
}

class _CodexAdvancedOptions extends StatelessWidget {
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;
  final WebSearchMode? webSearchMode;
  final ValueChanged<WebSearchMode?> onWebSearchModeChanged;
  final bool networkAccessEnabled;
  final ValueChanged<bool> onNetworkAccessChanged;

  const _CodexAdvancedOptions({
    required this.buildInputDecoration,
    required this.webSearchMode,
    required this.onWebSearchModeChanged,
    required this.networkAccessEnabled,
    required this.onNetworkAccessChanged,
  });

  List<Widget> buildChildren(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      DropdownButtonFormField<WebSearchMode?>(
        key: const ValueKey('dialog_codex_web_search_mode'),
        initialValue: webSearchMode,
        isExpanded: true,
        decoration: buildInputDecoration(l.webSearch),
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: [
          DropdownMenuItem<WebSearchMode?>(
            value: null,
            child: Text(l.defaultLabel, style: const TextStyle(fontSize: 13)),
          ),
          for (final mode in WebSearchMode.values)
            DropdownMenuItem<WebSearchMode?>(
              value: mode,
              child: Text(mode.label, style: const TextStyle(fontSize: 13)),
            ),
        ],
        onChanged: onWebSearchModeChanged,
      ),
      const SizedBox(height: 4),
      SwitchListTile(
        key: const ValueKey('dialog_codex_network_access'),
        contentPadding: EdgeInsets.zero,
        title: Text(l.networkAccess, style: const TextStyle(fontSize: 13)),
        value: networkAccessEnabled,
        onChanged: (value) {
          onNetworkAccessChanged(value);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: buildChildren(context));
  }
}

class _WorktreeOptions extends StatelessWidget {
  final AppColors appColors;
  final _WorktreeMode worktreeMode;
  final ValueChanged<_WorktreeMode> onWorktreeModeChanged;
  final List<WorktreeInfo>? worktrees;
  final WorktreeInfo? selectedWorktree;
  final ValueChanged<WorktreeInfo> onWorktreeSelected;
  final TextEditingController branchController;
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;

  const _WorktreeOptions({
    required this.appColors,
    required this.worktreeMode,
    required this.onWorktreeModeChanged,
    required this.worktrees,
    required this.selectedWorktree,
    required this.onWorktreeSelected,
    required this.branchController,
    required this.buildInputDecoration,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final hasWorktrees = worktrees != null && worktrees!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode selection: New / Existing
        if (hasWorktrees) ...[
          Row(
            children: [
              ChoiceChip(
                label: Text(
                  l.worktreeNew,
                  style: TextStyle(
                    fontSize: 12,
                    color: worktreeMode == _WorktreeMode.createNew
                        ? cs.onPrimaryContainer
                        : cs.onSurface,
                  ),
                ),
                checkmarkColor: cs.onPrimaryContainer,
                selected: worktreeMode == _WorktreeMode.createNew,
                onSelected: (_) =>
                    onWorktreeModeChanged(_WorktreeMode.createNew),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(
                  l.worktreeExisting(worktrees!.length),
                  style: TextStyle(
                    fontSize: 12,
                    color: worktreeMode == _WorktreeMode.useExisting
                        ? cs.onPrimaryContainer
                        : cs.onSurface,
                  ),
                ),
                checkmarkColor: cs.onPrimaryContainer,
                selected: worktreeMode == _WorktreeMode.useExisting,
                onSelected: (_) =>
                    onWorktreeModeChanged(_WorktreeMode.useExisting),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // New worktree: branch input
        if (worktreeMode == _WorktreeMode.createNew)
          TextField(
            key: const ValueKey('dialog_worktree_branch'),
            controller: branchController,
            decoration:
                buildInputDecoration(
                  l.branchOptional,
                  hintText: l.branchHint,
                  prefixIcon: const Icon(Icons.merge_outlined, size: 18),
                ).copyWith(
                  filled: true,
                  fillColor: Color.lerp(
                    cs.surfaceContainerHigh,
                    cs.onSurface,
                    0.05,
                  ),
                ),
            style: const TextStyle(fontSize: 13),
          ),
        // Existing worktree selection
        if (worktreeMode == _WorktreeMode.useExisting) ...[
          if (worktrees == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              ),
            )
          else if (worktrees!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l.noExistingWorktrees,
                style: TextStyle(fontSize: 13, color: appColors.subtleText),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final wt in worktrees!)
                      _WorktreeSelectionTile(
                        worktree: wt,
                        appColors: appColors,
                        isSelected:
                            selectedWorktree?.worktreePath == wt.worktreePath,
                        onTap: () => onWorktreeSelected(wt),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _WorktreeSelectionTile extends StatelessWidget {
  final WorktreeInfo worktree;
  final AppColors appColors;
  final bool isSelected;
  final VoidCallback onTap;

  const _WorktreeSelectionTile({
    required this.worktree,
    required this.appColors,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.tertiaryContainer.withValues(alpha: 0.3)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.fork_right,
              size: 18,
              color: isSelected ? cs.tertiary : appColors.subtleText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worktree.branch,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? cs.tertiary : null,
                    ),
                  ),
                  Text(
                    worktree.worktreePath.split('/').last,
                    style: TextStyle(fontSize: 11, color: appColors.subtleText),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: cs.tertiary),
          ],
        ),
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  final Provider provider;
  final bool canStart;
  final VoidCallback onStart;

  const _SheetActions({
    required this.provider,
    required this.canStart,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final providerStyle = providerStyleFor(context, provider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(l.cancel),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton(
                key: const ValueKey('dialog_start_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: canStart ? providerStyle.background : null,
                  foregroundColor: canStart ? providerStyle.foreground : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: canStart ? onStart : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Start with ${provider.label}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderToggleButton extends StatelessWidget {
  final Provider provider;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const _ProviderToggleButton({
    required this.provider,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = providerStyleFor(context, provider);
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? style.background : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              style.icon,
              size: 16,
              color: isSelected ? style.foreground : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              provider.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? style.foreground : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
