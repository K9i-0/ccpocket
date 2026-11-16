import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../theme/markdown_style.dart';
import '../../../widgets/workspace_pane_chrome.dart';
import '../state/github_item_cubit.dart';
import 'github_error_view.dart';
import 'github_item_tile.dart';

/// Shows the body and latest comments of one pull request or issue.
Future<void> showGitHubItemDetailSheet(
  BuildContext context, {
  required String projectPath,
  required GitHubItemKind kind,
  required GitHubItemSummary summary,
}) {
  final bridge = context.read<BridgeService>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: macOSModalBottomSheetConstraints(context),
    builder: (_) => BlocProvider(
      create: (_) => GitHubItemCubit(
        bridge: bridge,
        projectPath: projectPath,
        kind: kind,
        summary: summary,
      ),
      child: GitHubItemDetailSheet(kind: kind),
    ),
  );
}

class GitHubItemDetailSheet extends StatelessWidget {
  final GitHubItemKind kind;

  const GitHubItemDetailSheet({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 1,
      builder: (context, scrollController) =>
          BlocBuilder<GitHubItemCubit, GitHubItemState>(
            builder: (context, state) {
              final detail = state.detail;
              final failure = state.failure;
              return ListView(
                key: const ValueKey('github_detail_list'),
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _GitHubDetailHeader(summary: state.summary, kind: kind),
                  const Divider(height: 24),
                  if (failure != null)
                    GitHubErrorView(
                      failure: failure,
                      onRetry: context.read<GitHubItemCubit>().load,
                    )
                  else if (detail == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _GitHubDetailBody(detail: detail),
                ],
              );
            },
          ),
    );
  }
}

class _GitHubDetailHeader extends StatelessWidget {
  final GitHubItemSummary summary;
  final GitHubItemKind kind;

  const _GitHubDetailHeader({required this.summary, required this.kind});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final checks = summary.checks ?? GitHubChecksState.none;
    final created = githubRelativeTime(context, summary.createdAt);
    final uri = Uri.tryParse(summary.url);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '#${summary.number} ${summary.title}',
          key: const ValueKey('github_detail_title'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (summary.author.login.isNotEmpty)
              Text(
                [
                  summary.author.login,
                  if (created.isNotEmpty) created,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (summary.isDraft)
              GitHubBadge(
                label: l.githubDraft,
                foreground: colorScheme.onSurfaceVariant,
                background: colorScheme.surfaceContainerHighest,
              ),
            if (kind == GitHubItemKind.pr && checks != GitHubChecksState.none)
              GitHubChecksIcon(state: checks),
            for (final label in summary.labels)
              GitHubBadge(
                label: label,
                foreground: colorScheme.onSecondaryContainer,
                background: colorScheme.secondaryContainer,
              ),
          ],
        ),
        if (uri != null && uri.hasScheme) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('github_open_on_github_button'),
            onPressed: () => unawaited(launchMarkdownUri(uri)),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l.githubOpenOnGitHub),
          ),
        ],
      ],
    );
  }
}

class _GitHubDetailBody extends StatelessWidget {
  final GitHubItemDetail detail;

  const _GitHubDetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.body.trim().isEmpty)
          Text(l.githubNoDescription, style: muted)
        else
          GitHubMarkdown(
            key: const ValueKey('github_detail_body'),
            data: detail.body,
          ),
        const Divider(height: 32),
        Text(l.githubRecentComments, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (detail.comments.isEmpty)
          Text(l.githubNoComments, style: muted)
        else
          for (final comment in detail.comments)
            _GitHubCommentCard(comment: comment),
      ],
    );
  }
}

class _GitHubCommentCard extends StatelessWidget {
  final GitHubComment comment;

  const _GitHubCommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final created = githubRelativeTime(context, comment.createdAt);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [comment.author.login, if (created.isNotEmpty) created].join(' · '),
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          GitHubMarkdown(data: comment.body),
        ],
      ),
    );
  }
}

/// GitHub Markdown rendered with the app's chat Markdown style.
class GitHubMarkdown extends StatelessWidget {
  final String data;

  const GitHubMarkdown({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: buildMarkdownStyle(context),
      onTapLink: handleMarkdownLink,
      builders: markdownBuilders,
    );
  }
}
