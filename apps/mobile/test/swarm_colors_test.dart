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

    test('$name swarm colours are distinct and none is a reserved one', () {
      final scheme = theme.colorScheme;
      expect(palette.toSet(), hasLength(palette.length));
      for (final reserved in [scheme.primary, scheme.tertiary, scheme.error]) {
        expect(palette, isNot(contains(reserved)));
      }
    });
  }

  test('both themes have the same number of colours, in the same order', () {
    expect(swarmWorkerColorsDark, hasLength(swarmWorkerColorsLight.length));
  });

  test('workers take colours in order and repeat past the palette', () {
    final n = swarmWorkerColorsDark.length;
    expect(swarmWorkerColor(Brightness.dark, 0), swarmWorkerColorsDark[0]);
    expect(swarmWorkerColor(Brightness.light, 1), swarmWorkerColorsLight[1]);
    expect(swarmWorkerColor(Brightness.dark, n + 2), swarmWorkerColorsDark[2]);
  });
}
