import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import 'status_line.dart';

/// Isolates [MediaQuery.paddingOf] so only this widget rebuilds when system
/// insets change (e.g. Android notification shade).
class StatusLineFlexibleSpace extends StatelessWidget {
  const StatusLineFlexibleSpace({
    super.key,
    required this.status,
    required this.inPlanMode,
  });

  final ProcessStatus status;
  final bool inPlanMode;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.paddingOf(context).top,
          child: StatusLine(status: status, inPlanMode: inPlanMode),
        ),
      ],
    );
  }
}
