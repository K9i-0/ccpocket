import 'dart:convert';

import 'package:ccpocket/features/git/diff_comments.dart';
import 'package:ccpocket/features/media_feedback/media_feedback_send.dart';
import 'package:ccpocket/features/media_feedback/state/media_feedback_cubit.dart';
import 'package:ccpocket/features/media_feedback/state/media_feedback_state.dart';
import 'package:ccpocket/utils/diff_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _diff = '''
diff --git a/lib/a.dart b/lib/a.dart
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -10,4 +10,5 @@ class A {
 final one = 1;
-final two = 2;
+final two = 22;
+final three = 3;
 final four = 4;
''';

/// Same change, shifted down by five lines and with an unrelated new hunk.
const _shifted = '''
diff --git a/lib/a.dart b/lib/a.dart
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1,1 +1,2 @@
 import 'x.dart';
+import 'y.dart';
@@ -14,4 +15,5 @@ class A {
 final one = 1;
-final two = 2;
+final two = 22;
+final three = 3;
 final four = 4;
''';

DiffFile _file(String diff) => parseDiff(diff).single;

MediaFeedback _comment(CodeAnchor anchor, {String id = 'c1'}) => MediaFeedback(
  id: id,
  media: codeFeedbackMedia(
    projectPath: '/project',
    filePath: 'lib/a.dart',
    source: anchor.source,
  ),
  text: 'Use const',
  code: anchor,
);

void main() {
  group('anchorForLines', () {
    test('uses new-side numbers and quotes the selected lines', () {
      final hunk = _file(_diff).hunks.single;
      final anchor = anchorForLines(hunk, 3, 2, DiffSource.working);
      expect(anchor.side, DiffSide.newSide);
      expect(anchor.startLine, 11);
      expect(anchor.endLine, 12);
      expect(anchor.lineCount, 2);
      expect(anchor.excerpt, '+final two = 22;\n+final three = 3;');
    });

    test('uses old-side numbers for deletion-only ranges', () {
      final hunk = _file(_diff).hunks.single;
      final anchor = anchorForLines(hunk, 1, 1, DiffSource.staged);
      expect(anchor.side, DiffSide.oldSide);
      expect(anchor.startLine, 11);
      expect(codeLineLabel(anchor), 'L11 (old)');
    });

    test('limits the excerpt but keeps the full line count', () {
      final lines = [
        for (var i = 1; i <= 50; i++)
          DiffLine(
            type: DiffLineType.addition,
            content: 'l$i',
            newLineNumber: i,
          ),
      ];
      final hunk = DiffHunk(
        header: '@@',
        oldStart: 0,
        newStart: 1,
        lines: lines,
      );
      final anchor = anchorForLines(hunk, 0, 49, DiffSource.working);
      expect(anchor.lineCount, 50);
      expect(anchor.excerpt.split('\n').length, maxCodeExcerptLines);
      expect(locateCodeAnchor(DiffFile(filePath: 'x', hunks: [hunk]), anchor), (
        hunkIdx: 0,
        start: 0,
        end: 49,
      ));
    });
  });

  group('locateCodeAnchor', () {
    final anchor = anchorForLines(
      _file(_diff).hunks.single,
      2,
      3,
      DiffSource.working,
    );

    test('follows the lines when they move', () {
      expect(locateCodeAnchor(_file(_shifted), anchor), (
        hunkIdx: 1,
        start: 2,
        end: 3,
      ));
    });

    test('prefers the match closest to the original line', () {
      final repeated = DiffFile(
        filePath: 'lib/a.dart',
        hunks: [
          for (final start in [100, 9])
            DiffHunk(
              header: '@@',
              oldStart: start,
              newStart: start,
              lines: [
                DiffLine(
                  type: DiffLineType.addition,
                  content: 'final two = 22;',
                  newLineNumber: start + 2,
                ),
                DiffLine(
                  type: DiffLineType.addition,
                  content: 'final three = 3;',
                  newLineNumber: start + 3,
                ),
              ],
            ),
        ],
      );
      expect(locateCodeAnchor(repeated, anchor)?.hunkIdx, 1);
    });

    test('is outdated when the commented lines changed', () {
      final changed = _diff.replaceFirst(
        '+final three = 3;',
        '+final three = 33;',
      );
      final layout = layoutCodeComments(_file(changed), [_comment(anchor)]);
      expect(layout.placed, isEmpty);
      expect(layout.outdated.single.id, 'c1');
    });

    test('places comments below the last commented line', () {
      final layout = layoutCodeComments(_file(_diff), [_comment(anchor)]);
      expect(layout.placed[0]![3]!.single.id, 'c1');
    });
  });

  group('sending', () {
    test('formats code comments after media comments in line order', () {
      final hunk = _file(_diff).hunks.single;
      final later = _comment(
        anchorForLines(hunk, 4, 4, DiffSource.working),
        id: 'later',
      ).copyWith(text: 'Rename\nthis');
      final earlier = _comment(anchorForLines(hunk, 2, 3, DiffSource.working));
      const video = MediaFeedback(
        id: 'v',
        media: FeedbackMedia(
          key: 'clip',
          label: 'clip.mp4',
          path: 'clip.mp4',
          isVideo: true,
        ),
        text: 'Trim',
      );
      final text = appendMediaFeedback('Prompt', [later, video, earlier]);
      expect(text, startsWith('Prompt\n\nVideo: clip.mp4\nTrim\n\n'));
      expect(
        text,
        endsWith(
          'Code review comments:\n\n'
          'File: lib/a.dart (working tree diff)\n'
          'Project: /project\n'
          '- L11-12:\n'
          '  ```diff\n'
          '  +final two = 22;\n'
          '  +final three = 3;\n'
          '  ```\n'
          '  Use const\n'
          '- L13:\n'
          '  ```diff\n'
          '   final four = 4;\n'
          '  ```\n'
          '  Rename\n'
          '  this',
        ),
      );
    });

    test('code comments are never uploaded as images', () async {
      final comment = _comment(
        anchorForLines(_file(_diff).hunks.single, 0, 0, DiffSource.working),
      );
      final prepared = await feedbackImages([comment], []);
      expect(prepared.images, isEmpty);
    });

    test(
      'persists anchors and reads drafts saved before code comments',
      () async {
        SharedPreferences.setMockInitialValues({
          'media_feedback_v1_s': jsonEncode([
            {
              'id': 'old',
              'media': {'key': 'clip', 'label': 'clip.mp4', 'isVideo': true},
              'text': 'Trim',
              'positionMs': 1000,
            },
          ]),
        });
        final prefs = await SharedPreferences.getInstance();
        final cubit = MediaFeedbackCubit(prefs);
        expect(cubit.items('s').single.media.isCode, isFalse);
        final comment = _comment(
          anchorForLines(_file(_diff).hunks.single, 2, 3, DiffSource.staged),
        );
        cubit.put('s', comment);
        final restored = MediaFeedbackCubit(prefs);
        expect(restored.items('s').last, comment);
        await cubit.close();
        await restored.close();
      },
    );
  });
}
