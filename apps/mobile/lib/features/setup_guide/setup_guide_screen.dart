import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../router/app_router.dart';
import '../../services/connect_deep_link_scope.dart';
import '../../services/connection_url_parser.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../session_list/workspace_shell_screen.dart';
import 'setup_guide_platform.dart';
export 'setup_guide_platform.dart';
import 'widgets/guide_page.dart';
import 'widgets/guide_page_about.dart';
import 'widgets/guide_page_desktop_cli_setup.dart';
import 'widgets/guide_page_local_bridge.dart';
import 'widgets/guide_page_mobile_connect.dart';
import 'widgets/guide_page_mobile_host_setup.dart';
import 'widgets/guide_page_ready.dart';

@RoutePage()
class SetupGuideScreen extends HookWidget {
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  /// Overrides whether the guide is for a Mac that runs its own Bridge
  /// (tests); defaults to the platform.
  final bool? localBridgeOverride;

  /// Explicit platform flow override for tests or previews.
  final SetupGuidePlatform? platformOverride;

  const SetupGuideScreen({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onClose,
    this.localBridgeOverride,
    this.platformOverride,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shell = WorkspaceShellScreen.maybeOf(context);
    final chrome = resolveWorkspacePaneChrome(
      platform: Theme.of(context).platform,
      isAdaptiveWorkspace: shell != null && !shell.isSinglePane,
      isLeftPaneVisible: shell?.isLeftPaneVisible ?? false,
      slot: WorkspacePaneSlot.center,
    );
    final platform = resolveSetupGuidePlatform(
      platformOverride: platformOverride,
      localBridgeOverride: localBridgeOverride,
    );
    final connectLinks = ConnectDeepLinkScope.maybeOf(context);
    final pageController = usePageController();
    final currentPage = useState(0);

    void close() {
      final closeHandler = onClose;
      if (closeHandler != null) {
        closeHandler();
        return;
      }
      context.router.maybePop();
    }

    Future<void> scanQrAndConnect() async {
      final result = await context.router.push<ConnectionParams>(
        const QrScanRoute(),
      );
      if (result == null || !context.mounted) return;
      connectLinks?.value = result;
      close();
    }

    final canScanQr =
        platform == SetupGuidePlatform.mobile &&
        !kIsWeb &&
        connectLinks != null;

    final pages = switch (platform) {
      SetupGuidePlatform.mobile => [
        const GuidePageAbout(
          platform: SetupGuidePlatform.mobile,
          totalSteps: 4,
        ),
        const GuidePageMobileHostSetup(totalSteps: 4),
        const GuidePageMobileConnect(totalSteps: 4),
        GuidePageReady(
          platform: SetupGuidePlatform.mobile,
          totalSteps: 4,
          onGetStarted: close,
          onScanQrCode: canScanQr ? scanQrAndConnect : null,
        ),
      ],
      SetupGuidePlatform.macOS => [
        const GuidePageAbout(platform: SetupGuidePlatform.macOS, totalSteps: 3),
        const GuidePageLocalBridge(totalSteps: 3),
        GuidePageReady(
          platform: SetupGuidePlatform.macOS,
          totalSteps: 3,
          onGetStarted: close,
        ),
      ],
      SetupGuidePlatform.desktopOther => [
        const GuidePageAbout(
          platform: SetupGuidePlatform.desktopOther,
          totalSteps: 3,
        ),
        const GuidePageDesktopCliSetup(totalSteps: 3),
        GuidePageReady(
          platform: SetupGuidePlatform.desktopOther,
          totalSteps: 3,
          onGetStarted: close,
        ),
      ],
    };

    final pageCount = pages.length;

    void goBack() {
      if (currentPage.value > 0) {
        pageController.previousPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }

    void goNext() {
      if (currentPage.value < pageCount - 1) {
        pageController.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }

    final leading = onBack == null
        ? null
        : IconButton(
            key: const ValueKey('embedded_setup_guide_back_button'),
            onPressed: onBack,
            style: chrome.useMacOSAdaptiveChrome
                ? chrome.compactButtonStyle()
                : null,
            icon: const Icon(Icons.arrow_back),
            tooltip: l.back,
          );

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
          title: chrome.wrapTitle(Text(l.setupGuideTitle)),
          actions: [
            TextButton(
              key: const ValueKey('guide_skip_button'),
              onPressed: close,
              child: Text(l.skip),
            ),
          ],
        ),
      ),
      body: PageView(
        controller: pageController,
        onPageChanged: (index) => currentPage.value = index,
        children: pages,
      ),
      bottomNavigationBar: GuideBottomBar(
        pageController: pageController,
        currentPage: currentPage.value,
        pageCount: pageCount,
        onBack: goBack,
        onNext: goNext,
        onDone: close,
      ),
    );
  }
}
