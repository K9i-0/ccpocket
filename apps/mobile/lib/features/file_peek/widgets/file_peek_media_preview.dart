import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import 'file_peek_media_controls.dart';

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

class FilePeekMediaPreview extends StatefulWidget {
  final String? mediaUrl;
  final bool isVideo;

  const FilePeekMediaPreview({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
  });

  @override
  State<FilePeekMediaPreview> createState() => _FilePeekMediaPreviewState();
}

class _FilePeekMediaPreviewState extends State<FilePeekMediaPreview>
    with WidgetsBindingObserver {
  late final Player _player;
  VideoController? _videoController;
  StreamSubscription<String>? _errorSubscription;
  bool _loading = false;
  bool _failed = false;
  int _openGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = Player();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_player.pause());
  }

  Future<void> _open() async {
    final generation = ++_openGeneration;
    final url = widget.mediaUrl;
    if (url == null) {
      await _player.stop();
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
    try {
      await _player.open(Media(url), play: false);
      if (mounted && generation == _openGeneration) {
        setState(() {
          _loading = false;
          _failed = false;
        });
      }
    } catch (_) {
      if (generation == _openGeneration) _markFailed();
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
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_errorSubscription?.cancel());
    unawaited(_player.dispose());
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
      return _VideoPreview(controller: _videoController!, loading: _loading);
    }
    return _AudioPreview(player: _player, loading: _loading);
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            Video(controller: controller, fit: BoxFit.contain),
            if (loading) const CircularProgressIndicator.adaptive(),
          ],
        ),
      ),
    );
  }
}

class _AudioPreview extends StatelessWidget {
  final Player player;
  final bool loading;

  const _AudioPreview({required this.player, required this.loading});

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
                    'WAV',
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
