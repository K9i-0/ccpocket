import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:http/http.dart' as http;
import 'package:vector_math/vector_math.dart' as vm;

import '../../../l10n/app_localizations.dart';
import '../glb_preview_cache.dart';
import '../glb_preview_data.dart';

class FilePeekModelPreview extends StatefulWidget {
  const FilePeekModelPreview({super.key, required this.modelUrl});
  final String? modelUrl;

  @override
  State<FilePeekModelPreview> createState() => _FilePeekModelPreviewState();
}

class _FilePeekModelPreviewState extends State<FilePeekModelPreview> {
  http.Client? _client;
  fs.Scene? _scene;
  vm.Vector3 _center = vm.Vector3.zero();
  double _radius = 1;
  double _yaw = -0.5;
  double _pitch = 0.3;
  double _zoom = 1;
  double _startZoom = 1;
  int _generation = 0;
  String? _error;
  bool _warning = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(FilePeekModelPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelUrl != widget.modelUrl) unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _client?.close();
    final client = _client = http.Client();
    setState(() {
      _scene = null;
      _error = null;
      _warning = false;
    });
    try {
      final url = widget.modelUrl;
      if (url == null) throw const FormatException('Missing URL');
      final bytes =
          GlbPreviewCache.shared.get(url) ?? await _download(client, url);
      if (!mounted || generation != _generation) return;
      await fs.Scene.initializeStaticResources();
      if (!mounted || generation != _generation) return;
      var warning = false;
      final model = await fs.Node.fromGlbBytes(
        bytes,
        onWarning: (_) => warning = true,
      );
      if (!mounted || generation != _generation) return;
      // Empty transform/light nodes can make combinedWorldBounds unknown.
      // Fall back to the individual geometry bounds for the static pose.
      vm.Aabb3? bounds = model.combinedWorldBounds;
      if (bounds == null) {
        for (final node in model.meshNodes) {
          for (final primitive in node.mesh!.primitives) {
            final local = primitive.geometry.localBounds;
            if (local == null) continue;
            final world = vm.Aabb3.copy(local)..transform(node.globalTransform);
            if (bounds == null) {
              bounds = world;
            } else {
              bounds.hull(world);
            }
          }
        }
      }
      if (bounds == null ||
          !bounds.min.storage.every((v) => v.isFinite) ||
          !bounds.max.storage.every((v) => v.isFinite)) {
        throw const FormatException('No displayable geometry');
      }
      final scene = fs.Scene()..add(model);
      setState(() {
        _scene = scene;
        _center = bounds!.center;
        _radius = math.max((bounds.max - bounds.min).length / 2, 0.0001);
        _warning = warning;
        _resetCamera();
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              error is FormatException && error.message == 'model_too_large'
              ? 'model_too_large'
              : 'load_failed',
        );
      }
    } finally {
      client.close();
    }
  }

  Future<Uint8List> _download(http.Client client, String url) async {
    final request = http.Request('GET', Uri.parse(url))
      ..followRedirects = false;
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw const FormatException('Download failed');
    }
    if ((response.contentLength ?? 0) > maxGlbPreviewBytes) {
      throw const FormatException('model_too_large');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (builder.length + chunk.length > maxGlbPreviewBytes) {
        throw const FormatException('model_too_large');
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    validatePreviewGlb(bytes);
    GlbPreviewCache.shared.put(url, bytes);
    return bytes;
  }

  Future<void> _retry() async {
    final url = widget.modelUrl;
    if (url != null) GlbPreviewCache.shared.remove(url);
    await _load();
  }

  void _resetCamera() {
    _yaw = -0.5;
    _pitch = 0.3;
    _zoom = 1;
  }

  @override
  void dispose() {
    _generation++;
    _client?.close();
    _scene = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ModelError(
        tooLarge: _error == 'model_too_large',
        onRetry: _retry,
      );
    }
    final scene = _scene;
    if (scene == null) {
      return const Center(
        child: CircularProgressIndicator.adaptive(
          key: ValueKey('file_peek_model_loading_indicator'),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final aspect =
                  constraints.maxWidth / math.max(constraints.maxHeight, 1);
              final halfFov = math.min(
                math.pi / 8,
                math.atan(math.tan(math.pi / 8) * aspect),
              );
              final distance = _radius / math.sin(halfFov) * 1.15 * _zoom;
              final camera = fs.PerspectiveCamera(
                position:
                    _center +
                    vm.Vector3(
                          math.sin(_yaw) * math.cos(_pitch),
                          math.sin(_pitch),
                          -math.cos(_yaw) * math.cos(_pitch),
                        ) *
                        distance,
                target: _center,
                fovNear: _radius * 0.001,
                fovFar: distance + _radius * 3,
              );
              return Semantics(
                label: AppLocalizations.of(context).filePreviewModelGestures,
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      GestureBinding.instance.pointerSignalResolver.register(
                        event,
                        (_) {
                          setState(
                            () => _zoom =
                                (_zoom * math.exp(event.scrollDelta.dy * 0.002))
                                    .clamp(0.15, 10),
                          );
                        },
                      );
                    }
                  },
                  child: GestureDetector(
                    key: const ValueKey('file_peek_model_viewport'),
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (_) => _startZoom = _zoom,
                    onScaleUpdate: (details) => setState(() {
                      if (details.pointerCount > 1) {
                        _zoom = (_startZoom / details.scale).clamp(0.15, 10);
                      } else {
                        _yaw -= details.focalPointDelta.dx * 0.01;
                        _pitch = (_pitch + details.focalPointDelta.dy * 0.01)
                            .clamp(-1.5, 1.5);
                      }
                    }),
                    child: fs.SceneView(
                      scene,
                      camera: camera,
                      autoTick: false,
                      pixelRatio: math.min(
                        MediaQuery.devicePixelRatioOf(context),
                        2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _ModelControls(
          warning: _warning,
          onReset: () => setState(_resetCamera),
        ),
      ],
    );
  }
}

class _ModelError extends StatelessWidget {
  const _ModelError({required this.tooLarge, required this.onRetry});
  final bool tooLarge;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              tooLarge
                  ? l10n.filePreviewModelTooLarge
                  : l10n.filePreviewModelLoadFailed,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              key: const ValueKey('file_peek_model_retry_button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelControls extends StatelessWidget {
  const _ModelControls({required this.warning, required this.onReset});
  final bool warning;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (warning)
              Text(l10n.filePreviewModelWarning, textAlign: TextAlign.center),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.filePreviewModelGestures,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  key: const ValueKey('file_peek_model_reset_button'),
                  tooltip: l10n.filePreviewModelReset,
                  onPressed: onReset,
                  icon: const Icon(Icons.center_focus_strong),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
