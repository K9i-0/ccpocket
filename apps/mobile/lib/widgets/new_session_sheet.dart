import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../features/session_list/session_list_screen.dart' show shortenPath;
import '../services/bridge_service.dart';
import '../theme/app_theme.dart';
import '../theme/provider_style.dart';

/// Result returned when the user submits the new session sheet.
class NewSessionParams {
  final String projectPath;
  final Provider provider;
  final PermissionMode permissionMode;
  final bool useWorktree;
  final String? worktreeBranch;
  final String? existingWorktreePath;
  final String? model;
  final SandboxMode? sandboxMode;
  final ApprovalPolicy? approvalPolicy;
  final ReasoningEffort? modelReasoningEffort;
  final bool? networkAccessEnabled;
  final WebSearchMode? webSearchMode;
  final String? claudeModel;
  final ClaudeEffort? claudeEffort;
  final int? claudeMaxTurns;
  final double? claudeMaxBudgetUsd;
  final String? claudeFallbackModel;
  final bool? claudeForkSession;
  final bool? claudePersistSession;

  const NewSessionParams({
    required this.projectPath,
    this.provider = Provider.claude,
    required this.permissionMode,
    this.useWorktree = false,
    this.worktreeBranch,
    this.existingWorktreePath,
    this.model,
    this.sandboxMode,
    this.approvalPolicy,
    this.modelReasoningEffort,
    this.networkAccessEnabled,
    this.webSearchMode,
    this.claudeModel,
    this.claudeEffort,
    this.claudeMaxTurns,
    this.claudeMaxBudgetUsd,
    this.claudeFallbackModel,
    this.claudeForkSession,
    this.claudePersistSession,
  });
}

// ---- Serialization helpers for SharedPreferences ----

T? enumByValue<T>(List<T> values, String? raw, String Function(T) readValue) {
  if (raw == null || raw.isEmpty) return null;
  for (final v in values) {
    if (readValue(v) == raw) return v;
  }
  return null;
}

SandboxMode? sandboxModeFromRaw(String? raw) =>
    enumByValue(SandboxMode.values, raw, (v) => v.value);

ApprovalPolicy? approvalPolicyFromRaw(String? raw) =>
    enumByValue(ApprovalPolicy.values, raw, (v) => v.value);

ReasoningEffort? reasoningEffortFromRaw(String? raw) =>
    enumByValue(ReasoningEffort.values, raw, (v) => v.value);

WebSearchMode? webSearchModeFromRaw(String? raw) =>
    enumByValue(WebSearchMode.values, raw, (v) => v.value);

Provider _providerFromRaw(String? raw) =>
    enumByValue(Provider.values, raw, (v) => v.value) ?? Provider.claude;

PermissionMode? permissionModeFromRaw(String? raw) =>
    enumByValue(PermissionMode.values, raw, (v) => v.value);

PermissionMode _permissionModeFromRawWithDefault(String? raw) =>
    permissionModeFromRaw(raw) ?? PermissionMode.acceptEdits;

ClaudeEffort? _claudeEffortFromRaw(String? raw) =>
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
    'permissionMode': params.permissionMode.value,
    // NOTE: useWorktree, worktreeBranch, existingWorktreePath are
    // session-specific and intentionally NOT persisted.
    'model': params.model,
    'sandboxMode': params.sandboxMode?.value,
    'approvalPolicy': params.approvalPolicy?.value,
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
  return NewSessionParams(
    projectPath: projectPath,
    provider: _providerFromRaw(json['provider'] as String?),
    permissionMode: _permissionModeFromRawWithDefault(
      json['permissionMode'] as String?,
    ),
    // useWorktree, worktreeBranch, existingWorktreePath default to off/null
    model: json['model'] as String?,
    sandboxMode: sandboxModeFromRaw(json['sandboxMode'] as String?),
    approvalPolicy: approvalPolicyFromRaw(json['approvalPolicy'] as String?),
    modelReasoningEffort: reasoningEffortFromRaw(
      json['modelReasoningEffort'] as String?,
    ),
    networkAccessEnabled: json['networkAccessEnabled'] as bool?,
    webSearchMode: webSearchModeFromRaw(json['webSearchMode'] as String?),
    claudeModel: json['claudeModel'] as String?,
    claudeEffort: _claudeEffortFromRaw(json['claudeEffort'] as String?),
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
}) {
  return showModalBottomSheet<NewSessionParams>(
    context: context,
    isScrollControlled: true,
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
    ),
  );
}

/// Maximum number of recent projects shown in the bottom sheet.
const _maxRecentProjects = 5;

class _NewSessionSheetContent extends StatefulWidget {
  final List<({String path, String name})> recentProjects;
  final List<String> projectHistory;
  final BridgeService? bridge;
  final NewSessionParams? initialParams;
  final bool lockProvider;

  const _NewSessionSheetContent({
    required this.recentProjects,
    this.projectHistory = const [],
    this.bridge,
    this.initialParams,
    this.lockProvider = false,
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

/// Available Codex models for the dropdown.
const _codexModels = <String>[
  'gpt-5.3-codex',
  'gpt-5.3-codex-spark',
  'gpt-5.2-codex',
  'gpt-5.1-codex-max',
];

class _NewSessionSheetContentState extends State<_NewSessionSheetContent> {
  final _pathController = TextEditingController();
  final _branchController = TextEditingController();
  final _claudeModelController = TextEditingController();
  final _claudeMaxTurnsController = TextEditingController();
  final _claudeMaxBudgetController = TextEditingController();
  final _claudeFallbackModelController = TextEditingController();
  var _provider = Provider.claude;
  var _permissionMode = PermissionMode.acceptEdits;
  var _useWorktree = false;
  var _worktreeMode = _WorktreeMode.createNew;
  WorktreeInfo? _selectedWorktree;
  List<WorktreeInfo>? _worktrees;
  StreamSubscription<WorktreeListMessage>? _worktreeSub;

  // Claude-specific options
  ClaudeEffort? _claudeEffort;
  bool _claudeForkSession = false;
  bool _claudePersistSession = true;

  // Codex-specific options
  String? _selectedModel;
  var _sandboxMode = SandboxMode.workspaceWrite;
  var _approvalPolicy = ApprovalPolicy.never;
  ReasoningEffort? _modelReasoningEffort;
  bool _networkAccessEnabled = true;
  WebSearchMode? _webSearchMode;

  // Inline validation errors
  String? _maxTurnsError;
  String? _maxBudgetError;

  bool get _hasPath => _pathController.text.trim().isNotEmpty;

  /// Merge projectHistory (Bridge-managed, preferred) with recentProjects (session fallback).
  /// projectHistory paths are shown first; recentProjects paths not already covered are appended.
  /// Capped at [_maxRecentProjects].
  List<({String path, String name})> get _effectiveProjects {
    List<({String path, String name})> merged;
    if (widget.projectHistory.isEmpty) {
      merged = widget.recentProjects;
    } else {
      final seen = <String>{};
      final result = <({String path, String name})>[];
      for (final path in widget.projectHistory) {
        if (seen.add(path)) {
          final name = path.split('/').last;
          result.add((path: path, name: name));
        }
      }
      for (final project in widget.recentProjects) {
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

  @override
  void initState() {
    super.initState();
    _worktreeSub = widget.bridge?.worktreeList.listen((msg) {
      if (mounted) setState(() => _worktrees = msg.worktrees);
    });
    _applyInitialParams();
    if (_useWorktree) {
      _fetchWorktrees();
    }
  }

  @override
  void dispose() {
    _worktreeSub?.cancel();
    _pathController.dispose();
    _branchController.dispose();
    _claudeModelController.dispose();
    _claudeMaxTurnsController.dispose();
    _claudeMaxBudgetController.dispose();
    _claudeFallbackModelController.dispose();
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
    _provider = p.provider;
    _permissionMode = p.permissionMode;
    _useWorktree = p.useWorktree || p.existingWorktreePath != null;
    _branchController.text = p.worktreeBranch ?? "";
    _selectedModel = p.model;
    _sandboxMode = p.sandboxMode ?? _sandboxMode;
    final restoredPolicy = p.approvalPolicy;
    // on-request is not supported via SDK; fall back to default.
    _approvalPolicy =
        restoredPolicy != null && restoredPolicy != ApprovalPolicy.onRequest
        ? restoredPolicy
        : _approvalPolicy;
    _modelReasoningEffort = p.modelReasoningEffort;
    _networkAccessEnabled = p.networkAccessEnabled ?? _networkAccessEnabled;
    _webSearchMode = p.webSearchMode;
    _claudeModelController.text = p.claudeModel ?? "";
    _claudeEffort = p.claudeEffort;
    _claudeMaxTurnsController.text = p.claudeMaxTurns?.toString() ?? "";
    _claudeMaxBudgetController.text = p.claudeMaxBudgetUsd?.toString() ?? "";
    _claudeFallbackModelController.text = p.claudeFallbackModel ?? "";
    _claudeForkSession = p.claudeForkSession ?? _claudeForkSession;
    _claudePersistSession = p.claudePersistSession ?? _claudePersistSession;

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
    final claudeModel = _claudeModelController.text.trim();
    final claudeMaxTurns = int.tryParse(_claudeMaxTurnsController.text.trim());
    final claudeMaxBudgetUsd = double.tryParse(
      _claudeMaxBudgetController.text.trim(),
    );
    final claudeFallbackModel = _claudeFallbackModelController.text.trim();

    final useExisting =
        _useWorktree && _worktreeMode == _WorktreeMode.useExisting;

    return NewSessionParams(
      projectPath: path,
      provider: _provider,
      permissionMode: _permissionMode,
      useWorktree: useExisting ? false : _useWorktree,
      worktreeBranch: useExisting
          ? _selectedWorktree?.branch
          : (branch.isNotEmpty ? branch : null),
      existingWorktreePath: useExisting
          ? _selectedWorktree?.worktreePath
          : null,
      model: isCodex ? _selectedModel : null,
      sandboxMode: isCodex ? _sandboxMode : null,
      approvalPolicy: isCodex ? _approvalPolicy : null,
      modelReasoningEffort: isCodex ? _modelReasoningEffort : null,
      networkAccessEnabled: isCodex ? _networkAccessEnabled : null,
      webSearchMode: isCodex ? _webSearchMode : null,
      claudeModel: !isCodex && claudeModel.isNotEmpty ? claudeModel : null,
      claudeEffort: !isCodex ? _claudeEffort : null,
      claudeMaxTurns: !isCodex ? claudeMaxTurns : null,
      claudeMaxBudgetUsd: !isCodex ? claudeMaxBudgetUsd : null,
      claudeFallbackModel: !isCodex && claudeFallbackModel.isNotEmpty
          ? claudeFallbackModel
          : null,
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

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DragHandle(appColors: appColors),
            _SheetTitle(
              provider: _provider,
              lockProvider: widget.lockProvider,
              onProviderChanged: (p) => setState(() => _provider = p),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_effectiveProjects.isNotEmpty) ...[
                      _RecentProjectsSection(
                        appColors: appColors,
                        projects: _effectiveProjects,
                        selectedPath: _pathController.text,
                        onProjectSelected: _onProjectSelected,
                      ),
                      _SheetDivider(appColors: appColors),
                    ],
                    _PathInput(
                      controller: _pathController,
                      decoration: _buildInputDecoration(
                        AppLocalizations.of(context).projectPath,
                        hintText: AppLocalizations.of(context).projectPathHint,
                      ),
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _OptionsSection(
                      appColors: appColors,
                      provider: _provider,
                      permissionMode: _permissionMode,
                      onPermissionModeChanged: (value) {
                        setState(() => _permissionMode = value);
                      },
                      approvalPolicy: _approvalPolicy,
                      onApprovalPolicyChanged: (value) {
                        setState(() => _approvalPolicy = value);
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
                      claudeModelController: _claudeModelController,
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
                      claudeFallbackModelController:
                          _claudeFallbackModelController,
                      claudeForkSession: _claudeForkSession,
                      onClaudeForkSessionChanged: (value) {
                        setState(() => _claudeForkSession = value);
                      },
                      claudePersistSession: _claudePersistSession,
                      onClaudePersistSessionChanged: (value) {
                        setState(() => _claudePersistSession = value);
                      },
                      // Codex advanced
                      selectedModel: _selectedModel,
                      onSelectedModelChanged: (value) {
                        setState(() => _selectedModel = value);
                      },
                      sandboxMode: _sandboxMode,
                      onSandboxModeChanged: (value) {
                        setState(() => _sandboxMode = value);
                      },
                      modelReasoningEffort: _modelReasoningEffort,
                      onModelReasoningEffortChanged: (value) {
                        setState(() => _modelReasoningEffort = value);
                      },
                      webSearchMode: _webSearchMode,
                      onWebSearchModeChanged: (value) {
                        setState(() => _webSearchMode = value);
                      },
                      networkAccessEnabled: _networkAccessEnabled,
                      onNetworkAccessChanged: (value) {
                        setState(() => _networkAccessEnabled = value);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
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
  final ValueChanged<Provider> onProviderChanged;

  const _SheetTitle({
    required this.provider,
    required this.lockProvider,
    required this.onProviderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.newSession,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
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
                Expanded(
                  child: _ProviderToggleButton(
                    provider: Provider.claude,
                    isSelected: provider == Provider.claude,
                    isLocked: lockProvider,
                    onTap: () {
                      if (!lockProvider) {
                        onProviderChanged(Provider.claude);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _ProviderToggleButton(
                    provider: Provider.codex,
                    isSelected: provider == Provider.codex,
                    isLocked: lockProvider,
                    onTap: () {
                      if (!lockProvider) {
                        onProviderChanged(Provider.codex);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentProjectsSection extends StatelessWidget {
  final AppColors appColors;
  final List<({String path, String name})> projects;
  final String selectedPath;
  final ValueChanged<String> onProjectSelected;

  const _RecentProjectsSection({
    required this.appColors,
    required this.projects,
    required this.selectedPath,
    required this.onProjectSelected,
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
          _ProjectTile(
            project: project,
            appColors: appColors,
            isSelected: selectedPath == project.path,
            onTap: () => onProjectSelected(project.path),
          ),
      ],
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final ({String path, String name}) project;
  final AppColors appColors;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProjectTile({
    required this.project,
    required this.appColors,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                  ? cs.primaryContainer.withValues(alpha: 0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.5)
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
                color: isSelected ? cs.primary : appColors.subtleText,
              ),
              title: Text(
                project.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? cs.primary : null,
                ),
              ),
              subtitle: Text(
                shortenPath(project.path),
                style: TextStyle(fontSize: 11, color: appColors.subtleText),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle, size: 20, color: cs.primary)
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

class _OptionsSection extends StatelessWidget {
  final AppColors appColors;
  final Provider provider;
  final PermissionMode permissionMode;
  final ValueChanged<PermissionMode> onPermissionModeChanged;
  final ApprovalPolicy approvalPolicy;
  final ValueChanged<ApprovalPolicy> onApprovalPolicyChanged;
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
  final TextEditingController claudeModelController;
  final ClaudeEffort? claudeEffort;
  final ValueChanged<ClaudeEffort?> onClaudeEffortChanged;
  final TextEditingController claudeMaxTurnsController;
  final String? maxTurnsError;
  final VoidCallback onMaxTurnsChanged;
  final TextEditingController claudeMaxBudgetController;
  final String? maxBudgetError;
  final VoidCallback onMaxBudgetChanged;
  final TextEditingController claudeFallbackModelController;
  final bool claudeForkSession;
  final ValueChanged<bool> onClaudeForkSessionChanged;
  final bool claudePersistSession;
  final ValueChanged<bool> onClaudePersistSessionChanged;

  // Codex advanced
  final String? selectedModel;
  final ValueChanged<String?> onSelectedModelChanged;
  final SandboxMode sandboxMode;
  final ValueChanged<SandboxMode> onSandboxModeChanged;
  final ReasoningEffort? modelReasoningEffort;
  final ValueChanged<ReasoningEffort?> onModelReasoningEffortChanged;
  final WebSearchMode? webSearchMode;
  final ValueChanged<WebSearchMode?> onWebSearchModeChanged;
  final bool networkAccessEnabled;
  final ValueChanged<bool> onNetworkAccessChanged;

  const _OptionsSection({
    required this.appColors,
    required this.provider,
    required this.permissionMode,
    required this.onPermissionModeChanged,
    required this.approvalPolicy,
    required this.onApprovalPolicyChanged,
    required this.useWorktree,
    required this.onWorktreeToggle,
    required this.worktreeMode,
    required this.onWorktreeModeChanged,
    required this.worktrees,
    required this.selectedWorktree,
    required this.onWorktreeSelected,
    required this.branchController,
    required this.buildInputDecoration,
    required this.claudeModelController,
    required this.claudeEffort,
    required this.onClaudeEffortChanged,
    required this.claudeMaxTurnsController,
    required this.maxTurnsError,
    required this.onMaxTurnsChanged,
    required this.claudeMaxBudgetController,
    required this.maxBudgetError,
    required this.onMaxBudgetChanged,
    required this.claudeFallbackModelController,
    required this.claudeForkSession,
    required this.onClaudeForkSessionChanged,
    required this.claudePersistSession,
    required this.onClaudePersistSessionChanged,
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
          // Primary control: Permission (Claude) or Approval (Codex)
          if (provider == Provider.claude)
            DropdownButtonFormField<PermissionMode>(
              key: const ValueKey('dialog_permission_mode'),
              initialValue: permissionMode,
              decoration: buildInputDecoration(l.permission),
              items: PermissionMode.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Row(
                        children: [
                          Icon(switch (m) {
                            PermissionMode.defaultMode => Icons.tune,
                            PermissionMode.plan => Icons.assignment,
                            PermissionMode.acceptEdits => Icons.edit_note,
                            PermissionMode.bypassPermissions => Icons.flash_on,
                          }, size: 16),
                          const SizedBox(width: 8),
                          Text(m.label, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onPermissionModeChanged(value);
                }
              },
            ),
          if (provider == Provider.codex)
            DropdownButtonFormField<ApprovalPolicy>(
              key: const ValueKey('dialog_codex_approval'),
              initialValue: approvalPolicy,
              decoration: buildInputDecoration(l.approval),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: ApprovalPolicy.values
                  .where((p) => p != ApprovalPolicy.onRequest)
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Row(
                        children: [
                          Icon(switch (p) {
                            ApprovalPolicy.never => Icons.flash_auto,
                            ApprovalPolicy.onRequest => Icons.front_hand,
                            ApprovalPolicy.onFailure => Icons.error_outline,
                            ApprovalPolicy.untrusted => Icons.shield_outlined,
                          }, size: 16),
                          const SizedBox(width: 8),
                          Text(p.label, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onApprovalPolicyChanged(value);
                }
              },
            ),
          const SizedBox(height: 8),
          // Worktree toggle (shared)
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilterChip(
                  key: const ValueKey('dialog_worktree'),
                  avatar: useWorktree
                      ? null
                      : Icon(
                          Icons.account_tree_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  label: Text(
                    l.worktree,
                    style: TextStyle(
                      fontSize: 13,
                      color: useWorktree
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  checkmarkColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                  selected: useWorktree,
                  onSelected: onWorktreeToggle,
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message:
                      'Creates an isolated git working tree for this session.',
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (useWorktree) ...[
            const SizedBox(height: 8),
            _WorktreeOptions(
              appColors: appColors,
              worktreeMode: worktreeMode,
              onWorktreeModeChanged: onWorktreeModeChanged,
              worktrees: worktrees,
              selectedWorktree: selectedWorktree,
              onWorktreeSelected: onWorktreeSelected,
              branchController: branchController,
              buildInputDecoration: buildInputDecoration,
            ),
          ],
          // Advanced section (unified for both providers)
          const SizedBox(height: 8),
          _AdvancedOptions(
            appColors: appColors,
            provider: provider,
            buildInputDecoration: buildInputDecoration,
            // Claude
            claudeModelController: claudeModelController,
            claudeEffort: claudeEffort,
            onClaudeEffortChanged: onClaudeEffortChanged,
            claudeMaxTurnsController: claudeMaxTurnsController,
            maxTurnsError: maxTurnsError,
            onMaxTurnsChanged: onMaxTurnsChanged,
            claudeMaxBudgetController: claudeMaxBudgetController,
            maxBudgetError: maxBudgetError,
            onMaxBudgetChanged: onMaxBudgetChanged,
            claudeFallbackModelController: claudeFallbackModelController,
            claudeForkSession: claudeForkSession,
            onClaudeForkSessionChanged: onClaudeForkSessionChanged,
            claudePersistSession: claudePersistSession,
            onClaudePersistSessionChanged: onClaudePersistSessionChanged,
            // Codex
            selectedModel: selectedModel,
            onSelectedModelChanged: onSelectedModelChanged,
            sandboxMode: sandboxMode,
            onSandboxModeChanged: onSandboxModeChanged,
            modelReasoningEffort: modelReasoningEffort,
            onModelReasoningEffortChanged: onModelReasoningEffortChanged,
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

class _AdvancedOptions extends StatelessWidget {
  final AppColors appColors;
  final Provider provider;
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;

  // Claude
  final TextEditingController claudeModelController;
  final ClaudeEffort? claudeEffort;
  final ValueChanged<ClaudeEffort?> onClaudeEffortChanged;
  final TextEditingController claudeMaxTurnsController;
  final String? maxTurnsError;
  final VoidCallback onMaxTurnsChanged;
  final TextEditingController claudeMaxBudgetController;
  final String? maxBudgetError;
  final VoidCallback onMaxBudgetChanged;
  final TextEditingController claudeFallbackModelController;
  final bool claudeForkSession;
  final ValueChanged<bool> onClaudeForkSessionChanged;
  final bool claudePersistSession;
  final ValueChanged<bool> onClaudePersistSessionChanged;

  // Codex
  final String? selectedModel;
  final ValueChanged<String?> onSelectedModelChanged;
  final SandboxMode sandboxMode;
  final ValueChanged<SandboxMode> onSandboxModeChanged;
  final ReasoningEffort? modelReasoningEffort;
  final ValueChanged<ReasoningEffort?> onModelReasoningEffortChanged;
  final WebSearchMode? webSearchMode;
  final ValueChanged<WebSearchMode?> onWebSearchModeChanged;
  final bool networkAccessEnabled;
  final ValueChanged<bool> onNetworkAccessChanged;

  const _AdvancedOptions({
    required this.appColors,
    required this.provider,
    required this.buildInputDecoration,
    required this.claudeModelController,
    required this.claudeEffort,
    required this.onClaudeEffortChanged,
    required this.claudeMaxTurnsController,
    required this.maxTurnsError,
    required this.onMaxTurnsChanged,
    required this.claudeMaxBudgetController,
    required this.maxBudgetError,
    required this.onMaxBudgetChanged,
    required this.claudeFallbackModelController,
    required this.claudeForkSession,
    required this.onClaudeForkSessionChanged,
    required this.claudePersistSession,
    required this.onClaudePersistSessionChanged,
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
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          l.advanced,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: provider == Provider.claude
            ? _ClaudeAdvancedOptions(
                buildInputDecoration: buildInputDecoration,
                claudeModelController: claudeModelController,
                claudeEffort: claudeEffort,
                onClaudeEffortChanged: onClaudeEffortChanged,
                claudeMaxTurnsController: claudeMaxTurnsController,
                maxTurnsError: maxTurnsError,
                onMaxTurnsChanged: onMaxTurnsChanged,
                claudeMaxBudgetController: claudeMaxBudgetController,
                maxBudgetError: maxBudgetError,
                onMaxBudgetChanged: onMaxBudgetChanged,
                claudeFallbackModelController: claudeFallbackModelController,
                claudeForkSession: claudeForkSession,
                onClaudeForkSessionChanged: onClaudeForkSessionChanged,
                claudePersistSession: claudePersistSession,
                onClaudePersistSessionChanged: onClaudePersistSessionChanged,
              ).buildChildren(context)
            : _CodexAdvancedOptions(
                buildInputDecoration: buildInputDecoration,
                selectedModel: selectedModel,
                onSelectedModelChanged: onSelectedModelChanged,
                sandboxMode: sandboxMode,
                onSandboxModeChanged: onSandboxModeChanged,
                modelReasoningEffort: modelReasoningEffort,
                onModelReasoningEffortChanged: onModelReasoningEffortChanged,
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
  final TextEditingController claudeModelController;
  final ClaudeEffort? claudeEffort;
  final ValueChanged<ClaudeEffort?> onClaudeEffortChanged;
  final TextEditingController claudeMaxTurnsController;
  final String? maxTurnsError;
  final VoidCallback onMaxTurnsChanged;
  final TextEditingController claudeMaxBudgetController;
  final String? maxBudgetError;
  final VoidCallback onMaxBudgetChanged;
  final TextEditingController claudeFallbackModelController;
  final bool claudeForkSession;
  final ValueChanged<bool> onClaudeForkSessionChanged;
  final bool claudePersistSession;
  final ValueChanged<bool> onClaudePersistSessionChanged;

  const _ClaudeAdvancedOptions({
    required this.buildInputDecoration,
    required this.claudeModelController,
    required this.claudeEffort,
    required this.onClaudeEffortChanged,
    required this.claudeMaxTurnsController,
    required this.maxTurnsError,
    required this.onMaxTurnsChanged,
    required this.claudeMaxBudgetController,
    required this.maxBudgetError,
    required this.onMaxBudgetChanged,
    required this.claudeFallbackModelController,
    required this.claudeForkSession,
    required this.onClaudeForkSessionChanged,
    required this.claudePersistSession,
    required this.onClaudePersistSessionChanged,
  });

  List<Widget> buildChildren(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      TextField(
        key: const ValueKey('dialog_claude_model'),
        controller: claudeModelController,
        decoration: buildInputDecoration(
          l.modelOptional,
          hintText: 'claude-sonnet-4-5',
          prefixIcon: const Icon(Icons.psychology_outlined, size: 18),
        ),
        style: const TextStyle(fontSize: 13),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<ClaudeEffort?>(
              key: const ValueKey('dialog_claude_effort'),
              initialValue: claudeEffort,
              decoration: buildInputDecoration(l.effort),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: [
                DropdownMenuItem<ClaudeEffort?>(
                  value: null,
                  child: Text(
                    l.defaultLabel,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                for (final effort in ClaudeEffort.values)
                  DropdownMenuItem<ClaudeEffort?>(
                    value: effort,
                    child: Text(
                      effort.label,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
              onChanged: (value) {
                onClaudeEffortChanged(value);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
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
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('dialog_claude_max_budget'),
              controller: claudeMaxBudgetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('dialog_claude_fallback_model'),
              controller: claudeFallbackModelController,
              decoration: buildInputDecoration(
                l.fallbackModel,
                hintText: 'claude-haiku-4-5',
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
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
  final String? selectedModel;
  final ValueChanged<String?> onSelectedModelChanged;
  final SandboxMode sandboxMode;
  final ValueChanged<SandboxMode> onSandboxModeChanged;
  final ReasoningEffort? modelReasoningEffort;
  final ValueChanged<ReasoningEffort?> onModelReasoningEffortChanged;
  final WebSearchMode? webSearchMode;
  final ValueChanged<WebSearchMode?> onWebSearchModeChanged;
  final bool networkAccessEnabled;
  final ValueChanged<bool> onNetworkAccessChanged;

  const _CodexAdvancedOptions({
    required this.buildInputDecoration,
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

  List<Widget> buildChildren(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      DropdownButtonFormField<String?>(
        key: const ValueKey('dialog_codex_model'),
        initialValue: selectedModel,
        decoration: buildInputDecoration(
          l.model,
          prefixIcon: const Icon(Icons.psychology_outlined, size: 18),
        ),
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(l.defaultLabel, style: const TextStyle(fontSize: 13)),
          ),
          for (final model in _codexModels)
            DropdownMenuItem<String?>(
              value: model,
              child: Text(model, style: const TextStyle(fontSize: 13)),
            ),
        ],
        onChanged: (value) => onSelectedModelChanged(value),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<SandboxMode>(
        key: const ValueKey('dialog_codex_sandbox'),
        initialValue: sandboxMode,
        decoration: buildInputDecoration(l.sandbox),
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: SandboxMode.values
            .map(
              (m) => DropdownMenuItem(
                value: m,
                child: Row(
                  children: [
                    Icon(switch (m) {
                      SandboxMode.workspaceWrite => Icons.edit,
                      SandboxMode.readOnly => Icons.visibility,
                      SandboxMode.dangerFullAccess => Icons.warning_amber,
                    }, size: 16),
                    const SizedBox(width: 8),
                    Text(m.label, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onSandboxModeChanged(value);
        },
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<ReasoningEffort?>(
              key: const ValueKey('dialog_codex_reasoning_effort'),
              initialValue: modelReasoningEffort,
              decoration: buildInputDecoration(l.reasoning),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: [
                DropdownMenuItem<ReasoningEffort?>(
                  value: null,
                  child: Text(
                    l.defaultLabel,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                for (final effort in ReasoningEffort.values)
                  DropdownMenuItem<ReasoningEffort?>(
                    value: effort,
                    child: Text(
                      effort.label,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
              onChanged: (value) {
                onModelReasoningEffortChanged(value);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<WebSearchMode?>(
              key: const ValueKey('dialog_codex_web_search_mode'),
              initialValue: webSearchMode,
              decoration: buildInputDecoration(l.webSearch),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: [
                DropdownMenuItem<WebSearchMode?>(
                  value: null,
                  child: Text(
                    l.defaultLabel,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                for (final mode in WebSearchMode.values)
                  DropdownMenuItem<WebSearchMode?>(
                    value: mode,
                    child: Text(
                      mode.label,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
              onChanged: (value) {
                onWebSearchModeChanged(value);
              },
            ),
          ),
        ],
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
            decoration: buildInputDecoration(
              l.branchOptional,
              hintText: l.branchHint,
              prefixIcon: const Icon(Icons.account_tree_outlined, size: 18),
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
              height: 48,
              child: FilledButton(
                key: const ValueKey('dialog_start_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: canStart ? providerStyle.background : null,
                  foregroundColor: canStart ? providerStyle.foreground : null,
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
