import 'package:ccpocket/features/git/diff_comments.dart';
import 'package:ccpocket/features/git/git_screen.dart';
import 'package:ccpocket/features/media_feedback/state/media_feedback_state.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/draft_service.dart';
import 'package:ccpocket/services/mock_bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _diff = '''
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

Future<DraftService> _pump(WidgetTester tester, {String? sessionId}) async {
  SharedPreferences.setMockInitialValues({});
  final drafts = DraftService(await SharedPreferences.getInstance());
  final bridge = MockBridgeService()..mockDiff = _diff;
  addTearDown(bridge.dispose);
  addTearDown(drafts.mediaFeedback.close);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<BridgeService>.value(value: bridge),
        RepositoryProvider<DraftService>.value(value: drafts),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.darkTheme,
        home: GitScreen(projectPath: '/tmp/project', sessionId: sessionId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return drafts;
}

void main() {
  testWidgets('comments on a line range and keeps the draft in the session', (
    tester,
  ) async {
    final drafts = await _pump(tester, sessionId: 's1');

    await tester.tap(find.text("  print('hello');"));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('diff_comment_field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('diff_comment_field')),
      'Use a logger',
    );
    await tester.tap(find.text("  print('world');"));
    await tester.pumpAndSettle();

    final saved = drafts.mediaFeedback.items('s1').single;
    expect(saved.text, 'Use a logger');
    expect(saved.media.path, 'lib/main.dart');
    expect(saved.media.projectPath, '/tmp/project');
    expect(saved.code!.source, DiffSource.working);
    expect((saved.code!.startLine, saved.code!.endLine), (2, 3));

    await tester.tap(find.byKey(const ValueKey('diff_comment_done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('diff_comment_field')), findsNothing);
    expect(find.text('Use a logger'), findsOneWidget);
    expect(find.text('L2-3'), findsOneWidget);

    // Several comments can coexist.
    await tester.tap(find.text('void main() {'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('diff_comment_field')),
      'Add docs',
    );
    await tester.tap(find.byKey(const ValueKey('diff_comment_done')));
    await tester.pumpAndSettle();
    expect(drafts.mediaFeedback.items('s1').length, 2);

    await tester.tap(
      find.byKey(
        ValueKey(
          'diff_comment_delete_${drafts.mediaFeedback.items('s1').first.id}',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(drafts.mediaFeedback.items('s1').single.text, 'Add docs');
  });

  testWidgets('hunk menu comments on the whole hunk', (tester) async {
    final drafts = await _pump(tester, sessionId: 's1');

    await tester.longPress(find.text('@@ -1,4 +1,5 @@'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('git_comment_hunk_action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('diff_comment_field')),
      'Revisit',
    );
    await tester.pump();

    final anchor = drafts.mediaFeedback.items('s1').single.code!;
    expect((anchor.startLine, anchor.endLine, anchor.lineCount), (1, 5, 6));
  });

  testWidgets('shows comments whose lines changed as outdated', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final drafts = await _pump(tester, sessionId: 's1');
    drafts.mediaFeedback.put(
      's1',
      MediaFeedback(
        id: 'old',
        media: codeFeedbackMedia(
          projectPath: '/tmp/project',
          filePath: 'lib/main.dart',
          source: DiffSource.working,
        ),
        text: 'Gone line',
        code: const CodeAnchor(
          source: DiffSource.working,
          side: DiffSide.newSide,
          startLine: 2,
          endLine: 2,
          lineCount: 1,
          hunkHeader: '@@',
          excerpt: "+  print('removed');",
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Outdated — the commented lines changed'), findsOneWidget);
    expect(find.text('Gone line'), findsOneWidget);
  });

  testWidgets('without a session, tapping lines does not start comments', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text("  print('hello');"));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('diff_comment_field')), findsNothing);

    await tester.longPress(find.text('@@ -1,4 +1,5 @@'));
    await tester.pumpAndSettle();
    expect(find.text('Request Change'), findsOneWidget);
    expect(find.byKey(const ValueKey('git_comment_hunk_action')), findsNothing);
  });
}
