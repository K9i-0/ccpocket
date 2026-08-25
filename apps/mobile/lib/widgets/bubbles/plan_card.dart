import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../features/file_peek/file_path_syntax.dart';
import '../../features/file_peek/markdown_link_handler.dart';
import '../../providers/bridge_cubits.dart';
import '../../theme/app_spacing.dart';
import '../../theme/markdown_style.dart';

/// A visually distinct card for rendering implementation plans inline in chat.
///
/// Shows a preview of the plan text with a header and optional "View Full Plan"
/// button when the content exceeds [_maxPreviewHeight].
class PlanCard extends StatefulWidget {
  final String planText;
  final VoidCallback onViewFullPlan;
  final FilePathTapCallback? onFileTap;

  /// Max height for the preview area before fade-out is applied.
  static const double _maxPreviewHeight = 200;

  const PlanCard({
    super.key,
    required this.planText,
    required this.onViewFullPlan,
    this.onFileTap,
  });

  @override
  State<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<PlanCard> {
  bool _isLongPlan = false;

  int get _sectionCount {
    return RegExp(
      r'^#{1,3}\s',
      multiLine: true,
    ).allMatches(widget.planText).length;
  }

  void _handleOverflowChanged(bool isLongPlan) {
    if (_isLongPlan == isLongPlan) return;
    setState(() => _isLongPlan = isLongPlan);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _isLongPlan ? widget.onViewFullPlan : null,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.bubbleMarginV,
          horizontal: AppSpacing.bubbleMarginH,
        ),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlanHeader(sectionCount: _sectionCount),
            Divider(height: 1, color: cs.primary.withValues(alpha: 0.15)),
            _PlanBody(
              planText: widget.planText,
              onOverflowChanged: _handleOverflowChanged,
              onFileTap: widget.onFileTap,
            ),
            if (_isLongPlan) _PlanFooter(onViewFullPlan: widget.onViewFullPlan),
          ],
        ),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final int sectionCount;

  const _PlanHeader({required this.sectionCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.assignment, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Implementation Plan',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (sectionCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$sectionCount sections',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: cs.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanBody extends StatefulWidget {
  final String planText;
  final ValueChanged<bool> onOverflowChanged;
  final FilePathTapCallback? onFileTap;

  const _PlanBody({
    required this.planText,
    required this.onOverflowChanged,
    this.onFileTap,
  });

  @override
  State<_PlanBody> createState() => _PlanBodyState();
}

class _PlanBodyState extends State<_PlanBody> {
  final ScrollController _scrollController = ScrollController();
  bool _checkScheduled = false;
  bool _overflows = false;

  void _scheduleOverflowCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      final overflows = _scrollController.position.maxScrollExtent > 0.5;
      if (_overflows != overflows) {
        setState(() => _overflows = overflows);
      }
      widget.onOverflowChanged(overflows);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileSuffixes = widget.onFileTap != null
        ? FilePathSyntax.cachedSuffixSet(context.watch<FileListCubit>().state)
        : const <String>{};
    final markdownWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: MarkdownBody(
        data: widget.planText,
        selectable: true,
        styleSheet: buildMarkdownStyle(context),
        onTapLink: buildChatMarkdownLinkHandler(
          context,
          onFileTap: widget.onFileTap,
          knownPathSuffixes: fileSuffixes,
        ),
        inlineSyntaxes: [
          if (widget.onFileTap != null) ...[
            FilePathSyntax(knownPathSuffixes: fileSuffixes),
            BareFilePathSyntax(knownPathSuffixes: fileSuffixes),
          ],
          ...colorCodeInlineSyntaxes,
        ],
        builders: {
          if (widget.onFileTap != null)
            'filePath': FilePathBuilder(onTap: widget.onFileTap),
          ...markdownBuilders,
        },
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleOverflowCheck();
        Widget preview = SingleChildScrollView(
          controller: _scrollController,
          physics: const NeverScrollableScrollPhysics(),
          child: markdownWidget,
        );
        if (_overflows) {
          preview = ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.white,
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.7, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: preview,
          );
        }
        return ClipRect(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: PlanCard._maxPreviewHeight,
            ),
            child: preview,
          ),
        );
      },
    );
  }
}

class _PlanFooter extends StatelessWidget {
  final VoidCallback onViewFullPlan;

  const _PlanFooter({required this.onViewFullPlan});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      key: const ValueKey('view_full_plan_button'),
      onTap: onViewFullPlan,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppSpacing.cardRadius),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cs.primary.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.unfold_more, size: 16, color: cs.primary),
            const SizedBox(width: 4),
            Text(
              'View Full Plan',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
