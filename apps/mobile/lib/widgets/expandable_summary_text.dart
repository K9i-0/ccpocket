import 'package:flutter/material.dart';

/// A text widget that truncates to [maxLines] with a "more" link
/// positioned inline at the bottom-right, maximising visible text.
///
/// Tap "more" to expand; tap "less" to collapse.
class ExpandableSummaryText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;

  /// Background color for the gradient fade behind "more".
  /// When null, the scaffold/surface color is used automatically.
  final Color? backgroundColor;

  const ExpandableSummaryText({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 2,
    this.backgroundColor,
  });

  @override
  State<ExpandableSummaryText> createState() => _ExpandableSummaryTextState();
}

class _ExpandableSummaryTextState extends State<ExpandableSummaryText> {
  bool _expanded = false;
  bool _hasOverflow = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final linkColor = Theme.of(context).colorScheme.primary;
    final linkStyle = style.copyWith(
      color: linkColor,
      fontWeight: FontWeight.w600,
    );

    // Resolve the effective background color from ancestors for the
    // gradient fade behind the "more" label.
    final bgColor = widget.backgroundColor ?? _resolveBackgroundColor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure whether the text overflows at maxLines.
        final textSpan = TextSpan(text: widget.text, style: style);
        final tp = TextPainter(
          text: textSpan,
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final overflows = tp.didExceedMaxLines;

        // Schedule state update if overflow status changed.
        if (overflows != _hasOverflow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hasOverflow = overflows);
          });
        }

        // --- Short text: no toggle needed ---
        if (!overflows && !_expanded) {
          return Text(widget.text, style: style);
        }

        // --- Expanded: full text + "less" ---
        if (_expanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.text, style: style),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = false),
                  child: Text('less', style: linkStyle),
                ),
              ),
            ],
          );
        }

        // --- Collapsed with overflow: text + inline "more" at bottom-right ---
        return Stack(
          children: [
            // Main text clipped to maxLines (no ellipsis — the gradient
            // and "more" label handle the visual truncation cue).
            Text(
              widget.text,
              style: style,
              maxLines: widget.maxLines,
              overflow: TextOverflow.clip,
            ),
            // "more" label with gradient fade, pinned bottom-right.
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [bgColor.withValues(alpha: 0), bgColor, bgColor],
                      stops: const [0.0, 0.3, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 32),
                  child: Text('more', style: linkStyle),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Walk up the widget tree to find the nearest opaque background color.
  Color _resolveBackgroundColor(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null) {
      final bg = Theme.of(context).scaffoldBackgroundColor;
      if (bg.a > 0) return bg;
    }
    return Theme.of(context).colorScheme.surface;
  }
}
