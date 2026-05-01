import 'package:flutter/material.dart';

import '../../../models/machine.dart';

/// Banner shown when the connected Bridge Server version is older than expected.
///
/// Follows the same pattern as [SessionReconnectBanner] but with an update icon
/// and a dismiss button.
class BridgeUpdateBanner extends StatelessWidget {
  final String currentVersion;
  final String expectedVersion;
  final String? latestBridgeVersion;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const BridgeUpdateBanner({
    super.key,
    required this.currentVersion,
    required this.expectedVersion,
    this.latestBridgeVersion,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.tertiary;
    final targetVersion = _targetVersion(
      expectedVersion,
      latestBridgeVersion: latestBridgeVersion,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: const ValueKey('bridge_update_banner'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.system_update, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bridge Server v$currentVersion → v$targetVersion',
                    style: TextStyle(fontSize: 13, color: color),
                  ),
                ),
                if (onDismiss != null)
                  GestureDetector(
                    key: const ValueKey('bridge_update_banner_dismiss'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    child: Icon(Icons.close, size: 16, color: color),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns true if the banner should be shown.
  static bool shouldShow(
    String? currentVersion,
    String expectedVersion, {
    String? latestBridgeVersion,
  }) {
    if (currentVersion == null) return false;
    final info = BridgeVersionInfo(version: currentVersion);
    return info.needsUpdate(
      _targetVersion(expectedVersion, latestBridgeVersion: latestBridgeVersion),
    );
  }

  static String _targetVersion(
    String expectedVersion, {
    String? latestBridgeVersion,
  }) {
    if (latestBridgeVersion == null) return expectedVersion;
    return compareSemanticVersions(latestBridgeVersion, expectedVersion) > 0
        ? latestBridgeVersion
        : expectedVersion;
  }
}
