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
    'auth_token_expired' => 'Run "claude auth login" on the Bridge machine',
    'auth_api_error' => 'Set ANTHROPIC_API_KEY on the Bridge machine',
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
    'auth_login_required' || 'auth_token_expired' => 'claude auth login',
    'bridge_update_required' => 'npm update -g @ccpocket/bridge',
    _ => null,
  };
}

bool _isClaudeAuthError(String? errorCode) {
  return errorCode == 'auth_login_required' ||
      errorCode == 'auth_token_expired';
}

bool _isApiKeyRequired(String? errorCode) {
  return errorCode == 'auth_api_error';
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
    final l = AppLocalizations.of(context);

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
          ? _isClaudeAuthError(resolvedErrorCode)
                ? _ClaudeAuthErrorCard(
                    textColor: textColor,
                    title: l.authErrorTitle,
                    body: l.authErrorBody,
                    primaryCommandLabel: l.authErrorPrimaryCommandLabel,
                    primaryCommand: 'claude',
                    secondaryCommandLabel: l.authErrorSecondaryCommandLabel,
                    secondaryCommand: '/login',
                    alternativeLabel: l.authErrorAlternativeLabel,
                    alternativeCommand: 'claude auth login',
                    helpLabel: l.authHelpButton,
                  )
                : _isApiKeyRequired(resolvedErrorCode)
                ? _ApiKeyRequiredCard(textColor: textColor)
                : _buildStructured(context, title, hint, textColor, isWarn)
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

class _ClaudeAuthErrorCard extends StatelessWidget {
  final Color textColor;
  final String title;
  final String body;
  final String primaryCommandLabel;
  final String primaryCommand;
  final String secondaryCommandLabel;
  final String secondaryCommand;
  final String alternativeLabel;
  final String alternativeCommand;
  final String helpLabel;

  const _ClaudeAuthErrorCard({
    required this.textColor,
    required this.title,
    required this.body,
    required this.primaryCommandLabel,
    required this.primaryCommand,
    required this.secondaryCommandLabel,
    required this.secondaryCommand,
    required this.alternativeLabel,
    required this.alternativeCommand,
    required this.helpLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _AuthIcon(textColor: textColor),
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
        Text(
          body,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.92),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        _AuthCommandRow(
          textColor: textColor,
          leadingLabel: primaryCommandLabel,
          command: primaryCommand,
        ),
        const SizedBox(height: 6),
        _AuthCommandRow(
          textColor: textColor,
          leadingLabel: secondaryCommandLabel,
          command: secondaryCommand,
        ),
        const SizedBox(height: 10),
        _AlternativeCommandHint(
          textColor: textColor,
          label: alternativeLabel,
          command: alternativeCommand,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('auth_help_button'),
          onPressed: () {
            context.router.navigate(const AuthHelpRoute());
          },
          icon: const Icon(Icons.help_outline, size: 16),
          label: Text(helpLabel),
        ),
      ],
    );
  }
}

class _ApiKeyRequiredCard extends StatelessWidget {
  final Color textColor;

  const _ApiKeyRequiredCard({required this.textColor});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _AuthIcon(textColor: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.apiKeyRequiredTitle,
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
        Text(
          l.apiKeyRequiredBody,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.92),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'ANTHROPIC_API_KEY=sk-ant-...',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l.apiKeyRequiredHint,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            Clipboard.setData(
              const ClipboardData(
                text: 'https://console.anthropic.com/settings/keys',
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied URL'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Text(
            'console.anthropic.com/settings/keys',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              decoration: TextDecoration.underline,
              decorationColor: textColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthCommandRow extends StatelessWidget {
  final Color textColor;
  final String leadingLabel;
  final String command;

  const _AuthCommandRow({
    required this.textColor,
    required this.leadingLabel,
    required this.command,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            leadingLabel,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: _CommandChip(
            textColor: textColor,
            command: command,
            copyValue: command,
          ),
        ),
      ],
    );
  }
}

class _AlternativeCommandHint extends StatelessWidget {
  final Color textColor;
  final String label;
  final String command;

  const _AlternativeCommandHint({
    required this.textColor,
    required this.label,
    required this.command,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        _CommandChip(
          textColor: textColor,
          command: command,
          copyValue: command,
        ),
      ],
    );
  }
}

class _CommandChip extends StatelessWidget {
  final Color textColor;
  final String command;
  final String copyValue;

  const _CommandChip({
    required this.textColor,
    required this.command,
    required this.copyValue,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: copyValue));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied "$copyValue"'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                command,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Icon(Icons.copy, size: 12, color: textColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _AuthIcon extends StatelessWidget {
  final Color textColor;

  const _AuthIcon({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.error_outline, size: 14, color: textColor),
    );
  }
}
