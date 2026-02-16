import 'package:flutter/material.dart';

import 'guide_page.dart';

/// Page 1: CC Pocketとは
class GuidePageAbout extends StatelessWidget {
  const GuidePageAbout({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bodyStyle = Theme.of(context).textTheme.bodyLarge;

    return GuidePage(
      icon: Icons.smartphone,
      title: 'CC Pocket とは',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'スマートフォンから Claude Code や Codex を操作できるモバイルクライアントです。',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          // Architecture diagram
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'しくみ',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _ArchDiagramRow(
                  items: const [
                    'iPhone',
                    'Bridge Server',
                    'Claude CLI\n/ Codex',
                  ],
                  colorScheme: cs,
                ),
                const SizedBox(height: 12),
                Text(
                  'PC で Bridge Server を起動し、\nスマホから接続して使います。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchDiagramRow extends StatelessWidget {
  final List<String> items;
  final ColorScheme colorScheme;

  const _ArchDiagramRow({required this.items, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                items[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
