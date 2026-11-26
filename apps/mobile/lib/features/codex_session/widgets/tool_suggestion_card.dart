import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

/// Bottom card for Codex plugin and connector installation suggestions.
class ToolSuggestionCard extends StatelessWidget {
  final AppColors appColors;
  final PermissionRequestMessage permission;
  final VoidCallback onInstall;
  final VoidCallback onComplete;
  final VoidCallback onReject;
  final ValueChanged<String> onOpenUrl;

  const ToolSuggestionCard({
    super.key,
    required this.appColors,
    required this.permission,
    required this.onInstall,
    required this.onComplete,
    required this.onReject,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final installState = permission.toolSuggestionInstallState;
    final apps = permission.appsNeedingAuthentication;
    final connectorUrl = permission.toolSuggestionInstallUrl;
    final accentColor = cs.primary;

    return Container(
      key: const ValueKey('tool_suggestion_card'),
      width: double.infinity,
      decoration: ShapeDecoration(
        color: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.85 : 0.9),
            width: 1,
          ),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(
                        alpha: isDark ? 0.16 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withValues(
                          alpha: isDark ? 0.28 : 0.22,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.extension_outlined,
                      size: 16,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.toolSuggestionTitle(permission.suggestedToolName),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          permission.toolSuggestionReason,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (installState == 'needs_auth') ...[
                const SizedBox(height: 12),
                Text(
                  l.toolSuggestionAuthDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                _ToolSuggestionAuthLinks(
                  apps: apps,
                  connectorUrl: connectorUrl,
                  fallbackName: permission.suggestedToolName,
                  onOpenUrl: onOpenUrl,
                ),
              ],
              if (installState == 'failed') ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: appColors.errorBubble,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: appColors.errorBubbleBorder.withValues(
                        alpha: isDark ? 0.8 : 0.45,
                      ),
                    ),
                  ),
                  child: Text(
                    [
                      l.toolSuggestionFailed,
                      if (permission.toolSuggestionInstallError case final e?
                          when e.isNotEmpty)
                        e,
                    ].join(': '),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: appColors.errorText,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _ToolSuggestionActions(
                installState: installState,
                toolName: permission.suggestedToolName,
                onInstall: onInstall,
                onComplete: onComplete,
                onReject: onReject,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolSuggestionAuthLinks extends StatelessWidget {
  final List<ToolSuggestionApp> apps;
  final String? connectorUrl;
  final String fallbackName;
  final ValueChanged<String> onOpenUrl;

  const _ToolSuggestionAuthLinks({
    required this.apps,
    required this.connectorUrl,
    required this.fallbackName,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final links = <({String id, String name, String url})>[
      for (final app in apps)
        if (app.installUrl case final url? when url.isNotEmpty)
          (id: app.id, name: app.name, url: url),
      if (connectorUrl case final url? when apps.isEmpty && url.isNotEmpty)
        (id: 'connector', name: fallbackName, url: url),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final link in links)
          OutlinedButton.icon(
            key: ValueKey('tool_suggestion_auth_${link.id}_button'),
            onPressed: () => onOpenUrl(link.url),
            icon: const Icon(Icons.open_in_new, size: 15),
            label: Text(l.toolSuggestionConnect(link.name)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 38),
              foregroundColor: cs.onSurface,
              side: BorderSide(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.85 : 1.0),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _ToolSuggestionActions extends StatelessWidget {
  final String installState;
  final String toolName;
  final VoidCallback onInstall;
  final VoidCallback onComplete;
  final VoidCallback onReject;

  const _ToolSuggestionActions({
    required this.installState,
    required this.toolName,
    required this.onInstall,
    required this.onComplete,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    if (installState == 'installing') {
      return Row(
        key: const ValueKey('tool_suggestion_installing'),
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            l.toolSuggestionInstalling,
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

    final isAuthPending = installState == 'needs_auth';
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            key: const ValueKey('tool_suggestion_decline_button'),
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(0, 40),
              foregroundColor: cs.onSurfaceVariant,
              side: BorderSide(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.85 : 1.0),
              ),
              shape: buttonShape,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: Text(l.toolSuggestionNotNow),
          ),
          FilledButton.icon(
            key: ValueKey(
              isAuthPending
                  ? 'tool_suggestion_complete_button'
                  : 'tool_suggestion_install_button',
            ),
            onPressed: isAuthPending ? onComplete : onInstall,
            icon: Icon(
              isAuthPending ? Icons.check : Icons.download_outlined,
              size: 16,
            ),
            label: Text(
              isAuthPending
                  ? l.toolSuggestionComplete
                  : installState == 'failed'
                  ? l.tryAgain
                  : l.toolSuggestionInstall(toolName),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(0, 40),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: buttonShape,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
