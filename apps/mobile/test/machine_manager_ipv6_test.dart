import 'dart:convert';

import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage implements FlutterSecureStorage {
  final values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<MachineManagerService> createManager([
    _FakeSecureStorage? secureStorage,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final manager = MachineManagerService(
      prefs,
      secureStorage ?? _FakeSecureStorage(),
    );
    manager.configureBridgeTunnelResolvers(
      httpBaseUrlResolver: (machine, {password, promptForPassword}) async =>
          'http://127.0.0.1:1',
    );
    return manager;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'recordConnection deduplicates bracket and zone escape variants',
    () async {
      final manager = await createManager();

      await manager.recordConnection(host: '[fe80::1%25en0]', port: 8765);
      await manager.recordConnection(host: 'fe80::1%en0', port: 8765);

      expect(manager.currentMachines, hasLength(1));
      expect(manager.currentMachines.single.host, 'fe80::1%en0');
      manager.dispose();
    },
  );

  test(
    'init normalizes bracketed saved hosts without changing machine id',
    () async {
      const saved = Machine(
        id: 'saved-ipv6',
        host: '[::1]',
        sshJumpHost: '[fe80::2%25en0]',
      );
      SharedPreferences.setMockInitialValues({
        'machines_v2': jsonEncode([saved.toJson()]),
      });
      final manager = await createManager();

      await manager.init();

      expect(manager.currentMachines.single.id, 'saved-ipv6');
      expect(manager.currentMachines.single.host, '::1');
      expect(manager.currentMachines.single.sshJumpHost, 'fe80::2%en0');
      expect(manager.findByHostPort('[::1]', 8765)?.id, 'saved-ipv6');
      manager.dispose();
    },
  );

  test(
    'init merges duplicate credentials into the preferred machine id',
    () async {
      const favorite = Machine(id: 'favorite', host: '[::1]', isFavorite: true);
      const apiOwner = Machine(
        id: 'api-owner',
        host: '0:0:0:0:0:0:0:1',
        hasApiKey: true,
      );
      const sshOwner = Machine(
        id: 'ssh-owner',
        host: '::1',
        hasCredentials: true,
        hasJumpCredentials: true,
      );
      SharedPreferences.setMockInitialValues({
        'machines_v2': jsonEncode([
          favorite.toJson(),
          apiOwner.toJson(),
          sshOwner.toJson(),
        ]),
      });
      final storage = _FakeSecureStorage()
        ..values['machine_api-owner_api'] = 'secret'
        ..values['machine_ssh-owner_ssh_key'] = 'private-key'
        ..values['machine_ssh-owner_jump_ssh_pass'] = 'jump-password';
      final manager = await createManager(storage);

      await manager.init();

      expect(manager.currentMachines, hasLength(1));
      expect(manager.currentMachines.single.id, 'favorite');
      expect(manager.currentMachines.single.hasApiKey, isTrue);
      expect(manager.currentMachines.single.hasCredentials, isTrue);
      expect(manager.currentMachines.single.hasJumpCredentials, isTrue);
      expect(await manager.getApiKey('favorite'), 'secret');
      expect(await manager.getSshPrivateKey('favorite'), 'private-key');
      expect(await manager.getSshJumpPassword('favorite'), 'jump-password');
      expect(await manager.getApiKey('api-owner'), isNull);
      expect(await manager.getSshPrivateKey('ssh-owner'), isNull);
      expect(await manager.getSshJumpPassword('ssh-owner'), isNull);
      manager.dispose();
    },
  );

  test(
    'addMachine preserves an existing normalized endpoint identity',
    () async {
      final manager = await createManager();
      final existing = await manager.recordConnection(
        host: '[::1]',
        port: 8765,
        apiKey: 'secret',
      );

      await manager.addMachine(
        const Machine(id: 'replacement', host: '::1', name: 'Loopback'),
      );

      expect(manager.currentMachines, hasLength(1));
      expect(manager.currentMachines.single.id, existing.id);
      expect(manager.currentMachines.single.name, 'Loopback');
      expect(manager.currentMachines.single.hasApiKey, isTrue);
      expect(await manager.getApiKey(existing.id), 'secret');
      manager.dispose();
    },
  );
}
