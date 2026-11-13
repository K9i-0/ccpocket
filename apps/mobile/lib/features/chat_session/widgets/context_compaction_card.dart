import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/markdown_style.dart';

/// Divider shown at a context compaction boundary.
///
/// In the chat it is the first visible row: earlier messages are folded into
/// it and [onOpenTranscript] shows them. The transcript screen renders it
/// without a tap action.
class ContextCompactionCard extends StatefulWidget {
  const ContextCompactionCard({
    super.key,
    required this.message,
    this.onOpenTranscript,
  });

  final ContextCompactionMessage message;
  final VoidCallback? onOpenTranscript;

  @override
  State<ContextCompactionCard> createState() => _ContextCompactionCardState();
}

class _ContextCompactionCardState extends State<ContextCompactionCard> {
  bool _summaryExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final message = widget.message;
    final summary = message.summary;
    return _BoundaryFrame(
      key: const ValueKey('context_compaction_card'),
      icon: Icons.compress,
      title: l.contextCompactionTitle,
      details: _CompactionDetails(message: message),
      children: [
        if (summary != null) ...[
          _CardTextButton(
            key: const ValueKey('context_compaction_summary_button'),
            icon: _summaryExpanded ? Icons.expand_less : Icons.expand_more,
            label: _summaryExpanded
                ? l.contextCompactionHideSummary
                : l.contextCompactionShowSummary,
            onPressed: () =>
                setState(() => _summaryExpanded = !_summaryExpanded),
          ),
          if (_summaryExpanded) _CompactionSummary(text: summary),
        ],
        if (widget.onOpenTranscript case final onOpen?)
          _CardTextButton(
            key: const ValueKey('context_compaction_transcript_button'),
            icon: Icons.history,
            label: l.contextCompactionOpenTranscript,
            onPressed: onOpen,
          ),
      ],
    );
  }
}

/// First row of a chat whose older messages were dropped from the live
/// history window without a compaction boundary.
class OlderHistoryCard extends StatelessWidget {
  const OlderHistoryCard({super.key, this.onOpenTranscript});

  final VoidCallback? onOpenTranscript;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _BoundaryFrame(
      key: const ValueKey('older_history_card'),
      icon: Icons.history,
      title: l.olderHistoryTitle,
      children: [
        if (onOpenTranscript case final onOpen?)
          _CardTextButton(
            key: const ValueKey('older_history_transcript_button'),
            icon: Icons.history,
            label: l.contextCompactionOpenTranscript,
            onPressed: onOpen,
          ),
      ],
    );
  }
}

/// Last row while the provider compacts the context.
class CompactingIndicatorRow extends StatelessWidget {
  const CompactingIndicatorRow({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      key: const ValueKey('compacting_indicator'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: appColors.statusCompacting,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              AppLocalizations.of(context).contextCompactionInProgress,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: appColors.statusCompacting),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle? _detailStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).extension<AppColors>()!.subtleText);

class _BoundaryFrame extends StatelessWidget {
  const _BoundaryFrame({
    super.key,
    required this.icon,
    required this.title,
    this.details,
    required this.children,
  });

  final IconData icon;
  final String title;
  final Widget? details;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final accent = appColors.statusCompacting;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (details case final details?)
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 4),
                  child: details,
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactionDetails extends StatelessWidget {
  const _CompactionDetails({required this.message});

  final ContextCompactionMessage message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final parts = <String>[
      if (message.isManual) l.contextCompactionManual,
      if (message.isAuto) l.contextCompactionAuto,
      ?_tokenRange(l, message),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(parts.join(' · '), style: _detailStyle(context));
  }
}

String? _tokenRange(AppLocalizations l, ContextCompactionMessage message) {
  final before = message.preTokens;
  if (before == null) return null;
  final after = message.postTokens;
  return l.contextCompactionTokens(
    formatTokenCount(before),
    after == null ? '?' : formatTokenCount(after),
  );
}

/// Formats a token count compactly (`21935` → `21.9k`).
String formatTokenCount(int tokens) {
  if (tokens < 1000) return '$tokens';
  final thousands = tokens / 1000;
  return thousands >= 100
      ? '${thousands.round()}k'
      : '${thousands.toStringAsFixed(1)}k';
}

class _CompactionSummary extends StatelessWidget {
  const _CompactionSummary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('context_compaction_summary'),
      padding: const EdgeInsets.fromLTRB(24, 0, 0, 8),
      child: SelectionArea(
        child: MarkdownBody(
          data: text,
          styleSheet: buildMarkdownStyle(context),
        ),
      ),
    );
  }
}

class _CardTextButton extends StatelessWidget {
  const _CardTextButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).extension<AppColors>()!.statusCompacting;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: accent,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
