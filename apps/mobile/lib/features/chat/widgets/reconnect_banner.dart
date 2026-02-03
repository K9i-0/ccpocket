import 'package:flutter/material.dart';

import '../../../models/messages.dart';

class ReconnectBanner extends StatelessWidget {
  final BridgeConnectionState bridgeState;
  const ReconnectBanner({super.key, required this.bridgeState});

  @override
  Widget build(BuildContext context) {
    final isReconnecting = bridgeState == BridgeConnectionState.reconnecting;
    final errorColor = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: errorColor.withValues(alpha: 0.12),
      child: Row(
        children: [
          if (isReconnecting)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.cloud_off, size: 16, color: errorColor),
          const SizedBox(width: 8),
          Text(
            isReconnecting ? 'Reconnecting...' : 'Disconnected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: errorColor,
            ),
          ),
        ],
      ),
    );
  }
}
