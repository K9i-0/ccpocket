import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../utils/command_parser.dart';

class UserBubble extends StatelessWidget {
  final String text;
  final MessageStatus status;
  final VoidCallback? onRetry;
  final VoidCallback? onRewind;
  final List<String> imageUrls;
  final String? httpBaseUrl;
  final List<Uint8List> imageBytesList;

  /// Number of images attached (from history restoration when actual data is unavailable).
  final int imageCount;

  const UserBubble({
    super.key,
    required this.text,
    this.status = MessageStatus.sent,
    this.onRetry,
    this.onRewind,
    this.imageUrls = const [],
    this.httpBaseUrl,
    this.imageBytesList = const [],
    this.imageCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Detect command message with XML tags
    final parsed = parseCommandMessage(text);
    if (parsed != null) {
      return _CommandBubble(
        command: parsed,
        status: status,
        text: text,
        onRetry: onRetry,
        onRewind: onRewind,
        onShowContextMenu: () => _showContextMenu(context),
      );
    }

    return _StandardBubble(
      displayText: text,
      status: status,
      onRetry: onRetry,
      onRewind: onRewind,
      imageBytesList: imageBytesList,
      imageUrls: imageUrls,
      httpBaseUrl: httpBaseUrl,
      onShowContextMenu: () => _showContextMenu(context),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.copy, size: 20),
                title: Text(AppLocalizations.of(context).copy),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context).copied),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              if (onRewind != null)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.history,
                    size: 20,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                  title: Text(AppLocalizations.of(context).rewindToHere),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onRewind!();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard user message bubble.
class _StandardBubble extends StatelessWidget {
  final String displayText;
  final MessageStatus status;
  final VoidCallback? onRetry;
  final VoidCallback? onRewind;
  final List<Uint8List> imageBytesList;
  final List<String> imageUrls;
  final String? httpBaseUrl;
  final VoidCallback onShowContextMenu;

  const _StandardBubble({
    required this.displayText,
    required this.status,
    required this.onRetry,
    required this.onRewind,
    required this.imageBytesList,
    required this.imageUrls,
    required this.httpBaseUrl,
    required this.onShowContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: onShowContextMenu,
        onTap: status == MessageStatus.failed ? onRetry : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(
                vertical: AppSpacing.bubbleMarginV,
                horizontal: AppSpacing.bubbleMarginH,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.bubblePaddingV,
                horizontal: AppSpacing.bubblePaddingH,
              ),
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width *
                    AppSpacing.maxBubbleWidthFraction,
              ),
              decoration: BoxDecoration(
                color: appColors.userBubble,
                borderRadius: AppSpacing.userBubbleBorderRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (imageBytesList.isNotEmpty ||
                      (imageUrls.isNotEmpty && httpBaseUrl != null))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final bytes in imageBytesList)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                bytes,
                                width: imageBytesList.length == 1 ? 200 : 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: imageBytesList.length == 1
                                          ? 200
                                          : 120,
                                      height: 80,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image),
                                    ),
                              ),
                            ),
                          if (imageBytesList.isEmpty)
                            for (final url in imageUrls)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  '$httpBaseUrl$url',
                                  width: imageUrls.length == 1 ? 200 : 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: imageUrls.length == 1
                                            ? 200
                                            : 120,
                                        height: 80,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image),
                                      ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  if (displayText.isNotEmpty)
                    Text(
                      displayText,
                      style: TextStyle(color: appColors.userBubbleText),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.bubbleMarginH),
              child: _StatusIndicator(status: status),
            ),
          ],
        ),
      ),
    );
  }
}

/// CLI-style command bubble: "/command-name args" in a single bubble.
class _CommandBubble extends StatelessWidget {
  final ParsedCommand command;
  final MessageStatus status;
  final String text;
  final VoidCallback? onRetry;
  final VoidCallback? onRewind;
  final VoidCallback onShowContextMenu;

  const _CommandBubble({
    required this.command,
    required this.status,
    required this.text,
    required this.onRetry,
    required this.onRewind,
    required this.onShowContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final hasArgs = command.args != null && command.args!.isNotEmpty;

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: onShowContextMenu,
        onTap: status == MessageStatus.failed ? onRetry : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(
                vertical: AppSpacing.bubbleMarginV,
                horizontal: AppSpacing.bubbleMarginH,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.bubblePaddingV,
                horizontal: AppSpacing.bubblePaddingH,
              ),
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width *
                    AppSpacing.maxBubbleWidthFraction,
              ),
              decoration: BoxDecoration(
                color: appColors.userBubble,
                borderRadius: AppSpacing.userBubbleBorderRadius,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: command.commandName,
                      style: TextStyle(
                        color: appColors.userBubbleText,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (hasArgs) ...[
                      TextSpan(
                        text: ' ${command.args}',
                        style: TextStyle(color: appColors.userBubbleText),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.bubbleMarginH),
              child: _StatusIndicator(status: status),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final MessageStatus status;

  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return switch (status) {
      MessageStatus.sending => SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: appColors.subtleText,
        ),
      ),
      MessageStatus.queued => Icon(
        Icons.schedule,
        size: 14,
        color: appColors.subtleText,
      ),
      MessageStatus.sent => Icon(
        Icons.check,
        size: 14,
        color: appColors.subtleText,
      ),
      MessageStatus.failed => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 14,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context).tapToRetry,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    };
  }
}
