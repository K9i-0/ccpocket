import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../models/model_picker_style.dart';
import '../../theme/app_theme.dart';
import '../antigravity_model_options_panel.dart';
import '../model_picker.dart';
import '../claude_settings_panel.dart';
import '../codex_effort_slider.dart';
import 'project_choice.dart';
import 'advanced_options.dart';
import 'worktree_options.dart';

class NewSessionOptionsSection extends StatelessWidget {
  final AppColors appColors;
  final Provider provider;
  final bool showExtendedCodexEfforts;
  final ModelPickerStyle modelPickerStyle;
  final PermissionMode claudePermissionMode;
  final ValueChanged<PermissionMode> onClaudePermissionModeChanged;
  final PermissionMode antigravityPermissionMode;
  final List<PermissionMode> antigravityPermissionModes;
  final ValueChanged<PermissionMode> onAntigravityPermissionModeChanged;

  /// Model families from the Bridge's catalog; empty when it is not known.
  final List<AntigravityModelOption> antigravityModelOptions;
  final AntigravityModelOption? antigravityModelOption;
  final String? antigravityThoughtLevel;
  final String? antigravityTierName;
  final ValueChanged<AntigravityModelOption> onAntigravityModelChanged;
  final ValueChanged<String?> onAntigravityThoughtLevelChanged;
  final ExecutionMode executionMode;
  final ValueChanged<ExecutionMode> onExecutionModeChanged;
  final CodexPermissionsMode codexPermissionsMode;
  final bool codexAutoReviewDisabled;
  final ValueChanged<CodexPermissionsMode> onCodexPermissionsModeChanged;
  final List<String> codexProfiles;
  final String? selectedCodexProfile;
  final ValueChanged<String?> onCodexProfileChanged;
  final bool planMode;
  final ValueChanged<bool> onPlanModeChanged;
  final bool useWorktree;
  final ValueChanged<bool> onWorktreeToggle;
  final NewSessionWorktreeMode worktreeMode;
  final ValueChanged<NewSessionWorktreeMode> onWorktreeModeChanged;
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
  final Map<String, ClaudeModelOption> claudeModelOptions;
  final Map<String, List<ClaudeEffort>> claudeModelEfforts;
  final String? selectedClaudeModel;
  final ValueChanged<String?> onClaudeModelChanged;
  final ClaudeEffort claudeEffort;
  final ValueChanged<ClaudeEffort> onClaudeEffortChanged;
  final bool claudeFastMode;
  final bool claudeUltracode;
  final ValueChanged<bool> onClaudeFastModeChanged;
  final ValueChanged<bool> onClaudeUltracodeChanged;
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
  final List<ReasoningEffort> codexReasoningEfforts;
  final ValueChanged<String?> onSelectedModelChanged;
  final SandboxMode sandboxMode;
  final ValueChanged<SandboxMode> onSandboxModeChanged;
  final ReasoningEffort modelReasoningEffort;
  final ValueChanged<ReasoningEffort> onModelReasoningEffortChanged;
  final CodexSpeed codexSpeed;
  final List<CodexSpeed> codexAvailableSpeeds;
  final ValueChanged<CodexSpeed> onCodexSpeedChanged;
  final WebSearchMode? webSearchMode;
  final ValueChanged<WebSearchMode?> onWebSearchModeChanged;
  final bool networkAccessEnabled;
  final ValueChanged<bool> onNetworkAccessChanged;

  const NewSessionOptionsSection({
    super.key,
    required this.appColors,
    required this.provider,
    required this.showExtendedCodexEfforts,
    required this.modelPickerStyle,
    required this.claudePermissionMode,
    required this.onClaudePermissionModeChanged,
    required this.antigravityPermissionMode,
    required this.antigravityPermissionModes,
    required this.onAntigravityPermissionModeChanged,
    required this.antigravityModelOptions,
    required this.antigravityModelOption,
    required this.antigravityThoughtLevel,
    required this.antigravityTierName,
    required this.onAntigravityModelChanged,
    required this.onAntigravityThoughtLevelChanged,
    required this.executionMode,
    required this.onExecutionModeChanged,
    required this.codexPermissionsMode,
    required this.codexAutoReviewDisabled,
    required this.onCodexPermissionsModeChanged,
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
    required this.claudeModelOptions,
    required this.claudeModelEfforts,
    required this.selectedClaudeModel,
    required this.onClaudeModelChanged,
    required this.claudeEffort,
    required this.onClaudeEffortChanged,
    required this.claudeFastMode,
    required this.claudeUltracode,
    required this.onClaudeFastModeChanged,
    required this.onClaudeUltracodeChanged,
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
    required this.codexReasoningEfforts,
    required this.onSelectedModelChanged,
    required this.sandboxMode,
    required this.onSandboxModeChanged,
    required this.modelReasoningEffort,
    required this.onModelReasoningEffortChanged,
    required this.codexSpeed,
    required this.codexAvailableSpeeds,
    required this.onCodexSpeedChanged,
    required this.webSearchMode,
    required this.onWebSearchModeChanged,
    required this.networkAccessEnabled,
    required this.onNetworkAccessChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selectedPermissionMode = switch (provider) {
      Provider.claude => claudePermissionMode,
      Provider.antigravity => antigravityPermissionMode,
      Provider.codex => legacyPermissionModeFromModes(
        provider,
        executionMode: executionMode,
        planMode: planMode,
      ),
    };
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

    IconData codexPermissionsIcon(CodexPermissionsMode mode) => switch (mode) {
      CodexPermissionsMode.defaultPermissions => Icons.back_hand_outlined,
      CodexPermissionsMode.autoReview => Icons.shield_outlined,
      CodexPermissionsMode.fullAccess => Icons.warning_amber_outlined,
      CodexPermissionsMode.custom => Icons.settings_outlined,
    };

    String codexPermissionsDescription(CodexPermissionsMode mode) =>
        switch (mode) {
          CodexPermissionsMode.defaultPermissions =>
            l.sandboxRestrictedDescription,
          CodexPermissionsMode.autoReview =>
            codexAutoReviewDisabled
                ? l.codexAutoReviewDisabledByPolicy
                : l.codexAutoReviewDescription,
          CodexPermissionsMode.fullAccess => l.sandboxNativeCautionDescription,
          CodexPermissionsMode.custom =>
            selectedCodexProfile == null
                ? 'Codex uses permissions from config.toml'
                : 'Codex uses permissions from the selected profile',
        };

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

    String antigravityPermissionDescription(PermissionMode mode) =>
        mode == PermissionMode.auto
        ? l.permissionAutoDescriptionAntigravity
        : permissionDescription(mode);

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
      bool Function(T)? enabledFor,
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
                            enabled: enabledFor?.call(mode) ?? true,
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
                            onTap: (enabledFor?.call(mode) ?? true)
                                ? () {
                                    Navigator.pop(sheetContext);
                                    onSelected(mode);
                                  }
                                : null,
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
                  key: const ValueKey('dialog_codex_permissions_mode'),
                  label: 'Permissions',
                  icon: codexPermissionsIcon(codexPermissionsMode),
                  title: codexPermissionsMode.label,
                  subtitle: codexPermissionsDescription(codexPermissionsMode),
                  accentColor:
                      codexPermissionsMode == CodexPermissionsMode.fullAccess
                      ? Theme.of(context).colorScheme.error
                      : null,
                  onTap: () => showModeSheet<CodexPermissionsMode>(
                    title: 'Permissions',
                    subtitle: l.sheetSubtitleApproval,
                    modes: CodexPermissionsMode.values,
                    currentMode: codexPermissionsMode,
                    iconFor: codexPermissionsIcon,
                    labelFor: (mode) => mode.label,
                    descriptionFor: codexPermissionsDescription,
                    enabledFor: (mode) =>
                        !codexAutoReviewDisabled ||
                        mode != CodexPermissionsMode.autoReview,
                    onSelected: onCodexPermissionsModeChanged,
                    colorFor: (mode, cs) => switch (mode) {
                      CodexPermissionsMode.fullAccess => cs.error,
                      CodexPermissionsMode.autoReview => cs.primary,
                      _ => cs.primary,
                    },
                  ),
                )
              : provider == Provider.antigravity
              ? modeSelectorField(
                  key: const ValueKey('dialog_antigravity_permission_mode'),
                  label: l.approval,
                  icon: permissionIcon(antigravityPermissionMode),
                  title: antigravityPermissionMode.label,
                  subtitle: antigravityPermissionDescription(
                    antigravityPermissionMode,
                  ),
                  accentColor: switch (antigravityPermissionMode) {
                    PermissionMode.auto => autoModeColor,
                    PermissionMode.bypassPermissions => Theme.of(
                      context,
                    ).colorScheme.error,
                    _ => null,
                  },
                  onTap: () => showModeSheet<PermissionMode>(
                    title: l.approval,
                    subtitle: l.sheetSubtitleApproval,
                    // The account's own list once the Bridge reported it.
                    modes: antigravityPermissionModes,
                    currentMode: antigravityPermissionMode,
                    iconFor: permissionIcon,
                    labelFor: (m) => m.label,
                    descriptionFor: antigravityPermissionDescription,
                    onSelected: onAntigravityPermissionModeChanged,
                    colorFor: (mode, cs) => switch (mode) {
                      PermissionMode.auto => autoModeColor,
                      PermissionMode.bypassPermissions => cs.error,
                      _ => cs.tertiary,
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
          if (isClaude) ...[
            const SizedBox(height: 8),
            modeSelectorField(
              key: const ValueKey('dialog_sandbox'),
              label: l.sandbox,
              icon: sandboxIcon(sandboxMode),
              title: sandboxLabel(sandboxMode),
              subtitle: sandboxDescription(sandboxMode),
              onTap: () => showModeSheet<SandboxMode>(
                title: l.sandbox,
                subtitle: l.sheetSubtitleSandboxClaude,
                modes: SandboxMode.values.reversed.toList(),
                currentMode: sandboxMode,
                iconFor: sandboxIcon,
                labelFor: sandboxLabel,
                descriptionFor: sandboxDescription,
                onSelected: onSandboxModeChanged,
                colorFor: (mode, cs) => cs.primary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (provider == Provider.antigravity)
            if (antigravityModelOption case final option?) ...[
              AntigravityModelOptionsPanel(
                key: const ValueKey('dialog_antigravity_settings'),
                keyPrefix: 'dialog_antigravity',
                modelOptions: antigravityModelOptions,
                model: option.id,
                thoughtLevel: antigravityThoughtLevel,
                thoughtLevels: option.thoughtLevels,
                tierName: antigravityTierName,
                modelPickerStyle: modelPickerStyle,
                onModelSelected: onAntigravityModelChanged,
                onThoughtLevelSelected: onAntigravityThoughtLevelChanged,
              ),
              const SizedBox(height: 4),
            ],
          if (provider == Provider.antigravity &&
              antigravityModelOption == null)
            Padding(
              key: const ValueKey('dialog_antigravity_model_note'),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l.antigravityModelAfterStartNote,
                style: TextStyle(
                  fontSize: 12,
                  color: appColors.subtleText,
                  height: 1.4,
                ),
              ),
            ),
          if (provider == Provider.claude)
            ClaudeSettingsPanel(
              key: const ValueKey('dialog_claude_settings'),
              keyPrefix: 'dialog_claude',
              models: [
                for (final model in claudeModels)
                  claudeModelOptions[model] ?? ClaudeModelOption(value: model),
              ],
              modelEfforts: claudeModelEfforts,
              model: selectedClaudeModel ?? claudeModels.firstOrNull,
              effort: claudeEffort,
              fastMode: claudeFastMode,
              ultracode: claudeUltracode,
              modelPickerStyle: modelPickerStyle,
              onModelChanged: onClaudeModelChanged,
              onEffortChanged: onClaudeEffortChanged,
              onFastModeChanged: onClaudeFastModeChanged,
              onUltracodeChanged: onClaudeUltracodeChanged,
            ),
          if (provider == Provider.codex && codexReasoningEfforts.isNotEmpty)
            _CodexSettingsSwitcher(
              buildInputDecoration: buildInputDecoration,
              models: codexModels,
              selectedModel: selectedModel ?? codexModels.firstOrNull,
              onModelChanged: onSelectedModelChanged,
              reasoningEfforts: codexReasoningEfforts,
              reasoningEffort: modelReasoningEffort,
              onReasoningEffortChanged: onModelReasoningEffortChanged,
              showExtendedEfforts: showExtendedCodexEfforts,
              modelPickerStyle: modelPickerStyle,
              speed: codexSpeed,
              availableSpeeds: codexAvailableSpeeds,
              onSpeedChanged: onCodexSpeedChanged,
            ),
          const SizedBox(height: 8),
          // Worktree toggle (shared) + inline options when expanded
          _WorktreeToggleTile(
            useWorktree: useWorktree,
            onChanged: onWorktreeToggle,
            worktreeOptions: useWorktree
                ? NewSessionWorktreeOptions(
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
          const SizedBox(height: 8),
          // Antigravity has no Claude / Codex advanced options.
          if (provider != Provider.antigravity)
            NewSessionAdvancedOptions(
              provider: provider,
              buildInputDecoration: buildInputDecoration,
              claudeModels: claudeModels,
              claudeModelOptions: claudeModelOptions,
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
                    message: 'Creates an isolated git working tree for this session.',
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

class NewSessionResponsiveOptionRow extends StatelessWidget {
  final Widget leading;
  final Widget trailing;

  const NewSessionResponsiveOptionRow({
    super.key,
    required this.leading,
    required this.trailing,
  });

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

class _CodexSettingsSwitcher extends StatefulWidget {
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;
  final List<String> models;
  final String? selectedModel;
  final ValueChanged<String?> onModelChanged;
  final List<ReasoningEffort> reasoningEfforts;
  final ReasoningEffort reasoningEffort;
  final ValueChanged<ReasoningEffort> onReasoningEffortChanged;
  final bool showExtendedEfforts;
  final ModelPickerStyle modelPickerStyle;
  final CodexSpeed speed;
  final List<CodexSpeed> availableSpeeds;
  final ValueChanged<CodexSpeed> onSpeedChanged;

  const _CodexSettingsSwitcher({
    required this.buildInputDecoration,
    required this.models,
    required this.selectedModel,
    required this.onModelChanged,
    required this.reasoningEfforts,
    required this.reasoningEffort,
    required this.onReasoningEffortChanged,
    required this.showExtendedEfforts,
    this.modelPickerStyle = ModelPickerStyle.bottomSheet,
    required this.speed,
    required this.availableSpeeds,
    required this.onSpeedChanged,
  });

  @override
  State<_CodexSettingsSwitcher> createState() => _CodexSettingsSwitcherState();
}

class _CodexSettingsSwitcherState extends State<_CodexSettingsSwitcher> {
  bool _showAdvanced = false;

  void _openModelPicker(BuildContext anchorContext) {
    final activeModel = widget.selectedModel ?? widget.models.firstOrNull;
    showModelPicker<String>(
      context: context,
      anchorContext: anchorContext,
      style: widget.modelPickerStyle,
      title: AppLocalizations.of(context).model,
      values: widget.models,
      selected: activeModel,
      label: codexModelDisplayName,
      optionKey: (m) => 'dialog_codex_model_${m}_option',
      onSelected: widget.onModelChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final effectiveEffort =
        widget.reasoningEfforts.contains(widget.reasoningEffort)
        ? widget.reasoningEffort
        : widget.reasoningEfforts.first;

    return CodexSettingsPanel(
      modelLabel: codexModelDisplayName(
        widget.selectedModel ?? widget.models.firstOrNull ?? 'gpt-5.5',
      ),
      effortLabel: effectiveEffort.label,
      speed: widget.speed,
      availableSpeeds: widget.availableSpeeds,
      supportsFast: widget.availableSpeeds.contains(CodexSpeed.fast),
      onSpeedChanged: widget.onSpeedChanged,
      speedButtonKey: 'dialog_codex_speed_button',
      showAdvanced: _showAdvanced,
      advancedLabel: l.advanced,
      toggleButtonKey: 'dialog_codex_settings_mode',
      onToggleMode: () => setState(() => _showAdvanced = !_showAdvanced),
      quickPanelKey: 'dialog_codex_quick_panel',
      advancedPanelKey: 'dialog_codex_advanced_panel',
      modelLabelKey: 'dialog_codex_model_label',
      effortLabelKey: 'dialog_codex_effort_label',
      onModelTapWithContext: widget.models.isEmpty ? null : _openModelPicker,
      quickChild: CodexEffortSlider(
        key: const ValueKey('dialog_codex_effort_control'),
        efforts: widget.reasoningEfforts,
        value: effectiveEffort,
        onChanged: widget.onReasoningEffortChanged,
        sliderKey: 'dialog_codex_effort_slider',
        includeExtended: widget.showExtendedEfforts,
      ),
      advancedChild: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          children: NewSessionCodexModelOptions(
            buildInputDecoration: widget.buildInputDecoration,
            models: widget.models,
            selectedModel: widget.selectedModel,
            onModelChanged: widget.onModelChanged,
            reasoningEfforts: widget.reasoningEfforts,
            reasoningEffort: effectiveEffort,
            onReasoningEffortChanged: widget.onReasoningEffortChanged,
            speed: widget.speed,
            availableSpeeds: widget.availableSpeeds,
            onSpeedChanged: widget.onSpeedChanged,
          ).buildChildren(context),
        ),
      ),
    );
  }
}
