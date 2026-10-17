import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// OS controls share the preview's player; closing the preview ends playback.
class BackgroundMediaHandler extends BaseAudioHandler {
  static BackgroundMediaHandler? instance;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static Future<void> initialize() async {
    if (!supported || instance != null) return;
    instance = await AudioService.init(
      builder: BackgroundMediaHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'ccpocket_media',
        androidNotificationChannelName: 'Media playback',
        androidNotificationIcon: 'drawable/ic_notification',
      ),
    );
  }

  Player? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _stopped = false;

  void attach(Player player, String id) {
    final previous = _player;
    if (previous != null && previous != player) unawaited(previous.pause());
    detach(previous);
    _player = player;
    _stopped = false;
    // Do not expose Bridge capability URLs on the lock screen.
    mediaItem.add(
      MediaItem(id: id, title: 'CC Pocket', artist: 'Media preview'),
    );
    _subscriptions.add(
      player.stream.playing.listen((playing) {
        if (playing) _stopped = false;
        _publish();
      }),
    );
    for (final stream in <Stream<dynamic>>[
      player.stream.completed,
      player.stream.buffering,
      player.stream.position,
      player.stream.duration,
      player.stream.rate,
    ]) {
      _subscriptions.add(stream.listen((_) => _publish()));
    }
    _publish();
  }

  void detach(Player? player) {
    if (player == null || player != _player) return;
    _player = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle),
    );
    mediaItem.add(null);
  }

  void _publish() {
    final player = _player;
    if (player == null) return;
    final state = player.state;
    final item = mediaItem.value;
    if (item != null && item.duration != state.duration) {
      mediaItem.add(item.copyWith(duration: state.duration));
    }
    playbackState.add(
      PlaybackState(
        controls: [
          state.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0],
        processingState: _stopped
            ? AudioProcessingState.idle
            : state.completed
            ? AudioProcessingState.completed
            : state.buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: state.playing && !state.completed && !_stopped,
        updatePosition: state.position,
        bufferedPosition: state.buffer,
        speed: state.rate,
      ),
    );
  }

  @override
  Future<void> play() async => _player?.play();

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> seek(Duration position) async => _player?.seek(position);

  @override
  Future<void> stop() async {
    final player = _player;
    await player?.pause();
    if (_player != player) return;
    _stopped = true;
    _publish();
  }

  @override
  Future<void> onTaskRemoved() => stop();
}

/// All preview controls (including media_kit's video controls) use these methods.
/// Focus is acquired before playing, and a pending play cannot survive a close.
class SessionMediaPlayer extends Player {
  SessionMediaPlayer({
    super.platformPlayer,
    Future<AudioSession> Function()? sessionFactory,
  }) : _sessionFactory = sessionFactory ?? (() => AudioSession.instance) {
    _subscriptions.add(
      stream.completed.listen((completed) {
        if (completed) unawaited(_releaseSession(generation: _generation));
      }),
    );
  }

  static SessionMediaPlayer? _owner;
  static Future<void> _sessionWork = Future<void>.value();

  static Future<void> _serialize(Future<void> Function() action) {
    final work = _sessionWork.then((_) => action());
    _sessionWork = work.catchError((Object _) {});
    return work;
  }

  Future<void> _releaseSession({int? generation}) => _serialize(() async {
    if (_owner != this || (generation != null && generation != _generation)) {
      return;
    }
    _owner = null;
    await _session?.setActive(false);
  });
  final Future<AudioSession> Function() _sessionFactory;
  Future<void>? _sessionPreparation;
  AudioSession? _session;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  int _generation = 0;
  bool _disposed = false;

  Future<void> _prepareSession() => _sessionPreparation ??= _loadSession();

  Future<void> _loadSession() async {
    if (_session != null || !BackgroundMediaHandler.supported) return;
    final session = await _sessionFactory();
    if (_disposed) return;
    _session = session;
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        // Resume is explicit: a call ending must not restart a user-paused clip.
        if (event.begin) unawaited(pause());
      }),
    );
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) => unawaited(pause())),
    );
  }

  @override
  Future<void> play() async {
    final generation = ++_generation;
    await _prepareSession();
    if (_disposed || generation != _generation) return;
    var allowed = true;
    await _serialize(() async {
      if (_disposed || generation != _generation) {
        allowed = false;
        return;
      }
      final session = _session;
      if (session == null) return;
      await session.configure(const AudioSessionConfiguration.music());
      if (_disposed || generation != _generation) {
        allowed = false;
        return;
      }
      allowed = await session.setActive(true);
      if (allowed) _owner = this;
    });
    if (!allowed || _disposed || generation != _generation) return;
    await super.play();
  }

  @override
  Future<void> playOrPause() => state.playing ? pause() : play();

  @override
  Future<void> pause() async {
    final generation = ++_generation;
    await super.pause();
    await _releaseSession(generation: generation);
  }

  @override
  Future<void> stop() async {
    final generation = ++_generation;
    await super.stop();
    await _releaseSession(generation: generation);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    ++_generation;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      await super.dispose();
    } finally {
      await _releaseSession();
    }
  }
}
