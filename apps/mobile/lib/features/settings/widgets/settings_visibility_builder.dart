import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../constants/feature_flags.dart';
import '../../../models/new_session_tab.dart';
import '../../../services/bridge_service.dart';
import '../../../services/machine_manager_service.dart';
import '../../../services/prompt_history_service.dart';
import '../../../services/revenuecat_service.dart';
import '../../../utils/platform_helper.dart';
import '../models/settings_catalog.dart';
import '../state/settings_cubit.dart';
import '../state/settings_state.dart';

/// Platform facts that are resolved asynchronously by the settings screen.
@immutable
class SettingsEnvironment {
  const SettingsEnvironment({
    this.isIOSAppOnMac = false,
    this.appIconDeviceName = 'iPhone',
  });

  final bool isIOSAppOnMac;
  final String appIconDeviceName;

  @override
  bool operator ==(Object other) =>
      other is SettingsEnvironment &&
      other.isIOSAppOnMac == isIOSAppOnMac &&
      other.appIconDeviceName == appIconDeviceName;

  @override
  int get hashCode => Object.hash(isIOSAppOnMac, appIconDeviceName);
}

typedef SettingsVisibilityWidgetBuilder = Widget Function(
  BuildContext context,
  SettingsState state,
  SettingsVisibility visibility,
  SettingsEnvironment environment,
);

/// Rebuilds whenever any input of [SettingsVisibility] changes.
class SettingsVisibilityBuilder extends StatelessWidget {
  const SettingsVisibilityBuilder({
    super.key,
    required this.environment,
    required this.builder,
  });

  final ValueListenable<SettingsEnvironment> environment;
  final SettingsVisibilityWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final revenueCat = context.read<RevenueCatService>();
    return ValueListenableBuilder<SettingsEnvironment>(
      valueListenable: environment,
      builder: (context, env, _) {
        return ValueListenableBuilder<SupportCatalogState>(
          valueListenable: revenueCat.catalogState,
          builder: (context, catalog, _) {
            return BlocBuilder<SettingsCubit, SettingsState>(
              builder: (context, state) {
                final visibility = resolveSettingsVisibility(
                  context,
                  state: state,
                  environment: env,
                  catalog: catalog,
                );
                return builder(context, state, visibility, env);
              },
            );
          },
        );
      },
    );
  }
}

SettingsVisibility resolveSettingsVisibility(
  BuildContext context, {
  required SettingsState state,
  required SettingsEnvironment environment,
  required SupportCatalogState catalog,
}) {
  final bridge = context.read<BridgeService>();
  return SettingsVisibility(
    hasActiveMachine: state.activeMachineId != null,
    bridgeConnected: bridge.isConnected,
    hasBridgeUrl: bridge.lastUrl != null,
    promptHistoryAvailable:
        _hasProvider<PromptHistoryService>(context) &&
        _hasProvider<MachineManagerService>(context),
    appIconSupported: state.appIconSupported,
    hideVoiceInput: state.hideVoiceInput,
    terminalAppEnabled: FeatureFlags.current.isEnabled(
      AppFeature.terminalAppIntegration,
    ),
    isMacOS: isMacOSPlatform,
    isMobile: isMobilePlatform,
    bothAgents:
        enabledAgentsModeFromTabs(state.newSessionTabs) ==
        EnabledAgentsMode.both,
    codexEnabled: isNewSessionTabEnabled(
      state.newSessionTabs,
      NewSessionTab.codex,
    ),
    claudeEnabled: isNewSessionTabEnabled(
      state.newSessionTabs,
      NewSessionTab.claude,
    ),
    fcmEnabled: state.fcmEnabled,
    supportAvailable: catalog.isAvailable || catalog.errorMessage != null,
    isIOSAppOnMac: environment.isIOSAppOnMac,
  );
}

bool _hasProvider<T>(BuildContext context) {
  try {
    context.read<T>();
    return true;
  } on ProviderNotFoundException {
    return false;
  }
}
