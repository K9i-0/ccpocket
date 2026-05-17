import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ccpocket/features/git/git_screen.dart';
import 'package:ccpocket/features/git/state/git_view_state.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/features/git/widgets/git_file_list_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/git_diff_interaction_mode.dart';
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

Future<Widget> _wrapWithSettings(
  Widget child, {
  BridgeService? bridge,
  GitDiffInteractionMode interactionMode = GitDiffInteractionMode.quickActions,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settingsCubit = SettingsCubit(prefs)
    ..setGitDiffInteractionMode(interactionMode);
  return RepositoryProvider<BridgeService>.value(
    value: bridge ?? BridgeService(),
    child: BlocProvider<SettingsCubit>(
      create: (_) => settingsCubit,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.darkTheme,
        home: child,
      ),
    ),
  );
}

class _RecordingMockBridgeService extends MockBridgeService {
  final sentMessages = <ClientMessage>[];

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
    super.send(message);
  }
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

const _nestedDiff = '''
diff --git a/apps/mobile/lib/app.dart b/apps/mobile/lib/app.dart
--- a/apps/mobile/lib/app.dart
+++ b/apps/mobile/lib/app.dart
@@ -1,1 +1,1 @@
-old
+new
diff --git a/apps/mobile/lib/features/git/git_screen.dart b/apps/mobile/lib/features/git/git_screen.dart
--- a/apps/mobile/lib/features/git/git_screen.dart
+++ b/apps/mobile/lib/features/git/git_screen.dart
@@ -1,1 +1,1 @@
-old
+new
diff --git a/apps/mobile/test/git_screen_test.dart b/apps/mobile/test/git_screen_test.dart
--- a/apps/mobile/test/git_screen_test.dart
+++ b/apps/mobile/test/git_screen_test.dart
@@ -1,1 +1,1 @@
-old
+new
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
    testWidgets('lays out project header below the AppBar', (tester) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      final appBarRect = tester.getRect(find.byType(AppBar));
      final headerRect = tester.getRect(
        find.byKey(const ValueKey('git_project_header')),
      );
      final branchRect = tester.getRect(
        find.byKey(const ValueKey('branch_selector_button')),
      );
      final pullRect = tester.getRect(
        find.byKey(const ValueKey('pull_button')),
      );

      expect(headerRect.top, greaterThanOrEqualTo(appBarRect.bottom));
      expect((branchRect.top - pullRect.top).abs(), lessThan(1));
      expect(find.byKey(const ValueKey('unstaged_tab_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('staged_tab_button')), findsOneWidget);
    });

    testWidgets('shows header sync buttons and bottom commit button', (
      tester,
    ) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pull_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('push_button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('git_file_list_button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('revert_all_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('stage_all_button')), findsOneWidget);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('git_file_list_button')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
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
    });

    testWidgets('focus mode hides project chrome and restores it on exit', (
      tester,
    ) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('git_focus_button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('git_focus_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('git_focus_exit_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('branch_selector_button')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('unstaged_tab_button')), findsNothing);
      expect(find.byKey(const ValueKey('staged_tab_button')), findsNothing);
      expect(find.byKey(const ValueKey('revert_all_button')), findsNothing);
      expect(find.byKey(const ValueKey('stage_all_button')), findsNothing);
      expect(find.byKey(const ValueKey('git_file_list_button')), findsNothing);
      expect(find.text('file_a.dart'), findsWidgets);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.transparent);

      final appBarRect = tester.getRect(find.byType(AppBar));
      final firstHeaderRect = tester.getRect(
        find.byKey(const ValueKey('diff_file_header_file_a.dart')),
      );
      expect(firstHeaderRect.top, greaterThanOrEqualTo(appBarRect.bottom));

      await tester.tap(find.byKey(const ValueKey('git_focus_exit_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('branch_selector_button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('unstaged_tab_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('stage_all_button')), findsOneWidget);
    });

    testWidgets('shows revert and stage all for unstaged changes', (
      tester,
    ) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('stage_all_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('revert_all_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('unstage_all_button')), findsNothing);
    });

    testWidgets('shows unstage all button in staged tab', (tester) async {
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

      expect(find.byKey(const ValueKey('unstage_all_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('commit_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('stage_all_button')), findsNothing);
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

      await tester.tap(find.byKey(const ValueKey('revert_all_button')));
      await tester.pumpAndSettle();

      expect(find.text('Discard all changes?'), findsOneWidget);
      expect(
        find.text('Discard all visible unstaged changes.'),
        findsOneWidget,
      );
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

    testWidgets('opens files sheet from the app bar', (tester) async {
      final bridge = MockBridgeService()..mockDiff = _nestedDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('git_file_list_button')));
      await tester.pumpAndSettle();

      expect(find.text('Files'), findsOneWidget);
      expect(find.text('3 files • Changes'), findsOneWidget);
      expect(find.text('apps'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('git_file_list_tree')),
          matching: find.text('git_screen.dart'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('git_file_list_tree')),
          matching: find.text('apps/mobile/lib/features/git'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('files sheet reflects the current tab only', (tester) async {
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
      await tester.tap(find.byKey(const ValueKey('git_file_list_button')));
      await tester.pumpAndSettle();

      expect(find.text('1 files • Staged'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('git_file_list_tree')),
          matching: find.text('file_a.dart'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('git_file_list_tree')),
          matching: find.text('file_b.dart'),
        ),
        findsNothing,
      );
    });

    testWidgets('selecting a file from the sheet closes it and scrolls there', (
      tester,
    ) async {
      final bridge = MockBridgeService()
        ..mockDiff = List.generate(
          12,
          (index) =>
              '''
diff --git a/lib/file_$index.dart b/lib/file_$index.dart
--- a/lib/file_$index.dart
+++ b/lib/file_$index.dart
@@ -1,1 +1,1 @@
-old
+new
''',
        ).join();
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(const GitScreen(projectPath: '/tmp/project'), bridge: bridge),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('diff_file_header_lib/file_11.dart')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('git_file_list_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('file_11.dart'));
      await tester.pumpAndSettle();

      expect(find.text('Files'), findsNothing);
      expect(
        find.byKey(const ValueKey('diff_file_header_lib/file_11.dart')),
        findsOneWidget,
      );
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

      expect(find.text('Discard this change?'), findsOneWidget);
      expect(
        find.text('Discard unstaged changes in this hunk.'),
        findsOneWidget,
      );
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

    testWidgets('scroll-first mode disables swipe actions', (tester) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        await _wrapWithSettings(
          const GitScreen(projectPath: '/tmp/project'),
          bridge: bridge,
          interactionMode: GitDiffInteractionMode.scrollFirst,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('hunk_swipe_file_a.dart:0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('swipe_stage_file_a.dart')),
        findsNothing,
      );
    });

    testWidgets('scroll-first mode ignores one-finger horizontal swipes', (
      tester,
    ) async {
      final bridge = _RecordingMockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        await _wrapWithSettings(
          const GitScreen(projectPath: '/tmp/project'),
          bridge: bridge,
          interactionMode: GitDiffInteractionMode.scrollFirst,
        ),
      );
      await tester.pumpAndSettle();
      bridge.sentMessages.clear();

      await tester.drag(find.text('new').first, const Offset(120, 0));
      await tester.pump();

      expect(bridge.sentMessages.where((m) => m.type == 'git_stage'), isEmpty);
      expect(
        bridge.sentMessages.where((m) => m.type == 'git_revert_hunks'),
        isEmpty,
      );
    });

    testWidgets('scroll-first mode keeps hunk action sheet available', (
      tester,
    ) async {
      final bridge = MockBridgeService()..mockDiff = _multiFileDiff;
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        await _wrapWithSettings(
          const GitScreen(projectPath: '/tmp/project'),
          bridge: bridge,
          interactionMode: GitDiffInteractionMode.scrollFirst,
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('@@ -1,2 +1,2 @@').first);
      await tester.pumpAndSettle();

      expect(find.text('Request Change'), findsOneWidget);
      expect(find.text('Stage'), findsWidgets);
      expect(find.text('Revert'), findsOneWidget);
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

  group('GitFileListSheet', () {
    testWidgets('builds a tree and toggles folders', (tester) async {
      final files = parseDiff(_nestedDiff);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: GitFileListSheet(
              files: files,
              viewMode: GitViewMode.unstaged,
              scrollController: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('apps'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('git_file_list_tree')),
          matching: find.text('git_screen.dart'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('git_file_list_tree')),
          matching: find.text('apps/mobile/lib/features/git'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('git_tree_node_folder:apps')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('git_file_list_tree')),
          matching: find.text('git_screen.dart'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('git_file_list_tree')),
          matching: find.text('git_screen_test.dart'),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('git_tree_node_folder:apps')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('git_file_list_tree')),
          matching: find.text('git_screen.dart'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('git_file_list_tree')),
          matching: find.text('git_screen_test.dart'),
        ),
        findsOneWidget,
      );
    });
  });
}
