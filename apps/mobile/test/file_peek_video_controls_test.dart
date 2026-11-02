import 'dart:async';

import 'package:ccpocket/features/file_peek/widgets/file_peek_video_controls.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

class _Streams extends Fake implements PlayerStream {
  final playingController = StreamController<bool>.broadcast();
  final positionController = StreamController<Duration>.broadcast();

  @override
  Stream<bool> get playing => playingController.stream;
  @override
  Stream<Duration> get position => positionController.stream;
  @override
  Stream<Duration> get duration => const Stream.empty();
  @override
  Stream<Duration> get buffer => const Stream.empty();
  @override
  Stream<bool> get buffering => const Stream.empty();
  @override
  Stream<double> get rate => const Stream.empty();
  @override
  Stream<double> get volume => const Stream.empty();

  Future<void> close() async {
    await playingController.close();
    await positionController.close();
  }
}

class _FakePlayer extends Fake implements Player {
  @override
  final _Streams stream = _Streams();
  @override
  PlayerState state = const PlayerState(duration: Duration(seconds: 18));
  final seeks = <Duration>[];

  @override
  Future<void> play() async {
    state = state.copyWith(playing: true);
    stream.playingController.add(true);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(playing: false);
    stream.playingController.add(false);
  }

  @override
  Future<void> seek(Duration duration) async {
    seeks.add(duration);
    state = state.copyWith(position: duration);
    stream.positionController.add(duration);
  }
}

const _controlKeys = [
  'file_peek_video_play_button',
  'file_peek_video_rewind_button',
  'file_peek_video_forward_button',
  'file_peek_video_seek_bar',
  'file_peek_video_volume_button',
  'file_peek_video_speed_button',
  'file_peek_video_fullscreen_button',
];

Future<_FakePlayer> _pump(WidgetTester tester, Size size) async {
  final player = _FakePlayer();
  addTearDown(player.stream.close);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox.fromSize(
            size: size,
            child: FilePeekVideoControls(player: player),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return player;
}

void main() {
  test('switches to compact controls only when the center does not fit', () {
    expect(filePeekVideoControlsCompact(224), isFalse);
    expect(filePeekVideoControlsCompact(144), isFalse);
    expect(filePeekVideoControlsCompact(143), isTrue);
    expect(filePeekVideoControlsCompact(100), isTrue);
    expect(filePeekVideoControlsMinimal(88), isFalse);
    expect(filePeekVideoControlsMinimal(87), isTrue);
  });

  testWidgets('bottom row actions stay right-aligned', (tester) async {
    await _pump(tester, const Size(800, 300));
    final bounds = tester.getRect(find.byType(FilePeekVideoControls));
    final fullscreen = tester.getRect(
      find.byKey(const ValueKey('file_peek_video_fullscreen_button')),
    );
    expect(bounds.right - fullscreen.right, lessThan(16));
  });

  for (final size in const [
    Size(393, 224),
    Size(393, 260),
    Size(600, 300),
    Size(320, 150),
    Size(320, 120),
    Size(844, 100),
    Size(450, 71),
    Size(280, 60),
    Size(844, 390),
  ]) {
    testWidgets('controls never overlap at $size', (tester) async {
      await _pump(tester, size);
      expect(tester.takeException(), isNull);

      final bounds = tester.getRect(find.byType(FilePeekVideoControls));
      final rects = <String, Rect>{};
      for (final key in _controlKeys) {
        final finder = find.byKey(ValueKey(key));
        if (finder.evaluate().isEmpty) continue;
        final rect = tester.getRect(finder);
        expect(
          bounds.inflate(0.5).contains(rect.topLeft) &&
              bounds.inflate(0.5).contains(rect.bottomRight),
          isTrue,
          reason: '$key $rect is outside $bounds',
        );
        rects[key] = rect;
      }
      expect(rects.keys, contains('file_peek_video_play_button'));
      expect(rects.keys, contains('file_peek_video_seek_bar'));

      final entries = rects.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final overlap = entries[i].value.intersect(entries[j].value);
          expect(
            overlap.width <= 0 || overlap.height <= 0,
            isTrue,
            reason:
                '${entries[i].key} ${entries[i].value} overlaps '
                '${entries[j].key} ${entries[j].value}',
          );
        }
      }
    });
  }

  testWidgets('play button toggles playback instead of seeking', (
    tester,
  ) async {
    final player = await _pump(tester, const Size(393, 224));
    await tester.tap(find.byKey(const ValueKey('file_peek_video_play_button')));
    await tester.pump();
    expect(player.state.playing, isTrue);
    expect(player.seeks, isEmpty);

    await tester.tap(find.byKey(const ValueKey('file_peek_video_play_button')));
    await tester.pump();
    expect(player.state.playing, isFalse);
    expect(player.seeks, isEmpty);
  });

  testWidgets('restarts from the beginning after playback completes', (
    tester,
  ) async {
    final player = await _pump(tester, const Size(393, 224));
    player.state = player.state.copyWith(
      completed: true,
      position: const Duration(seconds: 18),
    );
    await tester.tap(find.byKey(const ValueKey('file_peek_video_play_button')));
    await tester.pump();
    expect(player.seeks, [Duration.zero]);
    expect(player.state.playing, isTrue);
  });

  testWidgets('hides while playing and reappears on tap', (tester) async {
    await _pump(tester, const Size(393, 224));
    final play = find.byKey(const ValueKey('file_peek_video_play_button'));
    await tester.tap(play);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: play, matching: find.byType(AnimatedOpacity)),
          )
          .opacity,
      0,
    );

    // A hidden control must not receive the tap; it only reveals controls.
    await tester.tap(find.byType(FilePeekVideoControls));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: play, matching: find.byType(AnimatedOpacity)),
          )
          .opacity,
      1,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
