import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'guide_components.dart';

/// Shared responsive page frame for each setup guide step.
class GuidePage extends StatelessWidget {
  const GuidePage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.subtitle,
    this.stepIndex,
    this.totalSteps,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int? stepIndex;
  final int? totalSteps;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final palette = GuidePalette.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              const SizedBox(height: 4),
              if (stepIndex != null && totalSteps != null) ...[
                GuideBadge(
                  label: l.guideStepProgress(stepIndex!, totalSteps!),
                  filled: false,
                ),
                const SizedBox(height: 10),
              ],
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: palette.accentSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.accentBorder),
                ),
                child: Icon(icon, size: 26, color: cs.primary),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 18),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation bar with Back, dot indicator, and primary Next / Done CTA.
class GuideBottomBar extends StatelessWidget {
  const GuideBottomBar({
    super.key,
    required this.pageController,
    required this.currentPage,
    required this.pageCount,
    required this.onBack,
    required this.onNext,
    required this.onDone,
  });

  final PageController pageController;
  final int currentPage;
  final int pageCount;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final palette = GuidePalette.of(context);
    final isFirst = currentPage == 0;
    final isLast = currentPage >= pageCount - 1;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: palette.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      heightFactor: 1,
                      child: isFirst
                          ? const SizedBox.shrink()
                          : TextButton.icon(
                              key: const ValueKey('guide_back_button'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: onBack,
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                              ),
                              label: Text(l.back),
                            ),
                    ),
                  ),
                  const Spacer(),
                  ExpandingDotsIndicator(
                    controller: pageController,
                    count: pageCount,
                    dotWidth: 8,
                    dotHeight: 8,
                    spacing: 6,
                    expansionFactor: 2.5,
                    activeDotColor: cs.primary,
                    dotColor: palette.cardBorder,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 112,
                    child: Align(
                      alignment: Alignment.centerRight,
                      heightFactor: 1,
                      child: isLast
                          ? FilledButton(
                              key: const ValueKey('guide_done_button'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 11,
                                ),
                              ),
                              onPressed: onDone,
                              child: Text(l.done),
                            )
                          : FilledButton.icon(
                              key: const ValueKey('guide_next_button'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                              ),
                              onPressed: onNext,
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(l.next),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated page indicator that expands the active dot into a pill,
/// synced to [controller]'s scroll position.
class ExpandingDotsIndicator extends StatelessWidget {
  const ExpandingDotsIndicator({
    super.key,
    required this.controller,
    required this.count,
    required this.activeDotColor,
    required this.dotColor,
    this.dotWidth = 8,
    this.dotHeight = 8,
    this.spacing = 6,
    this.expansionFactor = 2.5,
  });

  final PageController controller;
  final int count;
  final Color activeDotColor;
  final Color dotColor;
  final double dotWidth;
  final double dotHeight;
  final double spacing;
  final double expansionFactor;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final radius = BorderRadius.circular(dotHeight / 2);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final rawPage =
            controller.positions.length == 1 &&
                controller.position.hasContentDimensions
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();
        final page = rawPage.clamp(0.0, (count - 1).toDouble());
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              _buildDot(i, page, radius),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDot(int index, double page, BorderRadius radius) {
    final t = (1.0 - (page - index).abs()).clamp(0.0, 1.0);
    final width = dotWidth + dotWidth * (expansionFactor - 1) * t;
    final color = Color.lerp(dotColor, activeDotColor, t)!;
    return Container(
      width: width,
      height: dotHeight,
      decoration: BoxDecoration(color: color, borderRadius: radius),
    );
  }
}
