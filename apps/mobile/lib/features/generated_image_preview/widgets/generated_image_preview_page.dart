import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../generated_image_preview_item.dart';

const _cacheMaxAge = Duration(days: 7);

class GeneratedImagePreviewPage extends StatefulWidget {
  final GeneratedImagePreviewItem item;
  final VoidCallback onTap;
  final VoidCallback? onSwipePrevious;
  final VoidCallback? onSwipeNext;

  const GeneratedImagePreviewPage({
    super.key,
    required this.item,
    required this.onTap,
    this.onSwipePrevious,
    this.onSwipeNext,
  });

  @override
  State<GeneratedImagePreviewPage> createState() =>
      _GeneratedImagePreviewPageState();
}

class _GeneratedImagePreviewPageState extends State<GeneratedImagePreviewPage>
    with SingleTickerProviderStateMixin {
  final _transformationController = TransformationController();
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;
  Offset? _interactionStart;
  Offset? _interactionLatest;
  bool _scaledDuringInteraction = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_applyAnimation);
  }

  @override
  void dispose() {
    _animationController
      ..removeListener(_applyAnimation)
      ..dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _applyAnimation() {
    final animation = _animation;
    if (animation != null) {
      _transformationController.value = animation.value;
    }
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final endMatrix = currentScale > 1.1
        ? Matrix4.identity()
        : _zoomedMatrix(position);

    _animateTo(endMatrix);
  }

  void _animateTo(Matrix4 endMatrix) {
    _animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: endMatrix,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward(from: 0);
  }

  void _handleInteractionStart(ScaleStartDetails details) {
    _animationController.stop();
    _animation = null;
    _interactionStart = details.focalPoint;
    _interactionLatest = details.focalPoint;
    _scaledDuringInteraction = false;
  }

  void _handleInteractionUpdate(ScaleUpdateDetails details) {
    _interactionLatest = details.focalPoint;
    if ((details.scale - 1).abs() > 0.02) {
      _scaledDuringInteraction = true;
    }
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    final start = _interactionStart;
    final latest = _interactionLatest;
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (start == null ||
        latest == null ||
        _scaledDuringInteraction ||
        scale > 1.1) {
      return;
    }

    final delta = latest - start;
    final velocity = details.velocity.pixelsPerSecond;
    final horizontalIntent =
        delta.dx.abs() > 64 && delta.dx.abs() > delta.dy.abs() * 1.15;
    final horizontalFling =
        velocity.dx.abs() > 450 && velocity.dx.abs() > velocity.dy.abs() * 1.15;

    _animateTo(Matrix4.identity());
    if (!horizontalIntent && !horizontalFling) return;

    final direction = horizontalIntent ? delta.dx : velocity.dx;
    if (direction < 0) {
      widget.onSwipeNext?.call();
    } else {
      widget.onSwipePrevious?.call();
    }
  }

  Matrix4 _zoomedMatrix(Offset position) {
    const scale = 2.5;
    final dx = -position.dx * (scale - 1);
    final dy = -position.dy * (scale - 1);
    // ignore: deprecated_member_use
    return Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(dx, dy)
      // ignore: deprecated_member_use
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.item.prompt,
      child: GestureDetector(
        key: ValueKey('generated_image_page_${widget.item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 5,
          onInteractionStart: _handleInteractionStart,
          onInteractionUpdate: _handleInteractionUpdate,
          onInteractionEnd: _handleInteractionEnd,
          child: Center(child: _GeneratedImage(item: widget.item)),
        ),
      ),
    );
  }
}

class _GeneratedImage extends StatelessWidget {
  final GeneratedImagePreviewItem item;

  const _GeneratedImage({required this.item});

  @override
  Widget build(BuildContext context) {
    final bytes = item.bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _ImageLoadFailure(),
      );
    }

    return ExtendedImage.network(
      item.url!,
      fit: BoxFit.contain,
      cache: true,
      cacheKey: item.cacheKey,
      cacheMaxAge: _cacheMaxAge,
      loadStateChanged: (state) {
        return switch (state.extendedImageLoadState) {
          LoadState.loading => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          LoadState.completed => state.completedWidget,
          LoadState.failed => const _ImageLoadFailure(),
        };
      },
    );
  }
}

class _ImageLoadFailure extends StatelessWidget {
  const _ImageLoadFailure();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
        const SizedBox(height: 10),
        Text(
          AppLocalizations.of(context).failedToLoadImage,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
