import 'package:material_ui/material_ui.dart';

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
  final colorScheme = Theme.of(context).colorScheme;
  final accent = switch (provider) {
    Provider.claude => colorScheme.primary,
    Provider.codex => colorScheme.secondary,
    Provider.antigravity => colorScheme.tertiary,
  };

  return ProviderStyle(
    foreground: accent,
    background: accent.withValues(alpha: 0.12),
    border: accent.withValues(alpha: 0.34),
    icon: switch (provider) {
      Provider.claude => Icons.smart_toy_outlined,
      Provider.codex => Icons.code,
      Provider.antigravity => Icons.rocket_launch_outlined,
    },
  );
}

/// Provider of a wire-format value. Missing or unknown values are Claude,
/// which is what Bridges sent before the `provider` field existed.
Provider providerFromRaw(String? provider) =>
    Provider.fromValue(provider) ?? Provider.claude;
