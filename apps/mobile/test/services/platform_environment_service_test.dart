import 'package:ccpocket/services/platform_environment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformEnvironmentService', () {
    test('returns gateway value', () async {
      final service = PlatformEnvironmentService.test(
        gateway: const _FakePlatformEnvironmentGateway(
          isIOSAppOnMacValue: true,
          iosUserInterfaceIdiomValue: 'pad',
        ),
      );

      expect(await service.isIOSAppOnMac(), isTrue);
      expect(await service.iosUserInterfaceIdiom(), 'pad');
    });
  });

  group('NativePlatformEnvironmentGateway', () {
    test('reports no iOS environment off iOS', () async {
      // Unit tests run on the host OS, where the UIKit bindings are skipped.
      const gateway = NativePlatformEnvironmentGateway();

      expect(await gateway.isIOSAppOnMac(), isFalse);
      expect(await gateway.iosUserInterfaceIdiom(), isNull);
    });
  });
}

class _FakePlatformEnvironmentGateway implements PlatformEnvironmentGateway {
  const _FakePlatformEnvironmentGateway({
    required this.isIOSAppOnMacValue,
    required this.iosUserInterfaceIdiomValue,
  });

  final bool isIOSAppOnMacValue;
  final String? iosUserInterfaceIdiomValue;

  @override
  Future<bool> isIOSAppOnMac() async => isIOSAppOnMacValue;

  @override
  Future<String?> iosUserInterfaceIdiom() async => iosUserInterfaceIdiomValue;
}
