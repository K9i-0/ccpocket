import 'package:flutter/material.dart';

import '../models/messages.dart';

/// Visual tokens for rendering provider-specific labels and badges.
class ProviderStyle {
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;

  const ProviderStyle({
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });
}

ProviderStyle providerStyleFor(BuildContext context, Provider provider) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  // Vibrant brand colors decoupled from the monochrome base theme.
  final brandColor = switch (provider) {
    Provider.claude =>
      isDark
          ? const Color(0xFFA78BFA)
          : const Color(0xFF7C3AED), // Violet 400 / Violet 600
    Provider.codex =>
      isDark
          ? const Color(0xFFFB923C)
          : const Color(0xFFEA580C), // Orange 400 / Orange 600
  };

  return ProviderStyle(
    foreground: brandColor,
    background: brandColor.withValues(alpha: 0.12),
    border: brandColor.withValues(alpha: 0.34),
    icon: switch (provider) {
      Provider.claude => Icons.smart_toy_outlined,
      Provider.codex => Icons.code,
    },
  );
}

Provider providerFromRaw(String? provider) =>
    provider == Provider.codex.value ? Provider.codex : Provider.claude;
