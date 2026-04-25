import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';

class MacOSNativeAppBanner extends StatelessWidget {
  const MacOSNativeAppBanner({super.key, this.onDismiss, this.onOpen});

  final VoidCallback? onDismiss;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.primary;
    final l = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('macos_native_app_banner'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.desktop_mac_outlined, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.macosNativeAppBannerTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l.macosNativeAppBannerSubtitle,
                  style: TextStyle(fontSize: 12, color: color),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  key: const ValueKey('macos_native_app_banner_open_button'),
                  onPressed:
                      onOpen ??
                      () => launchUrl(
                        Uri.parse(AppConstants.macOSReleasesUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: color,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: Text(l.openGitHubReleases),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('macos_native_app_banner_dismiss_button'),
            onPressed: onDismiss,
            icon: Icon(Icons.close, size: 18, color: color),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
