import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

class UserBubble extends StatelessWidget {
  final String text;
  const UserBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(
            vertical: AppSpacing.bubbleMarginV,
            horizontal: AppSpacing.bubbleMarginH,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.bubblePaddingV,
            horizontal: AppSpacing.bubblePaddingH,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width *
                AppSpacing.maxBubbleWidthFraction,
          ),
          decoration: BoxDecoration(
            color: appColors.userBubble,
            borderRadius: AppSpacing.userBubbleBorderRadius,
          ),
          child: Text(
            text,
            style: TextStyle(color: appColors.userBubbleText),
          ),
        ),
      ),
    );
  }
}
