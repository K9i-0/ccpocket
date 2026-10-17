import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:ccpocket/features/file_peek/playback/background_media_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

class _Streams extends Fake implements PlayerStream {
  final changes = StreamController<bool>.broadcast(sync: true);
  @override
  Stream<bool> get playing => changes.stream;
  @override
  Stream<bool> get completed => const Stream.empty();
  @override
  Stream<bool> get buffering => const Stream.empty();
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<Duration> get duration => const Stream.empty();
  @override
  Stream<double> get rate => const Stream.empty();
}

class _Player extends Fake implements Player {
  @override
  final _Streams stream = _Streams();
  @override
  PlayerState state = const PlayerState(duration: Duration(minutes: 2));
  int pauses = 0;
  @override
  Future<void> play() async {
    state = state.copyWith(playing: true);
    stream.changes.add(true);
  }

  @override
  Future<void> pause() async {
    pauses++;
    state = state.copyWith(playing: false);
    stream.changes.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
  }
}

void main() {
  test(
    'OS controls share preview playback and stop dismisses controls',
    () async {
      final handler = BackgroundMediaHandler();
      final player = _Player();
      addTearDown(player.stream.changes.close);
      handler.attach(player, 'preview');
      expect(handler.mediaItem.value!.duration, const Duration(minutes: 2));
      await handler.play();
      expect(player.state.playing, isTrue);
      expect(handler.playbackState.value.playing, isTrue);
      await handler.seek(const Duration(seconds: 12));
      expect(player.state.position, const Duration(seconds: 12));
      await handler.pause();
      expect(handler.playbackState.value.playing, isFalse);
      await handler.play();
      await handler.stop();
      expect(player.state.playing, isFalse);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
      await player.play();
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.ready,
      );
      handler.detach(player);
      expect(handler.mediaItem.value, isNull);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
    },
  );
  test(
    'replacement pauses old preview and ignores its later disposal',
    () async {
      final handler = BackgroundMediaHandler();
      final old = _Player();
      final current = _Player();
      addTearDown(old.stream.changes.close);
      addTearDown(current.stream.changes.close);
      handler.attach(old, 'old');
      await old.play();
      handler.attach(current, 'current');
      expect(old.pauses, 1);
      handler.detach(old);
      await handler.play();
      expect(current.state.playing, isTrue);
      expect(handler.mediaItem.value!.id, 'current');
      handler.detach(current);
      await handler.play();
      expect(handler.playbackState.value.playing, isFalse);
    },
  );
}
