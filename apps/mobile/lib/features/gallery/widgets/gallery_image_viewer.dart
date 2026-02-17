import 'dart:io';
import 'dart:math' as math;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';

const _kCacheMaxAge = Duration(days: 7);

/// Full-screen gallery image viewer with PageView swipe, double-tap zoom,
/// image info overlay, and delete/share actions.
class GalleryImageViewer extends HookWidget {
  final List<GalleryImage> images;
  final int initialIndex;
  final String httpBaseUrl;
  final Future<bool> Function(String id)? onDelete;

  const GalleryImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.httpBaseUrl,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Mutable image list for in-viewer deletion
    final imageList = useState(List<GalleryImage>.from(images));
    final pageController = usePageController(initialPage: initialIndex);
    final currentPage = useState(initialIndex);
    final chromeVisible = useState(true);
    final isDeleting = useState(false);

    // Hide system UI when chrome is hidden
    useEffect(() {
      if (chromeVisible.value) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      return () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }, [chromeVisible.value]);

    if (imageList.value.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            AppLocalizations.of(context).noImages,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final safeIndex = currentPage.value.clamp(0, imageList.value.length - 1);
    final currentImage = imageList.value[safeIndex];

    Future<void> handleDelete() async {
      if (onDelete == null || isDeleting.value) return;

      final confirmed = await showDeleteConfirmDialog(context);
      if (!confirmed || !context.mounted) return;

      isDeleting.value = true;
      final success = await onDelete!(currentImage.id);
      if (!context.mounted) return;
      isDeleting.value = false;

      if (success) {
        final newList = List<GalleryImage>.from(imageList.value)
          ..removeAt(safeIndex);
        if (newList.isEmpty) {
          Navigator.pop(context);
          return;
        }
        imageList.value = newList;
        // Adjust page index
        if (safeIndex >= newList.length) {
          currentPage.value = newList.length - 1;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).failedToDeleteImage),
          ),
        );
      }
    }

    Future<void> handleShare() async {
      final url = '$httpBaseUrl${currentImage.url}';
      File? tempFile;
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).failedToDownloadImage,
                ),
              ),
            );
          }
          return;
        }
        final tempDir = Directory.systemTemp;
        final ext = _extensionFromMime(currentImage.mimeType);
        tempFile = File('${tempDir.path}/screenshot_${currentImage.id}$ext');
        await tempFile.writeAsBytes(response.bodyBytes);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(tempFile.path)]),
        );
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).failedToShareImage),
            ),
          );
        }
      } finally {
        tempFile?.delete().ignore();
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: chromeVisible.value
          ? AppBar(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                '${safeIndex + 1} / ${imageList.value.length}',
                style: const TextStyle(fontSize: 16),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: handleShare,
                  tooltip: AppLocalizations.of(context).share,
                ),
                if (onDelete != null)
                  IconButton(
                    icon: isDeleting.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_outline),
                    onPressed: isDeleting.value ? null : handleDelete,
                    tooltip: AppLocalizations.of(context).delete,
                  ),
              ],
            )
          : null,
      body: Stack(
        children: [
          // PageView with images
          PageView.builder(
            controller: pageController,
            itemCount: imageList.value.length,
            onPageChanged: (index) => currentPage.value = index,
            itemBuilder: (context, index) {
              final image = imageList.value[index];
              final imageUrl = '$httpBaseUrl${image.url}';
              return _ZoomableImage(
                key: ValueKey(image.id),
                imageUrl: imageUrl,
                onTap: () => chromeVisible.value = !chromeVisible.value,
              );
            },
          ),

          // Bottom info overlay
          if (chromeVisible.value)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ImageInfoOverlay(
                image: currentImage,
                bottomPadding: MediaQuery.of(context).padding.bottom,
              ),
            ),
        ],
      ),
    );
  }
}

/// Image widget with double-tap-to-zoom and single-tap chrome toggle.
class _ZoomableImage extends StatefulWidget {
  final String imageUrl;
  final VoidCallback? onTap;

  const _ZoomableImage({super.key, required this.imageUrl, this.onTap});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final _transformController = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animController.addListener(() {
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

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final currentScale = _transformController.value.getMaxScaleOnAxis();

    Matrix4 endMatrix;
    if (currentScale > 1.1) {
      // Zoom out to identity
      endMatrix = Matrix4.identity();
    } else {
      // Zoom in to 2x centered on tap position
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
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: ExtendedImage.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            cache: true,
            cacheMaxAge: _kCacheMaxAge,
            loadStateChanged: (state) {
              switch (state.extendedImageLoadState) {
                case LoadState.loading:
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                case LoadState.completed:
                  return state.completedWidget;
                case LoadState.failed:
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 48,
                    ),
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Semi-transparent bottom overlay showing image metadata.
class _ImageInfoOverlay extends StatelessWidget {
  final GalleryImage image;
  final double bottomPadding;

  const _ImageInfoOverlay({required this.image, this.bottomPadding = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, math.max(bottomPadding, 12)),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            image.projectName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 13, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(image.addedAt),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.straighten, size: 13, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                _formatFileSize(image.sizeBytes),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 16),
              Text(
                image.mimeType.replaceFirst('image/', '').toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return '';
  final local = date.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);

  // Within today: show time only
  if (diff.inHours < 24 &&
      local.day == now.day &&
      local.month == now.month &&
      local.year == now.year) {
    return '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  // Within this year: show month/day + time
  if (local.year == now.year) {
    return '${local.month}/${local.day} ${_pad(local.hour)}:${_pad(local.minute)}';
  }

  // Different year: full date
  return '${local.year}/${local.month}/${local.day} ${_pad(local.hour)}:${_pad(local.minute)}';
}

String _pad(int n) => n.toString().padLeft(2, '0');

String _formatFileSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _extensionFromMime(String mimeType) {
  return switch (mimeType) {
    'image/png' => '.png',
    'image/jpeg' || 'image/jpg' => '.jpg',
    'image/gif' => '.gif',
    'image/webp' => '.webp',
    _ => '.png',
  };
}

/// Shared confirmation dialog for gallery image deletion.
Future<bool> showDeleteConfirmDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final l = AppLocalizations.of(ctx);
      return AlertDialog(
        title: Text(l.deleteScreenshot),
        content: Text(l.cannotBeUndone),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l.delete),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
