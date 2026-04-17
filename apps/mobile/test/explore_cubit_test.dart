import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/explore/explore_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ccpocket/features/explore/state/explore_cubit.dart';
import 'package:ccpocket/features/explore/widgets/explore_empty_state.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';

class _TestBridgeService extends BridgeService {
  final _fileContentController =
      StreamController<FileContentMessage>.broadcast();
  final sentMessages = <ClientMessage>[];

  @override
  Stream<FileContentMessage> get fileContent => _fileContentController.stream;

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  @override
  void dispose() {
    _fileContentController.close();
    super.dispose();
  }
}

void main() {
  group('buildExploreEntries', () {
    test('builds root entries from flat file list', () {
      final entries = buildExploreEntries([
        'README.md',
        'lib/main.dart',
        'lib/app.dart',
        'test/widget_test.dart',
      ], currentPath: '');

      expect(entries.map((entry) => (entry.name, entry.isDirectory)).toList(), [
        ('lib', true),
        ('test', true),
        ('README.md', false),
      ]);
    });

    test('builds nested entries for current directory', () {
      final entries = buildExploreEntries([
        'lib/main.dart',
        'lib/src/foo.dart',
        'lib/src/bar.dart',
        'lib/widgets/button.dart',
      ], currentPath: 'lib');

      expect(entries.map((entry) => (entry.name, entry.isDirectory)).toList(), [
        ('src', true),
        ('widgets', true),
        ('main.dart', false),
      ]);
    });

    test('sorts directories before files and alphabetically', () {
      final entries = buildExploreEntries([
        'zeta.md',
        'alpha.txt',
        'docs/guide.md',
        'assets/logo.png',
      ], currentPath: '');

      expect(entries.map((entry) => entry.name).toList(), [
        'assets',
        'docs',
        'alpha.txt',
        'zeta.md',
      ]);
    });

    test('collapses duplicate directory entries', () {
      final entries = buildExploreEntries([
        'lib/src/foo.dart',
        'lib/src/bar.dart',
        'lib/src/deep/baz.dart',
      ], currentPath: 'lib');

      expect(entries.where((entry) => entry.name == 'src').length, 1);
    });

    test('returns empty list when there are no files', () {
      expect(buildExploreEntries(const [], currentPath: ''), isEmpty);
    });
  });

  group('path helpers', () {
    test('returns parent directory for nested path', () {
      expect(parentDirectoryOf('lib/src/widgets'), 'lib/src');
      expect(parentDirectoryOf('lib'), '');
    });

    test('normalizes invalid path to nearest existing parent', () {
      expect(
        normalizeExplorePath([
          'lib/main.dart',
          'lib/src/app.dart',
          'test/widget_test.dart',
        ], 'lib/src/missing'),
        'lib/src',
      );
      expect(
        normalizeExplorePath([
          'lib/main.dart',
          'test/widget_test.dart',
        ], 'docs/reference'),
        '',
      );
    });

    test('builds breadcrumb paths', () {
      expect(breadcrumbsForPath('lib/src/widgets'), [
        'lib',
        'lib/src',
        'lib/src/widgets',
      ]);
    });

    test('updates recent file history with dedupe and cap', () {
      final updated = updateRecentFileHistory([
        'lib/a.dart',
        'lib/b.dart',
        'lib/c.dart',
      ], 'lib/b.dart');
      expect(updated, ['lib/b.dart', 'lib/a.dart', 'lib/c.dart']);

      final capped = updateRecentFileHistory(
        List.generate(10, (i) => 'lib/file_$i.dart'),
        'lib/new.dart',
      );
      expect(capped.length, 10);
      expect(capped.first, 'lib/new.dart');
      expect(capped.last, 'lib/file_8.dart');
    });
  });

  group('ExploreEmptyState', () {
    testWidgets('renders Git-backed empty state copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ExploreEmptyState())),
      );

      expect(find.text('No files to explore'), findsOneWidget);
      expect(find.textContaining('Git-listed files only'), findsOneWidget);
    });
  });

  group('Explore recent files', () {
    testWidgets('shows recent open files only and opens file peek', (
      tester,
    ) async {
      final bridge = _TestBridgeService();
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        RepositoryProvider<BridgeService>.value(
          value: bridge,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ExploreScreen(
              sessionId: 'session-1',
              projectPath: '/tmp/project',
              initialFiles: ['lib/main.dart', 'docs/readme.md'],
              recentPeekedFiles: ['lib/main.dart'],
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('explore_recent_files_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent open files'), findsOneWidget);
      expect(find.text('Current location'), findsNothing);
      expect(find.text('Project root'), findsNothing);

      await tester.tap(find.text('main.dart'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(bridge.sentMessages, hasLength(1));

      final payload =
          jsonDecode(bridge.sentMessages.single.toJson())
              as Map<String, dynamic>;
      expect(payload['type'], 'read_file');
      expect(payload['projectPath'], '/tmp/project');
      expect(payload['filePath'], 'lib/main.dart');
    });
  });
}
