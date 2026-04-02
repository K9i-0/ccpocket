import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:ccpocket/features/explore/state/explore_cubit.dart';
import 'package:ccpocket/features/explore/widgets/explore_empty_state.dart';

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

    test('builds breadcrumb paths', () {
      expect(breadcrumbsForPath('lib/src/widgets'), [
        'lib',
        'lib/src',
        'lib/src/widgets',
      ]);
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
}
