import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef NativePasteHandler = bool Function(String text);

class NativePasteBridge {
  NativePasteBridge._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static final NativePasteBridge instance = NativePasteBridge._();

  static const _channel = MethodChannel('ccpocket/native_paste_bridge');

  _NativePasteTarget? _activeTarget;

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  void activate(Object owner, NativePasteHandler handler) {
    if (!_isSupported) return;
    _activeTarget = _NativePasteTarget(owner, handler);
    _setEnabled(true);
  }

  void deactivate(Object owner) {
    if (!_isSupported) return;
    if (!identical(_activeTarget?.owner, owner)) return;
    _activeTarget = null;
    _setEnabled(false);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'nativePaste':
        final text = call.arguments as String? ?? '';
        if (text.isEmpty) return false;
        return _activeTarget?.handler(text) ?? false;
      default:
        throw PlatformException(
          code: 'unimplemented',
          message: 'Unknown native paste bridge method: ${call.method}',
        );
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      // Non-macOS targets and tests without the native runner have no plugin.
    }
  }
}

class _NativePasteTarget {
  const _NativePasteTarget(this.owner, this.handler);

  final Object owner;
  final NativePasteHandler handler;
}
