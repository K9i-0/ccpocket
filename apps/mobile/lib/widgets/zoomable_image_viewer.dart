import 'package:flutter/material.dart';

/// Pinch / double-tap zoom shared by every image preview.
///
/// - Fills the available area so a zoomed image can use all of it.
/// - Double tap zooms to 2.5x around the tapped point, and back to fit.
/// - A drag while not zoomed springs back to fit. When not zoomed, a horizontal swipe calls [onSwipePrevious] /
///   [onSwipeNext] (for viewers that page between images).
class ZoomableImageViewer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onSwipePrevious;
  final VoidCallback? onSwipeNext;

  const ZoomableImageViewer({
    super.key,
    required this.child,
    this.onTap,
    this.onSwipePrevious,
    this.onSwipeNext,
  });

  static const doubleTapScale = 2.5;
  static const maxScale = 5.0;

  @override
  State<ZoomableImageViewer> createState() => _ZoomableImageViewerState();
}

class _ZoomableImageViewerState extends State<ZoomableImageViewer>
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
    const scale = ZoomableImageViewer.doubleTapScale;
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: SizedBox.expand(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: ZoomableImageViewer.maxScale,
          onInteractionStart: _handleInteractionStart,
          onInteractionUpdate: _handleInteractionUpdate,
          onInteractionEnd: _handleInteractionEnd,
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
