import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:ccpocket/features/file_peek/file_path_syntax.dart';

/// Parses [input] with [FilePathSyntax] and returns detected file paths.
List<String> _detectFilePaths(String input, Set<String> knownSuffixes) {
  final doc = md.Document(
    inlineSyntaxes: [FilePathSyntax(knownPathSuffixes: knownSuffixes)],
  );
  final nodes = doc.parseInline(input);
  final paths = <String>[];
  for (final node in nodes) {
    if (node is md.Element && node.tag == 'filePath') {
      paths.add(node.attributes['path']!);
    }
  }
  return paths;
}

/// Parses [input] with both [FilePathSyntax] and [BareFilePathSyntax].
List<String> _detectAllFilePaths(String input, Set<String> knownSuffixes) {
  final doc = md.Document(
    inlineSyntaxes: [
      FilePathSyntax(knownPathSuffixes: knownSuffixes),
      BareFilePathSyntax(knownPathSuffixes: knownSuffixes),
    ],
  );
  final nodes = doc.parseInline(input);
  final paths = <String>[];
  for (final node in nodes) {
    if (node is md.Element && node.tag == 'filePath') {
      paths.add(node.attributes['path']!);
    }
  }
  return paths;
}

void main() {
  group('FilePathSyntax.buildSuffixSet', () {
    test('generates all suffixes for a path', () {
      final suffixes = FilePathSyntax.buildSuffixSet([
        'lib/models/messages.dart',
      ]);
      expect(suffixes, contains('lib/models/messages.dart'));
      expect(suffixes, contains('models/messages.dart'));
      expect(suffixes, contains('messages.dart'));
    });

    test('handles single-segment paths', () {
      final suffixes = FilePathSyntax.buildSuffixSet(['package.json']);
      expect(suffixes, contains('package.json'));
      expect(suffixes, hasLength(1));
    });

    test('handles multiple files', () {
      final suffixes = FilePathSyntax.buildSuffixSet([
        'lib/main.dart',
        'pubspec.yaml',
      ]);
      expect(suffixes, contains('lib/main.dart'));
      expect(suffixes, contains('main.dart'));
      expect(suffixes, contains('pubspec.yaml'));
    });
  });

  group('FilePathSyntax detection', () {
    final knownFiles = [
      'lib/main.dart',
      'lib/models/messages.dart',
      'packages/bridge/src/index.ts',
      'pubspec.yaml',
      'package.json',
      'apps/mobile/lib/features/file_peek/file_path_syntax.dart',
    ];
    final suffixes = FilePathSyntax.buildSuffixSet(knownFiles);

    test('detects exact match', () {
      final paths = _detectFilePaths(
        'See `lib/main.dart` for details',
        suffixes,
      );
      expect(paths, ['lib/main.dart']);
    });

    test('detects suffix match (partial path)', () {
      final paths = _detectFilePaths('Check `messages.dart` file', suffixes);
      expect(paths, ['messages.dart']);
    });

    test('detects file without slash', () {
      final paths = _detectFilePaths(
        'Edit `pubspec.yaml` to add deps',
        suffixes,
      );
      expect(paths, ['pubspec.yaml']);
    });

    test('detects multiple files in one line', () {
      final paths = _detectFilePaths(
        'Modified `main.dart` and `package.json`',
        suffixes,
      );
      expect(paths, ['main.dart', 'package.json']);
    });

    test('strips line number suffix', () {
      final paths = _detectFilePaths('Error at `main.dart:42`', suffixes);
      expect(paths, ['main.dart']);
    });

    test('strips line:col suffix', () {
      final paths = _detectFilePaths('See `main.dart:42:10`', suffixes);
      expect(paths, ['main.dart']);
    });

    test('does not detect unknown files', () {
      final paths = _detectFilePaths('Run `npm install`', suffixes);
      expect(paths, isEmpty);
    });

    test('does not detect random backtick text', () {
      final paths = _detectFilePaths('Use `on/off` toggle', suffixes);
      expect(paths, isEmpty);
    });

    test('does not detect code snippets', () {
      final paths = _detectFilePaths('Run `dart analyze`', suffixes);
      expect(paths, isEmpty);
    });

    test('returns empty when knownPathSuffixes is empty', () {
      final paths = _detectFilePaths('See `main.dart`', const {});
      expect(paths, isEmpty);
    });

    test('detects deep nested path by suffix', () {
      final paths = _detectFilePaths(
        'Updated `file_path_syntax.dart`',
        suffixes,
      );
      expect(paths, ['file_path_syntax.dart']);
    });

    test('backtick paths still detected with both syntaxes', () {
      final paths = _detectAllFilePaths(
        'See `lib/main.dart` for details',
        suffixes,
      );
      expect(paths, ['lib/main.dart']);
    });
    test('preserves line number in display text', () {
      final doc = md.Document(
        inlineSyntaxes: [FilePathSyntax(knownPathSuffixes: suffixes)],
      );
      final nodes = doc.parseInline('At `main.dart:42`');
      final fileNode = nodes.whereType<md.Element>().firstWhere(
        (e) => e.tag == 'filePath',
      );
      // path attribute should be stripped
      expect(fileNode.attributes['path'], 'main.dart');
      // display text should keep the line number
      expect(fileNode.textContent, 'main.dart:42');
    });
  });

  group('BareFilePathSyntax — real session messages', () {
    // Real file list from ccpocket project (subset)
    final knownFiles = [
      'docs/install/index.html',
      'README.ja.md',
      'apps/mobile/lib/features/claude_session/claude_session_screen.dart',
      'apps/mobile/lib/features/codex_session/codex_session_screen.dart',
      'apps/mobile/test/regressions/file_peek_file_list_refresh_test.dart',
      'lib/main.dart',
      'pubspec.yaml',
    ];
    final suffixes = FilePathSyntax.buildSuffixSet(knownFiles);

    test('detects bare file paths from actual Codex session', () {
      // Actual message text from running session 2dfd0f83
      final paths = _detectAllFilePaths(
        'docs/install/index.html の軽改修',
        suffixes,
      );
      expect(paths, ['docs/install/index.html']);
    });

    test('detects bare file path in mid-sentence', () {
      final paths = _detectAllFilePaths('詳細は README.ja.md に集約', suffixes);
      expect(paths, ['README.ja.md']);
    });

    test('detects both backtick and bare paths in same message', () {
      final paths = _detectAllFilePaths(
        '`claude_session_screen.dart` と docs/install/index.html を修正',
        suffixes,
      );
      expect(paths, ['claude_session_screen.dart', 'docs/install/index.html']);
    });

    test('does not match version numbers', () {
      final paths = _detectAllFilePaths(
        'mise exec flutter@3.41.6 -- flutter test',
        suffixes,
      );
      expect(paths, isEmpty);
    });

    test('does not match bare text without file extension match', () {
      final paths = _detectAllFilePaths(
        'use_build_context_synchronously info が2件',
        suffixes,
      );
      expect(paths, isEmpty);
    });

    test('does not match when suffix set is empty', () {
      final paths = _detectAllFilePaths(
        'docs/install/index.html の軽改修',
        const {},
      );
      expect(paths, isEmpty);
    });

    test('detects test file path', () {
      final paths = _detectAllFilePaths(
        '回帰テストは追加済みです: file_peek_file_list_refresh_test.dart',
        suffixes,
      );
      expect(paths, ['file_peek_file_list_refresh_test.dart']);
    });
  });
}
