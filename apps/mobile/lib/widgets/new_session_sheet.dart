import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/session_list/session_list_screen.dart' show recentProjects;
import '../features/projects/widgets/project_manager_sheet.dart';
import '../features/project_setup/widgets/new_project_sheet.dart';
import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../models/model_picker_style.dart';
import '../models/new_session_tab.dart';
import '../services/bridge_service.dart';
import '../theme/app_theme.dart';
import '../theme/provider_style.dart';
import '../utils/model_filter.dart';
import '../utils/project_usage.dart';
import 'antigravity_model_options_panel.dart';
import 'workspace_pane_chrome.dart';
import 'claude_settings_panel.dart';
import 'codex_effort_slider.dart';
import 'new_session_sheet/new_session_params.dart';
import 'new_session_sheet/project_choice.dart';
import 'new_session_sheet/project_widgets.dart';
import 'new_session_sheet/writable_roots.dart';
import 'new_session_sheet/options_section.dart';
import 'new_session_sheet/sheet_chrome.dart';
export 'new_session_sheet/new_session_params.dart';

// ---- Serialization helpers for SharedPreferences ----

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
  Map<Provider, NewSessionParams> providerDefaults = const {},
  bool lockProvider = false,
  bool lockProject = false,
  bool multiProjectOnly = false,
  List<NewSessionTab> visibleTabs = defaultNewSessionTabs,
  bool showExtendedCodexEfforts = false,
  bool showHiddenDirectories = false,
  ModelPickerStyle modelPickerStyle = ModelPickerStyle.bottomSheet,
  Set<String> enabledClaudeModels = const {},
  Set<String> enabledCodexModels = const {},
  Set<String> enabledAntigravityModels = const {},
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
      providerDefaults: providerDefaults,
      lockProvider: lockProvider,
      lockProject: lockProject,
      multiProjectOnly: multiProjectOnly,
      visibleTabs: visibleTabs,
      showExtendedCodexEfforts: showExtendedCodexEfforts,
      showHiddenDirectories: showHiddenDirectories,
      modelPickerStyle: modelPickerStyle,
      enabledClaudeModels: enabledClaudeModels,
      enabledCodexModels: enabledCodexModels,
      enabledAntigravityModels: enabledAntigravityModels,
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

  /// Saved defaults per provider. Used for the provider-specific options of
  /// the tab that [initialParams] does not belong to, so switching tabs shows
  /// that provider's own saved choices instead of hardcoded defaults.
  final Map<Provider, NewSessionParams> providerDefaults;
  final bool lockProvider;

  /// The session must start in the project of [initialParams] (e.g. a
  /// request about that repository), so the project cannot be changed.
  final bool lockProject;
  final bool multiProjectOnly;
  final List<NewSessionTab> visibleTabs;
  final bool showExtendedCodexEfforts;
  final bool showHiddenDirectories;
  final ModelPickerStyle modelPickerStyle;
  final Set<String> enabledClaudeModels;
  final Set<String> enabledCodexModels;
  final Set<String> enabledAntigravityModels;

  const _NewSessionSheetContent({
    required this.recentProjects,
    this.projectHistory = const [],
    this.bridge,
    this.initialParams,
    this.providerDefaults = const {},
    this.lockProvider = false,
    this.lockProject = false,
    this.multiProjectOnly = false,
    this.visibleTabs = defaultNewSessionTabs,
    this.showExtendedCodexEfforts = false,
    this.showHiddenDirectories = false,
    this.modelPickerStyle = ModelPickerStyle.bottomSheet,
    this.enabledClaudeModels = const {},
    this.enabledCodexModels = const {},
    this.enabledAntigravityModels = const {},
  });

  @override
  State<_NewSessionSheetContent> createState() =>
      _NewSessionSheetContentState();
}

class _NewSessionSheetContentState extends State<_NewSessionSheetContent> {
  final _pathController = TextEditingController();
  final _branchController = TextEditingController();
  final _claudeMaxTurnsController = TextEditingController();
  final _claudeMaxBudgetController = TextEditingController();
  final _additionalWritableRootController = TextEditingController();
  late final PageController _pageController;
  var _provider = Provider.codex;
  var _claudePermissionMode = PermissionMode.auto;

  /// Antigravity keeps its own mode: sharing the Claude one would leak
  /// `auto` / `bypassPermissions`, which a new Antigravity session cannot use.
  var _antigravityPermissionMode = PermissionMode.defaultMode;

  /// What a new Antigravity session offers; null until the Bridge answers
  /// (and with Bridges that cannot tell before a session starts).
  AntigravitySettings? _antigravityCatalog;
  StreamSubscription<AntigravityCatalogMessage>? _antigravityCatalogSub;

  /// Model family to start on; null keeps the account default.
  String? _antigravityModel;
  String? _antigravityThoughtLevel;

  List<PermissionMode> get _antigravityPermissionModes {
    final modes =
        _antigravityCatalog?.selectablePermissionModes ??
        defaultAntigravityPermissionModes;
    // A saved mode stays selectable until the catalog says otherwise.
    return modes.contains(_antigravityPermissionMode) ||
            _antigravityCatalog != null
        ? modes
        : [...modes, _antigravityPermissionMode];
  }

  /// Filtered Antigravity model families available in this sheet.
  List<AntigravityModelOption> get _antigravityModelOptions =>
      filterEnabledModels<AntigravityModelOption>(
        models: _antigravityCatalog?.modelOptions ?? const [],
        enabledIds: widget.enabledAntigravityModels,
        idOf: (option) => option.id,
      );

  /// The family the session will start on: the chosen one, or the default.
  AntigravityModelOption? get _antigravityModelOption {
    final catalog = _antigravityCatalog;
    if (catalog == null) return null;
    final options = _antigravityModelOptions;
    for (final option in options) {
      if (option.id == _antigravityModel) return option;
    }
    final defaultOption = catalog.currentModelOption;
    if (defaultOption != null && options.any((o) => o.id == defaultOption.id)) {
      return defaultOption;
    }
    return options.firstOrNull;
  }

  /// The level the session will start at, if the family has levels.
  String? get _antigravityEffectiveThoughtLevel {
    final option = _antigravityModelOption;
    if (option == null || option.thoughtLevels.isEmpty) return null;
    final chosen = _antigravityThoughtLevel;
    if (chosen != null && option.thoughtLevels.contains(chosen)) return chosen;
    final fallback = _antigravityCatalog?.thoughtLevel;
    if (fallback != null && option.thoughtLevels.contains(fallback)) {
      return fallback;
    }
    return preferredAntigravityThoughtLevel(option.thoughtLevels);
  }

  /// The mode was saved earlier or picked in this sheet; otherwise the sheet
  /// follows the `agy` CLI, which starts in auto where the account has it.
  bool _antigravityModeChosen = false;

  void _applyAntigravityCatalog(AntigravitySettings catalog) {
    _antigravityCatalog = catalog;
    final modes = catalog.selectablePermissionModes;
    if (!_antigravityModeChosen && modes.contains(PermissionMode.auto)) {
      _antigravityPermissionMode = PermissionMode.auto;
    } else if (!modes.contains(_antigravityPermissionMode)) {
      _antigravityPermissionMode = PermissionMode.defaultMode;
    }
    final filteredOptions = _antigravityModelOptions;
    if (filteredOptions.isNotEmpty &&
        _antigravityModel != null &&
        !filteredOptions.any((o) => o.id == _antigravityModel)) {
      _antigravityModel = null;
    }
  }

  var _executionMode = ExecutionMode.defaultMode;
  var _codexPermissionsMode = CodexPermissionsMode.defaultPermissions;
  var _codexApprovalPolicy = CodexApprovalPolicy.onRequest;
  var _codexAutoReviewEnabled = false;
  var _planMode = false;
  var _useWorktree = false;
  var _worktreeMode = NewSessionWorktreeMode.createNew;
  WorktreeInfo? _selectedWorktree;
  List<WorktreeInfo>? _worktrees;
  StreamSubscription<WorktreeListMessage>? _worktreeSub;
  StreamSubscription<List<RecentSession>>? _recentSub;
  StreamSubscription<List<String>>? _projectHistorySub;
  StreamSubscription<ProjectsMessage>? _projectsSub;
  StreamSubscription<bool>? _codexAutoReviewPolicySub;
  StreamSubscription<List<SessionInfo>>? _codexCatalogSub;
  StreamSubscription<BridgeConnectionState>? _codexConnectionSub;
  bool _codexAutoReviewDisabled = false;
  ProjectsMessage _workspaceProjectsState = const ProjectsMessage(projects: []);
  String? _selectedProjectId;
  String? _workspaceKind;
  bool _pendingInitialWorkspaceSelection = false;

  /// Live-updated recent projects (initially from widget, updated via stream).
  late List<({String path, String name})> _liveRecentProjects;

  /// Live-updated project history (initially from widget, updated via stream).
  late List<String> _liveProjectHistory;
  Map<String, DateTime> _projectUsage = {};

  // Claude-specific options
  String? _selectedClaudeModel;
  String? _selectedClaudeFallbackModel;
  ClaudeEffort _claudeEffort = ClaudeEffort.medium;
  bool _claudeFastMode = false;
  bool _claudeUltracode = false;
  bool _claudeForkSession = false;
  bool _claudePersistSession = true;

  // Model lists from Bridge (with fallbacks)
  // They are refreshed when the Bridge publishes a newer catalog: right after a
  // Bridge restart it announces a fallback catalog before the real one loads.
  late List<String> _claudeModelList;
  late Map<String, ClaudeModelOption> _claudeModelOptions;
  late Map<String, List<ClaudeEffort>> _claudeModelEfforts;
  late List<String> _codexModelList;
  late Map<String, List<ReasoningEffort>> _codexModelReasoningEfforts;

  /// Saved choices that seed the Claude / Codex options. Kept so a late
  /// catalog can still resolve them while the user has not changed them.
  NewSessionParams? _claudeSource;
  NewSessionParams? _codexSource;
  bool _claudeModelTouched = false;
  bool _claudeEffortTouched = false;
  Map<String, List<String>> get _codexModelServiceTiers =>
      widget.bridge?.codexModelServiceTiers ?? const {};
  Map<String, List<CodexSpeed>> get _codexModelServiceTierMetadata =>
      widget.bridge?.codexModelServiceTierMetadata ?? const {};
  bool get _supportsExtendedServiceTiers =>
      widget.bridge?.supportsCodexServiceTiers ?? false;
  // A profile resolves its model on the Bridge; the first catalog model is
  // not evidence of which tiers that profile supports.
  String? get _codexSpeedModel => _selectedCodexProfile != null
      ? null
      : (_selectedModel ?? _codexModelList.firstOrNull);

  List<CodexSpeed> get _availableCodexSpeeds {
    final speeds = codexAvailableSpeeds(
      _codexSpeedModel,
      _codexModelServiceTiers,
      modelServiceTierMetadata: _codexModelServiceTierMetadata,
      supportsExtendedServiceTiers: _supportsExtendedServiceTiers,
      currentSpeed: _codexSpeed,
    );
    // Preserve a saved profile tier for server-side validation once its model
    // is resolved. Do not offer new tiers based on an unrelated catalog model.
    if (_selectedCodexProfile != null &&
        _supportsExtendedServiceTiers &&
        !speeds.contains(_codexSpeed)) {
      speeds.add(_codexSpeed);
    }
    return speeds;
  }

  bool get _isCodexSpeedAvailable =>
      _availableCodexSpeeds.contains(_codexSpeed);
  late final List<String> _codexProfiles;

  // Codex-specific options
  String? _selectedModel;
  String? _selectedCodexProfile;
  var _claudeSandboxMode = SandboxMode.off; // Claude default = OFF
  var _codexSandboxMode = SandboxMode.on; // Codex default = ON
  ReasoningEffort _modelReasoningEffort = ReasoningEffort.high;
  CodexSpeed _codexSpeed = CodexSpeed.standard;
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

  void _applyCodexPermissionsMode(CodexPermissionsMode mode) {
    if (_codexAutoReviewDisabled && mode == CodexPermissionsMode.autoReview) {
      return;
    }
    _codexPermissionsMode = mode;
    final approvalPolicy = approvalPolicyForCodexPermissionsMode(mode);
    final sandboxMode = sandboxModeForCodexPermissionsMode(mode);
    _codexApprovalPolicy = approvalPolicy ?? CodexApprovalPolicy.onRequest;
    _codexAutoReviewEnabled = mode == CodexPermissionsMode.autoReview;
    _executionMode = mode == CodexPermissionsMode.fullAccess
        ? ExecutionMode.fullAccess
        : ExecutionMode.defaultMode;
    if (sandboxMode != null) {
      _codexSandboxMode = sandboxMode;
    }
    _codexApprovalPolicyTouched = true;
    _codexAutoReviewTouched = true;
    _codexSandboxModeTouched = true;
  }

  void _enforceCodexAutoReviewPolicy() {
    if (!_codexAutoReviewDisabled ||
        _codexPermissionsMode != CodexPermissionsMode.autoReview) {
      return;
    }
    _codexPermissionsMode = CodexPermissionsMode.defaultPermissions;
    _codexApprovalPolicy = CodexApprovalPolicy.onRequest;
    _codexAutoReviewEnabled = false;
    _executionMode = ExecutionMode.defaultMode;
    _codexSandboxMode = SandboxMode.on;
  }

  final _createdProjects = <String, NewProjectResult>{};

  bool get _hasPath => _pathController.text.trim().isNotEmpty;

  /// All merged projects before managed workspace paths are filtered out.
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
    return merged;
  }

  List<NewSessionProjectChoice> get _allProjectChoices {
    final result = <NewSessionProjectChoice>[];
    final representedFolderPaths = <String>{};
    for (final project in _workspaceProjectsState.projects) {
      result.add(
        NewSessionProjectChoice(
          kind: NewSessionProjectChoiceKind.workspaceProject,
          id: project.id,
          name: project.name,
          path: project.primaryPath,
          workspaceProject: project,
        ),
      );
      if (widget.multiProjectOnly) continue;
      for (final rootPath in project.rootPaths) {
        if (rootPath.isEmpty || !representedFolderPaths.add(rootPath)) continue;
        result.add(
          NewSessionProjectChoice(
            kind: NewSessionProjectChoiceKind.workspaceFolder,
            id: rootPath,
            name: pathBasename(rootPath),
            path: rootPath,
          ),
        );
      }
    }

    final managedRoots = _workspaceProjectsState.projects
        .expand((project) => project.rootPaths)
        .toList();
    for (final project
        in widget.multiProjectOnly
            ? <({String path, String name})>[]
            : _allMergedProjects) {
      if (!representedFolderPaths.add(project.path)) continue;
      final isManagedProject = managedRoots.any(
        (root) => isSameOrDescendantPath(project.path, root),
      );
      if (isManagedProject) continue;
      result.add(
        NewSessionProjectChoice(
          kind: NewSessionProjectChoiceKind.recent,
          id: project.path,
          name: project.name,
          path: project.path,
        ),
      );
    }
    // Compare exact selections: a group's use must not promote its folders,
    // and using a folder must not promote groups containing that folder.
    final fallbackOrder = {for (final (i, choice) in result.indexed) choice: i};
    final folderOrder = {
      if (_projectUsage.isEmpty)
        for (final (i, project) in _allMergedProjects.indexed) project.path: i,
    };
    String usageKey(NewSessionProjectChoice choice) =>
        choice.kind == NewSessionProjectChoiceKind.workspaceProject
        ? 'project:${choice.id}'
        : 'folder:${choice.path}';
    result.sort((a, b) {
      final aUsed = _projectUsage[usageKey(a)];
      final bUsed = _projectUsage[usageKey(b)];
      if (aUsed != null && bUsed != null) {
        final byTime = bUsed.compareTo(aUsed);
        if (byTime != 0) return byTime;
      } else if (aUsed != null || bUsed != null) {
        return aUsed != null ? -1 : 1;
      }
      // Use path-only history only when no session usage is available.
      // It includes group primary paths and cannot identify actual choices.
      final aFallback = a.workspaceProject == null ? folderOrder[a.path] : null;
      final bFallback = b.workspaceProject == null ? folderOrder[b.path] : null;
      if (aFallback != null && bFallback != null) {
        return aFallback.compareTo(bFallback);
      }
      if (aFallback != null || bFallback != null) {
        return aFallback != null ? -1 : 1;
      }
      return fallbackOrder[a]!.compareTo(fallbackOrder[b]!);
    });
    if (widget.multiProjectOnly) return result;
    return result.length > _maxRecentProjects
        ? result.sublist(0, _maxRecentProjects)
        : result;
  }

  /// Returns the unified ccpocket Project and folder history.
  List<NewSessionProjectChoice> get _effectiveProjectChoices {
    final all = _allProjectChoices;
    if (!_isProjectListExpanded && all.length > _defaultRecentProjects) {
      return all.sublist(0, _defaultRecentProjects);
    }
    return all;
  }

  /// Whether the project list has more items than the default collapsed count.
  bool get _canExpandProjects =>
      _allProjectChoices.length > _defaultRecentProjects;

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
    final bridge = widget.bridge;
    if (bridge != null &&
        bridge.supportsAntigravityCatalog &&
        widget.visibleTabs.any((t) => t.toProvider() == Provider.antigravity)) {
      _antigravityCatalog = bridge.antigravityCatalog;
      _antigravityCatalogSub = bridge.antigravityCatalogResults.listen((msg) {
        final catalog = msg.catalog;
        if (catalog == null || !mounted) return;
        setState(() => _applyAntigravityCatalog(catalog));
      });
      // Ask every time: the plan and the model list change with the account.
      bridge.requestAntigravityCatalog();
    }
    // Use the latest cached recent sessions from BridgeService if available,
    // because the broadcast stream may have already fired before this listener
    // was registered.
    final cachedSessions = widget.bridge?.recentSessions;
    _projectUsage = projectUsage(cachedSessions ?? const []);
    _liveRecentProjects = (cachedSessions != null && cachedSessions.isNotEmpty)
        ? recentProjects(cachedSessions)
        : widget.recentProjects;
    // Use the latest cached project history from BridgeService if available,
    // because the broadcast stream may have already fired before this listener
    // was registered.
    _liveProjectHistory =
        widget.bridge?.projectHistory ?? widget.projectHistory;
    _workspaceProjectsState =
        widget.bridge?.projectsState ?? _workspaceProjectsState;

    _loadModelCatalogs();
    _codexProfiles = widget.bridge?.codexProfiles ?? const [];
    _codexAutoReviewDisabled = widget.bridge?.codexAutoReviewDisabled ?? false;
    final defaultCodexProfile = widget.bridge?.defaultCodexProfile;
    if (_codexProfiles.contains(defaultCodexProfile)) {
      _selectedCodexProfile = defaultCodexProfile;
    }
    _worktreeSub = widget.bridge?.worktreeList.listen((msg) {
      final requestedPath = _pathController.text.trim();
      if (msg.projectPath != null && msg.projectPath != requestedPath) return;
      if (mounted) setState(() => _worktrees = msg.worktrees);
    });
    // Subscribe to live updates so projects appear even if data arrives
    // after the sheet is already open (e.g. right after connection).
    _recentSub = widget.bridge?.recentSessionsStream.listen((sessions) {
      if (mounted) {
        setState(() {
          _liveRecentProjects = recentProjects(sessions);
          _projectUsage = projectUsage(sessions);
        });
      }
    });
    _projectHistorySub = widget.bridge?.projectHistoryStream.listen((projects) {
      if (mounted) {
        setState(() => _liveProjectHistory = projects);
      }
    });
    _projectsSub = widget.bridge?.projectsStream.listen((state) {
      if (!mounted) return;
      setState(() => _applyWorkspaceProjectsState(state));
    });
    widget.bridge?.requestProjects();
    _codexAutoReviewPolicySub = widget.bridge?.codexAutoReviewPolicyStream
        .listen((disabled) {
          if (!mounted) return;
          setState(() {
            _codexAutoReviewDisabled = disabled;
            _enforceCodexAutoReviewPolicy();
          });
        });
    // Catalog and capability changes invalidate saved choices without rewriting them.
    _codexCatalogSub = widget.bridge?.sessionList.listen((_) {
      if (!mounted) return;
      setState(_refreshModelCatalogs);
    });
    _codexConnectionSub = widget.bridge?.connectionStatus.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(_loadAdditionalWritableRootHistory());
    _applyInitialParams();
    _enforceCodexAutoReviewPolicy();
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
    _projectsSub?.cancel();
    _codexAutoReviewPolicySub?.cancel();
    _codexCatalogSub?.cancel();
    _codexConnectionSub?.cancel();
    _antigravityCatalogSub?.cancel();
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
        _worktreeMode = NewSessionWorktreeMode.createNew;
        _selectedWorktree = null;
        _worktrees = null;
      }
    });
  }

  void _normalizeSelectedClaudeEffort() {
    final efforts = claudeEffortsForModel(
      _selectedClaudeModel ?? _claudeModelList.firstOrNull,
      _claudeModelEfforts,
    );
    if (efforts.isNotEmpty && !efforts.contains(_claudeEffort)) {
      _claudeEffort = efforts.contains(ClaudeEffort.high)
          ? ClaudeEffort.high
          : efforts.first;
    }
    if (_claudeFastMode &&
        !claudeModelSupportsFast(
          _claudeModelOptions.values.toList(),
          _selectedClaudeModel ?? _claudeModelList.firstOrNull,
        )) {
      _claudeFastMode = false;
    }
  }

  void _normalizeSelectedCodexReasoningEffort() {
    final efforts = codexReasoningEffortsForModel(
      _selectedModel ?? _codexModelList.firstOrNull,
      _codexModelReasoningEfforts,
    );
    if (efforts.isNotEmpty && !efforts.contains(_modelReasoningEffort)) {
      _modelReasoningEffort = preferredCodexEffort(
        efforts,
        current: _modelReasoningEffort,
      );
    }
  }

  /// Load available models from Bridge (with hardcoded fallbacks).
  void _loadModelCatalogs() {
    final bridgeClaudeOptions =
        widget.bridge?.claudeModelOptions ?? const <ClaudeModelOption>[];
    final allClaudeOptions = bridgeClaudeOptions.isNotEmpty
        ? bridgeClaudeOptions
        : defaultClaudeModelOptions;
    final claudeOptions = filterEnabledModels<ClaudeModelOption>(
      models: allClaudeOptions,
      enabledIds: widget.enabledClaudeModels,
      idOf: (option) => option.value,
    );
    _claudeModelList = [for (final option in claudeOptions) option.value];
    _claudeModelOptions = {
      for (final option in claudeOptions) option.value: option,
    };
    _claudeModelEfforts = normalizeClaudeModelEfforts(
      widget.bridge?.claudeModelEfforts ?? const {},
    );
    final bridgeCodexModels = widget.bridge?.codexModels ?? const [];
    final allCodexModels = bridgeCodexModels.isNotEmpty
        ? bridgeCodexModels
        : defaultNewSessionCodexModels;
    _codexModelList = filterEnabledModels<String>(
      models: allCodexModels,
      enabledIds: widget.enabledCodexModels,
      idOf: (model) => model,
    );
    _codexModelReasoningEfforts = normalizeCodexModelReasoningEfforts(
      widget.bridge?.codexModelReasoningEfforts ?? const {},
    );
  }

  /// Apply a newer catalog and re-resolve saved choices the user has not
  /// changed in this sheet, so a fallback catalog cannot replace them.
  void _refreshModelCatalogs() {
    final previousCodexModels = _codexModelList;
    final previousClaudeModels = _claudeModelList;
    _loadModelCatalogs();
    final codexChanged = !listEquals(previousCodexModels, _codexModelList);
    final claudeChanged = !listEquals(previousClaudeModels, _claudeModelList);
    final codex = _codexSource;
    if (codexChanged && codex != null) {
      if (!_codexModelTouched) _resolveCodexModel(codex);
      if (!_codexReasoningEffortTouched && codex.modelReasoningEffort != null) {
        _modelReasoningEffort = codex.modelReasoningEffort!;
      }
    }
    if (_selectedModel != null && !_codexModelList.contains(_selectedModel)) {
      _selectedModel = null;
    }
    _normalizeSelectedCodexReasoningEffort();
    final claude = _claudeSource;
    if (claudeChanged && claude != null) {
      if (!_claudeModelTouched) _resolveClaudeModels(claude);
      if (!_claudeEffortTouched && claude.claudeEffort != null) {
        _claudeEffort = claude.claudeEffort!;
      }
    }
    if (_selectedClaudeModel != null &&
        !_claudeModelList.contains(_selectedClaudeModel)) {
      _selectedClaudeModel = null;
    }
    if (_selectedClaudeFallbackModel != null &&
        !_claudeModelList.contains(_selectedClaudeFallbackModel)) {
      _selectedClaudeFallbackModel = null;
    }
    _normalizeSelectedClaudeEffort();
  }

  void _resolveCodexModel(NewSessionParams p) {
    final normalizedCodexModel = normalizeCodexModelForAvailableList(
      p.model,
      _codexModelList,
    );
    _selectedModel = _codexModelList.contains(normalizedCodexModel)
        ? normalizedCodexModel
        : null;
  }

  void _resolveClaudeModels(NewSessionParams p) {
    _selectedClaudeModel = _claudeModelList.contains(p.claudeModel)
        ? p.claudeModel
        : null;
    _selectedClaudeFallbackModel =
        _claudeModelList.contains(p.claudeFallbackModel)
        ? p.claudeFallbackModel
        : null;
  }

  /// The defaults that seed [provider]'s options: [initialParams] for its own
  /// provider, otherwise that provider's saved defaults when available.
  NewSessionParams _sourceFor(Provider provider, NewSessionParams initial) {
    if (initial.provider == provider || widget.lockProvider) return initial;
    return widget.providerDefaults[provider] ?? initial;
  }

  void _applyInitialParams() {
    final p = widget.initialParams;
    if (p == null) return;

    _pathController.text = p.projectPath;
    _pendingInitialWorkspaceSelection = p.projectId != null;
    _resolveInitialWorkspaceSelection();
    // Validate provider is in visibleTabs; fall back to first tab if hidden.
    final isVisible = widget.visibleTabs.any(
      (t) => t.toProvider() == p.provider,
    );
    _provider = isVisible ? p.provider : widget.visibleTabs.first.toProvider();

    final codex = _sourceFor(Provider.codex, p);
    final claude = _sourceFor(Provider.claude, p);
    _codexSource = codex;
    _claudeSource = claude;
    _applyCodexParams(codex);
    _applyClaudeParams(claude);
    final antigravity = _sourceFor(Provider.antigravity, p);
    if (antigravity.provider == Provider.antigravity) {
      _antigravityPermissionMode = antigravity.permissionMode;
      _antigravityModeChosen = true;
      _antigravityModel = antigravity.antigravityModel;
      _antigravityThoughtLevel = antigravity.antigravityThoughtLevel;
    }
    // Also without saved choices: the catalog decides the defaults then.
    final antigravityCatalog = _antigravityCatalog;
    if (antigravityCatalog != null) {
      _applyAntigravityCatalog(antigravityCatalog);
    }

    // Options shared by both tabs follow the initial provider. Apply them last
    // because Codex permissions also derive the shared execution mode.
    if (p.provider == Provider.claude) _executionMode = p.executionMode;
    if (p.provider == Provider.antigravity) {
      // Antigravity's mode lives in its own field; it must not seed the
      // plan mode of the Claude and Codex tabs. The execution mode keeps the
      // value derived from the saved Codex defaults above.
      _planMode = false;
    } else {
      _planMode = p.planMode;
    }
    _useWorktree = p.useWorktree || p.existingWorktreePath != null;
    _branchController.text = p.worktreeBranch ?? "";
    if (_selectedProjectId == null) {
      _additionalWritableRoots = [...p.additionalWritableRoots];
    }
    _claudeMaxTurnsController.text = p.claudeMaxTurns?.toString() ?? "";
    _claudeMaxBudgetController.text = p.claudeMaxBudgetUsd?.toString() ?? "";

    if (p.existingWorktreePath != null) {
      _worktreeMode = NewSessionWorktreeMode.useExisting;
      _selectedWorktree = WorktreeInfo(
        worktreePath: p.existingWorktreePath!,
        branch: p.worktreeBranch ?? "",
        projectPath: p.projectPath,
      );
    }
    _enforceCodexAutoReviewPolicy();
  }

  void _applyCodexParams(NewSessionParams p) {
    _executionMode = p.executionMode;
    _codexPermissionsMode = p.codexPermissionsMode;
    _codexApprovalPolicy =
        p.codexApprovalPolicy == CodexApprovalPolicy.onFailure
        ? CodexApprovalPolicy.onRequest
        : p.codexApprovalPolicy;
    _codexAutoReviewEnabled =
        _codexApprovalPolicy == CodexApprovalPolicy.onRequest &&
        p.codexAutoReviewEnabled;
    _resolveCodexModel(p);
    _selectedCodexProfile = _codexProfiles.contains(p.codexProfile)
        ? p.codexProfile
        : null;
    if (p.provider == Provider.codex) {
      _codexSandboxMode = p.sandboxMode ?? SandboxMode.on;
      _applyCodexPermissionsMode(p.codexPermissionsMode);
    }
    _modelReasoningEffort = p.modelReasoningEffort ?? _modelReasoningEffort;
    _codexSpeed = p.codexSpeed;
    _normalizeSelectedCodexReasoningEffort();
    _networkAccessEnabled = p.networkAccessEnabled ?? _networkAccessEnabled;
    _webSearchMode = p.webSearchMode;
    _codexApprovalPolicyTouched = p.codexApprovalPolicyOverridden;
    _codexAutoReviewTouched = p.codexAutoReviewOverridden;
    _codexModelTouched = p.codexModelOverridden;
    _codexSandboxModeTouched = p.codexSandboxModeOverridden;
    _codexReasoningEffortTouched = p.codexReasoningEffortOverridden;
    _codexNetworkAccessTouched = p.codexNetworkAccessOverridden;
    _codexWebSearchTouched = p.codexWebSearchModeOverridden;
  }

  void _applyClaudeParams(NewSessionParams p) {
    if (p.provider == Provider.claude) {
      _claudePermissionMode = p.permissionMode;
      _claudeSandboxMode = p.sandboxMode ?? SandboxMode.off;
    }
    _resolveClaudeModels(p);
    _claudeEffort = p.claudeEffort ?? _claudeEffort;
    _claudeFastMode = p.claudeFastMode ?? false;
    _claudeUltracode = p.claudeUltracode ?? false;
    _normalizeSelectedClaudeEffort();
    _claudeForkSession = p.claudeForkSession ?? _claudeForkSession;
    _claudePersistSession = p.claudePersistSession ?? _claudePersistSession;
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
      _pendingInitialWorkspaceSelection = false;
      _selectedProjectId = null;
      _workspaceKind = null;
      _additionalWritableRoots = const [];
      _pathController.text = path;
      // Re-fetch worktrees if worktree mode is active
      if (_useWorktree) {
        _worktrees = null;
        _selectedWorktree = null;
        widget.bridge?.requestWorktreeList(path);
      }
    });
  }

  void _onWorkspaceProjectSelected(WorkspaceProject project) {
    setState(() {
      _pendingInitialWorkspaceSelection = false;
      _selectedProjectId = project.id;
      _workspaceKind = 'project';
      _pathController.text = project.primaryPath;
      _additionalWritableRoots = project.secondaryPaths;
    });
    if (_useWorktree) _fetchWorktrees();
  }

  void _onProjectChoiceSelected(NewSessionProjectChoice choice) {
    switch (choice.kind) {
      case NewSessionProjectChoiceKind.workspaceProject:
        final project = choice.workspaceProject;
        if (project != null) _onWorkspaceProjectSelected(project);
      case NewSessionProjectChoiceKind.workspaceFolder:
        _onProjectSelected(choice.path);
      case NewSessionProjectChoiceKind.recent:
        _onProjectSelected(choice.path);
    }
  }

  Future<void> _openProjectManager() async {
    final bridge = widget.bridge;
    if (bridge == null) return;
    await showProjectManagerSheet(
      context: context,
      bridge: bridge,
      showHiddenDirectories: widget.showHiddenDirectories,
    );
  }

  void _resolveInitialWorkspaceSelection() {
    if (!_pendingInitialWorkspaceSelection) return;
    final initial = widget.initialParams;
    if (initial == null) {
      _pendingInitialWorkspaceSelection = false;
      return;
    }
    if (initial.projectId != null) {
      final project = _workspaceProjectsState.projects
          .where((item) => item.id == initial.projectId)
          .firstOrNull;
      if (project == null) return;
      _selectedProjectId = project.id;
      _workspaceKind = 'project';
      _pathController.text = project.primaryPath;
      _additionalWritableRoots = project.secondaryPaths;
      _pendingInitialWorkspaceSelection = false;
      return;
    }
  }

  void _applyWorkspaceProjectsState(ProjectsMessage state) {
    _workspaceProjectsState = state;
    if (_pendingInitialWorkspaceSelection) {
      _resolveInitialWorkspaceSelection();
      if (!_pendingInitialWorkspaceSelection) return;
      // This is an authoritative Projects response. If the referenced
      // Project no longer exists, fall back to the recorded legacy path.
      _pendingInitialWorkspaceSelection = false;
    }
    final selectedProjectId = _selectedProjectId;
    if (selectedProjectId != null) {
      final project = state.projects
          .where((item) => item.id == selectedProjectId)
          .firstOrNull;
      if (project == null) {
        _selectedProjectId = null;
        _workspaceKind = null;
        _additionalWritableRoots = const [];
      } else {
        _pathController.text = project.primaryPath;
        _additionalWritableRoots = project.secondaryPaths;
      }
    }
  }

  Future<void> _createProject() async {
    final bridge = widget.bridge;
    if (bridge == null) return;
    final created = await showNewProjectSheet(
      context,
      bridge,
      {
        ..._allMergedProjects.map((p) => p.path),
        ..._workspaceProjectsState.projects.expand((p) => p.rootPaths),
      }.toList(),
    );
    if (!mounted || created == null) return;
    _createdProjects[created.path] = created;
    setState(() {
      _useWorktree = false;
      _selectedWorktree = null;
      _selectedCodexProfile = null;
      _liveRecentProjects = [
        (path: created.path, name: pathBasename(created.path)),
        ..._liveRecentProjects.where((p) => p.path != created.path),
      ];
    });
    _onProjectSelected(created.path);
  }

  Future<void> _changeProjectLocation() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => NewSessionProjectLocationSheet(
        initialPath: _pathController.text.trim(),
        bridge: widget.bridge,
        includeHidden: widget.showHiddenDirectories,
      ),
    );
    if (!mounted || selected == null || selected.trim().isEmpty) return;
    _onProjectSelected(selected);
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
    final selected = await showAddWritableRootSheet(
      context: context,
      controller: _additionalWritableRootController,
      suggestions: _addDirSuggestions,
      bridge: widget.bridge,
      includeHidden: widget.showHiddenDirectories,
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
    final nextHistory = _uniquePaths([path, ..._additionalWritableRootHistory])
        .take(_maxAdditionalWritableRootHistory)
        .toList();
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

  bool get _antigravityTakesExtraRoots =>
      widget.bridge?.supportsAntigravityCatalog ?? false;

  NewSessionParams _buildParams() {
    final path = _pathController.text.trim();
    final branch = _branchController.text.trim();
    final isCodex = _provider == Provider.codex;
    final isClaude = _provider == Provider.claude;
    final isAntigravity = _provider == Provider.antigravity;
    final claudeMaxTurns = int.tryParse(_claudeMaxTurnsController.text.trim());
    final claudeMaxBudgetUsd = double.tryParse(
      _claudeMaxBudgetController.text.trim(),
    );

    final useExisting =
        _useWorktree && _worktreeMode == NewSessionWorktreeMode.useExisting;

    return NewSessionParams(
      projectPath: path,
      initialPrompt: _selectedProjectId == null
          ? _createdProjects[path]?.prompt
          : null,
      isNewProject:
          _selectedProjectId == null && _createdProjects.containsKey(path),
      projectId: _selectedProjectId,
      workspaceKind: _workspaceKind,
      provider: _provider,
      claudePermissionMode: isClaude ? _claudePermissionMode : null,
      // Antigravity only has a permission mode (default / acceptEdits / plan),
      // carried as the matching execution + plan mode.
      executionMode: isAntigravity
          ? (_antigravityPermissionMode == PermissionMode.acceptEdits
                ? ExecutionMode.acceptEdits
                : ExecutionMode.defaultMode)
          : _executionMode,
      codexPermissionsMode: _codexPermissionsMode,
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
      planMode: isAntigravity
          ? _antigravityPermissionMode == PermissionMode.plan
          : (isCodex ? false : _planMode),
      useWorktree: useExisting ? false : _useWorktree,
      worktreeBranch: useExisting
          ? _selectedWorktree?.branch
          : (branch.isNotEmpty ? branch : null),
      existingWorktreePath: useExisting
          ? _selectedWorktree?.worktreePath
          : null,
      model: isCodex ? _codexSpeedModel : null,
      sandboxMode: isAntigravity ? null : _sandboxMode,
      modelReasoningEffort: isCodex ? _modelReasoningEffort : null,
      codexSpeed: isCodex ? _codexSpeed : CodexSpeed.standard,
      networkAccessEnabled: isCodex ? _networkAccessEnabled : null,
      webSearchMode: isCodex ? _webSearchMode : null,
      // Bridges before `antigravity_v2` ignore extra roots for Antigravity.
      additionalWritableRoots: isAntigravity && !_antigravityTakesExtraRoots
          ? const []
          : _additionalWritableRoots,
      antigravityPermissionMode: isAntigravity
          ? _antigravityPermissionMode
          : null,
      antigravityModel: isAntigravity
          ? (_antigravityCatalog != null &&
                    _antigravityCatalog!.modelOptions.isNotEmpty
                ? _antigravityModelOption?.id
                : _antigravityModel)
          : null,
      antigravityThoughtLevel: isAntigravity
          ? (_antigravityCatalog != null &&
                    _antigravityCatalog!.modelOptions.isNotEmpty
                ? _antigravityEffectiveThoughtLevel
                : _antigravityThoughtLevel)
          : null,
      claudeModel: isClaude ? _selectedClaudeModel : null,
      claudeEffort: isClaude ? _claudeEffort : null,
      claudeFastMode: isClaude ? _claudeFastMode : null,
      claudeUltracode: isClaude ? _claudeUltracode : null,
      claudeMaxTurns: isClaude ? claudeMaxTurns : null,
      claudeMaxBudgetUsd: isClaude ? claudeMaxBudgetUsd : null,
      claudeFallbackModel: isClaude ? _selectedClaudeFallbackModel : null,
      claudeForkSession: isClaude ? _claudeForkSession : null,
      claudePersistSession: isClaude ? _claudePersistSession : null,
    );
  }

  void _start() {
    if (widget.multiProjectOnly && _selectedProjectId == null) return;
    if (_provider == Provider.codex && !_isCodexSpeedAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(codexSpeedUnavailableMessage(_codexSpeed))),
      );
      return;
    }
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
          if (widget.multiProjectOnly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).multiProjectHint),
                  TextButton.icon(
                    onPressed: widget.bridge == null
                        ? null
                        : _openProjectManager,
                    icon: const Icon(Icons.folder_copy_outlined),
                    label: Text(AppLocalizations.of(context).createProject),
                  ),
                ],
              ),
            ),
          NewSessionProjectSectionHeader(
            onCreate:
                widget.bridge == null ||
                    widget.multiProjectOnly ||
                    widget.lockProvider ||
                    widget.lockProject
                ? null
                : _createProject,
            onMulti: widget.bridge == null || widget.lockProject
                ? null
                : _openProjectManager,
          ),
          NewSessionSelectedProjectCard(
            path: _pathController.text.trim(),
            name: _workspaceProjectsState.projects
                .where((p) => p.id == _selectedProjectId)
                .firstOrNull
                ?.name,
            isMulti: _selectedProjectId != null,
            onChange: widget.multiProjectOnly || widget.lockProject
                ? null
                : _changeProjectLocation,
          ),
          if (!widget.lockProject && _effectiveProjectChoices.isNotEmpty)
            NewSessionRecentProjectsSection(
              appColors: appColors,
              accentColor: accent,
              projects: _effectiveProjectChoices,
              selectedPath: _pathController.text,
              selectedProjectId: _selectedProjectId,
              workspaceKind: _workspaceKind,
              onProjectSelected: _onProjectChoiceSelected,
              onProjectRemoved: _onProjectRemoved,
              canExpand: _canExpandProjects,
              isExpanded: _isProjectListExpanded,
              onToggleExpand: () {
                setState(
                  () => _isProjectListExpanded = !_isProjectListExpanded,
                );
              },
            ),
          const Divider(indent: 16, endIndent: 16, height: 24),
          if (_selectedProjectId == null &&
              (pageProvider != Provider.antigravity ||
                  _antigravityTakesExtraRoots)) ...[
            const SizedBox(height: 12),
            NewSessionAdditionalWritableRootsSection(
              roots: _additionalWritableRoots,
              onAddPressed: _openAddWritableRootSheet,
              onDeleted: _removeWritableRoot,
            ),
          ],
          const SizedBox(height: 12),
          NewSessionOptionsSection(
            appColors: appColors,
            provider: pageProvider,
            showExtendedCodexEfforts: widget.showExtendedCodexEfforts,
            modelPickerStyle: widget.modelPickerStyle,
            claudePermissionMode: _claudePermissionMode,
            onClaudePermissionModeChanged: (value) {
              setState(() => _claudePermissionMode = value);
            },
            antigravityPermissionMode: _antigravityPermissionMode,
            antigravityPermissionModes: _antigravityPermissionModes,
            onAntigravityPermissionModeChanged: (value) {
              setState(() {
                _antigravityPermissionMode = value;
                _antigravityModeChosen = true;
              });
            },
            antigravityModelOptions: _antigravityModelOptions,
            antigravityModelOption: _antigravityModelOption,
            antigravityThoughtLevel: _antigravityEffectiveThoughtLevel,
            antigravityTierName: _antigravityCatalog?.tierName,
            onAntigravityModelChanged: (option) {
              setState(() {
                _antigravityModel = option.id;
                if (option.thoughtLevels.isEmpty) {
                  _antigravityThoughtLevel = null;
                } else if (_antigravityThoughtLevel != null &&
                    !option.thoughtLevels.contains(_antigravityThoughtLevel)) {
                  _antigravityThoughtLevel = preferredAntigravityThoughtLevel(
                    option.thoughtLevels,
                    current: _antigravityCatalog?.thoughtLevel,
                  );
                }
              });
            },
            onAntigravityThoughtLevelChanged: (value) {
              setState(() => _antigravityThoughtLevel = value);
            },
            executionMode: _executionMode,
            onExecutionModeChanged: (value) {
              setState(() => _executionMode = value);
            },
            codexPermissionsMode: _codexPermissionsMode,
            codexAutoReviewDisabled: _codexAutoReviewDisabled,
            onCodexPermissionsModeChanged: (value) {
              setState(() => _applyCodexPermissionsMode(value));
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
                if (mode == NewSessionWorktreeMode.createNew) {
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
            claudeModelOptions: _claudeModelOptions,
            claudeModelEfforts: _claudeModelEfforts,
            selectedClaudeModel: _selectedClaudeModel,
            onClaudeModelChanged: (value) {
              setState(() {
                _selectedClaudeModel = value;
                _claudeModelTouched = true;
                _normalizeSelectedClaudeEffort();
              });
            },
            claudeEffort: _claudeEffort,
            onClaudeEffortChanged: (value) {
              setState(() {
                _claudeEffort = value;
                _claudeEffortTouched = true;
              });
            },
            claudeFastMode: _claudeFastMode,
            onClaudeFastModeChanged: (value) {
              setState(() => _claudeFastMode = value);
            },
            claudeUltracode: _claudeUltracode,
            onClaudeUltracodeChanged: (value) {
              setState(() => _claudeUltracode = value);
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
              setState(() {
                _selectedClaudeFallbackModel = value;
                _claudeModelTouched = true;
              });
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
            codexReasoningEfforts: codexReasoningEffortsForModel(
              _selectedModel ?? _codexModelList.firstOrNull,
              _codexModelReasoningEfforts,
            ),
            onSelectedModelChanged: (value) {
              setState(() {
                _selectedModel = value;
                _codexModelTouched = true;
                _normalizeSelectedCodexReasoningEffort();
                if (_codexSpeed == CodexSpeed.fast &&
                    !codexAvailableSpeeds(
                      value,
                      _codexModelServiceTiers,
                      modelServiceTierMetadata: _codexModelServiceTierMetadata,
                      supportsExtendedServiceTiers:
                          _supportsExtendedServiceTiers,
                    ).contains(CodexSpeed.fast)) {
                  _codexSpeed = CodexSpeed.standard;
                }
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
            codexSpeed: _codexSpeed,
            codexAvailableSpeeds: _availableCodexSpeeds,
            onCodexSpeedChanged: (value) {
              setState(() => _codexSpeed = value);
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
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NewSessionDragHandle(appColors: appColors),
              NewSessionSheetTitle(
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
              NewSessionSheetActions(
                provider: _provider,
                canStart:
                    _hasPath &&
                    (_provider != Provider.codex || _isCodexSpeedAvailable) &&
                    (!widget.multiProjectOnly || _selectedProjectId != null) &&
                    !_pendingInitialWorkspaceSelection &&
                    (!_useWorktree ||
                        _worktreeMode == NewSessionWorktreeMode.createNew ||
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
