import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

class SessionStatusDot extends StatefulWidget {
  final Color color;
  final bool animate;
  final bool glow;
  final bool inPlanMode;
  const SessionStatusDot({
    super.key,
    required this.color,
    required this.animate,
    this.glow = false,
    this.inPlanMode = false,
  });

  @override
  State<SessionStatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<SessionStatusDot>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.animate) _pulseController.repeat(reverse: true);
    if (widget.inPlanMode) _orbitController.repeat();
  }

  @override
  void didUpdateWidget(SessionStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.animate && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
    if (widget.inPlanMode && !_orbitController.isAnimating) {
      _orbitController.repeat();
    } else if (!widget.inPlanMode && _orbitController.isAnimating) {
      _orbitController.stop();
      _orbitController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _orbitController]),
      builder: (context, child) {
        return CustomPaint(
          size: const Size(14, 14),
          painter: _StatusDotPainter(
            color: widget.color,
            pulseValue: _pulseAnimation.value,
            animate: widget.animate,
            glow: widget.glow,
            inPlanMode: widget.inPlanMode,
            orbitProgress: _orbitController.value,
            planColor: appColors.statusPlan,
            planGlowColor: appColors.statusPlanGlow,
            isDark: isDark,
          ),
        );
      },
    );
  }
}

class _StatusDotPainter extends CustomPainter {
  final Color color;
  final double pulseValue;
  final bool animate;
  final bool glow;
  final bool inPlanMode;
  final double orbitProgress;
  final Color planColor;
  final Color planGlowColor;
  final bool isDark;

  _StatusDotPainter({
    required this.color,
    required this.pulseValue,
    required this.animate,
    this.glow = false,
    required this.inPlanMode,
    required this.orbitProgress,
    required this.planColor,
    required this.planGlowColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const dotRadius = 5.0;

    // Glow behind the dot (animated pulse or static unseen glow)
    if (animate) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: pulseValue * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(center, dotRadius + 1.5, glowPaint);
    } else if (glow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(center, dotRadius + 1.5, glowPaint);
    }

    // Main dot
    final dotPaint = Paint()..color = color.withValues(alpha: pulseValue);
    canvas.drawCircle(center, dotRadius, dotPaint);

    // Plan mode: orbiting light around the dot
    if (inPlanMode) {
      final orbitRadius = dotRadius + 2.5;
      final path = Path()
        ..addOval(Rect.fromCircle(center: center, radius: orbitRadius));
      final metric = path.computeMetrics().first;
      final lightPos = metric
          .getTangentForOffset(metric.length * orbitProgress)!
          .position;

      // Clip to a thin ring around the dot
      const ringHalf = 2.0;
      final clipPath = Path()
        ..addOval(
          Rect.fromCircle(center: center, radius: orbitRadius + ringHalf),
        )
        ..addOval(Rect.fromCircle(center: center, radius: dotRadius - 0.5))
        ..fillType = PathFillType.evenOdd;

      canvas.save();
      canvas.clipPath(clipPath);

      // Glow
      final glowRect = Rect.fromCircle(center: lightPos, radius: 8);
      final radial = RadialGradient(
        colors: [
          planGlowColor.withValues(alpha: isDark ? 0.9 : 0.7),
          planColor.withValues(alpha: isDark ? 0.3 : 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      );
      final glowPaint = Paint()
        ..shader = radial.createShader(glowRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawRect(glowRect, glowPaint);

      // Bright core
      final coreRect = Rect.fromCircle(center: lightPos, radius: 4);
      final coreGradient = RadialGradient(
        colors: [
          planGlowColor.withValues(alpha: isDark ? 1.0 : 0.85),
          planColor.withValues(alpha: isDark ? 0.4 : 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      canvas.drawRect(
        coreRect,
        Paint()..shader = coreGradient.createShader(coreRect),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StatusDotPainter oldDelegate) =>
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.orbitProgress != orbitProgress ||
      oldDelegate.color != color ||
      oldDelegate.glow != glow ||
      oldDelegate.inPlanMode != inPlanMode;
}
