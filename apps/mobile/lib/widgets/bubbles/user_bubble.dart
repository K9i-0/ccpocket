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
      return _buildCommandBubble(context, parsed);
    }

    final appColors = Theme.of(context).extension<AppColors>()!;
    return _buildStandardBubble(context, appColors, text);
  }

  /// Standard user message bubble.
  Widget _buildStandardBubble(
    BuildContext context,
    AppColors appColors,
    String displayText,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () {
          _showContextMenu(context);
        },
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
              child: _buildStatusIndicator(context, appColors),
            ),
          ],
        ),
      ),
    );
  }

  /// CLI-style command bubble: "/command-name args" in a single bubble.
  Widget _buildCommandBubble(BuildContext context, ParsedCommand command) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final hasArgs = command.args != null && command.args!.isNotEmpty;

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () {
          _showContextMenu(context);
        },
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
              child: _buildStatusIndicator(context, appColors),
            ),
          ],
        ),
      ),
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

  Widget _buildStatusIndicator(BuildContext context, AppColors appColors) {
    return switch (status) {
      MessageStatus.sending => SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: appColors.subtleText,
        ),
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
