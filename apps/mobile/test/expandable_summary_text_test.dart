import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/widgets/expandable_summary_text.dart';

void main() {
  const shortText = 'ls -la';
  const longText =
      'git add README.md README.ja.md apps/mobile/fastlane/metadata/en-US/description.txt '
      'apps/mobile/fastlane/metadata/ja/description.txt '
      'apps/mobile/fastlane/metadata/android/en-US/full_description.txt '
      'apps/mobile/fastlane/metadata/android/ja-JP/full_description.txt';

  Widget buildSubject(String text, {int maxLines = 2}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: ExpandableSummaryText(
            text: text,
            style: const TextStyle(fontSize: 12),
            maxLines: maxLines,
          ),
        ),
      ),
    );
  }

  group('ExpandableSummaryText', () {
    testWidgets('shows full text when it fits within maxLines', (tester) async {
      await tester.pumpWidget(buildSubject(shortText));

      // Text is shown
      expect(find.text(shortText), findsOneWidget);
      // "more" is not shown
      expect(find.text('more'), findsNothing);
    });

    testWidgets('shows "more" when text overflows maxLines', (tester) async {
      await tester.pumpWidget(buildSubject(longText));
      await tester.pumpAndSettle();

      // Text widget exists
      expect(find.byType(ExpandableSummaryText), findsOneWidget);
      // "more" indicator is visible
      expect(find.text('more'), findsOneWidget);
    });

    testWidgets('collapsed text uses clip overflow (no ellipsis)', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(longText));
      await tester.pumpAndSettle();

      final richText = _findMainRichText(tester);
      expect(richText.maxLines, 2);
      expect(richText.overflow, TextOverflow.clip);
    });

    testWidgets('expands on tap when text overflows', (tester) async {
      await tester.pumpWidget(buildSubject(longText));
      await tester.pumpAndSettle();

      // Initially has maxLines constraint (collapsed)
      var richText = _findMainRichText(tester);
      expect(richText.maxLines, 2);

      // Tap to expand
      await tester.tap(find.text('more'));
      await tester.pumpAndSettle();

      // After tap, maxLines is removed (expanded)
      richText = _findMainRichText(tester);
      expect(richText.maxLines, isNull);
      // "more" disappears, "less" appears
      expect(find.text('more'), findsNothing);
      expect(find.text('less'), findsOneWidget);
    });

    testWidgets('collapses on second tap', (tester) async {
      await tester.pumpWidget(buildSubject(longText));
      await tester.pumpAndSettle();

      // Expand
      await tester.tap(find.text('more'));
      await tester.pumpAndSettle();

      // Collapse
      await tester.tap(find.text('less'));
      await tester.pumpAndSettle();

      // Back to collapsed
      final richText = _findMainRichText(tester);
      expect(richText.maxLines, 2);
      expect(find.text('more'), findsOneWidget);
    });

    testWidgets('respects custom maxLines parameter', (tester) async {
      await tester.pumpWidget(buildSubject(longText, maxLines: 1));
      await tester.pumpAndSettle();

      final richText = _findMainRichText(tester);
      expect(richText.maxLines, 1);
    });

    testWidgets('does not show toggle for empty text', (tester) async {
      await tester.pumpWidget(buildSubject(''));

      expect(find.text('more'), findsNothing);
    });

    testWidgets('"more" is positioned at bottom-right via Stack', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(longText));
      await tester.pumpAndSettle();

      // Stack is used for the collapsed-overflow layout
      expect(
        find.descendant(
          of: find.byType(ExpandableSummaryText),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );

      // "more" is inside a Positioned widget (bottom-right)
      expect(
        find.descendant(
          of: find.byType(Stack),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );
    });
  });
}

/// Find the first (main) RichText inside ExpandableSummaryText.
RichText _findMainRichText(WidgetTester tester) {
  return tester.widget<RichText>(
    find.descendant(
      of: find.byType(ExpandableSummaryText),
      matching: find.byType(RichText).first,
    ),
  );
}
