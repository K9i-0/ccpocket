import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../l10n/app_localizations.dart';
import 'file_peek_media_controls.dart';

/// Height reserved for the seek bar and the bottom button row.
///
/// The controls are laid out in a [Column], so the centered transport can
/// never overlap the seek bar regardless of the viewport size.
const filePeekVideoBottomControlsHeight = 88.0;

/// Minimum free height above the bottom controls that still fits the
/// centered transport (play/pause and ±10s).
const filePeekVideoCenterTransportMinHeight = 56.0;

/// Whether the viewport is too short for a centered transport. In compact mode
/// play/pause moves into the bottom row and the ±10s buttons are omitted.
bool filePeekVideoControlsCompact(double height) =>
    height - filePeekVideoBottomControlsHeight <
    filePeekVideoCenterTransportMinHeight;

/// Width of the desktop volume slider next to the mute button.
const filePeekVideoVolumeSliderWidth = 88.0;

/// Desktop platforms have no hardware volume keys, so they get a slider in
/// addition to mute. Narrow rows keep only the mute button.
bool filePeekVideoShowsVolumeSlider({
  required TargetPlatform platform,
  required double rowWidth,
}) =>
    switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    } &&
    rowWidth >= 360;

/// Height of the single-row layout used when even the seek bar and bottom row
/// do not fit (e.g. landscape with the keyboard open).
const filePeekVideoMinimalControlsHeight = 48.0;

/// Whether only a single row (play, seek bar, fullscreen) fits.
bool filePeekVideoControlsMinimal(double height) =>
    height < filePeekVideoBottomControlsHeight;

/// Size of the centered play button, scaled to the free space above the
/// bottom controls.
double filePeekVideoPlayButtonSize(double height) => math
    .min(64.0, height - filePeekVideoBottomControlsHeight - 8)
    .clamp(filePeekVideoCenterTransportMinHeight - 8, 64.0);

/// [Video.controls] builder shared by the inline and fullscreen video views.
Widget filePeekVideoControlsBuilder(VideoState state) =>
    FilePeekVideoControls(player: state.widget.controller.player);

class FilePeekVideoControls extends StatefulWidget {
  final Player player;
  final Duration hideDelay;

  const FilePeekVideoControls({
    super.key,
    required this.player,
    this.hideDelay = const Duration(seconds: 3),
  });

  @override
  State<FilePeekVideoControls> createState() => _FilePeekVideoControlsState();
}

class _FilePeekVideoControlsState extends State<FilePeekVideoControls> {
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _hideTimer;
  bool _visible = true;
  late bool _playing = widget.player.state.playing;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(FilePeekVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _unsubscribe();
      _playing = widget.player.state.playing;
      _subscribe();
    }
  }

  void _subscribe() {
    _subscriptions.add(
      widget.player.stream.playing.listen((playing) {
        if (!mounted) return;
        setState(() => _playing = playing);
        if (playing) {
          _scheduleHide();
        } else {
          _show();
        }
      }),
    );
  }

  void _unsubscribe() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _unsubscribe();
    super.dispose();
  }

  void _show() {
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_playing) return;
    _hideTimer = Timer(widget.hideDelay, () {
      if (mounted && _playing) setState(() => _visible = false);
    });
  }

  void _toggleVisible() {
    if (_visible && _playing) {
      _hideTimer?.cancel();
      setState(() => _visible = false);
    } else {
      _show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullscreen = isFullscreen(context);
    return MouseRegion(
      onHover: (_) => _show(),
      onExit: (_) => _scheduleHide(),
      child: Listener(
        // Any interaction with a control keeps the controls on screen.
        onPointerDown: (_) => _scheduleHide(),
        child: GestureDetector(
          key: const ValueKey('file_peek_video_controls'),
          behavior: HitTestBehavior.opaque,
          onTap: _toggleVisible,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _BufferingIndicator(player: widget.player),
              IgnorePointer(
                ignoring: !_visible,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: SafeArea(
                    top: fullscreen,
                    bottom: fullscreen,
                    left: fullscreen,
                    right: fullscreen,
                    child: _ControlsLayout(
                      player: widget.player,
                      fullscreen: fullscreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlsLayout extends StatelessWidget {
  final Player player;
  final bool fullscreen;

  const _ControlsLayout({required this.player, required this.fullscreen});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = filePeekVideoControlsCompact(constraints.maxHeight);
        final minimal = filePeekVideoControlsMinimal(constraints.maxHeight);
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.45, 1],
              colors: [Color(0x33000000), Color(0x22000000), Color(0x99000000)],
            ),
          ),
          child: minimal
              ? ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.bottomCenter,
                    minHeight: filePeekVideoMinimalControlsHeight,
                    maxHeight: filePeekVideoMinimalControlsHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                      child: _MinimalBar(
                        player: player,
                        fullscreen: fullscreen,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: compact
                          ? const SizedBox.shrink()
                          : Center(
                              child: _CenterTransport(
                                player: player,
                                playSize: filePeekVideoPlayButtonSize(
                                  constraints.maxHeight,
                                ),
                              ),
                            ),
                    ),
                    SizedBox(
                      height: filePeekVideoBottomControlsHeight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 36,
                              child: _VideoSeekBar(player: player),
                            ),
                            Expanded(
                              child: _BottomBar(
                                player: player,
                                compact: compact,
                                fullscreen: fullscreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CenterTransport extends StatelessWidget {
  final Player player;
  final double playSize;

  const _CenterTransport({required this.player, required this.playSize});

  @override
  Widget build(BuildContext context) {
    final seekSize = math.max(40.0, playSize * 0.72);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SeekButton(player: player, backwards: true, size: seekSize),
        SizedBox(width: playSize * 0.5),
        _PlayButton(player: player, size: playSize),
        SizedBox(width: playSize * 0.5),
        _SeekButton(player: player, backwards: false, size: seekSize),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final Player player;
  final bool compact;
  final bool fullscreen;

  const _BottomBar({
    required this.player,
    required this.compact,
    required this.fullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          if (compact) _PlayButton(player: player, size: 40, filled: false),
          _VolumeControl(
            player: player,
            showSlider: filePeekVideoShowsVolumeSlider(
              platform: defaultTargetPlatform,
              rowWidth: constraints.maxWidth,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: _PositionLabel(player: player)),
          FilePeekPlaybackRateMenu(
            player: player,
            onDarkSurface: true,
            compact: true,
          ),
          _FullscreenButton(fullscreen: fullscreen),
        ],
      ),
    );
  }
}

class _MinimalBar extends StatelessWidget {
  final Player player;
  final bool fullscreen;

  const _MinimalBar({required this.player, required this.fullscreen});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PlayButton(player: player, size: 40, filled: false),
        Expanded(child: _VideoSeekBar(player: player)),
        _FullscreenButton(fullscreen: fullscreen),
      ],
    );
  }
}

const _controlShadows = [
  Shadow(color: Colors.black, blurRadius: 2),
  Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
];

class _PlayButton extends StatelessWidget {
  final Player player;
  final double size;
  final bool filled;

  const _PlayButton({
    required this.player,
    required this.size,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;
        final label = playing ? l10n.filePreviewPause : l10n.filePreviewPlay;
        return _RoundButton(
          key: const ValueKey('file_peek_video_play_button'),
          tooltip: label,
          size: size,
          filled: filled,
          onPressed: () => unawaited(_playOrPause(player)),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(playing),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _playOrPause(Player player) async {
  if (player.state.playing) return player.pause();
  final duration = player.state.duration;
  if (player.state.completed ||
      (duration > Duration.zero && player.state.position >= duration)) {
    await player.seek(Duration.zero);
  }
  await player.play();
}

class _SeekButton extends StatelessWidget {
  final Player player;
  final bool backwards;
  final double size;

  const _SeekButton({
    required this.player,
    required this.backwards,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _RoundButton(
      key: ValueKey(
        backwards
            ? 'file_peek_video_rewind_button'
            : 'file_peek_video_forward_button',
      ),
      tooltip: backwards ? l10n.filePreviewRewind10 : l10n.filePreviewForward10,
      size: size,
      filled: false,
      onPressed: () => _seekBy(player, backwards ? -10 : 10),
      icon: Icon(
        backwards ? Icons.replay_10_rounded : Icons.forward_10_rounded,
      ),
    );
  }
}

void _seekBy(Player player, int seconds) {
  unawaited(
    player.seek(
      filePeekSeekTarget(
        position: player.state.position,
        duration: player.state.duration,
        offset: Duration(seconds: seconds),
      ),
    ),
  );
}

class _VolumeControl extends StatefulWidget {
  final Player player;
  final bool showSlider;

  const _VolumeControl({required this.player, required this.showSlider});

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  /// Volume restored by unmute, so muting does not lose the slider level.
  double _restoreVolume = 100;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final player = widget.player;
    final accent = Theme.of(context).colorScheme.primary;
    return StreamBuilder<double>(
      stream: player.stream.volume,
      initialData: player.state.volume,
      builder: (context, snapshot) {
        final volume = (snapshot.data ?? 100).clamp(0, 100).toDouble();
        final muted = volume <= 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundButton(
              key: const ValueKey('file_peek_video_volume_button'),
              tooltip: muted ? l10n.filePreviewUnmute : l10n.filePreviewMute,
              size: 40,
              filled: false,
              onPressed: () {
                if (!muted) _restoreVolume = volume;
                unawaited(player.setVolume(muted ? _restoreVolume : 0));
              },
              icon: Icon(
                muted
                    ? Icons.volume_off_rounded
                    : volume < 50
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
              ),
            ),
            if (widget.showSlider)
              SizedBox(
                width: filePeekVideoVolumeSliderWidth,
                height: 36,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: accent.withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Slider(
                    key: const ValueKey('file_peek_video_volume_slider'),
                    value: volume,
                    max: 100,
                    semanticFormatterCallback: (value) =>
                        '${l10n.filePreviewVolume} ${value.round()}%',
                    onChanged: (next) {
                      if (next > 0) _restoreVolume = next;
                      unawaited(player.setVolume(next));
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FullscreenButton extends StatelessWidget {
  final bool fullscreen;

  const _FullscreenButton({required this.fullscreen});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _RoundButton(
      key: const ValueKey('file_peek_video_fullscreen_button'),
      tooltip: fullscreen
          ? l10n.filePreviewExitFullscreen
          : l10n.filePreviewFullscreen,
      size: 40,
      filled: false,
      onPressed: () => unawaited(toggleFullscreen(context)),
      icon: Icon(
        fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final String tooltip;
  final double size;
  final bool filled;
  final VoidCallback onPressed;
  final Widget icon;

  const _RoundButton({
    super.key,
    required this.tooltip,
    required this.size,
    required this.filled,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: size * (filled ? 0.62 : 0.6),
        color: Colors.white,
        style: IconButton.styleFrom(
          backgroundColor: filled ? const Color(0x99000000) : null,
          foregroundColor: Colors.white,
          side: filled ? const BorderSide(color: Colors.white30) : null,
          shape: const CircleBorder(),
          minimumSize: Size.square(size),
          maximumSize: Size.square(size),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        icon: IconTheme.merge(
          data: const IconThemeData(shadows: _controlShadows),
          child: icon,
        ),
      ),
    );
  }
}

class _PositionLabel extends StatelessWidget {
  final Player player;

  const _PositionLabel({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.duration,
      initialData: player.state.duration,
      builder: (context, durationSnapshot) => StreamBuilder<Duration>(
        stream: player.stream.position,
        initialData: player.state.position,
        builder: (context, positionSnapshot) {
          final position = formatFilePeekMediaDuration(
            positionSnapshot.data ?? Duration.zero,
          );
          final duration = formatFilePeekMediaDuration(
            durationSnapshot.data ?? Duration.zero,
          );
          return Text(
            '$position / $duration',
            key: const ValueKey('file_peek_video_position_label'),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
              shadows: _controlShadows,
            ),
          );
        },
      ),
    );
  }
}

class _VideoSeekBar extends StatefulWidget {
  final Player player;

  const _VideoSeekBar({required this.player});

  @override
  State<_VideoSeekBar> createState() => _VideoSeekBarState();
}

class _VideoSeekBarState extends State<_VideoSeekBar> {
  /// Position under the user's finger while dragging. Player position updates
  /// are ignored meanwhile so the thumb does not jump back.
  double? _dragMillis;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final accent = Theme.of(context).colorScheme.primary;
    return StreamBuilder<Duration>(
      stream: player.stream.duration,
      initialData: player.state.duration,
      builder: (context, durationSnapshot) => StreamBuilder<Duration>(
        stream: player.stream.position,
        initialData: player.state.position,
        builder: (context, positionSnapshot) => StreamBuilder<Duration>(
          stream: player.stream.buffer,
          initialData: player.state.buffer,
          builder: (context, bufferSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final maxMillis = math.max(1, duration.inMilliseconds).toDouble();
            double clampMillis(Duration? value) => (value ?? Duration.zero)
                .inMilliseconds
                .clamp(0, maxMillis)
                .toDouble();
            final value = _dragMillis ?? clampMillis(positionSnapshot.data);
            return SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: accent,
                inactiveTrackColor: Colors.white24,
                secondaryActiveTrackColor: Colors.white54,
                thumbColor: accent,
                overlayColor: accent.withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Slider(
                key: const ValueKey('file_peek_video_seek_bar'),
                value: value,
                secondaryTrackValue: clampMillis(bufferSnapshot.data),
                max: maxMillis,
                semanticFormatterCallback: (next) =>
                    formatFilePeekMediaDuration(
                      Duration(milliseconds: next.round()),
                    ),
                onChangeStart: (next) => setState(() => _dragMillis = next),
                onChanged: duration == Duration.zero
                    ? null
                    : (next) => setState(() => _dragMillis = next),
                onChangeEnd: (next) {
                  setState(() => _dragMillis = null);
                  unawaited(player.seek(Duration(milliseconds: next.round())));
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BufferingIndicator extends StatelessWidget {
  final Player player;

  const _BufferingIndicator({required this.player});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: StreamBuilder<bool>(
        stream: player.stream.buffering,
        initialData: player.state.buffering,
        builder: (context, snapshot) => snapshot.data ?? false
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 3,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
