import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../media_feedback/state/media_feedback_state.dart';

class DiffCommentCard extends StatelessWidget {
  final MediaFeedback comment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Outdated comments quote their lines because they are no longer visible.
  final bool showExcerpt;

  /// Where the lines are now; the stored anchor keeps the original numbers.
  final CodeAnchor? currentAnchor;

  const DiffCommentCard({
    super.key,
    required this.comment,
    required this.onEdit,
    required this.onDelete,
    this.showExcerpt = false,
    this.currentAnchor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final anchor = currentAnchor ?? comment.code;
    return _CommentFrame(
      child: InkWell(
        key: ValueKey('diff_comment_${comment.id}'),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  if (anchor != null)
                    Text(
                      codeLineLabel(anchor),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: appColors.subtleText,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    key: ValueKey('diff_comment_delete_${comment.id}'),
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    tooltip: AppLocalizations.of(context).delete,
                    icon: const Icon(Icons.close),
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (showExcerpt && anchor != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 8),
                  child: Text(
                    anchor.excerpt,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: appColors.subtleText,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(comment.text, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saves on every change like media instructions; an empty text removes the
/// draft through [onChanged]'s owner.
class DiffCommentEditor extends StatefulWidget {
  final String initialText;
  final CodeAnchor anchor;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;
  final VoidCallback? onDelete;

  const DiffCommentEditor({
    super.key,
    required this.initialText,
    required this.anchor,
    required this.onChanged,
    required this.onDone,
    this.onDelete,
  });

  @override
  State<DiffCommentEditor> createState() => _DiffCommentEditorState();
}

class _DiffCommentEditorState extends State<DiffCommentEditor> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    return _CommentFrame(
      highlighted: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('diff_comment_field'),
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: l.diffCommentHint(codeLineLabel(widget.anchor)),
              ),
              onChanged: widget.onChanged,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.mediaFeedbackSendHint,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: appColors.subtleText,
                    ),
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    key: const ValueKey('diff_comment_editor_delete'),
                    visualDensity: VisualDensity.compact,
                    tooltip: l.delete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: widget.onDelete,
                  ),
                TextButton(
                  key: const ValueKey('diff_comment_done'),
                  onPressed: widget.onDone,
                  child: Text(l.mediaFeedbackDone),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DiffOutdatedComments extends StatelessWidget {
  final List<Widget> children;
  const DiffOutdatedComments({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              AppLocalizations.of(context).diffCommentOutdated,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _CommentFrame extends StatelessWidget {
  final Widget child;
  final bool highlighted;
  const _CommentFrame({required this.child, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: highlighted ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
