import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../models/messages.dart';

/// Claude badge accent in light mode (deep Ember tuned for WCAG AA contrast on
/// tinted light badges while staying cohesive with `colorScheme.primary`).
const claudeAccentLight = Color(0xFFB83B08);

/// Codex accent (Emerald 700 / Emerald 400) — refined pine-emerald dedicated to
/// Codex, distinct from Claude's ember orange, Antigravity's blue, and neutral
/// tool/status tokens.
const codexAccentLight = Color(0xFF047857);
const codexAccentDark = Color(0xFF34D399);

/// Antigravity accent (Blue 600 / Blue 400), next to Claude's ember and
/// Codex's emerald.
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
  final isDark = colorScheme.brightness == Brightness.dark;
  final accent = switch (provider) {
    Provider.claude => isDark ? colorScheme.primary : claudeAccentLight,
    Provider.codex => isDark ? codexAccentDark : codexAccentLight,
    // Its own blue: the theme's tertiary is an amber too close to Claude.
    Provider.antigravity =>
      isDark ? antigravityAccentDark : antigravityAccentLight,
  };

  // Tune badge tint and border per brightness (and hue where needed) so all
  // three providers share balanced perceived weight and WCAG AA text contrast
  // (>= 4.5:1) on both light and dark surfaces.
  final (bgAlpha, borderAlpha) = switch ((isDark, provider)) {
    (true, Provider.codex) => (0.14, 0.28),
    (true, _) => (0.15, 0.30),
    (false, Provider.antigravity) => (0.08, 0.24),
    (false, _) => (0.09, 0.24),
  };

  return ProviderStyle(
    foreground: accent,
    background: accent.withValues(alpha: bgAlpha),
    border: accent.withValues(alpha: borderAlpha),
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
