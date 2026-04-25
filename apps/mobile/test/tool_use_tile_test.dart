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
        _wrap(ToolUseTile(name: 'Bash', input: {'command': 'a' * 100})),
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

  group('ToolUseTile - ImageGeneration', () {
    testWidgets('shows compact progress status without expansion controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ToolUseTile(
            name: 'ImageGeneration',
            input: {
              'status': 'in_progress',
              'revisedPrompt': 'A cover image for a mobile agent app',
            },
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('image_generation_tool_use_status')),
        findsOneWidget,
      );
      expect(find.text('Generating image'), findsOneWidget);
      expect(find.text('A cover image for a mobile agent app'), findsOneWidget);
      expect(find.text('ImageGeneration'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);
    });
  });

  group('ToolUseTile - 3-state expansion (non-edit tools)', () {
    testWidgets(
      'tap cycles collapsed → preview → expanded → collapsed for Bash',
      (tester) async {
        const longCmd =
            'find /Users/project -name "*.dart" -not -path "*/build/*" '
            '-not -path "*/.dart_tool/*" | xargs grep -l "ToolUseTile" '
            '| sort | head -20';

        await tester.pumpWidget(
          _wrap(const ToolUseTile(name: 'Bash', input: {'command': longCmd})),
        );

        // --- collapsed ---
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);

        // Tap → preview
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();

        // preview: card with expand_more, full input text visible
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsNothing);
        // Full command should be visible (not truncated at 60 chars)
        expect(find.textContaining('xargs grep'), findsOneWidget);

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

        // Tap → expanded
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();

        // expanded: expand_less icon, SelectableText with full content
        expect(find.byIcon(Icons.expand_less), findsOneWidget);
        expect(find.byType(SelectableText), findsOneWidget);

        // Tap header area → collapsed (tap tool name to avoid SelectableText)
        await tester.tap(find.text('Bash'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        expect(find.byIcon(Icons.expand_less), findsNothing);
        expect(find.byIcon(Icons.expand_more), findsNothing);
      },
    );

    testWidgets('preview shows "... N more lines" for multiline commands', (
      tester,
    ) async {
      // Create a command with more than 5 lines
      final lines = List.generate(10, (i) => 'echo "line $i"');
      final longCmd = lines.join('\n');

      await tester.pumpWidget(
        _wrap(ToolUseTile(name: 'Bash', input: {'command': longCmd})),
      );

      // Tap → preview
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Should show "... 5 more lines"
      expect(find.textContaining('5 more lines'), findsOneWidget);
    });

    testWidgets('short command in preview shows no "more lines" indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ToolUseTile(name: 'Bash', input: {'command': 'ls -la'})),
      );

      // Tap → preview
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // No "more lines" text
      expect(find.textContaining('more lines'), findsNothing);
    });

    testWidgets('Read tool also uses 3-state expansion', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolUseTile(
            name: 'Read',
            input: {
              'file_path':
                  '/Users/project/apps/mobile/lib/widgets/bubbles/assistant_bubble.dart',
            },
          ),
        ),
      );

      // collapsed
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Tap → preview (shows full path)
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.textContaining('assistant_bubble.dart'), findsWidgets);

      // Tap → expanded
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      // Tap header area → collapsed (tap tool name to avoid SelectableText)
      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('ToolUseTile - Edit tools keep 2-state expansion', () {
    testWidgets('Edit tool toggles between collapsed and expanded', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ToolUseTile(
            name: 'Edit',
            input: {
              'file_path': 'lib/main.dart',
              'old_string': 'hello',
              'new_string': 'world',
            },
          ),
        ),
      );

      // Edit tools default to expanded
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      // Tap → collapsed
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Tap → expanded (skip preview, go straight to expanded)
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      // No expand_more (preview) state for edit tools
      expect(find.byIcon(Icons.expand_more), findsNothing);
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
