import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_constants.dart';
import '../../constants/feature_flags.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_icon.dart';
import '../../models/git_diff_interaction_mode.dart';
import '../../models/image_paste_shortcut.dart';
import '../../models/input_delivery.dart';
import '../../models/machine.dart';
import '../../models/new_session_tab.dart';
import '../../models/skill_trigger_style.dart';
import '../../providers/machine_manager_cubit.dart';
import '../../router/app_router.dart';
import '../../services/bridge_service.dart';
import '../../services/platform_environment_service.dart';
import '../../services/revenuecat_service.dart';
import '../../utils/platform_helper.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../session_list/workspace_shell_screen.dart';
import 'code_font_settings_screen.dart';
import 'state/settings_cubit.dart';
import 'state/settings_state.dart';
import 'widgets/about_tiles.dart';
import 'widgets/app_icon_bottom_sheet.dart';
import 'widgets/bridge_update_status_tile.dart';
import 'widgets/notification_tiles.dart';
import 'widgets/settings_tiles.dart';
import 'widgets/spread_appeal_message.dart';
import 'widgets/text_scale_tile.dart';
import 'widgets/local_url_settings_tile.dart';
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
    this.focusUsage = false,
    this.embedded = false,
    this.onBack,
  });

  final bool focusConnection;
  final bool focusSupport;
  final bool focusUsage;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _scrollController = ScrollController();
  final _connectionSectionKey = GlobalKey();
  final _supportSectionKey = GlobalKey();
  final _usageSectionKey = GlobalKey();
  Timer? _connectionHighlightTimer;
  Timer? _supportHighlightTimer;
  Timer? _usageHighlightTimer;
  bool _didHandleConnectionFocus = false;
  bool _didHandleSupportFocus = false;
  bool _didHandleUsageFocus = false;
  bool _highlightConnectionSection = false;
  bool _highlightSupportSection = false;
  bool _highlightUsageSection = false;
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
      // The lazy list only estimates its extent, so one jump to the end may
      // stop short of the support section; repeat until it is built.
      for (
        var attempt = 0;
        attempt < 5 &&
            mounted &&
            _supportSectionKey.currentContext == null &&
            _scrollController.hasClients;
        attempt++
      ) {
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

  void _maybeFocusUsageSection() {
    if (!widget.focusUsage || _didHandleUsageFocus) return;
    _didHandleUsageFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final targetContext = _usageSectionKey.currentContext;
      if (targetContext == null || !targetContext.mounted) {
        _didHandleUsageFocus = false;
        return;
      }
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
      if (!mounted) return;

      setState(() => _highlightUsageSection = true);
      _usageHighlightTimer?.cancel();
      _usageHighlightTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() => _highlightUsageSection = false);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlatformEnvironment());
    // The support section may sit beyond the lazily built part of the list,
    // so start scrolling toward it instead of waiting for it to build.
    _maybeFocusSupportSection();
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
    _usageHighlightTimer?.cancel();
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
            scrollCacheExtent:
                widget.focusSupport ||
                    widget.focusConnection ||
                    widget.focusUsage
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
                SettingsSectionHeader(title: l.sectionConnectionAccounts),
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
                          if (bridge.lastUrl != null)
                            LocalUrlSettingsTile(bridgeUrl: bridge.lastUrl!),
                          BridgeUpdateStatusTile(
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
              SettingsSectionHeader(title: l.sectionGeneral),
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
                    SwitchListTile(
                      key: const ValueKey('lite_mode_toggle'),
                      secondary: Icon(Icons.bolt_outlined, color: cs.primary),
                      title: Text(l.liteMode),
                      subtitle: Text(l.liteModeDescription),
                      value: state.liteMode,
                      onChanged: context.read<SettingsCubit>().setLiteMode,
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
                    SwitchListTile(
                      key: const ValueKey('open_gallery_directly_toggle'),
                      secondary: Icon(
                        Icons.photo_library_outlined,
                        color: cs.primary,
                      ),
                      title: Text(l.openGalleryDirectly),
                      subtitle: Text(l.openGalleryDirectlySubtitle),
                      value: state.openGalleryDirectly,
                      onChanged: (value) => context
                          .read<SettingsCubit>()
                          .setOpenGalleryDirectly(value),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    TextScaleTile(
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

              SettingsSectionHeader(title: 'AGENTS'),
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
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    SwitchListTile(
                      key: const ValueKey('show_hidden_directories_toggle'),
                      secondary: Icon(
                        Icons.folder_open_outlined,
                        color: cs.primary,
                      ),
                      title: Text(l.showHiddenDirectories),
                      subtitle: Text(l.showHiddenDirectoriesSubtitle),
                      value: state.showHiddenDirectories,
                      onChanged: (value) => context
                          .read<SettingsCubit>()
                          .setShowHiddenDirectories(value),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    ListTile(
                      key: const ValueKey('default_input_delivery_tile'),
                      leading: Icon(
                        Icons.low_priority_rounded,
                        color: cs.primary,
                      ),
                      title: Text(l.defaultInputDelivery),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.defaultInputDeliverySubtitle),
                            const SizedBox(height: 8),
                            SegmentedButton<InputDelivery>(
                              key: const ValueKey(
                                'default_input_delivery_selector',
                              ),
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(
                                  value: InputDelivery.queue,
                                  icon: const Icon(Icons.schedule, size: 18),
                                  label: Text(l.inputDeliveryQueue),
                                ),
                                ButtonSegment(
                                  value: InputDelivery.steer,
                                  icon: const Icon(
                                    Icons.subdirectory_arrow_left,
                                    size: 18,
                                  ),
                                  label: Text(l.inputDeliverySteer),
                                ),
                              ],
                              selected: {state.defaultInputDelivery},
                              onSelectionChanged: (selection) => context
                                  .read<SettingsCubit>()
                                  .setDefaultInputDelivery(selection.first),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    ListTile(
                      key: const ValueKey('skill_trigger_style_tile'),
                      leading: Icon(Icons.extension, color: cs.primary),
                      title: Text(l.skillTriggerStyle),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.skillTriggerStyleSubtitle),
                            const SizedBox(height: 8),
                            SegmentedButton<SkillTriggerStyle>(
                              key: const ValueKey(
                                'skill_trigger_style_selector',
                              ),
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(
                                  value: SkillTriggerStyle.both,
                                  label: Text(l.skillTriggerStyleBoth),
                                ),
                                ButtonSegment(
                                  value: SkillTriggerStyle.slash,
                                  label: Text(l.skillTriggerStyleSlash),
                                ),
                                ButtonSegment(
                                  value: SkillTriggerStyle.dollar,
                                  label: Text(l.skillTriggerStyleDollar),
                                ),
                              ],
                              selected: {state.skillTriggerStyle},
                              onSelectionChanged: (selection) => context
                                  .read<SettingsCubit>()
                                  .setSkillTriggerStyle(selection.first),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                SettingsSectionHeader(title: l.sectionNotifications),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      PushNotificationTile(
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
                        PushPrivacyTile(
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
                        UpdateNotificationLanguageTile(
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
              SettingsSectionHeader(title: l.sectionEditor),
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

              if (bridge.isConnected) ...[
                // ── Usage ──
                Builder(
                  builder: (context) {
                    _maybeFocusUsageSection();
                    return KeyedSubtree(
                      key: _usageSectionKey,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: _highlightUsageSection
                              ? cs.tertiary.withValues(alpha: 0.06)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _highlightUsageSection
                                ? cs.tertiary.withValues(alpha: 0.7)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: UsageSection(bridgeService: bridge),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],

              if (isConnected) ...[
                // ── Prompt History 2.0 ──
                PromptHistorySectionSlot(bridgeService: bridge),
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
                        SettingsSectionHeader(title: l.sectionSupport),
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
                SettingsSectionHeader(title: l.sectionSpread),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SpreadAppealMessage(),
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
              SettingsSectionHeader(title: l.sectionAbout),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Version
                    const VersionTile(),
                    const AppUpdateTile(),
                    if (_isIOSAppOnMac) ...[
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                      const MacOSNativeAppTile(),
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
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
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
