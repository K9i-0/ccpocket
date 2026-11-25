import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

/// Gemini-style action bar shown below assistant messages.
class MessageActionBar extends StatefulWidget {
  final String textToCopy;
  final bool isPlainTextMode;
  final VoidCallback? onTogglePlainText;
  final VoidCallback? onFork;

  const MessageActionBar({
    super.key,
    required this.textToCopy,
    this.isPlainTextMode = false,
    this.onTogglePlainText,
    this.onFork,
  });

  @override
  State<MessageActionBar> createState() => _MessageActionBarState();
}

class _MessageActionBarState extends State<MessageActionBar> {
  Timer? _copiedResetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.textToCopy));
    HapticFeedback.lightImpact();
    _copiedResetTimer?.cancel();
    setState(() => _copied = true);
    _copiedResetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).copied),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.bubbleMarginH,
        right: AppSpacing.bubbleMarginH,
        top: 2,
        bottom: 4,
      ),
      child: Row(
        children: [
          Tooltip(
            message: _copied ? l.copied : l.copyMessage,
            child: _ActionIcon(
              key: const ValueKey('copy_button'),
              icon: _copied ? Icons.check : Icons.content_copy,
              size: 18,
              color: _copied ? primaryColor : appColors.subtleText,
              onTap: _handleCopy,
            ),
          ),
          const SizedBox(width: 16),
          Tooltip(
            message: widget.isPlainTextMode ? 'Markdown' : 'Plain text',
            child: _ActionIcon(
              key: const ValueKey('plain_text_toggle'),
              icon: Icons.text_fields,
              size: 18,
              color: widget.isPlainTextMode
                  ? primaryColor
                  : appColors.subtleText,
              onTap: widget.onTogglePlainText,
            ),
          ),
          const SizedBox(width: 16),
          Tooltip(
            message: l.share,
            child: _ActionIcon(
              key: const ValueKey('share_button'),
              icon: Icons.share,
              size: 18,
              color: appColors.subtleText,
              onTap: () {
                SharePlus.instance.share(ShareParams(text: widget.textToCopy));
              },
            ),
          ),
          if (widget.onFork != null) ...[
            const SizedBox(width: 16),
            Tooltip(
              message: l.forkConversation,
              child: _ActionIcon(
                key: const ValueKey('fork_button'),
                icon: Icons.call_split,
                size: 18,
                color: appColors.subtleText,
                onTap: widget.onFork,
              ),
            ),
          ],
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
