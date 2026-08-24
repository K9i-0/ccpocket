import 'package:flutter/services.dart';

import '../utils/platform_helper.dart';

class PlatformSettingsService {
  static const _channel = MethodChannel('ccpocket/app_settings');

  static Future<bool> openNotificationSettings() async {
    if (!isAndroidPlatform) return false;
    return await _channel.invokeMethod<bool>('openNotificationSettings') ??
        false;
  }
}
