import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

/// A thin glowing line at the bottom of the AppBar that indicates session status.
///
/// When active (running/starting/compacting), the line pulses with a glow effect.
/// When idle, it shows as a subtle static line.
class StatusLine extends StatefulWidget implements PreferredSizeWidget {
  final ProcessStatus status;
  final bool inPlanMode;

  const StatusLine({super.key, required this.status, this.inPlanMode = false});

  @override
  Size get preferredSize => const Size.fromHeight(2);

  @override
  State<StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<StatusLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (_isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!_isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isActive =>
      widget.status == ProcessStatus.running ||
      widget.status == ProcessStatus.starting ||
      widget.status == ProcessStatus.compacting;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;

    final color = switch (widget.status) {
      ProcessStatus.starting => appColors.statusStarting,
      ProcessStatus.idle =>
        widget.inPlanMode ? cs.tertiary : appColors.statusIdle,
      ProcessStatus.running =>
        widget.inPlanMode ? cs.tertiary : appColors.statusRunning,
      ProcessStatus.waitingApproval => appColors.statusApproval,
      ProcessStatus.compacting => appColors.statusCompacting,
    };

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowOpacity = _isActive ? _glowAnimation.value : 0.4;
        final blurRadius = _isActive ? 6.0 * _glowAnimation.value : 0.0;

        return Container(
          height: 2,
          decoration: BoxDecoration(
            color: color.withValues(alpha: glowOpacity),
            boxShadow: [
              if (blurRadius > 0)
                BoxShadow(
                  color: color.withValues(alpha: glowOpacity * 0.6),
                  blurRadius: blurRadius,
                  spreadRadius: 1,
                ),
            ],
          ),
        );
      },
    );
  }
}
