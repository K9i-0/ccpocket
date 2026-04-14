import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/app_icon.dart';

const _appIconChannelName = 'ccpocket/app_icon';

abstract class AppIconGateway {
  Future<bool> supportsAlternateIcons();
  Future<String?> getCurrentIcon();
  Future<void> setIcon(String? iconId);
}

class MethodChannelAppIconGateway implements AppIconGateway {
  const MethodChannelAppIconGateway([
    this._channel = const MethodChannel(_appIconChannelName),
  ]);

  final MethodChannel _channel;

  @override
  Future<bool> supportsAlternateIcons() async {
    final supported = await _channel.invokeMethod<bool>(
      'supportsAlternateIcons',
    );
    return supported ?? false;
  }

  @override
  Future<String?> getCurrentIcon() {
    return _channel.invokeMethod<String>('getCurrentIcon');
  }

  @override
  Future<void> setIcon(String? iconId) {
    return _channel.invokeMethod<void>('setIcon', {'icon': iconId});
  }
}

class AppIconService {
  AppIconService({AppIconGateway? gateway, TargetPlatform? platform})
    : _gateway = gateway ?? const MethodChannelAppIconGateway(),
      _platform = platform;

  final AppIconGateway _gateway;
  final TargetPlatform? _platform;

  AppIconVariant? _lastAppliedIcon;
  Future<bool>? _availabilityFuture;

  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    final platform = _platform ?? defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  Future<bool> isSupported() {
    if (!isSupportedPlatform) return SynchronousFuture(false);
    WidgetsFlutterBinding.ensureInitialized();
    return _availabilityFuture ??= _gateway.supportsAlternateIcons().catchError(
      (Object _) => false,
    );
  }

  Future<void> sync({
    required AppIconVariant selectedIcon,
    required bool isSupporter,
    bool force = false,
    bool allowResetToDefault = true,
  }) async {
    final supported = await isSupported();
    if (!supported) return;

    if (!isSupporter && !allowResetToDefault) {
      return;
    }

    final targetIcon = isSupporter ? selectedIcon : AppIconVariant.defaultIcon;
    if (!force && _lastAppliedIcon == targetIcon) return;

    final currentIcon =
        _lastAppliedIcon ??
        appIconVariantFromId(await _gateway.getCurrentIcon());
    if (currentIcon == targetIcon) {
      _lastAppliedIcon = currentIcon;
      return;
    }

    await _gateway.setIcon(targetIcon.platformIconId);
    _lastAppliedIcon = targetIcon;
  }
}
