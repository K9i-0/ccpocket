import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'guide_page.dart';

/// Page 4: 外出先からの接続 (Tailscale)
class GuidePageTailscale extends StatelessWidget {
  const GuidePageTailscale({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bodyStyle = Theme.of(context).textTheme.bodyLarge;

    return GuidePage(
      icon: Icons.vpn_lock,
      title: '外出先からの接続',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '自宅の外からも使いたい場合は、Tailscale（VPN の一種）を使えば安全にリモート接続できます。',
            style: bodyStyle,
          ),
          const SizedBox(height: 20),
          // Steps
          _TailscaleStep(
            colorScheme: cs,
            number: '1',
            text: 'Mac と iPhone の両方に Tailscale をインストール',
          ),
          const SizedBox(height: 12),
          _TailscaleStep(colorScheme: cs, number: '2', text: '同じアカウントでログイン'),
          const SizedBox(height: 12),
          _TailscaleStep(
            colorScheme: cs,
            number: '3',
            text: 'Bridge URL に Tailscale IP を使用\n(例: ws://100.x.x.x:8765)',
          ),
          const SizedBox(height: 24),
          // Link to Tailscale
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://tailscale.com/'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Tailscale 公式サイト'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '詳しいセットアップ方法は公式サイトをご覧ください。',
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

class _TailscaleStep extends StatelessWidget {
  final ColorScheme colorScheme;
  final String number;
  final String text;

  const _TailscaleStep({
    required this.colorScheme,
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text, style: const TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }
}
