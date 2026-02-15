import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../providers/bridge_cubits.dart';
import '../../services/bridge_service.dart';
import 'widgets/gallery_content.dart';
import 'widgets/gallery_empty_state.dart';

@RoutePage()
class GalleryScreen extends HookWidget {
  final String? sessionId;

  const GalleryScreen({super.key, this.sessionId});

  @override
  Widget build(BuildContext context) {
    final selectedProject = useState<String?>(null);
    final isSessionMode = sessionId != null;

    useEffect(() {
      context.read<BridgeService>().requestGallery(sessionId: sessionId);
      return null;
    }, [sessionId]);

    final bridge = context.read<BridgeService>();
    final images = context.watch<GalleryCubit>().state.isNotEmpty
        ? context.watch<GalleryCubit>().state
        : bridge.galleryImages;

    return Scaffold(
      appBar: AppBar(
        title: Text(images.isEmpty ? 'Gallery' : 'Gallery (${images.length})'),
      ),
      body: images.isEmpty
          ? GalleryEmptyState(isSessionMode: isSessionMode)
          : GalleryContent(
              images: images,
              selectedProject: selectedProject.value,
              isSessionMode: isSessionMode,
              httpBaseUrl: bridge.httpBaseUrl ?? '',
              onProjectSelected: (p) => selectedProject.value = p,
            ),
    );
  }
}
