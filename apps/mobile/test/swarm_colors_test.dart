import 'dart:io';
import 'dart:math' as math;

import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/theme/swarm_colors.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// CIE L*a*b*, to tell how far apart two colours look.
List<double> _lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final x = f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047);
  final y = f(0.2126 * r + 0.7152 * g + 0.0722 * b);
  final z = f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883);
  return [116 * y - 16, 500 * (x - y), 200 * (y - z)];
}

double _distance(Color a, Color b) {
  final la = _lab(a), lb = _lab(b);
  return math.sqrt(
    [for (var i = 0; i < 3; i++) math.pow(la[i] - lb[i], 2)]
        .reduce((sum, v) => sum + v),
  );
}

void main() {
  for (final (name, theme, palette) in [
    ('light', AppTheme.lightTheme, swarmWorkerColorsLight),
    ('dark', AppTheme.darkTheme, swarmWorkerColorsDark),
  ]) {
    test('$name swarm colours read as text on a tinted card', () {
      final surface = theme.colorScheme.surface;
      for (final color in palette) {
        // An expanded post sits on its own colour at 8% over the surface.
        final card = Color.alphaBlend(color.withValues(alpha: 0.08), surface);
        expect(
          _contrast(color, card),
          greaterThanOrEqualTo(4.5),
          reason: '$color on $card',
        );
      }
    });

    test('$name swarm colours can be told apart, also from reserved ones', () {
      final scheme = theme.colorScheme;
      for (var i = 0; i < palette.length; i++) {
        for (var j = i + 1; j < palette.length; j++) {
          expect(
            _distance(palette[i], palette[j]),
            greaterThanOrEqualTo(25),
            reason: 'colours $i and $j',
          );
        }
        // The coordinator's, warnings' and errors'.
        for (final reserved in [
          scheme.primary,
          scheme.tertiary,
          scheme.error,
        ]) {
          expect(
            _distance(palette[i], reserved),
            greaterThanOrEqualTo(35),
            reason: 'colour $i and $reserved',
          );
        }
      }
    });
  }

  test('both themes have the same number of colours, in the same order', () {
    expect(swarmWorkerColorsDark, hasLength(swarmWorkerColorsLight.length));
    expect(
      swarmWorkerIconColorsLight,
      hasLength(swarmWorkerColorsLight.length),
    );
  });

  test('light swarm icon colours stay vivid yet distinguishable', () {
    final scheme = AppTheme.lightTheme.colorScheme;
    final surface = scheme.surface;
    for (var i = 0; i < swarmWorkerIconColorsLight.length; i++) {
      final color = swarmWorkerIconColorsLight[i];
      final card = Color.alphaBlend(color.withValues(alpha: 0.08), surface);
      // WCAG 2.1 non-text graphic contrast (>= 3.0).
      expect(
        _contrast(color, card),
        greaterThanOrEqualTo(3.0),
        reason: 'light icon $i ($color) on $card',
      );
      for (var j = i + 1; j < swarmWorkerIconColorsLight.length; j++) {
        expect(
          _distance(color, swarmWorkerIconColorsLight[j]),
          greaterThanOrEqualTo(25),
          reason: 'light icon colours $i and $j',
        );
      }
      for (final reserved in [scheme.primary, scheme.tertiary, scheme.error]) {
        expect(
          _distance(color, reserved),
          greaterThanOrEqualTo(35),
          reason: 'light icon colour $i and $reserved',
        );
      }
    }
    expect(
      swarmWorkerIconColor(Brightness.light, 0),
      swarmWorkerIconColorsLight[0],
    );
    expect(swarmWorkerIconColor(Brightness.dark, 0), swarmWorkerColorsDark[0]);
  });

  test('workers take colours in order and repeat past the palette', () {
    final n = swarmWorkerColorsDark.length;
    expect(swarmWorkerColor(Brightness.dark, 0), swarmWorkerColorsDark[0]);
    expect(swarmWorkerColor(Brightness.light, 1), swarmWorkerColorsLight[1]);
    expect(swarmWorkerColor(Brightness.dark, n + 2), swarmWorkerColorsDark[2]);
  });

  test('each palette slot has a unique creature SVG asset that exists', () {
    final n = swarmWorkerColorsDark.length;
    expect(swarmWorkerIconAssets, hasLength(n));
    expect(swarmWorkerIconAssets.toSet(), hasLength(n));
    expect(swarmWorkerIconAsset(0), swarmWorkerIconAssets[0]);
    expect(swarmWorkerIconAsset(n + 3), swarmWorkerIconAssets[3]);
    for (final asset in [swarmCoordinatorIconAsset, ...swarmWorkerIconAssets]) {
      expect(
        File(asset).existsSync(),
        isTrue,
        reason: 'missing SVG asset: $asset',
      );
    }
    expect(swarmWorkerIconAssets, isNot(contains(swarmCoordinatorIconAsset)));
  });
}
