import 'package:flutter/material.dart';

/// Reserves a stable video viewport regardless of the number of comments.
class VideoFeedbackLayout extends StatelessWidget {
  final Widget video;
  final Widget feedback;

  const VideoFeedbackLayout({
    super.key,
    required this.video,
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final sideBySide =
          constraints.maxWidth >= 700 &&
          constraints.maxWidth > constraints.maxHeight;
      final panel = ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          key: const ValueKey('video_feedback_panel_scroll'),
          primary: false,
          child: feedback,
        ),
      );
      if (sideBySide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: video),
            SizedBox(
              width: (constraints.maxWidth * .38).clamp(300.0, 420.0),
              child: panel,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 55, child: video),
          Expanded(flex: 45, child: panel),
        ],
      );
    },
  );
}
