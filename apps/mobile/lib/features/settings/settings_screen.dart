import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_constants.dart';
import '../../constants/feature_flags.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_icon.dart';
import '../../models/git_diff_interaction_mode.dart';
import '../../models/image_paste_shortcut.dart';
import '../../models/machine.dart';
import '../../models/new_session_tab.dart';
import '../../providers/machine_manager_cubit.dart';
import '../../router/app_router.dart';
import '../../services/app_update_service.dart';
import '../../services/bridge_service.dart';
import '../../services/in_app_review_service.dart';
import '../../services/machine_manager_service.dart';
import '../../services/platform_environment_service.dart';
import '../../services/prompt_history_service.dart';
import '../../services/revenuecat_service.dart';
import '../../services/support_banner_service.dart';
import '../../utils/platform_helper.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../session_list/workspace_shell_screen.dart';
import 'code_font_settings_screen.dart';
import 'state/settings_cubit.dart';
import 'state/settings_state.dart';
import 'widgets/app_icon_bottom_sheet.dart';
import 'widgets/app_locale_bottom_sheet.dart';
import 'widgets/support_section.dart';

import 'widgets/new_session_tabs_bottom_sheet.dart';
import 'widgets/speech_locale_bottom_sheet.dart';
import 'widgets/terminal_app_bottom_sheet.dart';
import 'widgets/theme_bottom_sheet.dart';
import 'widgets/prompt_history_section.dart';
import 'widgets/usage_section.dart';

@RoutePage()
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.focusConnection = false,
    this.focusSupport = false,
    this.embedded = false,
    this.onBack,
  });

  final bool focusConnection;
  final bool focusSupport;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _scrollController = ScrollController();
  final _connectionSectionKey = GlobalKey();
  final _supportSectionKey = GlobalKey();
  Timer? _connectionHighlightTimer;
  Timer? _supportHighlightTimer;
  bool _didHandleConnectionFocus = false;
  bool _didHandleSupportFocus = false;
  bool _highlightConnectionSection = false;
  bool _highlightSupportSection = false;
  bool _isIOSAppOnMac = false;
  String _appIconDeviceName = isAndroidPlatform ? 'Android' : 'iPhone';

  void _maybeFocusConnectionSection() {
    if (!widget.focusConnection || _didHandleConnectionFocus) return;
    _didHandleConnectionFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final targetContext = _connectionSectionKey.currentContext;
      if (targetContext == null || !targetContext.mounted) {
        _didHandleConnectionFocus = false;
        return;
      }
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.0,
      );
      if (!mounted) return;

      setState(() {
        _highlightConnectionSection = true;
      });
      _connectionHighlightTimer?.cancel();
      _connectionHighlightTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() {
          _highlightConnectionSection = false;
        });
      });
    });
  }

  void _maybeFocusSupportSection() {
    if (!widget.focusSupport || _didHandleSupportFocus) return;
    _didHandleSupportFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_supportSectionKey.currentContext == null &&
          _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted) return;
      final targetContext = _supportSectionKey.currentContext;
      if (targetContext == null) {
        _didHandleSupportFocus = false;
        return;
      }
      if (!targetContext.mounted) {
        _didHandleSupportFocus = false;
        return;
      }
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
      if (!mounted) return;

      setState(() {
        _highlightSupportSection = true;
      });
      _supportHighlightTimer?.cancel();
      _supportHighlightTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() {
          _highlightSupportSection = false;
        });
      });
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlatformEnvironment());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<MachineManagerCubit>().refreshLatestBridgeVersionIfStale(),
      );
    });
  }

  Future<void> _loadPlatformEnvironment() async {
    final environment = PlatformEnvironmentService.instance;
    final isIOSAppOnMac = await environment.isIOSAppOnMac();
    final appIconDeviceName = await _resolveAppIconDeviceName(environment);
    if (!mounted) return;
    if (isIOSAppOnMac == _isIOSAppOnMac &&
        appIconDeviceName == _appIconDeviceName) {
      return;
    }
    setState(() {
      _isIOSAppOnMac = isIOSAppOnMac;
      _appIconDeviceName = appIconDeviceName;
    });
  }

  Future<String> _resolveAppIconDeviceName(
    PlatformEnvironmentService environment,
  ) async {
    if (isAndroidPlatform) return 'Android';
    if (!isIOSPlatform) return 'iPhone';

    final idiom = await environment.iosUserInterfaceIdiom();
    return idiom == 'pad' ? 'iPad' : 'iPhone';
  }

  @override
  void dispose() {
    _connectionHighlightTimer?.cancel();
    _supportHighlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shell = WorkspaceShellScreen.maybeOf(context);
    final chrome = resolveWorkspacePaneChrome(
      platform: Theme.of(context).platform,
      isAdaptiveWorkspace: shell != null && !shell.isSinglePane,
      isLeftPaneVisible: shell?.isLeftPaneVisible ?? false,
      slot: WorkspacePaneSlot.center,
    );
    final l = AppLocalizations.of(context);
    final bridge = context.read<BridgeService>();
    final revenueCat = context.read<RevenueCatService>();
    final leading = widget.onBack == null
        ? null
        : IconButton(
            key: const ValueKey('embedded_settings_back_button'),
            onPressed: widget.onBack,
            style: chrome.useMacOSAdaptiveChrome
                ? chrome.compactButtonStyle()
                : null,
            icon: const Icon(Icons.arrow_back),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          );

    return Scaffold(
      appBar: chrome.wrapAppBar(
        AppBar(
          toolbarHeight: chrome.toolbarHeight,
          title: chrome.wrapTitle(Text(l.settingsTitle)),
          automaticallyImplyLeading: !widget.embedded,
          leading: chrome.wrapLeading(leading),
          leadingWidth: chrome.resolveLeadingWidth(
            hasLeading: leading != null,
            baseWidth: chrome.useMacOSAdaptiveChrome
                ? kWorkspaceMacOSToolbarLeadingSlotWidth
                : kToolbarHeight,
          ),
          titleSpacing: chrome.resolveTitleSpacing(hasLeading: leading != null),
        ),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final machineManagerCubit = context.watch<MachineManagerCubit>();
          final machineWithStatus = _activeMachineWithStatus(
            machineManagerCubit.state,
            state.activeMachineId,
          );
          final enabledAgentsMode = enabledAgentsModeFromTabs(
            state.newSessionTabs,
          );
          final codexEnabled = isNewSessionTabEnabled(
            state.newSessionTabs,
            NewSessionTab.codex,
          );
          final claudeEnabled = isNewSessionTabEnabled(
            state.newSessionTabs,
            NewSessionTab.claude,
          );
          final machine = machineWithStatus?.machine;
          final isConnected = state.activeMachineId != null;
          final isUpdating =
              machine != null &&
              machineManagerCubit.state.updatingMachineId == machine.id;
          return ListView(
            key: const PageStorageKey('settings_list'),
            controller: _scrollController,
            scrollCacheExtent: widget.focusSupport || widget.focusConnection
                ? const ScrollCacheExtent.pixels(4096)
                : null,
            children: [
              if (isConnected) ...[
                Builder(
                  builder: (context) {
                    _maybeFocusConnectionSection();
                    return const SizedBox.shrink();
                  },
                ),
                _SectionHeader(title: l.sectionConnectionAccounts),
                KeyedSubtree(
                  key: _connectionSectionKey,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _highlightConnectionSection
                          ? [
                              BoxShadow(
                                color: cs.tertiary.withValues(alpha: 0.22),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Card(
                      key: const ValueKey('settings_connection_section_card'),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _highlightConnectionSection
                              ? cs.tertiary.withValues(alpha: 0.75)
                              : Colors.transparent,
                          width: _highlightConnectionSection ? 1.5 : 0,
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.computer_outlined,
                              color: cs.primary,
                            ),
                            title: const Text('Bridge machine'),
                            subtitle: Text(
                              machine?.displayName ??
                                  (bridge.lastUrl ?? 'Not connected'),
                            ),
                          ),
                          Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: cs.outlineVariant,
                          ),
                          _BridgeUpdateStatusTile(
                            machineWithStatus: machineWithStatus,
                            isUpdating: isUpdating,
                            latestBridgeVersion:
                                machineManagerCubit.state.latestBridgeVersion,
                            isCheckingLatestBridgeVersion: machineManagerCubit
                                .state
                                .isCheckingLatestBridgeVersion,
                            latestBridgeVersionError: machineManagerCubit
                                .state
                                .latestBridgeVersionError,
                            onRefreshLatestVersion: () => machineManagerCubit
                                .refreshLatestBridgeVersion(forceRefresh: true),
                            onUpdate: machineWithStatus == null
                                ? null
                                : () => _updateBridgeFromSettings(
                                    machineWithStatus,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // ── General ──
              _SectionHeader(title: l.sectionGeneral),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (state.appIconSupported) ...[
                      ValueListenableBuilder<SupporterState>(
                        valueListenable: revenueCat.supporterState,
                        builder: (context, supporterState, _) {
                          return ListTile(
                            key: const ValueKey('app_icon_tile'),
                            leading: Icon(
                              Icons.apps_outlined,
                              color: cs.primary,
                            ),
                            title: Text(l.appIconTitle),
                            subtitle: Text(
                              _getAppIconSubtitle(
                                context,
                                selectedIcon: state.selectedAppIcon,
                                isSupporter: supporterState.isSupporter,
                                deviceName: _appIconDeviceName,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () async {
                              if (!context.mounted) return;
                              await showAppIconBottomSheet(
                                context: context,
                                current: state.selectedAppIcon,
                                isSupporter: supporterState.isSupporter,
                                onChanged: (icon) => context
                                    .read<SettingsCubit>()
                                    .setSelectedAppIcon(icon),
                                onSupporterRequired: () =>
                                    _openSupporterPerk(context),
                              );
                            },
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                    ],
                    // Theme
                    ListTile(
                      leading: Icon(Icons.palette, color: cs.primary),
                      title: Text(l.theme),
                      subtitle: Text(_getThemeLabel(context, state.themeMode)),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => showThemeBottomSheet(
                        context: context,
                        current: state.themeMode,
                        onChanged: (mode) =>
                            context.read<SettingsCubit>().setThemeMode(mode),
                      ),
                    ),
                    // Language
                    ListTile(
                      leading: Icon(Icons.language, color: cs.primary),
                      title: Text(l.language),
                      subtitle: Text(
                        getAppLocaleLabel(context, state.appLocaleId),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => showAppLocaleBottomSheet(
                        context: context,
                        current: state.appLocaleId,
                        onChanged: (id) =>
                            context.read<SettingsCubit>().setAppLocaleId(id),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // Voice Input
                    if (!state.hideVoiceInput) ...[
                      ListTile(
                        leading: Icon(
                          Icons.record_voice_over,
                          color: cs.primary,
                        ),
                        title: Text(l.voiceInput),
                        subtitle: Text(
                          getSpeechLocaleLabel(context, state.speechLocaleId),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => showSpeechLocaleBottomSheet(
                          context: context,
                          current: state.speechLocaleId,
                          onChanged: (id) => context
                              .read<SettingsCubit>()
                              .setSpeechLocaleId(id),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                    ],
                    // Hide Voice Input
                    SwitchListTile(
                      secondary: Icon(Icons.mic_off, color: cs.primary),
                      title: Text(l.hideVoiceInput),
                      subtitle: Text(l.hideVoiceInputSubtitle),
                      value: state.hideVoiceInput,
                      onChanged: (value) => context
                          .read<SettingsCubit>()
                          .setHideVoiceInput(value),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    _TextScaleTile(
                      value: state.textScale,
                      onChanged: (value) =>
                          context.read<SettingsCubit>().setTextScale(value),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    SwitchListTile(
                      secondary: Icon(Icons.dns_outlined, color: cs.primary),
                      title: Text(l.showBridgeNameInSessionList),
                      subtitle: Text(l.showBridgeNameInSessionListSubtitle),
                      value: state.showBridgeNameInSessionList,
                      onChanged: (value) => context
                          .read<SettingsCubit>()
                          .setShowBridgeNameInSessionList(value),
                    ),
                    if (FeatureFlags.current.isEnabled(
                      AppFeature.terminalAppIntegration,
                    )) ...[
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                      ListTile(
                        leading: Icon(Icons.terminal, color: cs.primary),
                        title: Row(
                          children: [
                            Text(l.terminalApp),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: cs.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l.terminalAppExperimental,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          state.terminalApp.isConfigured
                              ? state.terminalApp.displayName
                              : l.terminalAppNone,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => showTerminalAppBottomSheet(
                          context: context,
                          current: state.terminalApp,
                          onChanged: (config) => context
                              .read<SettingsCubit>()
                              .setTerminalApp(config),
                          onClear: () =>
                              context.read<SettingsCubit>().clearTerminalApp(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              _SectionHeader(title: 'AGENTS'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Icon(Icons.smart_toy_outlined, color: cs.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SegmentedButton<EnabledAgentsMode>(
                              key: const ValueKey('enabled_agents_selector'),
                              segments: const [
                                ButtonSegment(
                                  value: EnabledAgentsMode.both,
                                  label: Text('Both'),
                                ),
                                ButtonSegment(
                                  value: EnabledAgentsMode.codex,
                                  label: Text('Codex'),
                                ),
                                ButtonSegment(
                                  value: EnabledAgentsMode.claude,
                                  label: Text('Claude'),
                                ),
                              ],
                              selected: {enabledAgentsMode},
                              showSelectedIcon: false,
                              onSelectionChanged: (selection) => context
                                  .read<SettingsCubit>()
                                  .setEnabledAgentsMode(selection.single),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (enabledAgentsMode == EnabledAgentsMode.both) ...[
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                      ListTile(
                        leading: Icon(Icons.tab, color: cs.primary),
                        title: Text(l.settingsNewSessionTabs),
                        subtitle: Text(
                          state.newSessionTabs
                              .map((t) => t.localizedLabel(l))
                              .join(', '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showNewSessionTabsBottomSheet(
                          context: context,
                          current: state.newSessionTabs,
                          onChanged: (tabs) => context
                              .read<SettingsCubit>()
                              .setNewSessionTabs(tabs),
                        ),
                      ),
                    ],
                    if (codexEnabled) ...[
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                      SwitchListTile(
                        secondary: Icon(
                          Icons.drive_file_rename_outline,
                          color: cs.primary,
                        ),
                        title: Text(l.autoRenameCodexSessions),
                        subtitle: Text(l.autoRenameCodexSessionsSubtitle),
                        value: state.autoRenameCodexSessions,
                        onChanged: (value) => context
                            .read<SettingsCubit>()
                            .setAutoRenameCodexSessions(value),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                      SwitchListTile(
                        key: const ValueKey(
                          'show_extended_codex_efforts_toggle',
                        ),
                        secondary: Icon(
                          Icons.linear_scale_rounded,
                          color: cs.primary,
                        ),
                        title: Text(l.showExtendedCodexEfforts),
                        subtitle: Text(l.showExtendedCodexEffortsSubtitle),
                        value: state.showExtendedCodexEfforts,
                        onChanged: (value) => context
                            .read<SettingsCubit>()
                            .setShowExtendedCodexEfforts(value),
                      ),
                    ],
                    if (claudeEnabled) ...[
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                      SwitchListTile(
                        secondary: Icon(
                          Icons.drive_file_rename_outline,
                          color: cs.primary,
                        ),
                        title: Text(l.autoRenameClaudeSessions),
                        subtitle: Text(l.autoRenameClaudeSessionsSubtitle),
                        value: state.autoRenameClaudeSessions,
                        onChanged: (value) => context
                            .read<SettingsCubit>()
                            .setAutoRenameClaudeSessions(value),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              if (state.activeMachineId != null) ...[
                _SectionHeader(title: l.sectionNotifications),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _PushNotificationTile(
                        state: state,
                        onChanged: (enabled) =>
                            context.read<SettingsCubit>().toggleFcm(enabled),
                      ),
                      if (state.fcmEnabled) ...[
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: cs.outlineVariant,
                        ),
                        _PushPrivacyTile(
                          value: state.fcmPrivacy,
                          syncInProgress: state.fcmSyncInProgress,
                          onChanged: (enabled) => context
                              .read<SettingsCubit>()
                              .toggleFcmPrivacy(enabled),
                        ),
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: cs.outlineVariant,
                        ),
                        _UpdateNotificationLanguageTile(
                          syncInProgress: state.fcmSyncInProgress,
                          onTap: () async {
                            final cubit = context.read<SettingsCubit>();
                            await cubit.syncPushLocale();
                            if (context.mounted) {
                              final status = cubit.state.fcmStatusKey;
                              final isSuccess =
                                  status == FcmStatusKey.enabled ||
                                  status == FcmStatusKey.enabledPending;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isSuccess
                                        ? l.notificationLanguageUpdated
                                        : l.fcmTokenFailed,
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // ── Editor ──
              _SectionHeader(title: l.sectionEditor),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.indentSize,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 1, label: Text('1')),
                              ButtonSegment(value: 2, label: Text('2')),
                              ButtonSegment(value: 3, label: Text('3')),
                              ButtonSegment(value: 4, label: Text('4')),
                            ],
                            selected: {state.indentSize},
                            onSelectionChanged: (selected) {
                              context.read<SettingsCubit>().setIndentSize(
                                selected.first,
                              );
                            },
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    ListTile(
                      key: const ValueKey('code_font_settings_tile'),
                      leading: const Icon(Icons.font_download_outlined),
                      title: Text(l.codeFontFamily),
                      subtitle: Text(
                        '${state.codeFontFamily.label} · ${state.codeFontSize.round()}pt',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CodeFontSettingsScreen(),
                        ),
                      ),
                    ),
                    if (isMacOSPlatform) ...[
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l.imagePasteShortcut,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<ImagePasteShortcut>(
                              key: const ValueKey(
                                'image_paste_shortcut_segment',
                              ),
                              segments: [
                                ButtonSegment(
                                  value: ImagePasteShortcut.ctrlV,
                                  label: Text(l.imagePasteShortcutCtrlV),
                                ),
                                ButtonSegment(
                                  value: ImagePasteShortcut.commandV,
                                  label: Text(l.imagePasteShortcutCommandV),
                                ),
                              ],
                              selected: {state.imagePasteShortcut},
                              onSelectionChanged: (selected) {
                                context
                                    .read<SettingsCubit>()
                                    .setImagePasteShortcut(selected.first);
                              },
                              showSelectedIcon: false,
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _imagePasteShortcutDescription(
                                l,
                                state.imagePasteShortcut,
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l.gitDiffInteractionMode,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<GitDiffInteractionMode>(
                            key: const ValueKey(
                              'git_diff_interaction_mode_segment',
                            ),
                            segments: [
                              ButtonSegment(
                                value: GitDiffInteractionMode.quickActions,
                                label: Text(l.gitDiffQuickActions),
                              ),
                              ButtonSegment(
                                value: GitDiffInteractionMode.scrollFirst,
                                label: Text(l.gitDiffScrollFirst),
                              ),
                            ],
                            selected: {state.gitDiffInteractionMode},
                            onSelectionChanged: (selected) {
                              context
                                  .read<SettingsCubit>()
                                  .setGitDiffInteractionMode(selected.first);
                            },
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _gitDiffInteractionModeDescription(
                              l,
                              state.gitDiffInteractionMode,
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    SwitchListTile(
                      key: const ValueKey(
                        'git_diff_focus_auto_landscape_toggle',
                      ),
                      title: Text(l.gitDiffFocusAutoLandscape),
                      subtitle: Text(l.gitDiffFocusAutoLandscapeDescription),
                      value: state.gitDiffFocusAutoLandscape,
                      onChanged: context
                          .read<SettingsCubit>()
                          .setGitDiffFocusAutoLandscape,
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    SwitchListTile(
                      key: const ValueKey('remote_git_status_badge_toggle'),
                      title: Text(l.remoteGitStatusBadge),
                      subtitle: Text(l.remoteGitStatusBadgeDescription),
                      value: state.showRemoteGitStatusBadge,
                      onChanged: context
                          .read<SettingsCubit>()
                          .setShowRemoteGitStatusBadge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              if (isConnected) ...[
                // ── Usage ──
                UsageSection(bridgeService: bridge),
                const SizedBox(height: 8),

                // ── Prompt History 2.0 ──
                _PromptHistorySectionSlot(bridgeService: bridge),
                const SizedBox(height: 8),
              ],

              ValueListenableBuilder<SupportCatalogState>(
                valueListenable: revenueCat.catalogState,
                builder: (context, supportState, _) {
                  if (!supportState.isAvailable &&
                      supportState.errorMessage == null) {
                    return const SizedBox.shrink();
                  }

                  _maybeFocusSupportSection();

                  return KeyedSubtree(
                    key: _supportSectionKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionHeader(title: l.sectionSupport),
                        SupportSectionCard(
                          highlighted: _highlightSupportSection,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),

              if (isConnected) ...[
                // ── Spread ──
                _SectionHeader(title: l.sectionSpread),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const _SpreadAppealMessage(),
                      // Rate on Store (mobile only)
                      if (isMobilePlatform) ...[
                        ListTile(
                          leading: Icon(
                            Icons.rate_review_outlined,
                            color: cs.primary,
                          ),
                          title: Text(
                            isIOSPlatform
                                ? l.rateOnStore
                                : l.rateOnStoreAndroid,
                          ),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => launchUrl(
                            Uri.parse(
                              isIOSPlatform
                                  ? AppConstants.appStoreUrl
                                  : AppConstants.playStoreUrl,
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: cs.outlineVariant,
                        ),
                      ],
                      // Share on SNS
                      ListTile(
                        leading: Icon(Icons.share, color: cs.primary),
                        title: Text(l.shareApp),
                        subtitle: Text(l.shareAppSubtitle),
                        onTap: () => SharePlus.instance.share(
                          ShareParams(text: l.shareText(AppConstants.shareUrl)),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                      // Star on GitHub
                      ListTile(
                        leading: Icon(Icons.star_border, color: cs.primary),
                        title: Text(l.starOnGithub),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => launchUrl(
                          Uri.parse(AppConstants.githubUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // ── About ──
              _SectionHeader(title: l.sectionAbout),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Version
                    const _VersionTile(),
                    const _AppUpdateTile(),
                    if (_isIOSAppOnMac) ...[
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                      const _MacOSNativeAppTile(),
                    ],
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // GitHub Repository
                    ListTile(
                      leading: Icon(Icons.code, color: cs.onSurfaceVariant),
                      title: Text(l.githubRepository),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => launchUrl(
                        Uri.parse(AppConstants.githubUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // Changelog
                    ListTile(
                      leading: Icon(Icons.history, color: cs.onSurfaceVariant),
                      title: Text(l.changelog),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.router.push(const ChangelogRoute()),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // Setup Guide
                    ListTile(
                      leading: Icon(
                        Icons.lightbulb_outline,
                        color: cs.onSurfaceVariant,
                      ),
                      title: Text(l.setupGuide),
                      subtitle: Text(l.setupGuideSubtitle),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.router.push(SetupGuideRoute()),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // Licenses
                    ListTile(
                      leading: Icon(
                        Icons.article_outlined,
                        color: cs.onSurfaceVariant,
                      ),
                      title: Text(l.openSourceLicenses),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.router.push(const LicensesRoute()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Footer ──
              Center(
                child: Column(
                  children: [
                    Text(
                      'ccpocket',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\u00a9 2026 K9i',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  static String _getThemeLabel(BuildContext context, ThemeMode mode) {
    final l = AppLocalizations.of(context);
    switch (mode) {
      case ThemeMode.system:
        return l.themeSystem;
      case ThemeMode.light:
        return l.themeLight;
      case ThemeMode.dark:
        return l.themeDark;
    }
  }

  static String _getAppIconSubtitle(
    BuildContext context, {
    required AppIconVariant selectedIcon,
    required bool isSupporter,
    required String deviceName,
  }) {
    final l = AppLocalizations.of(context);
    if (!isSupporter) {
      return l.appIconSettingsSubtitle(deviceName);
    }
    return switch (selectedIcon) {
      AppIconVariant.defaultIcon => l.appIconOptionDefaultTitle,
      AppIconVariant.lightOutline => l.appIconOptionLightOutlineTitle,
      AppIconVariant.proCopperEmerald => l.appIconOptionCopperEmeraldTitle,
    };
  }

  static void _openSupporterPerk(BuildContext context) {
    context.pushRoute(const SupporterRoute());
  }

  MachineWithStatus? _activeMachineWithStatus(
    MachineManagerState machineState,
    String? activeMachineId,
  ) {
    if (activeMachineId == null) return null;
    for (final item in machineState.machines) {
      if (item.machine.id == activeMachineId) {
        return item;
      }
    }
    return null;
  }

  void _updateBridgeFromSettings(MachineWithStatus machine) async {
    final cubit = context.read<MachineManagerCubit>();
    final bridge = context.read<BridgeService>();
    final settingsCubit = context.read<SettingsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);

    String? password;
    if (machine.machine.sshAuthType == SshAuthType.password) {
      final savedPassword = await cubit.getSshPassword(machine.machine.id);
      password = savedPassword;
      if (password == null || password.isEmpty) {
        password = await _promptForPassword(machine.machine.displayName);
        if (password == null) return;
      }
    }

    if (!mounted) return;

    messenger.showSnackBar(SnackBar(content: Text(l.bridgeUpdateStarted)));

    final isActiveMachine =
        settingsCubit.state.activeMachineId == machine.machine.id;
    if (isActiveMachine && bridge.isConnected) {
      bridge.disconnect();
    }

    if (widget.embedded) {
      WorkspaceShellScreen.maybeOf(context)?.popCenterOverlay();
    } else {
      await context.router.maybePop();
    }

    final success = await cubit.updateBridge(
      machine.machine.id,
      password: password,
    );

    final message = success
        ? l.bridgeUpdateReconnectHint
        : cubit.state.error ?? l.failedToUpdateServer;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _promptForPassword(String machineName) async {
    final controller = TextEditingController();
    final l = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.sshPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.sshPasswordPrompt(machineName)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l.password,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.pop(ctx, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.update),
          ),
        ],
      ),
    );
  }
}

String _gitDiffInteractionModeDescription(
  AppLocalizations l,
  GitDiffInteractionMode mode,
) {
  return switch (mode) {
    GitDiffInteractionMode.quickActions => l.gitDiffQuickActionsDescription,
    GitDiffInteractionMode.scrollFirst => l.gitDiffScrollFirstDescription,
  };
}

String _imagePasteShortcutDescription(
  AppLocalizations l,
  ImagePasteShortcut shortcut,
) {
  return switch (shortcut) {
    ImagePasteShortcut.ctrlV => l.imagePasteShortcutCtrlVDescription,
    ImagePasteShortcut.commandV => l.imagePasteShortcutCommandVDescription,
  };
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _BridgeUpdateStatusTile extends StatelessWidget {
  final MachineWithStatus? machineWithStatus;
  final bool isUpdating;
  final String? latestBridgeVersion;
  final bool isCheckingLatestBridgeVersion;
  final String? latestBridgeVersionError;
  final VoidCallback? onRefreshLatestVersion;
  final VoidCallback? onUpdate;

  const _BridgeUpdateStatusTile({
    required this.machineWithStatus,
    required this.isUpdating,
    this.latestBridgeVersion,
    this.isCheckingLatestBridgeVersion = false,
    this.latestBridgeVersionError,
    this.onRefreshLatestVersion,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final expectedVersion = AppConstants.expectedBridgeVersion;
    final updateTargetVersion =
        latestBridgeVersion != null &&
            compareSemanticVersions(latestBridgeVersion!, expectedVersion) > 0
        ? latestBridgeVersion!
        : expectedVersion;
    final machine = machineWithStatus?.machine;
    final versionInfo = machineWithStatus?.versionInfo;
    final hasSshSetup = machine?.canStartRemotely ?? false;
    final isOnline = machineWithStatus?.status == MachineStatus.online;
    final latestCheckFailed =
        latestBridgeVersion == null && latestBridgeVersionError != null;
    final bridgeNeedsUpdate =
        isOnline &&
        versionInfo != null &&
        versionInfo.needsUpdate(updateTargetVersion);
    final needsUpdate = bridgeNeedsUpdate && hasSshSetup;
    final canShowSetupHelp = bridgeNeedsUpdate && !hasSshSetup;
    final isKnownUpToDate =
        versionInfo != null &&
        !bridgeNeedsUpdate &&
        !isCheckingLatestBridgeVersion &&
        !latestCheckFailed;

    final title = bridgeNeedsUpdate
        ? l.bridgeUpdateAvailable
        : latestCheckFailed
        ? l.bridgeLatestVersionUnavailable
        : isKnownUpToDate
        ? l.bridgeIsUpToDate
        : l.updateBridge;
    final subtitle = canShowSetupHelp
        ? l.bridgeUpdateRequiresSetup
        : isCheckingLatestBridgeVersion
        ? l.bridgeLatestVersionChecking
        : versionInfo == null
        ? l.bridgeVersionUnknown
        : latestBridgeVersion != null
        ? l.bridgeVersionCurrentLatest(versionInfo.version, updateTargetVersion)
        : l.bridgeVersionCurrentExpected(versionInfo.version, expectedVersion);
    final icon = bridgeNeedsUpdate
        ? Icons.system_update
        : latestCheckFailed
        ? Icons.warning_amber_outlined
        : isKnownUpToDate
        ? Icons.check_circle_outline
        : Icons.info_outline;
    final iconColor = bridgeNeedsUpdate
        ? cs.tertiary
        : latestCheckFailed
        ? cs.error
        : isKnownUpToDate
        ? cs.primary
        : cs.onSurfaceVariant;

    return ListTile(
      key: canShowSetupHelp
          ? const ValueKey('settings_bridge_update_setup_tile')
          : null,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: canShowSetupHelp
          ? () => _showBridgeUpdateSetupSheet(context)
          : null,
      trailing: isUpdating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isCheckingLatestBridgeVersion
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : needsUpdate
          ? FilledButton.tonalIcon(
              key: const ValueKey('settings_update_bridge_button'),
              onPressed: onUpdate,
              icon: const Icon(Icons.system_update, size: 18),
              label: Text(l.update),
            )
          : canShowSetupHelp
          ? Icon(Icons.chevron_right, color: cs.onSurfaceVariant)
          : latestCheckFailed
          ? IconButton(
              key: const ValueKey('settings_bridge_latest_retry_button'),
              onPressed: onRefreshLatestVersion,
              icon: const Icon(Icons.refresh),
              tooltip: l.bridgeLatestVersionRetry,
            )
          : null,
    );
  }

  void _showBridgeUpdateSetupSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.bridgeUpdateSetupTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.bridgeUpdateSetupDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _BridgeUpdateSetupStep(
                    index: 1,
                    text: l.bridgeUpdateSetupEnableSsh,
                  ),
                  const SizedBox(height: 12),
                  _BridgeUpdateSetupStep(
                    index: 2,
                    text: l.bridgeUpdateSetupRunCommand,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      l.bridgeUpdateSetupCommand,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BridgeUpdateSetupStep extends StatelessWidget {
  final int index;
  final String text;

  const _BridgeUpdateSetupStep({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _PushNotificationTile extends StatelessWidget {
  final SettingsState state;
  final ValueChanged<bool> onChanged;

  const _PushNotificationTile({required this.state, required this.onChanged});

  static String? _resolveFcmStatus(AppLocalizations l, FcmStatusKey? key) {
    if (key == null) return null;
    return switch (key) {
      FcmStatusKey.unavailable => l.pushNotificationsUnavailable,
      FcmStatusKey.bridgeNotInitialized => l.fcmBridgeNotInitialized,
      FcmStatusKey.tokenFailed => l.fcmTokenFailed,
      FcmStatusKey.enabled => l.fcmEnabled,
      FcmStatusKey.enabledPending => l.fcmEnabledPending,
      FcmStatusKey.disabled => l.fcmDisabled,
      FcmStatusKey.disabledPending => l.fcmDisabledPending,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final baseSubtitle = state.fcmAvailable
        ? l.pushNotificationsSubtitle
        : l.pushNotificationsUnavailable;
    final subtitle = _resolveFcmStatus(l, state.fcmStatusKey) ?? baseSubtitle;

    return SwitchListTile(
      value: state.fcmEnabled,
      onChanged: state.fcmSyncInProgress ? null : onChanged,
      title: Text(l.pushNotifications),
      subtitle: Text(subtitle),
      secondary: state.fcmSyncInProgress
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.notifications_active_outlined),
    );
  }
}

class _PushPrivacyTile extends StatelessWidget {
  final bool value;
  final bool syncInProgress;
  final ValueChanged<bool> onChanged;

  const _PushPrivacyTile({
    required this.value,
    required this.syncInProgress,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SwitchListTile(
      value: value,
      onChanged: syncInProgress ? null : onChanged,
      title: Text(l.pushPrivacyMode),
      subtitle: Text(l.pushPrivacyModeSubtitle),
      secondary: const Icon(Icons.visibility_off_outlined),
    );
  }
}

class _UpdateNotificationLanguageTile extends StatelessWidget {
  final bool syncInProgress;
  final VoidCallback onTap;

  const _UpdateNotificationLanguageTile({
    required this.syncInProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.translate_outlined),
      title: Text(l.updateNotificationLanguage),
      trailing: syncInProgress
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right, size: 20),
      onTap: syncInProgress ? null : onTap,
    );
  }
}

class _SpreadAppealMessage extends StatefulWidget {
  const _SpreadAppealMessage();

  @override
  State<_SpreadAppealMessage> createState() => _SpreadAppealMessageState();
}

class _SpreadAppealMessageState extends State<_SpreadAppealMessage> {
  Future<InAppReviewEligibility>? _eligibilityFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_eligibilityFuture != null) return;
    final reviewService = context.read<InAppReviewService?>();
    _eligibilityFuture = reviewService?.getSupportBannerEligibility();
  }

  @override
  Widget build(BuildContext context) {
    final supportBannerService = context.watch<SupportBannerService?>();
    if (supportBannerService?.shouldForceShowInDebug ?? false) {
      return const _SpreadAppealMessageContent();
    }

    final eligibilityFuture = _eligibilityFuture;
    if (eligibilityFuture == null) return const SizedBox.shrink();

    return FutureBuilder<InAppReviewEligibility>(
      future: eligibilityFuture,
      builder: (context, snapshot) {
        if (!(snapshot.data?.isEligible ?? false)) {
          return const SizedBox.shrink();
        }

        return const _SpreadAppealMessageContent();
      },
    );
  }
}

class _SpreadAppealMessageContent extends StatelessWidget {
  const _SpreadAppealMessageContent();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          key: const ValueKey('spread_appeal_message'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign_outlined, color: cs.primary, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  l.spreadAppealMessage,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
      ],
    );
  }
}

class _TextScaleTile extends StatelessWidget {
  const _TextScaleTile({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final percent = _formatPercent(value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.format_size, color: cs.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(l.textDensity)),
                        Text(
                          percent,
                          key: const ValueKey('text_scale_value_label'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.textDensityDescription,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Slider(
            key: const ValueKey('text_scale_slider'),
            value: value,
            min: SettingsCubit.minTextScale,
            max: SettingsCubit.maxTextScale,
            divisions:
                ((SettingsCubit.maxTextScale - SettingsCubit.minTextScale) *
                        100)
                    .round(),
            label: percent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _formatPercent(double scale) => '${(scale * 100).round()}%';
}

class _VersionTile extends StatefulWidget {
  const _VersionTile();

  @override
  State<_VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends State<_VersionTile> {
  String? _versionText;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    final version = '${info.version}+${info.buildNumber}';

    String result = version;
    try {
      final updater = ShorebirdUpdater();
      final patch = await updater.readCurrentPatch();
      if (patch != null) {
        result = '$version (patch ${patch.number})';
      }
    } catch (_) {
      // Shorebird not available (e.g. debug builds)
    }

    if (mounted) {
      setState(() => _versionText = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final trackSuffix = settings.shorebirdTrack != 'stable'
            ? ' [${settings.shorebirdTrack}]'
            : '';
        return ListTile(
          leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
          title: Text(l.version),
          subtitle: Text(
            _versionText != null ? '$_versionText$trackSuffix' : l.loading,
          ),
        );
      },
    );
  }
}

/// Shows a download link when a newer macOS version is available.
///
/// Only visible on macOS desktop. Reads from [AppUpdateService.cachedUpdate].
class _AppUpdateTile extends StatelessWidget {
  const _AppUpdateTile();

  @override
  Widget build(BuildContext context) {
    final update = AppUpdateService.instance.cachedUpdate;
    if (update == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(Icons.upgrade, color: cs.primary),
      title: Text(
        l.appUpdateAvailable(update.latestVersion),
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
      ),
      trailing: TextButton(
        onPressed: () async {
          await AppUpdateService.instance.performUpdate(update);
        },
        child: Text(update.canInstallInApp ? l.update : l.download),
      ),
    );
  }
}

class _MacOSNativeAppTile extends StatelessWidget {
  const _MacOSNativeAppTile();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return ListTile(
      key: const ValueKey('macos_native_app_settings_tile'),
      leading: Icon(Icons.desktop_mac_outlined, color: cs.onSurfaceVariant),
      title: Text(l.macosNativeAppSettingsTitle),
      subtitle: Text(l.macosNativeAppSettingsSubtitle),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => launchUrl(
        Uri.parse(AppConstants.macOSReleasesUrl),
        mode: LaunchMode.externalApplication,
      ),
    );
  }
}

class _PromptHistorySectionSlot extends StatelessWidget {
  const _PromptHistorySectionSlot({required this.bridgeService});

  final BridgeService bridgeService;

  @override
  Widget build(BuildContext context) {
    final promptHistoryService = _readOptional<PromptHistoryService>(context);
    final machineManagerService = _readOptional<MachineManagerService>(context);

    if (promptHistoryService == null || machineManagerService == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        PromptHistorySection(
          bridgeService: bridgeService,
          promptHistoryService: promptHistoryService,
          machineManagerService: machineManagerService,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  T? _readOptional<T>(BuildContext context) {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
