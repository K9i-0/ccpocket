import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../ast/rendered_text.dart';
import 'selection_autoscroll.dart';
import 'selection_controller.dart';
import 'selection_handles.dart';
import 'selection_model.dart';

/// Builder for a custom selection context menu / action toolbar.
typedef MarkdownContextMenuBuilder =
    Widget Function(BuildContext context, MarkdownSelectionScopeState state);

/// Predicate determining whether a pointer gesture at [globalPosition] may
/// begin a new text selection.
typedef MarkdownCanStartSelectionAt = bool Function(Offset globalPosition);

const Set<PointerDeviceKind> _kTouchPointerDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

const Set<PointerDeviceKind> _kDesktopPointerDevices = <PointerDeviceKind>{
  PointerDeviceKind.mouse,
  PointerDeviceKind.trackpad,
  PointerDeviceKind.unknown,
};

enum _MouseDragMode { none, character, word, block }

enum _ActiveAutoscrollDrag { none, longPress, handle, mouse }

/// Provides model-anchored Markdown selection, opaque low-slop touch handles,
/// touch magnifier, edge autoscroll, desktop mouse/keyboard gestures, and
/// customizable context menus for its descendant subtree.
class MarkdownSelectionScope extends StatefulWidget {
  const MarkdownSelectionScope({
    super.key,
    required this.child,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.selectionColor,
    this.contextMenuBuilder,
    this.handleBuilder,
    this.magnifierBuilder,
    this.autoscroll = const MarkdownSelectionAutoscrollConfig(),
    this.canStartSelectionAt,
    this.onSelectionChanged,
  });

  /// Descendant subtree containing selectable Markdown content.
  final Widget child;

  /// Optional external selection controller. When omitted, the scope creates
  /// and manages an internal controller.
  final MarkdownSelectionController? controller;

  /// Optional external focus node for desktop keyboard selection shortcuts.
  final FocusNode? focusNode;

  /// Whether selection gestures and shortcuts are active.
  final bool enabled;

  /// Optional selection highlight / handle accent color override.
  final Color? selectionColor;

  /// Optional builder for the selection context menu toolbar.
  final MarkdownContextMenuBuilder? contextMenuBuilder;

  /// Optional custom handle painter/widget builder.
  final MarkdownSelectionHandleBuilder? handleBuilder;

  /// Optional custom touch magnifier loupe builder.
  final MarkdownMagnifierBuilder? magnifierBuilder;

  /// Edge autoscroll configuration during touch/mouse drags.
  final MarkdownSelectionAutoscrollConfig autoscroll;

  /// Optional predicate to block starting selection at specific points (e.g.
  /// interactive buttons inside a bubble).
  final MarkdownCanStartSelectionAt? canStartSelectionAt;

  /// Callback invoked whenever the active [MarkdownSelection] changes.
  final ValueChanged<MarkdownSelection?>? onSelectionChanged;

  /// Returns the nearest ancestor [MarkdownSelectionController], or `null`.
  static MarkdownSelectionController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_MarkdownSelectionScopeInherited>()
        ?.controller;
  }

  /// Returns the nearest ancestor [MarkdownSelectionController], throwing if
  /// no [MarkdownSelectionScope] is present.
  static MarkdownSelectionController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No MarkdownSelectionScope found in context.');
    return controller!;
  }

  /// Returns the nearest ancestor [MarkdownSelectionScopeState], or `null`.
  static MarkdownSelectionScopeState? maybeStateOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_MarkdownSelectionScopeInherited>()
        ?.scopeState;
  }

  /// Returns the nearest ancestor [MarkdownSelectionScopeState], throwing if
  /// no [MarkdownSelectionScope] is present.
  static MarkdownSelectionScopeState stateOf(BuildContext context) {
    final state = maybeStateOf(context);
    assert(state != null, 'No MarkdownSelectionScope found in context.');
    return state!;
  }

  @override
  State<MarkdownSelectionScope> createState() => MarkdownSelectionScopeState();
}

/// Public state of [MarkdownSelectionScope], exposed to custom context menus
/// and programmatic callers via [MarkdownSelectionScope.stateOf].
class MarkdownSelectionScopeState extends State<MarkdownSelectionScope>
    with SingleTickerProviderStateMixin {
  MarkdownSelectionController? _ownedController;
  FocusNode? _ownedFocusNode;

  late MarkdownSelectionHandleOverlay _handleOverlay;
  final MarkdownAutoscrollSession _autoscrollSession =
      MarkdownAutoscrollSession();

  Ticker? _autoscrollTicker;
  Duration? _lastAutoscrollTick;
  MarkdownAutoscrollTarget? _autoscrollTarget;
  Offset? _autoscrollPointer;
  _ActiveAutoscrollDrag _activeAutoscrollDrag = _ActiveAutoscrollDrag.none;

  MarkdownSelection? _lastNotifiedSelection;
  MarkdownSelection? _longPressAnchor;
  MarkdownSelection? _mouseAnchor;
  _MouseDragMode _mouseDragMode = _MouseDragMode.none;

  // Handle drag tracking.
  MarkdownPosition? _handleFixedAnchor;
  Offset _handleDragAnchorOffset = Offset.zero;
  bool _isDraggingHandle = false;

  // Whether touch handles should be shown for the current selection.
  bool _showTouchHandles = false;

  // Explicit global anchor for desktop right-click context menu.
  Offset? _toolbarAnchorOverride;

  // Temporarily hides toolbar while user actively scrolls the parent list.
  bool _isUserScrolling = false;
  bool _overlaySyncScheduled = false;
  bool _hadSelection = false;
  bool _isRouteActive = true;
  ScrollPosition? _ancestorScrollPosition;

  /// Active [MarkdownSelectionController] bound to this scope.
  MarkdownSelectionController get controller =>
      widget.controller ?? _ownedController!;

  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode!;

  /// Focus node backing keyboard shortcuts (Cmd/Ctrl+C, Cmd/Ctrl+A, Esc,
  /// Shift+Arrow) for this selection scope.
  FocusNode get focusNode => _focusNode;

  /// Active selection formatted as plain text.
  String get selectedPlainText => controller.getText();

  /// Active selection formatted as reconstructed Markdown.
  String get selectedMarkdown => controller.getMarkdown();

  /// Whether the selection context menu toolbar is currently visible.
  bool get toolbarIsVisible => _handleOverlay.toolbarVisible;

  /// Anchors describing where a context menu toolbar should be positioned.
  TextSelectionToolbarAnchors get contextMenuAnchors {
    if (_toolbarAnchorOverride != null) {
      return TextSelectionToolbarAnchors(
        primaryAnchor: _toolbarAnchorOverride!,
      );
    }

    final rects = controller.globalSelectionRects();
    if (rects.isNotEmpty) {
      final first = rects.first;
      final last = rects.last;
      return TextSelectionToolbarAnchors(
        primaryAnchor: Offset(first.center.dx, first.top),
        secondaryAnchor: Offset(last.center.dx, last.bottom),
      );
    }

    final endpoints = controller.selectionHandleEndpoints();
    if (endpoints != null) {
      final start = endpoints.startGlobal;
      final end = endpoints.endGlobal;
      final startHeight = endpoints.startLineHeight ?? 20.0;
      if (start != null && end != null) {
        return TextSelectionToolbarAnchors(
          primaryAnchor: Offset(
            (start.dx + end.dx) / 2,
            start.dy - startHeight,
          ),
          secondaryAnchor: Offset((start.dx + end.dx) / 2, end.dy),
        );
      }
      final only = start ?? end!;
      return TextSelectionToolbarAnchors(
        primaryAnchor: Offset(only.dx, only.dy - startHeight),
        secondaryAnchor: only,
      );
    }

    return const TextSelectionToolbarAnchors(primaryAnchor: Offset.zero);
  }

  /// Copies the current plain-text selection to the system clipboard and hides
  /// the toolbar while keeping the selection active.
  Future<void> copySelection() async {
    final text = selectedPlainText;
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
    if (!mounted) return;
    hideToolbar();
  }

  /// Copies the current selection as reconstructed Markdown to the system
  /// clipboard and hides the toolbar.
  Future<void> copySelectionAsMarkdown() async {
    final markdown = selectedMarkdown;
    if (markdown.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: markdown));
    }
    if (!mounted) return;
    hideToolbar();
  }

  /// Selects all text in the active document (or across documents when allowed).
  void selectAll() {
    if (!widget.enabled || !_isRouteActive) return;
    if (controller.selectAll()) {
      _focusNode.requestFocus();
      if (_isTouchPlatform) {
        _showTouchHandles = true;
      }
      _scheduleOverlaySync();
    }
  }

  /// Clears the active selection and hides handles, magnifier, and toolbar.
  void clearSelection() {
    _stopAutoscroll();
    _handleOverlay.hideMagnifier();
    _longPressAnchor = null;
    _mouseAnchor = null;
    _mouseDragMode = _MouseDragMode.none;
    _handleFixedAnchor = null;
    _isDraggingHandle = false;
    _showTouchHandles = false;
    _toolbarAnchorOverride = null;
    controller.clear();
    _handleOverlay.hideAll();
  }

  /// Shows the context menu toolbar at [anchor] (or computed selection anchors).
  void showToolbar([Offset? anchor]) {
    if (!widget.enabled || !_isRouteActive || !controller.hasSelection) return;
    _toolbarAnchorOverride = anchor;
    controller.toolbarWanted = true;
    _scheduleOverlaySync();
  }

  /// Hides the context menu toolbar without clearing the selection.
  void hideToolbar() {
    _toolbarAnchorOverride = null;
    controller.toolbarWanted = false;
    _handleOverlay.updateToolbar(visible: false, builder: null);
  }

  bool get _isTouchPlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  Color get _resolvedHandleColor =>
      widget.selectionColor ??
      controller.selectionColor ??
      kDefaultMarkdownHandleColor;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = MarkdownSelectionController(
        selectionColor: widget.selectionColor,
      );
    }
    if (widget.focusNode == null) {
      _ownedFocusNode = FocusNode(debugLabel: 'MarkdownSelectionScope');
    }
    _createHandleOverlay();
    _lastNotifiedSelection = controller.selection;
    _hadSelection = controller.hasSelection;
    controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant MarkdownSelectionScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.removeListener(
        _onControllerChanged,
      );
      if (widget.controller == null) {
        _ownedController ??= MarkdownSelectionController(
          selectionColor: widget.selectionColor,
        );
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
      controller.addListener(_onControllerChanged);
      _lastNotifiedSelection = controller.selection;
      _hadSelection = controller.hasSelection;
    }

    if (oldWidget.focusNode != widget.focusNode) {
      if (widget.focusNode == null) {
        _ownedFocusNode ??= FocusNode(debugLabel: 'MarkdownSelectionScope');
      } else {
        _ownedFocusNode?.dispose();
        _ownedFocusNode = null;
      }
    }

    if (oldWidget.handleBuilder != widget.handleBuilder ||
        oldWidget.magnifierBuilder != widget.magnifierBuilder) {
      _handleOverlay.dispose();
      _createHandleOverlay();
    }

    if (!widget.enabled && oldWidget.enabled) {
      clearSelection();
    } else {
      _scheduleOverlaySync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAncestorScrollPosition();
    _syncRouteActiveState();
  }

  void _syncRouteActiveState() {
    final isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final nextActive = isCurrent && tickerEnabled;
    if (nextActive == _isRouteActive) return;
    _isRouteActive = nextActive;
    if (!_isRouteActive) {
      _hideOverlaysForInactiveRoute();
    } else {
      _scheduleOverlaySync();
    }
  }

  void _hideOverlaysForInactiveRoute() {
    _stopAutoscroll();
    _isDraggingHandle = false;
    _handleFixedAnchor = null;
    _handleDragAnchorOffset = Offset.zero;
    _longPressAnchor = null;
    _mouseAnchor = null;
    _mouseDragMode = _MouseDragMode.none;
    _isUserScrolling = false;
    _scheduleOverlaySync();
  }

  @override
  void dispose() {
    _detachAncestorScrollPosition();
    controller.removeListener(_onControllerChanged);
    _stopAutoscroll();
    _autoscrollTicker?.dispose();
    _handleOverlay.dispose();
    _ownedController?.dispose();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _syncAncestorScrollPosition() {
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (nextPosition == _ancestorScrollPosition) return;
    _detachAncestorScrollPosition();
    _ancestorScrollPosition = nextPosition;
    if (nextPosition != null) {
      nextPosition.addListener(_onAncestorScrollPositionChanged);
      nextPosition.isScrollingNotifier.addListener(
        _onAncestorScrollingStateChanged,
      );
    }
  }

  void _detachAncestorScrollPosition() {
    final pos = _ancestorScrollPosition;
    if (pos == null) return;
    pos.removeListener(_onAncestorScrollPositionChanged);
    pos.isScrollingNotifier.removeListener(_onAncestorScrollingStateChanged);
    _ancestorScrollPosition = null;
  }

  void _onAncestorScrollingStateChanged() {
    if (!mounted || !_isRouteActive || !controller.hasSelection) return;
    if (_activeAutoscrollDrag != _ActiveAutoscrollDrag.none) return;

    final isScrolling =
        _ancestorScrollPosition?.isScrollingNotifier.value ?? false;
    if (isScrolling) {
      if (!_isUserScrolling) {
        _isUserScrolling = true;
        _handleOverlay.updateToolbar(visible: false, builder: null);
      }
    } else {
      if (_isUserScrolling) {
        _isUserScrolling = false;
      }
      _scheduleOverlaySync(deferToPostFrame: true);
    }
  }

  void _onAncestorScrollPositionChanged() {
    if (!mounted || !_isRouteActive || !controller.hasSelection) return;
    if (_activeAutoscrollDrag != _ActiveAutoscrollDrag.none) return;
    _scheduleOverlaySync(deferToPostFrame: true);
  }

  void _createHandleOverlay() {
    _handleOverlay = MarkdownSelectionHandleOverlay(
      context: context,
      handleBuilder: widget.handleBuilder,
      magnifierBuilder: widget.magnifierBuilder,
      isSurfaceMounted: (surface) =>
          mounted && controller.mountedSurfaces.contains(surface),
      onHandleDragStart: _onHandleDragStart,
      onHandleDragUpdate: _onHandleDragUpdate,
      onHandleDragEnd: _onHandleDragEnd,
      onHandleDragCancel: _onHandleDragCancel,
    );
  }

  void _onControllerChanged() {
    final current = controller.selection;
    if (current != _lastNotifiedSelection) {
      _lastNotifiedSelection = current;
      widget.onSelectionChanged?.call(current);
    }
    final hasSel = controller.hasSelection;
    if (!hasSel) {
      _showTouchHandles = false;
      _toolbarAnchorOverride = null;
    }
    if (hasSel != _hadSelection) {
      _hadSelection = hasSel;
      if (mounted) {
        if (SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        } else {
          setState(() {});
        }
      }
    }
    _scheduleOverlaySync();
  }

  void _scheduleOverlaySync({bool deferToPostFrame = false}) {
    if (!mounted) return;
    final inPersistentCallbacks =
        SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;
    if (deferToPostFrame || inPersistentCallbacks) {
      if (_overlaySyncScheduled) return;
      _overlaySyncScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _overlaySyncScheduled = false;
        if (mounted) {
          _syncOverlay();
        }
      });
      if (!inPersistentCallbacks) {
        SchedulerBinding.instance.ensureVisualUpdate();
      }
    } else {
      _syncOverlay();
    }
  }

  void _syncOverlay() {
    if (!mounted) return;

    if (!widget.enabled || !controller.hasSelection || !_isRouteActive) {
      if (_isDraggingHandle) {
        // Hiding the handles disposes the recognizer that owns the drag, so
        // its end/cancel callback never arrives. Finish the drag here or the
        // autoscroll ticker keeps running and later toolbars stay hidden.
        _isDraggingHandle = false;
        _handleFixedAnchor = null;
        _handleDragAnchorOffset = Offset.zero;
        _stopAutoscroll();
        _handleOverlay.hideMagnifier();
      }
      _handleOverlay.hideAll();
      return;
    }

    final endpoints = controller.selectionHandleEndpoints();
    final clipRect = _visibleHandleClipRect();
    final normalized = controller.normalizedSelection;
    final draggingStartEdge =
        _isDraggingHandle &&
        _handleFixedAnchor != null &&
        normalized != null &&
        normalized.end == _handleFixedAnchor;
    final draggingEndEdge =
        _isDraggingHandle &&
        _handleFixedAnchor != null &&
        normalized != null &&
        normalized.start == _handleFixedAnchor;

    final showStartHandle =
        endpoints != null &&
        endpoints.hasStart &&
        (draggingStartEdge ||
            clipRect == null ||
            _isHandleEndpointVisible(endpoints.startGlobal!, clipRect));
    final showEndHandle =
        endpoints != null &&
        endpoints.hasEnd &&
        (draggingEndEdge ||
            clipRect == null ||
            _isHandleEndpointVisible(endpoints.endGlobal!, clipRect));

    _handleOverlay.updateHandles(
      endpoints: endpoints,
      visible: _showTouchHandles && (showStartHandle || showEndHandle),
      showStartHandle: showStartHandle,
      showEndHandle: showEndHandle,
      handleColor: _resolvedHandleColor,
    );

    final shouldShowToolbar =
        controller.toolbarWanted &&
        widget.contextMenuBuilder != null &&
        !_isDraggingHandle &&
        _longPressAnchor == null &&
        !_isUserScrolling &&
        _isSelectionVisibleInViewport(endpoints, clipRect: clipRect);

    _handleOverlay.updateToolbar(
      visible: shouldShowToolbar,
      builder: shouldShowToolbar
          ? (ctx) => widget.contextMenuBuilder!(ctx, this)
          : null,
    );
  }

  Rect? _visibleHandleClipRect() {
    final viewport = _currentViewportRect();
    if (viewport == null) return null;
    if (viewport.isEmpty) return Rect.zero;
    final top = viewport.top + widget.autoscroll.topPad;
    final bottom = viewport.bottom - widget.autoscroll.bottomPad;
    if (bottom <= top) {
      final mid = (viewport.top + viewport.bottom) / 2.0;
      return Rect.fromLTRB(viewport.left, mid, viewport.right, mid);
    }
    return Rect.fromLTRB(viewport.left, top, viewport.right, bottom);
  }

  bool _isHandleEndpointVisible(Offset endpoint, Rect clipRect) {
    if (clipRect.isEmpty) return false;
    const horizontalSlop = 2.0;
    return endpoint.dx >= clipRect.left - horizontalSlop &&
        endpoint.dx <= clipRect.right + horizontalSlop &&
        endpoint.dy >= clipRect.top &&
        endpoint.dy <= clipRect.bottom;
  }

  bool _isSelectionVisibleInViewport(
    MarkdownHandleEndpoints? endpoints, {
    Rect? clipRect,
  }) {
    if (_toolbarAnchorOverride != null) return true;
    final rects = controller.globalSelectionRects();
    if (rects.isEmpty && (endpoints == null || !endpoints.hasAny)) {
      return false;
    }

    final viewportRect = clipRect ?? _visibleHandleClipRect();
    if (viewportRect == null) return true;
    if (viewportRect.isEmpty) return false;

    if (rects.isNotEmpty) {
      for (final r in rects) {
        if (r.overlaps(viewportRect)) return true;
      }
      return false;
    }

    final start = endpoints?.startGlobal;
    final end = endpoints?.endGlobal;
    if (start != null && _isHandleEndpointVisible(start, viewportRect)) {
      return true;
    }
    if (end != null && _isHandleEndpointVisible(end, viewportRect)) {
      return true;
    }
    return false;
  }

  Rect? _currentViewportRect() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    var rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;

    // When this scope is nested inside an ancestor Scrollable (e.g. a
    // SingleChildScrollView inside a dialog or sheet), clamp the visibility
    // rect to the ancestor Scrollable's viewport.
    final ancestorScrollable = Scrollable.maybeOf(context);
    final ancestorBox = ancestorScrollable?.context.findRenderObject();
    if (ancestorBox is RenderBox &&
        ancestorBox.attached &&
        ancestorBox.hasSize) {
      final ancestorRect =
          ancestorBox.localToGlobal(Offset.zero) & ancestorBox.size;
      rect = rect.intersect(ancestorRect);
    }
    return rect;
  }

  // ---------------------------------------------------------------------------
  // Touch gesture handlers (Long-press ONLY to start; tap to clear/toggle)
  // ---------------------------------------------------------------------------

  void _onLongPressStart(LongPressStartDetails details) {
    if (!widget.enabled || !_isRouteActive) return;
    final global = details.globalPosition;
    if (widget.canStartSelectionAt != null &&
        !widget.canStartSelectionAt!(global)) {
      return;
    }
    if (!controller.hitsSelectableContent(global)) {
      return;
    }

    _focusNode.requestFocus();
    if (!controller.selectWordAtGlobal(global)) {
      return;
    }

    _longPressAnchor = controller.selection;
    _showTouchHandles = true;
    _toolbarAnchorOverride = null;
    controller.toolbarWanted = false;
    unawaited(HapticFeedback.selectionClick());

    final lineHeight =
        controller.selectionEndpointGlobalRect(base: false)?.height ?? 20.0;
    _handleOverlay.showMagnifier(
      globalFocalPoint: global,
      lineHeight: lineHeight,
    );
    _startAutoscroll(
      dragKind: _ActiveAutoscrollDrag.longPress,
      globalPointer: global,
    );
    _syncOverlay();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final anchor = _longPressAnchor;
    if (!_isRouteActive || anchor == null) return;

    final global = details.globalPosition;
    _autoscrollPointer = global;
    controller.extendGranular(anchor, global, word: true);

    final lineHeight =
        controller.selectionEndpointGlobalRect(base: false)?.height ?? 20.0;
    _handleOverlay.showMagnifier(
      globalFocalPoint: global,
      lineHeight: lineHeight,
    );
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_longPressAnchor == null) return;
    _longPressAnchor = null;
    _stopAutoscroll();
    _handleOverlay.hideMagnifier();

    if (controller.hasSelection) {
      _showTouchHandles = true;
      showToolbar();
    }
  }

  void _onLongPressCancel() {
    // NEVER clear selection on cancel — only stop transient drag helpers.
    _longPressAnchor = null;
    _stopAutoscroll();
    _handleOverlay.hideMagnifier();
  }

  void _onTouchTapUp(TapUpDetails details) {
    if (!widget.enabled || !_isRouteActive || !controller.hasSelection) return;
    final global = details.globalPosition;

    if (_isPointInsideSelection(global)) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        if (toolbarIsVisible) {
          hideToolbar();
        } else {
          showToolbar();
        }
      }
      return;
    }

    clearSelection();
  }

  bool _isPointInsideSelection(Offset global) {
    for (final rect in controller.globalSelectionRects()) {
      if (rect.inflate(4.0).contains(global)) {
        return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Selection handle drag handlers
  // ---------------------------------------------------------------------------

  void _onHandleDragStart(
    MarkdownSelectionHandleType type,
    Offset globalPosition,
  ) {
    if (!widget.enabled || !_isRouteActive || !controller.hasSelection) return;
    final normalized = controller.normalizedSelection;
    if (normalized == null) return;

    final isStart = type == MarkdownSelectionHandleType.start;
    _handleFixedAnchor = isStart ? normalized.end : normalized.start;
    _isDraggingHandle = true;
    _toolbarAnchorOverride = null;

    // Compensate for the vertical offset between the handle's touch center
    // (above/below the line) and the caret center so dragging starts smoothly
    // on the current line without jumping vertically.
    final endpoints = controller.selectionHandleEndpoints();
    final endpointGlobal = isStart
        ? endpoints?.startGlobal
        : endpoints?.endGlobal;
    final lineHeight =
        (isStart ? endpoints?.startLineHeight : endpoints?.endLineHeight) ??
        20.0;
    if (endpointGlobal != null) {
      final caretCenter = Offset(
        endpointGlobal.dx,
        endpointGlobal.dy - lineHeight / 2,
      );
      _handleDragAnchorOffset = caretCenter - globalPosition;
    } else {
      _handleDragAnchorOffset = Offset.zero;
    }

    _handleOverlay.updateToolbar(visible: false, builder: null);
    _handleOverlay.showMagnifier(
      globalFocalPoint: globalPosition + _handleDragAnchorOffset,
      lineHeight: lineHeight,
    );
    _startAutoscroll(
      dragKind: _ActiveAutoscrollDrag.handle,
      globalPointer: globalPosition,
    );
  }

  void _onHandleDragUpdate(
    MarkdownSelectionHandleType type,
    Offset globalPosition,
  ) {
    if (!_isRouteActive || !_isDraggingHandle || _handleFixedAnchor == null) {
      return;
    }
    _autoscrollPointer = globalPosition;
    _applyHandleDragPosition(globalPosition);
  }

  void _applyHandleDragPosition(Offset globalPosition) {
    final fixed = _handleFixedAnchor;
    if (fixed == null || !controller.hasSelection) return;

    final normalized = controller.normalizedSelection;
    if (normalized == null) return;

    // Preserve the fixed anchor even if the user drags one handle past the other.
    final isDraggingStart = normalized.end == fixed;
    final textProbe = globalPosition + _handleDragAnchorOffset;
    controller.moveSelectionEdgeToGlobal(textProbe, isStart: isDraggingStart);

    final lineHeight =
        controller.selectionEndpointGlobalRect(base: false)?.height ?? 20.0;
    _handleOverlay.showMagnifier(
      globalFocalPoint: textProbe,
      lineHeight: lineHeight,
    );
  }

  void _onHandleDragEnd(MarkdownSelectionHandleType type) {
    _isDraggingHandle = false;
    _handleFixedAnchor = null;
    _handleDragAnchorOffset = Offset.zero;
    _stopAutoscroll();
    _handleOverlay.hideMagnifier();

    if (controller.hasSelection) {
      showToolbar();
    } else {
      _scheduleOverlaySync();
    }
  }

  void _onHandleDragCancel(MarkdownSelectionHandleType type) {
    // NEVER clear selection on cancel — restore handles/toolbar cleanly.
    _isDraggingHandle = false;
    _handleFixedAnchor = null;
    _handleDragAnchorOffset = Offset.zero;
    _stopAutoscroll();
    _handleOverlay.hideMagnifier();
    _scheduleOverlaySync();
  }

  // ---------------------------------------------------------------------------
  // Desktop mouse gesture handlers
  // ---------------------------------------------------------------------------

  void _onDesktopTapDown(TapDragDownDetails details) {
    if (!widget.enabled || !_isRouteActive) return;
    final global = details.globalPosition;
    final tapCount = details.consecutiveTapCount;

    // Shift+Click always extends the existing selection regardless of
    // consecutiveTapCount (rapid click -> Shift+click within kDoubleTapSlop
    // must extend rather than trigger double-click word selection).
    if (HardwareKeyboard.instance.isShiftPressed &&
        controller.selection != null) {
      _focusNode.requestFocus();
      _showTouchHandles = false;
      hideToolbar();
      controller.extendToGlobal(global);
      _mouseDragMode = _MouseDragMode.character;
      return;
    }

    if (tapCount == 1) {
      if ((widget.canStartSelectionAt != null &&
              !widget.canStartSelectionAt!(global)) ||
          !controller.hitsSelectableContent(global)) {
        _mouseDragMode = _MouseDragMode.none;
        clearSelection();
        return;
      }

      _focusNode.requestFocus();
      _showTouchHandles = false;
      hideToolbar();
      if (controller.startAtGlobal(global)) {
        _mouseDragMode = _MouseDragMode.character;
      } else {
        _mouseDragMode = _MouseDragMode.none;
      }
    } else if (tapCount == 2) {
      if ((widget.canStartSelectionAt != null &&
              !widget.canStartSelectionAt!(global)) ||
          !controller.hitsSelectableContent(global)) {
        return;
      }
      _focusNode.requestFocus();
      _showTouchHandles = false;
      hideToolbar();
      if (controller.selectWordAtGlobal(global)) {
        _mouseAnchor = controller.selection;
        _mouseDragMode = _MouseDragMode.word;
      }
    } else {
      if ((widget.canStartSelectionAt != null &&
              !widget.canStartSelectionAt!(global)) ||
          !controller.hitsSelectableContent(global)) {
        return;
      }
      _focusNode.requestFocus();
      _showTouchHandles = false;
      hideToolbar();
      if (controller.selectBlockAtGlobal(global)) {
        _mouseAnchor = controller.selection;
        _mouseDragMode = _MouseDragMode.block;
      }
    }
  }

  void _onDesktopDragStart(TapDragStartDetails details) {
    if (!widget.enabled || _mouseDragMode == _MouseDragMode.none) return;
    _startAutoscroll(
      dragKind: _ActiveAutoscrollDrag.mouse,
      globalPointer: details.globalPosition,
    );
  }

  void _onDesktopDragUpdate(TapDragUpdateDetails details) {
    if (!widget.enabled || _mouseDragMode == _MouseDragMode.none) return;
    final global = details.globalPosition;
    _autoscrollPointer = global;
    _applyMouseDragPosition(global);
  }

  void _applyMouseDragPosition(Offset global) {
    switch (_mouseDragMode) {
      case _MouseDragMode.none:
        return;
      case _MouseDragMode.character:
        controller.extendToGlobal(global);
      case _MouseDragMode.word:
        if (_mouseAnchor != null) {
          controller.extendGranular(_mouseAnchor!, global, word: true);
        }
      case _MouseDragMode.block:
        if (_mouseAnchor != null) {
          controller.extendGranular(_mouseAnchor!, global, word: false);
        }
    }
  }

  void _onDesktopDragEnd(TapDragEndDetails details) {
    _stopAutoscroll();
    _mouseAnchor = null;
    _mouseDragMode = _MouseDragMode.none;
  }

  void _onDesktopCancel() {
    // NEVER clear selection on cancel.
    _stopAutoscroll();
    _mouseAnchor = null;
    _mouseDragMode = _MouseDragMode.none;
  }

  void _onDesktopSecondaryTapUp(TapUpDetails details) {
    if (!widget.enabled || !_isRouteActive) return;
    final global = details.globalPosition;
    if (controller.hasSelection) {
      if (defaultTargetPlatform == TargetPlatform.macOS &&
          !_isPointInsideSelection(global) &&
          (widget.canStartSelectionAt == null ||
              widget.canStartSelectionAt!(global)) &&
          controller.hitsSelectableContent(global)) {
        _focusNode.requestFocus();
        controller.selectWordAtGlobal(global);
        showToolbar(global);
        return;
      }
      _focusNode.requestFocus();
      showToolbar(global);
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS &&
        (widget.canStartSelectionAt == null ||
            widget.canStartSelectionAt!(global)) &&
        controller.hitsSelectableContent(global)) {
      _focusNode.requestFocus();
      if (controller.selectWordAtGlobal(global)) {
        showToolbar(global);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Edge autoscroll driver
  // ---------------------------------------------------------------------------

  void _startAutoscroll({
    required _ActiveAutoscrollDrag dragKind,
    required Offset globalPointer,
  }) {
    if (!widget.autoscroll.enabled) return;
    _activeAutoscrollDrag = dragKind;
    _autoscrollPointer = globalPointer;
    _autoscrollSession.reset();
    _autoscrollTarget = MarkdownScrollableAutoscrollTarget.resolve(
      context,
      globalPointer: globalPointer,
      config: widget.autoscroll,
    );
    _lastAutoscrollTick = null;

    _autoscrollTicker ??= createTicker(_onAutoscrollTick);
    if (!_autoscrollTicker!.isActive) {
      _autoscrollTicker!.start();
    }
  }

  void _stopAutoscroll() {
    _activeAutoscrollDrag = _ActiveAutoscrollDrag.none;
    _autoscrollPointer = null;
    _autoscrollTarget = null;
    _lastAutoscrollTick = null;
    _autoscrollSession.reset();
    if (_autoscrollTicker != null && _autoscrollTicker!.isActive) {
      _autoscrollTicker!.stop();
    }
  }

  void _onAutoscrollTick(Duration elapsed) {
    if (!mounted ||
        !_isRouteActive ||
        _activeAutoscrollDrag == _ActiveAutoscrollDrag.none ||
        _autoscrollPointer == null) {
      _stopAutoscroll();
      return;
    }

    final previous = _lastAutoscrollTick;
    _lastAutoscrollTick = elapsed;
    if (previous == null) return;

    final dt = elapsed - previous;
    if (dt <= Duration.zero) return;

    final pointer = _autoscrollPointer!;
    final target =
        _autoscrollTarget ??
        MarkdownScrollableAutoscrollTarget.resolve(
          context,
          globalPointer: pointer,
          config: widget.autoscroll,
        );
    _autoscrollTarget = target;
    if (target == null) return;

    final hostBounds = _autoscrollHostBounds();
    final applied = applyMarkdownSelectionAutoscroll(
      target: target,
      session: _autoscrollSession,
      globalPointer: pointer,
      dt: dt,
      config: widget.autoscroll,
      hostBounds: hostBounds,
    );

    if (applied != 0.0) {
      // Wait for the scrolled frame's layout before re-projecting pointer
      // coordinates into updated surface bounds.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isRouteActive || _autoscrollPointer == null) return;
        final currentPointer = _autoscrollPointer!;
        switch (_activeAutoscrollDrag) {
          case _ActiveAutoscrollDrag.none:
            return;
          case _ActiveAutoscrollDrag.longPress:
            if (_longPressAnchor != null) {
              controller.extendGranular(
                _longPressAnchor!,
                currentPointer,
                word: true,
              );
            }
          case _ActiveAutoscrollDrag.handle:
            _applyHandleDragPosition(currentPointer);
          case _ActiveAutoscrollDrag.mouse:
            _applyMouseDragPosition(currentPointer);
        }
        _syncOverlay();
      });
    }
  }

  /// Computes the host union bounds passed to [applyMarkdownSelectionAutoscroll].
  @visibleForTesting
  Rect? debugAutoscrollHostBounds() => _autoscrollHostBounds();

  ({int first, int last})? _selectableBlockRange(MarkdownDocumentRef ref) {
    final blocks = ref.document.blocks;
    int? first;
    int? last;
    for (var i = 0; i < blocks.length; i++) {
      if (extractBlockRenderedText(blocks[i]).isNotEmpty) {
        first ??= i;
        last = i;
      }
    }
    if (first == null || last == null) return null;
    return (first: first, last: last);
  }

  ({int minBlock, int maxBlock})? _mountedBlockRangeForDoc(String documentId) {
    int? minBlock;
    int? maxBlock;
    for (final s in controller.mountedSurfaces) {
      if (s.documentId != documentId) continue;
      minBlock = minBlock == null
          ? s.blockIndex
          : math.min(minBlock, s.blockIndex);
      maxBlock = maxBlock == null
          ? s.blockIndex
          : math.max(maxBlock, s.blockIndex);
    }
    if (minBlock == null || maxBlock == null) return null;
    return (minBlock: minBlock, maxBlock: maxBlock);
  }

  Rect? _autoscrollHostBounds() {
    if (!widget.autoscroll.useHostUnionGate) return null;

    final union = controller.mountedHostBounds();
    if (union == null) return null;

    // If registered documents have unmounted selectable blocks outside the
    // currently mounted surfaces, keep the corresponding side(s) open so
    // virtualized lists (including reverse: true lists) can scroll toward
    // off-screen items.
    final restrictDocId =
        !controller.allowCrossDocumentSelection && controller.selection != null
        ? controller.selection!.base.documentId
        : null;

    final relevantSurfaces = <MarkdownSelectionSurface>[
      for (final s in controller.mountedSurfaces)
        if ((restrictDocId == null || s.documentId == restrictDocId) &&
            s.globalBounds != null)
          s,
    ];

    var hasEarlierUnmounted = false;
    var hasLaterUnmounted = false;

    if (restrictDocId != null) {
      final ref = controller.documentForId(restrictDocId);
      if (ref != null) {
        final selectable = _selectableBlockRange(ref);
        final mountedRange = _mountedBlockRangeForDoc(restrictDocId);
        if (selectable != null) {
          if (mountedRange == null) {
            hasEarlierUnmounted = true;
            hasLaterUnmounted = true;
          } else {
            hasEarlierUnmounted = mountedRange.minBlock > selectable.first;
            hasLaterUnmounted = mountedRange.maxBlock < selectable.last;
          }
        }
      }
    } else if (controller.hasDocuments) {
      MarkdownDocumentRef? firstSelectableDoc;
      ({int first, int last})? firstSelectableRange;
      MarkdownDocumentRef? lastSelectableDoc;
      ({int first, int last})? lastSelectableRange;

      for (final ref in controller.documents) {
        final range = _selectableBlockRange(ref);
        if (range == null) continue;
        if (firstSelectableDoc == null) {
          firstSelectableDoc = ref;
          firstSelectableRange = range;
        }
        lastSelectableDoc = ref;
        lastSelectableRange = range;
      }

      if (firstSelectableDoc != null && firstSelectableRange != null) {
        final mountedFirst = _mountedBlockRangeForDoc(firstSelectableDoc.id);
        hasEarlierUnmounted =
            mountedFirst == null ||
            mountedFirst.minBlock > firstSelectableRange.first;
      }
      if (lastSelectableDoc != null && lastSelectableRange != null) {
        final mountedLast = _mountedBlockRangeForDoc(lastSelectableDoc.id);
        hasLaterUnmounted =
            mountedLast == null ||
            mountedLast.maxBlock < lastSelectableRange.last;
      }
    }

    // Detect whether reading order grows downward (normal ListView) or upward
    // (reverse: true ListView with ascending document order).
    var readingOrderIsVisuallyReversed = false;
    if (relevantSurfaces.length >= 2) {
      final docsOrder = <String, int>{
        for (var i = 0; i < controller.documents.length; i++)
          controller.documents[i].id: i,
      };
      relevantSurfaces.sort((a, b) {
        final oa = docsOrder[a.documentId] ?? 0;
        final ob = docsOrder[b.documentId] ?? 0;
        if (oa != ob) return oa.compareTo(ob);
        final bc = a.blockIndex.compareTo(b.blockIndex);
        if (bc != 0) return bc;
        return a.textOffsetInBlock.compareTo(b.textOffsetInBlock);
      });
      final firstTop = relevantSurfaces.first.globalBounds!.top;
      final lastTop = relevantSurfaces.last.globalBounds!.top;
      if (lastTop < firstTop - 1.0) {
        readingOrderIsVisuallyReversed = true;
      }
    }

    var top = union.top;
    var bottom = union.bottom;
    if (readingOrderIsVisuallyReversed) {
      if (hasLaterUnmounted) top = double.negativeInfinity;
      if (hasEarlierUnmounted) bottom = double.infinity;
    } else {
      if (hasEarlierUnmounted) top = double.negativeInfinity;
      if (hasLaterUnmounted) bottom = double.infinity;
    }

    return Rect.fromLTRB(union.left, top, union.right, bottom);
  }

  // ---------------------------------------------------------------------------
  // Scroll notification tracking (keeps selection intact during scroll!)
  // ---------------------------------------------------------------------------

  bool _onScrollNotification(ScrollNotification notification) {
    if (!_isRouteActive || !controller.hasSelection) return false;
    if (_activeAutoscrollDrag != _ActiveAutoscrollDrag.none) return false;

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      if (!_isUserScrolling) {
        _isUserScrolling = true;
        _handleOverlay.updateToolbar(visible: false, builder: null);
      }
    } else if (notification is ScrollUpdateNotification) {
      // Continuously sync handle visibility post-layout so handles scrolled
      // outside the visible clip (e.g. behind a bottom composer) are
      // suppressed immediately; toolbar remains hidden while _isUserScrolling.
      _scheduleOverlaySync(deferToPostFrame: true);
    } else if (notification is ScrollEndNotification) {
      if (_isUserScrolling) {
        _isUserScrolling = false;
      }
      _scheduleOverlaySync(deferToPostFrame: true);
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Keyboard shortcuts & actions
  // ---------------------------------------------------------------------------

  Map<ShortcutActivator, Intent> _buildShortcuts() {
    final isApple =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return <ShortcutActivator, Intent>{
      SingleActivator(
        LogicalKeyboardKey.keyC,
        meta: isApple,
        control: !isApple,
      ): CopySelectionTextIntent.copy,
      SingleActivator(
        LogicalKeyboardKey.keyA,
        meta: isApple,
        control: !isApple,
      ): const SelectAllTextIntent(
        SelectionChangedCause.keyboard,
      ),
      const SingleActivator(LogicalKeyboardKey.escape): const DismissIntent(),
      const SingleActivator(
        LogicalKeyboardKey.arrowRight,
        shift: true,
      ): const ExtendSelectionByCharacterIntent(
        forward: true,
        collapseSelection: false,
      ),
      const SingleActivator(
        LogicalKeyboardKey.arrowLeft,
        shift: true,
      ): const ExtendSelectionByCharacterIntent(
        forward: false,
        collapseSelection: false,
      ),
      SingleActivator(
        LogicalKeyboardKey.arrowRight,
        shift: true,
        alt: isApple,
        control: !isApple,
      ): const ExtendSelectionToNextWordBoundaryIntent(
        forward: true,
        collapseSelection: false,
      ),
      SingleActivator(
        LogicalKeyboardKey.arrowLeft,
        shift: true,
        alt: isApple,
        control: !isApple,
      ): const ExtendSelectionToNextWordBoundaryIntent(
        forward: false,
        collapseSelection: false,
      ),
      const SingleActivator(
        LogicalKeyboardKey.arrowDown,
        shift: true,
      ): const ExtendSelectionVerticallyToAdjacentLineIntent(
        forward: true,
        collapseSelection: false,
      ),
      const SingleActivator(
        LogicalKeyboardKey.arrowUp,
        shift: true,
      ): const ExtendSelectionVerticallyToAdjacentLineIntent(
        forward: false,
        collapseSelection: false,
      ),
      if (isApple) ...<ShortcutActivator, Intent>{
        const SingleActivator(
          LogicalKeyboardKey.arrowRight,
          shift: true,
          meta: true,
        ): const ExtendSelectionToLineBreakIntent(
          forward: true,
          collapseSelection: false,
        ),
        const SingleActivator(
          LogicalKeyboardKey.arrowLeft,
          shift: true,
          meta: true,
        ): const ExtendSelectionToLineBreakIntent(
          forward: false,
          collapseSelection: false,
        ),
        const SingleActivator(
          LogicalKeyboardKey.arrowDown,
          shift: true,
          meta: true,
        ): const ExtendSelectionToDocumentBoundaryIntent(
          forward: true,
          collapseSelection: false,
        ),
        const SingleActivator(
          LogicalKeyboardKey.arrowUp,
          shift: true,
          meta: true,
        ): const ExtendSelectionToDocumentBoundaryIntent(
          forward: false,
          collapseSelection: false,
        ),
      } else ...<ShortcutActivator, Intent>{
        const SingleActivator(
          LogicalKeyboardKey.end,
          shift: true,
        ): const ExtendSelectionToLineBreakIntent(
          forward: true,
          collapseSelection: false,
        ),
        const SingleActivator(
          LogicalKeyboardKey.home,
          shift: true,
        ): const ExtendSelectionToLineBreakIntent(
          forward: false,
          collapseSelection: false,
        ),
        const SingleActivator(
          LogicalKeyboardKey.end,
          shift: true,
          control: true,
        ): const ExtendSelectionToDocumentBoundaryIntent(
          forward: true,
          collapseSelection: false,
        ),
        const SingleActivator(
          LogicalKeyboardKey.home,
          shift: true,
          control: true,
        ): const ExtendSelectionToDocumentBoundaryIntent(
          forward: false,
          collapseSelection: false,
        ),
      },
    };
  }

  Map<Type, Action<Intent>> _buildActions() {
    return <Type, Action<Intent>>{
      CopySelectionTextIntent: _GuardedCallbackAction<CopySelectionTextIntent>(
        isEnabledCallback: () => widget.enabled && controller.hasSelection,
        onInvokeCallback: (_) {
          unawaited(copySelection());
          return null;
        },
      ),
      SelectAllTextIntent: _GuardedCallbackAction<SelectAllTextIntent>(
        isEnabledCallback: () =>
            widget.enabled &&
            (controller.hasDocuments || controller.mountedSurfaces.isNotEmpty),
        onInvokeCallback: (_) {
          selectAll();
          return null;
        },
      ),
      if (widget.enabled && controller.hasSelection)
        DismissIntent: _GuardedCallbackAction<DismissIntent>(
          isEnabledCallback: () => widget.enabled && controller.hasSelection,
          onInvokeCallback: (_) {
            clearSelection();
            return null;
          },
        ),
      ExtendSelectionByCharacterIntent:
          _GuardedCallbackAction<ExtendSelectionByCharacterIntent>(
            isEnabledCallback: () =>
                widget.enabled && controller.selection != null,
            onInvokeCallback: (intent) {
              controller.extendByCharacter(forward: intent.forward);
              return null;
            },
          ),
      ExtendSelectionToNextWordBoundaryIntent:
          _GuardedCallbackAction<ExtendSelectionToNextWordBoundaryIntent>(
            isEnabledCallback: () =>
                widget.enabled && controller.selection != null,
            onInvokeCallback: (intent) {
              controller.extendByWord(forward: intent.forward);
              return null;
            },
          ),
      ExtendSelectionToNextWordBoundaryOrCaretLocationIntent:
          _GuardedCallbackAction<
            ExtendSelectionToNextWordBoundaryOrCaretLocationIntent
          >(
            isEnabledCallback: () =>
                widget.enabled && controller.selection != null,
            onInvokeCallback: (intent) {
              controller.extendByWord(forward: intent.forward);
              return null;
            },
          ),
      ExtendSelectionToLineBreakIntent:
          _GuardedCallbackAction<ExtendSelectionToLineBreakIntent>(
            isEnabledCallback: () =>
                widget.enabled && controller.selection != null,
            onInvokeCallback: (intent) {
              controller.extendToLineBreak(forward: intent.forward);
              return null;
            },
          ),
      ExtendSelectionVerticallyToAdjacentLineIntent:
          _GuardedCallbackAction<ExtendSelectionVerticallyToAdjacentLineIntent>(
            isEnabledCallback: () =>
                widget.enabled && controller.selection != null,
            onInvokeCallback: (intent) {
              controller.extendToAdjacentLine(forward: intent.forward);
              return null;
            },
          ),
      ExtendSelectionToDocumentBoundaryIntent:
          _GuardedCallbackAction<ExtendSelectionToDocumentBoundaryIntent>(
            isEnabledCallback: () =>
                widget.enabled && controller.selection != null,
            onInvokeCallback: (intent) {
              controller.extendToDocumentBoundary(forward: intent.forward);
              return null;
            },
          ),
    };
  }

  Map<Type, GestureRecognizerFactory> _buildGestures() {
    if (!widget.enabled) {
      return const <Type, GestureRecognizerFactory>{};
    }

    return <Type, GestureRecognizerFactory>{
      // Touch: selection starts ONLY on long-press (zero scroll competition).
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              debugOwner: this,
              supportedDevices: _kTouchPointerDevices,
            ),
            (LongPressGestureRecognizer instance) {
              instance
                ..onLongPressStart = _onLongPressStart
                ..onLongPressMoveUpdate = _onLongPressMoveUpdate
                ..onLongPressEnd = _onLongPressEnd
                ..onLongPressCancel = _onLongPressCancel;
            },
          ),
      // Touch: tap outside clears selection (or toggles toolbar on iOS).
      // Only registered while a selection is active so idle touches never
      // enter a parent TapGestureRecognizer into the gesture arena.
      if (controller.hasSelection)
        _TouchSelectionTapRecognizer:
            GestureRecognizerFactoryWithHandlers<_TouchSelectionTapRecognizer>(
              () => _TouchSelectionTapRecognizer(
                debugOwner: this,
                supportedDevices: _kTouchPointerDevices,
              ),
              (_TouchSelectionTapRecognizer instance) {
                instance.onTapUp = _onTouchTapUp;
              },
            ),
      // Desktop: mouse click-drag, double-click word, triple-click block, Shift-click.
      TapAndPanGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapAndPanGestureRecognizer>(
            () => TapAndPanGestureRecognizer(
              debugOwner: this,
              supportedDevices: _kDesktopPointerDevices,
            ),
            (TapAndPanGestureRecognizer instance) {
              instance
                ..onTapDown = _onDesktopTapDown
                ..onDragStart = _onDesktopDragStart
                ..onDragUpdate = _onDesktopDragUpdate
                ..onDragEnd = _onDesktopDragEnd
                ..onCancel = _onDesktopCancel;
            },
          ),
      // Desktop: secondary (right-click) context menu without competing with primary tap.
      _DesktopSecondaryTapRecognizer:
          GestureRecognizerFactoryWithHandlers<_DesktopSecondaryTapRecognizer>(
            () => _DesktopSecondaryTapRecognizer(
              debugOwner: this,
              supportedDevices: _kDesktopPointerDevices,
            ),
            (_DesktopSecondaryTapRecognizer instance) {
              instance.onSecondaryTapUp = _onDesktopSecondaryTapUp;
            },
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return _MarkdownSelectionScopeInherited(
      controller: controller,
      scopeState: this,
      child: Shortcuts(
        shortcuts: _buildShortcuts(),
        child: Actions(
          actions: _buildActions(),
          child: Focus(
            focusNode: _focusNode,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: RawGestureDetector(
                behavior: HitTestBehavior.translucent,
                gestures: _buildGestures(),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkdownSelectionScopeInherited extends InheritedWidget {
  const _MarkdownSelectionScopeInherited({
    required this.controller,
    required this.scopeState,
    required super.child,
  });

  final MarkdownSelectionController controller;
  final MarkdownSelectionScopeState scopeState;

  @override
  bool updateShouldNotify(_MarkdownSelectionScopeInherited oldWidget) {
    return oldWidget.controller != controller ||
        oldWidget.scopeState != scopeState;
  }
}

class _GuardedCallbackAction<T extends Intent> extends Action<T> {
  _GuardedCallbackAction({
    required this.isEnabledCallback,
    required this.onInvokeCallback,
  });

  final bool Function() isEnabledCallback;
  final Object? Function(T intent) onInvokeCallback;

  @override
  bool isEnabled(T intent) => isEnabledCallback();

  @override
  bool consumesKey(T intent) => isEnabled(intent);

  @override
  Object? invoke(T intent) => onInvokeCallback(intent);
}

class _TouchSelectionTapRecognizer extends TapGestureRecognizer {
  _TouchSelectionTapRecognizer({super.debugOwner, super.supportedDevices});
}

class _DesktopSecondaryTapRecognizer extends TapGestureRecognizer {
  _DesktopSecondaryTapRecognizer({super.debugOwner, super.supportedDevices});
}
