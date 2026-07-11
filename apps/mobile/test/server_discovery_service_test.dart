import 'package:ccpocket/services/server_discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DiscoveredServer brackets IPv6 hosts in websocket URLs', () {
    const server = DiscoveredServer(
      name: 'bridge',
      host: 'fdbd:dc01:ff:321:254e:39ac:2d5d:1a67',
      port: 19000,
      authRequired: true,
    );

    expect(server.wsUrl, 'ws://[fdbd:dc01:ff:321:254e:39ac:2d5d:1a67]:19000');
  });

  test('DiscoveredServer equality uses canonical host identity', () {
    const raw = DiscoveredServer(
      name: 'first',
      host: 'FE80::1%En0',
      port: 8765,
      authRequired: false,
    );
    const escaped = DiscoveredServer(
      name: 'second',
      host: '[fe80::1%25En0]',
      port: 8765,
      authRequired: true,
    );

    expect(raw, escaped);
    expect(raw.hashCode, escaped.hashCode);
  });
}
