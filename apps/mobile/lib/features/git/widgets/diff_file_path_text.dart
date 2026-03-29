import 'package:flutter/material.dart';

/// Scrollable file path text widget used in diff file headers and filter sheets.
///
/// - Short paths: left-aligned (no scroll needed).
/// - Long paths: horizontally scrollable with `reverse: true` so the
///   file name (tail) is visible by default.
class DiffFilePathText extends StatelessWidget {
  final String filePath;
  final TextStyle style;

  const DiffFilePathText({
    super.key,
    required this.filePath,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: filePath, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final fitsInLine = tp.width <= constraints.maxWidth;

        if (fitsInLine) {
          return Text(filePath, style: style);
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Text(filePath, style: style),
        );
      },
    );
  }
}
