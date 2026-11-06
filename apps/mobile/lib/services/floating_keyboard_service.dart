import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keyboard frame reported by the iOS `keyboardLayoutGuide`, in the Flutter
/// view's logical coordinates (same as Flutter global coordinates).
@immutable
class KeyboardGuideFrame {
  const KeyboardGuideFrame({required this.rect, required this.viewSize});

  factory KeyboardGuideFrame.fromMap(Map<Object?, Object?> map) {
    double read(String key) => (map[key]! as num).toDouble();
    return KeyboardGuideFrame(
      rect: Rect.fromLTWH(read('x'), read('y'), read('w'), read('h')),
      viewSize: Size(read('viewW'), read('viewH')),
    );
  }

  final Rect rect;
  final Size viewSize;

  /// A floating / undocked iPad keyboard: the guide follows it away from the
  /// bottom edge. A hidden keyboard leaves only the bottom safe-area strip,
  /// and a docked keyboard spans the full width at the bottom.
  bool get isFloating =>
      rect.height > 40 &&
      (rect.bottom < viewSize.height - 1 || rect.width < viewSize.width - 1);

  @override
  bool operator ==(Object other) =>
      other is KeyboardGuideFrame &&
      other.rect == rect &&
      other.viewSize == viewSize;

  @override
  int get hashCode => Object.hash(rect, viewSize);
}

/// Tracks iPad floating keyboards, which Flutter reports as a zero
/// `viewInsets.bottom`. [floatingFrame] is non-null only while a floating
/// keyboard is shown.
///
/// Builds without the native channel (older binaries receiving a Dart-only
/// OTA patch, Android, desktop, web) keep [floatingFrame] null.
class FloatingKeyboardService {
  FloatingKeyboardService({EventChannel? channel, bool? enabled})
    : _channel = channel ?? const EventChannel(channelName),
      _enabled =
          enabled ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  static const channelName = 'ccpocket/floating_keyboard';

  final EventChannel _channel;
  final bool _enabled;
  StreamSubscription<dynamic>? _subscription;

  final ValueNotifier<KeyboardGuideFrame?> _floatingFrame = ValueNotifier(null);

  ValueListenable<KeyboardGuideFrame?> get floatingFrame => _floatingFrame;

  void start() {
    if (!_enabled || _subscription != null) return;
    _subscription = _channel.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final frame = KeyboardGuideFrame.fromMap(event);
        _floatingFrame.value = frame.isFloating ? frame : null;
      },
      onError: (Object _) {
        // MissingPluginException on binaries without the native tracker.
        _floatingFrame.value = null;
        unawaited(_subscription?.cancel());
      },
      cancelOnError: true,
    );
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _floatingFrame.dispose();
  }
}
