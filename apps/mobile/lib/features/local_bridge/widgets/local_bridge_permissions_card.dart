import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/settings_tiles.dart';
import '../data/local_bridge_launcher.dart';
import '../state/local_bridge_cubit.dart';
import '../state/local_bridge_state.dart';

enum _Importance { required, recommended, optional }

/// The macOS permissions of the Bridge the app runs: what each is for,
/// whether it is granted, and a button to the System Settings page.
///
/// macOS lists the Bridge under the app's own name, because the helper that
/// runs it lives inside the app. See docs/design/local-bridge-management.md.
class LocalBridgePermissionsCard extends StatefulWidget {
  const LocalBridgePermissionsCard({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  State<LocalBridgePermissionsCard> createState() =>
      _LocalBridgePermissionsCardState();
}

class _LocalBridgePermissionsCardState
    extends State<LocalBridgePermissionsCard> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back from System Settings: show what changed there.
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<LocalBridgeCubit>().refreshPermissions(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<LocalBridgeCubit, LocalBridgeState>(
      builder: (context, state) {
        final cubit = context.read<LocalBridgeCubit>();
        final permissions = state.launcherPermissions;
        final loginItem = switch (state.launcherRegistration) {
          LauncherRegistration.enabled => true,
          LauncherRegistration.requiresApproval => false,
          _ => null,
        };
        return SettingsGroup(
          title: widget.showTitle ? l.localBridgePermissionsTitle : null,
          footer: l.localBridgePermissionsFooter,
          cardKey: const ValueKey('local_bridge_permissions_card'),
          children: [
            _PermissionTile(
              permission: BridgePermission.loginItem,
              icon: Icons.play_circle_outline_rounded,
              title: l.localBridgePermissionLoginItem,
              description: l.localBridgePermissionLoginItemDesc,
              importance: _Importance.required,
              granted: loginItem,
              onOpen: cubit.openPermissionSettings,
            ),
            _PermissionTile(
              permission: BridgePermission.fullDiskAccess,
              icon: Icons.folder_copy_outlined,
              title: l.localBridgePermissionFullDisk,
              description: l.localBridgePermissionFullDiskDesc,
              importance: _Importance.recommended,
              granted: permissions?.fullDiskAccess,
              onOpen: cubit.openPermissionSettings,
            ),
            _PermissionTile(
              permission: BridgePermission.screenCapture,
              icon: Icons.screenshot_monitor_outlined,
              title: l.localBridgePermissionScreenCapture,
              description: l.localBridgePermissionScreenCaptureDesc,
              importance: _Importance.optional,
              granted: permissions?.screenCapture,
              onOpen: cubit.openPermissionSettings,
            ),
            _PermissionTile(
              permission: BridgePermission.localNetwork,
              icon: Icons.lan_outlined,
              title: l.localBridgePermissionLocalNetwork,
              description: l.localBridgePermissionLocalNetworkDesc,
              importance: _Importance.optional,
              // macOS offers no way to ask.
              granted: null,
              onOpen: cubit.openPermissionSettings,
            ),
          ],
        );
      },
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.permission,
    required this.icon,
    required this.title,
    required this.description,
    required this.importance,
    required this.granted,
    required this.onOpen,
  });

  final BridgePermission permission;
  final IconData icon;
  final String title;
  final String description;
  final _Importance importance;

  /// Null when macOS does not tell.
  final bool? granted;
  final ValueChanged<BridgePermission> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    // Only a missing permission that matters is shown as a problem.
    final problem = granted == false && importance != _Importance.optional;
    final (statusIcon, statusColor, statusText) = switch (granted) {
      true => (
        Icons.check_circle_rounded,
        cs.primary,
        l.localBridgePermissionGranted,
      ),
      false => (
        problem ? Icons.error_rounded : Icons.remove_circle_outline_rounded,
        problem ? cs.error : cs.onSurfaceVariant,
        l.localBridgePermissionMissing,
      ),
      null => (
        Icons.help_outline_rounded,
        cs.onSurfaceVariant,
        l.localBridgePermissionUnknown,
      ),
    };
    final importanceLabel = switch (importance) {
      _Importance.required => l.localBridgePermissionRequired,
      _Importance.recommended => l.localBridgePermissionRecommended,
      _Importance.optional => l.localBridgePermissionOptional,
    };
    return ListTile(
      key: ValueKey('local_bridge_permission:${permission.name}'),
      leading: SettingsLeadingIcon(icon),
      title: Row(
        children: [
          Flexible(child: Text(title)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(importanceLabel, style: muted),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, style: muted),
          const SizedBox(height: 4),
          Row(
            key: ValueKey(
              'local_bridge_permission_status:${permission.name}:$granted',
            ),
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  statusText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: granted == true
          ? TextButton(
              key: ValueKey('local_bridge_permission_open:${permission.name}'),
              onPressed: () => onOpen(permission),
              child: Text(l.localBridgePermissionOpenSettings),
            )
          : OutlinedButton(
              key: ValueKey('local_bridge_permission_open:${permission.name}'),
              onPressed: () => onOpen(permission),
              child: Text(l.localBridgePermissionOpenSettings),
            ),
    );
  }
}

/// Shown right after the Bridge was first started from the app: the moment
/// to send the user to System Settings.
Future<void> showLocalBridgePermissionsDialog(BuildContext context) {
  final cubit = context.read<LocalBridgeCubit>();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l = AppLocalizations.of(dialogContext);
      return BlocProvider.value(
        value: cubit,
        child: AlertDialog(
          key: const ValueKey('local_bridge_permissions_dialog'),
          title: Text(l.localBridgePermissionsDialogTitle),
          contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(l.localBridgePermissionsDialogBody),
                  ),
                  const LocalBridgePermissionsCard(showTitle: false),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              key: const ValueKey('local_bridge_permissions_dialog_done'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l.done),
            ),
          ],
        ),
      );
    },
  );
}
