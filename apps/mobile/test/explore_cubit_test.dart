import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/explore/explore_screen.dart';
import 'package:ccpocket/features/explore/state/explore_state.dart';
import 'package:ccpocket/features/file_peek/file_peek_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ccpocket/features/explore/state/explore_cubit.dart';
import 'package:ccpocket/features/explore/widgets/explore_empty_state.dart';
import 'package:ccpocket/features/explore/widgets/explore_entry_tile.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';

class _TestBridgeService extends BridgeService {
  final _fileContentController =
      StreamController<FileContentMessage>.broadcast();
  final _fileListMessageController =
      StreamController<FileListMessage>.broadcast();
  final sentMessages = <ClientMessage>[];

  @override
  Stream<FileContentMessage> get fileContent => _fileContentController.stream;

  @override
  Stream<FileListMessage> get fileListMessages =>
      _fileListMessageController.stream;

  @override
  Stream<FileListMessage> fileListMessagesForProject(String projectPath) =>
      _fileListMessageController.stream;

  void emitFileList(FileListMessage message) {
    _fileListMessageController.add(message);
  }

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  @override
  void dispose() {
    _fileContentController.close();
    _fileListMessageController.close();
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

    test('marks git-ignored files', () {
      final entries = buildExploreEntries(
        ['notes.md', 'renders/preview.mp4'],
        currentPath: 'renders',
        ignoredFiles: {'renders/preview.mp4'},
      );

      expect(entries.single.isIgnored, isTrue);
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

  group('file peek path resolution', () {
    test('sorts duplicate filename matches by modification time', () {
      final paths = resolveFilePeekPaths(
        'script.md',
        ['old/script.md', 'new/script.md', 'middle/script.md'],
        modifiedAt: {
          'old/script.md': 100,
          'middle/script.md': 200,
          'new/script.md': 300,
        },
      );

      expect(paths, ['new/script.md', 'middle/script.md', 'old/script.md']);
    });
  });

  group('ExploreEmptyState', () {
    testWidgets('renders empty state copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ExploreEmptyState())),
      );

      expect(find.text('No files to explore'), findsOneWidget);
      expect(
        find.textContaining('No visible files were found'),
        findsOneWidget,
      );
    });
  });

  testWidgets('hides file actions when sharing is unsupported', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ExploreEntryTile(
            entry: const ExploreEntry(
              name: 'movie.mp4',
              relativePath: 'media/movie.mp4',
              isDirectory: false,
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(PopupMenuButton<void>), findsNothing);
  });

  testWidgets('shows ignored files with a muted label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ExploreEntryTile(
            entry: const ExploreEntry(
              name: 'preview.mp4',
              relativePath: 'renders/preview.mp4',
              isDirectory: false,
              isIgnored: true,
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Ignored · renders/preview.mp4'), findsOneWidget);
  });

  group('Explore recent files', () {
    testWidgets('resets the list to the top after opening a directory', (
      tester,
    ) async {
      final bridge = _TestBridgeService();
      addTearDown(bridge.dispose);
      final files = [
        for (var i = 0; i < 30; i++)
          "dir_${i.toString().padLeft(2, '0')}/a.txt",
        'z_target/first.txt',
        'z_target/second.txt',
      ];

      await tester.pumpWidget(
        RepositoryProvider<BridgeService>.value(
          value: bridge,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExploreScreen(
              sessionId: 'session-1',
              projectPath: '/tmp/project',
              initialFiles: files,
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('z_target'),
        400,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('explore_list')),
          matching: find.byType(Scrollable),
        ),
      );
      final listBefore = tester.widget<ListView>(
        find.byKey(const ValueKey('explore_list')),
      );
      expect(listBefore.controller!.offset, greaterThan(0));

      await tester.tap(find.text('z_target'));
      await tester.pump();
      await tester.pump();

      final listAfter = tester.widget<ListView>(
        find.byKey(const ValueKey('explore_list')),
      );
      expect(listAfter.controller!.offset, 0);
    });

    testWidgets('shows when the bridge truncated the file list', (
      tester,
    ) async {
      final bridge = _TestBridgeService();
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        RepositoryProvider<BridgeService>.value(
          value: bridge,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ExploreScreen(
              sessionId: 'session-1',
              projectPath: '/tmp/project',
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('explore_upload_button')),
        findsOneWidget,
      );
      bridge.emitFileList(
        const FileListMessage(
          files: ['lib/main.dart', 'README.md'],
          truncated: true,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('explore_file_list_truncated_notice')),
        findsOneWidget,
      );
      expect(find.text('Showing the first 2 entries'), findsOneWidget);
    });

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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
      final copyButton = find.byKey(
        const ValueKey('file_peek_copy_path_button'),
      );
      expect(copyButton, findsOneWidget);
      expect(tester.getSize(copyButton).shortestSide, greaterThanOrEqualTo(44));
      final payload = bridge.sentMessages
          .map(
            (message) => jsonDecode(message.toJson()) as Map<String, dynamic>,
          )
          .singleWhere((message) => message['type'] == 'read_file');
      expect(payload['type'], 'read_file');
      expect(payload['projectPath'], '/tmp/project');
      expect(payload['filePath'], 'lib/main.dart');
    });

    testWidgets('opens Share or save from a file action menu', (tester) async {
      final bridge = _TestBridgeService();
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        RepositoryProvider<BridgeService>.value(
          value: bridge,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ExploreScreen(
              sessionId: 'session-1',
              projectPath: '/tmp/project',
              initialFiles: ['build/report.pdf'],
              initialPath: 'build',
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey('explore_entry_actions_build/report.pdf_button'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Share or save'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey('explore_entry_share_build/report.pdf_button'),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('file_transfer_cancel_button')),
        findsOneWidget,
      );
      final payload = bridge.sentMessages
          .map(
            (message) => jsonDecode(message.toJson()) as Map<String, dynamic>,
          )
          .singleWhere((message) => message['type'] == 'prepare_file_download');
      expect(payload['projectPath'], '/tmp/project');
      expect(payload['filePath'], 'build/report.pdf');

      await tester.tap(
        find.byKey(const ValueKey('file_transfer_cancel_button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('file_transfer_cancel_button')),
        findsNothing,
      );
    });
  });
}
