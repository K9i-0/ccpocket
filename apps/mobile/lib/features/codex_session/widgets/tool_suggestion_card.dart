import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final installState = permission.toolSuggestionInstallState;
    final apps = permission.appsNeedingAuthentication;
    final connectorUrl = permission.toolSuggestionInstallUrl;

    return Container(
      key: const ValueKey('tool_suggestion_card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            appColors.approvalBar,
            appColors.approvalBar.withValues(alpha: 0.7),
          ],
        ),
        border: Border(
          top: BorderSide(color: appColors.approvalBarBorder, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.extension_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.toolSuggestionTitle(permission.suggestedToolName),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        permission.toolSuggestionReason,
                        style: TextStyle(
                          fontSize: 12,
                          color: appColors.subtleText,
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
                  color: colorScheme.onSurfaceVariant,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  [
                    l.toolSuggestionFailed,
                    if (permission.toolSuggestionInstallError case final e?
                        when e.isNotEmpty)
                      e,
                  ].join(': '),
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onErrorContainer,
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
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(l.toolSuggestionConnect(link.name)),
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
          Text(l.toolSuggestionInstalling),
        ],
      );
    }

    final isAuthPending = installState == 'needs_auth';
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          key: const ValueKey('tool_suggestion_decline_button'),
          onPressed: onReject,
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
            size: 18,
          ),
          label: Text(
            isAuthPending
                ? l.toolSuggestionComplete
                : installState == 'failed'
                ? l.tryAgain
                : l.toolSuggestionInstall(toolName),
          ),
        ),
      ],
    );
  }
}
