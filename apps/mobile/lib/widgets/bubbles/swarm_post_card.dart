import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/file_peek/file_path_syntax.dart';
import '../../features/file_peek/markdown_link_handler.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/bridge_cubits.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/markdown_style.dart';
import '../../theme/swarm_colors.dart';
import '../google_search_text_selection.dart';
import '../link_hover_underline.dart';
import '../workspace_pane_chrome.dart';

/// Tool name the Bridge uses for a post on an Antigravity swarm's board.
const swarmPostToolName = 'SwarmPost';

/// Parsed summary fields of a swarm board post, used for the compact row.
class SwarmPostSummary {
  final String agent;
  final String? seqLabel;
  final String? timeLabel;
  final String? targetMention;
  final String previewText;
  final String fullText;

  /// Where the author and the member the post addresses stand in the order
  /// workers joined. Null for the coordinator and from an older Bridge.
  final int? agentIndex;
  final int? targetIndex;

  const SwarmPostSummary({
    required this.agent,
    this.agentIndex,
    this.targetIndex,
    required this.seqLabel,
    required this.timeLabel,
    required this.targetMention,
    required this.previewText,
    required this.fullText,
  });

  bool get isCoordinator => agent == 'coordinator';

  /// The colour this post's author is shown in everywhere.
  Color accent(BuildContext context) => swarmMemberColor(
    context,
    isCoordinator: isCoordinator,
    index: agentIndex,
  );

  /// The colour of the member the post addresses, when it is known.
  Color? targetAccent(BuildContext context) {
    final isCoordinatorTarget = targetMention == '@coordinator';
    if (!isCoordinatorTarget && targetIndex == null) return null;
    return swarmMemberColor(
      context,
      isCoordinator: isCoordinatorTarget,
      index: targetIndex,
    );
  }
}

/// The chip naming whom a post addresses. With a member colour for the text
/// it sits on the plain surface, outlined in that colour, so the name keeps
/// its contrast; without one it is the grey chip it always was.
BoxDecoration swarmTargetChipDecoration(
  BuildContext context,
  SwarmPostSummary summary, {
  required double radius,
  required Color plainColor,
}) {
  final accent = summary.targetAccent(context);
  return BoxDecoration(
    color: accent == null ? plainColor : Theme.of(context).colorScheme.surface,
    border: accent == null
        ? null
        : Border.all(color: accent.withValues(alpha: 0.45), width: 0.8),
    borderRadius: BorderRadius.circular(radius),
  );
}

int? _memberIndex(Object? value) =>
    value is num && value >= 0 ? value.toInt() : null;

final _leadingMentionRe = RegExp(r'^@([A-Za-z0-9_-]+)\s+');
final _timeExtractRe = RegExp(r'(\d{2}:\d{2})(?::\d{2})?');
final _markdownPrefixRe = RegExp(r'^\s*(?:#{1,6}\s+|[-*+]\s+|\d+\.\s+|>\s*)');
final _inlineMarkdownRe = RegExp(r'[*_`~]+');

/// Extract compact display fields from a `SwarmPost` tool input.
SwarmPostSummary parseSwarmPostSummary(Map<String, dynamic> input) {
  final agent = input['agent']?.toString().trim() ?? '';
  final fullText = input['text']?.toString() ?? '';
  final seq = input['seq'];
  final seqLabel = seq != null ? '#$seq' : null;
  final rawTime = input['time']?.toString().trim();
  final timeMatch = rawTime != null ? _timeExtractRe.firstMatch(rawTime) : null;
  final timeLabel = timeMatch?.group(1);

  final trimmed = fullText.trim();
  String? targetMention;
  var bodyForPreview = trimmed;
  final mentionMatch = _leadingMentionRe.firstMatch(trimmed);
  if (mentionMatch != null) {
    targetMention = '@${mentionMatch.group(1)}';
    bodyForPreview = trimmed.substring(mentionMatch.end).trimLeft();
  }

  final previewLines = <String>[];
  for (final rawLine in bodyForPreview.split('\n')) {
    var line = rawLine.trim();
    if (line.isEmpty || line.startsWith('```')) continue;
    line = line
        .replaceFirst(_markdownPrefixRe, '')
        .replaceAll(_inlineMarkdownRe, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (line.isEmpty) continue;
    previewLines.add(line);
    if (previewLines.length >= 2) break;
  }
  final previewText = previewLines.isNotEmpty
      ? previewLines.join(' · ')
      : trimmed.replaceAll(RegExp(r'\s+'), ' ');

  return SwarmPostSummary(
    agent: agent,
    agentIndex: _memberIndex(input['agentIndex']),
    // Only for the member the post opens with, which is who the Bridge numbers.
    targetIndex: targetMention != null
        ? _memberIndex(input['targetIndex'])
        : null,
    seqLabel: seqLabel,
    timeLabel: timeLabel,
    targetMention: targetMention,
    previewText: previewText,
    fullText: fullText,
  );
}

/// One post on a swarm's shared board: compact by default, expandable inline
/// on tap, with a full-screen bottom sheet for comfortable reading of long
/// posts.
class SwarmPostCard extends StatefulWidget {
  final Map<String, dynamic> input;
  final FilePathTapCallback? onFileTap;

  const SwarmPostCard({super.key, required this.input, this.onFileTap});

  @override
  State<SwarmPostCard> createState() => _SwarmPostCardState();
}

class _SwarmPostCardState extends State<SwarmPostCard> {
  bool _expanded = false;
  bool _restoredFromStorage = false;

  String get _storageKey {
    final seq = widget.input['seq'];
    final agent = widget.input['agent']?.toString() ?? '';
    if (seq != null) return 'swarm_post_expanded:$seq:$agent';
    return 'swarm_post_expanded:${agent.hashCode}:${widget.input['text'].hashCode}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredFromStorage) return;
    _restoredFromStorage = true;
    final saved = PageStorage.maybeOf(context)
        ?.readState(context, identifier: _storageKey);
    if (saved is bool) {
      _expanded = saved;
    }
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    PageStorage.maybeOf(context)
        ?.writeState(context, _expanded, identifier: _storageKey);
    HapticFeedback.selectionClick();
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).copied),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openDetailSheet(SwarmPostSummary summary) {
    showSwarmPostDetailSheet(context, summary, onFileTap: widget.onFileTap);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final summary = parseSwarmPostSummary(widget.input);
    final seq = widget.input['seq'];
    final accent = summary.accent(context);

    return Padding(
      key: ValueKey('swarm_post_$seq'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bubbleMarginH,
        vertical: 2,
      ),
      child: Material(
        color: accent.withValues(alpha: _expanded ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                key: ValueKey('swarm_post_toggle_$seq'),
                onTap: _toggleExpanded,
                onLongPress: () => _copyText(summary.fullText),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 6, 6, _expanded ? 4 : 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SwarmPostHeader(
                        summary: summary,
                        seq: seq,
                        accent: accent,
                        expanded: _expanded,
                        onCopy: () => _copyText(summary.fullText),
                        onOpenDetail: () => _openDetailSheet(summary),
                      ),
                      if (!_expanded && summary.previewText.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            summary.previewText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: cs.onSurface.withValues(alpha: 0.84),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_expanded) ...[
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: accent.withValues(alpha: 0.2),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: _SwarmPostMarkdownBody(
                    text: summary.fullText,
                    onFileTap: widget.onFileTap,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SwarmPostHeader extends StatelessWidget {
  final SwarmPostSummary summary;
  final Object? seq;
  final Color accent;
  final bool expanded;
  final VoidCallback onCopy;
  final VoidCallback onOpenDetail;

  const _SwarmPostHeader({
    required this.summary,
    required this.seq,
    required this.accent,
    required this.expanded,
    required this.onCopy,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Row(
      children: [
        SwarmMemberIcon(
          key: ValueKey('swarm_post_icon_$seq'),
          isCoordinator: summary.isCoordinator,
          index: summary.agentIndex,
          size: summary.isCoordinator ? 14 : 16,
          color: accent,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  summary.agent,
                  key: ValueKey('swarm_post_agent_$seq'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (summary.targetMention != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: swarmTargetChipDecoration(
                    context,
                    summary,
                    radius: 4,
                    plainColor: cs.surfaceContainerHighest.withValues(
                      alpha: 0.7,
                    ),
                  ),
                  child: Text(
                    '→ ${summary.targetMention}',
                    key: ValueKey('swarm_post_target_$seq'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color:
                          summary.targetAccent(context) ?? cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (summary.seqLabel != null) ...[
                const SizedBox(width: 5),
                Text(
                  summary.seqLabel!,
                  style: TextStyle(fontSize: 11, color: appColors.subtleText),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (summary.timeLabel != null) ...[
          Text(
            summary.timeLabel!,
            style: TextStyle(
              fontSize: 10.5,
              color: appColors.subtleText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 2),
        ],
        if (expanded) ...[
          _HeaderIconButton(
            key: ValueKey('swarm_post_copy_button_$seq'),
            icon: Icons.copy_outlined,
            tooltip: l.copy,
            color: appColors.subtleText,
            onPressed: onCopy,
          ),
          _HeaderIconButton(
            key: ValueKey('swarm_post_sheet_button_$seq'),
            icon: Icons.open_in_full,
            tooltip: l.guardianApprovalDetails,
            color: appColors.subtleText,
            onPressed: onOpenDetail,
          ),
        ],
        Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          size: 16,
          color: appColors.subtleText,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 14),
      color: color,
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 26, height: 24),
    );
  }
}

class _SwarmPostMarkdownBody extends StatelessWidget {
  final String text;
  final FilePathTapCallback? onFileTap;

  const _SwarmPostMarkdownBody({required this.text, this.onFileTap});

  @override
  Widget build(BuildContext context) {
    final fileListCubit = onFileTap != null
        ? context.read<FileListCubit?>()
        : null;
    final fileSuffixes = fileListCubit != null
        ? FilePathSyntax.cachedSuffixSet(fileListCubit.state)
        : const <String>{};
    return GoogleSearchSelectionArea(
      child: LinkHoverUnderline(
        child: MarkdownBody(
          data: text,
          selectable: false,
          styleSheet: buildMarkdownStyle(context),
          onTapLink: buildChatMarkdownLinkHandler(
            context,
            onFileTap: onFileTap,
            knownPathSuffixes: fileSuffixes,
          ),
          inlineSyntaxes: [
            if (onFileTap != null) ...[
              FilePathSyntax(knownPathSuffixes: fileSuffixes),
              BareFilePathSyntax(knownPathSuffixes: fileSuffixes),
            ],
            ...colorCodeInlineSyntaxes,
            ...localhostAutolinkInlineSyntaxes,
          ],
          builders: {
            if (onFileTap != null)
              'filePath': FilePathBuilder(onTap: onFileTap),
            ...markdownBuilders,
          },
        ),
      ),
    );
  }
}

/// Shows a full-height bottom sheet with the complete swarm board post.
Future<void> showSwarmPostDetailSheet(
  BuildContext context,
  SwarmPostSummary summary, {
  FilePathTapCallback? onFileTap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: macOSModalBottomSheetConstraints(context),
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) =>
        _SwarmPostDetailSheet(summary: summary, onFileTap: onFileTap),
  );
}

class _SwarmPostDetailSheet extends StatelessWidget {
  final SwarmPostSummary summary;
  final FilePathTapCallback? onFileTap;

  const _SwarmPostDetailSheet({required this.summary, this.onFileTap});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final accent = summary.accent(context);

    return ConstrainedBox(
      key: const ValueKey('swarm_post_detail_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: appColors.subtleText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                SwarmMemberIcon(
                  isCoordinator: summary.isCoordinator,
                  index: summary.agentIndex,
                  size: summary.isCoordinator ? 18 : 20,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        summary.agent,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      if (summary.targetMention != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: swarmTargetChipDecoration(
                            context,
                            summary,
                            radius: 6,
                            plainColor: cs.surfaceContainerHighest,
                          ),
                          child: Text(
                            '→ ${summary.targetMention}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  summary.targetAccent(context) ??
                                  cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (summary.seqLabel != null)
                        Text(
                          summary.seqLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            color: appColors.subtleText,
                          ),
                        ),
                      if (summary.timeLabel != null)
                        Text(
                          summary.timeLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            color: appColors.subtleText,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('swarm_post_detail_copy_button'),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  tooltip: l.copy,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: summary.fullText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l.copied),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _SwarmPostMarkdownBody(
                text: summary.fullText,
                onFileTap: onFileTap,
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
