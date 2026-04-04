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
}
