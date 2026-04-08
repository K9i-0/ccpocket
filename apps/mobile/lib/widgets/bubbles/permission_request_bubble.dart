import 'package:flutter/material.dart';

import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

class PermissionRequestBubble extends StatefulWidget {
  final PermissionRequestMessage message;
  final bool isCodex;
  const PermissionRequestBubble({
    super.key,
    required this.message,
    this.isCodex = false,
  });

  @override
  State<PermissionRequestBubble> createState() =>
      _PermissionRequestBubbleState();
}

class _PermissionRequestBubbleState extends State<PermissionRequestBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final presentation = widget.message.presentation;
    final detailLines = _visiblePermissionDetailLines(
      presentation.secondaryDetails,
      isCodex: widget.isCodex,
    );
    final inputStr = presentation.rawDetails;
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.bubbleMarginV,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: appColors.permissionBubble,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: appColors.permissionBubbleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(Icons.security, size: 16, color: appColors.permissionIcon),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    presentation.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: appColors.subtleText,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            presentation.summary,
            style: TextStyle(fontSize: 12, color: appColors.subtleText),
          ),
          if (presentation.primaryTarget != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: appColors.permissionBubble.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: appColors.permissionBubbleBorder.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              child: Text(
                presentation.primaryTarget!,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: appColors.subtleText,
                ),
              ),
            ),
          ],
          if (detailLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final line in detailLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5, right: 6),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: appColors.subtleText,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: 11,
                          color: appColors.subtleText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (_expanded) ...[
            const SizedBox(height: 8),
            Text(
              inputStr,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: appColors.subtleText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

List<String> _visiblePermissionDetailLines(
  List<String> detailLines, {
  required bool isCodex,
}) {
  if (!isCodex) return detailLines;
  return detailLines.where((line) => !line.startsWith('Why:')).toList();
}
