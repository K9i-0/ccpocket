import 'package:ccpocket/features/media_feedback/media_feedback_scope.dart';
import 'package:ccpocket/features/media_feedback/state/media_feedback_cubit.dart';
import 'package:ccpocket/features/media_feedback/state/media_feedback_state.dart';
import 'package:ccpocket/features/media_feedback/widgets/media_feedback_editor.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:ccpocket/features/media_feedback/widgets/video_feedback_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late MediaFeedbackCubit cubit;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cubit = MediaFeedbackCubit(await SharedPreferences.getInstance());
  });
  tearDown(() => cubit.close());
  Widget wrap(
    FeedbackMedia media, {
    String sessionId = 'session',
    Duration Function()? position,
    VoidCallback? pause,
    ValueChanged<Duration>? seek,
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        children: [
          const Expanded(child: SizedBox()),
          MediaFeedbackEditor(
            key: ValueKey(media.key),
            binding: MediaFeedbackBinding(cubit, sessionId),
            media: media,
            position: position,
            onPause: pause,
            onSeek: seek,
          ),
        ],
      ),
    ),
  );

  for (final size in [
    const Size(390, 600),
    const Size(900, 360),
    const Size(390, 280),
  ]) {
    testWidgets('video stays stable with many comments at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const video = FeedbackMedia(key: 'clip', label: 'Clip', isVideo: true);
      const videoKey = ValueKey('test_video');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoFeedbackLayout(
              video: const ColoredBox(key: videoKey, color: Colors.black),
              feedback: MediaFeedbackEditor(
                binding: MediaFeedbackBinding(cubit, 'session'),
                media: video,
              ),
            ),
          ),
        ),
      );
      final initialRect = tester.getRect(find.byKey(videoKey));
      for (var i = 0; i < 30; i++) {
        cubit.put(
          'session',
          MediaFeedback(
            id: 'comment$i',
            media: video,
            text: 'Comment $i with a longer instruction for this video',
            positionMs: i * 1000,
          ),
        );
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(videoKey)), initialRect);
      await tester.drag(
        find.byKey(const ValueKey('media_feedback_comments_list')),
        const Offset(0, -2500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('media_feedback_input')),
      );
      await tester.enterText(find.byType(TextField), 'Another instruction');
      await tester.pump();
      expect(cubit.items('session').last.text, 'Another instruction');
      expect(tester.getRect(find.byKey(videoKey)), initialRect);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'reusing the same preview for another session restores only its draft',
    (tester) async {
      const media = FeedbackMedia(key: 'shared', label: 'Image');
      await tester.pumpWidget(wrap(media));
      await tester.enterText(find.byType(TextField), 'Session one');
      await tester.pumpWidget(wrap(media, sessionId: 'other'));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField), 'Session two');
      expect(cubit.items('session').single.text, 'Session one');
      expect(cubit.items('other').single.text, 'Session two');
    },
  );

  testWidgets(
    'accepted feedback clears an open editor without restoring sent text',
    (tester) async {
      const media = FeedbackMedia(key: 'shared', label: 'Image');
      await tester.pumpWidget(wrap(media));
      await tester.enterText(find.byType(TextField), 'Sent instruction');
      await tester.pump();
      cubit.removeSent('session', List.of(cubit.items('session')));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField), 'Next instruction');
      expect(cubit.items('session').single.text, 'Next instruction');
    },
  );

  testWidgets('image edits autosave, restore and stay separate by source', (
    tester,
  ) async {
    const a = FeedbackMedia(key: 'a', label: 'A');
    const b = FeedbackMedia(key: 'b', label: 'B');
    await tester.pumpWidget(wrap(a));
    await tester.enterText(
      find.byKey(const ValueKey('media_feedback_input')),
      'Make the background blue',
    );
    expect(cubit.items('session').single.text, 'Make the background blue');
    await tester.pumpWidget(wrap(b));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.pumpWidget(wrap(a));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Make the background blue',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('video captures time once, seeks, edits and deletes comments', (
    tester,
  ) async {
    var position = const Duration(seconds: 5);
    var pauses = 0;
    Duration? sought;
    const video = FeedbackMedia(key: 'clip', label: 'Clip', isVideo: true);
    await tester.pumpWidget(
      wrap(
        video,
        position: () => position,
        pause: () => pauses++,
        seek: (p) => sought = p,
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('media_feedback_timestamp_button')),
    );
    await tester.pump();
    position = const Duration(seconds: 12);
    await tester.enterText(
      find.byKey(const ValueKey('media_feedback_input')),
      'Change this dialogue',
    );
    await tester.pump();
    expect(cubit.items('session').single.positionMs, 5000);
    expect(pauses, 1);
    await tester.tap(find.byKey(const ValueKey('media_feedback_done_button')));
    await tester.pump();
    await tester.tap(find.text('0:05'));
    expect(sought, const Duration(seconds: 5));
    await tester.tap(find.text('Change this dialogue'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Updated dialogue');
    await tester.pump();
    expect(cubit.items('session').single.text, 'Updated dialogue');
    await tester.tap(
      find.byKey(
        ValueKey(
          'media_feedback_delete_${cubit.items('session').single.id}_button',
        ),
      ),
    );
    await tester.pump();
    expect(cubit.items('session'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'video unfinished comments persist and overall comments omit time',
    (tester) async {
      const video = FeedbackMedia(key: 'clip', label: 'Clip', isVideo: true);
      await tester.pumpWidget(wrap(video));
      await tester.enterText(
        find.byType(TextField),
        'Make the whole video calmer',
      );
      await tester.pumpWidget(const SizedBox());
      expect(cubit.items('session').single.positionMs, isNull);
      await tester.pumpWidget(wrap(video));
      expect(find.text('Make the whole video calmer'), findsOneWidget);
    },
  );

  testWidgets('source changes require explicit acknowledgement', (
    tester,
  ) async {
    const old = FeedbackMedia(
      key: 'clip',
      label: 'Clip',
      isVideo: true,
      modifiedAt: 1,
    );
    cubit.put(
      'session',
      const MediaFeedback(
        id: 'a',
        media: old,
        text: 'Change',
        positionMs: 5000,
      ),
    );
    await tester.pumpWidget(wrap(old.copyWith(modifiedAt: 2)));
    expect(find.text('Use updated media'), findsOneWidget);
    await tester.tap(find.text('Use updated media'));
    await tester.pump();
    expect(cubit.items('session').single.media.modifiedAt, 2);
    expect(find.text('Use updated media'), findsNothing);
  });
}
