import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../l10n/app_localizations.dart';
import 'widgets/guide_page_about.dart';
import 'widgets/guide_page_bridge_setup.dart';
import 'widgets/guide_page_connection.dart';
import 'widgets/guide_page_launchd.dart';
import 'widgets/guide_page_ready.dart';
import 'widgets/guide_page_tailscale.dart';

@RoutePage()
class SetupGuideScreen extends HookWidget {
  const SetupGuideScreen({super.key});

  static const _pageCount = 6;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final pageController = usePageController();
    final currentPage = useState(0);

    void goBack() {
      if (currentPage.value > 0) {
        pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

    void goNext() {
      if (currentPage.value < _pageCount - 1) {
        pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

    void close() {
      context.router.maybePop();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.setupGuideTitle),
        actions: [
          TextButton(
            key: const ValueKey('guide_skip_button'),
            onPressed: close,
            child: Text(l.skip),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pages
          Expanded(
            child: PageView(
              controller: pageController,
              onPageChanged: (index) => currentPage.value = index,
              children: [
                const GuidePageAbout(),
                const GuidePageBridgeSetup(),
                const GuidePageConnection(),
                const GuidePageTailscale(),
                const GuidePageLaunchd(),
                GuidePageReady(onGetStarted: close),
              ],
            ),
          ),
          // Bottom navigation
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  // Back button
                  if (currentPage.value > 0)
                    TextButton.icon(
                      key: const ValueKey('guide_back_button'),
                      onPressed: goBack,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: Text(l.back),
                    )
                  else
                    const SizedBox(width: 80),
                  const Spacer(),
                  // Dot indicator
                  SmoothPageIndicator(
                    controller: pageController,
                    count: _pageCount,
                    effect: WormEffect(
                      dotWidth: 8,
                      dotHeight: 8,
                      spacing: 6,
                      activeDotColor: cs.primary,
                      dotColor: cs.outlineVariant,
                    ),
                  ),
                  const Spacer(),
                  // Next button
                  if (currentPage.value < _pageCount - 1)
                    TextButton.icon(
                      key: const ValueKey('guide_next_button'),
                      onPressed: goNext,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(l.next),
                    )
                  else
                    SizedBox(
                      width: 80,
                      child: TextButton(
                        key: const ValueKey('guide_done_button'),
                        onPressed: close,
                        child: Text(l.done),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
