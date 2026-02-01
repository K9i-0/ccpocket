import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'app_theme.dart';

MarkdownStyleSheet buildMarkdownStyle(BuildContext context) {
  final appColors = Theme.of(context).extension<AppColors>()!;
  final theme = Theme.of(context);
  final baseStyle = theme.textTheme.bodyMedium ?? const TextStyle();

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: baseStyle,
    code: baseStyle.copyWith(
      fontFamily: 'monospace',
      fontSize: 13,
      backgroundColor: appColors.codeBackground,
    ),
    codeblockDecoration: BoxDecoration(
      color: appColors.codeBackground,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: appColors.codeBorder),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: appColors.subtleText, width: 3),
      ),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
    listBullet: baseStyle.copyWith(fontSize: 14),
  );
}
