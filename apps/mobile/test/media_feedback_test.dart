import 'dart:convert';
import 'dart:typed_data';

import 'package:ccpocket/features/media_feedback/media_feedback_send.dart';
import 'package:ccpocket/features/media_feedback/state/media_feedback_cubit.dart';
import 'package:ccpocket/features/media_feedback/state/media_feedback_state.dart';
import 'package:ccpocket/services/draft_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const video = FeedbackMedia(
  key: 'clip',
  label: 'clip.mp4',
  path: 'output/clip.mp4',
  projectPath: '/project',
  isVideo: true,
);
const comment = MediaFeedback(
  id: 'one',
  media: video,
  text: 'Change the dialogue',
  positionMs: 5000,
);

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('persists independently of the prompt and other sessions', () async {
    final drafts = DraftService(prefs);
    drafts.saveDraft('a', 'Main prompt');
    drafts.mediaFeedback.put('a', comment);
    final restored = MediaFeedbackCubit(prefs);
    expect(restored.items('a'), [comment]);
    expect(restored.items('b'), isEmpty);
    expect(drafts.getDraft('a'), 'Main prompt');
    await restored.close();
    await drafts.mediaFeedback.close();
  });

  test(
    'sending removes exact snapshots and preserves edits and new comments',
    () async {
      final cubit = MediaFeedbackCubit(prefs);
      cubit.put('a', comment);
      final snapshot = List<MediaFeedback>.of(cubit.items('a'));
      final edited = comment.copyWith(text: 'New instruction');
      cubit.put('a', edited);
      cubit.put('a', comment.copyWith(id: 'two', positionMs: 12000));
      cubit.removeSent('a', snapshot);
      expect(cubit.items('a').length, 2);
      cubit.removeSent('a', [edited]);
      expect(cubit.items('a').single.id, 'two');
      await cubit.close();
    },
  );

  test('pending session migration works without a text draft and retains open binding', () async {
    final drafts = DraftService(prefs);
    drafts.mediaFeedback.put('pending', comment);
    drafts.migrateDraft('pending', 'real');
    drafts.mediaFeedback.put(
      'pending',
      comment.copyWith(text: 'Edited in open preview'),
    );
    expect(
      drafts.mediaFeedback.items('real').single.text,
      'Edited in open preview',
    );
    expect(MediaFeedbackCubit(prefs).items('pending'), isEmpty);
    await drafts.mediaFeedback.close();
  });

  test('corrupt persisted data does not erase other sessions', () async {
    await prefs.setString('media_feedback_v1_broken', '{bad');
    final cubit = MediaFeedbackCubit(prefs);
    cubit.put('valid', comment);
    final restored = MediaFeedbackCubit(prefs);
    expect(restored.items('valid'), [comment]);
    await cubit.close();
    await restored.close();
  });

  test('appends grouped chronological instructions after main text', () {
    final text = appendMediaFeedback('Main prompt', [
      comment.copyWith(id: 'two', positionMs: 12000, text: 'Hold subtitle'),
      comment,
    ]);
    expect(text, startsWith('Main prompt\n\nVideo: output/clip.mp4'));
    expect(text, contains('Project: /project'));
    expect(text.indexOf('0:05'), lessThan(text.indexOf('0:12')));
    expect(appendMediaFeedback('', [comment]), startsWith('Video:'));
  });

  test(
    'attaches pathless images with unambiguous ordinal references',
    () async {
      final a = comment.copyWith(
        media: FeedbackMedia(
          key: 'generated:a',
          label: 'A',
          base64: base64Encode([1, 2, 3]),
        ),
      );
      final b = comment.copyWith(
        id: 'two',
        media: FeedbackMedia(
          key: 'generated:b',
          label: 'B',
          base64: base64Encode([4, 5, 6]),
        ),
      );
      final prepared = await feedbackImages([a, b], []);
      expect(prepared.images.length, 2);
      final text = appendMediaFeedback('', [
        a,
        b,
      ], attachmentIndices: prepared.indices);
      expect(text, contains('generated:a (attached image 1)'));
      expect(text, contains('generated:b (attached image 2)'));
    },
  );

  test(
    'deduplicates an already attached image and leaves file paths unuploaded',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final image = comment.copyWith(
        media: FeedbackMedia(
          key: 'image',
          label: 'Image',
          base64: base64Encode(bytes),
        ),
      );
      final prepared = await feedbackImages(
        [image, image, comment],
        [(bytes: bytes, mimeType: 'image/png')],
      );
      expect(prepared.images.length, 1);
      expect(prepared.indices['image'], 1);
    },
  );

  test('download failures and image limits reject preparation without removing drafts', () async {
    final cubit = MediaFeedbackCubit(prefs);
    final image = comment.copyWith(
      media: const FeedbackMedia(
        key: 'remote',
        label: 'Image',
        url: 'https://example.com/a.png',
      ),
    );
    cubit.put('a', image);
    await expectLater(
      feedbackImages(
        cubit.items('a'),
        [],
        get: (_) async => http.Response('', 404),
      ),
      throwsStateError,
    );
    expect(cubit.items('a'), [image]);
    final existing = List.generate(
      5,
      (i) => (bytes: Uint8List.fromList([i]), mimeType: 'image/png'),
    );
    await expectLater(
      feedbackImages(
        [image],
        existing,
        get: (_) async => http.Response.bytes([9], 200),
      ),
      throwsStateError,
    );
    await cubit.close();
  });
}
