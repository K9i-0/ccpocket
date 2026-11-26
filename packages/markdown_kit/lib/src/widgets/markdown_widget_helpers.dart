import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../parser/gfm_parser.dart';
import '../parser/markdown_parser.dart';
import '../selection/selection_controller.dart';
import '../selection/selection_model.dart';

int _nextAutoDocumentId = 0;

/// Generates a unique, stable fallback document identifier for widgets created
/// without an explicit `documentId`.
String generateMarkdownDocumentId() => 'mk_doc_${++_nextAutoDocumentId}';

/// Shared default [GfmMarkdownParser] used when callers omit both `parser` and
/// custom `parserOptions`, preserving cross-widget LRU AST cache hits.
final GfmMarkdownParser sharedDefaultMarkdownParser = GfmMarkdownParser();

/// Resolves an effective [MarkdownParser] from explicit [parser] and
/// [options], reusing [cachedCustomParser] when [options] are unchanged.
({MarkdownParser parser, GfmMarkdownParser? customParser})
resolveMarkdownParser({
  required MarkdownParser? parser,
  required MarkdownParserOptions options,
  required GfmMarkdownParser? cachedCustomParser,
}) {
  if (parser != null) {
    return (parser: parser, customParser: null);
  }
  if (options == const MarkdownParserOptions()) {
    return (parser: sharedDefaultMarkdownParser, customParser: null);
  }
  if (cachedCustomParser != null && cachedCustomParser.options == options) {
    return (parser: cachedCustomParser, customParser: cachedCustomParser);
  }
  final created = GfmMarkdownParser(options: options);
  return (parser: created, customParser: created);
}

/// Manages safe registration of a [MarkdownDocumentRef] against an active
/// [MarkdownSelectionController], avoiding synchronous `notifyListeners()`
/// during Flutter's build/layout phase when an active selection touches the
/// updating document.
class MarkdownDocumentRegistration {
  MarkdownSelectionController? _registeredController;
  String? _registeredDocumentId;
  bool _registeredKeepDocumentOnDispose = true;
  MarkdownDocumentRef? _pendingRef;
  MarkdownSelectionController? _pendingController;
  bool _postFrameScheduled = false;
  bool _disposed = false;

  /// Registers or updates [ref] on [controller].
  ///
  /// When [controller] is `null` or [selectable] is `false`, detaches any
  /// prior registration (removing the document only if the prior registration
  /// had `keepDocumentOnDispose == false`).
  void sync({
    required MarkdownSelectionController? controller,
    required MarkdownDocumentRef ref,
    required bool selectable,
    required bool keepDocumentOnDispose,
  }) {
    if (_disposed) return;

    final targetController = selectable ? controller : null;
    final prevController = _registeredController;
    final prevDocId = _registeredDocumentId;
    final prevKeep = _registeredKeepDocumentOnDispose;

    if (prevController != null &&
        prevDocId != null &&
        (prevController != targetController || prevDocId != ref.id)) {
      if (!prevKeep) {
        _removeSafely(prevController, prevDocId);
      }
      _registeredController = null;
      _registeredDocumentId = null;
    }

    if (targetController == null) {
      _pendingController = null;
      _pendingRef = null;
      return;
    }

    _registeredController = targetController;
    _registeredDocumentId = ref.id;
    _registeredKeepDocumentOnDispose = keepDocumentOnDispose;

    if (targetController.documentForId(ref.id) == ref) {
      if (_pendingController == targetController && _pendingRef?.id == ref.id) {
        _pendingController = null;
        _pendingRef = null;
      }
      return;
    }

    final activeSelection = targetController.selection;
    final selectionTouchesDoc =
        activeSelection != null &&
        (activeSelection.base.documentId == ref.id ||
            activeSelection.extent.documentId == ref.id);

    final inBuildPhase =
        SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;

    if (selectionTouchesDoc && inBuildPhase) {
      _pendingController = targetController;
      _pendingRef = ref;
      if (!_postFrameScheduled) {
        _postFrameScheduled = true;
        SchedulerBinding.instance.addPostFrameCallback(_flushPendingPut);
      }
      return;
    }

    _pendingController = null;
    _pendingRef = null;
    targetController.putDocument(ref);
  }

  /// Cleans up registration on widget disposal.
  ///
  /// When [keepDocumentOnDispose] is `true`, the document stays registered in
  /// the controller so model-anchored selections survive virtualized scroll-off
  /// and streaming-to-final widget handoffs.
  void dispose({required bool keepDocumentOnDispose}) {
    if (_disposed) return;
    _disposed = true;
    _pendingController = null;
    _pendingRef = null;

    final controller = _registeredController;
    final docId = _registeredDocumentId;
    _registeredController = null;
    _registeredDocumentId = null;

    if (!keepDocumentOnDispose && controller != null && docId != null) {
      _removeSafely(controller, docId);
    }
  }

  void _flushPendingPut(Duration _) {
    _postFrameScheduled = false;
    if (_disposed) return;
    final controller = _pendingController;
    final ref = _pendingRef;
    _pendingController = null;
    _pendingRef = null;
    if (controller == null || ref == null) return;
    if (_registeredController != controller ||
        _registeredDocumentId != ref.id) {
      return;
    }
    controller.putDocument(ref);
  }

  void _removeSafely(MarkdownSelectionController controller, String docId) {
    final activeSelection = controller.selection;
    final selectionTouchesDoc =
        activeSelection != null &&
        (activeSelection.base.documentId == docId ||
            activeSelection.extent.documentId == docId);
    final inBuildPhase =
        SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;

    if (selectionTouchesDoc && inBuildPhase) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        controller.removeDocument(docId);
      });
      return;
    }
    controller.removeDocument(docId);
  }
}

/// Wraps [child] with explicit [textDirection] and/or [textScaler] overrides
/// only when provided, avoiding unnecessary [MediaQuery] subscriptions.
Widget wrapWithTextOverrides(
  BuildContext context, {
  required Widget child,
  required TextDirection? textDirection,
  required TextScaler? textScaler,
}) {
  var result = child;
  if (textScaler != null) {
    final existing = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    result = MediaQuery(
      data: existing.copyWith(textScaler: textScaler),
      child: result,
    );
  }
  if (textDirection != null) {
    result = Directionality(textDirection: textDirection, child: result);
  }
  return result;
}
