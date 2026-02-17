import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

/// Gemini-style action bar shown below assistant messages.
class MessageActionBar extends StatelessWidget {
  final String textToCopy;
  final bool isPlainTextMode;
  final VoidCallback? onTogglePlainText;

  const MessageActionBar({
    super.key,
    required this.textToCopy,
    this.isPlainTextMode = false,
    this.onTogglePlainText,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.bubbleMarginH,
        right: AppSpacing.bubbleMarginH,
        top: 2,
        bottom: 4,
      ),
      child: Row(
        children: [
          _ActionIcon(
            key: const ValueKey('copy_button'),
            icon: Icons.content_copy,
            size: 18,
            color: appColors.subtleText,
            onTap: () {
              Clipboard.setData(ClipboardData(text: textToCopy));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).copied),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          _ActionIcon(
            key: const ValueKey('plain_text_toggle'),
            icon: Icons.text_fields,
            size: 18,
            color: isPlainTextMode ? primaryColor : appColors.subtleText,
            onTap: onTogglePlainText,
          ),
          const SizedBox(width: 16),
          _ActionIcon(
            key: const ValueKey('share_button'),
            icon: Icons.share,
            size: 18,
            color: appColors.subtleText,
            onTap: () {
              SharePlus.instance.share(ShareParams(text: textToCopy));
            },
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onTap;

  const _ActionIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}
