import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../settings/widgets/settings_tiles.dart';
import 'data/local_bridge_client.dart';
import 'state/local_bridge_cubit.dart';
import 'state/local_bridge_state.dart';
import 'widgets/local_bridge_logs_screen.dart';
import 'widgets/local_bridge_pairing_card.dart';
import 'widgets/local_bridge_setting_editors.dart';
import 'widgets/local_bridge_settings_section.dart';
import 'widgets/local_bridge_status_card.dart';
import 'widgets/local_bridge_tools_card.dart';
import 'widgets/local_bridge_unavailable_view.dart';

/// Manages the Bridge running on this machine: status, pairing QR, required
/// tools, settings and logs. See docs/design/local-bridge-management.md.
class LocalBridgeScreen extends StatelessWidget {
  const LocalBridgeScreen({super.key, this.createCubit});

  /// Overrides the cubit (tests).
  final LocalBridgeCubit Function()? createCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createCubit?.call() ?? LocalBridgeCubit())..load(),
      child: const LocalBridgeView(),
    );
  }
}

class LocalBridgeView extends StatelessWidget {
  const LocalBridgeView({super.key});

  Future<void> _changePort(BuildContext context) async {
    final cubit = context.read<LocalBridgeCubit>();
    final l = AppLocalizations.of(context);
    final result = await showDialog<SettingEdit>(
      context: context,
      builder: (_) => TextSettingDialog(
        title: l.localBridgeChangePort,
        initialValue: '${cubit.state.port}',
        numeric: true,
        canReset: false,
      ),
    );
    final port = result?.value;
    if (port is int && port > 0 && port <= 65535) await cubit.setPort(port);
  }

  void _showFailure(BuildContext context, LocalBridgeFailure failure) {
    final l = AppLocalizations.of(context);
    final message = switch (failure) {
      LocalBridgeFailure.notSupervised => l.localBridgeNotSupervised,
      LocalBridgeFailure.invalidSettings => l.localBridgeInvalidSettings,
      LocalBridgeFailure.notRunning => l.localBridgeRestartFailed,
      _ => l.localBridgeActionFailed,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    context.read<LocalBridgeCubit>().clearActionFailure();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocConsumer<LocalBridgeCubit, LocalBridgeState>(
      listenWhen: (previous, current) =>
          current.actionFailure != null &&
          previous.actionFailure != current.actionFailure,
      listener: (context, state) => _showFailure(context, state.actionFailure!),
      builder: (context, state) {
        final cubit = context.read<LocalBridgeCubit>();
        return Scaffold(
          appBar: AppBar(
            title: Text(l.localBridgeTitle),
            actions: [
              IconButton(
                key: const ValueKey('local_bridge_refresh_button'),
                tooltip: l.refresh,
                onPressed: state.busy == LocalBridgeBusy.none
                    ? () => cubit.load(showLoading: false)
                    : null,
                icon: const Icon(Icons.refresh_rounded),
              ),
              PopupMenuButton<void>(
                key: const ValueKey('local_bridge_menu_button'),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    key: const ValueKey('local_bridge_change_port_item'),
                    onTap: () => _changePort(context),
                    child: Text(l.localBridgeChangePort),
                  ),
                ],
              ),
            ],
          ),
          body: switch (state.phase) {
            LocalBridgePhase.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            LocalBridgePhase.ready => LocalBridgeReadyBody(state: state),
            _ => LocalBridgeUnavailableView(
              phase: state.phase,
              port: state.port,
              detail: state.errorDetail,
              onRetry: cubit.load,
            ),
          },
          bottomNavigationBar: state.hasEdits
              ? LocalBridgeUnsavedBar(
                  saving: state.busy == LocalBridgeBusy.saving,
                  onSave: cubit.save,
                  onDiscard: cubit.discardEdits,
                )
              : null,
        );
      },
    );
  }
}

class LocalBridgeReadyBody extends StatelessWidget {
  const LocalBridgeReadyBody({super.key, required this.state});

  final LocalBridgeState state;

  Future<void> _confirmRestart(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<LocalBridgeCubit>();
    final sessions = state.status?.sessions ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.localBridgeRestartConfirmTitle),
        content: Text(
          [
            if (sessions > 0) l.localBridgeRestartConfirmSessions(sessions),
            l.localBridgeRestartConfirmBody,
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('local_bridge_restart_confirm_button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.restart),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.restart();
  }

  Future<void> _confirmRotateKey(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<LocalBridgeCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.localBridgeRotateKey),
        content: Text(l.localBridgeRotateKeyConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('local_bridge_rotate_key_confirm_button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.localBridgeRotateKey),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (await cubit.rotateApiKey()) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.localBridgeRotateKeyDone)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<LocalBridgeCubit>();
    final status = state.status;
    final pairing = state.pairing;
    if (status == null) return const SizedBox.shrink();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const ValueKey('local_bridge_list'),
          padding: const EdgeInsets.only(top: 12, bottom: 32),
          children: [
            LocalBridgeStatusCard(
              status: status,
              restartRequired: state.restartRequired,
              busy: state.busy,
              onRestart: () => _confirmRestart(context),
            ),
            if (pairing != null) ...[
              SettingsSectionHeader(title: l.localBridgePairingTitle),
              LocalBridgePairingCard(
                pairing: pairing,
                canRotateApiKey: status.canRotateApiKey,
                onRotateApiKey: state.busy == LocalBridgeBusy.none
                    ? () => _confirmRotateKey(context)
                    : null,
              ),
            ],
            SettingsSectionHeader(title: l.localBridgeToolsTitle),
            LocalBridgeToolsCard(
              tools: state.tools,
              loading: state.toolsLoading,
              unsupported: state.toolsUnsupported,
              onRecheck: cubit.refreshTools,
            ),
            LocalBridgeSettingsSection(state: state, onEdit: cubit.edit),
            SettingsGroup(
              children: [
                SettingsNavTile(
                  key: const ValueKey('local_bridge_logs_tile'),
                  icon: Icons.article_outlined,
                  title: Text(l.localBridgeLogsTitle),
                  subtitle: l.localBridgeLogsSubtitle,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          LocalBridgeLogsScreen(loadLogs: cubit.loadLogs),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Save / discard bar shown while settings have unsaved changes.
class LocalBridgeUnsavedBar extends StatelessWidget {
  const LocalBridgeUnsavedBar({
    super.key,
    required this.saving,
    required this.onSave,
    required this.onDiscard,
  });

  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('local_bridge_unsaved_bar'),
      color: cs.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
          child: Row(
            children: [
              Expanded(child: Text(l.localBridgeUnsavedChanges)),
              TextButton(
                key: const ValueKey('local_bridge_discard_button'),
                onPressed: saving ? null : onDiscard,
                child: Text(l.localBridgeDiscard),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('local_bridge_save_button'),
                onPressed: saving ? null : onSave,
                child: Text(l.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
