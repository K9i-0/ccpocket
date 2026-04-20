import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/bridge_cubits.dart';
import '../../services/bridge_service.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../session_list/workspace_shell_screen.dart';
import 'widgets/gallery_content.dart';
import 'widgets/gallery_empty_state.dart';

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
      context.read<BridgeService>().requestGallery(sessionId: sessionId);
      return null;
    }, [sessionId]);

    final bridge = context.read<BridgeService>();
    final images = context.watch<GalleryCubit>().state.isNotEmpty
        ? context.watch<GalleryCubit>().state
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
      appBar: AppBar(
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
        title: Text(
          images.isEmpty
              ? AppLocalizations.of(context).gallery
              : AppLocalizations.of(context).galleryWithCount(images.length),
        ),
        actions: [
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
        ],
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
