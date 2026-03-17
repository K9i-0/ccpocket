import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../router/app_router.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../utils/structured_error_inference.dart';

/// Maps errorCode to a localized title for the error bubble header.
String? _errorTitle(String? errorCode) {
  return switch (errorCode) {
    'auth_login_required' ||
    'auth_token_expired' ||
    'auth_api_error' => 'Authentication Error',
    'codex_auth_required' => 'Codex Authentication Error',
    'path_not_allowed' => 'Path Not Allowed',
    'git_not_available' => 'Git Not Available',
    'bridge_update_required' => 'Bridge Update Required',
    _ => null,
  };
}

/// Maps errorCode to a short remedy hint shown below the message.
String? _errorHint(String? errorCode) {
  return switch (errorCode) {
    'auth_login_required' ||
    'auth_token_expired' ||
    'auth_api_error' => 'Run "claude auth login" on the Bridge machine',
    'codex_auth_required' => 'Check OPENAI_API_KEY on the Bridge machine',
    'path_not_allowed' => 'Update BRIDGE_ALLOWED_DIRS on the Bridge server',
    'git_not_available' =>
      'Git features (diff, file list) are not available for this project',
    'bridge_update_required' => 'npm update -g @ccpocket/bridge',
    _ => null,
  };
}

/// Copyable command for the hint tap action.
String? _copyableCommand(String? errorCode) {
  return switch (errorCode) {
    'auth_login_required' ||
    'auth_token_expired' ||
    'auth_api_error' => 'claude auth login',
    'bridge_update_required' => 'npm update -g @ccpocket/bridge',
    _ => null,
  };
}

bool _isClaudeAuthError(String? errorCode) {
  return errorCode == 'auth_login_required' ||
      errorCode == 'auth_token_expired' ||
      errorCode == 'auth_api_error';
}

/// Whether the errorCode represents a non-critical warning (amber style).
bool _isWarning(String? errorCode) {
  return errorCode == 'git_not_available' ||
      errorCode == 'bridge_update_required';
}

class ErrorBubble extends StatelessWidget {
  final ErrorMessage message;
  const ErrorBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final resolvedErrorCode = inferStructuredErrorCode(
      message: message.message,
      explicitErrorCode: message.errorCode,
    );
    final title = _errorTitle(resolvedErrorCode);
    final hint = _errorHint(resolvedErrorCode);
    final hasStructured = title != null;
    final isWarn = _isWarning(resolvedErrorCode);

    final bubbleColor = isWarn
        ? appColors.warningBubble
        : appColors.errorBubble;
    final borderColor = isWarn
        ? appColors.warningBubbleBorder
        : appColors.errorBubbleBorder;
    final textColor = isWarn ? appColors.warningText : appColors.errorText;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.bubbleMarginV,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: borderColor),
      ),
      child: hasStructured
          ? _buildStructured(context, appColors, title, hint, textColor, isWarn)
          : _buildSimple(textColor),
    );
  }

  /// Original simple layout for errors without errorCode (backward compat).
  Widget _buildSimple(Color textColor) {
    return Row(
      children: [
        _icon(textColor, false),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message.message,
            style: TextStyle(color: textColor, fontSize: 13),
          ),
        ),
      ],
    );
  }

  /// Structured layout with title, message body, and remedy hint.
  Widget _buildStructured(
    BuildContext context,
    AppColors appColors,
    String title,
    String? hint,
    Color textColor,
    bool isWarn,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with icon and title
        Row(
          children: [
            _icon(textColor, isWarn),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Message body
        Text(
          message.message,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
        // Remedy hint
        if (hint != null) ...[
          const SizedBox(height: 8),
          _buildHint(context, textColor, hint),
        ],
        if (_isClaudeAuthError(
          inferStructuredErrorCode(
            message: message.message,
            explicitErrorCode: message.errorCode,
          ),
        )) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  context.router.navigate(const SettingsRoute());
                },
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Open Settings'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  context.router.navigate(const AuthHelpRoute());
                },
                icon: const Icon(Icons.help_outline, size: 16),
                label: Text(AppLocalizations.of(context).authHelpButton),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHint(BuildContext context, Color textColor, String hint) {
    final command = _copyableCommand(
      inferStructuredErrorCode(
        message: message.message,
        explicitErrorCode: message.errorCode,
      ),
    );
    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 14,
            color: textColor.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
          if (command != null)
            Icon(Icons.copy, size: 12, color: textColor.withValues(alpha: 0.5)),
        ],
      ),
    );

    if (command != null) {
      return GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: command));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied "$command"'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: child,
      );
    }
    return child;
  }

  Widget _icon(Color textColor, bool isWarn) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        isWarn ? Icons.info_outline : Icons.error_outline,
        size: 14,
        color: textColor,
      ),
    );
  }
}
