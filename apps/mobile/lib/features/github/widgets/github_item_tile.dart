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
///
/// The leading circle picks the item for the session; the rest of the row
/// opens its detail, so both work without a selection mode.
class GitHubItemTile extends StatelessWidget {
  final GitHubItemSummary item;
  final GitHubItemKind kind;
  final bool selected;
  final VoidCallback onTap;

  /// `null` when the item cannot be selected (it has no URL).
  final VoidCallback? onToggleSelected;

  const GitHubItemTile({
    super.key,
    required this.item,
    required this.kind,
    required this.selected,
    required this.onTap,
    required this.onToggleSelected,
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
        onLongPress: onToggleSelected,
        child: Padding(
          padding: const EdgeInsets.only(left: 4, right: 16, top: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GitHubSelectToggle(
                number: item.number,
                selected: selected,
                onPressed: onToggleSelected,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14, right: 8),
                child: _GitHubKindIcon(kind: kind, isDraft: item.isDraft),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selection circle of a row, with a full-size tap target.
class GitHubSelectToggle extends StatelessWidget {
  final int number;
  final bool selected;
  final VoidCallback? onPressed;

  const GitHubSelectToggle({
    super.key,
    required this.number,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      key: ValueKey('github_item_select_$number'),
      onPressed: onPressed,
      isSelected: selected,
      tooltip: selected ? l.githubDeselect : l.githubSelect,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(Icons.radio_button_unchecked, color: colorScheme.outline),
      selectedIcon: Icon(Icons.check_circle, color: colorScheme.primary),
    );
  }
}

class _GitHubKindIcon extends StatelessWidget {
  final GitHubItemKind kind;
  final bool isDraft;

  const _GitHubKindIcon({required this.kind, required this.isDraft});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    return Icon(
      switch (kind) {
        GitHubItemKind.pr => Icons.merge_type,
        GitHubItemKind.issue => Icons.adjust,
      },
      size: 20,
      color: isDraft ? theme.colorScheme.outline : appColors.statusOnline,
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
