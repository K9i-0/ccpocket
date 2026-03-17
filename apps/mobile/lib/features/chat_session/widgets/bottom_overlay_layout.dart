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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleHeight = (constraints.maxHeight - keyboardInset).clamp(
          0.0,
          constraints.maxHeight,
        );
        final bottomObstruction = _overlayHeight + keyboardInset;

        // Clamp so the padding never exceeds the Stack height
        // (e.g. when keyboard + overlay > available height).
        final clampedObstruction = bottomObstruction.clamp(
          0.0,
          constraints.maxHeight,
        );

        return Stack(
          children: [
            // Clip chat content above the overlay so messages don't
            // scroll behind it.
            Padding(
              padding: EdgeInsets.only(bottom: clampedObstruction),
              child: widget.contentBuilder(bottomObstruction),
            ),
            if (widget.topOverlay != null) widget.topOverlay!,
            if (widget.floatingButtonBuilder != null)
              widget.floatingButtonBuilder!(bottomObstruction),
            if (widget.overlay != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: SizedBox(
                    width: double.infinity,
                    height: visibleHeight,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragStart: (_) =>
                            FocusScope.of(context).unfocus(),
                        child:
                            NotificationListener<SizeChangedLayoutNotification>(
                              onNotification: (_) {
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _syncOverlayHeight(),
                                );
                                return false;
                              },
                              child: SizeChangedLayoutNotifier(
                                child: ClipRect(
                                  child: ConstrainedBox(
                                    key: _overlayKey,
                                    constraints: BoxConstraints(
                                      maxHeight: visibleHeight,
                                    ),
                                    child: widget.overlay,
                                  ),
                                ),
                              ),
                            ),
                      ),
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
