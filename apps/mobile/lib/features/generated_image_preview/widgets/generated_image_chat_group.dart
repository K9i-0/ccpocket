import 'dart:math' as math;
import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../generated_image_preview_item.dart';
import '../generated_image_preview_screen.dart';

const _cacheMaxAge = Duration(days: 7);
const _maxVisibleImages = 4;
const _spacing = 6.0;

class GeneratedImageChatGroup extends StatelessWidget {
  final List<GeneratedImagePreviewItem> items;

  const GeneratedImageChatGroup({super.key, required this.items})
    : assert(items.length > 0);

  void _openPreview(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GeneratedImagePreviewScreen(items: items, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = math.min(items.length, _maxVisibleImages);
    return Padding(
      key: const ValueKey('generated_image_chat_group'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bubbleMarginH,
        vertical: 4,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (visibleCount == 1) {
            return _GeneratedImageChatTile(
              item: items.first,
              index: 0,
              total: 1,
              remainingCount: 0,
              preserveAspectRatio: true,
              onTap: () => _openPreview(context, 0),
            );
          }

          final columns = visibleCount;
          final tileWidth =
              (constraints.maxWidth - _spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: _spacing,
            runSpacing: _spacing,
            children: [
              for (var index = 0; index < visibleCount; index++)
                SizedBox(
                  width: tileWidth,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _GeneratedImageChatTile(
                      item: items[index],
                      index: index,
                      total: items.length,
                      preserveAspectRatio: false,
                      remainingCount:
                          index == visibleCount - 1 &&
                              items.length > visibleCount
                          ? items.length - visibleCount
                          : 0,
                      onTap: () => _openPreview(context, index),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GeneratedImageChatTile extends StatelessWidget {
  final GeneratedImagePreviewItem item;
  final int index;
  final int total;
  final int remainingCount;
  final bool preserveAspectRatio;
  final VoidCallback onTap;

  const _GeneratedImageChatTile({
    required this.item,
    required this.index,
    required this.total,
    required this.remainingCount,
    required this.preserveAspectRatio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      image: true,
      label: l.generatedImagePositionLabel(index + 1, total),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('generated_image_chat_thumbnail_$index'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: preserveAspectRatio
                ? _IntrinsicAspectRatioImage(item: item)
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      _GeneratedImageThumbnail(item: item, fit: BoxFit.cover),
                      if (remainingCount > 0)
                        ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: Text(
                              '+$remainingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _IntrinsicAspectRatioImage extends StatefulWidget {
  final GeneratedImagePreviewItem item;

  const _IntrinsicAspectRatioImage({required this.item});

  @override
  State<_IntrinsicAspectRatioImage> createState() =>
      _IntrinsicAspectRatioImageState();
}

class _IntrinsicAspectRatioImageState
    extends State<_IntrinsicAspectRatioImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _aspectRatio = _pngAspectRatio(widget.item.bytes);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _IntrinsicAspectRatioImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _aspectRatio = _pngAspectRatio(widget.item.bytes);
      _resolveAspectRatio();
    }
  }

  ImageProvider<Object> _providerFor(GeneratedImagePreviewItem item) {
    final bytes = item.bytes;
    if (bytes != null) return MemoryImage(bytes);
    return ExtendedNetworkImageProvider(
      item.url!,
      cache: true,
      cacheMaxAge: _cacheMaxAge,
    );
  }

  void _resolveAspectRatio() {
    final stream = _providerFor(
      widget.item,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key == _imageStream?.key) return;
    _removeImageStreamListener();
    _imageStream = stream;
    _imageStreamListener = ImageStreamListener(
      (info, _) {
        final ratio = info.image.width / info.image.height;
        if (!mounted || ratio == _aspectRatio) return;
        setState(() => _aspectRatio = ratio);
      },
      onError: (_, _) {
        // The visible image widget owns the failure UI.
      },
    );
    stream.addListener(_imageStreamListener!);
  }

  void _removeImageStreamListener() {
    final listener = _imageStreamListener;
    if (listener != null) {
      _imageStream?.removeListener(listener);
    }
    _imageStreamListener = null;
  }

  @override
  void dispose() {
    _removeImageStreamListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _aspectRatio ?? 16 / 9,
      child: _GeneratedImageThumbnail(item: widget.item, fit: BoxFit.cover),
    );
  }
}

double? _pngAspectRatio(Uint8List? bytes) {
  if (bytes == null || bytes.length < 24) return null;
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  for (var index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) return null;
  }
  final data = ByteData.sublistView(bytes);
  final width = data.getUint32(16);
  final height = data.getUint32(20);
  if (width == 0 || height == 0) return null;
  return width / height;
}

class _GeneratedImageThumbnail extends StatelessWidget {
  final GeneratedImagePreviewItem item;
  final BoxFit fit;

  const _GeneratedImageThumbnail({required this.item, required this.fit});

  @override
  Widget build(BuildContext context) {
    final bytes = item.bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _ThumbnailLoadFailure(),
      );
    }

    return ExtendedImage.network(
      item.url!,
      fit: fit,
      cache: true,
      cacheMaxAge: _cacheMaxAge,
      loadStateChanged: (state) {
        return switch (state.extendedImageLoadState) {
          LoadState.loading => const ColoredBox(
            color: Color(0x14000000),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          LoadState.completed => state.completedWidget,
          LoadState.failed => const _ThumbnailLoadFailure(),
        };
      },
    );
  }
}

class _ThumbnailLoadFailure extends StatelessWidget {
  const _ThumbnailLoadFailure();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: const Center(child: Icon(Icons.broken_image_outlined, size: 28)),
    );
  }
}
