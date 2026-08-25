import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IOSClipboardImageAvailability {
  const IOSClipboardImageAvailability._();

  static const _channel = MethodChannel('ccpocket/clipboard');

  static Future<bool> hasSupportedImage() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return await _channel.invokeMethod<bool>('hasSupportedImage') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
