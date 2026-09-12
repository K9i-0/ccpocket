import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_painter/flutter_painter.dart';

import '../../l10n/app_localizations.dart';
import 'sketch_document.dart';
import 'widgets/sketch_text_dialog.dart';
import 'widgets/sketch_toolbar.dart';

typedef SketchResult = ({Uint8List bytes, String documentJson});

/// A local drawing editor. Attaching returns an image to the composer; this
/// screen never sends a message or invokes image generation.
class SketchScreen extends StatefulWidget {
  const SketchScreen({
    super.key,
    this.initialDocumentJson,
    this.backgroundImageBytes,
  });

  final String? initialDocumentJson;
  final Uint8List? backgroundImageBytes;

  @override
  State<SketchScreen> createState() => _SketchScreenState();
}

class _SketchScreenState extends State<SketchScreen> {
  late final PainterController _controller;
  SketchDocument _document = const SketchDocument();
  List<Drawable> _originalDrawables = const [];
  ui.Image? _backgroundImage;
  SketchTool _tool = SketchTool.pen;
  Color _color = Colors.black;
  double _strokeWidth = 6;
  bool _loading = false;
  bool _loadFailed = false;
  bool _exporting = false;
  bool _dirty = false;
  bool _canPop = false;
  bool _confirmingDiscard = false;

  @override
  void initState() {
    super.initState();
    _controller = PainterController(
      background: const ColorBackgroundDrawable(color: Colors.white),
      settings: const PainterSettings(
        freeStyle: FreeStyleSettings(mode: FreeStyleMode.draw, strokeWidth: 6),
        scale: ScaleSettings(enabled: true, maxScale: 4),
      ),
    )..addListener(_onDrawingChanged);
    final initialJson = widget.initialDocumentJson;
    if (initialJson != null || widget.backgroundImageBytes != null) {
      _loading = true;
      _loadDocument(initialJson);
    }
  }

  Future<void> _loadDocument(String? source) async {
    ui.Image? image;
    try {
      var document = source == null
          ? SketchDocument(backgroundImageBytes: widget.backgroundImageBytes)
          : await SketchDocument.decode(source);
      final bytes = document.backgroundImageBytes;
      if (bytes != null) {
        image = await SketchDocument.decodeBackground(bytes);
        if (source == null) {
          final imageSize = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          );
          document = SketchDocument(
            canvasSize: imageSize * (800 / imageSize.longestSide),
            backgroundImageBytes: bytes,
          );
        }
      }
      if (!mounted) {
        image?.dispose();
        return;
      }
      _document = document;
      _originalDrawables = document.drawables;
      _controller.value = _controller.value.copyWith(
        drawables: document.drawables,
        background: image == null
            ? ColorBackgroundDrawable(color: document.background)
            : ImageBackgroundDrawable(image: image),
      );
      _backgroundImage = image;
    } catch (_) {
      image?.dispose();
      if (!mounted) return;
      _loadFailed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onDrawingChanged() {
    final dirty = !listEquals(_originalDrawables, _controller.drawables);
    if (dirty != _dirty && mounted) setState(() => _dirty = dirty);
  }

  @override
  void dispose() {
    _controller.removeListener(_onDrawingChanged);
    _controller.dispose();
    _backgroundImage?.dispose();
    super.dispose();
  }

  void _configureTool() {
    final mode = switch (_tool) {
      SketchTool.pen => FreeStyleMode.draw,
      SketchTool.eraser => FreeStyleMode.erase,
      _ => FreeStyleMode.none,
    };
    final ShapeFactory? factory = switch (_tool) {
      SketchTool.arrow => ArrowFactory(),
      SketchTool.rectangle => RectangleFactory(),
      SketchTool.ellipse => OvalFactory(),
      _ => null,
    };
    _controller.settings = _controller.settings.copyWith(
      freeStyle: FreeStyleSettings(
        mode: mode,
        color: _color,
        strokeWidth: _tool == SketchTool.eraser
            ? _strokeWidth * 3
            : _strokeWidth,
      ),
      shape: ShapeSettings(
        factory: factory,
        drawOnce: false,
        paint: Paint()
          ..color = _color
          ..strokeWidth = _strokeWidth
          ..style = PaintingStyle.stroke,
      ),
    );
  }

  void _selectTool(SketchTool tool) {
    if (tool == SketchTool.text) {
      _editText();
      return;
    }
    _controller.deselectObjectDrawable();
    setState(() => _tool = tool);
    _configureTool();
  }

  Future<void> _editText() async {
    final selected = _controller.selectedObjectDrawable;
    final existing = selected is TextDrawable ? selected : null;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => SketchTextDialog(initialText: existing?.text ?? ''),
    );
    if (!mounted || text == null) return;
    final drawable =
        existing?.copyWith(text: text) ??
        TextDrawable(
          text: text,
          position: _document.canvasSize.center(Offset.zero),
          style: TextStyle(color: _color, fontSize: 32),
        );
    if (existing != null) {
      _controller.replaceDrawable(existing, drawable);
    } else {
      _controller.addDrawables([drawable]);
    }
    setState(() => _tool = SketchTool.select);
    _configureTool();
    _controller.selectObjectDrawable(drawable);
  }

  void _changeColor(Color color) {
    setState(() => _color = color);
    final selected = _controller.selectedObjectDrawable;
    if (selected != null) _controller.setDrawableColor(selected, color);
    _configureTool();
  }

  void _changeStrokeWidth(double width) {
    setState(() => _strokeWidth = width);
    _configureTool();
  }

  Future<void> _close() async {
    if (_exporting || _confirmingDiscard) return;
    if (_dirty) {
      _confirmingDiscard = true;
      final l10n = AppLocalizations.of(context);
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.sketchDiscardTitle),
          content: Text(l10n.sketchDiscardMessage),
          actions: [
            TextButton(
              key: const ValueKey('sketch_keep_editing_button'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.sketchKeepEditing),
            ),
            TextButton(
              key: const ValueKey('sketch_discard_button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.sketchDiscard),
            ),
          ],
        ),
      );
      _confirmingDiscard = false;
      if (!mounted || discard != true) return;
    }
    _finish();
  }

  void _finish([SketchResult? result]) {
    setState(() => _canPop = true);
    // PopScope must rebuild before the programmatic pop can be accepted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  Future<void> _attach() async {
    if (_loading ||
        _loadFailed ||
        _exporting ||
        (_controller.drawables.isEmpty && _backgroundImage == null)) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final document = SketchDocument(
        canvasSize: _document.canvasSize,
        background: _document.background,
        backgroundImageBytes: _document.backgroundImageBytes,
        drawables: List.of(_controller.drawables),
      );
      // renderImage captures the current drawables synchronously. Start it
      // before awaiting the codec so the PNG and document share one snapshot.
      final image = await _controller.renderImage(document.exportSize);
      final String json;
      final ByteData? data;
      try {
        json = await document.encode();
        data = await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
      if (data == null) throw StateError('Could not render sketch');
      if (!mounted) return;
      _finish((
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        documentJson: json,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).sketchExportFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope<SketchResult>(
      canPop: _canPop || (!_dirty && !_exporting),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const ValueKey('sketch_close_button'),
            tooltip: l10n.sketchCancel,
            onPressed: _exporting ? null : _close,
            icon: const Icon(Icons.close),
          ),
          title: Text(l10n.sketchTitle),
          actions: [
            ValueListenableBuilder<PainterControllerValue>(
              valueListenable: _controller,
              builder: (context, value, child) => TextButton(
                key: const ValueKey('sketch_attach_button'),
                onPressed:
                    _loading ||
                        _loadFailed ||
                        _exporting ||
                        (value.drawables.isEmpty && _backgroundImage == null)
                    ? null
                    : _attach,
                child: _exporting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.sketchAttach),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadFailed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.sketchLoadFailed),
                ),
              )
            : AbsorbPointer(
                absorbing: _exporting,
                child: Column(
                  children: [
                    Expanded(
                      child: SketchCanvas(
                        controller: _controller,
                        size: _document.canvasSize,
                      ),
                    ),
                    SketchToolbar(
                      controller: _controller,
                      tool: _tool,
                      color: _color,
                      strokeWidth: _strokeWidth,
                      onToolChanged: _selectTool,
                      onColorChanged: _changeColor,
                      onStrokeWidthChanged: _changeStrokeWidth,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class SketchCanvas extends StatelessWidget {
  const SketchCanvas({super.key, required this.controller, required this.size});

  final PainterController controller;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(
            child: SizedBox.fromSize(
              size: size,
              child: ClipRect(
                child: FlutterPainter(
                  key: const ValueKey('sketch_canvas'),
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
