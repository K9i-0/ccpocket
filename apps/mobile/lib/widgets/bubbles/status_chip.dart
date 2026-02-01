import 'package:flutter/material.dart';

import '../../models/messages.dart';

class StatusChip extends StatelessWidget {
  final StatusMessage message;
  const StatusChip({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // Don't render individual status messages as they're shown in the AppBar
    return const SizedBox.shrink();
  }
}
