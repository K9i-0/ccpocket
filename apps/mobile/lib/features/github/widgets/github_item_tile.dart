import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

/// Relative time for list rows; falls back to a short date after a month.
String githubRelativeTime(BuildContext context, DateTime? time) {
  if (time == null) return '';
  final l = AppLocalizations.of(context);
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.hoursAgo(diff.inHours);
  if (diff.inDays < 30) return l.daysAgo(diff.inDays);
  return MaterialLocalizations.of(context).formatShortDate(time.toLocal());
}

/// One pull request or issue row.
class GitHubItemTile extends StatelessWidget {
  final GitHubItemSummary item;
  final GitHubItemKind kind;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const GitHubItemTile({
    super.key,
    required this.item,
    required this.kind,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
          : Colors.transparent,
      child: InkWell(
        key: ValueKey('github_item_${item.number}'),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: _GitHubItemLeading(
                  number: item.number,
                  kind: kind,
                  isDraft: item.isDraft,
                  selectionMode: selectionMode,
                  selected: selected,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '#${item.number} ',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: item.title),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 6),
                    switch (kind) {
                      GitHubItemKind.pr => _PullRequestMeta(item: item),
                      GitHubItemKind.issue => _IssueMeta(item: item),
                    },
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GitHubItemLeading extends StatelessWidget {
  final int number;
  final GitHubItemKind kind;
  final bool isDraft;
  final bool selectionMode;
  final bool selected;

  const _GitHubItemLeading({
    required this.number,
    required this.kind,
    required this.isDraft,
    required this.selectionMode,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (selectionMode) {
      return Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        key: ValueKey('github_item_check_$number'),
        size: 22,
        color: selected ? colorScheme.primary : colorScheme.outline,
      );
    }
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Icon(
      switch (kind) {
        GitHubItemKind.pr => Icons.merge_type,
        GitHubItemKind.issue => Icons.adjust,
      },
      size: 22,
      color: isDraft ? colorScheme.outline : appColors.statusOnline,
    );
  }
}

class _PullRequestMeta extends StatelessWidget {
  final GitHubItemSummary item;

  const _PullRequestMeta({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final checks = item.checks ?? GitHubChecksState.none;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (item.isDependabot)
          GitHubBadge(
            key: ValueKey('github_dependabot_badge_${item.number}'),
            icon: Icons.smart_toy_outlined,
            label: 'dependabot',
            foreground: colorScheme.onTertiaryContainer,
            background: colorScheme.tertiaryContainer,
          )
        else if (item.author.login.isNotEmpty)
          Text(
            item.author.login,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        if (item.isDraft)
          GitHubBadge(
            key: ValueKey('github_draft_badge_${item.number}'),
            label: AppLocalizations.of(context).githubDraft,
            foreground: colorScheme.onSurfaceVariant,
            background: colorScheme.surfaceContainerHighest,
          ),
        if (checks != GitHubChecksState.none)
          GitHubChecksIcon(
            key: ValueKey('github_checks_${item.number}'),
            state: checks,
          ),
      ],
    );
  }
}

class _IssueMeta extends StatelessWidget {
  final GitHubItemSummary item;

  const _IssueMeta({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final created = githubRelativeTime(context, item.createdAt);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final label in item.labels)
          GitHubBadge(
            label: label,
            foreground: colorScheme.onSecondaryContainer,
            background: colorScheme.secondaryContainer,
          ),
        if (created.isNotEmpty)
          Text(
            created,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Small pill used for Draft, dependabot, and label markers.
class GitHubBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color foreground;
  final Color background;

  const GitHubBadge({
    super.key,
    required this.label,
    this.icon,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Combined CI state of a pull request.
class GitHubChecksIcon extends StatelessWidget {
  final GitHubChecksState state;

  const GitHubChecksIcon({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final (icon, color, label) = switch (state) {
      GitHubChecksState.success => (
        Icons.check_circle_outline,
        appColors.statusOnline,
        l.githubChecksSuccess,
      ),
      GitHubChecksState.failure => (
        Icons.cancel_outlined,
        Theme.of(context).colorScheme.error,
        l.githubChecksFailure,
      ),
      GitHubChecksState.pending => (
        Icons.schedule,
        appColors.statusApproval,
        l.githubChecksPending,
      ),
      GitHubChecksState.none => (Icons.remove, Colors.transparent, ''),
    };
    if (state == GitHubChecksState.none) return const SizedBox.shrink();
    return Tooltip(
      message: label,
      child: Icon(icon, size: 16, color: color, semanticLabel: label),
    );
  }
}
