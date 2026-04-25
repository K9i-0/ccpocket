import 'package:ccpocket/services/platform_environment_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformEnvironmentService', () {
    test('returns gateway value', () async {
      final service = PlatformEnvironmentService.test(
        gateway: const _FakePlatformEnvironmentGateway(true),
      );

      expect(await service.isIOSAppOnMac(), isTrue);
    });
  });

  group('MethodChannelPlatformEnvironmentGateway', () {
    const channel = MethodChannel('ccpocket/platform_environment_test');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('reads isIOSAppOnMac from the platform channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'isIOSAppOnMac');
            return true;
          });

      final gateway = MethodChannelPlatformEnvironmentGateway(channel);

      expect(await gateway.isIOSAppOnMac(), isTrue);
    });

    test('falls back to false when the channel is unavailable', () async {
      final gateway = MethodChannelPlatformEnvironmentGateway(channel);

      expect(await gateway.isIOSAppOnMac(), isFalse);
    });

    test('falls back to false on platform errors', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'unavailable');
          });

      final gateway = MethodChannelPlatformEnvironmentGateway(channel);

      expect(await gateway.isIOSAppOnMac(), isFalse);
    });
  });
}

class _FakePlatformEnvironmentGateway implements PlatformEnvironmentGateway {
  const _FakePlatformEnvironmentGateway(this.value);

  final bool value;

  @override
  Future<bool> isIOSAppOnMac() async => value;
}
