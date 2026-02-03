import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/screens/diff_screen.dart';
import 'package:ccpocket/theme/app_theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.darkTheme, home: child);
}

const _sampleDiff = '''
diff --git a/lib/main.dart b/lib/main.dart
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -1,4 +1,5 @@
 void main() {
-  print('goodbye');
+  print('hello');
+  print('world');
   runApp(App());
 }
''';

const _multiFileDiff = '''
diff --git a/file_a.dart b/file_a.dart
--- a/file_a.dart
+++ b/file_a.dart
@@ -1,2 +1,2 @@
-old
+new
 same
diff --git a/file_b.dart b/file_b.dart
--- a/file_b.dart
+++ b/file_b.dart
@@ -1,2 +1,3 @@
 first
+added
 last
''';

void main() {
  group('DiffScreen - individual diff mode', () {
    testWidgets('displays diff content with color coding', (tester) async {
      await tester.pumpWidget(
        _wrap(const DiffScreen(initialDiff: _sampleDiff)),
      );
      await tester.pumpAndSettle();

      // File name should appear
      expect(find.text('lib/main.dart'), findsOneWidget);

      // Addition lines
      expect(find.text("  print('hello');"), findsOneWidget);
      expect(find.text("  print('world');"), findsOneWidget);

      // Deletion line
      expect(find.text("  print('goodbye');"), findsOneWidget);

      // Context lines
      expect(find.text('void main() {'), findsOneWidget);
    });

    testWidgets('displays title when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DiffScreen(initialDiff: _sampleDiff, title: 'Custom Title'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Title'), findsOneWidget);
    });

    testWidgets('shows empty state when no changes', (tester) async {
      await tester.pumpWidget(_wrap(const DiffScreen(initialDiff: '')));
      await tester.pumpAndSettle();

      expect(find.text('No changes'), findsOneWidget);
    });
  });

  group('DiffScreen - multi-file diff', () {
    testWidgets('shows filter button for multi-file diffs', (tester) async {
      await tester.pumpWidget(
        _wrap(const DiffScreen(initialDiff: _multiFileDiff)),
      );
      await tester.pumpAndSettle();

      // Filter icon should be present
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('shows file header with stats', (tester) async {
      await tester.pumpWidget(
        _wrap(const DiffScreen(initialDiff: _multiFileDiff)),
      );
      await tester.pumpAndSettle();

      // First file should be displayed initially
      expect(find.text('file_a.dart'), findsWidgets);
    });
  });

  group('DiffScreen - line numbers', () {
    testWidgets('displays line numbers for context lines', (tester) async {
      await tester.pumpWidget(
        _wrap(const DiffScreen(initialDiff: _sampleDiff)),
      );
      await tester.pumpAndSettle();

      // Line number 1 should appear (context line "void main() {")
      expect(find.text('1'), findsWidgets);
    });
  });
}
