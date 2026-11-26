import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/cached_network_image.dart';
import '../../../widgets/zoomable_image_viewer.dart';
import '../generated_image_preview_item.dart';

const _cacheMaxAge = Duration(days: 7);

class GeneratedImagePreviewPage extends StatelessWidget {
  final GeneratedImagePreviewItem item;
  final VoidCallback onTap;
  final VoidCallback? onSwipePrevious;
  final VoidCallback? onSwipeNext;

  const GeneratedImagePreviewPage({
    super.key,
    required this.item,
    required this.onTap,
    this.onSwipePrevious,
    this.onSwipeNext,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: item.prompt,
      child: ZoomableImageViewer(
        key: ValueKey('generated_image_page_${item.id}'),
        onTap: onTap,
        onSwipePrevious: onSwipePrevious,
        onSwipeNext: onSwipeNext,
        child: _GeneratedImage(item: item),
      ),
    );
  }
}

class _GeneratedImage extends StatelessWidget {
  final GeneratedImagePreviewItem item;

  const _GeneratedImage({required this.item});

  @override
  Widget build(BuildContext context) {
    final bytes = item.bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _ImageLoadFailure(),
      );
    }

    return CachedNetworkImage(
      url: item.url!,
      fit: BoxFit.contain,
      cacheKey: item.cacheKey,
      cacheMaxAge: _cacheMaxAge,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
      errorBuilder: (_, _, _) => const _ImageLoadFailure(),
    );
  }
}

class _ImageLoadFailure extends StatelessWidget {
  const _ImageLoadFailure();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
        const SizedBox(height: 10),
        Text(
          AppLocalizations.of(context).failedToLoadImage,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
