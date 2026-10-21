import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../media_feedback/media_feedback_scope.dart';
import '../../media_feedback/state/media_feedback_state.dart';
import '../../media_feedback/widgets/media_feedback_editor.dart';
import '../../media_feedback/widgets/video_feedback_layout.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import 'file_peek_media_controls.dart';
import '../playback/local_media_snapshot.dart';
import '../playback/background_media_handler.dart';

String? resolveFilePeekMediaUrl(String? httpBaseUrl, String? mediaUrl) {
  if (mediaUrl == null || mediaUrl.isEmpty) return null;
  final uri = Uri.tryParse(mediaUrl);
  if (uri == null) return null;
  if (uri.hasScheme) {
    return uri.scheme == 'http' || uri.scheme == 'https'
        ? uri.toString()
        : null;
  }
  final base = httpBaseUrl == null ? null : Uri.tryParse(httpBaseUrl);
  if (base == null || !base.hasScheme) return null;
  return base.resolveUri(uri).toString();
}

bool isFatalFilePeekMediaError(String error) {
  // mpv can report this warning on simulators/headless devices even though
  // video decoding and controls are fully available.
  return !error.contains('Could not open/initialize audio device -> no sound.');
}

double filePeekVideoAspectRatio(VideoParams params) {
  final declaredAspect = params.aspect;
  if (declaredAspect != null && declaredAspect.isFinite && declaredAspect > 0) {
    return declaredAspect;
  }

  final width = params.dw ?? params.w;
  final height = params.dh ?? params.h;
  if (width != null && height != null && width > 0 && height > 0) {
    return width / height;
  }
  return 16 / 9;
}

const filePeekVideoMinimumViewportHeight = 224.0;

double filePeekVideoViewportHeight({
  required double width,
  required double aspectRatio,
  required double maxHeight,
}) {
  final naturalHeight = width / aspectRatio;
  final preferredHeight = math.max(
    naturalHeight,
    filePeekVideoMinimumViewportHeight,
  );
  return maxHeight.isFinite
      ? math.min(preferredHeight, maxHeight)
      : preferredHeight;
}

class FilePeekMediaPreview extends StatefulWidget {
  final String? mediaUrl;
  final bool isVideo;
  final String? formatLabel;
  final MediaFeedbackBinding? feedback;
  final FeedbackMedia? feedbackMedia;

  const FilePeekMediaPreview({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
    this.formatLabel,
    this.feedback,
    this.feedbackMedia,
  });

  @override
  State<FilePeekMediaPreview> createState() => _FilePeekMediaPreviewState();
}

class _FilePeekMediaPreviewState extends State<FilePeekMediaPreview> {
  late final Player _player;
  VideoController? _videoController;
  StreamSubscription<String>? _errorSubscription;
  bool _loading = false;
  bool _failed = false;
  int _openGeneration = 0;
  LocalMediaSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _player = SessionMediaPlayer();
    if (widget.isVideo) _videoController = VideoController(_player);
    _errorSubscription = _player.stream.error.listen((error) {
      if (isFatalFilePeekMediaError(error)) _markFailed();
    });
    unawaited(_open());
  }

  @override
  void didUpdateWidget(FilePeekMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVideo && _videoController == null) {
      _videoController = VideoController(_player);
    }
    if (oldWidget.mediaUrl != widget.mediaUrl ||
        oldWidget.isVideo != widget.isVideo) {
      unawaited(_open());
    }
  }

  Future<void> _open() async {
    final generation = ++_openGeneration;
    final url = widget.mediaUrl;
    final previous = _snapshot;
    final snapshot = widget.isVideo ? LocalMediaSnapshot() : null;
    _snapshot = snapshot;
    try {
      // Stop playback before removing the file it may still be reading.
      BackgroundMediaHandler.instance?.detach(_player);
      await _player.stop();
      await previous?.dispose();
      if (!mounted || generation != _openGeneration) {
        await snapshot?.dispose();
        return;
      }
      if (url == null) {
        if (mounted && generation == _openGeneration) {
          setState(() {
            _loading = false;
            _failed = false;
          });
        }
        return;
      }
      setState(() {
        _loading = true;
        _failed = false;
      });
      await BackgroundMediaHandler.initialize();
      final source = await snapshot?.prepare(url) ?? url;
      if (!mounted || generation != _openGeneration) {
        await snapshot?.dispose();
        return;
      }
      await _player.open(Media(source), play: false);
      if (mounted && generation == _openGeneration) {
        BackgroundMediaHandler.instance?.attach(_player, 'preview-$generation');
        setState(() {
          _loading = false;
          _failed = false;
        });
      }
    } catch (_) {
      if (generation == _openGeneration) _markFailed();
    } finally {
      await previous?.dispose();
    }
  }

  void _markFailed() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = true;
    });
  }

  @override
  void dispose() {
    ++_openGeneration;
    BackgroundMediaHandler.instance?.detach(_player);
    unawaited(_errorSubscription?.cancel());
    final snapshot = _snapshot;
    unawaited(_player.dispose().whenComplete(() => snapshot?.dispose()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrl == null) {
      return const _MediaUnavailable();
    }
    if (_failed) {
      return _MediaLoadError(onRetry: _open);
    }
    if (widget.isVideo) {
      final video = _VideoPreview(
        controller: _videoController!,
        loading: _loading,
      );
      if (_loading || widget.feedback == null || widget.feedbackMedia == null) {
        return video;
      }
      return VideoFeedbackLayout(
        video: video,
        feedback: MediaFeedbackEditor(
          key: ValueKey(widget.feedbackMedia!.key),
          binding: widget.feedback!,
          media: widget.feedbackMedia!,
          position: () => _player.state.position,
          onPause: () => unawaited(_player.pause()),
          onSeek: (position) => unawaited(_player.seek(position)),
        ),
      );
    }
    return _AudioPreview(
      player: _player,
      loading: _loading,
      formatLabel: widget.formatLabel,
    );
  }
}

class _VideoPreview extends StatelessWidget {
  final VideoController controller;
  final bool loading;

  const _VideoPreview({required this.controller, required this.loading});

  @override
  Widget build(BuildContext context) {
    return FilePeekVideoControlsTheme(
      player: controller.player,
      child: ColoredBox(
        key: const ValueKey('file_peek_video_player'),
        color: Colors.black,
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          minimum: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: StreamBuilder<VideoParams>(
              stream: controller.player.stream.videoParams,
              initialData: controller.player.state.videoParams,
              builder: (context, snapshot) {
                final aspectRatio = filePeekVideoAspectRatio(
                  snapshot.data ?? const VideoParams(),
                );
                return LayoutBuilder(
                  key: const ValueKey('file_peek_video_viewport'),
                  builder: (context, constraints) {
                    final height = filePeekVideoViewportHeight(
                      width: constraints.maxWidth,
                      aspectRatio: aspectRatio,
                      maxHeight: constraints.maxHeight,
                    );
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: height,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Video(
                            controller: controller,
                            pauseUponEnteringBackgroundMode: false,
                            fit: BoxFit.contain,
                            aspectRatio: aspectRatio,
                          ),
                          if (loading)
                            const CircularProgressIndicator.adaptive(),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioPreview extends StatelessWidget {
  final Player player;
  final bool loading;
  final String? formatLabel;

  const _AudioPreview({
    required this.player,
    required this.loading,
    required this.formatLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primaryContainer,
                          colors.secondaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 56,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formatLabel ?? 'AUDIO',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (loading) const LinearProgressIndicator(),
                  if (!loading) FilePeekAudioControls(player: player),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaUnavailable extends StatelessWidget {
  const _MediaUnavailable();

  @override
  Widget build(BuildContext context) {
    return _MediaMessage(
      icon: Icons.play_disabled_outlined,
      message: AppLocalizations.of(context).filePreviewMediaUnavailable,
    );
  }
}

class _MediaLoadError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _MediaLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _MediaMessage(
      icon: Icons.error_outline,
      message: AppLocalizations.of(context).filePreviewMediaLoadFailed,
      action: FilledButton.tonalIcon(
        key: const ValueKey('file_peek_media_retry_button'),
        onPressed: () => unawaited(onRetry()),
        icon: const Icon(Icons.refresh),
        label: Text(AppLocalizations.of(context).retry),
      ),
    );
  }
}

class _MediaMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _MediaMessage({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: appColors.subtleText),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: appColors.subtleText),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
