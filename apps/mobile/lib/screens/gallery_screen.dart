import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/messages.dart';
import '../providers/bridge_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/bubbles/image_preview.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  final String? sessionId;

  const GalleryScreen({super.key, this.sessionId});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  String? _selectedProject;

  bool get _isSessionMode => widget.sessionId != null;

  @override
  void initState() {
    super.initState();
    ref.read(bridgeServiceProvider).requestGallery(sessionId: widget.sessionId);
  }

  Map<String, int> _projectCounts(List<GalleryImage> images) {
    final counts = <String, int>{};
    for (final img in images) {
      counts[img.projectName] = (counts[img.projectName] ?? 0) + 1;
    }
    return counts;
  }

  List<GalleryImage> _filteredImages(List<GalleryImage> images) {
    if (_selectedProject == null) return images;
    return images.where((img) => img.projectName == _selectedProject).toList();
  }

  void _onFilterChanged(String? project) {
    setState(() => _selectedProject = project);
  }

  String _timeAgo(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final images =
        ref.watch(galleryProvider).valueOrNull ??
        ref.read(bridgeServiceProvider).galleryImages;

    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: images.isEmpty
          ? _buildEmptyState(appColors)
          : _buildContent(appColors, images),
    );
  }

  Widget _buildEmptyState(AppColors appColors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.preview,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No previews yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _isSessionMode
                  ? 'Use /preview command to capture screenshots from this session.'
                  : 'Screenshots from Claude sessions will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: appColors.subtleText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppColors appColors, List<GalleryImage> images) {
    final filtered = _filteredImages(images);
    final counts = _projectCounts(images);

    return Column(
      children: [
        if (!_isSessionMode && counts.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildFilterChips(appColors, counts, images),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final image = filtered[index];
              return _GalleryTile(
                image: image,
                httpBaseUrl: ref.read(bridgeServiceProvider).httpBaseUrl ?? '',
                timeAgo: _timeAgo(image.addedAt),
                appColors: appColors,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(
    AppColors appColors,
    Map<String, int> counts,
    List<GalleryImage> images,
  ) {
    return SizedBox(
      height: 36,
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white,
            Colors.white,
            Colors.white,
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.85, 0.92, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 28),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('All (${images.length})'),
                selected: _selectedProject == null,
                onSelected: (_) => _onFilterChanged(null),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _selectedProject == null
                      ? Theme.of(context).colorScheme.onPrimary
                      : appColors.subtleText,
                ),
                selectedColor: Theme.of(context).colorScheme.primary,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            for (final entry in counts.entries)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(entry.key),
                  selected: _selectedProject == entry.key,
                  onSelected: (_) => _onFilterChanged(entry.key),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _selectedProject == entry.key
                        ? Theme.of(context).colorScheme.onPrimary
                        : appColors.subtleText,
                  ),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final GalleryImage image;
  final String httpBaseUrl;
  final String timeAgo;
  final AppColors appColors;

  const _GalleryTile({
    required this.image,
    required this.httpBaseUrl,
    required this.timeAgo,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = '$httpBaseUrl${image.url}';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FullScreenImageViewer(url: imageUrl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stack) =>
                      const Center(child: Icon(Icons.broken_image, size: 32)),
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
