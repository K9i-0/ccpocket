import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../theme/app_spacing.dart';
import '../../theme/markdown_style.dart';

/// A visually distinct card for rendering implementation plans inline in chat.
///
/// Shows a preview of the plan text with a header and optional "View Full Plan"
/// button when the content exceeds [_maxPreviewHeight].
class PlanCard extends StatelessWidget {
  final String planText;
  final VoidCallback onViewFullPlan;
  final bool isEdited;

  /// Lines threshold below which the full plan is shown without a button.
  static const int _shortPlanLineThreshold = 10;

  /// Max height for the preview area before fade-out is applied.
  static const double _maxPreviewHeight = 200;

  const PlanCard({
    super.key,
    required this.planText,
    required this.onViewFullPlan,
    this.isEdited = false,
  });

  bool get _isLongPlan => planText.split('\n').length > _shortPlanLineThreshold;

  int get _sectionCount {
    return RegExp(r'^#{1,3}\s', multiLine: true).allMatches(planText).length;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _isLongPlan ? onViewFullPlan : null,
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
            _buildHeader(cs),
            Divider(height: 1, color: cs.primary.withValues(alpha: 0.15)),
            _buildBody(context, cs),
            if (_isLongPlan) _buildFooter(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.assignment, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            'Implementation Plan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          const Spacer(),
          if (isEdited)
            Container(
              key: const ValueKey('plan_edited_badge'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: cs.tertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Edited',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: cs.tertiary,
                ),
              ),
            ),
          if (_sectionCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_sectionCount sections',
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

  Widget _buildBody(BuildContext context, ColorScheme cs) {
    final markdownWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: MarkdownBody(
        data: planText,
        selectable: true,
        styleSheet: buildMarkdownStyle(context),
        onTapLink: handleMarkdownLink,
      ),
    );

    if (!_isLongPlan) return markdownWidget;

    return ClipRect(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxPreviewHeight),
        child: ShaderMask(
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
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: markdownWidget,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ColorScheme cs) {
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
