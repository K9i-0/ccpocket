import 'package:flutter/foundation.dart';

import 'native/ios_environment.dart';

abstract class PlatformEnvironmentGateway {
  Future<bool> isIOSAppOnMac();
  Future<String?> iosUserInterfaceIdiom();
}

/// Reads the environment straight from UIKit / Foundation through FFIgen
/// bindings instead of a platform channel.
class NativePlatformEnvironmentGateway implements PlatformEnvironmentGateway {
  const NativePlatformEnvironmentGateway();

  @override
  Future<bool> isIOSAppOnMac() async => readIsIOSAppOnMac();

  @override
  Future<String?> iosUserInterfaceIdiom() async => readIOSUserInterfaceIdiom();
}

class PlatformEnvironmentService {
  PlatformEnvironmentService._({PlatformEnvironmentGateway? gateway})
    : _gateway = gateway ?? const NativePlatformEnvironmentGateway();

  static final _default = PlatformEnvironmentService._();
  static PlatformEnvironmentService? _override;

  static PlatformEnvironmentService get instance => _override ?? _default;

  /// Replaces [instance] in tests; pass null to restore the native gateway.
  @visibleForTesting
  static set debugOverride(PlatformEnvironmentService? service) {
    _override = service;
  }

  @visibleForTesting
  factory PlatformEnvironmentService.test({
    required PlatformEnvironmentGateway gateway,
  }) {
    return PlatformEnvironmentService._(gateway: gateway);
  }

  final PlatformEnvironmentGateway _gateway;

  Future<bool> isIOSAppOnMac() => _gateway.isIOSAppOnMac();

  Future<String?> iosUserInterfaceIdiom() => _gateway.iosUserInterfaceIdiom();
}
