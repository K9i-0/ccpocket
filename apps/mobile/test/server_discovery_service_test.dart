import 'package:ccpocket/services/server_discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscoveredServer', () {
    test('wraps IPv6 hosts in websocket URLs', () {
      const server = DiscoveredServer(
        name: 'bridge',
        host: 'fdbd:dc01:ff:321:254e:39ac:2d5d:1a67',
        port: 19000,
        authRequired: true,
      );

      expect(server.wsUrl, 'ws://[fdbd:dc01:ff:321:254e:39ac:2d5d:1a67]:19000');
    });
  });
}
