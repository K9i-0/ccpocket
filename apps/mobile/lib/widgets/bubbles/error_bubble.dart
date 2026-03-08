import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/messages.dart';
import '../../router/app_router.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

/// Maps errorCode to a localized title for the error bubble header.
String? _errorTitle(String? errorCode) {
  return switch (errorCode) {
    'auth_login_required' ||
    'auth_token_expired' ||
    'auth_api_error' => 'Authentication Error',
    'codex_auth_required' => 'Codex Authentication Error',
    'path_not_allowed' => 'Path Not Allowed',
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
    _ => null,
  };
}

/// Copyable command for the hint tap action.
String? _copyableCommand(String? errorCode) {
  return switch (errorCode) {
    'auth_login_required' ||
    'auth_token_expired' ||
    'auth_api_error' => 'claude auth login',
    _ => null,
  };
}

bool _isClaudeAuthError(String? errorCode) {
  return errorCode == 'auth_login_required' ||
      errorCode == 'auth_token_expired' ||
      errorCode == 'auth_api_error';
}

class ErrorBubble extends StatelessWidget {
  final ErrorMessage message;
  const ErrorBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final title = _errorTitle(message.errorCode);
    final hint = _errorHint(message.errorCode);
    final hasStructured = title != null;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.bubbleMarginV,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: appColors.errorBubble,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: appColors.errorBubbleBorder),
      ),
      child: hasStructured
          ? _buildStructured(context, appColors, title, hint)
          : _buildSimple(appColors),
    );
  }

  /// Original simple layout for errors without errorCode (backward compat).
  Widget _buildSimple(AppColors appColors) {
    return Row(
      children: [
        _errorIcon(appColors),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message.message,
            style: TextStyle(color: appColors.errorText, fontSize: 13),
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with icon and title
        Row(
          children: [
            _errorIcon(appColors),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: appColors.errorText,
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
            color: appColors.errorText.withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
        // Remedy hint
        if (hint != null) ...[
          const SizedBox(height: 8),
          _buildHint(context, appColors, hint),
        ],
        if (_isClaudeAuthError(message.errorCode)) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                context.router.navigate(const SettingsRoute());
              },
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Open Settings'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHint(BuildContext context, AppColors appColors, String hint) {
    final command = _copyableCommand(message.errorCode);
    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: appColors.errorText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 14,
            color: appColors.errorText.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                color: appColors.errorText.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
          if (command != null)
            Icon(
              Icons.copy,
              size: 12,
              color: appColors.errorText.withValues(alpha: 0.5),
            ),
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

  Widget _errorIcon(AppColors appColors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: appColors.errorText.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.error_outline, size: 14, color: appColors.errorText),
    );
  }
}
