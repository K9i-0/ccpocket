import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

class PermissionRequestBubble extends StatefulWidget {
  final PermissionRequestMessage message;
  const PermissionRequestBubble({super.key, required this.message});

  @override
  State<PermissionRequestBubble> createState() =>
      _PermissionRequestBubbleState();
}

class _PermissionRequestBubbleState extends State<PermissionRequestBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final inputStr = const JsonEncoder.withIndent(
      '  ',
    ).convert(widget.message.input);
    final preview = inputStr.length > 200
        ? '${inputStr.substring(0, 200)}...'
        : inputStr;
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
                    widget.message.toolName,
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
            _expanded ? inputStr : preview,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: appColors.subtleText,
            ),
          ),
        ],
      ),
    );
  }
}
