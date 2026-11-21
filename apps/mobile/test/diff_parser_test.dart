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
      expect(
        files[0].hunks[0].lines.every((l) => l.type == DiffLineType.addition),
        true,
      );
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
      expect(
        files[0].hunks[0].lines.every((l) => l.type == DiffLineType.deletion),
        true,
      );
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

    test('parses non-ASCII paths from unquoted diff headers', () {
      const diff = '''
diff --git a/docs/あいう.md b/docs/あいう.md
new file mode 100644
index 0000000..ce01362
--- /dev/null
+++ b/docs/あいう.md
@@ -0,0 +1 @@
+hello
''';
      final files = parseDiff(diff);

      expect(files.length, 1);
      expect(files[0].filePath, 'docs/あいう.md');
    });

    test('parses unquoted diff headers with spaces in paths', () {
      const diff = '''
diff --git a/docs/空 白.md b/docs/空 白.md
new file mode 100644
index 0000000..ce01362
--- /dev/null
+++ b/docs/空 白.md
@@ -0,0 +1 @@
+hello
''';
      final files = parseDiff(diff);

      expect(files.length, 1);
      expect(files[0].filePath, 'docs/空 白.md');
    });

    test('parses quoted escaped paths from diff headers', () {
      const diff = r'''
diff --git "a/docs/\343\201\202\343\201\204\343\201\206.md" "b/docs/\343\201\202\343\201\204\343\201\206.md"
new file mode 100644
index 0000000..ce01362
--- /dev/null
+++ "b/docs/\343\201\202\343\201\204\343\201\206.md"
@@ -0,0 +1 @@
+hello
''';
      final files = parseDiff(diff);

      expect(files.length, 1);
      expect(files[0].filePath, 'docs/あいう.md');
    });

    test('parses quoted escaped paths that also contain spaces', () {
      const diff = r'''
diff --git "a/docs/\347\251\272 \347\231\275.md" "b/docs/\347\251\272 \347\231\275.md"
new file mode 100644
index 0000000..ce01362
--- /dev/null
+++ "b/docs/\347\251\272 \347\231\275.md"
@@ -0,0 +1 @@
+hello
''';
      final files = parseDiff(diff);

      expect(files.length, 1);
      expect(files[0].filePath, 'docs/空 白.md');
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
    test('treats headerless diff mentioning "diff --git" as single file', () {
      const diff =
          '--- a/x.md\n+++ b/x.md\n@@ -1 +1 @@\n-old\n+run diff --git here';
      final files = parseDiff(diff);
      expect(files, hasLength(1));
      expect(files[0].filePath, 'x.md');
      expect(files[0].hunks, hasLength(1));
      expect(files[0].stats.added, 1);
      expect(files[0].stats.removed, 1);
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

  group('Request Change reconstruction', () {
    test('reconstructDiff always returns unified diff text', () {
      const diff = '''
diff --git a/file_a.dart b/file_a.dart
--- a/file_a.dart
+++ b/file_a.dart
@@ -1,2 +1,2 @@
-old
+new
 same
''';
      final files = parseDiff(diff);
      final selection = reconstructDiff(files, {'0:0'});

      expect(
        selection.diffText,
        contains('diff --git a/file_a.dart b/file_a.dart'),
      );
      expect(selection.diffText, contains('--- a/file_a.dart'));
      expect(selection.diffText, contains('+++ b/file_a.dart'));
      expect(selection.diffText, isNot(contains('@file_a.dart')));
    });

    test(
      'summarizeDiffSelection counts only changed lines for a single hunk',
      () {
        const diff = '''
diff --git a/lib/todo_list.dart b/lib/todo_list.dart
--- a/lib/todo_list.dart
+++ b/lib/todo_list.dart
@@ -5,7 +5,7 @@ class TodoList {
 List<Todo> get items => List.unmodifiable(_items);
-void add(String title) {
+void add(String title, {Priority priority = Priority.medium}) {
   final id = DateTime.now().millisecondsSinceEpoch.toString();
   _items.add(Todo(id: id, title: title));
 }
''';
        final summary = summarizeDiffSelection(diff);

        expect(summary.fileCount, 1);
        expect(summary.hunkCount, 1);
        expect(summary.changedLineCount, 2);
        expect(summary.primaryFilePath, 'lib/todo_list.dart');
        expect(summary.primaryHunkHeader, '@@ -5,7 +5,7 @@ class TodoList {');
        expect(summary.isSingleFile, isTrue);
        expect(summary.isSingleHunk, isTrue);
      },
    );

    test('summarizeDiffSelection counts hunks and files across a diff', () {
      const diff = '''
diff --git a/lib/a.dart b/lib/a.dart
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1,2 +1,2 @@
-old
+new
 same
@@ -10,2 +10,2 @@
-old2
+new2
 same2
diff --git a/lib/b.dart b/lib/b.dart
--- a/lib/b.dart
+++ b/lib/b.dart
@@ -3,2 +3,2 @@
-left
+right
 same
''';
      final summary = summarizeDiffSelection(diff);

      expect(summary.fileCount, 2);
      expect(summary.hunkCount, 3);
      expect(summary.changedLineCount, 6);
      expect(summary.primaryFilePath, 'lib/a.dart');
      expect(summary.primaryHunkHeader, '@@ -1,2 +1,2 @@');
    });

    test('summarizeDiffSelection handles binary diffs', () {
      const diff = '''
diff --git a/image.png b/image.png
Binary files a/image.png and b/image.png differ
''';
      final summary = summarizeDiffSelection(diff);

      expect(summary.fileCount, 1);
      expect(summary.hunkCount, 0);
      expect(summary.changedLineCount, 0);
      expect(summary.primaryFilePath, 'image.png');
      expect(summary.primaryHunkHeader, isNull);
    });

    test('reconstructUnifiedDiff includes binary file headers', () {
      const diff = '''
diff --git a/image.png b/image.png
Binary files a/image.png and b/image.png differ
''';
      final file = parseDiff(diff).single;

      expect(
        reconstructUnifiedDiff(file),
        'diff --git a/image.png b/image.png\nBinary files a/image.png and b/image.png differ',
      );
    });
  });
  group('synthesized tool diffs round-trip', () {
    test('Edit diff reconstructs with a hunk header and parses back', () {
      final file = synthesizeEditToolDiff('Edit', {
        'file_path': 'lib/a.dart',
        'old_string': 'foo',
        'new_string': 'bar',
      })!;
      final text = reconstructUnifiedDiff(file);
      expect(text, contains('@@ -1,1 +1,1 @@'));

      final parsed = parseDiff(text);
      expect(parsed, hasLength(1));
      expect(parsed[0].filePath, 'lib/a.dart');
      expect(parsed[0].hunks, hasLength(1));
      expect(parsed[0].stats.added, 1);
      expect(parsed[0].stats.removed, 1);
    });

    test('MultiEdit diff keeps one hunk per edit', () {
      final file = synthesizeEditToolDiff('MultiEdit', {
        'file_path': 'lib/a.dart',
        'edits': [
          {'old_string': 'a', 'new_string': 'b\nc'},
          {'old_string': 'd', 'new_string': 'e'},
        ],
      })!;
      final parsed = parseDiff(reconstructUnifiedDiff(file));
      expect(parsed[0].hunks, hasLength(2));
      expect(parsed[0].stats.added, 3);
      expect(parsed[0].stats.removed, 2);
    });

    test('Write diff reconstructs as a new file with additions', () {
      final file = synthesizeEditToolDiff('Write', {
        'file_path': 'lib/new.dart',
        'content': 'one\ntwo',
      })!;
      final text = reconstructUnifiedDiff(file);
      expect(text, contains('@@ -0,0 +1,2 @@'));

      final parsed = parseDiff(text);
      expect(parsed[0].isNewFile, isTrue);
      expect(parsed[0].hunks, hasLength(1));
      expect(parsed[0].stats.added, 2);
      expect(parsed[0].stats.removed, 0);
    });

    test('reconstructDiff emits a header for header-less hunks', () {
      final files = parseDiff('-old\n+new');
      expect(files[0].hunks.single.header, isEmpty);
      final selection = reconstructDiff(files, {'0:0'});
      final reparsed = parseDiff(selection.diffText);
      expect(reparsed[0].hunks, hasLength(1));
      expect(reparsed[0].stats.added, 1);
      expect(reparsed[0].stats.removed, 1);
    });

    test('FileChange synthesizes colored diff from changes array', () {
      final file = synthesizeEditToolDiff('FileChange', {
        'changes': [
          {
            'path': 'lib/a.dart',
            'kind': 'update',
            'diff': '--- a/lib/a.dart\n+++ b/lib/a.dart\n@@ -1,2 +1,2 @@\n-oldA\n+newA\n same',
          },
          {'path': 'lib/empty.dart', 'kind': 'update', 'diff': '   '},
          {
            'path': 'lib/b.dart',
            'kind': 'add',
            'diff':
                '--- /dev/null\n+++ b/lib/b.dart\n@@ -0,0 +1,2 @@\n+one\n+two',
          },
        ],
      })!;

      expect(file.filePath, 'lib/a.dart');
      expect(file.hunks, hasLength(2));
      expect(file.stats.added, 3);
      expect(file.stats.removed, 1);
    });

    test('FileChange returns null when changes have no non-empty diffs', () {
      expect(
        synthesizeEditToolDiff('FileChange', {
          'changes': [
            {'path': 'lib/a.dart', 'kind': 'update', 'diff': ''},
          ],
        }),
        isNull,
      );
    });

    test('parseDiff splits concatenated headerless unified diffs', () {
      const multi = '''
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1,1 +1,1 @@
-oldA
+newA

--- /dev/null
+++ b/lib/b.dart
@@ -0,0 +1,2 @@
+line1
+line2
''';
      final files = parseDiff(multi);
      expect(files, hasLength(2));
      expect(files[0].filePath, 'lib/a.dart');
      expect(files[0].stats, (added: 1, removed: 1));
      expect(files[1].filePath, 'lib/b.dart');
      expect(files[1].isNewFile, isTrue);
      expect(files[1].stats, (added: 2, removed: 0));
    });
  });

  group('parseDiff headerless file path extraction', () {
    test('keeps backslashes in an unquoted path', () {
      const diff =
          '--- C:\\work\\old.txt\n+++ C:\\work\\new.txt\n@@ -1 +1 @@\n-old\n+new\n';

      expect(parseDiff(diff).single.filePath, r'C:\work\new.txt');
    });

    test('does not split a hunk on removed and added lines that look like a file header', () {
      const diff =
          '--- a/query.sql\n+++ b/query.sql\n@@ -1,3 +1,3 @@\n keep\n--- old comment\n+++ new comment\n tail\n';

      final file = parseDiff(diff).single;

      expect(file.filePath, 'query.sql');
      expect(file.hunks.single.lines.map((line) => line.content), [
        'keep',
        '-- old comment',
        '++ new comment',
        'tail',
      ]);
    });

    test('still splits files when a hunk header overstates its line counts', () {
      const diff =
          '--- a/one.txt\n+++ b/one.txt\n@@ -1,9 +1,9 @@\n-a\n+b\n--- a/two.txt\n+++ b/two.txt\n@@ -1 +1 @@\n-c\n+d\n';

      expect(parseDiff(diff).map((file) => file.filePath), [
        'one.txt',
        'two.txt',
      ]);
    });

    test('drops the tab git appends after a path containing spaces', () {
      const modified =
          '--- a/docs/my notes.md\t\n+++ b/docs/my notes.md\t\n@@ -1 +1 @@\n-old\n+new\n';
      const deleted =
          '--- a/docs/my notes.md\t\n+++ /dev/null\n@@ -1 +0,0 @@\n-old\n';

      expect(parseDiff(modified).single.filePath, 'docs/my notes.md');
      expect(parseDiff(deleted).single.filePath, 'docs/my notes.md');
    });

    test('prefers the new path when old and new paths differ', () {
      const diff = '''
--- a/lib/old_name.dart
+++ b/lib/new_name.dart
@@ -1 +1 @@
-old
+new
''';
      final file = parseDiff(diff).single;

      expect(file.filePath, 'lib/new_name.dart');
      expect(file.isNewFile, isFalse);
      expect(file.isDeleted, isFalse);
    });

    test('reads paths that have no a/ b/ prefixes', () {
      const diff = '''
--- /dev/null
+++ lib/new.dart
@@ -0,0 +1 @@
+hello
''';
      final file = parseDiff(diff).single;

      expect(file.filePath, 'lib/new.dart');
      expect(file.isNewFile, isTrue);
      expect(file.isDeleted, isFalse);
    });

    test('falls back to the old path for a deleted file', () {
      const diff = '''
--- a/lib/gone.dart
+++ /dev/null
@@ -1,2 +0,0 @@
-line 1
-line 2
''';
      final file = parseDiff(diff).single;

      expect(file.filePath, 'lib/gone.dart');
      expect(file.isDeleted, isTrue);
      expect(file.isNewFile, isFalse);
      expect(file.stats, (added: 0, removed: 2));
    });

    test('decodes a quoted escaped old path for a deleted file', () {
      const diff = r'''
--- "a/docs/\343\201\202\343\201\204\343\201\206.md"
+++ /dev/null
@@ -1 +0,0 @@
-hello
''';
      final file = parseDiff(diff).single;

      expect(file.filePath, 'docs/あいう.md');
      expect(file.isDeleted, isTrue);
      expect(file.isNewFile, isFalse);
    });

    test('falls back to an old path without the a/ prefix', () {
      const diff = '''
--- lib/gone.dart
+++ /dev/null
@@ -1 +0,0 @@
-bye
''';
      final file = parseDiff(diff).single;

      expect(file.filePath, 'lib/gone.dart');
      expect(file.isDeleted, isTrue);
    });

    test('decodes a quoted escaped new path', () {
      const diff = r'''
--- /dev/null
+++ "b/docs/\347\251\272 \347\231\275.md"
@@ -0,0 +1 @@
+hello
''';
      final file = parseDiff(diff).single;

      expect(file.filePath, 'docs/空 白.md');
      expect(file.isNewFile, isTrue);
    });

    test('never reports /dev/null as the file path', () {
      const diff = '''
--- /dev/null
+++ /dev/null
@@ -0,0 +0,0 @@
''';
      final file = parseDiff(diff).single;

      expect(file.filePath, isEmpty);
      expect(file.isNewFile, isTrue);
      expect(file.isDeleted, isTrue);
    });

    test('leaves the path empty when there are no file headers', () {
      final file = parseDiff('-old\n+new').single;

      expect(file.filePath, isEmpty);
      expect(file.isNewFile, isFalse);
      expect(file.isDeleted, isFalse);
    });

    test('ignores added lines that look like file headers', () {
      const diff = '''
--- a/notes.md
+++ b/notes.md
@@ -1 +1,4 @@
 title
+++ b/other.md
+++ "b/quoted.md"
+++ plain.md
''';
      final file = parseDiff(diff).single;

      expect(file.filePath, 'notes.md');
      expect(file.hunks.single.lines.map((l) => l.content), [
        'title',
        '++ b/other.md',
        '++ "b/quoted.md"',
        '++ plain.md',
      ]);
      expect(file.stats, (added: 3, removed: 0));
    });

    test('does not split a single diff on a removed "-- " comment line', () {
      const diff = '''
--- a/schema.sql
+++ b/schema.sql
@@ -1,2 +1,2 @@
--- old comment
+-- new comment
 select 1;
''';
      final files = parseDiff(diff);

      expect(files, hasLength(1));
      expect(files[0].filePath, 'schema.sql');
      expect(files[0].stats, (added: 1, removed: 1));
      expect(files[0].hunks.single.lines[0].content, '-- old comment');
      expect(files[0].hunks.single.lines[1].content, '-- new comment');
    });
  });

  group('parseDiff git path decoding', () {
    test('reads an unquoted new path with spaces after a quoted old path', () {
      const diff =
          'diff --git "a/\\343\\201\\202.md" b/my file.md\n--- "a/\\343\\201\\202.md"\n+++ b/my file.md\t\n@@ -1 +1 @@\n-old\n+new\n';

      expect(parseDiff(diff).single.filePath, 'my file.md');
    });

    test('reads a quoted new path after an unquoted old path with spaces', () {
      const diff =
          'diff --git a/my file.md "b/\\343\\201\\202.md"\n--- a/my file.md\t\n+++ "b/\\343\\201\\202.md"\n@@ -1 +1 @@\n-old\n+new\n';

      expect(parseDiff(diff).single.filePath, 'あ.md');
    });

    test('decodes control-character and quote escapes in quoted paths', () {
      const diff = r'''
diff --git "a/dir/tab\there \"q\" back\\slash\nnl\rcr.txt" "b/dir/tab\there \"q\" back\\slash\nnl\rcr.txt"
--- "a/dir/tab\there \"q\" back\\slash\nnl\rcr.txt"
+++ "b/dir/tab\there \"q\" back\\slash\nnl\rcr.txt"
@@ -1 +1 @@
-a
+b
''';
      final file = parseDiff(diff).single;

      expect(file.filePath, 'dir/tab\there "q" back\\slash\nnl\rcr.txt');
    });

    test('decodes an escape that sits near the end of a quoted path', () {
      const diff = r'''
--- /dev/null
+++ "b/a\tb"
@@ -0,0 +1 @@
+x
''';

      expect(parseDiff(diff).single.filePath, 'a\tb');
    });

    test('decodes an octal escape at the very end of a quoted path', () {
      const diff = r'''
--- /dev/null
+++ "b/docs/\343\201\202"
@@ -0,0 +1 @@
+x
''';

      expect(parseDiff(diff).single.filePath, 'docs/あ');
    });

    test('keeps a trailing lone backslash instead of failing', () {
      const diff = r'''
--- /dev/null
+++ odd\
@@ -0,0 +1 @@
+x
''';

      expect(parseDiff(diff).single.filePath, r'odd\');
    });
  });

  group('parseDiff hunk lines', () {
    test('skips "\\ No newline at end of file" markers', () {
      const diff = r'''
--- a/x.txt
+++ b/x.txt
@@ -1,2 +1,2 @@
 keep
-old
\ No newline at end of file
+new
\ No newline at end of file
''';
      final lines = parseDiff(diff).single.hunks.single.lines;

      expect(lines.map((l) => l.type), [
        DiffLineType.context,
        DiffLineType.deletion,
        DiffLineType.addition,
      ]);
      expect(lines.map((l) => l.content), ['keep', 'old', 'new']);
      expect(lines[1].oldLineNumber, 2);
      expect(lines[2].newLineNumber, 2);
    });

    test('treats an unprefixed line inside a hunk as context', () {
      const diff = '''
--- a/x.txt
+++ b/x.txt
@@ -3,1 +3,2 @@
unprefixed
+added
''';
      final lines = parseDiff(diff).single.hunks.single.lines;

      expect(lines, hasLength(2));
      expect(lines[0].type, DiffLineType.context);
      expect(lines[0].content, 'unprefixed');
      expect(lines[0].oldLineNumber, 3);
      expect(lines[0].newLineNumber, 3);
      expect(lines[1].type, DiffLineType.addition);
      expect(lines[1].newLineNumber, 4);
    });

    test('excludes file headers from raw lines without hunk headers', () {
      const diff = '--- a/lib/a.dart\n+++ b/lib/a.dart\n-old\n+new\n same';
      final file = parseDiff(diff).single;
      final lines = file.hunks.single.lines;

      expect(file.filePath, 'lib/a.dart');
      expect(lines.map((l) => l.type), [
        DiffLineType.deletion,
        DiffLineType.addition,
        DiffLineType.context,
      ]);
      expect(lines.map((l) => l.content), ['old', 'new', 'same']);
      expect(lines[0].oldLineNumber, 1);
      expect(lines[1].newLineNumber, 1);
      expect(lines[2].oldLineNumber, 2);
      expect(lines[2].newLineNumber, 2);
    });
  });

  group('combineFileChangeDiffs', () {
    test('returns null when there are no changes', () {
      expect(combineFileChangeDiffs({}), isNull);
      expect(combineFileChangeDiffs({'changes': 'not a list'}), isNull);
      expect(combineFileChangeDiffs({'changes': <dynamic>[]}), isNull);
    });

    test('passes through diffs that already carry file headers', () {
      const unified = '--- a/lib/a.dart\n+++ b/lib/a.dart\n@@ -1 +1 @@\n-a\n+b';
      const git =
          'diff --git a/lib/b.dart b/lib/b.dart\n'
          '--- a/lib/b.dart\n+++ b/lib/b.dart\n@@ -1 +1 @@\n-c\n+d';

      expect(
        combineFileChangeDiffs({
          'changes': [
            {'path': 'lib/a.dart', 'kind': 'update', 'diff': '$unified\n'},
          ],
        }),
        unified,
      );
      expect(
        combineFileChangeDiffs({
          'changes': [
            {'path': 'lib/b.dart', 'kind': 'update', 'diff': '$git\n'},
          ],
        }),
        git,
      );
    });

    test('adds file headers to bare hunks based on the change kind', () {
      String? combine(String? kind) => combineFileChangeDiffs({
        'changes': [
          {'path': 'lib/a.dart', 'kind': kind, 'diff': '@@ -1 +1 @@\n-a\n+b\n'},
        ],
      });

      expect(
        combine('update'),
        '--- a/lib/a.dart\n+++ b/lib/a.dart\n@@ -1 +1 @@\n-a\n+b',
      );
      expect(
        combine(null),
        '--- a/lib/a.dart\n+++ b/lib/a.dart\n@@ -1 +1 @@\n-a\n+b',
      );
      expect(
        combine('add'),
        '--- /dev/null\n+++ b/lib/a.dart\n@@ -1 +1 @@\n-a\n+b',
      );
      expect(
        combine('delete'),
        '--- a/lib/a.dart\n+++ /dev/null\n@@ -1 +1 @@\n-a\n+b',
      );
      expect(
        combine('deleted'),
        '--- a/lib/a.dart\n+++ /dev/null\n@@ -1 +1 @@\n-a\n+b',
      );
    });

    test('keeps a bare hunk as is when the change has no path', () {
      expect(
        combineFileChangeDiffs({
          'changes': [
            {'diff': '@@ -1 +1 @@\n-a\n+b\n\n'},
          ],
        }),
        '@@ -1 +1 @@\n-a\n+b',
      );
    });

    test('joins sections with a blank line and skips unusable entries', () {
      expect(
        combineFileChangeDiffs({
          'changes': [
            {
              'path': 'lib/a.dart',
              'diff': '--- a/lib/a.dart\n+++ b/lib/a.dart\n@@ -1 +1 @@\n-a\n+b',
            },
            'not a map',
            {'path': 'lib/empty.dart', 'diff': ' \n'},
            {'path': 'lib/b.dart', 'kind': 'add', 'diff': '@@ -0,0 +1 @@\n+c'},
          ],
        }),
        '--- a/lib/a.dart\n+++ b/lib/a.dart\n@@ -1 +1 @@\n-a\n+b'
        '\n\n'
        '--- /dev/null\n+++ b/lib/b.dart\n@@ -0,0 +1 @@\n+c',
      );
    });
  });

  group('synthesizeEditToolDiff', () {
    DiffFile? fileChange(List<Object?> changes) =>
        synthesizeEditToolDiff('FileChange', {'changes': changes});

    test('FileChange with a single update is neither new nor deleted', () {
      final file = fileChange([
        {'path': 'lib/a.dart', 'kind': 'update', 'diff': '@@ -1 +1 @@\n-a\n+b'},
      ])!;

      expect(file.filePath, 'lib/a.dart');
      expect(file.isNewFile, isFalse);
      expect(file.isDeleted, isFalse);
      expect(file.stats, (added: 1, removed: 1));
    });

    test('FileChange with a single added file is marked as new', () {
      final file = fileChange([
        {'path': 'lib/a.dart', 'kind': 'add', 'diff': '@@ -0,0 +1 @@\n+a'},
      ])!;

      expect(file.filePath, 'lib/a.dart');
      expect(file.isNewFile, isTrue);
      expect(file.isDeleted, isFalse);
    });

    test('FileChange with a single deleted file is marked as deleted', () {
      final file = fileChange([
        {'path': 'lib/a.dart', 'kind': 'delete', 'diff': '@@ -1 +0,0 @@\n-a'},
      ])!;

      expect(file.filePath, 'lib/a.dart');
      expect(file.isNewFile, isFalse);
      expect(file.isDeleted, isTrue);
    });

    test('FileChange spanning several files is neither new nor deleted', () {
      final addedFirst = fileChange([
        {'path': 'lib/a.dart', 'kind': 'add', 'diff': '@@ -0,0 +1 @@\n+a'},
        {'path': 'lib/b.dart', 'kind': 'update', 'diff': '@@ -1 +1 @@\n-b\n+c'},
      ])!;
      final deletedFirst = fileChange([
        {'path': 'lib/a.dart', 'kind': 'delete', 'diff': '@@ -1 +0,0 @@\n-a'},
        {'path': 'lib/b.dart', 'kind': 'update', 'diff': '@@ -1 +1 @@\n-b\n+c'},
      ])!;

      expect(addedFirst.isNewFile, isFalse);
      expect(addedFirst.isDeleted, isFalse);
      expect(addedFirst.hunks, hasLength(2));
      expect(deletedFirst.isNewFile, isFalse);
      expect(deletedFirst.isDeleted, isFalse);
      expect(deletedFirst.hunks, hasLength(2));
    });

    test('FileChange falls back to the first change path when the diff '
        'names no file', () {
      final file = fileChange([
        {'diff': '@@ -1 +1 @@\n-a\n+b'},
        'not a map',
        {'path': '', 'diff': ''},
        {'path': 'lib/fallback.dart', 'diff': ''},
        {'path': 'lib/later.dart', 'diff': ''},
      ])!;

      expect(file.filePath, 'lib/fallback.dart');
      expect(file.stats, (added: 1, removed: 1));
    });

    test('Write numbers the added lines from 1', () {
      final file = synthesizeEditToolDiff('Write', {
        'file_path': 'lib/new.dart',
        'content': 'one\ntwo\nthree',
      })!;
      final lines = file.hunks.single.lines;

      expect(lines.map((l) => l.newLineNumber), [1, 2, 3]);
      expect(lines.map((l) => l.oldLineNumber), everyElement(isNull));
      expect(lines.map((l) => l.content), ['one', 'two', 'three']);
    });
  });

  group('reconstructUnifiedDiff file headers', () {
    test('writes /dev/null as the old side of a new file', () {
      final file = synthesizeEditToolDiff('Write', {
        'file_path': 'lib/new.dart',
        'content': 'one\ntwo',
      })!;

      expect(
        reconstructUnifiedDiff(file),
        'diff --git a/lib/new.dart b/lib/new.dart\n'
        'new file mode 100644\n'
        '--- /dev/null\n'
        '+++ b/lib/new.dart\n'
        '@@ -0,0 +1,2 @@\n'
        '+one\n'
        '+two',
      );
    });

    test('writes /dev/null as the new side of a deleted file', () {
      const diff =
          'diff --git a/old_file.dart b/old_file.dart\n'
          'deleted file mode 100644\n'
          '--- a/old_file.dart\n'
          '+++ /dev/null\n'
          '@@ -1,2 +0,0 @@\n'
          '-line 1\n'
          '-line 2';
      final file = parseDiff(diff).single;

      expect(file.filePath, 'old_file.dart');
      expect(reconstructUnifiedDiff(file), diff);
      expect(reconstructDiff([file], {'0:0'}).diffText, diff);
    });
  });
}
