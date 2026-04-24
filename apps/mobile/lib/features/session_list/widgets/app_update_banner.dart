import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/app_update_service.dart';

/// Banner shown on the home screen when a newer macOS app version is available.
///
/// Styled consistently with [BridgeUpdateBanner] but uses the primary color
/// scheme and includes an update action.
class AppUpdateBanner extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback? onDismiss;

  const AppUpdateBanner({super.key, required this.updateInfo, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.primary;
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.upgrade, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.appUpdateAvailable(updateInfo.latestVersion),
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
          GestureDetector(
            onTap: () => AppUpdateService.instance.performUpdate(updateInfo),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                updateInfo.canInstallInApp ? l.update : l.download,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 16, color: color),
            ),
          ],
        ],
      ),
    );
  }
}
