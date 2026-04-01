import 'package:flutter/material.dart';

enum GitSwipeActionTone { primary, neutral, danger }

class GitSwipeActionBackground extends StatelessWidget {
  final Alignment alignment;
  final EdgeInsetsGeometry padding;
  final IconData icon;
  final String label;
  final GitSwipeActionTone tone;

  const GitSwipeActionBackground({
    super.key,
    required this.alignment,
    required this.padding,
    required this.icon,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = _styleFor(cs);

    return Container(
      color: style.backdropColor,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: padding,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: style.fillColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: style.borderColor, width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: style.foregroundColor),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: style.foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _GitSwipeActionStyle _styleFor(ColorScheme cs) {
    return switch (tone) {
      GitSwipeActionTone.primary => _GitSwipeActionStyle(
        backdropColor: cs.primary.withValues(alpha: 0.12),
        fillColor: cs.primary,
        borderColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      GitSwipeActionTone.neutral => _GitSwipeActionStyle(
        backdropColor: cs.tertiary.withValues(alpha: 0.12),
        fillColor: cs.surface,
        borderColor: cs.tertiary.withValues(alpha: 0.7),
        foregroundColor: cs.tertiary,
      ),
      GitSwipeActionTone.danger => _GitSwipeActionStyle(
        backdropColor: cs.error.withValues(alpha: 0.12),
        fillColor: cs.surface,
        borderColor: cs.error.withValues(alpha: 0.75),
        foregroundColor: cs.error,
      ),
    };
  }
}

class _GitSwipeActionStyle {
  final Color backdropColor;
  final Color fillColor;
  final Color borderColor;
  final Color foregroundColor;

  const _GitSwipeActionStyle({
    required this.backdropColor,
    required this.fillColor,
    required this.borderColor,
    required this.foregroundColor,
  });
}
