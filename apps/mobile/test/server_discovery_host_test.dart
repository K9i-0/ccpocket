import 'package:ccpocket/services/server_discovery_impl_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('selectDiscoveryHost', () {
    test('prefers the mDNS hostname when addresses are not preferred', () {
      expect(
        selectDiscoveryHost(
          name: 'ccpocket',
          hostname: 'mac.local.',
          hostAddresses: ['192.168.1.10'],
          preferAddress: false,
        ),
        'mac.local.',
      );
    });

    test('prefers an IPv4 address when addresses are preferred', () {
      expect(
        selectDiscoveryHost(
          name: 'ccpocket',
          hostname: 'mac.local',
          hostAddresses: ['fe80::1', '192.168.1.10'],
          preferAddress: true,
        ),
        '192.168.1.10',
      );
    });

    test('falls back to the other field when the preferred one is missing', () {
      expect(
        selectDiscoveryHost(
          name: 'ccpocket',
          hostname: null,
          hostAddresses: ['fe80::1'],
          preferAddress: false,
        ),
        'fe80::1',
      );
      expect(
        selectDiscoveryHost(
          name: 'ccpocket',
          hostname: 'mac.local',
          hostAddresses: const [],
          preferAddress: true,
        ),
        'mac.local',
      );
    });

    test('falls back to the service name when nothing is resolved', () {
      expect(
        selectDiscoveryHost(
          name: 'ccpocket',
          hostname: '',
          hostAddresses: const [],
          preferAddress: false,
        ),
        'ccpocket',
      );
    });
  });
}
