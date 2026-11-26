import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// A horizontal [PageView] that sizes itself to the measured height of its
/// current page and smoothly interpolates height while scrolling between pages.
class ExpandablePageView extends StatefulWidget {
  const ExpandablePageView.builder({
    super.key,
    this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
    this.physics,
    this.pageSnapping = true,
    this.clipBehavior = Clip.hardEdge,
    this.padEnds = true,
  });

  final PageController? controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onPageChanged;
  final ScrollPhysics? physics;
  final bool pageSnapping;
  final Clip clipBehavior;
  final bool padEnds;

  @override
  State<ExpandablePageView> createState() => _ExpandablePageViewState();
}

class _ExpandablePageViewState extends State<ExpandablePageView> {
  PageController? _ownController;
  final Map<int, double> _heights = {};
  double _lastKnownHeight = 0;

  PageController get _controller => widget.controller ?? _ownController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownController = PageController();
    }
  }

  @override
  void didUpdateWidget(covariant ExpandablePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == null && widget.controller != null) {
      _ownController?.dispose();
      _ownController = null;
    } else if (oldWidget.controller != null && widget.controller == null) {
      _ownController = PageController();
    }
    if (widget.itemCount < oldWidget.itemCount) {
      _heights.removeWhere((index, _) => index >= widget.itemCount);
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  void _updateHeight(int index, double height) {
    if (!mounted || _heights[index] == height) return;
    setState(() {
      _heights[index] = height;
    });
  }

  double _resolveHeight() {
    final maxIndex = (widget.itemCount - 1).toDouble();
    final rawPage =
        _controller.positions.length == 1 &&
            _controller.position.hasContentDimensions
        ? (_controller.page ?? _controller.initialPage.toDouble())
        : _controller.initialPage.toDouble();
    final page = rawPage.clamp(0.0, maxIndex);
    final floorIndex = page.floor();
    final ceilIndex = page.ceil();
    final floorHeight = _heights[floorIndex] ?? _lastKnownHeight;
    final ceilHeight = _heights[ceilIndex] ?? floorHeight;
    final t = page - floorIndex;
    final height = floorHeight + (ceilHeight - floorHeight) * t;
    if (height > 0) _lastKnownHeight = height;
    return height;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) return const SizedBox.shrink();

    final pageView = PageView.builder(
      controller: _controller,
      itemCount: widget.itemCount,
      onPageChanged: widget.onPageChanged,
      physics: widget.physics,
      pageSnapping: widget.pageSnapping,
      clipBehavior: widget.clipBehavior,
      padEnds: widget.padEnds,
      itemBuilder: (context, index) => OverflowBox(
        minHeight: 0,
        maxHeight: double.infinity,
        alignment: Alignment.topCenter,
        child: _MeasureHeight(
          onChange: (height) => _updateHeight(index, height),
          child: widget.itemBuilder(context, index),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          SizedBox(height: _resolveHeight(), child: child),
      child: pageView,
    );
  }
}

class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onChange, super.child});

  final ValueChanged<double> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureHeightRenderObject(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _MeasureHeightRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureHeightRenderObject extends RenderProxyBox {
  _MeasureHeightRenderObject(this.onChange);

  ValueChanged<double> onChange;
  double? _lastHeight;

  @override
  void performLayout() {
    super.performLayout();
    final height = child?.size.height;
    if (height == null || _lastHeight == height) return;
    _lastHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(height);
    });
  }
}
