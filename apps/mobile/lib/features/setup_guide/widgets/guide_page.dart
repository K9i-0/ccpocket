import 'package:flutter/material.dart';

/// 各ガイドページの共通レイアウト。
/// 上部にアイコン、タイトル、本文を配置する。
class GuidePage extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget body;

  const GuidePage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: cs.primary),
          ),
          const SizedBox(height: 24),
          // Title
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Body
          body,
        ],
      ),
    );
  }
}
