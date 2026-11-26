import 'package:material_ui/material_ui.dart';

/// Pinch / double-tap zoom shared by every image preview.
///
/// - Fills the available area so a zoomed image can use all of it.
/// - Double tap zooms to 2.5x around the tapped point, and back to fit.
/// - Reports zoom state changes (`scale > 1.01`) via [onZoomChanged] so a parent
///   [PageView] can lock scrolling with [NeverScrollableScrollPhysics] only
///   while zoomed and allow smooth finger-tracking swipes when unzoomed.
/// - A drag while not zoomed springs back to fit. When [onSwipePrevious] /
///   [onSwipeNext] are provided, a horizontal swipe while unzoomed invokes them.
class ZoomableImageViewer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onSwipePrevious;
  final VoidCallback? onSwipeNext;
  final ValueChanged<bool>? onZoomChanged;
  final double minScale;

  const ZoomableImageViewer({
    super.key,
    required this.child,
    this.onTap,
    this.onSwipePrevious,
    this.onSwipeNext,
    this.onZoomChanged,
    this.minScale = 0.5,
  });

  static const doubleTapScale = 2.5;
  static const maxScale = 5.0;
  static const zoomThreshold = 1.01;

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
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformationChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_applyAnimation);
  }

  @override
  void dispose() {
    _transformationController
      ..removeListener(_handleTransformationChanged)
      ..dispose();
    _animationController
      ..removeListener(_applyAnimation)
      ..dispose();
    super.dispose();
  }

  void _handleTransformationChanged() {
    final zoomed =
        _transformationController.value.getMaxScaleOnAxis() >
        ZoomableImageViewer.zoomThreshold;
    if (zoomed == _isZoomed) return;
    _isZoomed = zoomed;
    widget.onZoomChanged?.call(zoomed);
    if (widget.onZoomChanged != null && mounted) {
      setState(() {});
    }
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
    final endMatrix = currentScale > ZoomableImageViewer.zoomThreshold
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
    if (scale <= ZoomableImageViewer.zoomThreshold &&
        _transformationController.value != Matrix4.identity()) {
      _animateTo(Matrix4.identity());
    }

    if (start == null ||
        latest == null ||
        _scaledDuringInteraction ||
        scale > 1.1) {
      return;
    }

    if (widget.onSwipeNext == null && widget.onSwipePrevious == null) return;

    final delta = latest - start;
    final velocity = details.velocity.pixelsPerSecond;
    final horizontalIntent =
        delta.dx.abs() > 64 && delta.dx.abs() > delta.dy.abs() * 1.15;
    final horizontalFling =
        velocity.dx.abs() > 450 && velocity.dx.abs() > velocity.dy.abs() * 1.15;

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
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) {
    final allowUnzoomedPan =
        widget.onZoomChanged == null ||
        widget.onSwipePrevious != null ||
        widget.onSwipeNext != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: SizedBox.expand(
        child: InteractiveViewer(
          transformationController: _transformationController,
          panEnabled: allowUnzoomedPan || _isZoomed,
          minScale: widget.minScale,
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
