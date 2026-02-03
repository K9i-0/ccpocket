import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/utils/diff_parser.dart';

void main() {
  group('parseDiff', () {
    test('parses simple single-file unified diff', () {
      const diff = '''
diff --git a/lib/main.dart b/lib/main.dart
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -1,3 +1,4 @@
 void main() {
+  print('hello');
   print('world');
 }
''';
      final files = parseDiff(diff);
      expect(files.length, 1);
      expect(files[0].filePath, 'lib/main.dart');
      expect(files[0].hunks.length, 1);
      expect(files[0].hunks[0].oldStart, 1);
      expect(files[0].hunks[0].newStart, 1);

      final lines = files[0].hunks[0].lines;
      expect(lines.length, 4);
      expect(lines[0].type, DiffLineType.context);
      expect(lines[0].content, 'void main() {');
      expect(lines[0].oldLineNumber, 1);
      expect(lines[0].newLineNumber, 1);

      expect(lines[1].type, DiffLineType.addition);
      expect(lines[1].content, "  print('hello');");
      expect(lines[1].newLineNumber, 2);
      expect(lines[1].oldLineNumber, isNull);

      expect(lines[2].type, DiffLineType.context);
      expect(lines[2].content, "  print('world');");
      expect(lines[2].oldLineNumber, 2);
      expect(lines[2].newLineNumber, 3);
    });

    test('parses multi-file diff', () {
      const diff = '''
diff --git a/file_a.dart b/file_a.dart
--- a/file_a.dart
+++ b/file_a.dart
@@ -1,2 +1,2 @@
-old line
+new line
 same line
diff --git a/file_b.dart b/file_b.dart
--- a/file_b.dart
+++ b/file_b.dart
@@ -5,3 +5,4 @@
 context
+added
 more context
 end
''';
      final files = parseDiff(diff);
      expect(files.length, 2);
      expect(files[0].filePath, 'file_a.dart');
      expect(files[1].filePath, 'file_b.dart');

      // File A
      expect(files[0].hunks.length, 1);
      expect(files[0].hunks[0].lines.length, 3);
      expect(files[0].hunks[0].lines[0].type, DiffLineType.deletion);
      expect(files[0].hunks[0].lines[1].type, DiffLineType.addition);
      expect(files[0].hunks[0].lines[2].type, DiffLineType.context);

      // File B
      expect(files[1].hunks.length, 1);
      expect(files[1].hunks[0].oldStart, 5);
      expect(files[1].hunks[0].newStart, 5);
    });

    test('tracks line numbers correctly for additions and deletions', () {
      const diff = '''
diff --git a/test.dart b/test.dart
--- a/test.dart
+++ b/test.dart
@@ -10,5 +10,6 @@
 line10
-line11
+new11a
+new11b
 line12
 line13
''';
      final files = parseDiff(diff);
      final lines = files[0].hunks[0].lines;

      // context: line10
      expect(lines[0].oldLineNumber, 10);
      expect(lines[0].newLineNumber, 10);

      // deletion: line11
      expect(lines[1].type, DiffLineType.deletion);
      expect(lines[1].oldLineNumber, 11);
      expect(lines[1].newLineNumber, isNull);

      // addition: new11a
      expect(lines[2].type, DiffLineType.addition);
      expect(lines[2].oldLineNumber, isNull);
      expect(lines[2].newLineNumber, 11);

      // addition: new11b
      expect(lines[3].type, DiffLineType.addition);
      expect(lines[3].newLineNumber, 12);

      // context: line12
      expect(lines[4].type, DiffLineType.context);
      expect(lines[4].oldLineNumber, 12);
      expect(lines[4].newLineNumber, 13);
    });

    test('handles empty diff text', () {
      expect(parseDiff(''), isEmpty);
      expect(parseDiff('  \n  '), isEmpty);
    });

    test('handles new file', () {
      const diff = '''
diff --git a/new_file.dart b/new_file.dart
new file mode 100644
--- /dev/null
+++ b/new_file.dart
@@ -0,0 +1,3 @@
+line 1
+line 2
+line 3
''';
      final files = parseDiff(diff);
      expect(files.length, 1);
      expect(files[0].isNewFile, true);
      expect(files[0].filePath, 'new_file.dart');
      expect(files[0].hunks[0].lines.length, 3);
      expect(files[0].hunks[0].lines.every(
        (l) => l.type == DiffLineType.addition,
      ), true);
    });

    test('handles deleted file', () {
      const diff = '''
diff --git a/old_file.dart b/old_file.dart
deleted file mode 100644
--- a/old_file.dart
+++ /dev/null
@@ -1,2 +0,0 @@
-line 1
-line 2
''';
      final files = parseDiff(diff);
      expect(files.length, 1);
      expect(files[0].isDeleted, true);
      expect(files[0].hunks[0].lines.length, 2);
      expect(files[0].hunks[0].lines.every(
        (l) => l.type == DiffLineType.deletion,
      ), true);
    });

    test('handles binary file', () {
      const diff = '''
diff --git a/image.png b/image.png
Binary files a/image.png and b/image.png differ
''';
      final files = parseDiff(diff);
      expect(files.length, 1);
      expect(files[0].isBinary, true);
      expect(files[0].hunks, isEmpty);
    });

    test('parses tool result diff without diff --git header', () {
      const toolResultDiff = '''
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -5,3 +5,4 @@
 existing line
+new line
 another line
 end
''';
      final files = parseDiff(toolResultDiff);
      expect(files.length, 1);
      expect(files[0].filePath, 'lib/main.dart');
      expect(files[0].hunks.length, 1);
      expect(files[0].hunks[0].lines.length, 4);
    });

    test('parses raw +/- lines without hunk headers', () {
      const rawDiff = '''
-old code
+new code
 context line
-removed
+added
''';
      final files = parseDiff(rawDiff);
      expect(files.length, 1);
      final lines = files[0].hunks[0].lines;
      expect(lines[0].type, DiffLineType.deletion);
      expect(lines[1].type, DiffLineType.addition);
      expect(lines[2].type, DiffLineType.context);
      expect(lines[3].type, DiffLineType.deletion);
      expect(lines[4].type, DiffLineType.addition);
    });

    test('multiple hunks in single file', () {
      const diff = '''
diff --git a/file.dart b/file.dart
--- a/file.dart
+++ b/file.dart
@@ -1,3 +1,3 @@
-old1
+new1
 same
 same
@@ -20,3 +20,3 @@
-old2
+new2
 same
 same
''';
      final files = parseDiff(diff);
      expect(files.length, 1);
      expect(files[0].hunks.length, 2);
      expect(files[0].hunks[0].oldStart, 1);
      expect(files[0].hunks[1].oldStart, 20);
    });
  });

  group('DiffFile stats', () {
    test('calculates aggregate stats', () {
      const diff = '''
diff --git a/test.dart b/test.dart
--- a/test.dart
+++ b/test.dart
@@ -1,3 +1,4 @@
-removed
+added1
+added2
 context
 end
''';
      final files = parseDiff(diff);
      final stats = files[0].stats;
      expect(stats.added, 2);
      expect(stats.removed, 1);
    });
  });

  group('DiffHunk stats', () {
    test('calculates hunk-level stats', () {
      const diff = '''
diff --git a/test.dart b/test.dart
--- a/test.dart
+++ b/test.dart
@@ -1,4 +1,5 @@
 ctx
-del1
-del2
+add1
+add2
+add3
 ctx
''';
      final files = parseDiff(diff);
      final hunkStats = files[0].hunks[0].stats;
      expect(hunkStats.added, 3);
      expect(hunkStats.removed, 2);
    });
  });
}
