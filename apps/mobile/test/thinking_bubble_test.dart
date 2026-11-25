import 'package:ccpocket/models/code_font_family.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/thinking_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.darkTheme,
  themeAnimationDuration: Duration.zero,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('ThinkingBubble styling', () {
    testWidgets(
      'uses neutral surface and codeTextSettingsOf font in dark and light themes',
      (tester) async {
        for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
          await tester.pumpWidget(
            _wrap(
              const ThinkingBubble(
                thinking: 'Step 1: analyze\nStep 2: verify',
                initiallyExpanded: true,
              ),
              theme: theme,
            ),
          );

          final cs = theme.colorScheme;
          final expectedBg = theme.brightness == Brightness.dark
              ? cs.surfaceContainerLow
              : cs.surfaceContainerLowest;
          final material = tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(ThinkingBubble),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(material.color, expectedBg);

          final expandedText = tester.widget<Text>(
            find.text('Step 1: analyze\nStep 2: verify'),
          );
          expect(
            expandedText.style?.fontFamily,
            CodeFontFamily.jetBrainsMono.fontFamily,
          );

          final idleIcon = tester.widget<Icon>(find.byIcon(Icons.psychology));
          expect(idleIcon.color, cs.onSurfaceVariant);
        }
      },
    );

    testWidgets('uses accent icon only while streaming', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ThinkingBubble(
            thinking: 'Analyzing code...',
            isStreaming: true,
          ),
        ),
      );

      final cs = AppTheme.darkTheme.colorScheme;
      final streamingIcon = tester.widget<Icon>(find.byIcon(Icons.psychology));
      expect(streamingIcon.color, cs.primary);

      final previewText = tester.widget<Text>(find.text('Analyzing code...'));
      expect(
        previewText.style?.fontFamily,
        CodeFontFamily.jetBrainsMono.fontFamily,
      );
    });
  });
}
