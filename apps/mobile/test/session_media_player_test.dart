import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:ccpocket/features/file_peek/playback/background_media_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

class _Streams extends Fake implements PlayerStream {
  final completion = StreamController<bool>.broadcast(sync: true);
  @override
  Stream<bool> get completed => completion.stream;
}

class _Platform extends Fake implements PlatformPlayer {
  @override
  final _Streams stream = _Streams();
  @override
  PlayerState state = const PlayerState();
  int plays = 0;
  @override
  Future<void> play() async {
    plays++;
    state = state.copyWith(playing: true);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(playing: false);
  }

  @override
  Future<void> stop() => pause();
  @override
  Future<void> dispose() => stream.completion.close();
}

class _Session extends Fake implements AudioSession {
  final activations = <bool>[];
  final interruptions = StreamController<AudioInterruptionEvent>.broadcast(
    sync: true,
  );
  Completer<bool>? pendingActivation;
  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      interruptions.stream;
  @override
  Stream<void> get becomingNoisyEventStream => const Stream.empty();
  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {}
  @override
  Future<bool> setActive(
    bool active, {
    AVAudioSessionSetActiveOptions? avAudioSessionSetActiveOptions,
    AndroidAudioFocusGainType? androidAudioFocusGainType,
    AndroidAudioAttributes? androidAudioAttributes,
    bool? androidWillPauseWhenDucked,
    AudioSessionConfiguration fallbackConfiguration =
        const AudioSessionConfiguration.music(),
  }) async {
    activations.add(active);
    return active && pendingActivation != null
        ? pendingActivation!.future
        : true;
  }
}

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'pause, completion and interruption release focus without automatic resume',
    () async {
      final session = _Session();
      final platform = _Platform();
      final player = SessionMediaPlayer(
        platformPlayer: platform,
        sessionFactory: () async => session,
      );
      await player.play();
      await player.pause();
      expect(session.activations, [true, false]);
      await player.play();
      platform.stream.completion.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(session.activations, [true, false, true, false]);
      await player.play();
      session.interruptions.add(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await Future<void>.delayed(Duration.zero);
      expect(platform.state.playing, isFalse);
      session.interruptions.add(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      await Future<void>.delayed(Duration.zero);
      expect(platform.plays, 3);
      await player.dispose();
      await session.interruptions.close();
    },
  );

  test('disposing an old preview cannot deactivate its replacement', () async {
    final session = _Session();
    final old = SessionMediaPlayer(
      platformPlayer: _Platform(),
      sessionFactory: () async => session,
    );
    final current = SessionMediaPlayer(
      platformPlayer: _Platform(),
      sessionFactory: () async => session,
    );
    await old.play();
    await current.play();
    await old.dispose();
    expect(session.activations, [true, true]);
    await current.dispose();
    expect(session.activations, [true, true, false]);
    await session.interruptions.close();
  });

  test('pause cancels a play waiting for OS audio focus', () async {
    final session = _Session()..pendingActivation = Completer<bool>();
    final platform = _Platform();
    final player = SessionMediaPlayer(
      platformPlayer: platform,
      sessionFactory: () async => session,
    );
    final playing = player.play();
    await Future<void>.delayed(Duration.zero);
    final pausing = player.pause();
    session.pendingActivation!.complete(true);
    await Future.wait([playing, pausing]);
    expect(platform.plays, 0);
    expect(session.activations, [true, false]);
    await player.dispose();
    await session.interruptions.close();
  });
}
