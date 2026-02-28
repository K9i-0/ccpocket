import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/diff_parser.dart';

/// Comparison mode for the full-screen diff image viewer.
enum DiffCompareMode { sideBySide, slider, overlay }

/// Formats a byte count into a human-readable string.
String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Full-screen diff image comparison viewer with three modes:
/// Side-by-side, Slider (onion skin), and Overlay (opacity blend).
class DiffImageViewer extends HookWidget {
  final DiffFile file;
  final DiffImageData imageData;

  const DiffImageViewer({
    super.key,
    required this.file,
    required this.imageData,
  });

  /// Whether both old and new images are available for comparison.
  bool get _hasBothSides =>
      !file.isNewFile &&
      !file.isDeleted &&
      imageData.oldBytes != null &&
      imageData.newBytes != null;

  @override
  Widget build(BuildContext context) {
    final compareMode = useState(DiffCompareMode.sideBySide);
    final chromeVisible = useState(true);
    final overlayOpacity = useState(0.5);

    // Hide system UI when chrome is hidden
    useEffect(() {
      if (chromeVisible.value) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      return () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }, [chromeVisible.value]);

    final l = AppLocalizations.of(context);
    final fileName = file.filePath.split('/').last;

    void toggleChrome() => chromeVisible.value = !chromeVisible.value;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: chromeVisible.value
          ? AppBar(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(fileName, style: const TextStyle(fontSize: 16)),
            )
          : null,
      body: Stack(
        children: [
          // Main content
          Positioned.fill(
            child: _hasBothSides
                ? switch (compareMode.value) {
                    DiffCompareMode.sideBySide => _SideBySideContent(
                      oldBytes: imageData.oldBytes,
                      newBytes: imageData.newBytes,
                      isSvg: imageData.isSvg,
                      onTap: toggleChrome,
                    ),
                    DiffCompareMode.slider => _SliderContent(
                      oldBytes: imageData.oldBytes!,
                      newBytes: imageData.newBytes!,
                      isSvg: imageData.isSvg,
                      onTap: toggleChrome,
                    ),
                    DiffCompareMode.overlay => _OverlayContent(
                      oldBytes: imageData.oldBytes!,
                      newBytes: imageData.newBytes!,
                      isSvg: imageData.isSvg,
                      opacity: overlayOpacity.value,
                      onTap: toggleChrome,
                    ),
                  }
                : _SingleImageContent(
                    bytes: imageData.newBytes ?? imageData.oldBytes,
                    isSvg: imageData.isSvg,
                    label: file.isNewFile
                        ? l.diffNewFile
                        : file.isDeleted
                        ? l.diffDeleted
                        : null,
                    onTap: toggleChrome,
                  ),
          ),

          // Bottom bar
          if (chromeVisible.value)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(
                mode: compareMode.value,
                onModeChanged: (m) => compareMode.value = m,
                showModeSelector: _hasBothSides,
                imageData: imageData,
                overlayOpacity: compareMode.value == DiffCompareMode.overlay
                    ? overlayOpacity.value
                    : null,
                onOpacityChanged: (v) => overlayOpacity.value = v,
                bottomPadding: MediaQuery.of(context).padding.bottom,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Side-by-side content (two independent zoomable panes)
// ---------------------------------------------------------------------------

class _SideBySideContent extends StatelessWidget {
  final Uint8List? oldBytes;
  final Uint8List? newBytes;
  final bool isSvg;
  final VoidCallback onTap;

  const _SideBySideContent({
    required this.oldBytes,
    required this.newBytes,
    required this.isSvg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _ZoomableMemoryImage(
            bytes: oldBytes,
            isSvg: isSvg,
            label: l.diffBefore,
            onTap: onTap,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: Colors.white24),
        Expanded(
          child: _ZoomableMemoryImage(
            bytes: newBytes,
            isSvg: isSvg,
            label: l.diffAfter,
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Slider content (onion skin with draggable divider)
// ---------------------------------------------------------------------------

class _SliderContent extends StatefulWidget {
  final Uint8List oldBytes;
  final Uint8List newBytes;
  final bool isSvg;
  final VoidCallback onTap;

  const _SliderContent({
    required this.oldBytes,
    required this.newBytes,
    required this.isSvg,
    required this.onTap,
  });

  @override
  State<_SliderContent> createState() => _SliderContentState();
}

class _SliderContentState extends State<_SliderContent> {
  double _fraction = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sliderX = constraints.maxWidth * _fraction;
        return GestureDetector(
          onTap: widget.onTap,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Bottom layer: old image
                  _buildMemoryImage(
                    bytes: widget.oldBytes,
                    isSvg: widget.isSvg,
                  ),
                  // Top layer: new image, clipped to slider position
                  ClipRect(
                    clipper: _SliderClipper(_fraction),
                    child: _buildMemoryImage(
                      bytes: widget.newBytes,
                      isSvg: widget.isSvg,
                    ),
                  ),
                  // Slider handle
                  Positioned(
                    left: sliderX - 20,
                    top: 0,
                    bottom: 0,
                    width: 40,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _fraction =
                              ((_fraction * constraints.maxWidth +
                                          details.delta.dx) /
                                      constraints.maxWidth)
                                  .clamp(0.0, 1.0);
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Container(width: 2, color: Colors.white),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.drag_handle,
                                size: 16,
                                color: Colors.black87,
                              ),
                            ),
                            Expanded(
                              child: Container(width: 2, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Before/After labels at top
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _ModeLabel(
                      text: AppLocalizations.of(context).diffBefore,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _ModeLabel(
                      text: AppLocalizations.of(context).diffAfter,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Clips a rectangle from left edge to [fraction] of width.
class _SliderClipper extends CustomClipper<Rect> {
  final double fraction;
  _SliderClipper(this.fraction);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_SliderClipper old) => old.fraction != fraction;
}

// ---------------------------------------------------------------------------
// Overlay content (opacity blend)
// ---------------------------------------------------------------------------

class _OverlayContent extends StatefulWidget {
  final Uint8List oldBytes;
  final Uint8List newBytes;
  final bool isSvg;
  final double opacity;
  final VoidCallback onTap;

  const _OverlayContent({
    required this.oldBytes,
    required this.newBytes,
    required this.isSvg,
    required this.opacity,
    required this.onTap,
  });

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent>
    with SingleTickerProviderStateMixin {
  final _transformController = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          if (_animation != null) {
            _transformController.value = _animation!.value;
          }
        });
  }

  @override
  void dispose() {
    _animController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final currentScale = _transformController.value.getMaxScaleOnAxis();

    Matrix4 endMatrix;
    if (currentScale > 1.1) {
      endMatrix = Matrix4.identity();
    } else {
      const scale = 2.5;
      final dx = -position.dx * (scale - 1);
      final dy = -position.dy * (scale - 1);
      // ignore: deprecated_member_use
      endMatrix = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(dx, dy)
        // ignore: deprecated_member_use
        ..scale(scale);
    }

    _animation = Matrix4Tween(begin: _transformController.value, end: endMatrix)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildMemoryImage(bytes: widget.oldBytes, isSvg: widget.isSvg),
              Opacity(
                opacity: widget.opacity,
                child: _buildMemoryImage(
                  bytes: widget.newBytes,
                  isSvg: widget.isSvg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single image content (for new/deleted files)
// ---------------------------------------------------------------------------

class _SingleImageContent extends StatelessWidget {
  final Uint8List? bytes;
  final bool isSvg;
  final String? label;
  final VoidCallback onTap;

  const _SingleImageContent({
    required this.bytes,
    required this.isSvg,
    this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ZoomableMemoryImage(
      bytes: bytes,
      isSvg: isSvg,
      label: label,
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Zoomable memory image with double-tap zoom
// ---------------------------------------------------------------------------

class _ZoomableMemoryImage extends StatefulWidget {
  final Uint8List? bytes;
  final bool isSvg;
  final String? label;
  final VoidCallback? onTap;

  const _ZoomableMemoryImage({
    required this.bytes,
    required this.isSvg,
    this.label,
    this.onTap,
  });

  @override
  State<_ZoomableMemoryImage> createState() => _ZoomableMemoryImageState();
}

class _ZoomableMemoryImageState extends State<_ZoomableMemoryImage>
    with SingleTickerProviderStateMixin {
  final _transformController = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          if (_animation != null) {
            _transformController.value = _animation!.value;
          }
        });
  }

  @override
  void dispose() {
    _animController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final currentScale = _transformController.value.getMaxScaleOnAxis();

    Matrix4 endMatrix;
    if (currentScale > 1.1) {
      endMatrix = Matrix4.identity();
    } else {
      const scale = 2.5;
      final dx = -position.dx * (scale - 1);
      final dy = -position.dy * (scale - 1);
      // ignore: deprecated_member_use
      endMatrix = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(dx, dy)
        // ignore: deprecated_member_use
        ..scale(scale);
    }

    _animation = Matrix4Tween(begin: _transformController.value, end: endMatrix)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bytes == null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Center(
          child: Text(
            AppLocalizations.of(context).diffNoImage,
            style: const TextStyle(
              color: Colors.white54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: _buildMemoryImage(
                  bytes: widget.bytes!,
                  isSvg: widget.isSvg,
                ),
              ),
            ),
          ),
          if (widget.label != null)
            Positioned(left: 8, top: 8, child: _ModeLabel(text: widget.label!)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom bar with mode selector and size info
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  final DiffCompareMode mode;
  final ValueChanged<DiffCompareMode> onModeChanged;
  final bool showModeSelector;
  final DiffImageData imageData;
  final double? overlayOpacity;
  final ValueChanged<double> onOpacityChanged;
  final double bottomPadding;

  const _BottomBar({
    required this.mode,
    required this.onModeChanged,
    required this.showModeSelector,
    required this.imageData,
    this.overlayOpacity,
    required this.onOpacityChanged,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, math.max(bottomPadding, 12)),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showModeSelector) ...[
            SegmentedButton<DiffCompareMode>(
              segments: [
                ButtonSegment(
                  value: DiffCompareMode.sideBySide,
                  icon: const Icon(Icons.view_column_outlined, size: 18),
                  label: Text(l.diffCompareSideBySide),
                ),
                ButtonSegment(
                  value: DiffCompareMode.slider,
                  icon: const Icon(Icons.compare, size: 18),
                  label: Text(l.diffCompareSlider),
                ),
                ButtonSegment(
                  value: DiffCompareMode.overlay,
                  icon: const Icon(Icons.layers_outlined, size: 18),
                  label: Text(l.diffCompareOverlay),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) => onModeChanged(s.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.black;
                  }
                  return Colors.white70;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.white.withValues(alpha: 0.1);
                }),
                side: WidgetStateProperty.all(
                  const BorderSide(color: Colors.white24),
                ),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (overlayOpacity != null) ...[
            Row(
              children: [
                Text(
                  l.diffBefore,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Colors.white70,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: Slider(
                      value: overlayOpacity!,
                      onChanged: onOpacityChanged,
                    ),
                  ),
                ),
                Text(
                  l.diffAfter,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          // Size info
          _SizeInfoText(imageData: imageData),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Renders an in-memory image (raster or SVG).
Widget _buildMemoryImage({required Uint8List bytes, required bool isSvg}) {
  if (isSvg) {
    return SvgPicture.memory(bytes, fit: BoxFit.contain);
  }
  return Image.memory(
    bytes,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => const Center(
      child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
    ),
  );
}

/// Small label badge for mode overlays (Before/After).
class _ModeLabel extends StatelessWidget {
  final String text;
  const _ModeLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}

/// Size info text for the bottom bar.
class _SizeInfoText extends StatelessWidget {
  final DiffImageData imageData;
  const _SizeInfoText({required this.imageData});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (imageData.oldSize != null) {
      parts.add(_formatFileSize(imageData.oldSize!));
    }
    if (imageData.newSize != null) {
      parts.add(_formatFileSize(imageData.newSize!));
    }
    final sizeText = parts.join(' → ');

    return Text(
      sizeText.isNotEmpty ? sizeText : '',
      style: const TextStyle(color: Colors.white70, fontSize: 12),
    );
  }
}
