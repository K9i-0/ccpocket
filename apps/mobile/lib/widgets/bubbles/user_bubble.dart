import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

/// Pattern to extract a skill name from a skill loading prompt.
/// Matches `Base directory for this skill: .../.claude/skills/{name}`
final _skillPathPattern = RegExp(r'\.claude/skills/([^/\s]+)');

/// Extract the skill name from a meta message, or return null.
String? _extractSkillName(String text) {
  if (!text.startsWith('Base directory for this skill:')) return null;
  final match = _skillPathPattern.firstMatch(text);
  return match?.group(1);
}

class UserBubble extends StatelessWidget {
  final String text;
  final MessageStatus status;
  final bool isMeta;
  final VoidCallback? onRetry;
  final VoidCallback? onRewind;
  final String? imageUrl;
  final String? httpBaseUrl;
  final Uint8List? imageBytes;
  const UserBubble({
    super.key,
    required this.text,
    this.status = MessageStatus.sent,
    this.isMeta = false,
    this.onRetry,
    this.onRewind,
    this.imageUrl,
    this.httpBaseUrl,
    this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    // Detect skill loading prompt
    final skillName = isMeta ? _extractSkillName(text) : null;
    if (skillName != null) {
      return _buildSkillChip(context, skillName);
    }

    final appColors = Theme.of(context).extension<AppColors>()!;
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
                  if (imageBytes != null ||
                      (imageUrl != null && httpBaseUrl != null))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageBytes != null
                            ? Image.memory(
                                imageBytes!,
                                width: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 200,
                                      height: 100,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image),
                                    ),
                              )
                            : Image.network(
                                '$httpBaseUrl$imageUrl',
                                width: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 200,
                                      height: 100,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image),
                                    ),
                              ),
                      ),
                    ),
                  if (text.isNotEmpty)
                    Text(
                      text,
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

  /// Compact chip for skill loading prompts (e.g. "/self-review").
  Widget _buildSkillChip(BuildContext context, String skillName) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 2,
          horizontal: AppSpacing.bubbleMarginH,
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: appColors.userBubble.withAlpha(128),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '/$skillName',
          style: TextStyle(
            color: appColors.userBubbleText.withAlpha(200),
            fontSize: 13,
          ),
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
                title: const Text('Copy'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied'),
                      duration: Duration(seconds: 1),
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
                  title: const Text('Rewind to here'),
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
            'Tap to retry',
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
