import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

import '../../../l10n/app_localizations.dart';

// Keep controls legible over both bright frames and black letterboxing.
const _videoControlBackground = Color(0xB3000000);
const _videoControlShadows = [
  Shadow(color: Colors.black, blurRadius: 2),
  Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
];
const filePeekPlaybackRates = <double>[0.5, 1.0, 1.5, 2.0];

Duration filePeekSeekTarget({
  required Duration position,
  required Duration duration,
  required Duration offset,
}) {
  final target = math.max(0, position.inMilliseconds + offset.inMilliseconds);
  final bounded = duration > Duration.zero
      ? math.min(target, duration.inMilliseconds)
      : target;
  return Duration(milliseconds: bounded);
}

String formatFilePeekMediaDuration(Duration duration) {
  final totalSeconds = math.max(0, duration.inSeconds);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final suffix =
      '${minutes.toString().padLeft(hours > 0 ? 2 : 1, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
  return hours > 0 ? '$hours:$suffix' : suffix;
}

class FilePeekAudioControls extends StatelessWidget {
  final Player player;

  const FilePeekAudioControls({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AudioTransport(player: player),
        const SizedBox(height: 20),
        _MediaTimeline(player: player),
        const SizedBox(height: 12),
        _AudioOptions(player: player),
      ],
    );
  }
}

class _AudioTransport extends StatelessWidget {
  final Player player;

  const _AudioTransport({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AudioSeekButton(player: player, backwards: true),
        const SizedBox(width: 16),
        StreamBuilder<bool>(
          stream: player.stream.playing,
          initialData: player.state.playing,
          builder: (context, snapshot) => _AudioPlayButton(
            playing: snapshot.data ?? false,
            onPressed: player.playOrPause,
          ),
        ),
        const SizedBox(width: 16),
        _AudioSeekButton(player: player, backwards: false),
      ],
    );
  }
}

class _AudioPlayButton extends StatelessWidget {
  final bool playing;
  final Future<void> Function() onPressed;

  const _AudioPlayButton({required this.playing, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = playing ? l10n.filePreviewPause : l10n.filePreviewPlay;
    return Semantics(
      button: true,
      label: label,
      child: IconButton.filled(
        key: const ValueKey('file_peek_audio_play_button'),
        tooltip: label,
        iconSize: 40,
        padding: const EdgeInsets.all(16),
        onPressed: () => unawaited(onPressed()),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(playing),
          ),
        ),
      ),
    );
  }
}

class _AudioSeekButton extends StatelessWidget {
  final Player player;
  final bool backwards;

  const _AudioSeekButton({required this.player, required this.backwards});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = backwards
        ? l10n.filePreviewRewind10
        : l10n.filePreviewForward10;
    return IconButton.outlined(
      key: ValueKey(
        backwards
            ? 'file_peek_audio_rewind_button'
            : 'file_peek_audio_forward_button',
      ),
      tooltip: label,
      iconSize: 28,
      padding: const EdgeInsets.all(12),
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

class _MediaTimeline extends StatelessWidget {
  final Player player;

  const _MediaTimeline({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.duration,
      initialData: player.state.duration,
      builder: (context, durationSnapshot) => StreamBuilder<Duration>(
        stream: player.stream.position,
        initialData: player.state.position,
        builder: (context, positionSnapshot) => StreamBuilder<Duration>(
          stream: player.stream.buffer,
          initialData: player.state.buffer,
          builder: (context, bufferSnapshot) => _TimelineView(
            duration: durationSnapshot.data ?? Duration.zero,
            position: positionSnapshot.data ?? Duration.zero,
            buffer: bufferSnapshot.data ?? Duration.zero,
            onSeek: player.seek,
          ),
        ),
      ),
    );
  }
}

class _TimelineView extends StatelessWidget {
  final Duration duration;
  final Duration position;
  final Duration buffer;
  final Future<void> Function(Duration) onSeek;

  const _TimelineView({
    required this.duration,
    required this.position,
    required this.buffer,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final maxMillis = math.max(1, duration.inMilliseconds);
    final value = position.inMilliseconds.clamp(0, maxMillis).toDouble();
    final buffered = buffer.inMilliseconds.clamp(0, maxMillis) / maxMillis;
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: buffered,
                  color: colors.primary.withValues(alpha: 0.28),
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                inactiveTrackColor: Colors.transparent,
                activeTrackColor: colors.primary,
                thumbColor: colors.primary,
                overlayColor: colors.primary.withValues(alpha: 0.12),
              ),
              child: Slider(
                key: const ValueKey('file_peek_audio_seek_slider'),
                value: value,
                max: maxMillis.toDouble(),
                semanticFormatterCallback: (next) =>
                    formatFilePeekMediaDuration(
                      Duration(milliseconds: next.round()),
                    ),
                onChanged: duration == Duration.zero
                    ? null
                    : (next) => unawaited(
                        onSeek(Duration(milliseconds: next.round())),
                      ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DurationLabel(duration: position),
              _DurationLabel(duration: duration),
            ],
          ),
        ),
      ],
    );
  }
}

class _DurationLabel extends StatelessWidget {
  final Duration duration;

  const _DurationLabel({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Text(
      formatFilePeekMediaDuration(duration),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _AudioOptions extends StatelessWidget {
  final Player player;

  const _AudioOptions({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _AudioVolumeControl(player: player)),
        const SizedBox(width: 12),
        FilePeekPlaybackRateMenu(player: player),
      ],
    );
  }
}

class _AudioVolumeControl extends StatelessWidget {
  final Player player;

  const _AudioVolumeControl({required this.player});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<double>(
      stream: player.stream.volume,
      initialData: player.state.volume,
      builder: (context, snapshot) {
        final volume = (snapshot.data ?? 100).clamp(0, 100).toDouble();
        final muted = volume == 0;
        return Row(
          children: [
            IconButton(
              key: const ValueKey('file_peek_audio_mute_button'),
              tooltip: muted ? l10n.filePreviewUnmute : l10n.filePreviewMute,
              onPressed: () => unawaited(player.setVolume(muted ? 100 : 0)),
              icon: Icon(
                muted
                    ? Icons.volume_off_rounded
                    : volume < 50
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
              ),
            ),
            Expanded(
              child: Slider(
                key: const ValueKey('file_peek_audio_volume_slider'),
                value: volume,
                max: 100,
                semanticFormatterCallback: (value) =>
                    '${l10n.filePreviewVolume} ${value.round()}%',
                onChanged: (next) => unawaited(player.setVolume(next)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FilePeekPlaybackRateMenu extends StatelessWidget {
  final Player player;
  final bool onDarkSurface;
  final bool compact;

  const FilePeekPlaybackRateMenu({
    super.key,
    required this.player,
    this.onDarkSurface = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<double>(
      stream: player.stream.rate,
      initialData: player.state.rate,
      builder: (context, snapshot) {
        final rate = snapshot.data ?? 1;
        return PopupMenuButton<double>(
          key: ValueKey(
            onDarkSurface
                ? 'file_peek_video_speed_button'
                : 'file_peek_audio_speed_button',
          ),
          tooltip: l10n.filePreviewPlaybackSpeed,
          initialValue: rate,
          itemBuilder: (_) => [
            for (final value in filePeekPlaybackRates)
              PopupMenuItem(
                key: ValueKey('file_peek_speed_${value.g}_item'),
                value: value,
                // Video controls can unmount while this route remains open.
                // PopupMenuButton.onSelected ignores results once unmounted.
                onTap: () => unawaited(player.setRate(value)),
                child: Text('${value.g}×'),
              ),
          ],
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: onDarkSurface
                  ? _videoControlBackground
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: onDarkSurface
                    ? Colors.white24
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              '${rate.g}×',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: onDarkSurface ? Colors.white : null,
                fontWeight: FontWeight.w700,
                shadows: onDarkSurface ? _videoControlShadows : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      },
    );
  }
}

extension on double {
  String get g => this == roundToDouble() ? toInt().toString() : toString();
}
