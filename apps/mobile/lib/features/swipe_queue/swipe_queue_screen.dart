import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'swipe_queue_data.dart';
import 'widgets/approval_card.dart';
import 'widgets/progress_bar.dart';

/// Color palette for option swipe zones.
const optionSwipeColors = [
  Colors.blue,
  Colors.teal,
  Colors.purple,
  Colors.orange,
];

/// How the current card responds to swipe gestures.
enum SwipeMode {
  /// Both directions: right = approve, left = reject.
  full,

  /// Both directions: maps drag position to one of the N options.
  selectOption,

  /// Left only: skip / defer. Right is clamped.
  deferOnly,
}

/// Swipe-based approval queue screen.
@RoutePage()
class SwipeQueueScreen extends StatefulWidget {
  const SwipeQueueScreen({super.key});

  @override
  State<SwipeQueueScreen> createState() => _SwipeQueueScreenState();
}

class _SwipeQueueScreenState extends State<SwipeQueueScreen>
    with TickerProviderStateMixin {
  late List<ApprovalItem> _queue;
  int _processedCount = 0;
  int _streak = 0;
  int _bestStreak = 0;
  bool _allCleared = false;

  // Defer tracking
  final Map<String, int> _deferCounts = {};

  // Drag state
  double _dragX = 0;
  double _dragY = 0;
  bool _isFlyingAway = false;
  bool _wasOverThreshold = false;
  late AnimationController _flyAwayController;
  late CurvedAnimation _flyAwayCurve;
  double _flyDirectionX = 1; // -1 left, 1 right
  double _flyDirectionY = 0; // 0 horizontal, 1 down (skip)

  // Spring snap-back
  late AnimationController _snapBackController;
  double _snapStartX = 0;
  double _snapStartY = 0;

  @override
  void initState() {
    super.initState();
    _queue = List.of(sampleApprovalItems);

    _flyAwayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onFlyAwayComplete();
        }
      });
    _flyAwayCurve = CurvedAnimation(
      parent: _flyAwayController,
      curve: Curves.easeIn,
    );

    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        setState(() {
          final t = _snapBackController.value;
          _dragX = _snapStartX * (1 - t);
          _dragY = _snapStartY * (1 - t);
        });
      });
  }

  @override
  void dispose() {
    _flyAwayController.dispose();
    _flyAwayCurve.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  // ── Swipe mode classification ────────────────────────────────────────

  SwipeMode get _swipeMode {
    if (_queue.isEmpty) return SwipeMode.full;
    final item = _queue.first;
    switch (item.type) {
      case ApprovalType.toolApproval:
      case ApprovalType.planApproval:
        return SwipeMode.full;
      case ApprovalType.askQuestion:
        if (!item.multiSelect &&
            item.options != null &&
            item.options!.isNotEmpty) {
          return SwipeMode.selectOption;
        }
        return SwipeMode.deferOnly;
      case ApprovalType.textInput:
        return SwipeMode.deferOnly;
    }
  }

  /// Drag distance from origin.
  double get _dragDist => sqrt(_dragX * _dragX + _dragY * _dragY);

  /// Drag angle in radians. 0 = right, pi/2 = up, -pi/2 = down, ±pi = left.
  double get _dragAngle => atan2(-_dragY, _dragX);

  /// For selectOption mode: compute which option index the current drag
  /// position corresponds to, using radial (angle-based) zones.
  /// Right half-circle is divided into N equal sectors for N options.
  int? get _highlightedOptionIndex {
    if (_swipeMode != SwipeMode.selectOption) return null;
    if (_queue.isEmpty) return null;
    final options = _queue.first.options;
    if (options == null || options.isEmpty) return null;
    if (_dragDist < 15) return null; // Dead zone

    final angle = _dragAngle;
    // Left half-circle = skip zone, no option highlighted
    if (angle.abs() > pi / 2) return null;

    final count = options.length;
    // Map angle from +pi/2 (top) to -pi/2 (bottom) → index 0..count-1
    final normalized = ((pi / 2 - angle) / pi).clamp(0.0, 1.0);
    return (normalized * count).floor().clamp(0, count - 1);
  }

  /// Whether the current drag is in the skip zone.
  /// For selectOption: left half-circle. For others: downward drag.
  bool get _isInSkipZone {
    if (_swipeMode == SwipeMode.selectOption) {
      if (_dragDist < 15) return false;
      return _dragAngle.abs() > pi / 2;
    }
    return _dragY > 30 && _dragX.abs() < _dragY * 0.8;
  }

  /// Legacy check for non-selectOption down-drag (used in full/deferOnly).
  bool get _isDraggingDown => _dragY > 30 && _dragX.abs() < _dragY * 0.8;

  // ── Gesture handlers ─────────────────────────────────────────────────

  void _onPanStart(DragStartDetails details) {
    // Cancel any lingering snap-back from previous card
    if (_snapBackController.isAnimating) {
      _snapBackController.stop();
    }
    // Ensure clean state at drag start
    _dragX = 0;
    _dragY = 0;
    _wasOverThreshold = false;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isFlyingAway) return;
    final mode = _swipeMode;

    final dx = details.delta.dx;
    final dy = details.delta.dy;

    if (mode == SwipeMode.selectOption) {
      // Radial mode: free XY drag (no vertical filter)
      setState(() {
        _dragX += dx;
        _dragY += dy;
      });

      // Distance-based threshold haptic
      final screenWidth = MediaQuery.of(context).size.width;
      final threshold = screenWidth * 0.25;
      final isOver = _dragDist > threshold;
      if (isOver && !_wasOverThreshold) {
        HapticFeedback.selectionClick();
        _wasOverThreshold = true;
      } else if (!isOver && _wasOverThreshold) {
        HapticFeedback.selectionClick();
        _wasOverThreshold = false;
      }
      return;
    }

    // Non-selectOption modes: original horizontal-primary logic
    // Allow downward drag if mostly vertical and downward
    final isDownwardDrag =
        dy > 0 && dy.abs() > dx.abs() * 1.2 && _dragX.abs() < 40;

    // Vertical-dominant drag: don't interfere with content scrolling
    // BUT allow downward drag for skip gesture
    if (!isDownwardDrag && dy.abs() > dx.abs() * 1.5) return;

    setState(() {
      if (isDownwardDrag) {
        _dragY += dy;
        _dragX += dx * 0.3;
        if (_dragY < 0) _dragY = 0;
      } else {
        _dragX += dx;
        _dragY += dy;

        if (mode == SwipeMode.deferOnly && _dragX > 0) {
          _dragX = 0;
        }
      }
    });

    if (!_isDraggingDown) {
      final threshold = MediaQuery.of(context).size.width * 0.3;
      final isOver = _dragX.abs() > threshold;
      if (isOver && !_wasOverThreshold) {
        HapticFeedback.selectionClick();
        _wasOverThreshold = true;
      } else if (!isOver && _wasOverThreshold) {
        HapticFeedback.selectionClick();
        _wasOverThreshold = false;
      }
    } else {
      final screenHeight = MediaQuery.of(context).size.height;
      final verticalThreshold = screenHeight * 0.15;
      final isOverVertical = _dragY > verticalThreshold;
      if (isOverVertical && !_wasOverThreshold) {
        HapticFeedback.selectionClick();
        _wasOverThreshold = true;
      } else if (!isOverVertical && _wasOverThreshold) {
        HapticFeedback.selectionClick();
        _wasOverThreshold = false;
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isFlyingAway) return;

    final mode = _swipeMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final velocity = details.velocity.pixelsPerSecond;

    if (mode == SwipeMode.selectOption) {
      // Radial mode: distance + angle based
      final dist = _dragDist;
      final velMagnitude =
          sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy);
      final threshold = screenWidth * 0.25;
      final effectiveThreshold =
          velMagnitude > 800 ? threshold * 0.5 : threshold;

      if (dist > effectiveThreshold) {
        // Fly away in drag direction (normalized vector)
        _flyDirectionX = _dragX / dist;
        _flyDirectionY = _dragY / dist;
        _isFlyingAway = true;
        _wasOverThreshold = false;
        _flyAwayController.forward(from: 0);
      } else {
        _snapBack();
      }
      return;
    }

    // Non-selectOption modes: original horizontal + downward logic
    final horizontalThreshold = screenWidth * 0.3;
    final verticalThreshold = screenHeight * 0.15;
    final effectiveHorizontalThreshold =
        velocity.dx.abs() > 800
            ? horizontalThreshold * 0.5
            : horizontalThreshold;
    final effectiveVerticalThreshold =
        velocity.dy > 500 ? verticalThreshold * 0.5 : verticalThreshold;

    // Priority 1: Downward skip
    if (_dragY > effectiveVerticalThreshold && _isDraggingDown) {
      _flyDirectionX = 0;
      _flyDirectionY = 1;
      _isFlyingAway = true;
      _wasOverThreshold = false;
      _flyAwayController.forward(from: 0);
      return;
    }

    // Priority 2: Horizontal swipe
    if (_dragX.abs() > effectiveHorizontalThreshold) {
      _flyDirectionX = _dragX > 0 ? 1 : -1;
      _flyDirectionY = 0;
      _isFlyingAway = true;
      _wasOverThreshold = false;
      _flyAwayController.forward(from: 0);
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    _snapStartX = _dragX;
    _snapStartY = _dragY;
    _wasOverThreshold = false;
    _snapBackController.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 500, damping: 30),
        0,
        1,
        0,
      ),
    );
    HapticFeedback.selectionClick();
  }

  void _onFlyAwayComplete() {
    final mode = _swipeMode;

    if (mode == SwipeMode.selectOption) {
      // Radial: determine zone by fly direction angle
      final angle = atan2(-_flyDirectionY, _flyDirectionX);
      if (angle.abs() > pi / 2) {
        // Left half-circle → skip
        _deferItem();
      } else {
        // Right half-circle → select option by angle
        final options = _queue.first.options!;
        final count = options.length;
        final normalized = ((pi / 2 - angle) / pi).clamp(0.0, 1.0);
        final idx = (normalized * count).floor().clamp(0, count - 1);
        _onSelectOption(options[idx].label);
      }
      return;
    }

    // Non-selectOption modes
    if (_flyDirectionY > 0) {
      _deferItem();
      return;
    }
    if (mode == SwipeMode.deferOnly) {
      _deferItem();
    } else {
      _processItem(approved: _flyDirectionX > 0);
    }
  }

  // ── Item processing ──────────────────────────────────────────────────

  void _processItem({required bool approved}) {
    final newStreak = approved ? _streak + 1 : 0;
    if (newStreak >= 5) {
      HapticFeedback.heavyImpact();
    } else if (newStreak >= 3) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    if (!approved && _streak >= 3) {
      HapticFeedback.heavyImpact();
    }

    setState(() {
      if (_queue.isNotEmpty) _queue.removeAt(0);
      _processedCount++;
      _streak = newStreak;
      if (_streak > _bestStreak) _bestStreak = _streak;
      _resetDragState();
      if (_queue.isEmpty) _allCleared = true;
    });
  }

  void _deferItem() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_queue.isNotEmpty) {
        final item = _queue.removeAt(0);
        _deferCounts[item.id] = (_deferCounts[item.id] ?? 0) + 1;
        _queue.add(item);
      }
      _streak = 0; // Break streak on defer
      _resetDragState();
    });
  }

  void _onSelectOption(String option) {
    HapticFeedback.lightImpact();
    _processItem(approved: true);
  }

  void _onSelectMultiple(Set<String> options) {
    HapticFeedback.lightImpact();
    _processItem(approved: true);
  }

  void _onSubmitText(String text) {
    HapticFeedback.lightImpact();
    _processItem(approved: true);
  }

  void _resetDragState() {
    _dragX = 0;
    _dragY = 0;
    _isFlyingAway = false;
    _wasOverThreshold = false;
    _flyDirectionX = 1;
    _flyDirectionY = 0;
    // Reset snap-back origins BEFORE resetting controller to prevent
    // the listener from restoring stale values when value snaps to 0.
    _snapStartX = 0;
    _snapStartY = 0;
    _flyAwayController.reset();
    _snapBackController.reset();
  }

  void _resetQueue() {
    setState(() {
      _queue = List.of(sampleApprovalItems);
      _processedCount = 0;
      _streak = 0;
      _bestStreak = 0;
      _allCleared = false;
      _deferCounts.clear();
      _resetDragState();
    });
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = sampleApprovalItems.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Queue'),
        actions: [
          if (_processedCount > 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset queue',
              onPressed: _resetQueue,
            ),
        ],
      ),
      body: Column(
        children: [
          QueueProgressBar(
            processed: _processedCount,
            total: total,
            streak: _streak,
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                _allCleared ? _buildAllClearedState(cs) : _buildCardStack(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStack(ColorScheme cs) {
    if (_queue.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final threshold = screenWidth * 0.3;
    final mode = _swipeMode;
    final dragProgress = mode == SwipeMode.selectOption
        ? (_dragDist / (screenWidth * 0.25)).clamp(0.0, 1.0)
        : (_dragX.abs() / threshold).clamp(0.0, 1.0);
    final inSkipZone = _isInSkipZone;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            // Third card — parallax
            if (_queue.length > 2)
              Positioned(
                top: _lerp(32, 16, dragProgress),
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _lerp(0.3, 0.6, dragProgress),
                  child: Transform.scale(
                    scale: _lerp(0.9, 0.95, dragProgress),
                    child: SizedBox(
                      height: constraints.maxHeight - 40,
                      child: ApprovalCard(
                        item: _queue[2],
                        onApprove: () {},
                        onReject: () {},
                      ),
                    ),
                  ),
                ),
              ),

            // Second card — parallax
            if (_queue.length > 1)
              Positioned(
                top: _lerp(16, 0, dragProgress),
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _lerp(0.6, 1.0, dragProgress),
                  child: Transform.scale(
                    scale: _lerp(0.95, 1.0, dragProgress),
                    child: SizedBox(
                      height: constraints.maxHeight - 24,
                      child: ApprovalCard(
                        item: _queue[1],
                        onApprove: () {},
                        onReject: () {},
                      ),
                    ),
                  ),
                ),
              ),

            // Top card — draggable
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation:
                    Listenable.merge([_flyAwayController, _snapBackController]),
                builder: (context, child) {
                  final flyProgress = _flyAwayCurve.value;
                  final totalX = _isFlyingAway
                      ? _dragX +
                          _flyDirectionX * screenWidth * 1.5 * flyProgress
                      : _dragX;
                  final totalY = _isFlyingAway
                      ? _dragY +
                          _flyDirectionY * screenHeight * 1.5 * flyProgress
                      : _dragY;
                  final rotation = (totalX / screenWidth) * 0.3;
                  final opacity = _isFlyingAway
                      ? (1.0 - ((flyProgress - 0.3) / 0.7).clamp(0.0, 1.0))
                          .clamp(0.0, 1.0)
                      : 1.0;
                  final isDragging = (_dragX.abs() > 5 || _dragY > 5) &&
                      !_isFlyingAway;
                  final scale =
                      isDragging ? _lerp(1.0, 1.02, dragProgress) : 1.0;

                  return Transform.translate(
                    offset: Offset(totalX, totalY),
                    child: Transform.rotate(
                      angle: rotation,
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: SizedBox(
                    height: constraints.maxHeight - 8,
                    child: ApprovalCard(
                      key: ValueKey(_queue.first.id),
                      item: _queue.first,
                      dragOffset: _dragX,
                      dragOffsetY: _dragY,
                      highlightedOptionIndex: _highlightedOptionIndex,
                      isInSkipZone: _isInSkipZone,
                      isDeferred: (_deferCounts[_queue.first.id] ?? 0) > 0,
                      onApprove: () => _processItem(approved: true),
                      onReject: () => _processItem(approved: false),
                      onSelectOption: _onSelectOption,
                      onSelectMultiple: _onSelectMultiple,
                      onSubmitText: _onSubmitText,
                    ),
                  ),
                ),
              ),
            ),

            // Radial zone overlay for selectOption mode
            // Covers the full screen area so zones extend beyond the card
            if (mode == SwipeMode.selectOption &&
                _dragDist > 15 &&
                _queue.first.options != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: _buildRadialZoneOverlay(
                    _queue.first.options!.length,
                  ),
                ),
              ),

            // Overlay label — selectOption radial
            if (mode == SwipeMode.selectOption && _dragDist > 30)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildSwipeLabel(
                    _overlayText,
                    _overlayColor,
                    _dragDist,
                  ),
                ),
              ),

            // Overlay label — horizontal (non-selectOption)
            if (mode != SwipeMode.selectOption &&
                !inSkipZone &&
                (_dragX.abs() > 30 && mode != SwipeMode.deferOnly ||
                    (_dragX < -30 && mode == SwipeMode.deferOnly)))
              Positioned(
                top: 40,
                left: _dragX > 0 ? null : 40,
                right: _dragX > 0 ? 40 : null,
                child: _buildSwipeLabel(
                  _overlayText,
                  _overlayColor,
                  _dragX.abs(),
                ),
              ),

            // Overlay label — downward skip (non-selectOption)
            if (mode != SwipeMode.selectOption &&
                inSkipZone &&
                _dragY > 30)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildSwipeLabel(
                    'SKIP',
                    Colors.amber,
                    _dragY,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Zone boundary overlay ───────────────────────────────────────────

  Widget _buildRadialZoneOverlay(int optionCount) {
    final highlightIdx = _highlightedOptionIndex;
    final zoneOpacity = (_dragDist / 80).clamp(0.0, 1.0);

    return AnimatedOpacity(
      opacity: zoneOpacity,
      duration: const Duration(milliseconds: 120),
      child: CustomPaint(
        painter: _RadialZonePainter(
          optionCount: optionCount,
          highlightedIndex: highlightIdx,
          isInSkipZone: _isInSkipZone,
          colors: optionSwipeColors,
        ),
      ),
    );
  }

  // ── Overlay helpers ──────────────────────────────────────────────────

  String get _overlayText {
    final mode = _swipeMode;
    if (mode == SwipeMode.selectOption) {
      if (_isInSkipZone) return 'SKIP';
      final idx = _highlightedOptionIndex;
      if (idx != null && _queue.first.options != null) {
        return _queue.first.options![idx].label.toUpperCase();
      }
      return '';
    }
    if (mode == SwipeMode.deferOnly) return 'SKIP';
    return _dragX > 0 ? 'APPROVE' : 'REJECT';
  }

  Color get _overlayColor {
    final mode = _swipeMode;
    if (mode == SwipeMode.selectOption) {
      if (_isInSkipZone) return Colors.amber;
      final idx = _highlightedOptionIndex;
      if (idx != null) {
        return optionSwipeColors[idx % optionSwipeColors.length];
      }
      return Colors.blue;
    }
    if (mode == SwipeMode.deferOnly) return Colors.amber;
    return _dragX > 0 ? Colors.green : Colors.red;
  }

  Widget _buildSwipeLabel(String text, Color color, double offset) {
    final opacity = (offset / 150).clamp(0.0, 1.0);
    final scale = _lerp(0.6, 1.0, (offset / 150).clamp(0.0, 1.0));
    return Transform.scale(
      scale: scale,
      child: Transform.rotate(
        angle: _isDraggingDown ? 0 : (_dragX > 0 ? -0.2 : 0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: 0.1),
          ),
          child: Opacity(
            opacity: opacity,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Cleared state ────────────────────────────────────────────────────

  Widget _buildAllClearedState(ColorScheme cs) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline,
                  size: 48, color: cs.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text('All Clear!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const SizedBox(height: 8),
          Text('$_processedCount items processed',
              style: TextStyle(fontSize: 14, color: appColors.subtleText)),
          if (_bestStreak > 0) ...[
            const SizedBox(height: 4),
            Text('Best streak: $_bestStreak',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary)),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _resetQueue,
            icon: const Icon(Icons.replay),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// CustomPainter that draws radial (fan-shaped) zone sectors.
/// Right half-circle: N option sectors. Left half-circle: skip zone.
class _RadialZonePainter extends CustomPainter {
  final int optionCount;
  final int? highlightedIndex;
  final bool isInSkipZone;
  final List<Color> colors;

  _RadialZonePainter({
    required this.optionCount,
    required this.highlightedIndex,
    required this.isInSkipZone,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width; // Large enough to fill the card

    // Left half-circle: skip zone (amber)
    final skipAlpha = isInSkipZone ? 0.12 : 0.03;
    final skipPaint = Paint()
      ..color = Colors.amber.withValues(alpha: skipAlpha)
      ..style = PaintingStyle.fill;
    // Left half = from 90° to 270° (in canvas coords: pi/2 to 3*pi/2)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi / 2, // start angle (pointing down)
      pi, // sweep 180°
      true,
      skipPaint,
    );

    // Right half-circle: option sectors
    final sectorAngle = pi / optionCount;
    for (var i = 0; i < optionCount; i++) {
      final color = colors[i % colors.length];
      final isHighlighted = highlightedIndex == i;
      final alpha = isHighlighted ? 0.15 : 0.04;

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      // Sector: from top-right going clockwise
      // i=0 starts at -pi/2 (pointing up), each sector spans sectorAngle
      final startAngle = -pi / 2 + (i * sectorAngle);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sectorAngle,
        true,
        paint,
      );

      // Draw boundary line between sectors
      if (i > 0) {
        final lineAngle = -pi / 2 + (i * sectorAngle);
        final lineEnd = Offset(
          center.dx + radius * cos(lineAngle),
          center.dy + radius * sin(lineAngle),
        );
        final linePaint = Paint()
          ..color = color.withValues(alpha: 0.2)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(center, lineEnd, linePaint);
      }
    }

    // Boundary line between left (skip) and right (options)
    final boundaryPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    // Top boundary (pointing up)
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - radius),
      boundaryPaint,
    );
    // Bottom boundary (pointing down)
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy + radius),
      boundaryPaint,
    );
  }

  @override
  bool shouldRepaint(_RadialZonePainter oldDelegate) =>
      oldDelegate.highlightedIndex != highlightedIndex ||
      oldDelegate.isInSkipZone != isInSkipZone ||
      oldDelegate.optionCount != optionCount;
}
