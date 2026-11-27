import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Keeps the source pane and the preview scrolled to the same place, and marks
// in the preview the block the caret is in.
//
// The link between the two is `MarkdownDocument.blockSourceRanges`: it says
// which stretch of source each block came from. A block's top in the preview
// and the line its source starts on in the editor make one anchor; scrolling
// between two anchors is interpolated.

/// A pair of scroll offsets that show the same place: [source] in the editor
/// and [preview] in the preview.
typedef SyncAnchor = ({double source, double preview});

/// Maps [offset] through [anchors] from one side to the other, linearly
/// between neighbours. [anchors] must ascend on both sides.
double mapScrollOffset(
  double offset,
  List<SyncAnchor> anchors, {
  required bool fromSource,
}) {
  if (anchors.isEmpty) return offset;
  double from(SyncAnchor anchor) => fromSource ? anchor.source : anchor.preview;
  double to(SyncAnchor anchor) => fromSource ? anchor.preview : anchor.source;

  if (offset <= from(anchors.first)) return to(anchors.first);
  if (offset >= from(anchors.last)) return to(anchors.last);
  var low = 0;
  var high = anchors.length - 1;
  while (high - low > 1) {
    final middle = (low + high) >> 1;
    if (from(anchors[middle]) <= offset) {
      low = middle;
    } else {
      high = middle;
    }
  }
  final a = anchors[low];
  final b = anchors[high];
  final span = from(b) - from(a);
  if (span <= 0) return to(a);
  return to(a) + (to(b) - to(a)) * (offset - from(a)) / span;
}

/// Adds the two ends to [anchors] and drops any that would make the mapping
/// go backwards, so both panes reach their top and bottom together.
List<SyncAnchor> boundSyncAnchors(
  Iterable<SyncAnchor> anchors, {
  required double sourceMax,
  required double previewMax,
}) {
  final result = <SyncAnchor>[(source: 0, preview: 0)];
  for (final anchor in anchors) {
    if (anchor.source <= result.last.source ||
        anchor.preview <= result.last.preview) {
      continue;
    }
    if (anchor.source >= sourceMax || anchor.preview >= previewMax) break;
    result.add(anchor);
  }
  if (sourceMax > result.last.source && previewMax > result.last.preview) {
    result.add((source: sourceMax, preview: previewMax));
  } else if (result.length == 1) {
    // One side does not scroll: the other moves freely.
    result.add((source: sourceMax, preview: previewMax));
  }
  return result;
}

/// Follows two [ScrollController]s and moves each when the other is scrolled.
class ScrollSync {
  /// Creates a link between [source] and [preview]. [anchors] is asked for the
  /// current anchors whenever a scroll has to be mapped.
  ScrollSync({
    required this.source,
    required this.preview,
    required this.anchors,
  }) {
    source.addListener(_sourceScrolled);
    preview.addListener(_previewScrolled);
  }

  /// Scroll position of the editor.
  final ScrollController source;

  /// Scroll position of the preview.
  final ScrollController preview;

  /// Returns the anchors for the current layout.
  final List<SyncAnchor> Function() anchors;

  /// Whether scrolling one pane moves the other.
  bool enabled = true;

  bool _moving = false;

  /// Stops listening.
  void dispose() {
    source.removeListener(_sourceScrolled);
    preview.removeListener(_previewScrolled);
  }

  /// Runs [move] without the other pane following it.
  void withoutFollowing(VoidCallback move) {
    final wasMoving = _moving;
    _moving = true;
    try {
      move();
    } finally {
      _moving = wasMoving;
    }
  }

  /// Scrolls the preview to where the editor is.
  void previewFollowsSource() => _follow(fromSource: true);

  /// Scrolls the editor to where the preview is.
  void sourceFollowsPreview() => _follow(fromSource: false);

  void _sourceScrolled() {
    if (enabled && !_moving) _follow(fromSource: true);
  }

  void _previewScrolled() {
    if (enabled && !_moving) _follow(fromSource: false);
  }

  void _follow({required bool fromSource}) {
    final leader = fromSource ? source : preview;
    final follower = fromSource ? preview : source;
    if (!leader.hasClients || !follower.hasClients) return;
    final position = follower.position;
    if (!position.hasContentDimensions) return;
    final target = mapScrollOffset(
      leader.offset,
      anchors(),
      fromSource: fromSource,
    ).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) return;
    withoutFollowing(() => follower.jumpTo(target));
  }
}

/// The blocks of the preview that are on screen, by index, and which of them
/// the caret is in.
class PreviewBlocks extends ChangeNotifier {
  final Map<int, RenderBox> _boxes = {};

  /// First and last block the caret is in, or null when there is none.
  ({int first, int last})? get active => _active;
  ({int first, int last})? _active;
  set active(({int first, int last})? value) {
    if (value == _active) return;
    _active = value;
    notifyListeners();
  }

  /// Called with the index of a block the user tapped.
  ValueChanged<int>? onTap;

  /// The box of block [index], or null when it is not laid out.
  RenderBox? boxOf(int index) {
    final box = _boxes[index];
    return box != null && box.attached && box.hasSize ? box : null;
  }
}

/// Wraps one block of the preview so that it can be found by index, shows a
/// bar beside it while the caret is in its source, and reports taps.
///
/// This is what `MarkdownView.blockWrapper` returns in the editor.
class PreviewBlock extends SingleChildRenderObjectWidget {
  /// Wraps [child], the widget of block [index].
  const PreviewBlock({
    super.key,
    required this.index,
    required this.blocks,
    required this.color,
    required super.child,
  });

  /// Index of the block in the document.
  final int index;

  /// Where the block registers itself.
  final PreviewBlocks blocks;

  /// Colour of the bar shown while the block is active.
  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPreviewBlock(index, blocks, color);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderPreviewBlock)
      ..index = index
      ..blocks = blocks
      ..color = color;
  }
}

class _RenderPreviewBlock extends RenderProxyBoxWithHitTestBehavior {
  _RenderPreviewBlock(this._index, this._blocks, this._color)
    : super(behavior: HitTestBehavior.translucent);

  int _index;
  set index(int value) {
    if (value == _index) return;
    _unregister();
    _index = value;
    _register();
    _updateActive();
  }

  PreviewBlocks _blocks;
  set blocks(PreviewBlocks value) {
    if (identical(value, _blocks)) return;
    if (attached) _blocks.removeListener(_updateActive);
    _unregister();
    _blocks = value;
    if (attached) {
      _blocks.addListener(_updateActive);
      _register();
      _updateActive();
    }
  }

  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    if (_active) markNeedsPaint();
  }

  bool _active = false;

  void _register() {
    if (attached) _blocks._boxes[_index] = this;
  }

  void _unregister() {
    if (identical(_blocks._boxes[_index], this)) _blocks._boxes.remove(_index);
  }

  void _updateActive() {
    final range = _blocks.active;
    final active =
        range != null && _index >= range.first && _index <= range.last;
    if (active == _active) return;
    _active = active;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
    _blocks.addListener(_updateActive);
    _updateActive();
  }

  @override
  void detach() {
    _blocks.removeListener(_updateActive);
    _unregister();
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_active) {
      // In the margin, so the text does not move when the bar appears.
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(offset.dx - 12, offset.dy, 3, size.height),
          const Radius.circular(1.5),
        ),
        Paint()..color = _color,
      );
    }
    super.paint(context, offset);
  }

  // A tap is watched from the side rather than won in the gesture arena, so
  // selecting text and following links in the block keep working.
  Offset? _downAt;
  Duration? _downTime;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _downAt = event.position;
      _downTime = event.timeStamp;
    } else if (event is PointerCancelEvent) {
      _downAt = null;
    } else if (event is PointerUpEvent) {
      final downAt = _downAt;
      final downTime = _downTime;
      _downAt = null;
      if (downAt != null &&
          downTime != null &&
          (event.position - downAt).distance < kTouchSlop &&
          event.timeStamp - downTime < kLongPressTimeout) {
        _blocks.onTap?.call(_index);
      }
    }
  }
}
