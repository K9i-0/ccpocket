import 'package:flutter/material.dart';

import 'guide_page.dart';

/// Page 6: 準備完了
class GuidePageReady extends StatelessWidget {
  final VoidCallback onGetStarted;

  const GuidePageReady({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GuidePage(
      icon: Icons.rocket_launch,
      title: '準備完了!',
      body: Column(
        children: [
          Text(
            'Bridge Server を起動して、\nQR コードをスキャンするところから\n始めましょう。',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onGetStarted,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('さっそく始める'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'このガイドは設定画面からいつでも確認できます',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
