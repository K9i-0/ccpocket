import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/git/git_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/mock_bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/utils/diff_parser.dart';

Widget _wrap(Widget child, {BridgeService? bridge}) {
  return RepositoryProvider<BridgeService>.value(
    value: bridge ?? BridgeService(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.darkTheme,
      home: child,
    ),
  );
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
  group('GitScreen - individual diff mode', () {
    testWidgets('displays diff content with color coding', (tester) async {
      await tester.pumpWidget(_wrap(const GitScreen(initialDiff: _sampleDiff)));
      await tester.pumpAndSettle();

      // AppBar title should show "Changes" (not file path)
      expect(find.text('Changes'), findsOneWidget);

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
        _wrap(const GitScreen(initialDiff: _sampleDiff, title: 'Custom Title')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Title'), findsOneWidget);
    });

    testWidgets('shows empty state when no changes', (tester) async {
      await tester.pumpWidget(_wrap(const GitScreen(initialDiff: '')));
      await tester.pumpAndSettle();

      expect(find.text('No changes'), findsOneWidget);
    });
  });

  group('GitScreen - multi-file diff', () {
    testWidgets('does not show overflow menu for multi-file diffs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const GitScreen(initialDiff: _multiFileDiff)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('shows file header with stats', (tester) async {
      await tester.pumpWidget(
        _wrap(const GitScreen(initialDiff: _multiFileDiff)),
      );
      await tester.pumpAndSettle();

      // First file should be displayed initially
      expect(find.text('file_a.dart'), findsWidgets);
    });
  });

  group('GitScreen - project mode hunk actions', () {
    testWidgets('shows compact bottom action buttons', (tester) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pull_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('push_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('commit_button')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pull_button')),
          matching: find.text('-'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('push_button')),
          matching: find.text('-'),
        ),
        findsOneWidget,
      );
      expect(find.text('Pull'), findsNothing);
      expect(find.text('Push'), findsNothing);
    });

    testWidgets('shows bulk actions menu for unstaged changes', (tester) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('git_bulk_actions_button')));
      await tester.pumpAndSettle();

      expect(find.text('Stage All'), findsOneWidget);
      expect(find.text('Revert All'), findsOneWidget);
      expect(find.text('Unstage All'), findsNothing);
    });

    testWidgets('shows unstage all menu item in staged tab', (tester) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      bridge.send(
        ClientMessage.gitStage('/tmp/project', files: ['file_a.dart']),
      );
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Staged'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('git_bulk_actions_button')));
      await tester.pumpAndSettle();

      expect(find.text('Unstage All'), findsOneWidget);
      expect(find.text('Stage All'), findsNothing);
    });

    testWidgets('shows confirmation dialog before reverting all changes', (
      tester,
    ) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('git_bulk_actions_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revert All'));
      await tester.pumpAndSettle();

      expect(find.text('すべての変更を破棄しますか'), findsOneWidget);
      expect(find.text('表示中の未ステージ変更をすべて破棄します。'), findsOneWidget);
    });

    testWidgets('shows hunk action sheet on header long press', (tester) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('@@ -1,2 +1,2 @@').first);
      await tester.pumpAndSettle();

      expect(find.text('Request Change'), findsOneWidget);
      expect(find.text('Stage'), findsWidgets);
    });

    testWidgets('shows hunk action sheet on line long press', (tester) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('new').first);
      await tester.pumpAndSettle();

      expect(find.text('Request Change'), findsOneWidget);
      expect(find.text('Revert'), findsOneWidget);
      expect(find.text('Line copied'), findsNothing);
    });

    testWidgets('shows file action sheet on file header long press', (
      tester,
    ) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('file_a.dart').first);
      await tester.pumpAndSettle();

      expect(find.text('Request Change'), findsOneWidget);
      expect(find.text('Stage'), findsWidgets);
    });

    testWidgets('hunk swipe is enabled by default', (tester) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('hunk_swipe_file_a.dart:0')),
        findsOneWidget,
      );
    });

    testWidgets('wraps each file section in the file swipe dismissible', (
      tester,
    ) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      final fileSwipe = find.byKey(const ValueKey('swipe_stage_file_a.dart'));
      expect(fileSwipe, findsOneWidget);
      expect(
        find.descendant(of: fileSwipe, matching: find.text('file_a.dart')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fileSwipe, matching: find.text('@@ -1,2 +1,2 @@')),
        findsOneWidget,
      );
    });

    testWidgets('shows confirmation dialog before reverting a hunk', (
      tester,
    ) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('@@ -1,2 +1,2 @@').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revert'));
      await tester.pumpAndSettle();

      expect(find.text('この変更を破棄しますか'), findsOneWidget);
      expect(find.text('このハンクの未ステージ変更を破棄します。'), findsOneWidget);
    });

    testWidgets('does not throw when Wrap is on and staged tab is selected', (
      tester,
    ) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      bridge.send(
        ClientMessage.gitStage('/tmp/project', files: ['file_a.dart']),
      );
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Staged'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('hunk_swipe_file_a.dart:0')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('GitScreen - line numbers', () {
    testWidgets('displays line numbers for context lines', (tester) async {
      await tester.pumpWidget(_wrap(const GitScreen(initialDiff: _sampleDiff)));
      await tester.pumpAndSettle();

      // Line number 1 should appear (context line "void main() {")
      expect(find.text('1'), findsWidgets);
    });
  });

  group('GitScreen - request change payload helpers', () {
    test('file request change yields non-empty unified diff text', () {
      final selection = DiffSelection(
        diffText: reconstructUnifiedDiff(parseDiff(_multiFileDiff).first),
      );

      expect(selection.diffText, isNotEmpty);
      expect(
        selection.diffText,
        contains('diff --git a/file_a.dart b/file_a.dart'),
      );
      expect(selection.diffText, contains('@@ -1,2 +1,2 @@'));
    });

    test('hunk request change yields only the selected hunk', () {
      final selection = reconstructDiff(parseDiff(_multiFileDiff), {'1:0'});

      expect(
        selection.diffText,
        contains('diff --git a/file_b.dart b/file_b.dart'),
      );
      expect(selection.diffText, contains('@@ -1,2 +1,3 @@'));
      expect(selection.diffText, contains('+added'));
      expect(selection.diffText, isNot(contains('file_a.dart')));
    });
  });
}
