import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class SessionReconnectBanner extends StatelessWidget {
  const SessionReconnectBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: appColors.approvalBar,
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: appColors.statusApproval,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Reconnecting...',
            style: TextStyle(fontSize: 13, color: appColors.statusApproval),
          ),
        ],
      ),
    );
  }
}
