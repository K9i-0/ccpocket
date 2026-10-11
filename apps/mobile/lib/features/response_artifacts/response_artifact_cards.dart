import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/file_type_icon.dart';
import '../file_peek/file_path_syntax.dart';
import '../gallery/widgets/gallery_image_viewer.dart';
import 'workspace_output_links.dart';

/// Output attachments stay accessible outside collapsible tool content.
class ResponseArtifactCards extends StatelessWidget {
  final List<GalleryImage> images;
  final List<WorkspaceOutputLink> files;
  final String? httpBaseUrl;
  final FilePathTapCallback? onFileTap;

  const ResponseArtifactCards({
    super.key,
    this.images = const [],
    this.files = const [],
    this.httpBaseUrl,
    this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty && (files.isEmpty || onFileTap == null)) {
      return const SizedBox.shrink();
    }
    return Column(
      key: const ValueKey('response_artifact_cards'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.bubbleMarginH,
              vertical: 4,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < images.length; index++)
                  _GalleryImageCard(
                    images: images,
                    index: index,
                    httpBaseUrl: httpBaseUrl,
                  ),
              ],
            ),
          ),
        if (files.isNotEmpty && onFileTap != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.bubbleMarginH,
              vertical: 4,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final file in files)
                  _WorkspaceFileCard(
                    file: file,
                    onTap: () => onFileTap!(file.path),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GalleryImageCard extends StatelessWidget {
  final List<GalleryImage> images;
  final int index;
  final String? httpBaseUrl;

  const _GalleryImageCard({
    required this.images,
    required this.index,
    required this.httpBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final image = images[index];
    final colors = Theme.of(context).colorScheme;
    final imageUrl = httpBaseUrl == null || httpBaseUrl!.isEmpty
        ? null
        : '$httpBaseUrl${image.url}';
    return SizedBox(
      width: 180,
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('response_gallery_image_card_${image.id}'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GalleryImageViewer(
                images: images,
                initialIndex: index,
                httpBaseUrl: httpBaseUrl ?? '',
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1.55,
                child: imageUrl == null
                    ? Icon(Icons.image_outlined, color: colors.onSurfaceVariant)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.broken_image_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Text(
                  image.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceFileCard extends StatelessWidget {
  final WorkspaceOutputLink file;
  final VoidCallback onTap;

  const _WorkspaceFileCard({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filePath = file.path.replaceFirst(RegExp(r'(:\d+){1,2}$'), '');
    final name = path.posix.basename(filePath.replaceAll('\\', '/'));
    final label = file.label.isEmpty || file.label == file.path
        ? name
        : file.label;
    return SizedBox(
      width: 220,
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('response_file_card_${file.path}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FileTypeIcon(path: filePath, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      if (label != name)
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
