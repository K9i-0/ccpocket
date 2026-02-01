import 'package:flutter/material.dart';

import '../../models/messages.dart';

class ImagePreviewWidget extends StatelessWidget {
  final List<ImageRef> images;
  final String httpBaseUrl;

  const ImagePreviewWidget({
    super.key,
    required this.images,
    required this.httpBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return _SingleImage(
        image: images.first,
        httpBaseUrl: httpBaseUrl,
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final image = images[index];
          return _ImageThumbnail(
            image: image,
            httpBaseUrl: httpBaseUrl,
            height: 150,
          );
        },
      ),
    );
  }
}

class _SingleImage extends StatelessWidget {
  final ImageRef image;
  final String httpBaseUrl;

  const _SingleImage({required this.image, required this.httpBaseUrl});

  @override
  Widget build(BuildContext context) {
    final url = '$httpBaseUrl${image.url}';
    return GestureDetector(
      onTap: () => _openFullScreen(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (context, error, stack) => Container(
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.broken_image, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final ImageRef image;
  final String httpBaseUrl;
  final double height;

  const _ImageThumbnail({
    required this.image,
    required this.httpBaseUrl,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final url = '$httpBaseUrl${image.url}';
    return GestureDetector(
      onTap: () => _openFullScreen(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: height,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: height * 0.75,
              height: height,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stack) => Container(
            width: height * 0.75,
            height: height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.broken_image, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

void _openFullScreen(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FullScreenImageViewer(url: url),
    ),
  );
}

class FullScreenImageViewer extends StatelessWidget {
  final String url;
  const FullScreenImageViewer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stack) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
