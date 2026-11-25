import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/theme/provider_style.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ProviderStyle> styleFor(
    WidgetTester tester,
    ThemeData theme,
    Provider provider,
  ) async {
    late ProviderStyle style;
    await tester.pumpWidget(
      MaterialApp(
        // A fresh app per call: reusing one would animate between themes.
        key: UniqueKey(),
        theme: theme,
        home: Builder(
          builder: (context) {
            style = providerStyleFor(context, provider);
            return const SizedBox();
          },
        ),
      ),
    );
    return style;
  }

  testWidgets('Codex uses its own emerald accent in both themes', (
    tester,
  ) async {
    final light = await styleFor(tester, AppTheme.lightTheme, Provider.codex);
    expect(light.foreground, codexAccentLight);
    expect(light.foreground, isNot(AppTheme.lightTheme.colorScheme.secondary));

    final dark = await styleFor(tester, AppTheme.darkTheme, Provider.codex);
    expect(dark.foreground, codexAccentDark);
    expect(dark.foreground, isNot(AppTheme.darkTheme.colorScheme.secondary));
  });

  testWidgets('Antigravity uses its own blue in both themes', (tester) async {
    final light = await styleFor(
      tester,
      AppTheme.lightTheme,
      Provider.antigravity,
    );
    expect(light.foreground, antigravityAccentLight);

    final dark = await styleFor(
      tester,
      AppTheme.darkTheme,
      Provider.antigravity,
    );
    expect(dark.foreground, antigravityAccentDark);
  });

  testWidgets('each provider has a distinct accent in light and dark themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final accents = <Color>{};
      for (final provider in Provider.values) {
        accents.add((await styleFor(tester, theme, provider)).foreground);
      }
      expect(accents, hasLength(Provider.values.length));
    }
  });

  testWidgets('provider badges meet WCAG AA contrast on card surfaces', (
    tester,
  ) async {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final cardSurface = theme.colorScheme.surfaceContainerHigh;
      for (final provider in Provider.values) {
        final style = await styleFor(tester, theme, provider);
        final badgeBg = Color.alphaBlend(style.background, cardSurface);
        final ratio = _contrastRatio(style.foreground, badgeBg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '${theme.brightness.name} ${provider.name} contrast=$ratio (<4.5)',
        );
      }
    }
  });

  testWidgets('each provider has a distinct custom SVG mark', (tester) async {
    final assets = <String>{};
    for (final provider in Provider.values) {
      final asset = providerIconAsset(provider);
      expect(asset, startsWith('assets/icons/provider_'));
      expect(asset, endsWith('.svg'));
      assets.add(asset);

      await tester.pumpWidget(
        MaterialApp(
          home: IconTheme(
            data: const IconThemeData(size: 18, color: Color(0xFF123456)),
            child: ProviderIcon(provider),
          ),
        ),
      );
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, 18);
      expect(svg.height, 18);
      expect(
        svg.colorFilter,
        const ColorFilter.mode(Color(0xFF123456), BlendMode.srcIn),
      );
    }
    expect(assets, hasLength(Provider.values.length));
  });
}

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}
