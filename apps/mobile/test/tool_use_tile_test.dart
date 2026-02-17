import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('ToolUseTile - collapsed state', () {
    testWidgets('shows inline row with icon, name, summary, chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ToolUseTile(
            name: 'Read',
            input: {'file_path': 'lib/main.dart'},
          ),
        ),
      );

      // Tool name
      expect(find.text('Read'), findsOneWidget);
      // Input summary: file name only (category=read extracts basename)
      expect(find.text('main.dart'), findsOneWidget);
      // Chevron right (collapsed)
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      // No expand icons
      expect(find.byIcon(Icons.expand_less), findsNothing);

      // Category icon (12px) instead of colored dot
      final iconFinder = find.byWidgetPredicate((w) {
        if (w is Icon && w.size == 12) {
          return true;
        }
        return false;
      });
      expect(iconFinder, findsOneWidget);

      // No card background (no Container with borderRadius + color)
      final cardFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.borderRadius != null && deco.color != null;
        }
        return false;
      });
      expect(cardFinder, findsNothing);
    });

    testWidgets('summary uses command key for Bash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolUseTile(
            name: 'Bash',
            input: {'command': 'ls -la /project'},
          ),
        ),
      );

      expect(find.text('ls -la /project'), findsOneWidget);
    });

    testWidgets('summary truncates long commands', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ToolUseTile(name: 'Bash', input: {'command': 'a' * 100}),
        ),
      );

      // Bash category: truncated to 57 chars + '...'
      expect(find.text('${'a' * 57}...'), findsOneWidget);
    });

    testWidgets('summary falls back to key names', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolUseTile(
            name: 'Custom',
            input: {'foo': 'bar', 'baz': 'qux'},
          ),
        ),
      );

      expect(find.text('foo, baz'), findsOneWidget);
    });
  });

  group('ToolUseTile - expansion', () {
    testWidgets('tap expands to card, tap again collapses', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolUseTile(
            name: 'Read',
            input: {'file_path': 'lib/main.dart'},
          ),
        ),
      );

      // Initially collapsed
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Tap to expand
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Expanded: expand_less icon, card background, JSON content visible
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.textContaining('"file_path"'), findsOneWidget);

      // Card background should exist
      final cardFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.borderRadius != null &&
              deco.color != null &&
              deco.border != null;
        }
        return false;
      });
      expect(cardFinder, findsOneWidget);

      // Tap to collapse
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);
    });
  });

  group('ToolUseTile - long press copy', () {
    testWidgets('long press copies content to clipboard', (tester) async {
      String? clipboardContent;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map;
            clipboardContent = args['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        _wrap(
          const ToolUseTile(name: 'Bash', input: {'command': 'echo hello'}),
        ),
      );

      await tester.longPress(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(clipboardContent, contains('Bash'));
      expect(clipboardContent, contains('"command"'));
      expect(clipboardContent, contains('echo hello'));
      expect(find.text('Copied'), findsOneWidget);
    });
  });
}
