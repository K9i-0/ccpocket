import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/github_list_state.dart';

/// Explains why GitHub data is unavailable and what to do about it.
///
/// An older Bridge (`unsupported`) is handled here, inside the screen that
/// waits for the response, instead of through the chat's unsupported-message
/// notices.
class GitHubErrorView extends StatelessWidget {
  final GitHubFailure failure;
  final VoidCallback? onRetry;

  const GitHubErrorView({super.key, required this.failure, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (icon, title, body, command) = switch (failure.kind) {
      GitHubFailureKind.ghMissing => (
        Icons.terminal,
        l.githubErrorGhMissingTitle,
        l.githubErrorGhMissingBody,
        'https://cli.github.com',
      ),
      GitHubFailureKind.ghUnauthenticated => (
        Icons.lock_outline,
        l.githubErrorUnauthenticatedTitle,
        l.githubErrorUnauthenticatedBody,
        'gh auth login',
      ),
      GitHubFailureKind.notGithub => (
        Icons.link_off,
        l.githubErrorNotGithubTitle,
        l.githubErrorNotGithubBody,
        null,
      ),
      GitHubFailureKind.unsupported => (
        Icons.system_update_alt,
        l.githubErrorUnsupportedTitle,
        l.githubErrorUnsupportedBody,
        null,
      ),
      GitHubFailureKind.timeout => (
        Icons.cloud_off,
        l.githubErrorFailedTitle,
        l.githubErrorTimeoutBody,
        null,
      ),
      GitHubFailureKind.failed => (
        Icons.error_outline,
        l.githubErrorFailedTitle,
        failure.message,
        null,
      ),
    };
    return Padding(
      key: ValueKey('github_error_${failure.kind.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (command != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                command,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              key: const ValueKey('github_retry_button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l.retry),
            ),
          ],
        ],
      ),
    );
  }
}
