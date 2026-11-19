import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../models/messages.dart';

/// Antigravity accent (Blue 600 / Blue 400), next to Claude's orange and
/// Codex's teal.
const antigravityAccentLight = Color(0xFF2563EB);
const antigravityAccentDark = Color(0xFF60A5FA);

/// Asset path of the monochrome SVG mark for [provider].
String providerIconAsset(Provider provider) => switch (provider) {
  Provider.claude => 'assets/icons/provider_claude.svg',
  Provider.codex => 'assets/icons/provider_codex.svg',
  Provider.antigravity => 'assets/icons/provider_antigravity.svg',
};

/// Visual tokens for rendering provider-specific labels and badges.
class ProviderStyle {
  final Color foreground;
  final Color background;
  final Color border;
  final String iconAsset;

  const ProviderStyle({
    required this.foreground,
    required this.background,
    required this.border,
    required this.iconAsset,
  });
}

ProviderStyle providerStyleFor(BuildContext context, Provider provider) {
  final colorScheme = Theme.of(context).colorScheme;
  final accent = switch (provider) {
    Provider.claude => colorScheme.primary,
    Provider.codex => colorScheme.secondary,
    // Its own blue: the theme's tertiary is an amber too close to Claude.
    Provider.antigravity =>
      colorScheme.brightness == Brightness.dark
          ? antigravityAccentDark
          : antigravityAccentLight,
  };

  return ProviderStyle(
    foreground: accent,
    background: accent.withValues(alpha: 0.12),
    border: accent.withValues(alpha: 0.34),
    iconAsset: providerIconAsset(provider),
  );
}

/// Monochrome provider mark, tinted like an [Icon] by the surrounding
/// [IconTheme].
class ProviderIcon extends StatelessWidget {
  final Provider provider;
  final double? size;
  final Color? color;

  const ProviderIcon(this.provider, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = this.size ?? iconTheme.size ?? 24;
    final color =
        this.color ??
        iconTheme.color ??
        Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      providerIconAsset(provider),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

/// Provider of a wire-format value. Missing or unknown values are Claude,
/// which is what Bridges sent before the `provider` field existed.
Provider providerFromRaw(String? provider) =>
    Provider.fromValue(provider) ?? Provider.claude;
