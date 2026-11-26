import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'section_header.dart';

/// Loading state shared by Bridge connection and initial session list fetches.
class SessionListLoadingView extends StatelessWidget {
  const SessionListLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final l = AppLocalizations.of(context);

    return ListView(
      key: const ValueKey('session_list_loading'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        SectionHeader(
          icon: Icons.history,
          label: l.recentSessions,
          color: color,
        ),
        const SizedBox(height: 8),
        const SessionListLoadingStatus(),
        const SizedBox(height: 12),
        const SessionListSkeleton(),
      ],
    );
  }
}

/// Visible and screen-reader friendly description of the loading state.
class SessionListLoadingStatus extends StatelessWidget {
  const SessionListLoadingStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Semantics(
      liveRegion: true,
      label: l.loadingSessions,
      excludeSemantics: true,
      child: Row(
        key: const ValueKey('session_list_loading_status'),
        children: [
          Icon(Icons.sync, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.loadingSessions,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer placeholder list that mimics `RecentSessionCard` widgets.
class SessionListSkeleton extends StatefulWidget {
  const SessionListSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  /// Resolves shimmer base and highlight colors from [theme] rather than
  /// platform brightness so a manual light/dark choice is always respected.
  static ({Color base, Color highlight}) shimmerColorsFor(ThemeData theme) {
    final cs = theme.colorScheme;
    if (theme.brightness == Brightness.dark) {
      return (
        base: Color.lerp(
          cs.surfaceContainerHigh,
          cs.surfaceContainerHighest,
          0.45,
        )!,
        highlight: Color.lerp(
          cs.surfaceContainerHigh,
          cs.surfaceContainerHighest,
          0.85,
        )!,
      );
    }
    return (base: cs.surfaceContainer, highlight: cs.surfaceContainerLow);
  }

  @override
  State<SessionListSkeleton> createState() => _SessionListSkeletonState();
}

class _SessionListSkeletonState extends State<SessionListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _cardSpecs = [
    _SkeletonCardSpec(
      badgeWidth: 88,
      firstLineFactor: 0.92,
      secondLineFactor: 0.64,
      branchWidth: 76,
      dateWidth: 64,
    ),
    _SkeletonCardSpec(
      badgeWidth: 104,
      firstLineFactor: 0.84,
      secondLineFactor: 0.56,
      branchWidth: 62,
      dateWidth: 72,
    ),
    _SkeletonCardSpec(
      badgeWidth: 76,
      firstLineFactor: 0.95,
      secondLineFactor: 0.70,
      branchWidth: 54,
      dateWidth: 60,
    ),
    _SkeletonCardSpec(
      badgeWidth: 96,
      firstLineFactor: 0.88,
      secondLineFactor: 0.60,
      branchWidth: 84,
      dateWidth: 68,
    ),
    _SkeletonCardSpec(
      badgeWidth: 80,
      firstLineFactor: 0.90,
      secondLineFactor: 0.52,
      branchWidth: 68,
      dateWidth: 64,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = SessionListSkeleton.shimmerColorsFor(theme);
    final textDirection = Directionality.maybeOf(context);
    final borderColor = colorScheme.outlineVariant.withValues(alpha: 0.45);

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final dx = -2.0 + 4.0 * _controller.value;
          final gradient = LinearGradient(
            begin: AlignmentDirectional(dx - 1.0, -0.2),
            end: AlignmentDirectional(dx + 1.0, 0.2),
            colors: [colors.base, colors.highlight, colors.base],
            stops: const [0.1, 0.5, 0.9],
          );
          return Column(
            children: [
              for (var i = 0; i < widget.itemCount; i++)
                _SkeletonSessionCard(
                  spec: _cardSpecs[i % _cardSpecs.length],
                  cardColor: colorScheme.surfaceContainerHigh,
                  borderColor: borderColor,
                  boneColor: colors.base,
                  gradient: gradient,
                  textDirection: textDirection,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SkeletonCardSpec {
  const _SkeletonCardSpec({
    required this.badgeWidth,
    required this.firstLineFactor,
    required this.secondLineFactor,
    required this.branchWidth,
    required this.dateWidth,
  });

  final double badgeWidth;
  final double firstLineFactor;
  final double secondLineFactor;
  final double branchWidth;
  final double dateWidth;
}

class _SkeletonSessionCard extends StatelessWidget {
  const _SkeletonSessionCard({
    required this.spec,
    required this.cardColor,
    required this.borderColor,
    required this.boneColor,
    required this.gradient,
    required this.textDirection,
  });

  final _SkeletonCardSpec spec;
  final Color cardColor;
  final Color borderColor;
  final Color boneColor;
  final LinearGradient gradient;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) =>
              gradient.createShader(bounds, textDirection: textDirection),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBone(
                width: spec.badgeWidth,
                height: 20,
                borderRadius: 6,
                color: boneColor,
              ),
              const SizedBox(height: 10),
              FractionallySizedBox(
                widthFactor: spec.firstLineFactor,
                child: _SkeletonBone(
                  height: 14,
                  borderRadius: 4,
                  color: boneColor,
                ),
              ),
              const SizedBox(height: 6),
              FractionallySizedBox(
                widthFactor: spec.secondLineFactor,
                child: _SkeletonBone(
                  height: 14,
                  borderRadius: 4,
                  color: boneColor,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _SkeletonBone(
                    width: spec.branchWidth,
                    height: 12,
                    borderRadius: 4,
                    color: boneColor,
                  ),
                  const Spacer(),
                  _SkeletonBone(
                    width: spec.dateWidth,
                    height: 11,
                    borderRadius: 4,
                    color: boneColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBone extends StatelessWidget {
  const _SkeletonBone({
    this.width = double.infinity,
    required this.height,
    required this.borderRadius,
    required this.color,
  });

  final double width;
  final double height;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
