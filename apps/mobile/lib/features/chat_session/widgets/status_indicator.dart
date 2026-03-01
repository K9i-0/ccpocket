import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

/// Compact status indicator that shows a colored icon and elapsed time when running.
/// Tap to show a tooltip with status text.
class StatusIndicator extends HookWidget {
  final ProcessStatus status;
  final bool inPlanMode;
  final VoidCallback? onLongPress;
  const StatusIndicator({
    super.key,
    required this.status,
    this.inPlanMode = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Track elapsed time when running/starting
    final isActive =
        status == ProcessStatus.running ||
        status == ProcessStatus.starting ||
        status == ProcessStatus.compacting;

    // Store the start time when entering active state
    final startTime = useRef<DateTime?>(null);
    final elapsed = useState<Duration>(Duration.zero);

    // Reset timer when status changes
    useEffect(() {
      if (isActive) {
        startTime.value ??= DateTime.now();
      } else {
        startTime.value = null;
        elapsed.value = Duration.zero;
      }
      return null;
    }, [isActive]);

    // Update elapsed time every second
    useEffect(() {
      if (!isActive || startTime.value == null) return null;

      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (startTime.value != null) {
          elapsed.value = DateTime.now().difference(startTime.value!);
        }
      });

      return timer.cancel;
    }, [isActive, startTime.value]);

    final (color, label) = switch (status) {
      ProcessStatus.starting => (appColors.statusStarting, 'Starting'),
      ProcessStatus.idle =>
        inPlanMode
            ? (appColors.statusPlan, 'Plan')
            : (appColors.statusIdle, 'Idle'),
      ProcessStatus.running =>
        inPlanMode
            ? (appColors.statusPlan, 'Plan')
            : (appColors.statusRunning, 'Running'),
      ProcessStatus.waitingApproval => (appColors.statusApproval, 'Approval'),
      ProcessStatus.compacting => (appColors.statusCompacting, 'Compacting'),
    };

    // Format elapsed time
    final elapsedStr = _formatDuration(elapsed.value);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Tooltip(
        message: isActive ? '$label ($elapsedStr)' : label,
        preferBelow: true,
        triggerMode: TooltipTriggerMode.tap,
        child: Padding(
          key: const ValueKey('status_indicator'),
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show elapsed time when active
              if (isActive && elapsed.value.inSeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Text(
                    elapsedStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              // Animated status dot
              _AnimatedStatusDot(color: color, isAnimating: isActive),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes >= 1) {
      return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inSeconds}s';
  }
}

/// Animated pulsing status dot
class _AnimatedStatusDot extends StatefulWidget {
  final Color color;
  final bool isAnimating;

  const _AnimatedStatusDot({required this.color, required this.isAnimating});

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isAnimating && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Transform.scale(
              scale: widget.isAnimating ? _animation.value : 1.0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: widget.isAnimating
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
