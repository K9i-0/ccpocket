import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../../models/machine.dart';
import '../../providers/machine_manager_cubit.dart';
import '../../services/bridge_service.dart';
import '../../services/platform_environment_service.dart';
import '../../services/revenuecat_service.dart';
import '../../utils/platform_helper.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../session_list/workspace_shell_screen.dart';
import 'models/settings_catalog.dart';
import 'state/settings_cubit.dart';
import 'widgets/settings_category_body.dart';
import 'widgets/settings_home.dart';
import 'widgets/settings_visibility_builder.dart';

/// Width at which settings switches to a category list + detail layout.
const double kSettingsTwoPaneBreakpoint = 840;

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

  /// Opens the connection category and highlights the Bridge update row.
  final bool focusConnection;

  /// Opens the support category and highlights the supporter entry.
  final bool focusSupport;

  /// Opens the usage category.
  final bool focusUsage;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _environment = ValueNotifier(
    SettingsEnvironment(
      appIconDeviceName: isAndroidPlatform ? 'Android' : 'iPhone',
    ),
  );

  /// Selected category in the two-pane layout.
  SettingsCategory? _selectedCategory;
  SettingsHighlightRequest? _highlight;
  int _highlightCounter = 0;

  /// Category page pushed in the single-pane layout.
  Route<void>? _categoryRoute;
  bool _isTwoPane = false;
  bool _didHandleInitialFocus = false;

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

  @override
  void dispose() {
    _environment.dispose();
    super.dispose();
  }

  Future<void> _loadPlatformEnvironment() async {
    final environment = PlatformEnvironmentService.instance;
    final isIOSAppOnMac = await environment.isIOSAppOnMac();
    final appIconDeviceName = await _resolveAppIconDeviceName(environment);
    if (!mounted) return;
    _environment.value = SettingsEnvironment(
      isIOSAppOnMac: isIOSAppOnMac,
      appIconDeviceName: appIconDeviceName,
    );
  }

  Future<String> _resolveAppIconDeviceName(
    PlatformEnvironmentService environment,
  ) async {
    if (isAndroidPlatform) return 'Android';
    if (!isIOSPlatform) return 'iPhone';

    final idiom = await environment.iosUserInterfaceIdiom();
    return idiom == 'pad' ? 'iPad' : 'iPhone';
  }

  SettingsVisibility _currentVisibility() {
    return resolveSettingsVisibility(
      context,
      state: context.read<SettingsCubit>().state,
      environment: _environment.value,
      catalog: context.read<RevenueCatService>().catalogState.value,
    );
  }

  /// Deep links from the home screen open a category directly.
  void _applyInitialFocus() {
    if (!mounted) return;
    final visibility = _currentVisibility();
    final (category, entryId) = widget.focusConnection
        ? (SettingsCategory.connection, SettingsEntryIds.bridgeUpdate)
        : widget.focusUsage
        ? (SettingsCategory.usage, SettingsEntryIds.usage)
        : widget.focusSupport
        ? (SettingsCategory.support, SettingsEntryIds.supporter)
        : (null, null);
    if (category == null) return;
    // Support can appear once the store catalog loads, so it is always opened.
    final canOpen =
        category == SettingsCategory.support ||
        visibleSettingsCategories(visibility).contains(category);
    if (!canOpen) return;
    _openCategory(category, entryId: entryId);
  }

  void _openCategory(SettingsCategory category, {String? entryId}) {
    final highlight = entryId == null
        ? null
        : SettingsHighlightRequest(entryId, ++_highlightCounter);
    if (_isTwoPane) {
      setState(() {
        _selectedCategory = category;
        _highlight = highlight;
      });
      return;
    }
    final route = MaterialPageRoute<void>(
      builder: (_) => SettingsCategoryPage(
        category: category,
        environment: _environment,
        onUpdateBridge: _updateBridgeFromSettings,
        highlight: highlight,
      ),
    );
    _categoryRoute = route;
    unawaited(
      Navigator.of(context).push(route).whenComplete(() {
        if (identical(_categoryRoute, route)) _categoryRoute = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = WorkspaceShellScreen.maybeOf(context);
    final chrome = resolveWorkspacePaneChrome(
      platform: Theme.of(context).platform,
      isAdaptiveWorkspace: shell != null && !shell.isSinglePane,
      isLeftPaneVisible: shell?.isLeftPaneVisible ?? false,
      slot: WorkspacePaneSlot.center,
    );
    final l = AppLocalizations.of(context);
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          _isTwoPane = constraints.maxWidth >= kSettingsTwoPaneBreakpoint;
          if (!_didHandleInitialFocus) {
            _didHandleInitialFocus = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _applyInitialFocus(),
            );
          }
          if (!_isTwoPane) {
            return SettingsHome(
              environment: _environment,
              onOpenCategory: _openCategory,
              onUpdateBridge: _updateBridgeFromSettings,
            );
          }
          return SettingsVisibilityBuilder(
            environment: _environment,
            builder: (context, state, visibility, env) {
              final categories = visibleSettingsCategories(visibility);
              final selected = categories.contains(_selectedCategory)
                  ? _selectedCategory!
                  : categories.first;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 360,
                    child: SettingsHome(
                      environment: _environment,
                      selectedCategory: selected,
                      onOpenCategory: _openCategory,
                      onUpdateBridge: _updateBridgeFromSettings,
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: SettingsCategoryBody(
                          key: ValueKey('settings_detail_${selected.name}'),
                          category: selected,
                          environment: _environment,
                          onUpdateBridge: _updateBridgeFromSettings,
                          highlight: _highlight,
                          showHeader: true,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
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

    final categoryRoute = _categoryRoute;
    if (categoryRoute != null && categoryRoute.isActive) {
      Navigator.of(context).removeRoute(categoryRoute);
      _categoryRoute = null;
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
