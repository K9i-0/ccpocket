import 'dart:async';

import 'package:flutter/material.dart';

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

PermissionMode _permissionModeFromRaw(String? raw) =>
    enumByValue(PermissionMode.values, raw, (v) => v.value) ??
    PermissionMode.acceptEdits;

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
    permissionMode: _permissionModeFromRaw(json['permissionMode'] as String?),
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
    _approvalPolicy = p.approvalPolicy ?? _approvalPolicy;
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
      _maxTurnsError = 'Must be an integer > 0';
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
      _maxBudgetError = 'Must be a number >= 0';
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

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(appColors),
            _buildTitle(),
            const SizedBox(height: 12),
            if (_effectiveProjects.isNotEmpty) ...[
              _buildRecentProjectsSection(appColors),
              _buildDivider(appColors),
            ],
            _buildPathInput(),
            const SizedBox(height: 12),
            _buildOptions(appColors),
            const SizedBox(height: 12),
            _buildActions(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(AppColors appColors) {
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

  Widget _buildTitle() {
    final colorScheme = Theme.of(context).colorScheme;
    final claudeStyle = providerStyleFor(context, Provider.claude);
    final codexStyle = providerStyleFor(context, Provider.codex);
    final claudeLabelColor = _provider == Provider.claude
        ? claudeStyle.foreground
        : claudeStyle.foreground.withValues(alpha: 0.72);
    final codexLabelColor = _provider == Provider.codex
        ? codexStyle.foreground
        : codexStyle.foreground.withValues(alpha: 0.72);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Session',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<Provider>(
              segments: [
                ButtonSegment(
                  value: Provider.claude,
                  label: Text(
                    Provider.claude.label,
                    style: TextStyle(fontSize: 13, color: claudeLabelColor),
                  ),
                  icon: Icon(
                    claudeStyle.icon,
                    size: 16,
                    color: claudeLabelColor,
                  ),
                ),
                ButtonSegment(
                  value: Provider.codex,
                  label: Text(
                    Provider.codex.label,
                    style: TextStyle(fontSize: 13, color: codexLabelColor),
                  ),
                  icon: Icon(codexStyle.icon, size: 16, color: codexLabelColor),
                ),
              ],
              selected: {_provider},
              onSelectionChanged: widget.lockProvider
                  ? null
                  : (selected) {
                      setState(() {
                        _provider = selected.first;
                      });
                    },
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: colorScheme.surfaceContainerLow,
                selectedBackgroundColor: colorScheme.surfaceContainerHighest,
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProjectsSection(AppColors appColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Recent Projects',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: appColors.subtleText,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final project in _effectiveProjects)
          _buildProjectTile(project, appColors),
      ],
    );
  }

  Widget _buildProjectTile(
    ({String path, String name}) project,
    AppColors appColors,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _pathController.text == project.path;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
      onTap: () => _onProjectSelected(project.path),
    );
  }

  Widget _buildDivider(AppColors appColors) {
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
              'or enter path',
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

  Widget _buildPathInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        key: const ValueKey('dialog_project_path'),
        controller: _pathController,
        decoration: const InputDecoration(
          labelText: 'Project Path',
          hintText: '/path/to/your/project',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildOptions(AppColors appColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary control: Permission (Claude) or Approval (Codex)
          if (_provider == Provider.claude)
            DropdownButtonFormField<PermissionMode>(
              key: const ValueKey('dialog_permission_mode'),
              initialValue: _permissionMode,
              decoration: const InputDecoration(
                labelText: 'Permission',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: PermissionMode.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(
                        m.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _permissionMode = value);
                }
              },
            ),
          if (_provider == Provider.codex)
            DropdownButtonFormField<ApprovalPolicy>(
              key: const ValueKey('dialog_codex_approval'),
              initialValue: _approvalPolicy,
              decoration: const InputDecoration(
                labelText: 'Approval',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: ApprovalPolicy.values
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                        p.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _approvalPolicy = value);
                }
              },
            ),
          const SizedBox(height: 8),
          // Worktree toggle (shared)
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              key: const ValueKey('dialog_worktree'),
              avatar: _useWorktree
                  ? null
                  : const Icon(Icons.account_tree_outlined, size: 16),
              label: const Text('Worktree', style: TextStyle(fontSize: 13)),
              selected: _useWorktree,
              onSelected: _onWorktreeToggle,
            ),
          ),
          if (_useWorktree) ...[
            const SizedBox(height: 8),
            _buildWorktreeOptions(appColors),
          ],
          // Advanced section (unified for both providers)
          const SizedBox(height: 8),
          _buildAdvancedOptions(appColors),
        ],
      ),
    );
  }

  /// Unified Advanced options section for both providers.
  Widget _buildAdvancedOptions(AppColors appColors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: appColors.subtleText.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        key: ValueKey('dialog_advanced_${_provider.value}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: const Text('Advanced', style: TextStyle(fontSize: 13)),
        children: _provider == Provider.claude
            ? _buildClaudeAdvancedChildren()
            : _buildCodexAdvancedChildren(),
      ),
    );
  }

  List<Widget> _buildClaudeAdvancedChildren() {
    return [
      TextField(
        key: const ValueKey('dialog_claude_model'),
        controller: _claudeModelController,
        decoration: const InputDecoration(
          labelText: 'Model (optional)',
          hintText: 'claude-sonnet-4-5',
          border: OutlineInputBorder(),
          isDense: true,
          prefixIcon: Icon(Icons.psychology_outlined, size: 18),
        ),
        style: const TextStyle(fontSize: 13),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<ClaudeEffort?>(
              key: const ValueKey('dialog_claude_effort'),
              initialValue: _claudeEffort,
              decoration: const InputDecoration(
                labelText: 'Effort',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: [
                const DropdownMenuItem<ClaudeEffort?>(
                  value: null,
                  child: Text('Default', style: TextStyle(fontSize: 13)),
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
                setState(() => _claudeEffort = value);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('dialog_claude_max_turns'),
              controller: _claudeMaxTurnsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Max Turns',
                hintText: 'e.g. 8',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _maxTurnsError,
                errorStyle: const TextStyle(fontSize: 11),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) {
                setState(() => _validateMaxTurns());
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
              controller: _claudeMaxBudgetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Max Budget (USD)',
                hintText: 'e.g. 1.00',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _maxBudgetError,
                errorStyle: const TextStyle(fontSize: 11),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) {
                setState(() => _validateMaxBudget());
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('dialog_claude_fallback_model'),
              controller: _claudeFallbackModelController,
              decoration: const InputDecoration(
                labelText: 'Fallback Model',
                hintText: 'claude-haiku-4-5',
                border: OutlineInputBorder(),
                isDense: true,
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
        title: const Text(
          'Fork Session on Resume',
          style: TextStyle(fontSize: 13),
        ),
        value: _claudeForkSession,
        onChanged: (value) {
          setState(() => _claudeForkSession = value);
        },
      ),
      SwitchListTile(
        key: const ValueKey('dialog_claude_persist_session'),
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Persist Session History',
          style: TextStyle(fontSize: 13),
        ),
        value: _claudePersistSession,
        onChanged: (value) {
          setState(() => _claudePersistSession = value);
        },
      ),
    ];
  }

  List<Widget> _buildCodexAdvancedChildren() {
    return [
      DropdownButtonFormField<String?>(
        key: const ValueKey('dialog_codex_model'),
        initialValue: _selectedModel,
        decoration: const InputDecoration(
          labelText: 'Model',
          border: OutlineInputBorder(),
          isDense: true,
          prefixIcon: Icon(Icons.psychology_outlined, size: 18),
        ),
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Default', style: TextStyle(fontSize: 13)),
          ),
          for (final model in _codexModels)
            DropdownMenuItem<String?>(
              value: model,
              child: Text(model, style: const TextStyle(fontSize: 13)),
            ),
        ],
        onChanged: (value) => setState(() => _selectedModel = value),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<SandboxMode>(
        key: const ValueKey('dialog_codex_sandbox'),
        initialValue: _sandboxMode,
        decoration: const InputDecoration(
          labelText: 'Sandbox',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: SandboxMode.values
            .map(
              (m) => DropdownMenuItem(
                value: m,
                child: Text(m.label, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _sandboxMode = value);
        },
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<ReasoningEffort?>(
              key: const ValueKey('dialog_codex_reasoning_effort'),
              initialValue: _modelReasoningEffort,
              decoration: const InputDecoration(
                labelText: 'Reasoning',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: [
                const DropdownMenuItem<ReasoningEffort?>(
                  value: null,
                  child: Text('Default', style: TextStyle(fontSize: 13)),
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
                setState(() => _modelReasoningEffort = value);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<WebSearchMode?>(
              key: const ValueKey('dialog_codex_web_search_mode'),
              initialValue: _webSearchMode,
              decoration: const InputDecoration(
                labelText: 'Web Search',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: [
                const DropdownMenuItem<WebSearchMode?>(
                  value: null,
                  child: Text('Default', style: TextStyle(fontSize: 13)),
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
                setState(() => _webSearchMode = value);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      SwitchListTile(
        key: const ValueKey('dialog_codex_network_access'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Network Access', style: TextStyle(fontSize: 13)),
        value: _networkAccessEnabled,
        onChanged: (value) {
          setState(() => _networkAccessEnabled = value);
        },
      ),
    ];
  }

  Widget _buildWorktreeOptions(AppColors appColors) {
    final cs = Theme.of(context).colorScheme;
    final hasWorktrees = _worktrees != null && _worktrees!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode selection: New / Existing
        if (hasWorktrees) ...[
          Row(
            children: [
              ChoiceChip(
                label: const Text('New', style: TextStyle(fontSize: 12)),
                selected: _worktreeMode == _WorktreeMode.createNew,
                onSelected: (_) => setState(() {
                  _worktreeMode = _WorktreeMode.createNew;
                  _selectedWorktree = null;
                }),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(
                  'Existing (${_worktrees!.length})',
                  style: const TextStyle(fontSize: 12),
                ),
                selected: _worktreeMode == _WorktreeMode.useExisting,
                onSelected: (_) => setState(() {
                  _worktreeMode = _WorktreeMode.useExisting;
                }),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // New worktree: branch input
        if (_worktreeMode == _WorktreeMode.createNew)
          TextField(
            key: const ValueKey('dialog_worktree_branch'),
            controller: _branchController,
            decoration: const InputDecoration(
              labelText: 'Branch (optional)',
              hintText: 'ccpocket/<auto>',
              border: OutlineInputBorder(),
              isDense: true,
              prefixIcon: Icon(Icons.account_tree_outlined, size: 18),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        // Existing worktree selection
        if (_worktreeMode == _WorktreeMode.useExisting) ...[
          if (_worktrees == null)
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
          else if (_worktrees!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No existing worktrees',
                style: TextStyle(fontSize: 13, color: appColors.subtleText),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final wt in _worktrees!)
                      _buildWorktreeSelectionTile(wt, cs, appColors),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildWorktreeSelectionTile(
    WorktreeInfo wt,
    ColorScheme cs,
    AppColors appColors,
  ) {
    final isSelected = _selectedWorktree?.worktreePath == wt.worktreePath;
    return InkWell(
      onTap: () => setState(() => _selectedWorktree = wt),
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
                    wt.branch,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? cs.tertiary : null,
                    ),
                  ),
                  Text(
                    wt.worktreePath.split('/').last,
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

  Widget _buildActions() {
    final canStart =
        _hasPath &&
        (!_useWorktree ||
            _worktreeMode == _WorktreeMode.createNew ||
            _selectedWorktree != null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              key: const ValueKey('dialog_start_button'),
              onPressed: canStart ? _start : null,
              child: const Text('Start'),
            ),
          ),
        ],
      ),
    );
  }
}
