import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme font fallback', () {
    test('applies Chinese system font fallback only for zh locale', () {
      final zhFallback = AppTheme.lightThemeForLocale(const Locale('zh'))
          .textTheme
          .bodyMedium
          ?.fontFamilyFallback;

      _expectChineseFallback(zhFallback);

      for (final locale in [
        null,
        const Locale('en'),
        const Locale('ja'),
        const Locale('ko'),
      ]) {
        final fallback = AppTheme.lightThemeForLocale(locale)
            .textTheme
            .bodyMedium
            ?.fontFamilyFallback;
        _expectNoChineseFallback(fallback, reason: 'locale=$locale');
      }
    });
  });

  group('AppTheme surfaces and contrast', () {
    test('dark mode uses softened hairline border tokens', () {
      final dark = AppTheme.darkTheme;
      final darkColors = dark.extension<AppColors>()!;
      expect(dark.colorScheme.outlineVariant, const Color(0xFF27272A));
      expect(darkColors.codeBorder, const Color(0xFF27272A));
      expect(darkColors.toolBubbleBorder, const Color(0xFF27272A));
    });

    test('light mode neutral surfaces align with Zinc palette', () {
      final light = AppTheme.lightTheme;
      final lightColors = light.extension<AppColors>()!;
      expect(lightColors.codeBackground, light.colorScheme.surfaceContainerLow);
      expect(
        lightColors.toolResultBackground,
        light.colorScheme.surfaceContainerLow,
      );
      expect(lightColors.codeBorder, light.colorScheme.outlineVariant);
      expect(lightColors.toolBubbleBorder, light.colorScheme.outlineVariant);
    });

    test('subtle and tool result text meet WCAG AA contrast', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final colors = theme.extension<AppColors>()!;
        final surface = theme.colorScheme.surface;
        final card = theme.colorScheme.surfaceContainerHigh;
        expect(
          _contrastRatio(colors.subtleText, surface),
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness.name} subtleText on surface',
        );
        expect(
          _contrastRatio(colors.subtleText, card),
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness.name} subtleText on card',
        );
        expect(
          _contrastRatio(colors.toolResultText, colors.toolResultBackground),
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness.name} toolResultText',
        );
        expect(
          _contrastRatio(
            colors.toolResultTextExpanded,
            colors.toolResultBackground,
          ),
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness.name} toolResultTextExpanded',
        );
      }
    });
  });
}

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void _expectChineseFallback(List<String>? fallback) {
  expect(
    fallback,
    containsAll(['Microsoft YaHei', 'PingFang SC', 'Noto Sans CJK SC']),
  );
}

void _expectNoChineseFallback(
  List<String>? fallback, {
  required String reason,
}) {
  for (final family in ['Microsoft YaHei', 'PingFang SC', 'Noto Sans CJK SC']) {
    expect(
      fallback ?? const <String>[],
      isNot(contains(family)),
      reason: reason,
    );
  }
}
