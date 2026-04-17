import 'package:flutter/material.dart';

import '../../models/messages.dart';
import '../../theme/app_theme.dart';

/// A gentle, non-intrusive chip for informational tips (e.g. "no git detected").
///
/// Visually similar to [SystemChip] but with an info icon. Designed to inform
/// without alarming — softer than [ErrorBubble]'s warning style.
class TipChip extends StatelessWidget {
  final SystemMessage message;
  const TipChip({super.key, required this.message});

  String get _text => switch (message.tipCode) {
    'git_not_available' => 'Git未検出 — Diff・ファイル一覧は利用できません',
    'auto_mode_fallback_default' => 'Auto mode はこの環境で使えないため Default に切り替えました',
    _ => message.subtype,
  };

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 14, color: appColors.subtleText),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _text,
                style: TextStyle(fontSize: 12, color: appColors.subtleText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
