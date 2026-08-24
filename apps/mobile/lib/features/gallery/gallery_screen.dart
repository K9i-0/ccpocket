import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../services/bridge_service.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../session_list/workspace_shell_screen.dart';
import 'widgets/gallery_content.dart';
import 'widgets/gallery_empty_state.dart';

int _galleryRequestSequence = 0;

@RoutePage()
class GalleryScreen extends HookWidget {
  final String? sessionId;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  const GalleryScreen({
    super.key,
    this.sessionId,
    this.embedded = false,
    this.onBack,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final selectedProject = useState<String?>(null);
    final isSessionMode = sessionId != null;
    final scopedImages = useState<List<GalleryImage>>(const []);
    final scopedLoading = useState(isSessionMode);
    final requestId = useMemoized(
      () => 'gallery-${++_galleryRequestSequence}',
      [sessionId],
    );
    final bridge = context.read<BridgeService>();
    final shell = WorkspaceShellScreen.maybeOf(context);
    final chrome = resolveWorkspacePaneChrome(
      platform: Theme.of(context).platform,
      isAdaptiveWorkspace: shell != null && !shell.isSinglePane,
      isLeftPaneVisible: shell?.isLeftPaneVisible ?? false,
      slot: embedded && sessionId == null
          ? WorkspacePaneSlot.center
          : WorkspacePaneSlot.right,
    );

    useEffect(() {
      if (!isSessionMode) {
        scopedLoading.value = false;
        bridge.requestGallery(requestId: requestId);
        return null;
      }

      scopedImages.value = const [];
      scopedLoading.value = true;
      final resultSub = bridge.galleryResults.listen((result) {
        if (result.requestId != null && result.requestId != requestId) return;
        if (result.sessionId != null && result.sessionId != sessionId) return;
        if (result.project != null) return;
        scopedImages.value = result.images;
        scopedLoading.value = false;
      });
      final newImageSub = bridge.galleryNewImages.listen((image) {
        if (image.sessionId != sessionId) return;
        scopedImages.value = [
          image,
          ...scopedImages.value.where((existing) => existing.id != image.id),
        ];
      });
      bridge.requestGallery(sessionId: sessionId, requestId: requestId);
      return () {
        unawaited(resultSub.cancel());
        unawaited(newImageSub.cancel());
      };
    }, [bridge, isSessionMode, requestId, sessionId]);

    final globalImages = context.watch<GalleryCubit>().state;
    final images = isSessionMode
        ? scopedImages.value
        : globalImages.isNotEmpty
        ? globalImages
        : bridge.galleryImages;
    final leading = onBack != null
        ? IconButton(
            key: const ValueKey('embedded_gallery_back_button'),
            onPressed: onBack,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            style: chrome.useMacOSAdaptiveChrome
                ? chrome.compactButtonStyle()
                : null,
            icon: const Icon(Icons.arrow_back),
          )
        : null;

    return Scaffold(
      appBar: chrome.wrapAppBar(
        AppBar(
          toolbarHeight: chrome.toolbarHeight,
          automaticallyImplyLeading: !embedded,
          leading: chrome.wrapLeading(leading),
          leadingWidth: chrome.resolveLeadingWidth(
            hasLeading: leading != null,
            baseWidth: chrome.useMacOSAdaptiveChrome
                ? kWorkspaceMacOSToolbarLeadingSlotWidth
                : kToolbarHeight,
          ),
          titleSpacing: chrome.resolveTitleSpacing(hasLeading: leading != null),
          title: chrome.wrapTitle(
            Text(
              images.isEmpty
                  ? AppLocalizations.of(context).gallery
                  : AppLocalizations.of(context)
                        .galleryWithCount(images.length),
            ),
          ),
          actions: chrome.padActions([
            if (embedded && onClose != null)
              IconButton(
                key: const ValueKey('embedded_gallery_close_button'),
                onPressed: onClose,
                style: chrome.useMacOSAdaptiveChrome
                    ? chrome.compactButtonStyle()
                    : null,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
              ),
          ]),
        ),
      ),
      body: scopedLoading.value
          ? const Center(
              key: ValueKey('gallery_scope_loading'),
              child: CircularProgressIndicator(),
            )
          : images.isEmpty
          ? GalleryEmptyState(isSessionMode: isSessionMode)
          : GalleryContent(
              images: images,
              selectedProject: selectedProject.value,
              isSessionMode: isSessionMode,
              httpBaseUrl: bridge.httpBaseUrl ?? '',
              onProjectSelected: (p) => selectedProject.value = p,
              onImageDeleted: isSessionMode
                  ? (id) {
                      scopedImages.value = scopedImages.value
                          .where((image) => image.id != id)
                          .toList();
                    }
                  : null,
            ),
    );
  }
}
