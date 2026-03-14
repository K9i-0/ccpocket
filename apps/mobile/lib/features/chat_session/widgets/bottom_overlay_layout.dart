import 'package:flutter/material.dart';

class BottomOverlayLayout extends StatefulWidget {
  final Widget Function(double overlayHeight) contentBuilder;
  final Widget? overlay;
  final Widget? topOverlay;
  final Widget Function(double overlayHeight)? floatingButtonBuilder;

  const BottomOverlayLayout({
    super.key,
    required this.contentBuilder,
    this.overlay,
    this.topOverlay,
    this.floatingButtonBuilder,
  });

  @override
  State<BottomOverlayLayout> createState() => _BottomOverlayLayoutState();
}

class _BottomOverlayLayoutState extends State<BottomOverlayLayout> {
  final GlobalKey _overlayKey = GlobalKey();
  double _overlayHeight = 0;

  void _syncOverlayHeight() {
    if (!mounted) return;
    final box = _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    final nextHeight = box?.size.height ?? 0;
    if ((_overlayHeight - nextHeight).abs() <= 0.5) return;
    setState(() => _overlayHeight = nextHeight);
  }

  @override
  void didUpdateWidget(covariant BottomOverlayLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset overlay height when overlay disappears
    if (widget.overlay == null && oldWidget.overlay != null) {
      _overlayHeight = 0;
    }
    // Schedule height sync when overlay appears or changes
    if (widget.overlay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlayHeight());
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            widget.contentBuilder(_overlayHeight),
            if (widget.topOverlay != null) widget.topOverlay!,
            if (widget.floatingButtonBuilder != null)
              widget.floatingButtonBuilder!(_overlayHeight),
            if (widget.overlay != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: NotificationListener<SizeChangedLayoutNotification>(
                  onNotification: (_) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _syncOverlayHeight(),
                    );
                    return false;
                  },
                  child: SizeChangedLayoutNotifier(
                    child: ConstrainedBox(
                      key: _overlayKey,
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight,
                      ),
                      child: SingleChildScrollView(child: widget.overlay),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
