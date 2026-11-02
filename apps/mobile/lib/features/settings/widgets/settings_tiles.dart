import 'package:flutter/material.dart';

/// Small uppercase label shown above a [SettingsGroup].
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A card that stacks settings rows and inserts dividers between them.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.cardKey});

  final List<Widget> children;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: cardKey,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: cs.outlineVariant,
              ),
            child,
          ],
        ],
      ),
    );
  }
}
