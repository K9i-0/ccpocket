import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/app_update_service.dart';
import 'settings_tiles.dart';

/// Shows a dialog that checks for app updates and presents the result without
/// using a bottom SnackBar.
Future<void> showCheckForUpdatesDialog(
  BuildContext context, {
  Future<AppUpdateInfo?> Function()? checkForUpdates,
  Future<void> Function(AppUpdateInfo update)? performUpdate,
  VoidCallback? onUpdateFound,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CheckForUpdatesDialog(
      checkForUpdates:
          checkForUpdates ??
          () => AppUpdateService.instance.checkForUpdate(force: true),
      performUpdate:
          performUpdate ??
          (update) => AppUpdateService.instance.performUpdate(update),
      onUpdateFound: onUpdateFound,
    ),
  );
}

enum _UpdateCheckPhase { checking, upToDate, available, failed }

class _CheckForUpdatesDialog extends StatefulWidget {
  const _CheckForUpdatesDialog({
    required this.checkForUpdates,
    required this.performUpdate,
    this.onUpdateFound,
  });

  final Future<AppUpdateInfo?> Function() checkForUpdates;
  final Future<void> Function(AppUpdateInfo update) performUpdate;
  final VoidCallback? onUpdateFound;

  @override
  State<_CheckForUpdatesDialog> createState() => _CheckForUpdatesDialogState();
}

class _CheckForUpdatesDialogState extends State<_CheckForUpdatesDialog> {
  _UpdateCheckPhase _phase = _UpdateCheckPhase.checking;
  AppUpdateInfo? _update;
  String? _currentVersion;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrentVersion());
    unawaited(_runCheck());
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final version = info.buildNumber.isNotEmpty
          ? 'v${info.version}+${info.buildNumber}'
          : 'v${info.version}';
      setState(() => _currentVersion = version);
    } catch (_) {
      // PackageInfo may be unavailable in some test environments.
    }
  }

  Future<void> _runCheck() async {
    final generation = ++_generation;
    setState(() {
      _phase = _UpdateCheckPhase.checking;
      _update = null;
    });
    try {
      final update = await widget.checkForUpdates();
      if (!mounted || generation != _generation) return;
      if (update != null) {
        widget.onUpdateFound?.call();
        setState(() {
          _phase = _UpdateCheckPhase.available;
          _update = update;
        });
      } else {
        setState(() => _phase = _UpdateCheckPhase.upToDate);
      }
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _phase = _UpdateCheckPhase.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ml = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final success = settingsSuccessColor(theme.brightness);

    return AlertDialog(
      key: const ValueKey('check_for_updates_dialog'),
      icon: switch (_phase) {
        _UpdateCheckPhase.checking => const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        _UpdateCheckPhase.upToDate => Icon(
          Icons.check_circle_rounded,
          color: success,
          size: 32,
        ),
        _UpdateCheckPhase.available => Icon(
          Icons.system_update_alt_rounded,
          color: cs.primary,
          size: 32,
        ),
        _UpdateCheckPhase.failed => Icon(
          Icons.error_outline_rounded,
          color: cs.error,
          size: 32,
        ),
      },
      title: Text(switch (_phase) {
        _UpdateCheckPhase.available => l.appUpdateAvailable(
          _update!.latestVersion,
        ),
        _ => l.settingsCheckForUpdates,
      }, textAlign: TextAlign.center),
      content: switch (_phase) {
        _UpdateCheckPhase.checking => Text(
          l.settingsCheckingForUpdates,
          textAlign: TextAlign.center,
        ),
        _UpdateCheckPhase.upToDate => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.settingsUpToDate, textAlign: TextAlign.center),
            if (_currentVersion != null) ...[
              const SizedBox(height: 6),
              Text(
                _currentVersion!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
        _UpdateCheckPhase.available => Text(
          'v${_update!.currentVersion} → v${_update!.latestVersion}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        _UpdateCheckPhase.failed => Text(
          l.settingsUpdateCheckFailed,
          textAlign: TextAlign.center,
        ),
      },
      actions: switch (_phase) {
        _UpdateCheckPhase.checking => [
          TextButton(
            key: const ValueKey('check_for_updates_cancel_button'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
        ],
        _UpdateCheckPhase.upToDate => [
          FilledButton(
            key: const ValueKey('check_for_updates_ok_button'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ml.okButtonLabel),
          ),
        ],
        _UpdateCheckPhase.available => [
          TextButton(
            key: const ValueKey('check_for_updates_cancel_button'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('check_for_updates_install_button'),
            onPressed: () {
              final update = _update!;
              Navigator.of(context).pop();
              unawaited(widget.performUpdate(update));
            },
            child: Text(_update!.canInstallInApp ? l.update : l.download),
          ),
        ],
        _UpdateCheckPhase.failed => [
          TextButton(
            key: const ValueKey('check_for_updates_close_button'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ml.closeButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('check_for_updates_retry_button'),
            onPressed: _runCheck,
            child: Text(l.retry),
          ),
        ],
      },
    );
  }
}
