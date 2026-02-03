import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/messages.dart';
import '../../providers/bridge_providers.dart';
import 'widgets/gallery_empty_state.dart';
import 'widgets/gallery_filter_chips.dart';
import 'widgets/gallery_tile.dart';

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
    final images =
        ref.watch(galleryProvider).valueOrNull ??
        ref.read(bridgeServiceProvider).galleryImages;

    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: images.isEmpty
          ? GalleryEmptyState(isSessionMode: _isSessionMode)
          : _buildContent(images),
    );
  }

  Widget _buildContent(List<GalleryImage> images) {
    final filtered = _filteredImages(images);
    final counts = _projectCounts(images);

    return Column(
      children: [
        if (!_isSessionMode && counts.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: GalleryFilterChips(
              projectCounts: counts,
              totalCount: images.length,
              selectedProject: _selectedProject,
              onSelected: (p) => setState(() => _selectedProject = p),
            ),
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
              return GalleryTile(
                image: image,
                httpBaseUrl: ref.read(bridgeServiceProvider).httpBaseUrl ?? '',
                timeAgo: _timeAgo(image.addedAt),
              );
            },
          ),
        ),
      ],
    );
  }
}
