import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/bridge_providers.dart';
import 'widgets/gallery_content.dart';
import 'widgets/gallery_empty_state.dart';

class GalleryScreen extends HookConsumerWidget {
  final String? sessionId;

  const GalleryScreen({super.key, this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProject = useState<String?>(null);
    final isSessionMode = sessionId != null;

    useEffect(() {
      ref.read(bridgeServiceProvider).requestGallery(sessionId: sessionId);
      return null;
    }, [sessionId]);

    final images =
        ref.watch(galleryProvider).valueOrNull ??
        ref.read(bridgeServiceProvider).galleryImages;

    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: images.isEmpty
          ? GalleryEmptyState(isSessionMode: isSessionMode)
          : GalleryContent(
              images: images,
              selectedProject: selectedProject.value,
              isSessionMode: isSessionMode,
              httpBaseUrl: ref.read(bridgeServiceProvider).httpBaseUrl ?? '',
              onProjectSelected: (p) => selectedProject.value = p,
            ),
    );
  }
}
