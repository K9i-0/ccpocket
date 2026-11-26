import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'clipboard_image_service.dart';

/// Receives OS-level image drops on desktop platforms via `ccpocket/image_drop`.
///
/// Safe no-op on mobile, Web, and older native runners without this channel.
class DesktopImageDropService {
  DesktopImageDropService({EventChannel? channel, bool? supported})
    : _channel = channel ?? const EventChannel(channelName),
      _supported = supported ?? _isDesktopRuntime();

  static const channelName = 'ccpocket/image_drop';

  static final _default = DesktopImageDropService();
  static DesktopImageDropService? _override;

  static DesktopImageDropService get instance => _override ?? _default;

  /// Replaces [instance] in tests; pass null to restore the default instance.
  @visibleForTesting
  static set debugOverride(DesktopImageDropService? service) {
    _override = service;
  }

  static bool _isDesktopRuntime() {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  final EventChannel _channel;
  final bool _supported;
  StreamController<List<ClipboardImageData>>? _controller;
  StreamSubscription<dynamic>? _channelSubscription;

  /// Broadcast stream of dropped image batches.
  ///
  /// The underlying native event channel is listened to lazily while at least
  /// one subscriber is attached, and cancelled when the last subscriber leaves.
  Stream<List<ClipboardImageData>> get images {
    if (!_supported) {
      return const Stream<List<ClipboardImageData>>.empty();
    }
    _controller ??= StreamController<List<ClipboardImageData>>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );
    return _controller!.stream;
  }

  void _startListening() {
    if (_channelSubscription != null) return;
    _channelSubscription = _channel.receiveBroadcastStream().listen(
      (event) {
        final parsed = parseDroppedImagesPayload(event);
        if (parsed.isNotEmpty) {
          _controller?.add(parsed);
        }
      },
      onError: (Object error) {
        // Older native runners or unsupported targets may throw
        // MissingPluginException. Treat as a safe no-op.
        if (error is MissingPluginException) {
          _stopListening();
        } else {
          debugPrint('[drop] Native image drop error: $error');
        }
      },
      cancelOnError: false,
    );
  }

  void _stopListening() {
    final sub = _channelSubscription;
    _channelSubscription = null;
    if (sub != null) {
      unawaited(sub.cancel().catchError((Object _, StackTrace _) {}));
    }
  }

  /// Parses an event payload into validated image records.
  ///
  /// Supports a list of `{bytes, mimeType}` maps (standard) as well as a single
  /// map payload defensively.
  static List<ClipboardImageData> parseDroppedImagesPayload(Object? raw) {
    if (raw is List) {
      final results = <ClipboardImageData>[];
      for (final item in raw) {
        final parsed = ClipboardImageService.parseClipboardImagePayload(item);
        if (parsed != null) {
          results.add(parsed);
        }
      }
      return results;
    }
    final single = ClipboardImageService.parseClipboardImagePayload(raw);
    return single == null ? const [] : [single];
  }
}

/// Subscribes to native desktop image drops while mounted and [enabled].
///
/// On mobile and Web (or when [enabled] is false), renders [child] directly
/// without opening a platform channel subscription.
class DesktopImageDropTarget extends StatefulWidget {
  const DesktopImageDropTarget({
    super.key,
    required this.enabled,
    required this.onImagesDropped,
    required this.child,
    this.service,
  });

  final bool enabled;
  final void Function(List<ClipboardImageData> images) onImagesDropped;
  final Widget child;
  final DesktopImageDropService? service;

  @override
  State<DesktopImageDropTarget> createState() => _DesktopImageDropTargetState();
}

class _DesktopImageDropTargetState extends State<DesktopImageDropTarget> {
  StreamSubscription<List<ClipboardImageData>>? _subscription;

  @override
  void initState() {
    super.initState();
    _syncSubscription();
  }

  @override
  void didUpdateWidget(covariant DesktopImageDropTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.service != widget.service) {
      _cancelSubscription();
      _syncSubscription();
    }
  }

  void _syncSubscription() {
    if (!widget.enabled || kIsWeb) return;
    final service = widget.service ?? DesktopImageDropService.instance;
    _subscription = service.images.listen((images) {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      if (images.isEmpty) return;
      widget.onImagesDropped(images);
    });
  }

  void _cancelSubscription() {
    final sub = _subscription;
    _subscription = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
  }

  @override
  void dispose() {
    _cancelSubscription();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
