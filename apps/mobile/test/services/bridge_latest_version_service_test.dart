import 'package:ccpocket/services/bridge_latest_version_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BridgeLatestVersionService', () {
    test('fetches latest bridge version from npm registry', () async {
      final service = BridgeLatestVersionService(
        httpClient: MockClient((request) async {
          expect(request.url, BridgeLatestVersionService.latestPackageUri);
          return http.Response('{"version":"1.2.3"}', 200);
        }),
      );

      final version = await service.fetchLatestVersion();

      expect(version, '1.2.3');
    });

    test('caches latest version for repeated calls', () async {
      var calls = 0;
      final service = BridgeLatestVersionService(
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('{"version":"1.2.3"}', 200);
        }),
      );

      expect(await service.fetchLatestVersion(), '1.2.3');
      expect(await service.fetchLatestVersion(), '1.2.3');

      expect(calls, 1);
    });

    test('throws when registry response is invalid', () async {
      final service = BridgeLatestVersionService(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(service.fetchLatestVersion(), throwsA(isA<FormatException>()));
    });

    test('throws on non-200 registry response', () async {
      final service = BridgeLatestVersionService(
        httpClient: MockClient((_) async => http.Response('nope', 503)),
      );

      expect(service.fetchLatestVersion(), throwsA(isA<StateError>()));
    });
  });
}
