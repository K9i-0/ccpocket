import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class PlatformEnvironmentGateway {
  Future<bool> isIOSAppOnMac();
}

class MethodChannelPlatformEnvironmentGateway
    implements PlatformEnvironmentGateway {
  const MethodChannelPlatformEnvironmentGateway([
    this._channel = const MethodChannel('ccpocket/platform_environment'),
  ]);

  final MethodChannel _channel;

  @override
  Future<bool> isIOSAppOnMac() async {
    try {
      return await _channel.invokeMethod<bool>('isIOSAppOnMac') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('Platform environment unavailable: ${e.code}');
      return false;
    }
  }
}

class PlatformEnvironmentService {
  PlatformEnvironmentService._({PlatformEnvironmentGateway? gateway})
    : _gateway = gateway ?? const MethodChannelPlatformEnvironmentGateway();

  static final instance = PlatformEnvironmentService._();

  @visibleForTesting
  factory PlatformEnvironmentService.test({
    required PlatformEnvironmentGateway gateway,
  }) {
    return PlatformEnvironmentService._(gateway: gateway);
  }

  final PlatformEnvironmentGateway _gateway;

  Future<bool> isIOSAppOnMac() => _gateway.isIOSAppOnMac();
}
