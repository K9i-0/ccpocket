import 'package:ccpocket/models/machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Machine URLs', () {
    test('defaults to ws/http when SSL is disabled', () {
      const machine = Machine(id: 'm1', host: 'bridge.example.com');

      expect(machine.useSsl, isFalse);
      expect(machine.wsUrl, 'ws://bridge.example.com:8765');
      expect(machine.httpUrl, 'http://bridge.example.com:8765');
    });

    test('uses wss/https when SSL is enabled', () {
      const machine = Machine(
        id: 'm2',
        host: 'bridge.example.com',
        port: 443,
        useSsl: true,
      );

      expect(machine.wsUrl, 'wss://bridge.example.com:443');
      expect(machine.httpUrl, 'https://bridge.example.com:443');
    });

    test('wraps IPv6 hosts in URLs and display endpoints', () {
      const machine = Machine(id: 'm-ipv6', host: '[::1]', port: 19000);

      expect(machine.wsUrl, 'ws://[::1]:19000');
      expect(machine.httpUrl, 'http://[::1]:19000');
      expect(machine.displayName, '[::1]:19000');
      expect(machine.uniqueKey, '[::1]:19000');
    });

    test('encodes IPv6 zone IDs in URLs', () {
      const machine = Machine(id: 'm-zone', host: 'fe80::1%en0');

      expect(machine.wsUrl, 'ws://[fe80::1%25en0]:8765');
    });
  });

  group('Machine JSON', () {
    test('useSsl defaults to false when missing from stored data', () {
      final machine = Machine.fromJson({
        'id': 'm3',
        'host': 'bridge.example.com',
        'port': 8765,
      });

      expect(machine.useSsl, isFalse);
      expect(machine.wsUrl, 'ws://bridge.example.com:8765');
    });

    test(
      'SSH jump host fields default safely when missing from stored data',
      () {
        final machine = Machine.fromJson({
          'id': 'm4',
          'host': 'bridge.example.com',
          'port': 8765,
          'sshEnabled': true,
          'sshUsername': 'target-user',
        });

        expect(machine.sshJumpHost, isNull);
        expect(machine.sshJumpPort, 22);
        expect(machine.sshJumpUsername, isNull);
      },
    );

    test('SSH jump host fields round trip through JSON', () {
      const machine = Machine(
        id: 'm5',
        host: 'target.internal',
        sshEnabled: true,
        sshUsername: 'target-user',
        sshJumpHost: 'jump.example.com',
        sshJumpPort: 2222,
        sshJumpUsername: 'jump-user',
      );

      final decoded = Machine.fromJson(machine.toJson());

      expect(decoded.sshJumpHost, 'jump.example.com');
      expect(decoded.sshJumpPort, 2222);
      expect(decoded.sshJumpUsername, 'jump-user');
    });
  });
}
