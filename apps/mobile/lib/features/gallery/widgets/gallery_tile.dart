import 'package:material_ui/material_ui.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_network_image.dart';

const _kCacheMaxAge = Duration(days: 7);

class GalleryTile extends StatelessWidget {
  final GalleryImage image;
  final String httpBaseUrl;
  final String timeAgo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GalleryTile({
    super.key,
    required this.image,
    required this.httpBaseUrl,
    required this.timeAgo,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final imageUrl = '$httpBaseUrl${image.url}';

    return GestureDetector(
      key: ValueKey('gallery_tile_${image.id}'),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Hero(
              tag: 'gallery_${image.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: CachedNetworkImage(
                    url: imageUrl,
                    fit: BoxFit.cover,
                    cacheMaxAge: _kCacheMaxAge,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image, size: 32)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            image.projectName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            timeAgo,
            style: TextStyle(fontSize: 11, color: appColors.subtleText),
          ),
        ],
      ),
    );
  }
}
